# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
param()

###########################################################################
# GET-BUDGETSTATUS.PS1
# AZURE FINOPS MULTITOOL - Budget vs. Actual Comparison
###########################################################################
# Purpose: Query Azure Budgets (Consumption API) for each subscription to
#          show configured budget amount vs current spend. Highlights
#          subscriptions at risk of overrun.
###########################################################################

function Format-BudgetAmount {
    param($Value, [string]$Currency)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Currency)) { return 'Unavailable' }
    try {
        $amount = Get-HubCostValue -Row ([pscustomobject]@{ Value = $Value }) -Column 'Value'
        return '{0} {1:N2}' -f $Currency, $amount
    }
    catch { return 'Unavailable' }
}

function Get-BudgetStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions,

        [Parameter()]
        $CostData    # Existing cost data keyed by subscription ID
    )

    # Guard: extract hashtable if pipeline pollution wrapped it in an array
    if ($CostData -and $CostData -isnot [hashtable]) {
        $CostData = @($CostData | Where-Object { $_ -is [hashtable] })[-1]
    }
    if (-not $CostData) { $CostData = @{} }

    $subCount = $Subscriptions.Count
    Write-Host "  Querying budget status ($subCount subs)..." -ForegroundColor Cyan

    $budgets = [System.Collections.Generic.List[PSCustomObject]]::new()
    $subsWithBudget = 0
    $subsWithoutBudget = 0
    $sampled = $false
    $scannedSubs = $subCount
    $coverageIncomplete = $false
    # Subscriptions whose budget query never answered. Counting these as "no
    # budget" would turn missing access into a confident coverage percentage.
    $unreadableSubs = 0

    # -- For large tenants, sample first to see if budgets exist --------
    $subsToQuery = $Subscriptions
    if ($subCount -gt 50) {
        $sampleSize = [math]::Min(10, $subCount)
        Write-Host "  Large tenant: sampling $sampleSize of $subCount subs for budgets..." -ForegroundColor Yellow
        # Random rather than the first N: subscription order is not arbitrary, so
        # the head of the list is not a representative sample.
        $sampleSubs = @($Subscriptions | Get-Random -Count $sampleSize)
        $sampleHits = 0
        $sampleErrors = 0
        foreach ($sub in $sampleSubs) {
            try {
                $budgetPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/budgets?api-version=2023-05-01"
                $resp = Invoke-AzRestMethodWithRetry -Path $budgetPath -Method GET
                if ($resp.StatusCode -eq 200) {
                    $sampleBudgets = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -RootNextLink -Context "budget sample for $($sub.Name)")) {
                            ($page.Content | ConvertFrom-Json -ErrorAction Stop).value
                        })
                    if ($sampleBudgets -and $sampleBudgets.Count -gt 0) { $sampleHits++ }
                }
                else { $sampleErrors++ }
            }
            catch {
                $sampleErrors++
                Write-Verbose "Budget sample failed for $($sub.Name): $($_.Exception.Message)"
            }
        }

        if ($sampleHits -eq 0 -and $sampleErrors -eq 0) {
            # Every probe answered and none held a budget. That is evidence about
            # the sampled subscriptions only - budgets can still exist in the ones
            # never queried - so the result is marked incomplete rather than
            # reported as "no budgets" for the whole tenant.
            Write-Host "  No budgets found in sample of $sampleSize subs - skipping remaining (coverage unverified)" -ForegroundColor Yellow
            $sampled = $true
            $coverageIncomplete = $true
            $scannedSubs = $sampleSize
            $subsWithoutBudget = $sampleSize
            $subsToQuery = @()   # Skip the main loop
        }
        elseif ($sampleHits -eq 0) {
            Write-Warning "  Budget sample inconclusive ($sampleErrors of $sampleSize probes failed); querying all $subCount subs instead of assuming none."
        }
        else {
            Write-Host "  Budgets found in sample ($sampleHits/$sampleSize), querying all $subCount subs..." -ForegroundColor Cyan
        }
    }

    $i = 0
    foreach ($sub in $subsToQuery) {
        $i++
        if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
            if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                Update-ScanStatus "Querying budgets ($i/$subCount subs)..."
            }
        }
        try {
            $budgetPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/budgets?api-version=2023-05-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $budgetPath -Method GET

            if ($resp.StatusCode -eq 200) {
                $budgetRows = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -RootNextLink -Context "budgets for $($sub.Name)")) {
                        ($page.Content | ConvertFrom-Json -ErrorAction Stop).value
                    })
                if ($budgetRows.Count -gt 0) {
                    $subsWithBudget++
                    foreach ($budget in $budgetRows) {
                        $bp = $budget.properties
                        $issues = [System.Collections.Generic.List[string]]::new()
                        $amount = $null
                        try {
                            $value = Get-HubCostValue -Row $bp -Column 'amount'
                            if ($value -le 0) { throw 'Budget amount must be positive.' }
                            $amount = $value
                        }
                        catch { [void]$issues.Add('Budget amount is missing or invalid.') }
                        $timeGrain = $bp.timeGrain
                        $category = $bp.category

                        $actualSpend = $null
                        $forecast = $null
                        $spendKnown = $false
                        $spendSource = 'Unavailable'
                        $forecastSource = 'Unavailable'
                        $spendCurrency = $null
                        $actualUnit = ([string]$bp.currentSpend.unit).Trim().ToUpperInvariant()
                        $forecastUnit = ([string]$bp.forecastSpend.unit).Trim().ToUpperInvariant()
                        if ($actualUnit) { $spendCurrency = $actualUnit }
                        elseif ($forecastUnit) { $spendCurrency = $forecastUnit }

                        if ($bp.currentSpend -and $actualUnit) {
                            try {
                                $actualSpend = Get-HubCostValue -Row $bp.currentSpend -Column 'amount'
                                $spendKnown = $true
                                $spendSource = 'Budget'
                            }
                            catch { [void]$issues.Add('Current spend amount is missing or invalid.') }
                        }
                        else { [void]$issues.Add('Current spend or its unit is unavailable.') }
                        if ($bp.forecastSpend -and $forecastUnit -and $forecastUnit -eq $spendCurrency) {
                            try {
                                $forecast = Get-HubCostValue -Row $bp.forecastSpend -Column 'amount'
                                $forecastSource = 'Budget'
                            }
                            catch { [void]$issues.Add('Forecast amount is missing or invalid.') }
                        }
                        elseif ($bp.forecastSpend) { [void]$issues.Add('Forecast unit is missing or does not match the budget unit.') }
                        else { [void]$issues.Add('Budget forecast is unavailable.') }

                        $pctUsed = if ($spendKnown -and $null -ne $amount) { [math]::Round(($actualSpend / $amount) * 100, 1) } else { $null }
                        $pctForecast = if ($forecastSource -ne 'Unavailable' -and $null -ne $amount) { [math]::Round(($forecast / $amount) * 100, 1) } else { $null }

                        $risk = if ($null -eq $amount) { 'Unknown' }
                        elseif ($pctUsed -gt 100) { 'Over Budget' }
                        elseif ($pctForecast -gt 100) { 'Forecast Over' }
                        elseif (-not $spendKnown) { 'Unknown' }
                        elseif ($pctForecast -gt 90) { 'At Risk' }
                        elseif ($pctUsed -gt 90) { 'Near Limit' }
                        elseif ($forecastSource -eq 'Unavailable') { 'Forecast unavailable' }
                        elseif ($pctForecast -gt 75) { 'Watch' }
                        else { 'On Track' }

                        # Notification thresholds and contacts
                        $thresholds = @()
                        $contactEmails = @()
                        $contactRoles = @()
                        if ($bp.notifications) {
                            foreach ($notif in $bp.notifications.PSObject.Properties) {
                                $np = $notif.Value
                                $thresholds += "$($np.threshold)% ($($np.operator))"
                                if ($np.contactEmails) { $contactEmails += @($np.contactEmails) }
                                if ($np.contactRoles) { $contactRoles += @($np.contactRoles) }
                            }
                        }

                        # Extract tag filters from budget filter property
                        $tagFilters = @()
                        if ($bp.filter -and $bp.filter.tags) {
                            foreach ($tagProp in $bp.filter.tags.PSObject.Properties) {
                                $tagKey = $tagProp.Name
                                $tagVals = @()
                                if ($tagProp.Value -and $tagProp.Value.values) {
                                    $tagVals = @($tagProp.Value.values)
                                }
                                $tagFilters += "$tagKey=$($tagVals -join '|')"
                            }
                        }
                        if ($bp.filter -and $bp.filter.dimensions) {
                            foreach ($dimProp in $bp.filter.dimensions.PSObject.Properties) {
                                if ($dimProp.Name -match '^Tag') {
                                    $dimName = $dimProp.Name -replace '^Tag', ''
                                    $dimVals = if ($dimProp.Value.values) { @($dimProp.Value.values) } else { @() }
                                    $tagFilters += "$dimName=$($dimVals -join '|')"
                                }
                            }
                        }
                        $tagFilterStr = $tagFilters -join '; '

                        [void]$budgets.Add([PSCustomObject]@{
                                Subscription   = $sub.Name
                                SubscriptionId = $sub.Id
                                BudgetName     = $budget.name
                                Amount         = $amount
                                TimeGrain      = $timeGrain
                                Category       = $category
                                ActualSpend    = $actualSpend
                                Forecast       = $forecast
                                SpendSource    = $spendSource
                                ForecastSource = $forecastSource
                                PctUsed        = $pctUsed
                                PctForecast    = $pctForecast
                                Risk           = $risk
                                Thresholds     = ($thresholds -join ', ')
                                ContactEmails  = (($contactEmails | Select-Object -Unique) -join ', ')
                                ContactRoles   = (($contactRoles  | Select-Object -Unique) -join ', ')
                                TagFilter      = $tagFilterStr
                                Filter         = $bp.filter
                                TimePeriod     = $bp.timePeriod
                                Scope          = "/subscriptions/$($sub.Id)"
                                Currency       = $spendCurrency
                                Note           = ($issues -join ' ')
                            })
                    }
                }
                else {
                    $subsWithoutBudget++
                }
            }
            else {
                $unreadableSubs++
            }
        }
        catch {
            Write-Warning "  Budget query failed for $($sub.Name): $($_.Exception.Message)"
            $unreadableSubs++
        }
    }

    # Count risk levels
    # OverBudgetCount = actual spend already exceeded budget (urgent / red).
    # AtRiskCount = forecast-driven warnings (projected over, or trending high).
    $overBudget = @($budgets | Where-Object { $_.Risk -eq 'Over Budget' }).Count
    $atRisk = @($budgets | Where-Object { $_.Risk -in @('Forecast Over', 'At Risk', 'Near Limit') }).Count

    # Either an unqueried sample or an unreadable subscription leaves coverage
    # unmeasured, so both suppress the percentage rather than rounding down.
    if ($unreadableSubs -gt 0) { $coverageIncomplete = $true }
    $readSubs = $scannedSubs - $unreadableSubs

    $note = if ($sampled) {
        "Sampled $scannedSubs of $subCount subscriptions and none had a budget. Budgets may still exist in the subscriptions that were not queried, so coverage is unverified."
    }
    elseif ($unreadableSubs -gt 0) {
        "$unreadableSubs of $subCount subscriptions could not be queried for budgets, so coverage is unverified. They are not counted as being without a budget."
    }
    else { $null }

    return [PSCustomObject]@{
        Budgets            = @($budgets)
        TotalBudgets       = $budgets.Count
        SubsWithBudget     = $subsWithBudget
        SubsWithoutBudget  = $subsWithoutBudget
        UnreadableSubs     = $unreadableSubs
        OverBudgetCount    = $overBudget
        AtRiskCount        = $atRisk
        HasData            = ($budgets.Count -gt 0)
        Sampled            = $sampled
        ScannedSubs        = $readSubs
        TotalSubs          = $subCount
        CoverageIncomplete = $coverageIncomplete
        Note               = $note
        # Left null when incomplete: a percentage derived from a partial read
        # would be taken as a measured figure for the whole tenant.
        BudgetCoverage     = if ($coverageIncomplete) { $null }
        elseif ($Subscriptions.Count -gt 0) {
            [math]::Round(($subsWithBudget / $Subscriptions.Count) * 100, 1)
        }
        else { 0 }
    }
}

