# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-FOHUBPROVIDER.PS1
# FINOPS HUB - SCALABLE DATA PROVIDER (KUSTO-FIRST)
###########################################################################
# Purpose: Resolve which FinOps Hub data provider to use and serve the
#          cost-family scans by pushing aggregation into the Kusto engine,
#          returning ONLY summarized results. This is the scalable hub path
#          for large customer datasets (tens of GB / hundreds of millions of
#          rows) that must never be loaded into PowerShell objects.
# Author: Zac Larsen
# Date: Created for FinOps Multitool scalable hub data path
#
# Description:
# Provider selection (same code path serves all three):
#   1. Explicit override  - FINOPS_HUB_KUSTO_URI (+ FINOPS_HUB_KUSTO_DB).
#      Covers the offline ftklocal Kusto emulator (anonymous) AND a user-
#      pinned ADX/Fabric cluster. Mirrors the toolkit's "use a provided
#      cluster URI" connect option.
#   2. Online discovery   - Azure Resource Graph for the hub's ADX cluster
#      (microsoft.kusto/clusters tagged ftk-tool == 'FinOps hubs'), exactly
#      the query the FinOps Toolkit's own ftk-hubs-connect flow uses.
#   3. None               - no cluster; caller falls back to the storage
#      export reader (small-dataset path).
#
# Each intent (Get-FOHubCostSummary / Get-FOHubResourceCosts /
# Get-FOHubCostByTag) builds a KQL summarize against the Hub database's
# versioned cost function (Costs - the latest-version alias the toolkit
# exposes) and returns the SAME shape the storage converters
# (ConvertTo-*FromHub) produce, so the cost tools are unchanged.
#
# Cost parity: the storage converters treat a 0 BilledCost as falsy and fall
# through to EffectiveCost. The KQL below replicates that exact coalescing so
# the Kusto path and the storage path return identical numbers.
#
# ── Functions ───────────────────────────────────────────────────
# Resolve-FOHubProvider     Decide provider (override | discovered | none)
# Get-FOHubCostSummary      -> @{ subId = @{ Actual; Forecast; Currency } }
# Get-FOHubResourceCosts    -> @(PSCustomObject Subscription/RG/Type/Path/...)
# Get-FOHubCostByTag        -> @{ TagsQueried; CostByTag; NoTagsFound; ... }
#
# Prerequisites:
# - Invoke-FOHubKustoQuery.ps1, Get-PlainAccessToken.ps1, Search-AzGraphSafe.ps1
#
# Usage:
#   $p = Resolve-FOHubProvider -Subscriptions $subs
#   if ($p.Found) { $cost = Get-FOHubCostSummary -Provider $p }
###########################################################################

# -- Shared KQL snippets --------------------------------------------------
# Replicates the storage converter's cost selection: BilledCost unless it is
# null or 0, in which case EffectiveCost (matches `if ($row.BilledCost)`).
$script:FOHubCostExpr = 'todouble(iff(isnull(BilledCost) or BilledCost == 0, EffectiveCost, BilledCost))'

function Get-FOHubAnchorLet {
    # Anchor the reporting window to the latest month that actually has data
    # (max ChargePeriodStart), not the calendar month. On a live hub the latest
    # month IS the current month, so this matches the storage reader; on stale or
    # historical data (e.g. a demo/ftklocal dataset) it still returns the newest
    # available months instead of an empty calendar-month window.
    return 'let _anchor = toscalar(Costs | summarize x = startofmonth(max(ChargePeriodStart)) | project x);'
}

function Get-FOHubWindowClause {
    # Trailing N calendar months ending at the latest data month (_anchor).
    param([int]$Months = 1)
    $back = [math]::Max(0, $Months - 1)
    return "| where ChargePeriodStart >= datetime_add('month', -$back, _anchor)"
}

