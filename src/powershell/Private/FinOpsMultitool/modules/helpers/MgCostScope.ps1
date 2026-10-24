# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Read-only: resolves a scope and changes no state.')]
param()

# -- MG-Scope State --------------------------------------------------------
# First cost module that gets 401/403 at MG scope sets this to $true.
# All subsequent modules check it and skip to per-sub immediately.
$script:MgCostScopeFailed = $false

function Test-MgCostScope {
    return (-not $script:MgCostScopeFailed)
}

function Set-MgCostScopeFailed {
    $script:MgCostScopeFailed = $true
    Write-Host "  Management-group cost queries are disabled for this scan. Subsequent cost modules will query the selected subscriptions individually." -ForegroundColor Yellow
}

# -- Resolved Cost MG Scope ------------------------------------------------
# Many orgs assign Cost Management Reader on a CHILD management group rather
# than the tenant-root group (whose id == tenant GUID), so querying
# managementGroups/<tenantId> returns 401. Resolve-CostMgId probes the tenant
# root first, then a bounded set of accessible MGs, and caches the first usable
# scope for this tenant. Falls back to per-subscription when none work.
$script:CostMgId = $null
$script:CostMgTenantId = $null
$script:CostMgCoverage = @{}

function Reset-CostMgScope {
    $script:CostMgId = $null
    $script:CostMgTenantId = $null
    $script:MgCostScopeFailed = $false
    $script:CostMgCoverage = @{}
    # A throttle window describes one tenant's quota, so it doesn't outlive the tenant.
    Reset-CostMgmtThrottle
}

# Probes one management group with a cheap query. Returns 'Usable', 'Throttled'
# (Cost Management asked for a wait longer than a call spends, so no later probe
# can be answered either), or 'Unusable' (no cost role here, or the scope
# doesn't answer). A low retry budget lets a throttled candidate fail fast; the
# real cost queries keep the full budget.
function Get-CostMgProbeResult {
    param(
        [Parameter(Mandatory)][string]$ManagementGroupId,
        [Parameter(Mandatory)][string]$Body
    )

    $path = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
    $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $Body -MaxRetries 2
    if ($resp -and $resp.StatusCode -eq 200) { return 'Usable' }
    if ($resp -and $resp.StatusCode -eq 429 -and (Get-CostMgmtThrottleRemaining -Key 'query') -gt 0) { return 'Throttled' }
    return 'Unusable'
}

