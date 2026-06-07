###########################################################################
# GET-UNITECONOMICS.PS1
# AZURE FINOPS MULTITOOL - Unit Economics ($/vCPU, $/GB)
###########################################################################
# Purpose: Compute FinOps unit-economics KPIs by dividing amortized cost
#          by provisioned capacity: cost per vCPU (compute) and cost per
#          GB (storage). Combines Cost Management amortized spend with
#          Azure Resource Graph capacity counts.
###########################################################################
# Notes:
# - RBAC: Cost Management Reader (billing/MG scope) + Reader (ARG).
# - vCPU and RAM are exact when the Compute SKU capability lookup succeeds
#   (authoritative vCPUs/MemoryGB per size); they fall back to a VM-size-name
#   heuristic only when the SKUs API is unavailable for a region.
# - Storage GB combines provisioned managed-disk size (Resource Graph) and
#   Storage-account used capacity (Azure Monitor UsedCapacity metric, one
#   call per account); failures fall back to disk-only with a note.
# - Costs are month-to-date amortized, scoped to the selected subscriptions,
#   grouped by meter category, with a per-subscription fallback when the
#   management-group scope is not accessible.
###########################################################################

# -- Helper: exact vCPU/RAM from Compute SKU capabilities -----------------
# The Resource Graph 'resources' table does not expose vCPU/memory, so we
# query the Compute SKUs API per region (cached by location, follows
# nextLink) and build a vmSize -> {vCPU, MemGb} map. Returns $null when the
# size is not found so the caller can fall back to a name heuristic.
function Get-VmSizeCapability {
    param(
        [string]$SubId,
        [string]$Location,
        [string]$VmSize,
        [hashtable]$Cache
    )
    if (-not $Location -or -not $SubId) { return $null }
    if (-not $Cache.ContainsKey($Location)) {
        $map = @{}
        try {
            $next = "/subscriptions/$SubId/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=location eq '$Location'"
            $pages = 0
            while ($next -and $pages -lt 6) {
                $resp = Invoke-AzRestMethodWithRetry -Path $next -Method GET
                if (-not $resp -or $resp.StatusCode -ne 200 -or -not $resp.Content) { break }
                $json = $resp.Content | ConvertFrom-Json
                foreach ($s in @($json.value)) {
                    if ($s.resourceType -ne 'virtualMachines') { continue }
                    if (-not $s.name -or $map.ContainsKey($s.name)) { continue }
                    $vc = 0; $mem = 0.0
                    foreach ($c in @($s.capabilities)) {
                        if ($c.name -eq 'vCPUs') { [void][int]::TryParse([string]$c.value, [ref]$vc) }
                        elseif ($c.name -eq 'MemoryGB') { [void][double]::TryParse([string]$c.value, [ref]$mem) }
                    }
                    $map[$s.name] = @{ VCpu = $vc; MemGb = $mem }
                }
                $nl = $json.nextLink
                $next = if ($nl) { ($nl -replace '^https?://[^/]+', '') } else { $null }
                $pages++
            }
        }
        catch { }
        $Cache[$Location] = $map
    }
    $m = $Cache[$Location]
    if ($m -and $m.ContainsKey($VmSize)) {
        return [PSCustomObject]@{ VCpu = [int]$m[$VmSize].VCpu; MemGb = [double]$m[$VmSize].MemGb }
    }
    return $null
}

# -- Helper: accumulate amortized cost by meter category ------------------
# Parses a Cost Management query response (grouped by MeterCategory) and adds
# compute vs storage spend into the supplied references. Returns $true when
# the response contained any rows (i.e. the query succeeded with data).
function Add-MeterCosts {
    param(
        [string]$Content,
        [ref]$ComputeRef,
        [ref]$StorageRef,
        [ref]$CurrencyRef
    )
    $any = $false
    try {
        $data = $Content | ConvertFrom-Json
        if ($data.properties.rows) {
            foreach ($row in $data.properties.rows) {
                $any = $true
                $amount = [double]$row[0]
                $category = [string]$row[1]
                if ($row.Count -ge 3 -and $row[2]) { $CurrencyRef.Value = [string]$row[2] }
                switch -Wildcard ($category) {
                    'Virtual Machines*' { $ComputeRef.Value += $amount }
                    'Storage*' { $StorageRef.Value += $amount }
                    default { }
                }
            }
        }
    }
    catch { }
    return $any
}

