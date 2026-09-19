# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
param()

###########################################################################
# GET-COSTDATA.PS1
# AZURE FINOPS MULTITOOL - Current & Forecasted Cost Data
###########################################################################
# Purpose: Query Cost Management API at the management-group scope to
#          retrieve actual month-to-date spend and forecasted spend for
#          every subscription in a single efficient call.
#
# Approach: MG-scope queries avoid N per-subscription calls. We group
#           results by SubscriptionId so costs roll up correctly.
#
# Reference: https://learn.microsoft.com/en-us/rest/api/cost-management/query/usage
###########################################################################

# Matches column names exactly. A substring match lands on 'CostStatus', whose
# value is the text 'Actual' or 'Forecast', and casting that to a number throws.
function Get-CostColumnIndex {
    param($Columns, [string[]]$Names)

    if (-not $Columns) { return -1 }
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        if (([string]$Columns[$i].name).ToLower() -in $Names) { return $i }
    }
    return -1
}

function Get-CostData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [switch]$RestrictToSelected
    )

    $costMap = @{}

    # Restrict results to the subscriptions the user selected. MG-scope
    # queries return every subscription under the management group, so we
    # filter to the selected set to avoid showing unselected siblings.
    $selectedSubs = $null
    if ($Subscriptions -and $Subscriptions.Count -gt 0) {
        $selectedSubs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($s in $Subscriptions) { if ($s.Id) { [void]$selectedSubs.Add([string]$s.Id) } }
    }

    # Resolve the management-group scope we can actually query for cost.
    # Falls back to per-subscription only if no accessible MG returns cost data.
    # When the user picked a subset of subscriptions we KEEP the single fast
    # MG-scope query but add a server-side SubscriptionId filter so only the
    # selected subs are returned - this avoids the slow per-subscription
    # fan-out (N calls per timeframe) that triggers 429 throttling.
    $mgScopeId = Resolve-CostMgId -TenantId $TenantId
    $subFilter = if ($RestrictToSelected) { Get-CostSubscriptionFilter -Subscriptions $Subscriptions } else { $null }
    if (-not $mgScopeId) {
        Write-Host "  Querying actual costs (per-subscription)..." -ForegroundColor Cyan
        return Get-CostDataPerSubscription -Subscriptions $Subscriptions
    }

    # -- Actual Cost (Month-to-Date) ------------------------------------
    try {
        Write-Host "  Querying actual costs (MG scope)..." -ForegroundColor Cyan
        $actualDataset = @{
            granularity = 'None'
            aggregation = @{
                totalCost = @{ name = 'Cost'; function = 'Sum' }
            }
            grouping    = @(
                @{ type = 'Dimension'; name = 'SubscriptionId' }
            )
        }
        if ($subFilter) { $actualDataset['filter'] = $subFilter }
        $actualBody = @{
            type      = 'ActualCost'
            timeframe = 'MonthToDate'
            dataset   = $actualDataset
        } | ConvertTo-Json -Depth 10

        $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
        $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $actualBody

        if ($response.StatusCode -in @(401, 403)) {
            Set-MgCostScopeFailed
            throw "MG-scope cost query returned HTTP $($response.StatusCode). Falling back to per-subscription."
        }
        if ($response.StatusCode -ne 200) {
            throw "MG-scope cost query returned HTTP $($response.StatusCode). Falling back to per-subscription."
        }

        # The query API returns one page at a time. A truncated read looks like
        # lower cost rather than an error, so follow nextLink before summing.
        foreach ($page in (Get-CostQueryResponsePage -FirstResponse $response -Payload $actualBody -Context 'actual cost')) {
            $result = ($page.Content | ConvertFrom-Json)

            # Resolve column indices by name. The MG-scope response is not contractually
            # ordered, and a reorder would silently attribute cost to the wrong sub.
            $aCols = $result.properties.columns
            $aSubIdx = Get-CostColumnIndex -Columns $aCols -Names @('subscriptionid')
            $aCurIdx = Get-CostColumnIndex -Columns $aCols -Names @('currency')
            $aCostIdx = Get-CostColumnIndex -Columns $aCols -Names @('cost', 'pretaxcost', 'costusd')

            # Guessing at positions here would attribute real money to the wrong
            # subscription, so fail into the per-subscription path instead.
            if ($aCostIdx -lt 0 -or $aSubIdx -lt 0) {
                throw "Actual cost response did not expose the expected Cost and SubscriptionId columns."
            }

            if ($result.properties.rows) {
                foreach ($row in $result.properties.rows) {
                    $subId = [string]$row[$aSubIdx]
                    $amount = [double]$row[$aCostIdx]
                    $currency = if ($aCurIdx -ge 0) { $row[$aCurIdx] } else { 'USD' }

                    if ($selectedSubs -and -not $selectedSubs.Contains($subId)) { continue }

                    if (-not $costMap.ContainsKey($subId)) {
                        $costMap[$subId] = @{ Actual = 0; Forecast = 0; Currency = $currency; ForecastSource = 'Actual' }
                    }
                    $costMap[$subId].Actual += $amount
                    $costMap[$subId].Currency = $currency
                }
            }
        }

        # Round once after every page is in, not per page.
        foreach ($subId in @($costMap.Keys)) {
            $costMap[$subId].Actual = [math]::Round($costMap[$subId].Actual, 2)
        }
    }
    catch {
        Write-Warning "Actual cost query failed: $($_.Exception.Message)"
        if (-not $Subscriptions) { throw }
        Write-Warning "Falling back to per-subscription queries."
        $costMap = Get-CostDataPerSubscription -Subscriptions $Subscriptions
        return $costMap
    }

    # -- Forecasted Cost (Current Billing Period) -----------------------
    # Try MG-scope first, fall back to per-subscription if it fails
    $forecastSuccess = $false
    try {
        Write-Host "  Querying forecast costs (MG scope)..." -ForegroundColor Cyan
        $now = (Get-Date).ToUniversalTime()
        $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)

        $forecastBody = @{
            type                    = 'Usage'
            timeframe               = 'Custom'
            timePeriod              = @{
                from = $now.AddDays(1 - $now.Day).ToString('yyyy-MM-dd')
                to   = $monthEnd.ToString('yyyy-MM-dd')
            }
            dataset                 = $(
                $fcDataset = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                    grouping    = @(
                        @{ type = 'Dimension'; name = 'SubscriptionId' }
                    )
                }
                if ($subFilter) { $fcDataset['filter'] = $subFilter }
                $fcDataset
            )
            includeActualCost       = $true
            includeFreshPartialCost = $false
        } | ConvertTo-Json -Depth 10

        $forecastPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01"
        $fResponse = Invoke-AzRestMethodWithRetry -Path $forecastPath -Method POST -Payload $forecastBody

        if ($fResponse.StatusCode -ne 200) {
            throw "Forecast query returned HTTP $($fResponse.StatusCode)"
        }

        $forecastSums = @{}
        foreach ($page in (Get-CostQueryResponsePage -FirstResponse $fResponse -Payload $forecastBody -Context 'forecast')) {
            $fResult = $page.Content | ConvertFrom-Json
            if ($fResult.properties.rows.Count -eq 0) { continue }
            $fCols = $fResult.properties.columns
            $fSubIdx = Get-CostColumnIndex -Columns $fCols -Names @('subscriptionid')
            $fCostIdx = Get-CostColumnIndex -Columns $fCols -Names @('cost', 'pretaxcost', 'costusd')
            if ($fCostIdx -lt 0 -or $fSubIdx -lt 0) {
                throw "Forecast response did not expose the expected Cost and SubscriptionId columns."
            }

            foreach ($row in @($fResult.properties.rows)) {
                $subId = [string]$row[$fSubIdx]
                if ($subId -notmatch '^[0-9a-fA-F]{8}-') { continue }
                if ($selectedSubs -and -not $selectedSubs.Contains($subId)) { continue }
                $amount = [double]$row[$fCostIdx]
                if (-not $forecastSums.ContainsKey($subId)) { $forecastSums[$subId] = 0 }
                $forecastSums[$subId] += $amount
            }
        }
        if ($forecastSums.Count -gt 0) {
            foreach ($subId in $forecastSums.Keys) {
                if (-not $costMap.ContainsKey($subId)) {
                    $costMap[$subId] = @{ Actual = 0; Forecast = 0; Currency = 'USD' }
                }
                $costMap[$subId].Forecast = [math]::Round($forecastSums[$subId], 2)
                $costMap[$subId].ForecastSource = 'Forecast'
            }
            $forecastSuccess = $true
            Write-Host "  MG-scope forecast: got data for $($forecastSums.Count) subscriptions" -ForegroundColor Green
        }
        else {
            throw "MG-scope forecast returned 0 rows"
        }
    }
    catch {
        Write-Warning "MG-scope forecast failed: $($_.Exception.Message)"
        if (-not $Subscriptions) { throw }
        Write-Host "  Falling back to per-subscription forecast queries..." -ForegroundColor Yellow
    }

    # Per-subscription forecast fallback
    if (-not $forecastSuccess -and $Subscriptions) {
        $now = (Get-Date).ToUniversalTime()
        $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)
        $subCount = $Subscriptions.Count
        $i = 0
        $hitCount = 0
        foreach ($sub in $Subscriptions) {
            $i++
            if ($i % [math]::Max(1, [int]($subCount / 10)) -eq 0) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Querying forecasts ($i/$subCount subs)..."
                }
            }
            try {
                $fBody = @{
                    type                    = 'Usage'
                    timeframe               = 'Custom'
                    timePeriod              = @{
                        from = $now.AddDays(1 - $now.Day).ToString('yyyy-MM-dd')
                        to   = $monthEnd.ToString('yyyy-MM-dd')
                    }
                    dataset                 = @{
                        granularity = 'None'
                        aggregation = @{
                            totalCost = @{ name = 'Cost'; function = 'Sum' }
                        }
                    }
                    includeActualCost       = $true
                    includeFreshPartialCost = $false
                } | ConvertTo-Json -Depth 10

                $fResp = Invoke-AzRestMethodWithRetry -Path "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01" -Method POST -Payload $fBody
                if (-not $fResp -or $fResp.StatusCode -ne 200) {
                    throw "Forecast retry returned HTTP $($fResp.StatusCode); results are incomplete."
                }
                if ($fResp.StatusCode -eq 200) {
                    $total = 0.0
                    $rowCount = 0
                    foreach ($page in (Get-CostQueryResponsePage -FirstResponse $fResp -Payload $fBody -Context "forecast for $($sub.Id)")) {
                        $fRes = $page.Content | ConvertFrom-Json
                        if ($fRes.properties.rows.Count -eq 0) { continue }
                        $costIndex = Get-CostColumnIndex -Columns $fRes.properties.columns -Names @('cost', 'pretaxcost', 'costusd')
                        if ($costIndex -lt 0) { throw 'Forecast response did not expose the expected Cost column.' }
                        foreach ($row in $fRes.properties.rows) { $total += [double]$row[$costIndex]; $rowCount++ }
                    }
                    if ($rowCount -gt 0) {
                        if (-not $costMap.ContainsKey($sub.Id)) {
                            $costMap[$sub.Id] = @{ Actual = 0; Forecast = 0; Currency = 'USD' }
                        }
                        $costMap[$sub.Id].Forecast = [math]::Round($total, 2)
                        $costMap[$sub.Id].ForecastSource = 'Forecast'
                        $hitCount++
                    }
                    else {
                        throw 'Forecast retry returned no rows; results are incomplete.'
                    }
                }
            }
            catch {
                throw "Forecast query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
        Write-Host "  Per-sub forecast: got data for $hitCount of $subCount subscriptions" -ForegroundColor $(if ($hitCount -gt 0) { 'Green' } else { 'Yellow' })
    }

    # Subs without forecast data fall back to actual, which understates a
    # full-month projection. Flag it so callers can label the number rather
    # than present month-to-date spend as a forecast.
    foreach ($subId in @($costMap.Keys)) {
        if ($costMap[$subId].ForecastSource -ne 'Forecast') {
            $costMap[$subId].Forecast = $costMap[$subId].Actual
            $costMap[$subId].ForecastSource = 'Actual'
        }
    }

    return $costMap
}