function Get-FOHubScopeClause {
    # Restrict to specific subscriptions (FOCUS SubAccountId is
    # /subscriptions/{guid}). Only valid GUIDs are injected (no KQL injection).
    param([string[]]$SubscriptionIds)
    $guids = @($SubscriptionIds | Where-Object { $_ -match '^[0-9a-fA-F-]{36}$' } | ForEach-Object { $_.ToLower() })
    if ($guids.Count -eq 0) { return '' }
    $arr = ($guids | ForEach-Object { '"' + $_ + '"' }) -join ', '
    return "| where tolower(SubAccountId) has_any (dynamic([$arr]))"
}

# -- Private: run a query through the resolved provider --------------------
function Invoke-FOHubProviderQuery {
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [Parameter(Mandatory)][string]$Query
    )
    $token = $null
    if ($Provider.UseAuth) {
        try { $token = Get-PlainAccessToken -ResourceUrl $Provider.ClusterUri }
        catch { return @{ Ok = $false; Rows = @(); RowCount = 0; Error = "Could not acquire a Kusto token for $($Provider.ClusterUri): $($_.Exception.Message)" } }
    }
    return Invoke-FOHubKustoQuery -ClusterUri $Provider.ClusterUri -Database $Provider.Database -Query $Query -AccessToken $token
}

# -- Provider resolution --------------------------------------------------
function Resolve-FOHubProvider {
    [CmdletBinding()]
    param(
        [string[]]$Subscriptions,
        [object]$Decision
    )

    # 1. Explicit override (ftklocal emulator or a pinned ADX/Fabric cluster).
    if (-not [string]::IsNullOrWhiteSpace($env:FINOPS_HUB_KUSTO_URI)) {
        $uri = $env:FINOPS_HUB_KUSTO_URI.Trim()
        $db = if ($env:FINOPS_HUB_KUSTO_DB) { $env:FINOPS_HUB_KUSTO_DB.Trim() } else { 'Hub' }
        $isLocal = $uri -match '^https?://(localhost|127\.0\.0\.1|\[::1\])(:|/|$)'
        return @{
            Found      = $true
            Mode       = if ($isLocal) { 'KustoLocal' } else { 'Kusto' }
            ClusterUri = $uri
            Database   = $db
            UseAuth    = (-not $isLocal)
            HubVersion = $null
            Source     = 'EnvOverride'
        }
    }

    # 2. A cluster already discovered by Resolve-CostDataSource.
    if ($Decision -and $Decision.KustoClusterUri) {
        return @{
            Found      = $true
            Mode       = 'Kusto'
            ClusterUri = [string]$Decision.KustoClusterUri
            Database   = if ($Decision.KustoDatabase) { [string]$Decision.KustoDatabase } else { 'Hub' }
            UseAuth    = $true
            HubVersion = $Decision.HubVersion
            Source     = 'Discovered'
        }
    }

    # 3. Online discovery via Resource Graph (the toolkit's own connect query).
    try {
        $clusterQuery = @"
resources
| where type =~ 'microsoft.kusto/clusters'
| where tags['ftk-tool'] == 'FinOps hubs'
| extend hubVersion = tostring(tags['ftk-version'])
| project clusterUri = tostring(properties.uri), hubVersion, resourceGroup, subscriptionId
| take 1
"@
        $res = Search-AzGraphSafe -Query $clusterQuery -Subscription @($Subscriptions) -First 1
        if ($res -and $res.Data -and @($res.Data).Count -gt 0) {
            $row = @($res.Data)[0]
            if ($row.clusterUri) {
                return @{
                    Found      = $true
                    Mode       = 'Kusto'
                    ClusterUri = [string]$row.clusterUri
                    Database   = 'Hub'
                    UseAuth    = $true
                    HubVersion = $row.hubVersion
                    Source     = 'Discovered'
                }
            }
        }
    }
    catch {
        # Discovery failed - fall through to None (storage fallback).
    }

    return @{ Found = $false; Mode = 'None'; ClusterUri = $null; Database = $null; UseAuth = $false; HubVersion = $null; Source = 'None' }
}

