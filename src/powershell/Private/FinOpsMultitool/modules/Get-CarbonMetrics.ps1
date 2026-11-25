# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
param()

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
    $scopeList = @('Scope1', 'Scope2', 'Scope3')

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
    $probeErrors = [Collections.Generic.List[string]]::new()
    foreach ($lag in 1..4) {
        $endMonth = $firstOfMonth.AddMonths(-$lag)
        $startMonth = $endMonth.AddMonths(-11)
        $probeBody = @{
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
            $probeErrors.Add($_.Exception.Message)
            $probe = $null
        }

        if ($probe -and $probe.StatusCode -eq 200) {
            # A 200 with an empty value array means the window published no data.
            # Accepting it would lock onto an empty month and never try older ones.
            $probeRows = 0
            try {
                $values = ($probe.Content | ConvertFrom-Json -ErrorAction Stop).value
                if ($values -isnot [array]) { throw 'Carbon probe returned an invalid result collection.' }
                $probeRows = $values.Count
            }
            catch { $probeRows = 0; $probeErrors.Add($_.Exception.Message) }
            if ($probeRows -gt 0) {
                $window = @{ Start = $startMonth; End = $endMonth }
                break
            }
        }
        elseif ($probe -and $probe.StatusCode -notin @(400, 404)) {
            $probeErrors.Add("Carbon window probe returned HTTP $($probe.StatusCode).")
            if ($probe.StatusCode -in @(401, 403)) { break }
        }

        # 404/400 here usually means "no data for that window" or the
        # provider isn't registered/available - try an earlier window.
    }

    if (-not $window) {
        Write-Host "    No carbon emissions data available (provider unavailable or no published months)." -ForegroundColor DarkGray
        return [PSCustomObject]@{
            HasData            = $false
            TotalEmissionsKg   = $null
            PreviousMonthKg    = $null
            ChangeRatio        = $null
            ChangeValueKg      = $null
            CoverageIncomplete = ($probeErrors.Count -gt 0)
            ReadErrors         = @($probeErrors)
            LatestMonth        = $null
            MonthlyTrend       = @()
            BySubscription     = @()
            Unit               = 'kgCO2e'
            ScannedSubs        = $subCount
            Note               = if ($probeErrors.Count -gt 0) { 'Carbon discovery is incomplete. ' + ($probeErrors -join ' ') } else { 'No measurements were returned for the queried windows; this is not a measured zero. Carbon data publishes with a delay.' }
        }
    }

    $startStr = $window.Start.ToString('yyyy-MM-dd')
    $endStr = $window.End.ToString('yyyy-MM-dd')

    $totalLatest = 0.0
    $totalPrevious = 0.0
    $monthlyTotals = @{}   # key 'yyyy-MM' -> kgCO2e
    $bySub = [System.Collections.Generic.List[PSCustomObject]]::new()
    $readErrors = [Collections.Generic.List[string]]::new()
    foreach ($probeError in $probeErrors) { $readErrors.Add($probeError) }
    $headlineComplete = $true
    $headlineRows = 0

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
            if (-not $resp -or $resp.StatusCode -ne 200) { throw "Overall carbon report returned HTTP $($resp.StatusCode)." }
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                if ($data.value -isnot [array] -or $data.value.Count -eq 0) { throw 'Overall carbon report has no measured values.' }
                foreach ($row in @($data.value)) {
                    $latest = Get-HubCostValue -Row $row -Column 'latestMonthEmissions'
                    $previous = Get-HubCostValue -Row $row -Column 'previousMonthEmissions'
                    $totalLatest += $latest
                    $totalPrevious += $previous
                    $headlineRows++
                }
            }
            else { throw 'Overall carbon report returned no content.' }
        }
        catch {
            $headlineComplete = $false
            $readErrors.Add("Overall batch $batchNo : $($_.Exception.Message)")
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
            if (-not $resp -or $resp.StatusCode -ne 200) { throw "Per-subscription carbon report returned HTTP $($resp.StatusCode)." }
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                if ($data.value -isnot [array]) { throw 'Per-subscription carbon report returned an invalid collection.' }
                foreach ($row in @($data.value)) {
                    $subId = if ($row.itemName) { [string]$row.itemName } else { '' }
                    $subObj = $Subscriptions | Where-Object { ([string]$_.Id).ToLower() -eq $subId.ToLower() } | Select-Object -First 1
                    $latest = Get-HubCostValue -Row $row -Column 'latestMonthEmissions'
                    [void]$bySub.Add([PSCustomObject]@{
                            Subscription   = if ($subObj) { $subObj.Name } else { $subId }
                            SubscriptionId = $subId
                            EmissionsKg    = [math]::Round($latest, 3)
                        })
                }
            }
            else { throw 'Per-subscription carbon report returned no content.' }
        }
        catch {
            $readErrors.Add("Subscription batch $batchNo : $($_.Exception.Message)")
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
            if (-not $resp -or $resp.StatusCode -ne 200) { throw "Monthly carbon report returned HTTP $($resp.StatusCode)." }
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                if ($data.value -isnot [array]) { throw 'Monthly carbon report returned an invalid collection.' }
                foreach ($row in @($data.value)) {
                    $month = ''
                    if ($row.date) { try { $month = ([datetime]$row.date).ToString('yyyy-MM') } catch { $month = [string]$row.date } }
                    elseif ($row.month) { $month = [string]$row.month }
                    if (-not $month) { continue }
                    $column = if ($null -ne $row.totalCarbonEmission) { 'totalCarbonEmission' }
                    elseif ($null -ne $row.carbonEmission) { 'carbonEmission' } else { 'latestMonthEmissions' }
                    $val = Get-HubCostValue -Row $row -Column $column
                    if (-not $monthlyTotals.ContainsKey($month)) { $monthlyTotals[$month] = 0.0 }
                    $monthlyTotals[$month] += $val
                }
            }
            else { throw 'Monthly carbon report returned no content.' }
        }
        catch {
            $readErrors.Add("Monthly batch $batchNo : $($_.Exception.Message)")
            Write-Warning "  Carbon monthly query failed (batch $batchNo): $($_.Exception.Message)"
        }
    }

    $trend = @(
        $monthlyTotals.Keys | Sort-Object | ForEach-Object {
            [PSCustomObject]@{ Month = $_; EmissionsKg = [math]::Round($monthlyTotals[$_], 3) }
        }
    )

    $headlineAvailable = $headlineComplete -and $headlineRows -gt 0
    $changeValue = if ($headlineAvailable) { $totalLatest - $totalPrevious } else { $null }
    $changeRatio = if ($headlineAvailable -and $totalPrevious -gt 0) { [math]::Round(($changeValue / $totalPrevious) * 100, 1) } else { $null }

    $hasData = $headlineAvailable -or ($trend.Count -gt 0) -or ($bySub.Count -gt 0)

    return [PSCustomObject]@{
        HasData            = $hasData
        TotalEmissionsKg   = if ($headlineAvailable) { [math]::Round($totalLatest, 3) } else { $null }
        PreviousMonthKg    = if ($headlineAvailable) { [math]::Round($totalPrevious, 3) } else { $null }
        ChangeValueKg      = if ($headlineAvailable) { [math]::Round($changeValue, 3) } else { $null }
        ChangeRatio        = $changeRatio
        CoverageIncomplete = ($readErrors.Count -gt 0)
        ReadErrors         = @($readErrors)
        LatestMonth        = $window.End.ToString('yyyy-MM')
        MonthlyTrend       = $trend
        BySubscription     = @($bySub | Sort-Object EmissionsKg -Descending)
        Unit               = 'kgCO2e'
        ScannedSubs        = $subCount
        Note               = if ($readErrors.Count -gt 0) { 'Carbon report coverage is incomplete. ' + ($readErrors -join ' ') }
        elseif ($headlineAvailable -and $totalPrevious -le 0) { 'A month-over-month percentage requires a positive previous-month measurement.' }
        elseif ($hasData) { $null } else { 'No emissions returned for the available window.' }
    }
}
