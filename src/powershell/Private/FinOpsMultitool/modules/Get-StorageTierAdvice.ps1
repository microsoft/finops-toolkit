# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
param()

###########################################################################
# GET-STORAGETIERADVICE.PS1
# AZURE FINOPS MULTITOOL - Storage Tier Optimization
###########################################################################
# Purpose: Identify storage accounts with hot-tier blob containers that
#          have not been accessed recently and would benefit from moving
#          to Cool or Archive tier to reduce costs.
###########################################################################

function Get-StorageTierAdvice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    Write-Host "  Scanning storage tier optimization opportunities..." -ForegroundColor Cyan

    $subIds = $Subscriptions | ForEach-Object { $_.Id }
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $metricFailures = [System.Collections.Generic.List[string]]::new()

    # -- 1: Find all storage accounts on Hot default tier -----------------
    try {
        $query = @"
resources
| where type =~ 'microsoft.storage/storageaccounts'
| where properties.accessTier =~ 'Hot' or isnull(properties.accessTier)
| project id, name, resourceGroup, subscriptionId, location,
          kind, sku = sku.name,
          accessTier = tostring(properties.accessTier),
          creationTime = properties.creationTime,
          blobCount = properties.primaryEndpoints.blob
"@
        $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000 -All
        $hotAccounts = if ($result) { @($result.Data) } else { @() }
        Write-Host "    Hot-tier storage accounts: $($hotAccounts.Count)" -ForegroundColor Gray
    }
    catch {
        throw "Storage account inventory is incomplete: $($_.Exception.Message)"
    }

    # -- 2: For each hot account, check last access metrics ---------------
    $armBase = Get-FinOpsArmEndpoint
    $token = Get-PlainAccessToken -ResourceUrl $armBase
    $headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }
    $now = (Get-Date).ToUniversalTime()
    $thirtyDaysAgo = $now.AddDays(-30).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $nowStr = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')

    foreach ($sa in $hotAccounts) {
        $scope = "/subscriptions/$($sa.subscriptionId)/resourceGroups/$($sa.resourceGroup)/providers/Microsoft.Storage/storageAccounts/$($sa.name)"
        try {
            # Query transaction count (Blob service) over last 30 days
            # FULL is the only way to get one datapoint for the whole span:
            # P30D is not a published timegrain and the API rejects it.
            $metricUri = "$armBase$scope/blobServices/default/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=Transactions&timespan=$thirtyDaysAgo/$nowStr&aggregation=Total&interval=FULL"
            $resp = Invoke-WebRequest -Uri $metricUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
            $metricData = ($resp.Content | ConvertFrom-Json)

            $totalTx = 0.0
            $transactionSamples = 0
            if ($metricData.value -and $metricData.value.Count -gt 0) {
                foreach ($ts in $metricData.value[0].timeseries) {
                    foreach ($dp in $ts.data) {
                        $value = Get-HubCostValue -Row $dp -Column 'total'
                        if ($value -lt 0) { throw 'Transactions contain a negative measurement.' }
                        $totalTx += $value
                        $transactionSamples++
                    }
                }
            }
            if ($transactionSamples -eq 0) { throw 'No transaction measurements were returned for the requested period.' }

            # Also query used capacity. Every recommendation below requires a
            # capacity reading, so a silent failure here would suppress the
            # recommendation instead of reporting the account as unevaluated.
            $capacityUri = "$armBase$scope/blobServices/default/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=BlobCapacity&timespan=$thirtyDaysAgo/$nowStr&aggregation=Average&interval=FULL"
            $capResp = Invoke-WebRequest -Uri $capacityUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
            $capacityBytes = 0.0
            $capacitySamples = 0
            if ($capResp) {
                $capData = ($capResp.Content | ConvertFrom-Json)
                if ($capData.value -and $capData.value.Count -gt 0) {
                    foreach ($ts in $capData.value[0].timeseries) {
                        foreach ($dp in $ts.data) {
                            $value = Get-HubCostValue -Row $dp -Column 'average'
                            if ($value -lt 0) { throw 'Capacity contains a negative measurement.' }
                            if ($value -gt $capacityBytes) { $capacityBytes = $value }
                            $capacitySamples++
                        }
                    }
                }
            }
            if ($capacitySamples -eq 0) { throw 'No capacity measurements were returned for the requested period.' }

            $capacityGB = [math]::Round($capacityBytes / 1GB, 2)
            $recommendation = $null
            $estSavingsPct = 0

            if ($totalTx -eq 0 -and $capacityGB -gt 0) {
                $recommendation = 'Archive'
                $estSavingsPct = 90
            }
            elseif ($totalTx -lt 100 -and $capacityGB -gt 0) {
                $recommendation = 'Archive'
                $estSavingsPct = 90
            }
            elseif ($totalTx -lt 1000 -and $capacityGB -gt 1) {
                $recommendation = 'Cool'
                $estSavingsPct = 50
            }

            if ($recommendation) {
                [void]$results.Add([PSCustomObject]@{
                        StorageAccount  = $sa.name
                        ResourceGroup   = $sa.resourceGroup
                        SubscriptionId  = $sa.subscriptionId
                        Location        = $sa.location
                        CurrentTier     = if ($sa.accessTier) { $sa.accessTier } else { 'Hot (default)' }
                        SKU             = $sa.sku
                        CapacityGB      = $capacityGB
                        Transactions30d = $totalTx
                        Recommendation  = $recommendation
                        EstSavingsPct   = $estSavingsPct
                    })
            }
        }
        catch {
            # A classic account with no blob service is expected; a throttled or
            # unauthorized call is not. Count both rather than reporting neither.
            [void]$metricFailures.Add("$($sa.name): $($_.Exception.Message)")
        }
    }

    if ($metricFailures.Count -gt 0) {
        Write-Warning "    Metrics unavailable for $($metricFailures.Count) of $($hotAccounts.Count) storage account(s); those accounts were not evaluated."
        foreach ($f in ($metricFailures | Select-Object -First 3)) { Write-Verbose "      $f" }
    }

    Write-Host "    Storage tier recommendations: $($results.Count)" -ForegroundColor Gray

    [PSCustomObject]@{
        Recommendations     = @($results)
        TotalHotAccounts    = $hotAccounts.Count
        Count               = $results.Count
        HasData             = ($results.Count -gt 0)
        # Evaluated excludes accounts whose metrics could not be read.
        EvaluatedAccounts   = ($hotAccounts.Count - $metricFailures.Count)
        MetricFailures      = $metricFailures.Count
        MetricFailureDetail = @($metricFailures)
    }
}