function Resolve-CostMgId {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )

    if ($script:CostMgTenantId -ne $TenantId) {
        Reset-CostMgScope
        $script:CostMgTenantId = $TenantId
    }
    if ($script:MgCostScopeFailed) { return $null }
    if ($script:CostMgId) { return $script:CostMgId }

    $probeBody = @{
        type      = 'ActualCost'
        timeframe = 'MonthToDate'
        dataset   = @{
            granularity = 'None'
            aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
        }
    } | ConvertTo-Json -Depth 10

    # Throttled isn't denied: access is unknown, so management-group queries stay
    # enabled and the scans that need them report incomplete results.
    $throttledMessage = "  Cost Management is limiting requests, so management-group cost access couldn't be checked. Cost scans query the selected subscriptions individually or report incomplete results."

    # The tenant root goes first. A cost role there covers every subscription
    # with one query, so a readable root settles discovery in a single probe
    # instead of listing groups and probing up to 25. Cost access often lives on
    # a child MG instead, which the steps below look for.
    $rootProbe = Get-CostMgProbeResult -ManagementGroupId $TenantId -Body $probeBody
    if ($rootProbe -eq 'Usable') {
        $script:CostMgId = $TenantId
        return $TenantId
    }
    if ($rootProbe -eq 'Throttled') {
        Write-Host $throttledMessage -ForegroundColor Yellow
        return $null
    }

    # Candidates are the management groups the caller can actually see. The
    # tenant root already had its probe, and it counts toward the probe limit.
    $probeLimit = 25
    $candidates = [System.Collections.Generic.List[string]]::new()
    $seenCandidates = @{}

    try {
        $listResp = Invoke-AzRestMethodWithRetry -Path '/providers/Microsoft.Management/managementGroups?api-version=2020-05-01' -Method GET
        if ($listResp -and $listResp.StatusCode -eq 200) {
            $mgs = (Get-FinOpsListResult -FirstResponse $listResp -Context 'management-group discovery').value
            foreach ($mg in @($mgs)) {
                $name = [string]$mg.name
                if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne $TenantId -and -not $seenCandidates.ContainsKey($name)) {
                    $seenCandidates[$name] = $true
                    $candidates.Add($name)
                }
            }
        }
    }
    catch {
        Write-Warning "Management-group discovery is incomplete; only the tenant root was probed. $($_.Exception.Message)"
    }

    $limited = $candidates.Count -ge $probeLimit
    if ($limited) { $candidates.RemoveRange(($probeLimit - 1), ($candidates.Count - $probeLimit + 1)) }

    # A throttled (429) probe must not abandon discovery - keep trying the rest,
    # unless a long throttle window means none of them can be answered.
    foreach ($mgId in $candidates) {
        $probe = Get-CostMgProbeResult -ManagementGroupId $mgId -Body $probeBody
        if ($probe -eq 'Usable') {
            $script:CostMgId = $mgId
            Write-Host "  Cost scope resolved to management group '$mgId'." -ForegroundColor Yellow
            return $mgId
        }
        if ($probe -eq 'Throttled') {
            Write-Host $throttledMessage -ForegroundColor Yellow
            return $null
        }
    }

    if ($limited) {
        Write-Warning "Management-group cost discovery is limited to $probeLimit candidates, including the tenant root. Remaining groups weren't probed, so cost scans query the selected subscriptions individually."
    }
    Set-MgCostScopeFailed
    return $null
}

# -- Selected-Subscription Coverage -----------------------------------------
# Resolve-CostMgId returns the first management group that accepts a cost
# query, which might not contain every selected subscription. Scans that can't
# detect a missing subscription in their grouped response confirm membership
# first. An unverified scope makes the caller query subscriptions individually.
function Test-CostMgCoverage {
    param(
        [Parameter(Mandatory)][string]$ManagementGroupId,
        [Parameter(Mandatory)][string]$TenantId,
        [object[]]$Subscriptions
    )

    $ids = @($Subscriptions | ForEach-Object { [string]$_.Id } | Where-Object { $_ } | Sort-Object -Unique)
    if ($ids.Count -eq 0) { return $false }
    if ($ManagementGroupId -eq $TenantId) { return $true }

    $key = "$ManagementGroupId|$($ids -join ',')".ToLowerInvariant()
    if ($script:CostMgCoverage.ContainsKey($key)) { return $script:CostMgCoverage[$key] }

    $covered = $false
    try {
        $ancestry = Search-AzGraphSafe -Query "resourcecontainers | where type =~ 'microsoft.resources/subscriptions' | project subscriptionId, ancestors = properties.managementGroupAncestorsChain" -Subscription $ids -First 1000 -All
        $members = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($row in @($ancestry.Data)) {
            $ancestors = if ($row.ancestors -is [string]) { @($row.ancestors | ConvertFrom-Json -ErrorAction Stop) } else { @($row.ancestors) }
            if (@($ancestors | Where-Object { [string]$_.name -eq $ManagementGroupId }).Count -gt 0) { [void]$members.Add([string]$row.subscriptionId) }
        }
        $covered = @($ids | Where-Object { -not $members.Contains($_) }).Count -eq 0
    }
    catch {
        Write-Verbose "Management-group membership could not be verified: $($_.Exception.Message)"
    }
    if (-not $covered) {
        Write-Host "  Management group '$ManagementGroupId' isn't verified to contain every selected subscription. This scan queries the selected subscriptions individually." -ForegroundColor Yellow
    }
    $script:CostMgCoverage[$key] = $covered
    return $covered
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
