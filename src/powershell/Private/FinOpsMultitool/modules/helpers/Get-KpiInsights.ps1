# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Accepted for signature parity; callers pass -Catalog across the KPI helper family.')]
param()

###########################################################################
# GET-KPIINSIGHTS.PS1
# FINOPS KPI CORRELATION LAYER
###########################################################################
# Purpose: Map FinOps Multitool scan output to FinOps Foundation KPIs
#          (https://www.finops.org/finops-kpis/) so callers who do not
#          know the KPI taxonomy still see which industry KPIs their results
#          inform, with a computed value where the data allows.
# Date: Created for KPI skills
#
# Description:
# Additive only. Does not change any scan. After a scan returns, the
# server calls Add-KpiInsights to attach a kpiInsights[] block:
#   - status 'computed'      a value was derived from the scan fields
#   - status 'informational' the scan relates to the KPI; explore to learn
# Two public entry points:
#   Add-KpiInsights      enrich a tool result in place (server-side)
#   Get-KpiExploration   browse the catalog (explore_finops_kpis tool)
#
# Usage: dot-sourced by FinOpsMultitool.psm1
###########################################################################

$script:KpiCatalog = $null

# Canonical CAF allocation (chargeback/showback) tag dimensions. Cost-allocation
# coverage is measured ONLY against these - not identity/marker tags (FinOps,
# cm-resource-parent, tag1, managedBy, CreatedByPolicy, ...) that blanket
# resources and would give a misleading untagged figure. Single source of truth
# shared by the KPI compute and the TUI cost-by-tag guidance so they agree.
function Get-CafAllocationTag {
    return @('CostCenter', 'Customer', 'Project', 'Environment', 'Application',
        'Owner', 'BusinessUnit', 'Department', 'Team', 'Service', 'WorkloadName')
}

function Get-KpiCatalog {
    if ($script:KpiCatalog) { return $script:KpiCatalog }
    # kpi-catalog.json lives in ../kpi relative to modules/helpers
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $path = Join-Path (Join-Path $root 'kpi') 'kpi-catalog.json'
    if (-not (Test-Path $path)) {
        # Fall back to ScriptRootDir if structure differs
        if ($script:ScriptRootDir) {
            $path = Join-Path (Join-Path $script:ScriptRootDir 'kpi') 'kpi-catalog.json'
        }
    }
    if (-not (Test-Path $path)) { return $null }
    $script:KpiCatalog = Get-Content $path -Raw | ConvertFrom-Json
    return $script:KpiCatalog
}

# Pull a property value off a scan-result object whether it is the object
# itself or wrapped in a .data property (server wrapper).
function Get-ScanField {
    param($Data, [string]$Name)
    if ($null -eq $Data) { return $null }
    if ($Data.PSObject.Properties[$Name]) { return $Data.$Name }
    if ($Data.PSObject.Properties['data'] -and $Data.data.PSObject.Properties[$Name]) { return $Data.data.$Name }
    return $null
}

# Compute a KPI value from scan data where we have a real formula. Returns
# a string value or $null when it cannot be computed (stays informational).
# Display is what a human reads; Value is the same figure as a number so scoring
# never has to recompute (and diverge from) the displayed math.
function New-KpiValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory object and changes no state.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Display, $Value = $null)
    [PSCustomObject]@{ Display = $Display; Value = $Value }
}

# Returns the utilization figures that were actually measured. A family with no
# commitments reports 0, which would otherwise read as a measured 0% and halve
# the average for anyone who owns reservations but no savings plans.
function Get-CommitmentUtilizationValue {
    param($Data)

    $vals = @()
    if ([int](Get-ScanField $Data 'RICount') -gt 0) {
        $ri = Get-ScanField $Data 'RIAvgUtilization'
        if ($null -ne $ri) { $vals += [double]$ri }
    }
    if ([int](Get-ScanField $Data 'SPCount') -gt 0) {
        $sp = Get-ScanField $Data 'SPAvgUtilization'
        if ($null -ne $sp) { $vals += [double]$sp }
    }
    return $vals
}

