# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# -- MG-Scope State --------------------------------------------------------
# First cost module that gets 401/403 at MG scope sets this to $true.
# All subsequent modules check it and skip to per-sub immediately.
$script:MgCostScopeFailed = $false

function Test-MgCostScope {
    return (-not $script:MgCostScopeFailed)
}

function Set-MgCostScopeFailed {
    $script:MgCostScopeFailed = $true
    Write-Host "  MG-scope cost access unavailable for this tenant - all subsequent modules will use per-subscription queries" -ForegroundColor Yellow
}

# -- Resolved Cost MG Scope ------------------------------------------------
# Many orgs assign Cost Management Reader on a CHILD management group rather
# than the tenant-root group (whose id == tenant GUID), so querying
# managementGroups/<tenantId> returns 401. Resolve-CostMgId probes the tenant
# root first, then every accessible MG, and caches the first scope that returns
# cost data. Falls back to per-subscription when none work.
$script:CostMgId = $null

function Reset-CostMgScope {
    $script:CostMgId = $null
    $script:MgCostScopeFailed = $false
}

function Resolve-CostMgId {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )

    if ($script:MgCostScopeFailed) { return $null }
    if ($script:CostMgId) { return $script:CostMgId }

    # Candidates are the management groups the caller can actually see. Cost
    # access usually lives on a child MG (not the tenant root), so probe the
    # visible MGs first and fall back to the tenant root last. A throttled
    # (429) probe must not abandon discovery - keep trying the rest.
    $candidates = [System.Collections.Generic.List[string]]::new()

    try {
        $listResp = Invoke-AzRestMethodWithRetry -Path '/providers/Microsoft.Management/managementGroups?api-version=2020-05-01' -Method GET
        if ($listResp -and $listResp.StatusCode -eq 200) {
            $mgs = ($listResp.Content | ConvertFrom-Json).value
            foreach ($mg in @($mgs)) {
                $name = $mg.name
                if ($name -and -not $candidates.Contains($name)) {
                    $candidates.Add($name)
                }
                if ($candidates.Count -ge 12) { break }
            }
        }
    }
    catch { }

    # Tenant root as a last-resort candidate (covers orgs where the cost role
    # is assigned at the root management group).
    if (-not $candidates.Contains($TenantId)) {
        $candidates.Add($TenantId)
    }

    $probeBody = @{
        type      = 'ActualCost'
        timeframe = 'MonthToDate'
        dataset   = @{
            granularity = 'None'
            aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
        }
    } | ConvertTo-Json -Depth 10

    # Use a low retry budget per probe so a throttled candidate fails fast and
    # we move on to the next one. The real cost queries keep the full budget.
    foreach ($mgId in $candidates) {
        $path = "/providers/Microsoft.Management/managementGroups/$mgId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
        $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $probeBody -MaxRetries 2
        if ($resp -and $resp.StatusCode -eq 200) {
            $script:CostMgId = $mgId
            if ($mgId -ne $TenantId) {
                Write-Host "  Cost scope resolved to management group '$mgId' (no cost role on tenant root)" -ForegroundColor Yellow
            }
            return $mgId
        }
        # 401/403 = no cost role here; 429 = throttled; anything else = unusable
        # at this scope. In every case, keep probing the remaining candidates so
        # a throttled tenant-root probe never blocks reaching the child MG.
    }

    Set-MgCostScopeFailed
    return $null
}

# -- Shared Subscription-Scope Filter -------------------------------------
# When the user picks a subset of subscriptions we still want the single fast
# MG-scope cost query (one call covers the whole management group), but scoped
# to only the selected subscriptions. The Cost Management Query API supports a
# server-side dataset filter on the SubscriptionId dimension, so we build that
# filter once and inject it into each cost query body. This avoids the slow
# per-subscription fan-out (N calls per timeframe) that hammers the throttle.
function Get-CostSubscriptionFilter {
    param([object[]]$Subscriptions)
    if (-not $Subscriptions -or $Subscriptions.Count -eq 0) { return $null }
    $ids = @($Subscriptions | ForEach-Object { [string]$_.Id } | Where-Object { $_ })
    if ($ids.Count -eq 0) { return $null }
    return @{
        dimensions = @{
            name     = 'SubscriptionId'
            operator = 'In'
            values   = $ids
        }
    }
}
