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
            } catch { }
        }

        if ($sampleHits -eq 0) {
            Write-Host "  No budgets found in sample of $sampleSize subs - skipping remaining" -ForegroundColor Yellow
            $sampled = $true
            $subsWithoutBudget = $subCount
            $subsToQuery = @()   # Skip the main loop
        } else {
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
                        $amount     = [math]::Round([double]$bp.amount, 2)
                        $timeGrain  = $bp.timeGrain
                        $category   = $bp.category

                        # Current spend from our existing cost data
                        $actualSpend = 0
                        $forecast    = 0
                        if ($CostData -and $CostData.ContainsKey($sub.Id)) {
                            $actualSpend = [math]::Round($CostData[$sub.Id].Actual, 2)
                            $forecast    = [math]::Round($CostData[$sub.Id].Forecast, 2)
                        }

                        # Calculate % used
                        $pctUsed = if ($amount -gt 0) { [math]::Round(($actualSpend / $amount) * 100, 1) } else { 0 }
                        $pctForecast = if ($amount -gt 0) { [math]::Round(($forecast / $amount) * 100, 1) } else { 0 }

                        # Risk level
                        $risk = if ($pctForecast -gt 100) { 'Over Budget' }
                                elseif ($pctForecast -gt 90) { 'At Risk' }
                                elseif ($pctForecast -gt 75) { 'Watch' }
                                else { 'On Track' }

                        # Notification thresholds and contacts
                        $thresholds    = @()
                        $contactEmails = @()
                        $contactRoles  = @()
                        if ($bp.notifications) {
                            foreach ($notif in $bp.notifications.PSObject.Properties) {
                                $np = $notif.Value
                                $thresholds += "$($np.threshold)% ($($np.operator))"
                                if ($np.contactEmails) { $contactEmails += @($np.contactEmails) }
                                if ($np.contactRoles)  { $contactRoles  += @($np.contactRoles) }
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
                            Subscription     = $sub.Name
                            SubscriptionId   = $sub.Id
                            BudgetName       = $budget.name
                            Amount           = $amount
                            TimeGrain        = $timeGrain
                            Category         = $category
                            ActualSpend      = $actualSpend
                            Forecast         = $forecast
                            PctUsed          = $pctUsed
                            PctForecast      = $pctForecast
                            Risk             = $risk
                            Thresholds       = ($thresholds -join ', ')
                            ContactEmails    = (($contactEmails | Select-Object -Unique) -join ', ')
                            ContactRoles     = (($contactRoles  | Select-Object -Unique) -join ', ')
                            TagFilter        = $tagFilterStr
                            Currency         = if ($CostData -and $CostData.ContainsKey($sub.Id)) { $CostData[$sub.Id].Currency } else { 'USD' }
                        })
                    }
                } else {
                    $subsWithoutBudget++
                }
            } else {
                $subsWithoutBudget++
            }
        } catch {
            Write-Warning "  Budget query failed for $($sub.Name): $($_.Exception.Message)"
            $subsWithoutBudget++
        }
    }

    # Count risk levels
    $overBudget = @($budgets | Where-Object { $_.Risk -eq 'Over Budget' }).Count
    $atRisk     = @($budgets | Where-Object { $_.Risk -eq 'At Risk' }).Count

    return [PSCustomObject]@{
        Budgets             = @($budgets)
        TotalBudgets        = $budgets.Count
        SubsWithBudget      = $subsWithBudget
        SubsWithoutBudget   = $subsWithoutBudget
        OverBudgetCount     = $overBudget
        AtRiskCount         = $atRisk
        HasData             = ($budgets.Count -gt 0)
        Sampled             = $sampled
        BudgetCoverage      = if ($Subscriptions.Count -gt 0) {
            [math]::Round(($subsWithBudget / $Subscriptions.Count) * 100, 1)
        } else { 0 }
    }
}