function Get-BudgetKpiData {
    param($Data)

    $budgets = @(Get-ScanField $Data 'Budgets')
    if (-not $budgets -or (Get-ScanField $Data 'CoverageIncomplete')) {
        return @{ Error = 'Unavailable: budget inventory is incomplete.' }
    }
    $currency = $null
    $timeGrain = $null
    $subscriptions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $percentages = [System.Collections.Generic.List[double]]::new()
    $totalBudget = 0.0
    $totalActual = 0.0
    $now = (Get-Date).ToUniversalTime()
    $monthStart = $now.Date.AddDays(1 - $now.Day)
    foreach ($budget in $budgets) {
        if ($budget.Category -ne 'Cost' -or -not $budget.Currency -or -not $budget.TimeGrain -or
            $budget.SpendSource -eq 'Unavailable' -or -not $budget.SubscriptionId) {
            return @{ Error = 'Unavailable: budget amounts, scope, units, or current spend are unknown.' }
        }
        try {
            if ($budget.TimeGrain -ne 'Monthly' -or -not $budget.TimePeriod.startDate -or
                ([datetime]$budget.TimePeriod.startDate).ToUniversalTime() -gt $monthStart -or
                ($budget.TimePeriod.endDate -and ([datetime]$budget.TimePeriod.endDate).ToUniversalTime() -lt $now)) {
                return @{ Error = 'Unavailable: budgets do not have a verified common current-month window.' }
            }
        }
        catch { return @{ Error = 'Unavailable: a budget reporting period is invalid.' } }
        if (($currency -and $currency -ne $budget.Currency) -or ($timeGrain -and $timeGrain -ne $budget.TimeGrain)) {
            return @{ Error = 'Unavailable: budget currencies or reporting periods differ.' }
        }
        if (-not $subscriptions.Add([string]$budget.SubscriptionId)) {
            return @{ Error = 'Unavailable: multiple budgets can overlap within a subscription.' }
        }
        try {
            $amount = Get-HubCostValue -Row $budget -Column 'Amount'
            $actual = Get-HubCostValue -Row $budget -Column 'ActualSpend'
            if ($amount -le 0) { throw 'Budget amount must be positive.' }
        }
        catch { return @{ Error = 'Unavailable: a budget amount or current spend is invalid.' } }
        $currency = $budget.Currency
        $timeGrain = $budget.TimeGrain
        $totalBudget += $amount
        $totalActual += $actual
        [void]$percentages.Add(100 * $actual / $amount)
    }
    return @{ Error = $null; Currency = $currency; TotalBudget = $totalBudget; TotalActual = $totalActual; Percentages = $percentages.ToArray() }
}

function Format-FinOpsUnitRate {
    param($Value, [string]$Currency)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Currency)) { return 'Unavailable' }
    try {
        $amount = Get-HubCostValue -Row ([pscustomobject]@{ Value = $Value }) -Column 'Value'
        $format = if ($amount -ne 0 -and [math]::Abs($amount) -lt 0.00000001) { '0.########E+0' } else { '0.########' }
        return "$Currency $($amount.ToString($format, [cultureinfo]::InvariantCulture))"
    }
    catch { return 'Unavailable' }
}

function Get-FinOpsUnitCostContext {
    param($Data)

    $currency = [string](Get-ScanField $Data 'Currency')
    $subtotal = $null
    if ($currency -match '^[A-Za-z]{3}$' -and $currency -notin @('XXX', 'XTS') -and
        -not (Get-ScanField $Data 'CostIssue') -and (Get-ScanField $Data 'CostAvailable') -ne $false) {
        try {
            $compute = Get-HubCostValue -Row $Data -Column 'ComputeCost'
            $storage = Get-HubCostValue -Row $Data -Column 'StorageCost'
            $sum = $compute + $storage
            if (-not [double]::IsNaN($sum) -and -not [double]::IsInfinity($sum)) { $subtotal = $sum }
        }
        catch { $subtotal = $null }
    }
    $period = 'Cost period unavailable'
    $start = Get-ScanField $Data 'CostPeriodStartUtc'
    $end = Get-ScanField $Data 'CostPeriodEndUtc'
    if ($null -ne $start -and $null -ne $end) {
        try {
            $start = ([datetime]$start).ToUniversalTime()
            $end = ([datetime]$end).ToUniversalTime()
            if ($end -gt $start) {
                $period = '{0} to {1} UTC' -f $start.ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture), $end.ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
            }
        }
        catch { $period = 'Cost period unavailable' }
    }
    $amount = Format-BudgetAmount -Value $subtotal -Currency $currency
    return [pscustomobject]@{
        Summary = "Amortized cost for selected subscriptions. Period: $period. Subtotal: $amount. Other Azure services are excluded. This is a cost distribution, not an efficiency score."
        Formula = 'Category share = category cost / (VM compute cost + storage cost) x 100. Shares are unavailable when the subtotal is not positive.'
        Capacity = 'Unit rates divide period cost by current inventory: all VMs, including stopped VMs; provisioned managed-disk capacity plus measured storage-account used capacity. These are not time-weighted running-resource rates.'
        Target = 'No universal target split applies. Compare unit costs for the same workload, scope, currency, period, capacity basis, and service requirements. A lower rate alone does not prove better efficiency.'
    }
}