# -- Intent: cost by subscription (matches ConvertTo-CostDataFromHub) ------
function Get-FOHubCostSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [string[]]$SubscriptionIds,
        [int]$Months = 1
    )
    $window = Get-FOHubWindowClause -Months $Months
    $scope = Get-FOHubScopeClause -SubscriptionIds $SubscriptionIds
    $query = @"
$(Get-FOHubAnchorLet)
Costs
$window
$scope
| extend _sub = extract('([0-9a-fA-F-]{36})', 1, tolower(SubAccountId))
| extend _cost = $($script:FOHubCostExpr)
| summarize Actual = sum(_cost), Currency = take_any(BillingCurrency), Name = take_any(SubAccountName) by _sub
"@
    $r = Invoke-FOHubProviderQuery -Provider $Provider -Query $query
    if (-not $r.Ok) { return @{ Error = $r.Error; Source = 'Kusto' } }

    $costMap = @{}
    foreach ($row in $r.Rows) {
        $subId = if ($row._sub) { [string]$row._sub } else { 'unknown' }
        $currency = if ($row.Currency) { [string]$row.Currency } else { 'USD' }
        # Carry the subscription's display name from the FOCUS data so the UI can
        # show a friendly name even for subscriptions that aren't in the caller's
        # selected list (a hub commonly covers more subs than are being scanned).
        $subName = if ($row.Name) { [string]$row.Name } else { '' }
        $costMap[$subId] = @{
            Actual   = [math]::Round([double]$row.Actual, 2)
            Forecast = 0.0
            Currency = $currency
            Name     = $subName
        }
    }
    return $costMap
}

# -- Intent: top resources by cost (matches ConvertTo-ResourceCostsFromHub) -
function Get-FOHubResourceCosts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [string[]]$SubscriptionIds,
        [int]$Months = 1,
        [int]$Top = 500
    )
    $window = Get-FOHubWindowClause -Months $Months
    $scope = Get-FOHubScopeClause -SubscriptionIds $SubscriptionIds
    $query = @"
$(Get-FOHubAnchorLet)
Costs
$window
$scope
| extend _cost = $($script:FOHubCostExpr)
| summarize Actual = sum(_cost), Currency = take_any(BillingCurrency)
    by Subscription = SubAccountName, ResourceGroup = x_ResourceGroupName, ResourceType, ResourcePath = ResourceId
| order by Actual desc
| take $Top
"@
    $r = Invoke-FOHubProviderQuery -Provider $Provider -Query $query
    if (-not $r.Ok) { return @{ Error = $r.Error; Source = 'Kusto' } }

    $out = foreach ($row in $r.Rows) {
        [PSCustomObject]@{
            Subscription  = if ($row.Subscription) { [string]$row.Subscription } else { 'unknown' }
            ResourceGroup = if ($row.ResourceGroup) { [string]$row.ResourceGroup } else { 'unknown' }
            ResourceType  = if ($row.ResourceType) { [string]$row.ResourceType } else { 'unknown' }
            ResourcePath  = [string]$row.ResourcePath
            Actual        = [math]::Round([double]$row.Actual, 2)
            Forecast      = 0.0
            Currency      = if ($row.Currency) { [string]$row.Currency } else { 'USD' }
        }
    }
    # Sort in PowerShell too (matches ConvertTo-ResourceCostsFromHub and is
    # robust even if the transport ever returns rows out of engine order).
    return @($out | Sort-Object -Property Actual -Descending)
}

