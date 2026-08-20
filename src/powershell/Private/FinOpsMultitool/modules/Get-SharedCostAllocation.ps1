# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-SHAREDCOSTALLOCATION.PS1
# AZURE FINOPS MULTITOOL - Shared Hub Cost Allocation (Showback)
###########################################################################
# Purpose: Distribute the billed cost of SHARED hub resources (ExpressRoute
#          gateway/circuit, VPN gateway, Azure Firewall, shared bandwidth)
#          across the spoke subscriptions that consume them, and report each
#          spoke's full "solution cost" = its own resources + its allocated
#          share of the shared pool.
#
# Why:     Shared connectivity bills entirely to the hub subscription, so
#          Cost Management cannot tell which spoke generated which gigabyte.
#          The split key (GB/TB transferred) lives in network telemetry, not
#          billing data. This tool keeps the cost math here and takes the
#          weighting vector as input - so an agent can fetch GB-per-spoke
#          from Azure Monitor / Traffic Analytics (e.g. via the Azure MCP
#          server) and hand it in, or fall back to a proxy key when no
#          flow logs exist.
#
# Weighting providers:
#   inline           - exact GB/TB map supplied by the caller (best)
#   trafficAnalytics - exact: queries Traffic Analytics / VNet flow logs in a
#                      Log Analytics workspace for measured GB per spoke
#   equal            - split evenly across spokes (no measurement)
#   resourceCount    - proxy: billable resource count per spoke (ARG, estimate)
#
# Split model (per shared pool):
#   spoke_i = (Fixed / nSpokes) + (Variable * weight_i / totalWeight)
#   where Fixed = pool * FixedRatio (split evenly - gateways cost money at
#   zero traffic) and Variable = pool * (1 - FixedRatio) (by transfer).
#
# Sources: Live Cost Management API (default) OR the FinOps Hub / export
#          when -HubData is injected by the caller (fast path).
#
# Notes:
# - RBAC: Cost Management Reader (hub + spoke subs) + Reader (ARG).
# - Per-spoke ExpressRoute attribution is impossible from billing alone; it
#   requires the flow-log weighting key. Without it, results are estimates
#   and are labelled as such.
###########################################################################

# -- Resolve the shared cost pool resources --------------------------------
# From explicit resource IDs and/or a resource group, confirm the shared
# resources exist via ARG and return their IDs + subscriptions.
function Resolve-SharedCostPool {
    param(
        [string[]]$SubscriptionIds,
        [string[]]$ResourceIds,
        [string]$ResourceGroup
    )

    $clauses = @()
    if ($ResourceIds -and $ResourceIds.Count -gt 0) {
        $idList = ($ResourceIds | ForEach-Object { "'$(ConvertTo-KqlLiteral $_)'" }) -join ','
        $clauses += "id in~ ($idList)"
    }
    if ($ResourceGroup) {
        $clauses += "resourceGroup =~ '$(ConvertTo-KqlLiteral $ResourceGroup)'"
    }
    if ($clauses.Count -eq 0) { return @() }

    $where = $clauses -join ' or '
    $query = @"
resources
| where $where
| project id, name, type, resourceGroup, subscriptionId
"@

    $res = Search-AzGraphSafe -Query $query -Subscription $SubscriptionIds -First 200
    $rows = if ($res) { @($res.Data) } else { @() }

    return @($rows | ForEach-Object {
            [PSCustomObject]@{
                Id             = [string]$_.id
                Name           = [string]$_.name
                Type           = [string]$_.type
                ResourceGroup  = [string]$_.resourceGroup
                SubscriptionId = [string]$_.subscriptionId
            }
        })
}

