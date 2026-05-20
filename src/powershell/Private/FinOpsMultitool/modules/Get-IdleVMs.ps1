###########################################################################
# GET-IDLEVMS.PS1
# AZURE FINOPS MULTITOOL - Idle & Underutilized VM Detection
###########################################################################
# Purpose: Query Azure Monitor metrics to find running VMs with very low
#          CPU and network utilization that Advisor hasn't flagged yet.
#          These are candidates for downsizing or shutting down.
###########################################################################

function Get-IdleVMs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    Write-Host "  Scanning for idle and underutilized VMs..." -ForegroundColor Cyan

    $subIds = $Subscriptions | ForEach-Object { $_.Id }
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -- 1: Find all running VMs ------------------------------------------
    try {
        $query = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend powerState = tostring(properties.extended.instanceView.powerState.code)
| where powerState =~ 'PowerState/running'
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          osType = properties.storageProfile.osDisk.osType,
          powerState
"@
        $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000
        $runningVMs = if ($result) { @($result.Data) } else { @() }
        Write-Host "    Running VMs found: $($runningVMs.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Running VM query failed: $($_.Exception.Message)"
        $runningVMs = @()
    }

    if ($runningVMs.Count -eq 0) {
        return [PSCustomObject]@{
            IdleVMs    = @()
            Count      = 0
            HasData    = $false
            ScannedVMs = 0
        }
    }

    # -- 2: Query 14-day avg CPU + Network for each VM -------------------
    $token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token
    $headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }
    $now = (Get-Date).ToUniversalTime()
    $fourteenDaysAgo = $now.AddDays(-14).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $nowStr = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')

    $cpuThreshold     = 5    # avg CPU < 5% = idle
    $networkThreshold = 1048576  # < 1 MB/day total network = idle (14d * 1MB = 14MB)
    $networkThreshold14d = $networkThreshold * 14

    $vmCount = $runningVMs.Count
    $vmIdx = 0
    foreach ($vm in $runningVMs) {
        $vmIdx++
        if ($vmCount -gt 10 -and ($vmIdx -eq 1 -or $vmIdx % [math]::Max(1, [int]($vmCount / 10)) -eq 0)) {
            if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                Update-ScanStatus "Checking VM metrics ($vmIdx/$vmCount VMs)..."
            }
        }
        $scope = "/subscriptions/$($vm.subscriptionId)/resourceGroups/$($vm.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.name)"
        try {
            # Query CPU + Network In + Network Out in a single call
            $metricUri = "https://management.azure.com$scope/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=Percentage CPU,Network In Total,Network Out Total&timespan=$fourteenDaysAgo/$nowStr&aggregation=Average,Total&interval=P14D"
            $resp = Invoke-WebRequest -Uri $metricUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $metricData = ($resp.Content | ConvertFrom-Json)

            $avgCpu = $null
            $totalNetIn = 0
            $totalNetOut = 0

            foreach ($metric in $metricData.value) {
                $metricName = $metric.name.value
                foreach ($ts in $metric.timeseries) {
                    foreach ($dp in $ts.data) {
                        switch ($metricName) {
                            'Percentage CPU' {
                                if ($dp.average -ne $null) { $avgCpu = $dp.average }
                            }
                            'Network In Total' {
                                if ($dp.total) { $totalNetIn += $dp.total }
                            }
                            'Network Out Total' {
                                if ($dp.total) { $totalNetOut += $dp.total }
                            }
                        }
                    }
                }
            }

            $totalNetwork = $totalNetIn + $totalNetOut

            # Classify: idle if CPU < threshold AND network < threshold
            $isIdle = $false
            $classification = $null

            if ($avgCpu -ne $null -and $avgCpu -lt $cpuThreshold -and $totalNetwork -lt $networkThreshold14d) {
                $isIdle = $true
                $classification = 'Idle'
            } elseif ($avgCpu -ne $null -and $avgCpu -lt 10 -and $totalNetwork -lt ($networkThreshold14d * 10)) {
                $isIdle = $true
                $classification = 'Underutilized'
            }

            if ($isIdle) {
                $dailyNetMB = [math]::Round($totalNetwork / 14 / 1MB, 2)
                [void]$results.Add([PSCustomObject]@{
                    VMName         = $vm.name
                    ResourceGroup  = $vm.resourceGroup
                    SubscriptionId = $vm.subscriptionId
                    Location       = $vm.location
                    VMSize         = $vm.vmSize
                    OS             = $vm.osType
                    AvgCPU14d      = [math]::Round($avgCpu, 1)
                    NetworkPerDay  = "$($dailyNetMB) MB"
                    Classification = $classification
                    Recommendation = if ($classification -eq 'Idle') { 'Deallocate or delete' } else { 'Downsize VM' }
                })
            }
        } catch {
            # Metrics not available — skip this VM
        }
    }

    Write-Host "    Idle/underutilized VMs: $($results.Count)" -ForegroundColor Gray

    [PSCustomObject]@{
        IdleVMs    = @($results)
        Count      = $results.Count
        HasData    = ($results.Count -gt 0)
        ScannedVMs = $runningVMs.Count
    }
}