# -- Helper: storage account used capacity (blob/file/queue/table) --------
# Managed disks are captured separately via Resource Graph. This adds the
# data-plane used capacity of Storage accounts via the Azure Monitor metrics
# API (UsedCapacity, account-level, emitted once per day). One metrics call
# per account; a failed account is skipped so it never breaks the scan.
# Returns used GB, or $null when the account inventory could not be read.
function Get-StorageAccountUsedGb {
    param([string[]]$SubIds)

    $accounts = @()
    try {
        $saQuery = @"
resources
| where type =~ 'microsoft.storage/storageaccounts'
| project id
"@
        $result = Search-AzGraphSafe -Query $saQuery -Subscription $SubIds -First 1000
        $accounts = if ($result) { @($result.Data) } else { @() }
    }
    catch {
        Write-Warning "  Storage account inventory query failed: $($_.Exception.Message)"
        return $null
    }

    if ($accounts.Count -eq 0) { return 0.0 }

    # UsedCapacity is a daily metric; a 2-day window guarantees a data point.
    $end = (Get-Date).ToUniversalTime()
    $start = $end.AddDays(-2)
    $timespan = "$($start.ToString('yyyy-MM-ddTHH:mm:ssZ'))/$($end.ToString('yyyy-MM-ddTHH:mm:ssZ'))"

    $totalBytes = 0.0
    $queried = 0
    foreach ($a in $accounts) {
        if ($queried -ge 500) { break }   # safety bound on call fan-out
        $queried++
        try {
            $path = "$($a.id)/providers/Microsoft.Insights/metrics?api-version=2018-01-01&metricnames=UsedCapacity&aggregation=Average&interval=P1D&timespan=$timespan"
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method GET
            if (-not $resp -or $resp.StatusCode -ne 200 -or -not $resp.Content) { continue }
            $json = $resp.Content | ConvertFrom-Json
            foreach ($metric in @($json.value)) {
                foreach ($ts in @($metric.timeseries)) {
                    $points = @($ts.data) | Where-Object { $null -ne $_.average }
                    if ($points.Count -gt 0) { $totalBytes += [double]$points[-1].average }
                }
            }
        }
        catch { }
    }
    return [math]::Round($totalBytes / 1GB, 1)
}

function Get-UnitEconomics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions
    )

    Write-Host "  Computing unit economics (per vCPU, per GB RAM, per GB disk)..." -ForegroundColor Cyan

    $subIds = @($Subscriptions | ForEach-Object { $_.Id })

    # -- 1: Provisioned compute capacity (exact vCPU + RAM via Compute SKUs) --
    $totalVCpu = 0
    $totalMemGb = 0.0
    $vmCount = 0
    $vcpuExact = $true
    $skuCache = @{}
    try {
        $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize), loc = tostring(location), subId = tostring(subscriptionId)
