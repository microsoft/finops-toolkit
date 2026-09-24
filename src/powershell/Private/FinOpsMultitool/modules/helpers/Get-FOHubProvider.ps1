# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
param()

###########################################################################
# GET-FOHUBPROVIDER.PS1
# FINOPS HUB - SCALABLE DATA PROVIDER (KUSTO-FIRST)
###########################################################################
# Purpose: Resolve which FinOps Hub data provider to use and serve the
#          cost-family scans by pushing aggregation into the Kusto engine,
#          returning ONLY summarized results. This is the scalable hub path
#          for large customer datasets (tens of GB / hundreds of millions of
#          rows) that must never be loaded into PowerShell objects.
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
# Cost parity: actual-cost summaries use BilledCost, including measured zero.
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
$script:FOHubCostExpr = 'todouble(BilledCost)'

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
    return "| where isnull(ChargePeriodStart) or ChargePeriodStart >= datetime_add('month', -$back, _anchor)"
}

function Get-FOHubScopeClause {
    # Restrict to specific subscriptions (FOCUS SubAccountId is
    # /subscriptions/{guid}). Parsing every id keeps the interpolation to hex
    # and hyphens, and an unparseable one fails rather than dropping the filter
    # and silently returning every subscription in the hub.
    param([string[]]$SubscriptionIds)

    if (-not $SubscriptionIds -or @($SubscriptionIds).Count -eq 0) { return '' }

    $guids = foreach ($id in $SubscriptionIds) {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($id, [ref]$parsed)) {
            throw "'$id' is not a subscription GUID. Refusing to drop the scope filter."
        }
        $parsed.ToString()
    }

    $arr = (@($guids) | ForEach-Object { '"' + $_ + '"' }) -join ', '
    return "| where SubAccountId has_any (dynamic([$arr]))"
}

# -- Private: run a query through the resolved provider --------------------
function Invoke-FOHubProviderQuery {
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [Parameter(Mandatory)][string]$Query
    )
    $token = $null
    try { $null = Resolve-FinOpsRequestUri -Uri $Provider.ClusterUri -AllowAnonymousLoopback:(-not $Provider.UseAuth) }
    catch { return @{ Ok = $false; Rows = @(); RowCount = 0; Error = $_.Exception.Message } }
    if ($Provider.UseAuth) {
        try { $token = Get-PlainAccessToken -ResourceUrl $Provider.ClusterUri }
        catch { return @{ Ok = $false; Rows = @(); RowCount = 0; Error = "Could not acquire a Kusto token for $($Provider.ClusterUri): $($_.Exception.Message)" } }
    }
    return Invoke-FOHubKustoQuery -ClusterUri $Provider.ClusterUri -Database $Provider.Database -Query $Query -AccessToken $token
}

function Invoke-FOHubCostQuery {
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [Parameter(Mandatory)][string]$Query,
        [string[]]$SubscriptionIds,
        [int]$Months = 1
    )

    $scope = Get-FOHubScopeClause -SubscriptionIds $SubscriptionIds
    $expectedIds = ConvertTo-Json -InputObject @($SubscriptionIds | Where-Object { $_ } | ForEach-Object { ([guid]$_).ToString() }) -Compress
    # Set difference is case-sensitive; extracted IDs must match the normalized GUIDs.
    $validatedQuery = @"
$(Get-FOHubAnchorLet)
let src = Costs
$(Get-FOHubWindowClause -Months $Months)
$scope
| extend _cost = $($script:FOHubCostExpr), _sub = tolower(extract('([0-9a-fA-F-]{36})', 1, SubAccountId));
let validation = src
| summarize _InvalidCosts = countif(isnull(_cost) or not(isfinite(_cost)) or isempty(BillingCurrency) or isnull(ChargePeriodStart)),
    _CurrencyCount = array_length(make_set(BillingCurrency, 2)), _SourceRows = count(),
    _MissingSubscriptions = array_length(set_difference(dynamic($expectedIds), make_set(_sub)))
| extend _CostValidation = true;
union validation, (
$Query
)
"@
    $result = Invoke-FOHubProviderQuery -Provider $Provider -Query $validatedQuery
    if (-not $result.Ok) { return $result }
    $validation = @($result.Rows | Where-Object { $_._CostValidation -eq $true })
    if ($validation.Count -ne 1 -or $null -eq $validation[0]._InvalidCosts -or $null -eq $validation[0]._MissingSubscriptions -or
        $null -eq $validation[0]._SourceRows -or $null -eq $validation[0]._CurrencyCount -or
        $validation[0]._InvalidCosts -ne 0 -or $validation[0]._MissingSubscriptions -ne 0 -or
        ($validation[0]._SourceRows -gt 0 -and $validation[0]._CurrencyCount -ne 1)) {
        return @{ Ok = $false; Rows = @(); Error = 'Hub cost validation failed: missing or invalid amounts, currency, dates, or subscription coverage.' }
    }
    $rows = @($result.Rows | Where-Object { $_._CostValidation -ne $true })
    try {
        foreach ($row in $rows) {
            $column = if ($row.PSObject.Properties.Name -contains 'Actual') { 'Actual' } else { 'Cost' }
            $null = Get-HubCostValue -Row $row -Column $column
        }
    }
    catch { return @{ Ok = $false; Rows = @(); Error = $_.Exception.Message } }
    return @{ Ok = $true; Rows = $rows; RowCount = $rows.Count; Error = $null }
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
        $endpoint = Resolve-FinOpsRequestUri -Uri $uri -AllowAnonymousLoopback
        if ($endpoint.Query) { throw 'The cluster URL cannot contain a query string.' }
        $isLocal = $endpoint.IsLoopback
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
        $null = Resolve-FinOpsRequestUri -Uri $Decision.KustoClusterUri
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
                $null = Resolve-FinOpsRequestUri -Uri $row.clusterUri
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
        Write-Verbose "Non-fatal: $($_.Exception.Message)"
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
    $query = @"