function ConvertTo-BudgetHistoryFilter {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Filter,
        [int]$Depth = 0
    )

    if ($Depth -gt 4) { throw 'Budget filter nesting is unsupported.' }
    if ($null -eq $Filter -and $Depth -eq 0) { return $null }
    if ($Filter -isnot [System.Collections.IDictionary] -and $Filter -isnot [pscustomobject]) {
        throw 'Budget filter must be a structured expression.'
    }
    $keys = @(if ($Filter -is [System.Collections.IDictionary]) { $Filter.Keys }
        else { $Filter.PSObject.Properties | ForEach-Object Name })
    if ($keys.Count -eq 0 -and $Depth -eq 0) { return $null }
    if ($keys.Count -ne 1 -or $keys[0] -notin @('and', 'dimensions', 'tags')) {
        throw 'Budget filter contains an unsupported or ambiguous expression.'
    }
    $kind = ([string]$keys[0]).ToLowerInvariant()
    if ($kind -eq 'and') {
        if ($Filter.and -isnot [array] -or $Filter.and.Count -lt 2) { throw 'Budget filter AND must contain at least two expressions.' }
        $children = @(foreach ($child in $Filter.and) { ConvertTo-BudgetHistoryFilter -Filter $child -Depth ($Depth + 1) })
        return [ordered]@{ and = $children }
    }

    $comparison = $Filter.$kind
    if ($comparison -isnot [System.Collections.IDictionary] -and $comparison -isnot [pscustomobject]) {
        throw 'Budget filter comparison is invalid.'
    }
    $comparisonKeys = @(if ($comparison -is [System.Collections.IDictionary]) { $comparison.Keys }
        else { $comparison.PSObject.Properties | ForEach-Object Name })
    if ($comparisonKeys.Count -ne 3 -or @($comparisonKeys | Where-Object { $_ -notin @('name', 'operator', 'values') }).Count -gt 0 -or
        $comparison.name -isnot [string] -or [string]::IsNullOrWhiteSpace($comparison.name) -or
        $comparison.operator -ne 'In' -or $comparison.values -isnot [array] -or $comparison.values.Count -eq 0 -or
        @($comparison.values | Where-Object { $_ -isnot [string] }).Count -gt 0) {
        throw 'Budget filter requires a name, the In operator, and string values.'
    }
    return [ordered]@{ $kind = [ordered]@{ name = $comparison.name; operator = 'In'; values = @($comparison.values) } }
}