function Get-FinOpsScanContext {
    param([string]$FunctionName, $Data)

    switch ($FunctionName) {
        'Get-IdleVMs' {
            $evaluated = Get-ScanField $Data 'EvaluatedVMs'
            $evaluatedLabel = if ($null -ne $evaluated) { [string]$evaluated } else { 'Unknown' }
            return [pscustomobject]@{
                Summary = "Evaluated: $evaluatedLabel of $($Data.ScannedVMs) running VMs. Missing CPU or network measurements leave a VM unevaluated, not active or idle."
                Details = @(
                    'Window: the 14 days preceding this scan, using available Azure Monitor measurements. Idle requires average CPU <5% AND combined network <1 MiB/day (14 MiB across the window).'
                    'Otherwise, underutilized requires average CPU <10% AND combined network <10 MiB/day (140 MiB across the window). These are scanner thresholds, not Azure Advisor criteria.'
                    'Only currently running VMs are candidates. Averages can hide bursts; memory, disk activity, availability requirements, and workload purpose are not assessed. No returned candidate is not proof of optimized compute spend.'
                )
            }
        }
        'Get-StorageTierAdvice' {
            $evaluated = Get-ScanField $Data 'EvaluatedAccounts'
            $evaluatedLabel = if ($null -ne $evaluated) { [string]$evaluated } else { 'Unknown' }
            return [pscustomobject]@{
                Summary = "Evaluated: $evaluatedLabel of $($Data.TotalHotAccounts) storage accounts with Hot or unspecified default tier. Missing transaction or capacity measurements leave an account unevaluated."
                Details = @(
                    'Window: the 30 days preceding this scan. Archive candidate: fewer than 100 blob transactions and rounded reported capacity greater than zero.'
                    'Otherwise, Cool candidate: fewer than 1,000 blob transactions and reported capacity greater than 1 GiB. Capacity is the largest returned time-series average, rounded to two decimal places; display labels GB/MB use binary units.'
                    'This is account-level screening, not per-blob last-access analysis. Active accounts can contain cold blobs; the account default does not establish every blob tier.'
                    'Validate tier eligibility, retrieval costs, access latency, and retention before changing tiers. The scan does not model a net saving; its 50%/90% estimates are assumptions. Archive is offline and has a 180-day minimum retention charge.'
                )
            }
        }
        'Get-BudgetStatus' {
            $budgets = @($Data.Budgets | Where-Object { $null -ne $_ })
            $available = 0
            foreach ($budget in $budgets) {
                if ($budget.ForecastSource -eq 'Unavailable' -or $budget.Currency -notmatch '^[A-Za-z]{3}$' -or $budget.Currency -in @('XXX', 'XTS')) { continue }
                try {
                    $null = Get-HubCostValue -Row $budget -Column 'Forecast'
                    $available++
                }
                catch { continue }
            }
            return [pscustomobject]@{
                Summary = "Forecasts available: $available of $($budgets.Count); $($budgets.Count - $available) unavailable. A zero at-risk count is not an all-clear when forecasts are missing."
                Details = @(
                    'Budget coverage = selected subscriptions with at least one budget / selected subscriptions x 100. It is not spend coverage or forecast availability. Unreadable subscriptions leave coverage unverified.'
                    'PctUsed = current spend / budget amount x 100, using each budget scope, filters, currency, and reset period. Budget scopes can overlap; do not add their amounts or spend as a subscription total.'
                    'Risk checks, in priority order: a missing or invalid budget amount is Unknown; actual >100% is Over Budget; forecast >100% is Forecast Over; missing current spend is Unknown; forecast >90% is At Risk; actual >90% is Near Limit; an unavailable forecast is Forecast unavailable; forecast >75% is Watch; otherwise On Track. Unknown amounts or forecasts are not replaced with zero.'
                    'There is no universal target burn rate. Compare the budget reset period, expected workload demand, and available forecast with the planned spending profile.'
                )
            }
        }
    }
    return $null
}