# -- Build the spoke weighting vector --------------------------------------
# Returns a hashtable: spokeId -> weight (double). Method decides the source.
function Get-SpokeWeighting {
    param(
        [string[]]$Spokes,
        [string]$Method,
        [object]$Values,
        [string[]]$SubscriptionIds,
        [string]$WorkspaceId,
        [int]$LookbackDays = 30,
        [string]$Query
    )

    $weights = @{}
    foreach ($s in $Spokes) { $weights[$s] = 0.0 }

    switch ($Method) {
        'equal' {
            foreach ($s in $Spokes) { $weights[$s] = 1.0 }
        }
        'trafficAnalytics' {
            if (-not $WorkspaceId) {
                Write-Warning '  trafficAnalytics weighting needs workspaceId (the Log Analytics workspace GUID); weights left at 0.'
                break
            }
            $lb = if ($LookbackDays -gt 0) { $LookbackDays } else { 30 }
            # The query must return two columns: Spoke (subscription id) and GB (number).
            $kql = if ($Query) {
                $Query
            }
            else {
                @"
AzureNetworkAnalytics_CL
| where TimeGenerated >= ago(${lb}d)
| where SubType_s == 'FlowLog'
| extend Spoke = column_ifexists('Subscription1_s', '')
| where isnotempty(Spoke)
| summarize GB = sum(InboundBytes_d + OutboundBytes_d) / 1e9 by Spoke
"@
            }
            try {
                $qr = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $kql -ErrorAction Stop
                foreach ($row in @($qr.Results)) {
                    $sid = [string]$row.Spoke
                    if ($weights.ContainsKey($sid)) { $weights[$sid] = [double]$row.GB }
                }
            }
            catch {
                Write-Warning "  Traffic Analytics query failed: $($_.Exception.Message)"
            }
        }
        'resourceCount' {
            $spokeList = ($Spokes | ForEach-Object { "'$(ConvertTo-KqlLiteral $_)'" }) -join ','
            $query = @"
resources
| where subscriptionId in~ ($spokeList)
| summarize c = count() by subscriptionId
"@
            $res = Search-AzGraphSafe -Query $query -Subscription $Spokes -First 1000
            foreach ($r in @($res.Data)) {
                $sid = [string]$r.subscriptionId
                if ($weights.ContainsKey($sid)) { $weights[$sid] = [double]$r.c }
            }
        }
        default {
            # inline: read numeric values keyed by spoke id from $Values
            if ($Values) {
                $pairs = if ($Values -is [hashtable]) {
                    $Values.GetEnumerator()
                }
                else {
                    $Values.PSObject.Properties | ForEach-Object { [PSCustomObject]@{ Key = $_.Name; Value = $_.Value } }
                }
                foreach ($p in $pairs) {
                    $k = [string]$p.Key
                    if ($weights.ContainsKey($k)) { $weights[$k] = [double]$p.Value }
                }
            }
        }
    }

    return $weights
}

# -- Read cost maps (by resource id + by subscription) ---------------------
# One pass over the data source produces both: byResourceId (for the shared
# pool) and bySubscriptionId (for each spoke's own cost).
function Get-AllocationCostMaps {
    param(
        [string[]]$SubscriptionIds,
        [object[]]$HubData
    )

    $byResource = @{}
    $bySub = @{}
    $currency = 'USD'
    $source = 'LiveApi'

    $fromHub = ($HubData -and @($HubData).Count -gt 0)

    if ($fromHub) {
        $source = 'FinOpsHub'
        $props = $HubData[0].PSObject.Properties.Name
        foreach ($row in $HubData) {
            $rid = [string](Get-HubRowValue -Row $row -Names @('ResourceId', 'x_ResourceId', 'InstanceId') -Props $props)
            $cost = [double](Get-HubRowValue -Row $row -Names @('CostInBillingCurrency', 'BilledCost', 'EffectiveCost', 'Cost') -Props $props)
            $sub = [string](Get-HubRowValue -Row $row -Names @('SubAccountId', 'SubscriptionId', 'x_SubscriptionId', 'SubscriptionGuid') -Props $props)
            $cur = [string](Get-HubRowValue -Row $row -Names @('BillingCurrency', 'BillingCurrencyCode', 'Currency') -Props $props)
            if ($cur) { $currency = $cur }

            # SubAccountId is a full path (/subscriptions/{guid}); normalize.
            if ($sub -and $sub -match '/subscriptions/([0-9a-fA-F-]+)') { $sub = $Matches[1] }

            if ($rid) {
                if (-not $byResource.ContainsKey($rid)) { $byResource[$rid] = 0.0 }
                $byResource[$rid] += $cost
            }
            if ($sub) {
                if (-not $bySub.ContainsKey($sub)) { $bySub[$sub] = 0.0 }
                $bySub[$sub] += $cost
            }
        }
    }
    else {
        foreach ($sub in ($SubscriptionIds | Select-Object -Unique)) {
            if (-not $sub) { continue }
            $body = @{
                type      = 'AmortizedCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping    = @(@{ type = 'Dimension'; name = 'ResourceId' })
                }
            } | ConvertTo-Json -Depth 12

            $path = "/subscriptions/$sub/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            try {
                $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body
                if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                    $data = $resp.Content | ConvertFrom-Json
                    $cols = @($data.properties.columns.name)
                    $iCost = [array]::IndexOf($cols, 'Cost')
                    $iRes = [array]::IndexOf($cols, 'ResourceId')
                    $iCur = [array]::IndexOf($cols, 'Currency')
                    if (-not $bySub.ContainsKey($sub)) { $bySub[$sub] = 0.0 }
                    foreach ($row in @($data.properties.rows)) {
                        $amount = if ($iCost -ge 0) { [double]$row[$iCost] } else { 0 }
                        $rid = if ($iRes -ge 0) { [string]$row[$iRes] } else { '' }
                        if ($iCur -ge 0 -and $row[$iCur]) { $currency = [string]$row[$iCur] }
                        $bySub[$sub] += $amount
                        if ($rid) {
                            if (-not $byResource.ContainsKey($rid)) { $byResource[$rid] = 0.0 }
                            $byResource[$rid] += $amount
                        }
                    }
                }
            }
            catch {
                Write-Warning "  Cost query failed for $sub : $($_.Exception.Message)"
            }
        }
    }

    return [PSCustomObject]@{
        ByResource = $byResource
        BySub      = $bySub
        Currency   = $currency
        Source     = $source
    }
}