# -- Intent: cost by tag (matches ConvertTo-CostByTagFromHub) --------------
function Get-FOHubCostByTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [string[]]$SubscriptionIds,
        [int]$Months = 1,
        [string[]]$TagKeys
    )
    $window = Get-FOHubWindowClause -Months $Months
    $scope = Get-FOHubScopeClause -SubscriptionIds $SubscriptionIds

    # Discover tag keys when the caller didn't supply a set to report on.
    $keys = @($TagKeys | Where-Object { $_ })
    if ($keys.Count -eq 0) {
        $keyQuery = @"
$(Get-FOHubAnchorLet)
Costs
$window
$scope
| mv-expand k = bag_keys(Tags) to typeof(string)
| distinct k
| take 200
"@
        $kr = Invoke-FOHubProviderQuery -Provider $Provider -Query $keyQuery
        if (-not $kr.Ok) { return @{ Error = $kr.Error; Source = 'Kusto' } }
        $keys = @($kr.Rows | ForEach-Object { [string]$_.k } | Where-Object { $_ })
    }

    if ($keys.Count -eq 0) {
        return [PSCustomObject]@{
            TagsQueried   = @()
            CostByTag     = @{}
            NoTagsFound   = $true
            UsedTimeframe = 'Hub query period'
            Source        = 'Kusto'
        }
    }

    # One snapshot: a sentinel *TOTAL* row plus per-(key,value) cost. Untagged
    # cost per key is derived in PowerShell as total minus the key's tagged sum
    # (mirrors the converter assigning '(untagged)' to rows lacking the key).
    $keyList = ($keys | Where-Object { $_ } | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ', '
    $query = @"
$(Get-FOHubAnchorLet)
let src = Costs
$window
$scope
| extend _cost = $($script:FOHubCostExpr);
let total = src | summarize Cost = sum(_cost), Currency = take_any(BillingCurrency) | extend TagKey = '*TOTAL*', TagValue = '*TOTAL*';
let perTag = src
| mv-expand k = bag_keys(Tags) to typeof(string)
| where k in ($keyList)
| extend TagValue = tostring(Tags[k])
| summarize Cost = sum(_cost), Currency = take_any(BillingCurrency) by TagKey = k, TagValue;
union total, perTag
"@
    $r = Invoke-FOHubProviderQuery -Provider $Provider -Query $query
    if (-not $r.Ok) { return @{ Error = $r.Error; Source = 'Kusto' } }

    $currency = 'USD'
    $total = 0.0
    $tagged = @{}   # key -> @{ value -> cost }
    foreach ($row in $r.Rows) {
        $tk = [string]$row.TagKey
        $cost = [double]$row.Cost
        if ($row.Currency) { $currency = [string]$row.Currency }
        if ($tk -eq '*TOTAL*') { $total = $cost; continue }
        if (-not $tagged.ContainsKey($tk)) { $tagged[$tk] = @{} }
        $tv = if ($null -ne $row.TagValue -and "$($row.TagValue)" -ne '') { [string]$row.TagValue } else { '(empty)' }
        if (-not $tagged[$tk].ContainsKey($tv)) { $tagged[$tk][$tv] = 0.0 }
        $tagged[$tk][$tv] += $cost
    }

    $costByTagOut = @{}
    foreach ($key in $keys) {
        $values = if ($tagged.ContainsKey($key)) { $tagged[$key] } else { @{} }
        $taggedSum = 0.0
        foreach ($v in $values.Values) { $taggedSum += $v }
        $untagged = [math]::Round($total - $taggedSum, 2)

        $entries = @($values.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{ TagValue = $_.Key; Cost = [math]::Round($_.Value, 2); Currency = $currency }
            })
        if ($untagged -gt 0) {
            $entries += [PSCustomObject]@{ TagValue = '(untagged)'; Cost = $untagged; Currency = $currency }
        }
        $costByTagOut[$key] = @($entries | Sort-Object Cost -Descending)
    }

    return [PSCustomObject]@{
        TagsQueried   = @($costByTagOut.Keys)
        CostByTag     = $costByTagOut
        NoTagsFound   = ($costByTagOut.Count -eq 0)
        UsedTimeframe = 'Hub query period'
        Source        = 'Kusto'
    }
}