function Get-KpiComputedValue {
    param([string]$KpiId, $Data, $Catalog)

    if ($KpiId -in @('cost-per-gb-stored', 'hourly-cost-per-cpu-core', 'effective-avg-compute-cost-per-core')) {
        $costIssue = Get-ScanField $Data 'CostIssue'
        $currency = [string](Get-ScanField $Data 'Currency')
        if ($costIssue) { return (New-KpiValue "Unavailable: $costIssue") }
        if ($currency -notmatch '^[A-Za-z]{3}$' -or $currency -in @('XXX', 'XTS')) {
            return (New-KpiValue 'Unavailable: one known billing currency is required.')
        }
        if ((Get-ScanField $Data 'CostAvailable') -eq $false) { return (New-KpiValue 'Unavailable: cost measurements could not be verified.') }
        $field = if ($KpiId -eq 'cost-per-gb-stored') { 'CostPerGb' } else { 'CostPerVCpu' }
        if ($null -eq (Get-ScanField $Data $field)) { return $null }
        try { $unitRate = Get-HubCostValue -Row ([pscustomobject]@{ Value = (Get-ScanField $Data $field) }) -Column 'Value' }
        catch { return (New-KpiValue 'Unavailable: a finite numeric unit rate is required.') }
    }

    switch ($KpiId) {
        'cost-per-gb-stored' {
            $v = $unitRate
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -ge 0) { return (New-KpiValue "$(Format-FinOpsUnitRate -Value $v -Currency $cur) per GB (month-to-date)" ([double]$v)) }
        }
        'hourly-cost-per-cpu-core' {
            $v = $unitRate
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -ge 0) {
                $periodStart = Get-ScanField $Data 'CostPeriodStartUtc'
                $periodEnd = Get-ScanField $Data 'CostPeriodEndUtc'
                if ($null -ne $periodStart -and $null -ne $periodEnd) {
                    $periodStart = ([datetime]$periodStart).ToUniversalTime()
                    $periodEnd = ([datetime]$periodEnd).ToUniversalTime()
                }
                else {
                    $periodEnd = (Get-Date).ToUniversalTime()
                    $periodStart = $periodEnd.Date.AddDays(1 - $periodEnd.Day)
                }
                $elapsedHours = [math]::Max(($periodEnd - $periodStart).TotalHours, 1)
                $hourly = [double]$v / $elapsedHours
                return (New-KpiValue "$(Format-FinOpsUnitRate -Value $hourly -Currency $cur) per vCPU / hour" $hourly)
            }
        }
        'effective-avg-compute-cost-per-core' {
            $v = $unitRate
            $cur = Get-ScanField $Data 'Currency'
            # Month-to-date, not a full month, so say so rather than implying a run rate.
            if ($null -ne $v -and $v -ge 0) { return (New-KpiValue "$(Format-FinOpsUnitRate -Value $v -Currency $cur) per vCPU (month-to-date)" ([double]$v)) }
        }
        'commitment-utilization-score' {
            # Get-CommitmentUtilization seeds both averages to 0 and only fills the
            # ones it found, so 0 usually means "none of this kind" (or access
            # denied) rather than a measured 0%. Gate on the counts: a real 0% with
            # commitments present still counts, an absent family does not drag the
            # average down.
            $vals = @(Get-CommitmentUtilizationValue -Data $Data)
            if ($vals.Count -gt 0) {
                $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1)
                return (New-KpiValue "$avg%" $avg)
            }
        }
        'anomaly-detection-rate' {
            if (Get-ScanField $Data 'CoverageIncomplete') { return (New-KpiValue 'Unavailable: alert and rule coverage is incomplete.') }
            # No true rate is possible (Azure does not expose how many anomalies
            # actually occurred, only what it caught). Report an honest PROXY:
            # anomaly alerts triggered + detection rules configured. Both are
            # countable. Returns $null only when neither field is present.
            $anom = Get-ScanField $Data 'AnomalyAlertCount'
            $rules = Get-ScanField $Data 'ConfiguredRuleCount'
            if ($null -ne $anom -or $null -ne $rules) {
                $a = if ($null -ne $anom) { [int]$anom } else { 0 }
                $r = if ($null -ne $rules) { [int]$rules } else { 0 }
                $alertWord = if ($a -eq 1) { 'alert' } else { 'alerts' }
                $ruleWord = if ($r -eq 1) { 'rule' } else { 'rules' }
                # Score on rules configured: that is the controllable maturity signal.
                return (New-KpiValue "$a anomaly $alertWord caught, $r detection $ruleWord configured (proxy)" $r)
            }
        }
        'percent-unused-resources' {
            # No per-orphan cost in the scan, so report the orphaned-resource
            # count (still a concrete waste signal).
            $n = Get-ScanField $Data 'TotalCount'
            if ($null -ne $n) {
                $word = if ([int]$n -eq 1) { 'orphaned resource' } else { 'orphaned resources' }
                return (New-KpiValue "$([int]$n) $word" ([int]$n))
            }
        }
        'computational-waste' {
            if ((Get-ScanField $Data 'MetricFailures') -gt 0) { return (New-KpiValue 'Unavailable: VM utilization coverage is incomplete.') }
            # Share of running VMs flagged idle/underutilized.
            $idle = Get-ScanField $Data 'Count'
            $scanned = Get-ScanField $Data 'ScannedVMs'
            if ($null -ne $idle -and $null -ne $scanned -and [int]$scanned -gt 0) {
                $pct = [math]::Round(100 * [int]$idle / [int]$scanned, 1)
                return (New-KpiValue "$pct% of running VMs idle ($([int]$idle) of $([int]$scanned))" $pct)
            }
        }
        'budget-burn-rate' {
            $budgetData = Get-BudgetKpiData -Data $Data
            if ($budgetData.Error) { return (New-KpiValue $budgetData.Error) }
            $pcts = $budgetData.Percentages
            $avg = [math]::Round(($pcts | Measure-Object -Average).Average, 1)
            $word = if ($pcts.Count -eq 1) { 'budget' } else { 'budgets' }
            return (New-KpiValue "$avg% of budget consumed (average of $($pcts.Count) comparable $word)" $avg)
        }
        'variance-budget-vs-actual' {
            $budgetData = Get-BudgetKpiData -Data $Data
            if ($budgetData.Error) { return (New-KpiValue $budgetData.Error) }
            $totBudget = $budgetData.TotalBudget
            $totActual = $budgetData.TotalActual
            $cur = $budgetData.Currency
            $pctOfPlan = [math]::Round(100 * $totActual / $totBudget, 1)
            $spend = '{0:N0}' -f [math]::Round([double]$totActual, 0)
            $plan = '{0:N0}' -f [math]::Round([double]$totBudget, 0)
            $variance = [math]::Abs([math]::Round(100 * ($totActual - $totBudget) / $totBudget, 1))
            return (New-KpiValue "Actual is $pctOfPlan% of planned ($cur $spend of $cur $plan, comparable budgets)" $variance)
        }
        'effective-savings-rate' {
            $savings = Get-ScanField $Data 'CommitmentSavingsMonthToDate'
            $cur = Get-ScanField $Data 'Currency'
            if (-not $cur) { return (New-KpiValue 'Unavailable: savings currency is unknown.') }
            $period = Get-ScanField $Data 'Period'
            if ($null -eq $savings -or -not $period -or [double]$savings -lt 0 -or [double]::IsNaN($savings) -or [double]::IsInfinity($savings)) {
                return (New-KpiValue 'Unavailable: a valid commitment estimate and cost period are required.')
            }
            return (New-KpiValue "$cur $([math]::Round([double]$savings, 2)) estimated savings ($period; assumed discounts, not a measured rate)" ([math]::Round([double]$savings, 2)))
        }
        'pct-compute-covered-by-commitment' {
            # Commitment coverage = committed eligible spend / total eligible
            # spend (excludes Spot). Computed in Get-SavingsRealized from
            # amortized cost grouped by pricing model.
            $cov = Get-ScanField $Data 'CommitmentCoveragePct'
            $committed = Get-ScanField $Data 'CommittedAmortized'
            $onDemand = Get-ScanField $Data 'OnDemandAmortized'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $cov) {
                $detail = ''
                if ($cur -and $null -ne $committed -and $null -ne $onDemand) {
                    $base = [double]$committed + [double]$onDemand
                    $detail = " ($cur $([math]::Round([double]$committed, 0)) committed of $cur $([math]::Round($base, 0)) eligible)"
                }
                return (New-KpiValue "$cov% covered by commitments$detail" ([double]$cov))
            }
        }
        'token-consumption-metrics' {
            $tokens = Get-ScanField $Data 'TotalTokens'
            $cost = Get-ScanField $Data 'TotalAICost'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $tokens -and [long]$tokens -gt 0) {
                $costStr = if ($null -ne $cost -and [double]$cost -gt 0 -and $cur -match '^[A-Za-z]{3}$' -and $cur -notin @('XXX', 'XTS') -and
                    -not (Get-ScanField $Data 'CostIssue')) { " for $cur $([math]::Round([double]$cost, 2))" } else { '' }
                $period = Get-ScanField $Data 'Period'
                if ($period -eq 'MonthToDate') { $period = 'Month to date' }
                elseif (-not $period) { $period = 'Unknown period' }
                return (New-KpiValue "$('{0:N0}' -f [long]$tokens) tokens$costStr ($period)" ([long]$tokens))
            }
        }
        'cost-per-api-call' {
            $cpr = Get-ScanField $Data 'CostPerRequest'
            $cur = Get-ScanField $Data 'Currency'
            $costIssue = Get-ScanField $Data 'CostIssue'
            if ($costIssue) { return (New-KpiValue "Unavailable: $costIssue") }
            $rateIssue = Get-ScanField $Data 'RateIssue'
            if ($rateIssue) { return (New-KpiValue "Unavailable: $rateIssue") }
            if ($cur -notmatch '^[A-Za-z]{3}$' -or $cur -in @('XXX', 'XTS')) { return (New-KpiValue 'Unavailable: one known AI billing currency is required.') }
            if ($null -ne $cpr -and [double]$cpr -ge 0) {
                return (New-KpiValue "$cur $([math]::Round([double]$cpr, 5)) per AI request" ([math]::Round([double]$cpr, 5)))
            }
            return (New-KpiValue 'Unavailable: comparable AI costs and measured request counts are required.')
        }
        'pct-commitment-discount-waste' {
            $vals = @(Get-CommitmentUtilizationValue -Data $Data)
            if ($vals.Count -gt 0) {
                $avg = ($vals | Measure-Object -Average).Average
                $waste = [math]::Round(100 - $avg, 1)
                return (New-KpiValue "$waste%" $waste)
            }
        }
        { $_ -in @('pct-costs-untagged', 'pct-costs-unallocated', 'tagging-policy-compliant') } {
            if (Get-ScanField $Data 'CoverageIncomplete') {
                return (New-KpiValue 'Unavailable: cost coverage is incomplete; allocation cannot be scored for the whole selected scope.')
            }
            # Prefer the per-resource allocation figure: a resource counts once,
            # and is allocated if it carries any CAF allocation tag. Per-tag
            # totals cannot answer this because a resource shows as untagged
            # under every tag it lacks, so summing them double-counts.
            $seen = Get-ScanField $Data 'ResourceCostSeen'
            $unalloc = Get-ScanField $Data 'UnallocatedCost'
            if ($null -ne $seen -and $null -ne $unalloc) {
                if ([double]$seen -le 0 -or [double]::IsNaN($seen) -or [double]::IsInfinity($seen) -or
                    [double]::IsNaN($unalloc) -or [double]::IsInfinity($unalloc)) {
                    return (New-KpiValue 'Unavailable: allocation percentages require finite amounts and a positive net cost total.')
                }
                if ([double]$unalloc -lt 0 -or [double]$unalloc -gt [double]$seen) {
                    return (New-KpiValue 'Unavailable: credits or negative net costs prevent a comparable allocation percentage.')
                }
                $pct = [math]::Round(100 * [double]$unalloc / [double]$seen, 1)
                switch ($KpiId) {
                    'pct-costs-untagged' { return (New-KpiValue "$pct% of resource spend carries no allocation tag" $pct) }
                    'pct-costs-unallocated' { return (New-KpiValue "$pct% unallocated across all allocation tags" $pct) }
                    'tagging-policy-compliant' { return (New-KpiValue "$([math]::Round(100 - $pct, 1))% of resource spend is allocated" ([math]::Round(100 - $pct, 1))) }
                }
            }

            # Fallback for sources that aggregate server-side and never walk
            # resources. Report the WORST-covered allocation tag: the best-covered
            # one flatters the estate and hides the gap.
            $cbt = Get-ScanField $Data 'CostByTag'
            if (-not $cbt) { return $null }
            $allocTags = Get-CafAllocationTag
            $tagPairs = @()
            if ($cbt -is [System.Collections.IDictionary]) {
                foreach ($k in $cbt.Keys) { $tagPairs += [PSCustomObject]@{ Name = $k; Value = $cbt[$k] } }
            }
            else {
                foreach ($prop in $cbt.PSObject.Properties) { $tagPairs += [PSCustomObject]@{ Name = $prop.Name; Value = $prop.Value } }
            }
            $worst = $null
            foreach ($tp in $tagPairs) {
                if ($allocTags -notcontains $tp.Name) { continue }   # allocation tags only
                $rows = @($tp.Value)
                if ($rows.Count -eq 0) { continue }
                $total = ($rows | Measure-Object -Property Cost -Sum).Sum
                if ($null -eq $total -or $total -le 0 -or [double]::IsNaN($total) -or [double]::IsInfinity($total)) {
                    return (New-KpiValue 'Unavailable: allocation percentages require finite amounts and a positive net cost total.')
                }
                if (@($rows | Where-Object { [double]$_.Cost -lt 0 }).Count -gt 0) {
                    return (New-KpiValue 'Unavailable: credits or negative net costs prevent a comparable allocation percentage.')
                }
                $untag = ($rows | Where-Object { $_.TagValue -eq '(untagged)' } | Measure-Object -Property Cost -Sum).Sum
                if ($null -eq $untag) { $untag = 0 }
                $pctUntag = [math]::Round(100 * $untag / $total, 1)
                if ($null -eq $worst -or $pctUntag -gt $worst.PctUntag) {
                    $worst = [PSCustomObject]@{ Tag = $tp.Name; PctUntag = $pctUntag }
                }
            }
            if ($null -eq $worst) { return $null }   # no allocation tags -> stays informational
            switch ($KpiId) {
                'pct-costs-untagged' { return (New-KpiValue "$($worst.PctUntag)% untagged (worst allocation tag: '$($worst.Tag)')" $worst.PctUntag) }
                'pct-costs-unallocated' { return (New-KpiValue "$($worst.PctUntag)% unallocated (worst: '$($worst.Tag)')" $worst.PctUntag) }
                'tagging-policy-compliant' { return (New-KpiValue "$([math]::Round(100 - $worst.PctUntag, 1))% compliant (worst: '$($worst.Tag)')" ([math]::Round(100 - $worst.PctUntag, 1))) }
            }
        }
    }
    return $null
}

