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

    # -- 1: Find all storage accounts on Hot default tier -----------------
    try {
        $query = @"
resources
| where type =~ 'microsoft.storage/storageaccounts'
| where properties.accessTier =~ 'Hot' or isnull(properties.accessTier)
| project name, resourceGroup, subscriptionId, location,
          kind, sku = sku.name,
          accessTier = tostring(properties.accessTier),
          creationTime = properties.creationTime,
          blobCount = properties.primaryEndpoints.blob
"@
        $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000
        $hotAccounts = if ($result) { @($result.Data) } else { @() }
        Write-Host "    Hot-tier storage accounts: $($hotAccounts.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Storage account query failed: $($_.Exception.Message)"
        $hotAccounts = @()
    }

    # -- 2: For each hot account, check last access metrics ---------------
    $token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token
    $headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }
    $now = (Get-Date).ToUniversalTime()
    $thirtyDaysAgo = $now.AddDays(-30).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $nowStr = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')

    foreach ($sa in $hotAccounts) {
        $scope = "/subscriptions/$($sa.subscriptionId)/resourceGroups/$($sa.resourceGroup)/providers/Microsoft.Storage/storageAccounts/$($sa.name)"
        try {
            # Query transaction count (Blob service) over last 30 days
            $metricUri = "https://management.azure.com$scope/blobServices/default/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=Transactions&timespan=$thirtyDaysAgo/$nowStr&aggregation=Total&interval=P30D"
            $resp = Invoke-WebRequest -Uri $metricUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $metricData = ($resp.Content | ConvertFrom-Json)

            $totalTx = 0
            if ($metricData.value -and $metricData.value.Count -gt 0) {
                foreach ($ts in $metricData.value[0].timeseries) {
                    foreach ($dp in $ts.data) {
                        if ($dp.total) { $totalTx += $dp.total }
                    }
                }
            }

            # Also query used capacity
            $capacityUri = "https://management.azure.com$scope/blobServices/default/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=BlobCapacity&timespan=$thirtyDaysAgo/$nowStr&aggregation=Average&interval=P30D"
            $capResp = Invoke-WebRequest -Uri $capacityUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
            $capacityBytes = 0
            if ($capResp) {
                $capData = ($capResp.Content | ConvertFrom-Json)
                if ($capData.value -and $capData.value.Count -gt 0) {
                    foreach ($ts in $capData.value[0].timeseries) {
                        foreach ($dp in $ts.data) {
                            if ($dp.average -and $dp.average -gt $capacityBytes) { $capacityBytes = $dp.average }
                        }
                    }
                }
            }

            $capacityGB = [math]::Round($capacityBytes / 1GB, 2)
            $recommendation = $null
            $estSavingsPct = 0

            if ($totalTx -eq 0 -and $capacityGB -gt 0) {
                $recommendation = 'Archive'
                $estSavingsPct = 90
            } elseif ($totalTx -lt 100 -and $capacityGB -gt 0) {
                $recommendation = 'Archive'
                $estSavingsPct = 90
            } elseif ($totalTx -lt 1000 -and $capacityGB -gt 1) {
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
        } catch {
            # Metrics not available (classic account, no blob service, etc.) — skip
        }
    }

    Write-Host "    Storage tier recommendations: $($results.Count)" -ForegroundColor Gray

    [PSCustomObject]@{
        Recommendations = @($results)
        TotalHotAccounts = $hotAccounts.Count
        Count           = $results.Count
        HasData         = ($results.Count -gt 0)
    }
}
