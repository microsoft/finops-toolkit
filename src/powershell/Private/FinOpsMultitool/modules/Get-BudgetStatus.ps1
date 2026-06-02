###########################################################################
# GET-BUDGETSTATUS.PS1
# AZURE FINOPS MULTITOOL - Budget vs. Actual Comparison
###########################################################################
# Purpose: Query Azure Budgets (Consumption API) for each subscription to
#          show configured budget amount vs current spend. Highlights
#          subscriptions at risk of overrun.
###########################################################################

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

    # -- For large tenants, sample first to see if budgets exist --------
    $subsToQuery = $Subscriptions
    if ($subCount -gt 50) {
        $sampleSize = [math]::Min(10, $subCount)
        Write-Host "  Large tenant: sampling $sampleSize of $subCount subs for budgets..." -ForegroundColor Yellow
        $sampleSubs = $Subscriptions | Select-Object -First $sampleSize
        $sampleHits = 0
        foreach ($sub in $sampleSubs) {
            try {
                $budgetPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/budgets?api-version=2023-05-01"
                $resp = Invoke-AzRestMethodWithRetry -Path $budgetPath -Method GET
                if ($resp.StatusCode -eq 200) {
                    $budgets = ($resp.Content | ConvertFrom-Json).value
                    if ($budgets -and $budgets.Count -gt 0) { $sampleHits++ }
                }
            }
            catch { }
        }

        if ($sampleHits -eq 0) {
            Write-Host "  No budgets found in sample of $sampleSize subs - skipping remaining" -ForegroundColor Yellow
            $sampled = $true
            $subsWithoutBudget = $subCount
            $subsToQuery = @()   # Skip the main loop
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
                $data = ($resp.Content | ConvertFrom-Json)
                if ($data.value -and $data.value.Count -gt 0) {
                    $subsWithBudget++
                    foreach ($budget in $data.value) {
                        $bp = $budget.properties
                        $amount = [math]::Round([double]$bp.amount, 2)
                        $timeGrain = $bp.timeGrain
                        $category = $bp.category

                        # Current spend from our existing cost data
                        $actualSpend = 0
                        $forecast = 0
                        if ($CostData -and $CostData.ContainsKey($sub.Id)) {
                            $actualSpend = [math]::Round($CostData[$sub.Id].Actual, 2)
                            $forecast = [math]::Round($CostData[$sub.Id].Forecast, 2)
                        }

                        # Calculate % used
                        $pctUsed = if ($amount -gt 0) { [math]::Round(($actualSpend / $amount) * 100, 1) } else { 0 }
                        $pctForecast = if ($amount -gt 0) { [math]::Round(($forecast / $amount) * 100, 1) } else { 0 }

                        # Risk level
                        # 'Over Budget' means actual spend has already exceeded the budget.
                        # 'Forecast Over' means actual is still within budget but the
                        # month-end forecast is projected to exceed it (early warning).
                        $risk = if ($pctUsed -gt 100) { 'Over Budget' }
                        elseif ($pctForecast -gt 100) { 'Forecast Over' }
                        elseif ($pctForecast -gt 90) { 'At Risk' }
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
                                PctUsed        = $pctUsed
                                PctForecast    = $pctForecast
                                Risk           = $risk
                                Thresholds     = ($thresholds -join ', ')
                                ContactEmails  = (($contactEmails | Select-Object -Unique) -join ', ')
                                ContactRoles   = (($contactRoles  | Select-Object -Unique) -join ', ')
                                TagFilter      = $tagFilterStr
                                Currency       = if ($CostData -and $CostData.ContainsKey($sub.Id)) { $CostData[$sub.Id].Currency } else { 'USD' }
                            })
                    }
                }
                else {
                    $subsWithoutBudget++
                }
            }
            else {
                $subsWithoutBudget++
            }
        }
        catch {
            Write-Warning "  Budget query failed for $($sub.Name): $($_.Exception.Message)"
            $subsWithoutBudget++
        }
    }

    # Count risk levels
    # OverBudgetCount = actual spend already exceeded budget (urgent / red).
    # AtRiskCount = forecast-driven warnings (projected over, or trending high).
    $overBudget = @($budgets | Where-Object { $_.Risk -eq 'Over Budget' }).Count
    $atRisk = @($budgets | Where-Object { $_.Risk -in @('Forecast Over', 'At Risk') }).Count

    return [PSCustomObject]@{
        Budgets           = @($budgets)
        TotalBudgets      = $budgets.Count
        SubsWithBudget    = $subsWithBudget
        SubsWithoutBudget = $subsWithoutBudget
        OverBudgetCount   = $overBudget
        AtRiskCount       = $atRisk
        HasData           = ($budgets.Count -gt 0)
        Sampled           = $sampled
        BudgetCoverage    = if ($Subscriptions.Count -gt 0) {
            [math]::Round(($subsWithBudget / $Subscriptions.Count) * 100, 1)
        }
        else { 0 }
    }
}