# Enrich a server tool-result hashtable in place with a kpiInsights array.
function Add-KpiInsights {
    param([Parameter(Mandatory)]$Result)

    $catalog = Get-KpiCatalog
    if (-not $catalog) { return $Result }

    $toolName = $null
    if ($Result -is [hashtable]) { $toolName = $Result['tool'] }
    elseif ($Result.PSObject.Properties['tool']) { $toolName = $Result.tool }
    if (-not $toolName) { return $Result }

    $matched = @($catalog.kpis | Where-Object { $_.sourceTool -eq $toolName })
    if ($matched.Count -eq 0) { return $Result }

    $data = if ($Result -is [hashtable]) { $Result['data'] } else { $Result.data }

    $insights = @()
    foreach ($kpi in $matched) {
        $value = $null
        if ($kpi.compute) { $value = Get-KpiComputedValue -KpiId $kpi.id -Data $data -Catalog $catalog }
        $status = if ($value -and $null -ne $value.Value) { 'computed' } elseif ($value) { 'unavailable' } else { 'informational' }
        $insights += [PSCustomObject]@{
            kpiId         = $kpi.id
            kpiName       = $kpi.name
            domain        = $kpi.domain
            definition    = $kpi.definition
            status        = $status
            yourValue     = if ($value) { $value.Display } else { $null }
            numericValue  = if ($value) { $value.Value } else { $null }
            plainLanguage = $kpi.plainLanguage
            exploreHint   = $kpi.exploreHint
            learnMore     = $catalog.learnMoreBase
        }
    }

    if ($insights.Count -gt 0) {
        if ($Result -is [hashtable]) { $Result['kpiInsights'] = @($insights) }
        else { $Result | Add-Member -NotePropertyName 'kpiInsights' -NotePropertyValue @($insights) -Force }
    }
    return $Result
}

