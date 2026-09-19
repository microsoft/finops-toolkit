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

function Get-KpiComputedValue {
    param([string]$KpiId, $Data, $Catalog)

    switch ($KpiId) {
        'cost-per-gb-stored' {
            $v = Get-ScanField $Data 'CostPerGb'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) { return (New-KpiValue "$(Format-FinOpsUnitRate -Value $v -Currency $cur) per GB (month-to-date)" ([double]$v)) }
        }
        'hourly-cost-per-cpu-core' {
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) {
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
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            # Month-to-date, not a full month, so say so rather than implying a run rate.
            if ($null -ne $v -and $v -gt 0) { return (New-KpiValue "$(Format-FinOpsUnitRate -Value $v -Currency $cur) per vCPU (month-to-date)" ([double]$v)) }
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
            if (-not $cur) { $cur = 'USD' }
            if ($null -ne $tokens -and [long]$tokens -gt 0) {
                $costStr = if ($null -ne $cost -and [double]$cost -gt 0) { " for $cur $([math]::Round([double]$cost, 2))" } else { '' }
                $period = Get-ScanField $Data 'Period'
                if ($period -eq 'MonthToDate') { $period = 'Month to date' }
                elseif (-not $period) { $period = 'Unknown period' }
                return (New-KpiValue "$('{0:N0}' -f [long]$tokens) tokens$costStr ($period)" ([long]$tokens))
            }
        }
        'cost-per-api-call' {
            $cpr = Get-ScanField $Data 'CostPerRequest'
            $cur = Get-ScanField $Data 'Currency'
            if (-not $cur) { $cur = 'USD' }
            if ($null -ne $cpr -and [double]$cpr -gt 0) {
                return (New-KpiValue "$cur $([math]::Round([double]$cpr, 5)) per AI request" ([math]::Round([double]$cpr, 5)))
            }
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
function Get-KpiToolNameForFunction {
    param([Parameter(Mandatory)][string]$FunctionName)
    $map = @{
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