| summarize cnt = count() by vmSize, loc, subId
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            $count = [int]$r.cnt
            $vmCount += $count
            $caps = Get-VmSizeCapability -SubId $r.subId -Location $r.loc -VmSize $r.vmSize -Cache $skuCache
            if ($caps -and $caps.VCpu -gt 0) {
                $totalVCpu += ($caps.VCpu * $count)
                $totalMemGb += ($caps.MemGb * $count)
            }
            else {
                # Fall back to the leading core digit in the size name.
                $vcpuExact = $false
                $cores = 1
                if ([string]$r.vmSize -match '(?i)[A-Z]+(\d+)') { $cores = [int]$matches[1] }
                if ($cores -lt 1) { $cores = 1 }
                $totalVCpu += ($cores * $count)
            }
        }
        Write-Host "    VMs: $vmCount  |  vCPUs: $totalVCpu  |  RAM: $([math]::Round($totalMemGb, 0)) GB" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  vCPU query failed: $($_.Exception.Message)"
    }

    # -- 2: Provisioned storage (managed disk GB) -------------------------
    $diskGb = 0
    try {
        $diskQuery = @"
resources
| where type =~ 'microsoft.compute/disks'
| summarize totalGb = sum(toint(properties.diskSizeGB))
"@
        $result = Search-AzGraphSafe -Query $diskQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        if ($rows.Count -gt 0 -and $null -ne $rows[0].totalGb) { $diskGb = [double]$rows[0].totalGb }
        Write-Host "    Provisioned disk: $diskGb GB" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Storage capacity query failed: $($_.Exception.Message)"
    }

    # -- 2b: Storage account used capacity (blob/file/queue/table) --------
    $blobFileGb = 0.0
    $blobFileOk = $false
    try {
        $used = Get-StorageAccountUsedGb -SubIds $subIds
        if ($null -ne $used) {
            $blobFileGb = [double]$used
            $blobFileOk = $true
            Write-Host "    Storage accounts used: $blobFileGb GB" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "  Storage account capacity query failed: $($_.Exception.Message)"
    }

    # Total storage denominator = managed disks + storage-account used capacity.
    $totalGb = $diskGb + $blobFileGb

    # -- 3: Amortized cost by meter category (sub-scoped, with fallback) --
    $computeCost = 0.0
    $storageCost = 0.0
    $currency = 'USD'
    $costOk = $false
    $costScope = 'none'
    $mgFailed = $false
    try {
        $mgScopeId = Resolve-CostMgId -TenantId $TenantId
        if ($mgScopeId) {
            $dataset = @{
                granularity = 'None'
                aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                grouping    = @(@{ type = 'Dimension'; name = 'MeterCategory' })
            }
            # Keep the single fast MG-scope call but scope it to the selected
            # subscriptions so the cost numerator matches the capacity denominator.
            $subFilter = Get-CostSubscriptionFilter -Subscriptions $Subscriptions
            if ($subFilter) { $dataset['filter'] = $subFilter }
            $body = @{
                type      = 'AmortizedCost'
                timeframe = 'MonthToDate'
                dataset   = $dataset
            } | ConvertTo-Json -Depth 10

            $path = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body

            if ($resp -and $resp.StatusCode -in @(401, 403)) {
                $mgFailed = $true
                Set-MgCostScopeFailed
            }
            elseif ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                if (Add-MeterCosts -Content $resp.Content -ComputeRef ([ref]$computeCost) -StorageRef ([ref]$storageCost) -CurrencyRef ([ref]$currency)) {
                    $costOk = $true
                    $costScope = "mg:$mgScopeId"
                }
            }
        }
        else {
            $mgFailed = $true
        }
    }
    catch {
        Write-Warning "  Amortized cost query failed: $($_.Exception.Message)"
        $mgFailed = $true
    }

    # Per-subscription fallback when the MG scope is not accessible. This is
    # the same pattern Get-CostData uses so unit economics is never silently $0.
    if (-not $costOk -and $mgFailed) {
        foreach ($sid in $subIds) {
            try {
                $body = @{
                    type      = 'AmortizedCost'
                    timeframe = 'MonthToDate'
                    dataset   = @{
                        granularity = 'None'
                        aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                        grouping    = @(@{ type = 'Dimension'; name = 'MeterCategory' })
                    }
                } | ConvertTo-Json -Depth 10

                $path = "/subscriptions/$sid/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body
                if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                    if (Add-MeterCosts -Content $resp.Content -ComputeRef ([ref]$computeCost) -StorageRef ([ref]$storageCost) -CurrencyRef ([ref]$currency)) {
                        $costOk = $true
                        $costScope = 'per-sub'
                    }
                }
            }
            catch {
                Write-Warning "  Per-sub cost query failed for $sid : $($_.Exception.Message)"
            }
        }
    }

    # -- 4: Derived KPIs --------------------------------------------------
    $costPerVCpu = if ($totalVCpu -gt 0) { [math]::Round($computeCost / $totalVCpu, 2) }  else { 0 }
    $costPerVm = if ($vmCount -gt 0) { [math]::Round($computeCost / $vmCount, 2) }    else { 0 }
    $costPerGb = if ($totalGb -gt 0) { [math]::Round($storageCost / $totalGb, 4) }    else { 0 }
    $costPerGbRam = if ($totalMemGb -gt 0) { [math]::Round($computeCost / $totalMemGb, 2) } else { 0 }

    $totalKnown = $computeCost + $storageCost
    $computeSharePct = if ($totalKnown -gt 0) { [math]::Round(100 * $computeCost / $totalKnown, 1) } else { 0 }
    $storageSharePct = if ($totalKnown -gt 0) { [math]::Round(100 * $storageCost / $totalKnown, 1) } else { 0 }

    $hasData = $costOk -and (($totalVCpu -gt 0) -or ($totalGb -gt 0))

    # -- 5: Honest diagnostics so $0 is explained, not silent -------------
    $notes = @()
    if (-not $costOk) {
        $notes += 'No cost data returned - check Cost Management Reader at the management-group or subscription scope.'
    }
    if ($costOk -and $computeCost -eq 0 -and $vmCount -gt 0) {
        $notes += 'VMs found but $0 compute MTD (newly created, deallocated, or fully reservation/savings-plan covered).'
    }
    if ($totalGb -eq 0 -and $vmCount -gt 0) {
        $notes += 'No storage GB found - VMs may use ephemeral OS disks and no Storage accounts hold data.'
    }
    if (-not $blobFileOk) {
        $notes += 'Storage-account used capacity unavailable (metrics not readable) - cost per GB reflects managed disks only.'
    }
    if (-not $vcpuExact) {
        $notes += 'Some vCPU/RAM values approximated from VM size names (SKU capability lookup unavailable for a region).'
    }
    if ($notes.Count -eq 0) {
        $notes += 'vCPU/RAM are exact (Compute SKU capabilities); storage GB combines managed disks and Storage-account used capacity.'
    }

    return [PSCustomObject]@{
        HasData         = $hasData
        Currency        = $currency
        ComputeCost     = [math]::Round($computeCost, 2)
        StorageCost     = [math]::Round($storageCost, 2)
        ComputeSharePct = $computeSharePct
        StorageSharePct = $storageSharePct
        VmCount         = $vmCount
        TotalVCpu       = $totalVCpu
        TotalMemoryGb   = [math]::Round($totalMemGb, 0)
        DiskGb          = [math]::Round($diskGb, 1)
        BlobFileGb      = [math]::Round($blobFileGb, 1)
        TotalStorageGb  = [math]::Round($totalGb, 1)
        CostPerVCpu     = $costPerVCpu
        CostPerGbRam    = $costPerGbRam
        CostPerVm       = $costPerVm
        CostPerGb       = $costPerGb
        VCpuExact       = $vcpuExact
        BlobFileOk      = $blobFileOk
        CostScope       = $costScope
        Period          = 'MonthToDate'
        ScannedSubs     = $Subscriptions.Count
        Note            = ($notes -join ' ')
    }
}