function Get-BudgetHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Budgets,

        [Parameter()]
        [ValidateRange(1, 36)]
        [int]$MonthsBack = 6,

        # Optional Cost Trend result (from Get-CostTrend). When supplied, its
        # already-fetched per-subscription monthly spend is reused instead of
        # re-querying the (throttle-prone) Cost Management Query API.
        [Parameter()]
        [object]$CostTrend
    )

    if (-not $Budgets -or $Budgets.Count -eq 0) { return @() }

    $history = [System.Collections.Generic.List[PSCustomObject]]::new()
    $now = (Get-Date).ToUniversalTime()
    $monthStart = $now.Date.AddDays(1 - $now.Day)
    $monthDates = @(for ($monthsAgo = $MonthsBack; $monthsAgo -ge 1; $monthsAgo--) { $monthStart.AddMonths(-$monthsAgo) })
    $costCache = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)

    foreach ($budget in $Budgets) {
        $reason = $null
        $budgetAmount = $null
        $periodStart = $null
        $periodEnd = [datetime]::MaxValue
        $subId = [string]$budget.SubscriptionId
        $queryFilter = $null
        try {
            $queryFilter = ConvertTo-BudgetHistoryFilter -Filter $budget.Filter
            if ($null -eq $queryFilter -and $budget.TagFilter) { throw 'The structured budget filter is unavailable.' }
        }
        catch { $reason = "Budget history cannot apply this filter: $($_.Exception.Message)" }
        $filterKey = if ($null -eq $queryFilter) { '' } else { ConvertTo-Json -InputObject $queryFilter -Depth 20 -Compress }
        $cacheKey = "$subId|$filterKey"
        if (-not $reason -and ($budget.Category -ne 'Cost' -or $budget.TimeGrain -ne 'Monthly')) { $reason = 'Subscription monthly costs cannot reconstruct this budget category or period.' }
        elseif (-not $budget.Currency) { $reason = 'Budget currency is unavailable.' }
        elseif ($budget.Scope -and $budget.Scope -ne "/subscriptions/$subId") { $reason = 'Budget scope differs from the subscription cost scope.' }
        try {
            $budgetAmount = Get-HubCostValue -Row $budget -Column 'Amount'
            if ($budgetAmount -le 0) { throw 'Budget amount must be positive.' }
        }
        catch { $budgetAmount = $null; $reason = 'Budget amount is missing or invalid.' }
        try {
            if (-not $budget.TimePeriod.startDate) { throw 'Missing start date.' }
            $periodStart = ([datetime]$budget.TimePeriod.startDate).ToUniversalTime()
            if ($budget.TimePeriod.endDate) { $periodEnd = ([datetime]$budget.TimePeriod.endDate).ToUniversalTime().Date.AddDays(1) }
        }
        catch { $reason = 'Budget validity period is unavailable.' }
        $activeMonths = if (-not $reason) { @($monthDates | Where-Object { $_ -ge $periodStart -and $_.AddMonths(1) -le $periodEnd }) } else { @() }

        if (-not $reason -and $activeMonths.Count -gt 0 -and -not $costCache.ContainsKey($cacheKey)) {
            $monthlyCosts = @{}
            if ($null -eq $queryFilter -and $CostTrend -and $CostTrend.BySubscription -and $CostTrend.BySubscription[$subId]) {
                try {
                    foreach ($entry in $CostTrend.BySubscription[$subId]) {
                        if ($entry.MonthDate -isnot [datetime] -or -not $entry.Currency) { throw 'Cached cost date or currency is missing.' }
                        $key = $entry.MonthDate.ToString('yyyy-MM')
                        $amount = Get-HubCostValue -Row $entry -Column 'Cost'
                        if (-not $monthlyCosts.ContainsKey($key)) { $monthlyCosts[$key] = @{ Cost = 0.0; Currency = $entry.Currency } }
                        if ($monthlyCosts[$key].Currency -ne $entry.Currency) { throw 'Cached monthly costs have mixed currencies.' }
                        $monthlyCosts[$key].Cost += $amount
                    }
                }
                catch { $monthlyCosts.Clear() }
            }
            $covered = $true
            foreach ($month in $monthDates) { if (-not $monthlyCosts.ContainsKey($month.ToString('yyyy-MM'))) { $covered = $false } }
            if (-not $covered) {
                $dataset = @{ granularity = 'Monthly'; aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } } }
                if ($null -ne $queryFilter) { $dataset.filter = $queryFilter }
                $body = @{
                    type = 'ActualCost'; timeframe = 'Custom'
                    timePeriod = @{ from = $monthDates[0].ToString('yyyy-MM-dd'); to = $monthStart.AddDays(-1).ToString('yyyy-MM-dd') }
                    dataset = $dataset
                } | ConvertTo-Json -Depth 20
                $costPath = "/subscriptions/$subId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $response = Invoke-AzRestMethodWithRetry -Path $costPath -Method POST -Payload $body
                $result = Get-CostQueryResult -FirstResponse $response -Payload $body -Context "budget history for $($budget.Subscription)"
                $costIndex = Get-CostColumnIndex -Columns $result.properties.columns -Names @('cost', 'totalcost', 'pretaxcost')
                $dateIndex = Get-CostColumnIndex -Columns $result.properties.columns -Names @('billingmonth', 'usagedate')
                $currencyIndex = Get-CostColumnIndex -Columns $result.properties.columns -Names @('currency', 'billingcurrency')
                if ($result.properties.rows.Count -gt 0 -and ($costIndex -lt 0 -or $dateIndex -lt 0 -or $currencyIndex -lt 0)) {
                    throw 'Budget history is missing required cost columns; results are incomplete.'
                }
                $monthlyCosts.Clear()
                foreach ($month in $monthDates) { $monthlyCosts[$month.ToString('yyyy-MM')] = @{ Cost = 0.0; Currency = $null } }
                foreach ($row in $result.properties.rows) {
                    $rawDate = $row[$dateIndex]
                    try {
                        $date = if ($rawDate -is [datetime]) { $rawDate }
                        elseif ([string]$rawDate -match '^\d{8}$') { [datetime]::ParseExact([string]$rawDate, 'yyyyMMdd', [cultureinfo]::InvariantCulture) }
                        else { [datetime]::Parse([string]$rawDate, [cultureinfo]::InvariantCulture) }
                    }
                    catch { throw 'Budget history contains an invalid date; results are incomplete.' }
                    $key = $date.ToString('yyyy-MM')
                    $currency = [string]$row[$currencyIndex]
                    if (-not $monthlyCosts.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($currency) -or
                        ($monthlyCosts[$key].Currency -and $monthlyCosts[$key].Currency -ne $currency)) {
                        throw 'Budget history has an invalid period or mixed currencies; results are incomplete.'
                    }
                    $monthlyCosts[$key].Currency = $currency
                    $monthlyCosts[$key].Cost += [double]$row[$costIndex]
                }
            }
            $costCache[$cacheKey] = $monthlyCosts
        }

        foreach ($month in $monthDates) {
            $key = $month.ToString('yyyy-MM')
            $rowReason = $reason
            $actual = $null
            $pctUsed = $null
            $status = 'Unavailable'
            if (-not $rowReason -and ($month -lt $periodStart -or $month.AddMonths(1) -gt $periodEnd)) {
                $rowReason = 'The budget was not active for this full month.'
            }
            if (-not $rowReason) {
                $cost = $costCache[$cacheKey][$key]
                if ($cost.Currency -and $cost.Currency -ne $budget.Currency) { $rowReason = 'Cost currency does not match the budget currency.' }
                else {
                    $actual = [math]::Round($cost.Cost, 2)
                    $pctUsed = [math]::Round(100 * $actual / $budgetAmount, 1)
                    $status = if ($pctUsed -gt 100) { 'Over' } elseif ($pctUsed -gt 90) { 'Near Limit' } else { 'Under' }
                }
            }
            [void]$history.Add([PSCustomObject]@{
                    Subscription = $budget.Subscription; BudgetName = $budget.BudgetName; Month = $month.ToString('MMM yyyy'); MonthSort = $key
                    BudgetAmount = if ($budget.TimeGrain -eq 'Monthly') { $budgetAmount } else { $null }
                    ActualSpend = $actual; PctUsed = $pctUsed; Status = $status; Currency = $budget.Currency
                    Note = if ($rowReason) { $rowReason }
                    elseif ($null -ne $queryFilter) { 'Costs use the current budget filter and amount; prior budget revisions are unavailable.' }
                    else { 'Compared with the current budget amount; prior budget revisions are unavailable.' }
                })
        }
    }

    return @($history | Sort-Object Subscription, BudgetName, MonthSort)
}