# -- Fallback: Per-Subscription Cost Queries ----------------------------
function Get-CostDataPerSubscription {
    param([object[]]$Subscriptions)

    $costMap = @{}
    $subCount = $Subscriptions.Count
    $skipForecast = ($subCount -gt 100)   # For very large tenants, skip per-sub forecast to halve API calls
    if ($skipForecast) {
        Write-Host "  Large tenant ($subCount subs): skipping per-sub forecast to reduce API calls" -ForegroundColor Yellow
    }

    $i = 0
    foreach ($sub in $Subscriptions) {
        $i++
        if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
            if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                Update-ScanStatus "Querying costs ($i/$subCount subs)..."
            }
        }
        try {
            $body = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                }
            } | ConvertTo-Json -Depth 10

            $path = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement"
            $resp = Invoke-AzRestMethodWithRetry -Path "$path/query?api-version=2023-11-01" -Method POST -Payload $body

            $actual = 0; $currency = 'USD'
            if ($resp.StatusCode -eq 200) {
                $sum = 0.0
                foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -Payload $body -Context "actual cost for $($sub.Id)")) {
                    $res = $page.Content | ConvertFrom-Json
                    if ($res.properties.rows.Count -eq 0) { continue }
                    $cIdx = Get-CostColumnIndex -Columns $res.properties.columns -Names @('cost', 'pretaxcost', 'costusd')
                    $curIdx = Get-CostColumnIndex -Columns $res.properties.columns -Names @('currency')
                    if ($cIdx -lt 0) { throw 'Actual cost response did not expose the expected Cost column.' }
                    foreach ($row in $res.properties.rows) {
                        $sum += [double]$row[$cIdx]
                        if ($curIdx -ge 0 -and $row[$curIdx]) { $currency = $row[$curIdx] }
                    }
                }
                $actual = [math]::Round($sum, 2)
            }
            elseif ($resp.StatusCode -in @(400, 403) -and $resp.Content) {
                $errMsg = try { ($resp.Content | ConvertFrom-Json).error.message } catch { '' }
                if ($errMsg -match 'AO View Charges') {
                    $script:costAccessIssue = 'EA'
                    Write-Warning "  Cost data disabled for EA account owners. Enable 'AO View Charges' in the EA portal."
                }
                elseif ($resp.StatusCode -eq 403) {
                    $script:costAccessIssue = 'MCA'
                    Write-Warning "  Cost data access denied. Verify Billing Profile Reader or Cost Management Reader role assignment."
                }
            }
            if (-not $resp -or $resp.StatusCode -ne 200) {
                throw "Actual cost query returned HTTP $($resp.StatusCode); results are incomplete."
            }

            # Forecast starts as actual so a sub with no forecast still reports a
            # number; ForecastSource records that it is month-to-date, not a projection.
            $costMap[$sub.Id] = @{ Actual = $actual; Forecast = $actual; Currency = $currency; ForecastSource = 'Actual' }

            # Per-sub forecast (skipped for large tenants)
            if (-not $skipForecast) {
                try {
                    $now = (Get-Date).ToUniversalTime()
                    $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)
                    $fBody = @{
                        type                    = 'Usage'
                        timeframe               = 'Custom'
                        timePeriod              = @{
                            from = $now.AddDays(1 - $now.Day).ToString('yyyy-MM-dd')
                            to   = $monthEnd.ToString('yyyy-MM-dd')
                        }
                        dataset                 = @{
                            granularity = 'None'
                            aggregation = @{
                                totalCost = @{ name = 'Cost'; function = 'Sum' }
                            }
                        }
                        includeActualCost       = $true
                        includeFreshPartialCost = $false
                    } | ConvertTo-Json -Depth 10

                    $fResp = Invoke-AzRestMethodWithRetry -Path "$path/forecast?api-version=2023-11-01" -Method POST -Payload $fBody
                    if (-not $fResp -or $fResp.StatusCode -ne 200) {
                        throw "Forecast query returned HTTP $($fResp.StatusCode); results are incomplete."
                    }
                    if ($fResp.StatusCode -eq 200) {
                        $total = 0.0
                        $rowCount = 0
                        foreach ($page in (Get-CostQueryResponsePage -FirstResponse $fResp -Payload $fBody -Context "forecast for $($sub.Id)")) {
                            $fRes = $page.Content | ConvertFrom-Json
                            if ($fRes.properties.rows.Count -eq 0) { continue }
                            $fcIdx = Get-CostColumnIndex -Columns $fRes.properties.columns -Names @('cost', 'pretaxcost', 'costusd')
                            if ($fcIdx -lt 0) { throw 'Forecast response did not expose the expected Cost column.' }
                            foreach ($fRow in $fRes.properties.rows) { $total += [double]$fRow[$fcIdx]; $rowCount++ }
                        }
                        if ($rowCount -gt 0) {
                            $costMap[$sub.Id].Forecast = [math]::Round($total, 2)
                            $costMap[$sub.Id].ForecastSource = 'Forecast'
                        }
                        else {
                            throw 'Forecast query returned no rows; results are incomplete.'
                        }
                    }
                }
                catch {
                    throw
                }
            }
        }
        catch {
            throw "Cost query failed for $($sub.Name): $($_.Exception.Message)"
        }
    }
    return $costMap
}