# Map a raw scan function name (as used by the TUI/automated editions) to the
# scan name the KPI catalog keys off (sourceTool). Lets every caller reuse the
# exact same compute path, so KPI behavior stays in parity.
function Get-KpiScanMap {
    return @{
        'Get-UnitEconomics'               = 'scan_unit_economics'
        'Get-CostByTag'                   = 'scan_cost_by_tag'
        'Get-CommitmentUtilization'       = 'scan_commitment_utilization'
        'Get-ReservationAdvice'           = 'scan_reservation_advice'
        'Get-OrphanedResources'           = 'scan_orphaned_resources'
        'Get-IdleVMs'                     = 'scan_idle_vms'
        'Get-StorageTierAdvice'           = 'scan_storage_tier_advice'
        'Get-BudgetStatus'                = 'scan_budget_status'
        'Get-AnomalyAlerts'               = 'scan_anomaly_alerts'
        'Get-SavingsRealized'             = 'scan_savings_realized'
        'Get-LegacyResources'             = 'scan_legacy_resources'
        'Get-CarbonMetrics'               = 'scan_carbon'
        'Get-AIWorkloadMetrics'           = 'scan_ai_workloads'
        'Get-CostTrend'                   = 'scan_cost_trend'
        'Get-ResourceCosts'               = 'scan_resource_costs'
        'Get-VmCostBreakdown'             = 'scan_vm_cost_breakdown'
        'Get-SharedCostAllocation'        = 'scan_allocate_shared_cost'
        'Get-UsageProportionalAllocation' = 'scan_usage_allocation'
    }
}

