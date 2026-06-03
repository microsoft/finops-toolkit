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
# - vCPU counts are approximated from the VM size name (the leading core
#   digit, accurate for current D/E/F/B families); unknown sizes count as
#   the VM only. Storage GB is the sum of provisioned managed-disk size.
# - Costs are month-to-date amortized, grouped by meter category.
###########################################################################

function Get-UnitEconomics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions
    )

    Write-Host "  Computing unit economics (\$/vCPU, \$/GB)..." -ForegroundColor Cyan

    $subIds = @($Subscriptions | ForEach-Object { $_.Id })

    # -- 1: Provisioned vCPUs (from VM sizes) -----------------------------
    $totalVCpu = 0
    $vmCount   = 0
    try {
        $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| summarize count() by vmSize
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            $count = [int]$r.count_
            $vmCount += $count
            # Leading core digit after the family letters (Standard_D4s_v5 -> 4).
            $cores = 1
            if ([string]$r.vmSize -match '(?i)[A-Z]+(\d+)') { $cores = [int]$matches[1] }
            if ($cores -lt 1) { $cores = 1 }
            $totalVCpu += ($cores * $count)
        }
        Write-Host "    VMs: $vmCount  |  approx vCPUs: $totalVCpu" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  vCPU query failed: $($_.Exception.Message)"
    }

    # -- 2: Provisioned storage (managed disk GB) -------------------------
    $totalGb = 0
    try {
        $diskQuery = @"
resources
| where type =~ 'microsoft.compute/disks'
| summarize totalGb = sum(toint(properties.diskSizeGB))
"@
        $result = Search-AzGraphSafe -Query $diskQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        if ($rows.Count -gt 0 -and $null -ne $rows[0].totalGb) { $totalGb = [double]$rows[0].totalGb }
        Write-Host "    Provisioned disk: $totalGb GB" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Storage capacity query failed: $($_.Exception.Message)"
    }

    # -- 3: Amortized cost by meter category ------------------------------
    $computeCost = 0.0
    $storageCost = 0.0
    $currency    = 'USD'
    $costOk      = $false
    try {
        $mgScopeId = Resolve-CostMgId -TenantId $TenantId
        if ($mgScopeId) {
            $body = @{
                type      = 'AmortizedCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping    = @(@{ type = 'Dimension'; name = 'MeterCategory' })
                }
            } | ConvertTo-Json -Depth 10

            $path = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body

            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                if ($data.properties.rows) {
                    $costOk = $true
                    foreach ($row in $data.properties.rows) {
                        $amount   = [double]$row[0]
                        $category = [string]$row[1]
                        if ($row.Count -ge 3 -and $row[2]) { $currency = [string]$row[2] }
                        switch -Wildcard ($category) {
                            'Virtual Machines*' { $computeCost += $amount }
                            'Storage'           { $storageCost += $amount }
                            default { }
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "  Amortized cost query failed: $($_.Exception.Message)"
    }

    $costPerVCpu = if ($totalVCpu -gt 0) { [math]::Round($computeCost / $totalVCpu, 2) } else { 0 }
    $costPerVm   = if ($vmCount   -gt 0) { [math]::Round($computeCost / $vmCount, 2) }   else { 0 }
    $costPerGb   = if ($totalGb   -gt 0) { [math]::Round($storageCost / $totalGb, 4) }   else { 0 }

    $hasData = $costOk -and (($totalVCpu -gt 0) -or ($totalGb -gt 0))

    return [PSCustomObject]@{
        HasData       = $hasData
        Currency      = $currency
        ComputeCost   = [math]::Round($computeCost, 2)
        StorageCost   = [math]::Round($storageCost, 2)
        VmCount       = $vmCount
        TotalVCpu     = $totalVCpu
        TotalStorageGb = [math]::Round($totalGb, 1)
        CostPerVCpu   = $costPerVCpu
        CostPerVm     = $costPerVm
        CostPerGb     = $costPerGb
        Period        = 'MonthToDate'
        ScannedSubs   = $Subscriptions.Count
        Note          = if ($hasData) { 'vCPU counts are approximate (derived from VM size names).' } else { 'Insufficient cost or capacity data to compute unit economics.' }
    }
}