# -- Main: allocate shared cost across spokes ------------------------------
function Get-SharedCostAllocation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [string[]]$SharedResourceIds,

        [Parameter()]
        [string]$SharedResourceGroup,

        [Parameter()]
        [string[]]$Spokes,

        [Parameter()]
        [string]$WeightingMethod = 'inline',

        [Parameter()]
        [object]$WeightingValues,

        [Parameter()]
        [string]$WorkspaceId,

        [Parameter()]
        [int]$LookbackDays = 30,

        [Parameter()]
        [string]$WeightingQuery,

        [Parameter()]
        [double]$FixedRatio = 0.5,

        [Parameter()]
        [object[]]$HubData
    )

    if ((-not $SharedResourceIds -or $SharedResourceIds.Count -eq 0) -and -not $SharedResourceGroup) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'Provide sharedResourceIds (e.g. the ExpressRoute gateway / firewall) or a sharedResourceGroup that holds them.'
        }
    }
    if (-not $Spokes -or $Spokes.Count -eq 0) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'Provide spokes - the subscription IDs that share the hub resources.'
        }
    }
    if ($FixedRatio -lt 0) { $FixedRatio = 0 }
    if ($FixedRatio -gt 1) { $FixedRatio = 1 }

    $scanSubs = @($Subscriptions | ForEach-Object { $_.Id })
    if (-not $scanSubs -or $scanSubs.Count -eq 0) { $scanSubs = $Spokes }

    Write-Host "  Resolving shared resources..." -ForegroundColor Cyan
    $pool = Resolve-SharedCostPool -SubscriptionIds $scanSubs -ResourceIds $SharedResourceIds -ResourceGroup $SharedResourceGroup
    if (-not $pool -or $pool.Count -eq 0) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'No shared resources matched the supplied sharedResourceIds / sharedResourceGroup in the scanned subscriptions.'
        }
    }

    $sharedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $pool) { [void]$sharedIds.Add($p.Id) }
    $hubSubs = @($pool | ForEach-Object { $_.SubscriptionId } | Select-Object -Unique)

    Write-Host "  Reading cost (pool + spokes)..." -ForegroundColor Cyan
    $costSubs = @($hubSubs + $Spokes | Select-Object -Unique)
    $maps = Get-AllocationCostMaps -SubscriptionIds $costSubs -HubData $HubData

    # -- Size the shared pool from billed cost ----------------------------
    $poolTotal = 0.0
    $poolResources = @()
    foreach ($p in $pool) {
        $c = if ($maps.ByResource.ContainsKey($p.Id)) { [double]$maps.ByResource[$p.Id] } else { 0.0 }
        $poolTotal += $c
        $poolResources += [PSCustomObject]@{
            Name = $p.Name
            Type = $p.Type
            Cost = [math]::Round($c, 2)
        }
    }

    # -- Build the weighting vector ---------------------------------------
    Write-Host "  Building weighting ($WeightingMethod)..." -ForegroundColor Cyan
    $weights = Get-SpokeWeighting -Spokes $Spokes -Method $WeightingMethod -Values $WeightingValues -SubscriptionIds $scanSubs -WorkspaceId $WorkspaceId -LookbackDays $LookbackDays -Query $WeightingQuery
    $totalWeight = 0.0
    foreach ($w in $weights.Values) { $totalWeight += [double]$w }

    # -- Allocate ----------------------------------------------------------
    $nSpokes = $Spokes.Count
    $fixedTotal = $poolTotal * $FixedRatio
    $varTotal = $poolTotal * (1 - $FixedRatio)

    $allocations = @()
    foreach ($s in $Spokes) {
        $w = [double]$weights[$s]
        $allocFixed = if ($nSpokes -gt 0) { $fixedTotal / $nSpokes } else { 0 }
        $allocVar = if ($totalWeight -gt 0) { $varTotal * ($w / $totalWeight) } elseif ($nSpokes -gt 0) { $varTotal / $nSpokes } else { 0 }
        $allocShared = $allocFixed + $allocVar
        $ownCost = if ($maps.BySub.ContainsKey($s)) { [double]$maps.BySub[$s] } else { 0.0 }

        $allocations += [PSCustomObject]@{
            Spoke           = $s
            WeightUnits     = [math]::Round($w, 2)
            WeightPct       = if ($totalWeight -gt 0) { [math]::Round(($w / $totalWeight) * 100, 1) } else { [math]::Round(100.0 / [math]::Max($nSpokes, 1), 1) }
            AllocatedFixed  = [math]::Round($allocFixed, 2)
            AllocatedVar    = [math]::Round($allocVar, 2)
            AllocatedShared = [math]::Round($allocShared, 2)
            OwnCost         = [math]::Round($ownCost, 2)
            SolutionCost    = [math]::Round($ownCost + $allocShared, 2)
        }
    }
    $allocations = @($allocations | Sort-Object SolutionCost -Descending)

    $notes = @()
    if ($WeightingMethod -in @('equal', 'resourceCount')) {
        $notes += "Weighting '$WeightingMethod' is a proxy estimate, not metered transfer. Use weightingMethod=trafficAnalytics (with workspaceId) or supply inline GB/TB per spoke for an exact split."
    }
    elseif ($totalWeight -le 0) {
        if ($WeightingMethod -eq 'trafficAnalytics') {
            $notes += 'Traffic Analytics returned no GB for any spoke; variable cost was split evenly. Verify the workspace has flow logs/Traffic Analytics enabled and that the query returns Spoke + GB columns.'
        }
        else {
            $notes += 'No inline weighting values resolved for any spoke; variable cost was split evenly. Provide weightingValues keyed by spoke subscription id.'
        }
    }
    if ($maps.Source -eq 'LiveApi') {
        $notes += 'Costs are live Cost Management actuals (month-to-date). Per-spoke ExpressRoute attribution cannot come from billing - it relies on the weighting key.'
    }

    # Ready-to-paste targets for set_cost_allocation_rule: each spoke's share of
    # the whole pool as a whole percentage, already normalized to sum 100.00.
    $ruleTargets = @()
    if ($poolTotal -gt 0 -and @($allocations).Count -gt 0) {
        $rtInput = @($allocations | ForEach-Object { @{ subscriptionId = $_.Spoke; allocatedShared = $_.AllocatedShared } })
        $rt = ConvertTo-AllocationPercentages -Targets $rtInput -TargetDimension 'SubscriptionId'
        if ($rt.Ok) {
            $ruleTargets = @($rt.Values | ForEach-Object { [PSCustomObject]@{ subscriptionId = $_.name; percentage = $_.percentage } })
            $notes += 'RuleTargets is ready to paste straight into set_cost_allocation_rule (targets); percentages already sum to 100.'
        }
    }

    return [PSCustomObject]@{
        HasData         = $true
        Period          = 'MonthToDate'
        Source          = $maps.Source
        Currency        = $maps.Currency
        WeightingMethod = $WeightingMethod
        FixedRatio      = $FixedRatio
        SharedPool      = [PSCustomObject]@{
            TotalCost = [math]::Round($poolTotal, 2)
            Resources = @($poolResources | Sort-Object Cost -Descending)
        }
        Allocations     = $allocations
        RuleTargets     = $ruleTargets
        Note            = ($notes -join ' ')
    }
}