function Get-KpiToolNameForFunction {
    param([Parameter(Mandatory)][string]$FunctionName)
    $map = Get-KpiScanMap
    if ($map.ContainsKey($FunctionName)) { return $map[$FunctionName] }
    return $null
}

# Compute the kpiInsights array for a raw scan output (where the result IS the
# data, not a { tool; data } envelope). Wraps the output in the same
# envelope the catalog expects so Add-KpiInsights/Get-KpiComputedValue run the
# identical logic. Returns an array of insight objects (possibly empty).
function Get-KpiInsightsForResult {
    param(
        [Parameter(Mandatory)][string]$FunctionName,
        $Output
    )
    if ($null -eq $Output) { return @() }
    $toolName = Get-KpiToolNameForFunction -FunctionName $FunctionName
    if (-not $toolName) { return @() }
    $envelope = @{ tool = $toolName; data = $Output }
    $enriched = Add-KpiInsights -Result $envelope
    if ($enriched -is [System.Collections.IDictionary] -and $enriched.Contains('kpiInsights')) {
        return @($enriched['kpiInsights'])
    }
    return @()
}

function Get-FinOpsKpiReference {
    param([System.Collections.IDictionary]$Results, [object[]]$Modules, [object[]]$Insights)

    $catalog = Get-KpiCatalog
    if (-not $catalog) { return @() }
    $scanMap = Get-KpiScanMap
    foreach ($kpi in $catalog.kpis) {
        $functionName = $scanMap.Keys | Where-Object { $scanMap[$_] -eq $kpi.sourceTool } | Select-Object -First 1
        $sourceModule = $Modules | Where-Object { $_.Fn -eq $functionName } | Select-Object -First 1
        $selected = $sourceModule | Where-Object Selected
        $status = if ($kpi.compute) { 'Not run' } else { 'Informational' }
        $value = if ($kpi.compute) { 'The source scan was not selected for this report.' } else { 'Reference only. This tool does not calculate this KPI.' }
        $context = $null
        if ($selected) {
            if ($Results.Contains("_error_$functionName")) {
                if ($kpi.compute) {
                    $status = 'Unavailable'
                    $value = [string]$Results["_error_$functionName"]
                }
                else { $context = "Related scan failed: $($Results["_error_$functionName"])" }
            }
            elseif (-not $Results.Contains($functionName) -or $null -eq $Results[$functionName]) {
                if ($kpi.compute) {
                    $status = 'Unavailable'
                    $value = 'The scan returned no result; this is not a measured zero.'
                }
                else { $context = 'The related scan returned no result.' }
            }
            else {
                if ($kpi.compute) {
                    $insight = $Insights | Where-Object { $_.kpiId -eq $kpi.id } | Select-Object -First 1
                    $status = if ($insight.status -eq 'computed' -and $null -ne $insight.numericValue) { 'Computed' } else { 'Unavailable' }
                    $value = if ($insight.yourValue) { [string]$insight.yourValue } else { 'Required comparable measurements were not available in this run.' }
                }
                if ($functionName -eq 'Get-UnitEconomics') { $context = (Get-FinOpsUnitCostContext -Data $Results[$functionName]).Summary }
                else { $context = (Get-FinOpsScanContext -FunctionName $functionName -Data $Results[$functionName]).Summary }
            }
        }
        [pscustomobject]@{
            Id = $kpi.id
            Name = $kpi.name
            Definition = $kpi.definition
            Domain = $kpi.domain
            Unit = $kpi.unit
            Calculation = $kpi.calculation
            RequiredInputs = @($kpi.requiredInputs)
            Interpretation = $kpi.interpretation
            Limitations = $kpi.limitations
            Status = $status
            Value = $value
            Context = $context
            SourceFunction = $functionName
            SourceName = if ($sourceModule) { $sourceModule.Name } elseif ($functionName) { $functionName } else { 'Data-source discovery (not a menu scan)' }
            SourceCategory = $selected.Category
            SourceSelected = $null -ne $selected
        }
    }
}