function Get-BudgetHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Budgets,

        [Parameter()]
        [int]$MonthsBack = 6
    )

    if (-not $Budgets -or $Budgets.Count -eq 0) { return @() }

    $history = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Group budgets by subscription to minimize API calls
    $bySubId = $Budgets | Group-Object SubscriptionId

    foreach ($subGroup in $bySubId) {
        $subId = $subGroup.Name
        $subName = $subGroup.Group[0].Subscription

        # Query monthly costs for this sub over the last N months
        $startDate = (Get-Date).AddMonths(-$MonthsBack).ToString('yyyy-MM-01')
        $endDate = (Get-Date -Day 1).AddDays(-1).ToString('yyyy-MM-dd')  # Last day of previous month

        $body = @{
            type       = 'ActualCost'
            timeframe  = 'Custom'
            timePeriod = @{ from = $startDate; to = $endDate }
            dataset    = @{
                granularity = 'Monthly'
                aggregation = @{
                    totalCost = @{ name = 'Cost'; function = 'Sum' }
                }
            }
        } | ConvertTo-Json -Depth 10

        $costPath = "/subscriptions/$subId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $costPath -Method POST -Payload $body
            if ($resp.StatusCode -ne 200) { continue }

            $result = ($resp.Content | ConvertFrom-Json)
            if (-not $result.properties -or -not $result.properties.rows) { continue }

            # Parse columns
            $cols = $result.properties.columns
            $costIdx = -1; $dateIdx = -1; $currIdx = -1
            for ($i = 0; $i -lt $cols.Count; $i++) {
                $n = $cols[$i].name.ToLower()
                if ($n -eq 'cost' -or $n -eq 'totalcost' -or $n -match 'pretaxcost') { $costIdx = $i }
                elseif ($n -match 'billingmonth|usagedate') { $dateIdx = $i }
                elseif ($n -match 'currency|billingcurrency') { $currIdx = $i }
            }
            if ($costIdx -eq -1) { $costIdx = 0 }
            if ($dateIdx -eq -1) { $dateIdx = 1 }
            if ($currIdx -eq -1) { $currIdx = 2 }

            # Build month → cost lookup
            $monthlyCosts = @{}
            foreach ($row in $result.properties.rows) {
                $cost = [math]::Round([double]$row[$costIdx], 2)
                $rawDate = $row[$dateIdx]
                # Parse date robustly — API may return a [datetime], a YYYYMMDD
                # integer (e.g. 20260101), or a locale-formatted string
                # (e.g. "1/1/2026 12:00:00 AM"). Avoid substring slicing, which
                # mangles non-ISO date formats and zeroes out actual spend.
                $parsed = $null
                if ($rawDate -is [datetime]) {
                    $parsed = $rawDate
                }
                else {
                    $dateStr = "$rawDate"
                    $digitsOnly = $dateStr -replace '[^0-9]', ''
                    if ($digitsOnly.Length -eq 8 -and $dateStr -notmatch '[/\-:]') {
                        $parsed = [datetime]::ParseExact($digitsOnly, 'yyyyMMdd', $null)
                    }
                    else {
                        try { $parsed = [datetime]::Parse($dateStr) } catch { continue }
                    }
                }
                $monthKey = $parsed.ToString('yyyy-MM')
                $monthlyCosts[$monthKey] = $cost
            }

            # Now create history rows per budget per month
            foreach ($budget in $subGroup.Group) {
                $budgetAmount = [double]$budget.Amount
                # For quarterly/annual budgets, pro-rate to monthly equivalent
                $monthlyAmount = switch ($budget.TimeGrain) {
                    'Quarterly' { [math]::Round($budgetAmount / 3, 2) }
                    'Annually' { [math]::Round($budgetAmount / 12, 2) }
                    default { $budgetAmount }
                }

                for ($m = $MonthsBack; $m -ge 1; $m--) {
                    $monthDate = (Get-Date).AddMonths(-$m)
                    $monthKey = $monthDate.ToString('yyyy-MM')
                    $monthLabel = $monthDate.ToString('MMM yyyy')
                    $actual = if ($monthlyCosts.ContainsKey($monthKey)) { $monthlyCosts[$monthKey] } else { 0 }
                    $pctUsed = if ($monthlyAmount -gt 0) { [math]::Round(($actual / $monthlyAmount) * 100, 1) } else { 0 }
                    $status = if ($pctUsed -gt 100) { 'Over' }
                    elseif ($pctUsed -gt 90) { 'Near Limit' }
                    else { 'Under' }

                    [void]$history.Add([PSCustomObject]@{
                            Subscription = $subName
                            BudgetName   = $budget.BudgetName
                            Month        = $monthLabel
                            MonthSort    = $monthKey
                            BudgetAmount = $monthlyAmount
                            ActualSpend  = $actual
                            PctUsed      = $pctUsed
                            Status       = $status
                            Currency     = $budget.Currency
                        })
                }
            }
        }
        catch {
            Write-Warning "  Budget history query failed for $subName : $($_.Exception.Message)"
        }
    }

    return @($history | Sort-Object Subscription, BudgetName, MonthSort)
}