src
| summarize Actual = sum(_cost), Currency = take_any(BillingCurrency), Name = take_any(SubAccountName),
    ActualPeriodStart = min(ChargePeriodStart), ActualPeriodEnd = max(ChargePeriodStart) by _sub
"@
    $r = Invoke-FOHubCostQuery -Provider $Provider -Query $query -SubscriptionIds $SubscriptionIds -Months $Months
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
            Actual         = [math]::Round([double]$row.Actual, 2)
            Forecast       = $null
            ForecastSource = 'Unavailable'
            Currency       = $currency
            Name           = $subName
            ActualPeriod   = if ($row.ActualPeriodStart -and $row.ActualPeriodEnd) { '{0:yyyy-MM-dd} to {1:yyyy-MM-dd}' -f [datetime]$row.ActualPeriodStart, [datetime]$row.ActualPeriodEnd } else { 'Unknown' }
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
    $query = @"
src
| summarize Actual = sum(_cost), Currency = take_any(BillingCurrency)
    by Subscription = SubAccountName, ResourceGroup = x_ResourceGroupName, ResourceType, ResourcePath = ResourceId
| order by Actual desc
| take $Top
"@
    $r = Invoke-FOHubCostQuery -Provider $Provider -Query $query -SubscriptionIds $SubscriptionIds -Months $Months
    if (-not $r.Ok) { return @{ Error = $r.Error; Source = 'Kusto' } }

    $out = foreach ($row in $r.Rows) {
        [PSCustomObject]@{
            Subscription  = if ($row.Subscription) { [string]$row.Subscription } else { 'unknown' }
            ResourceGroup = if ($row.ResourceGroup) { [string]$row.ResourceGroup } else { 'unknown' }
            ResourceType  = if ($row.ResourceType) { [string]$row.ResourceType } else { 'unknown' }
            ResourcePath  = [string]$row.ResourcePath
            Actual        = [math]::Round([double]$row.Actual, 2)
            Forecast      = $null
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
    $keys = @($TagKeys | Where-Object { $_ })

    # One snapshot: a sentinel *TOTAL* row plus per-(key,value) cost. Untagged
    # cost per key is derived in PowerShell as total minus the key's tagged sum
    # (mirrors the converter assigning '(untagged)' to rows lacking the key).
    # Escape backslash before quote, matching ConvertTo-KqlLiteral, so a tag key
    # ending in a backslash cannot terminate the KQL string early.
    $keyList = ($keys | Where-Object { $_ } | ForEach-Object { '"' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }) -join ', '
    $tagFilter = if ($keys.Count -gt 0) { "| where k in~ ($keyList)" } else { '' }
    $query = @"
union (src | summarize Cost = sum(_cost), Currency = take_any(BillingCurrency) | extend TagKey = '*TOTAL*', TagValue = '*TOTAL*'),
(src
| mv-expand k = bag_keys(Tags) to typeof(string)
$tagFilter
| extend TagValue = tostring(Tags[k])
| summarize Cost = sum(_cost), Currency = take_any(BillingCurrency) by TagKey = k, TagValue)
"@
    $r = Invoke-FOHubCostQuery -Provider $Provider -Query $query -SubscriptionIds $SubscriptionIds -Months $Months
    if (-not $r.Ok) { return @{ Error = $r.Error; Source = 'Kusto' } }

    $currency = 'USD'
    $total = 0.0
    $tagged = @{}   # key -> @{ value -> cost }
    foreach ($row in $r.Rows) {
        $tk = [string]$row.TagKey
        $cost = [double]$row.Cost
        if ($row.Currency) { $currency = [string]$row.Currency }
        if ($tk -eq '*TOTAL*') { $total = $cost; continue }
        if (-not $tagged.ContainsKey($tk)) { $tagged[$tk] = [System.Collections.Generic.Dictionary[string, double]]::new([System.StringComparer]::Ordinal) }
        $tv = if ($null -ne $row.TagValue -and "$($row.TagValue)" -ne '') { [string]$row.TagValue } else { '(empty)' }
        if (-not $tagged[$tk].ContainsKey($tv)) { $tagged[$tk][$tv] = 0.0 }
        $tagged[$tk][$tv] += $cost
    }

    if ($keys.Count -eq 0) { $keys = @($tagged.Keys) }
    $costByTagOut = @{}
    foreach ($key in $keys) {
        $values = if ($tagged.ContainsKey($key)) { $tagged[$key] } else { @{} }
        $taggedSum = 0.0
        foreach ($v in $values.Values) { $taggedSum += $v }
        $untagged = [math]::Round($total - $taggedSum, 2)

        $entries = @($values.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{ TagValue = $_.Key; Cost = [math]::Round($_.Value, 2); Currency = $currency }
            })
        if ($untagged -ne 0) {
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
