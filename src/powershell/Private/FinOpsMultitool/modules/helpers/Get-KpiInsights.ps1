###########################################################################
# GET-KPIINSIGHTS.PS1
# FINOPS KPI CORRELATION LAYER
###########################################################################
# Purpose: Map FinOps Multitool scan output to FinOps Foundation KPIs
#          (https://www.finops.org/finops-kpis/) so MCP users who do not
#          know the KPI taxonomy still see which industry KPIs their results
#          inform, with a computed value where the data allows.
# Author: Zac Larsen
# Date: Created for KPI skills
#
# Description:
# Additive only. Does not change any scan. After a tool returns, the MCP
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
function Get-KpiComputedValue {
    param([string]$KpiId, $Data, $Catalog)

    switch ($KpiId) {
        'cost-per-gb-stored' {
            $v = Get-ScanField $Data 'CostPerGb'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) { return "$cur $v per GB / month" }
        }
        'hourly-cost-per-cpu-core' {
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) {
                $hourly = [math]::Round([double]$v / 730, 4)
                return "$cur $hourly per vCPU / hour"
            }
        }
        'effective-avg-compute-cost-per-core' {
            $v = Get-ScanField $Data 'CostPerVCpu'
            $cur = Get-ScanField $Data 'Currency'
            if ($null -ne $v -and $v -gt 0) { return "$cur $v per vCPU / month" }
        }
        'commitment-utilization-score' {
            $ri = Get-ScanField $Data 'RIAvgUtilization'
            $sp = Get-ScanField $Data 'SPAvgUtilization'
            $vals = @($ri, $sp) | Where-Object { $null -ne $_ -and $_ -gt 0 }
            if ($vals.Count -gt 0) {
                $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1)
                return "$avg%"
            }
        }
        'pct-commitment-discount-waste' {
            $ri = Get-ScanField $Data 'RIAvgUtilization'
            $sp = Get-ScanField $Data 'SPAvgUtilization'
            $vals = @($ri, $sp) | Where-Object { $null -ne $_ -and $_ -gt 0 }
            if ($vals.Count -gt 0) {
                $avg = ($vals | Measure-Object -Average).Average
                return "$([math]::Round(100 - $avg, 1))%"
            }
        }
        { $_ -in @('pct-costs-untagged', 'pct-costs-unallocated', 'tagging-policy-compliant') } {
            # Derive from CostByTag. These KPIs measure ALLOCATION coverage, so
            # only consider recognized CAF allocation dimensions - not identity
            # tags (e.g. tag1/tag2) that blanket every resource and would give a
            # misleading 0% untagged. CostByTag may be a hashtable (hub/export)
            # or a PSCustomObject (live path).
            $cbt = Get-ScanField $Data 'CostByTag'
            if (-not $cbt) { return $null }
            $allocTags = @('CostCenter', 'Customer', 'Project', 'Environment', 'Application',
                'Owner', 'BusinessUnit', 'Department', 'Team', 'Service', 'WorkloadName')
            $tagPairs = @()
            if ($cbt -is [System.Collections.IDictionary]) {
                foreach ($k in $cbt.Keys) { $tagPairs += [PSCustomObject]@{ Name = $k; Value = $cbt[$k] } }
            }
            else {
                foreach ($prop in $cbt.PSObject.Properties) { $tagPairs += [PSCustomObject]@{ Name = $prop.Name; Value = $prop.Value } }
            }
            $best = $null
            foreach ($tp in $tagPairs) {
                if ($allocTags -notcontains $tp.Name) { continue }   # allocation tags only
                $rows = @($tp.Value)
                $total = ($rows | Measure-Object -Property Cost -Sum).Sum
                if (-not $total -or $total -le 0) { continue }
                $untag = ($rows | Where-Object { $_.TagValue -eq '(untagged)' } | Measure-Object -Property Cost -Sum).Sum
                if ($null -eq $untag) { $untag = 0 }
                $pctUntag = [math]::Round(100 * $untag / $total, 1)
                if ($null -eq $best -or $pctUntag -lt $best.PctUntag) {
                    $best = [PSCustomObject]@{ Tag = $tp.Name; PctUntag = $pctUntag }
                }
            }
            if ($null -eq $best) { return $null }   # no allocation tags -> stays informational
            switch ($KpiId) {
                'pct-costs-untagged' { return "$($best.PctUntag)% untagged (by allocation tag '$($best.Tag)')" }
                'pct-costs-unallocated' { return "$($best.PctUntag)% unallocated (by '$($best.Tag)')" }
                'tagging-policy-compliant' { return "$([math]::Round(100 - $best.PctUntag, 1))% compliant (by '$($best.Tag)')" }
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
            yourValue     = $value
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

# Browse the KPI catalog for the explore_finops_kpis tool.
function Get-KpiExploration {
    param([string]$KpiId)

    $catalog = Get-KpiCatalog
    if (-not $catalog) { return @{ error = 'KPI catalog not found.' } }

    if ($KpiId) {
        $kpi = $catalog.kpis | Where-Object { $_.id -eq $KpiId } | Select-Object -First 1
        if (-not $kpi) { return @{ error = "Unknown KPI id '$KpiId'. Call explore_finops_kpis with no id to list all." } }
        return @{
            kpi = [PSCustomObject]@{
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