# Browse the KPI catalog for the explore_finops_kpis tool.
function Get-KpiExploration {
    param([string]$KpiId)

    $catalog = Get-KpiCatalog
    if (-not $catalog) { return @{ error = 'KPI catalog not found.' } }

    if ($KpiId) {
        $kpi = $catalog.kpis | Where-Object { $_.id -eq $KpiId } | Select-Object -First 1
        if (-not $kpi) { return @{ error = "Unknown KPI id '$KpiId'. Call explore_finops_kpis with no id to list all." } }
        return @{
            kpi   = [PSCustomObject]@{
                id            = $kpi.id
                name          = $kpi.name
                domain        = $kpi.domain
                definition    = $kpi.definition
                sourceTool    = $kpi.sourceTool
                computable    = [bool]$kpi.compute
                plainLanguage = $kpi.plainLanguage
                exploreHint   = $kpi.exploreHint
                learnMore     = $catalog.learnMoreBase
            }
            howTo = "Run $($kpi.sourceTool) to inform this KPI. $(if ($kpi.compute) { 'The server computes a value from the scan.' } else { 'The scan relates to this KPI; use the explore hint to dig in.' })"
        }
    }

    # No id: list grouped by domain with computable flag
    $byDomain = @{}
    foreach ($kpi in $catalog.kpis) {
        $d = $kpi.domain
        if (-not $byDomain.ContainsKey($d)) { $byDomain[$d] = @() }
        $byDomain[$d] += [PSCustomObject]@{
            id         = $kpi.id
            name       = $kpi.name
            sourceTool = $kpi.sourceTool
            status     = if ($kpi.compute) { 'Computable now' } else { 'Informational (run the tool)' }
        }
    }
    return @{
        catalogVersion = $catalog.version
        totalKpis      = @($catalog.kpis).Count
        learnMore      = $catalog.learnMoreBase
        note           = 'These FinOps Foundation KPIs can be informed by this server today. Run the listed tool, then read the kpiInsights block it returns. More KPIs will be added over time.'
        byDomain       = $byDomain
    }
}
