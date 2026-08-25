# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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

function Get-KpiComputedValue {
    param([string]$KpiId, $Data, $Catalog)

    switch ($KpiId) {
        'cost-per-gb-stored' {
            $v = Get-ScanField $Data 'CostPerGb'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) { return (New-KpiValue "$cur $v per GB / month" ([double]$v)) }
        }
        'hourly-cost-per-cpu-core' {
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) {
                $hourly = [math]::Round([double]$v / 730, 4)
                return (New-KpiValue "$cur $hourly per vCPU / hour" $hourly)
            }
        }
        'effective-avg-compute-cost-per-core' {
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) { return (New-KpiValue "$cur $v per vCPU / month" ([double]$v)) }
        }
        'commitment-utilization-score' {
            $ri = Get-ScanField $Data 'RIAvgUtilization'
            $sp = Get-ScanField $Data 'SPAvgUtilization'
            $vals = @($ri, $sp) | Where-Object { $null -ne $_ -and $_ -gt 0 }
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
            # Average percent of budget consumed across all budgets.
            $budgets = Get-ScanField $Data 'Budgets'
            if ($budgets) {
                $pcts = @($budgets | ForEach-Object { $_.PctUsed } | Where-Object { $null -ne $_ })
                if ($pcts.Count -gt 0) {
                    $avg = [math]::Round(($pcts | Measure-Object -Average).Average, 1)
                    return (New-KpiValue "$avg% of budget consumed (avg across $($pcts.Count))" $avg)
                }
            }
        }
        'variance-budget-vs-actual' {
            # Total actual vs total budgeted across all budgets.
            $budgets = Get-ScanField $Data 'Budgets'
            if ($budgets) {
                $totBudget = ($budgets | Measure-Object -Property Amount -Sum).Sum
                $totActual = ($budgets | Measure-Object -Property ActualSpend -Sum).Sum
                if ($totBudget -and $totBudget -gt 0) {
                    $variance = [math]::Round(100 * ($totActual - $totBudget) / $totBudget, 1)
                    $sign = if ($variance -ge 0) { 'over' } else { 'under' }
                    # Score on distance from plan in either direction.
                    return (New-KpiValue "$([math]::Abs($variance))% $sign budget (actual vs planned)" ([math]::Abs($variance)))
                }
            }
        }
        'effective-savings-rate' {
            # Realized monthly savings from commitments + AHB (proxy: a true rate
            # also needs total on-demand-equivalent spend, not in this scan).
            $monthly = Get-ScanField $Data 'TotalMonthly'
            $cur = Get-ScanField $Data 'Currency'
            if (-not $cur) { $cur = 'USD' }
            if ($null -ne $monthly -and [double]$monthly -gt 0) {
                return (New-KpiValue "$cur $([math]::Round([double]$monthly, 2)) / month realized (proxy)" ([math]::Round([double]$monthly, 2)))
            }
        }
        'pct-compute-covered-by-commitment' {
            # Commitment coverage = committed eligible spend / total eligible
            # spend (excludes Spot). Computed in Get-SavingsRealized from
            # amortized cost grouped by pricing model.
            $cov = Get-ScanField $Data 'CommitmentCoveragePct'
            $committed = Get-ScanField $Data 'CommittedAmortized'
            $onDemand = Get-ScanField $Data 'OnDemandAmortized'
            $cur = Get-ScanField $Data 'Currency'
            if (-not $cur) { $cur = 'USD' }
            if ($null -ne $cov) {
                $detail = ''
                if ($null -ne $committed -and $null -ne $onDemand) {
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
                $costStr = if ($null -ne $cost -and [double]$cost -gt 0) { " for $cur $([math]::Round([double]$cost, 2)) (MTD)" } else { '' }
                return (New-KpiValue "$('{0:N0}' -f [long]$tokens) tokens$costStr" ([long]$tokens))
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
            $ri = Get-ScanField $Data 'RIAvgUtilization'
            $sp = Get-ScanField $Data 'SPAvgUtilization'
            $vals = @($ri, $sp) | Where-Object { $null -ne $_ -and $_ -gt 0 }
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
            if ($seen -and [double]$seen -gt 0 -and $null -ne $unalloc) {
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
                $total = ($rows | Measure-Object -Property Cost -Sum).Sum
                if (-not $total -or $total -le 0) { continue }
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

    $matches = @($catalog.kpis | Where-Object { $_.sourceTool -eq $toolName })
    if ($matches.Count -eq 0) { return $Result }

    $data = if ($Result -is [hashtable]) { $Result['data'] } else { $Result.data }

    $insights = @()
    foreach ($kpi in $matches) {
        $value = $null
        if ($kpi.compute) { $value = Get-KpiComputedValue -KpiId $kpi.id -Data $data -Catalog $catalog }
        $status = if ($value) { 'computed' } else { 'informational' }
        $insights += [PSCustomObject]@{
            kpiId         = $kpi.id
            kpiName       = $kpi.name
            domain        = $kpi.domain
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
