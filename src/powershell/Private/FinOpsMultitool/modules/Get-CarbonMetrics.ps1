###########################################################################
# GET-CARBONMETRICS.PS1
# AZURE FINOPS MULTITOOL - Carbon Emissions (Sustainability)
###########################################################################
# Purpose: Query the Azure Carbon Optimization service for greenhouse-gas
#          emissions (kgCO2e) across subscriptions: latest-month total,
#          month-over-month change, and a monthly trend. Supports FinOps
#          sustainability KPIs (carbon footprint, emissions trend).
###########################################################################
# Notes:
# - Endpoint: POST /providers/Microsoft.Carbon/carbonEmissionReports
#   (tenant scope), api-version 2025-04-01. subscriptionList goes in the
#   body (max 100 per call, lowercase ids) so we batch in chunks of 100.
# - Emissions data lags ~2 months and is only available for months that
#   have been published. We probe recent month windows and walk back
#   until the service returns data, then degrade gracefully if none.
# - RBAC: Reader (or Carbon Optimization Reader) on each subscription.
###########################################################################

function Get-CarbonMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $apiVersion = '2025-04-01'
    $carbonPath = "/providers/Microsoft.Carbon/carbonEmissionReports?api-version=$apiVersion"
    $scopeList  = @('Scope1', 'Scope2', 'Scope3')

    $subCount = $Subscriptions.Count
    Write-Host "  Querying carbon emissions ($subCount subs)..." -ForegroundColor Cyan

    # All subscription ids, lowercased, batched into <=100 per request.
    $allIds = @($Subscriptions | ForEach-Object { ([string]$_.Id).ToLower() })
    $batches = [System.Collections.Generic.List[object]]::new()
    for ($b = 0; $b -lt $allIds.Count; $b += 100) {
        $end = [math]::Min($b + 99, $allIds.Count - 1)
        [void]$batches.Add(@($allIds[$b..$end]))
    }

    # -- Resolve an available emissions window ----------------------------
    # Carbon data publishes ~2 months in arrears. Probe candidate "latest"
    # months (current-1 .. current-4, first of month) using the first
    # subscription batch; the first window that returns data is reused for
    # every batch. Returns $null when no recent window has data.
    $firstOfMonth = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    $window = $null
    foreach ($lag in 1..4) {
        $endMonth   = $firstOfMonth.AddMonths(-$lag)
        $startMonth = $endMonth.AddMonths(-11)
        $probeBody  = @{
            reportType       = 'OverallSummaryReport'
            subscriptionList = $batches[0]
            carbonScopeList  = $scopeList
            dateRange        = @{
                start = $startMonth.ToString('yyyy-MM-dd')
                end   = $endMonth.ToString('yyyy-MM-dd')
            }
        } | ConvertTo-Json -Depth 6

        try {
            $probe = Invoke-AzRestMethodWithRetry -Path $carbonPath -Method POST -Payload $probeBody
        }
        catch {
            $probe = $null
        }

        if ($probe -and $probe.StatusCode -eq 200) {
            $window = @{ Start = $startMonth; End = $endMonth }
            break
        }

        # 404/400 here usually means "no data for that window" or the
        # provider isn't registered/available - try an earlier window.
    }

    if (-not $window) {
        Write-Host "    No carbon emissions data available (provider unavailable or no published months)." -ForegroundColor DarkGray
        return [PSCustomObject]@{
            HasData            = $false
            TotalEmissionsKg   = 0
            PreviousMonthKg    = 0
            ChangeRatio        = 0
            ChangeValueKg      = 0
            LatestMonth        = $null
            MonthlyTrend       = @()
            BySubscription     = @()
            Unit               = 'kgCO2e'
            ScannedSubs        = $subCount
            Note               = 'Carbon Optimization returned no data. Requires Reader on subscriptions; emissions publish ~2 months in arrears.'
        }
    }

    $startStr = $window.Start.ToString('yyyy-MM-dd')
    $endStr   = $window.End.ToString('yyyy-MM-dd')

    $totalLatest   = 0.0
    $totalPrevious = 0.0
    $monthlyTotals = @{}   # key 'yyyy-MM' -> kgCO2e
    $bySub         = [System.Collections.Generic.List[PSCustomObject]]::new()

    $batchNo = 0
    foreach ($batch in $batches) {
        $batchNo++
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus "Querying carbon emissions (batch $batchNo/$($batches.Count))..."
        }

        # -- Overall summary (headline latest + previous month) -----------
        $overallBody = @{
            reportType       = 'OverallSummaryReport'
            subscriptionList = $batch
            carbonScopeList  = $scopeList
            dateRange        = @{ start = $startStr; end = $endStr }
        } | ConvertTo-Json -Depth 6

        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $carbonPath -Method POST -Payload $overallBody
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                foreach ($row in @($data.value)) {
                    $latest   = if ($null -ne $row.latestMonthEmissions)   { [double]$row.latestMonthEmissions }   else { 0 }
                    $previous = if ($null -ne $row.previousMonthEmissions) { [double]$row.previousMonthEmissions } else { 0 }
                    $totalLatest   += $latest
                    $totalPrevious += $previous
                }
            }
        }
        catch {
            Write-Warning "  Carbon overall query failed (batch $batchNo): $($_.Exception.Message)"
        }

        # -- Per-subscription summary (ItemDetails by subscription) -------
        $itemBody = @{
            reportType       = 'ItemDetailsReport'
            subscriptionList = $batch
            carbonScopeList  = $scopeList
            categoryType     = 'Subscription'
            orderBy          = 'LatestMonthEmissions'
            sortDirection    = 'Desc'
            pageSize         = 100
            dateRange        = @{ start = $endStr; end = $endStr }
        } | ConvertTo-Json -Depth 6

        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $carbonPath -Method POST -Payload $itemBody
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                foreach ($row in @($data.value)) {
                    $subId   = if ($row.itemName) { [string]$row.itemName } else { '' }
                    $subObj  = $Subscriptions | Where-Object { ([string]$_.Id).ToLower() -eq $subId.ToLower() } | Select-Object -First 1
                    $latest  = if ($null -ne $row.latestMonthEmissions) { [double]$row.latestMonthEmissions } else { 0 }
                    [void]$bySub.Add([PSCustomObject]@{
                        Subscription   = if ($subObj) { $subObj.Name } else { $subId }
                        SubscriptionId = $subId
                        EmissionsKg    = [math]::Round($latest, 3)
                    })
                }
            }
        }
        catch {
            Write-Warning "  Carbon per-subscription query failed (batch $batchNo): $($_.Exception.Message)"
        }

        # -- Monthly trend (12-month series) ------------------------------
        $monthlyBody = @{
            reportType       = 'MonthlySummaryReport'
            subscriptionList = $batch
            carbonScopeList  = $scopeList
            dateRange        = @{ start = $startStr; end = $endStr }
        } | ConvertTo-Json -Depth 6

        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $carbonPath -Method POST -Payload $monthlyBody
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                foreach ($row in @($data.value)) {
                    $month = ''
                    if ($row.date)      { try { $month = ([datetime]$row.date).ToString('yyyy-MM') } catch { $month = [string]$row.date } }
                    elseif ($row.month) { $month = [string]$row.month }
                    if (-not $month) { continue }
                    $val = if ($null -ne $row.totalCarbonEmission) { [double]$row.totalCarbonEmission }
                           elseif ($null -ne $row.carbonEmission)  { [double]$row.carbonEmission }
                           elseif ($null -ne $row.latestMonthEmissions) { [double]$row.latestMonthEmissions }
                           else { 0 }
                    if (-not $monthlyTotals.ContainsKey($month)) { $monthlyTotals[$month] = 0.0 }
                    $monthlyTotals[$month] += $val
                }
            }
        }
        catch {
            Write-Warning "  Carbon monthly query failed (batch $batchNo): $($_.Exception.Message)"
        }
    }

    $trend = @(
        $monthlyTotals.Keys | Sort-Object | ForEach-Object {
            [PSCustomObject]@{ Month = $_; EmissionsKg = [math]::Round($monthlyTotals[$_], 3) }
        }
    )

    $changeValue = $totalLatest - $totalPrevious
    $changeRatio = if ($totalPrevious -ne 0) { [math]::Round(($changeValue / $totalPrevious) * 100, 1) } else { 0 }

    $hasData = ($totalLatest -gt 0) -or ($trend.Count -gt 0) -or ($bySub.Count -gt 0)

    return [PSCustomObject]@{
        HasData          = $hasData
        TotalEmissionsKg = [math]::Round($totalLatest, 3)
        PreviousMonthKg  = [math]::Round($totalPrevious, 3)
        ChangeValueKg    = [math]::Round($changeValue, 3)
        ChangeRatio      = $changeRatio
        LatestMonth      = $window.End.ToString('yyyy-MM')
        MonthlyTrend     = $trend
        BySubscription   = @($bySub | Sort-Object EmissionsKg -Descending)
        Unit             = 'kgCO2e'
        ScannedSubs      = $subCount
        Note             = if ($hasData) { $null } else { 'No emissions returned for the available window.' }
    }
}
