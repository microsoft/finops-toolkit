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

        $result = ($response.Content | ConvertFrom-Json)

        # Resolve column indices by name. The MG-scope response is not contractually
        # ordered, and a reorder would silently attribute cost to the wrong sub.
        $aCols = $result.properties.columns
        $aCostIdx = -1; $aSubIdx = -1; $aCurIdx = -1
        if ($aCols) {
            for ($ci = 0; $ci -lt $aCols.Count; $ci++) {
                $cn = ([string]$aCols[$ci].name).ToLower()
                if ($cn -eq 'subscriptionid') { $aSubIdx = $ci }
                elseif ($cn -eq 'currency') { $aCurIdx = $ci }
                elseif ($cn -match 'cost|pretaxcost') { $aCostIdx = $ci }
            }
        }
        if ($aCostIdx -eq -1) { $aCostIdx = 0 }
        if ($aSubIdx -eq -1) { $aSubIdx = 1 }
        if ($aCurIdx -eq -1) { $aCurIdx = 2 }

        if ($result.properties.rows) {
            foreach ($row in $result.properties.rows) {
                $subId = $row[$aSubIdx]
                $amount = [math]::Round($row[$aCostIdx], 2)
                $currency = $row[$aCurIdx]

                if ($selectedSubs -and -not $selectedSubs.Contains([string]$subId)) { continue }

                if (-not $costMap.ContainsKey($subId)) {
                    $costMap[$subId] = @{ Actual = 0; Forecast = 0; Currency = $currency }
                }
                $costMap[$subId].Actual = $amount
                $costMap[$subId].Currency = $currency
            }
        }
    }
    catch {
        Write-Warning "Actual cost query failed: $($_.Exception.Message)"
        Write-Warning "Falling back to per-subscription queries."
        $costMap = Get-CostDataPerSubscription -Subscriptions $Subscriptions
        return $costMap
    }

    # -- Forecasted Cost (Current Billing Period) -----------------------
    # Try MG-scope first, fall back to per-subscription if it fails
    $forecastSuccess = $false
    try {
        Write-Host "  Querying forecast costs (MG scope)..." -ForegroundColor Cyan
        $now = Get-Date
        $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)

        $forecastBody = @{
            type                    = 'Usage'
            timeframe               = 'Custom'
            timePeriod              = @{
                from = $now.ToString('yyyy-MM-dd')
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

        $fResult = ($fResponse.Content | ConvertFrom-Json)

        if ($fResult.properties.rows -and $fResult.properties.rows.Count -gt 0) {
            # The Forecast API with includeActualCost returns rows that may have
            # a CostStatus column (Actual/Forecast). Sum all rows per subscription
            # to get the full-month projected cost.
            # Resolve column indices by name. The forecast endpoint may order
            # columns differently and adds a CostStatus column, so positional
            # access can mistake "Forecast"/"Actual" text for a subscription ID.
            $fCols = $fResult.properties.columns
            $fCostIdx = -1; $fSubIdx = -1
            if ($fCols) {
                for ($ci = 0; $ci -lt $fCols.Count; $ci++) {
                    $cn = ([string]$fCols[$ci].name).ToLower()
                    if ($cn -eq 'subscriptionid') { $fSubIdx = $ci }
                    elseif ($cn -match 'cost|pretaxcost') { $fCostIdx = $ci }
                }
            }
            if ($fCostIdx -eq -1) { $fCostIdx = 0 }
            if ($fSubIdx -eq -1) { $fSubIdx = 1 }

            $forecastSums = @{}
            foreach ($row in $fResult.properties.rows) {
                $subId = [string]$row[$fSubIdx]
                if ($subId -notmatch '^[0-9a-fA-F]{8}-') { continue }
                if ($selectedSubs -and -not $selectedSubs.Contains($subId)) { continue }
                $amount = [double]$row[$fCostIdx]
                if (-not $forecastSums.ContainsKey($subId)) { $forecastSums[$subId] = 0 }
                $forecastSums[$subId] += $amount
            }
            foreach ($subId in $forecastSums.Keys) {
                if (-not $costMap.ContainsKey($subId)) {
                    $costMap[$subId] = @{ Actual = 0; Forecast = 0; Currency = 'USD' }
                }
                $costMap[$subId].Forecast = [math]::Round($forecastSums[$subId], 2)
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
        Write-Host "  Falling back to per-subscription forecast queries..." -ForegroundColor Yellow
    }

    # Per-subscription forecast fallback
    if (-not $forecastSuccess -and $Subscriptions) {
        $now = Get-Date
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
                        from = $now.ToString('yyyy-MM-dd')
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
                if ($fResp.StatusCode -eq 200) {
                    $fRes = ($fResp.Content | ConvertFrom-Json)
                    if ($fRes.properties.rows -and $fRes.properties.rows.Count -gt 0) {
                        $total = 0
                        foreach ($row in $fRes.properties.rows) { $total += [double]$row[0] }
                        if (-not $costMap.ContainsKey($sub.Id)) {
                            $costMap[$sub.Id] = @{ Actual = 0; Forecast = 0; Currency = 'USD' }
                        }
                        $costMap[$sub.Id].Forecast = [math]::Round($total, 2)
                        $hitCount++
                    }
                }
            }
            catch {
                # Forecast not available for this sub
            }
        }
        Write-Host "  Per-sub forecast: got data for $hitCount of $subCount subscriptions" -ForegroundColor $(if ($hitCount -gt 0) { 'Green' } else { 'Yellow' })
    }

    # Ensure any subs without forecast data default to actual
    foreach ($subId in $costMap.Keys) {
        if ($costMap[$subId].Forecast -eq 0 -and $costMap[$subId].Actual -gt 0) {
            $costMap[$subId].Forecast = $costMap[$subId].Actual
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
                $res = ($resp.Content | ConvertFrom-Json)
                if ($res.properties.rows -and $res.properties.rows.Count -gt 0) {
                    $actual = [math]::Round($res.properties.rows[0][0], 2)
                    $currency = $res.properties.rows[0][1]
                }
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

            $costMap[$sub.Id] = @{ Actual = $actual; Forecast = $actual; Currency = $currency }

            # Per-sub forecast (skipped for large tenants)
            if (-not $skipForecast) {
                try {
                    $now = Get-Date
                    $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)
                    $fBody = @{
                        type                    = 'Usage'
                        timeframe               = 'Custom'
                        timePeriod              = @{
                            from = $now.ToString('yyyy-MM-dd')
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
                    if ($fResp.StatusCode -eq 200) {
                        $fRes = ($fResp.Content | ConvertFrom-Json)
                        if ($fRes.properties.rows -and $fRes.properties.rows.Count -gt 0) {
                            $fAmount = [math]::Round($fRes.properties.rows[0][0], 2)
                            $costMap[$sub.Id].Forecast = $actual + $fAmount
                        }
                    }
                }
                catch {
                    # Forecast not available for all account types
                }
            }
        }
        catch {
            Write-Warning "  Cost query failed for $($sub.Name): $($_.Exception.Message)"
        }
    }
    return $costMap
}
