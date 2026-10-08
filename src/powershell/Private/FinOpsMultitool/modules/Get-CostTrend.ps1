# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Read-only: builds in-memory objects and changes no state.')]
param()

###########################################################################
# GET-COSTTREND.PS1
# AZURE FINOPS MULTITOOL - 6-Month Cost Trend Data
###########################################################################
# Purpose: Query Cost Management for the last 6 months of actual spend,
#          returning monthly totals suitable for a bar chart display.
###########################################################################

function Get-CostTrend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [switch]$RestrictToSelected
    )

    Write-Host "  Querying six full months and current month-to-date cost trend..." -ForegroundColor Cyan

    $now = (Get-Date).ToUniversalTime()
    $periodEnd = $now.AddTicks( - ($now.Ticks % [TimeSpan]::TicksPerSecond))
    $periodStart = $periodEnd.Date.AddDays(1 - $periodEnd.Day).AddMonths(-6)
    $fromStr = $periodStart.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $toStr = $periodEnd.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $subscriptionNames = @{}
    foreach ($subscription in $Subscriptions) {
        if ($subscription.Id) {
            $subscriptionNames[[string]$subscription.Id] = if ($subscription.Name) { [string]$subscription.Name } else { [string]$subscription.Id }
        }
    }
    $noDataSubscriptionIds = [System.Collections.Generic.List[string]]::new()
    $individuallyQueriedIds = [System.Collections.Generic.List[string]]::new()
    $queryErrors = [System.Collections.Generic.List[string]]::new()
    $queryScope = $null

    $body = @{
        type       = 'ActualCost'
        timeframe  = 'Custom'
        timePeriod = @{
            from = $fromStr
            to   = $toStr
        }
        dataset    = @{
            granularity = 'Monthly'
            aggregation = @{
                totalCost = @{ name = 'Cost'; function = 'Sum' }
            }
        }
    } | ConvertTo-Json -Depth 10

    $months = [System.Collections.Generic.List[PSCustomObject]]::new()
    $bySubscription = @{}   # key = subId, value = sorted list of month entries

    # When the user picked a subset of subscriptions we KEEP the single fast
    # MG-scope grouped call but add a server-side SubscriptionId filter so the
    # trend only includes the selected subs - avoids per-subscription fan-out.
    $subFilter = if ($RestrictToSelected -or $subscriptionNames.Count -gt 0) { Get-CostSubscriptionFilter -Subscriptions $Subscriptions } else { $null }

    # Grouped variant: one MG-scope call returns the per-subscription matrix
    # (month x subscription) in a single response, avoiding an N-subscription loop.
    $groupedDataset = @{
        granularity = 'Monthly'
        aggregation = @{
            totalCost = @{ name = 'Cost'; function = 'Sum' }
        }
        grouping    = @(
            @{ type = 'Dimension'; name = 'SubscriptionId' }
        )
    }
    if ($subFilter) { $groupedDataset['filter'] = $subFilter }
    $groupedBody = @{
        type       = 'ActualCost'
        timeframe  = 'Custom'
        timePeriod = @{
            from = $fromStr
            to   = $toStr
        }
        dataset    = $groupedDataset
    } | ConvertTo-Json -Depth 10

    # Helper: parse cost query rows into month entries
    function ConvertFrom-TrendCostRow {
        param($Rows, $Columns)
        $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
        if (-not $Rows) { return $entries }

        $costIdx = Get-CostColumnIndex -Columns $Columns -Names @('cost', 'pretaxcost', 'costusd', 'totalcost')
        $dateIdx = Get-CostColumnIndex -Columns $Columns -Names @('billingmonth', 'usagedate')
        $currIdx = Get-CostColumnIndex -Columns $Columns -Names @('currency', 'billingcurrency')
        if ($costIdx -lt 0 -or $dateIdx -lt 0 -or $currIdx -lt 0) {
            throw 'Cost trend requires explicit cost, date, and currency columns; results are incomplete.'
        }

        foreach ($row in $Rows) {
            $cost = [math]::Round([double]$row[$costIdx], 2)
            $dateVal = $row[$dateIdx].ToString()
            $dateClean = $dateVal -replace '[^0-9\-]', ''
            if ($dateClean.Length -eq 8) {
                $parsed = [datetime]::ParseExact($dateClean, 'yyyyMMdd', $null)
            }
            else {
                $parsed = [datetime]::Parse($dateVal)
            }
            $currency = ([string]$row[$currIdx]).Trim().ToUpperInvariant()
            if ($currency -notmatch '^[A-Z]{3}$' -or $currency -in @('XXX', 'XTS')) { throw 'Cost trend currency is unavailable or invalid.' }
            [void]$entries.Add([PSCustomObject]@{
                    Month     = $parsed.ToString('MMM yyyy')
                    MonthDate = $parsed
                    Cost      = $cost
                    Currency  = $currency
                })
        }
        return $entries
    }

    # Cost Management answers one page at a time. Reading only the first page
    # under-reports a large scope as lower spend rather than as an error, so
    # every page is collected before the rows are parsed.
    function Get-AllCostRow {
        param($FirstResponse, [string]$Payload, [string]$Context)
        $rows = [System.Collections.Generic.List[object]]::new()
        $columns = $null
        foreach ($page in (Get-CostQueryResponsePage -FirstResponse $FirstResponse -Payload $Payload -Context $Context)) {
            $parsed = ($page.Content | ConvertFrom-Json)
            if (-not $columns) { $columns = $parsed.properties.columns }
            foreach ($row in @($parsed.properties.rows)) { [void]$rows.Add($row) }
        }
        return [PSCustomObject]@{ Rows = @($rows); Columns = $columns }
    }

    try {
        # Parse a SubscriptionId-grouped Monthly response into per-sub entries.
        function ConvertFrom-GroupedCostRow {
            param($Rows, $Columns)
            $out = [System.Collections.Generic.List[PSCustomObject]]::new()
            if (-not $Rows) { return $out }
            $costIdx = Get-CostColumnIndex -Columns $Columns -Names @('cost', 'pretaxcost', 'costusd', 'totalcost')
            $dateIdx = Get-CostColumnIndex -Columns $Columns -Names @('billingmonth', 'usagedate')
            $currIdx = Get-CostColumnIndex -Columns $Columns -Names @('currency', 'billingcurrency')
            $subIdx = Get-CostColumnIndex -Columns $Columns -Names @('subscriptionid')
            if ($costIdx -lt 0 -or $dateIdx -lt 0 -or $currIdx -lt 0 -or $subIdx -lt 0) {
                throw 'Grouped cost trend requires explicit cost, date, currency, and subscription columns; results are incomplete.'
            }
            foreach ($row in $Rows) {
                $subId = [string]$row[$subIdx]
                if ([string]::IsNullOrWhiteSpace($subId)) { throw 'Cost trend subscription is missing; results are incomplete.' }
                if ($subscriptionNames.Count -gt 0 -and -not $subscriptionNames.ContainsKey($subId)) { continue }
                $cost = [math]::Round([double]$row[$costIdx], 2)
                $dateVal = $row[$dateIdx].ToString()
                $dateClean = $dateVal -replace '[^0-9\-]', ''
                if ($dateClean.Length -eq 8) {
                    $parsed = [datetime]::ParseExact($dateClean, 'yyyyMMdd', $null)
                }
                else {
                    $parsed = [datetime]::Parse($dateVal)
                }
                $currency = ([string]$row[$currIdx]).Trim().ToUpperInvariant()
                if ($currency -notmatch '^[A-Z]{3}$' -or $currency -in @('XXX', 'XTS')) { throw 'Cost trend currency is unavailable or invalid.' }
                [void]$out.Add([PSCustomObject]@{
                        SubId     = $subId
                        Month     = $parsed.ToString('MMM yyyy')
                        MonthDate = $parsed
                        Cost      = $cost
                        Currency  = $currency
                    })
            }
            return $out
        }

        # Build the aggregate month list + per-sub breakdown from grouped entries.
        function Set-TrendFromGrouped {
            param($Entries)
            $agg = @{}
            foreach ($e in $Entries) {
                if ($e.SubId) {
                    if (-not $bySubscription.ContainsKey($e.SubId)) {
                        $bySubscription[$e.SubId] = [System.Collections.Generic.List[PSCustomObject]]::new()
                    }
                    [void]$bySubscription[$e.SubId].Add([PSCustomObject]@{
                            Month = $e.Month; MonthDate = $e.MonthDate; Cost = $e.Cost; Currency = $e.Currency
                        })
                }
                $key = $e.MonthDate.ToString('yyyy-MM')
                if (-not $agg.ContainsKey($key)) {
                    # Track every currency in the month, not just the first seen.
                    $agg[$key] = @{ Cost = 0; Date = $e.MonthDate; Currencies = @{} }
                }
                Add-CurrencySeen -Seen $agg[$key].Currencies -Currency $e.Currency
                if ($agg[$key].Currencies.Count -ne 1) { throw 'Cost trend cannot combine multiple billing currency values in one monthly total.' }
                $agg[$key].Cost += $e.Cost
            }
            foreach ($k in @($bySubscription.Keys)) {
                $bySubscription[$k] = @($bySubscription[$k] | Sort-Object MonthDate)
            }
            foreach ($entry in $agg.GetEnumerator() | Sort-Object Key) {
                [void]$months.Add([PSCustomObject]@{
                        Month     = $entry.Value.Date.ToString('MMM yyyy')
                        MonthDate = $entry.Value.Date
                        Cost      = [math]::Round($entry.Value.Cost, 2)
                        Currency  = Resolve-CurrencyLabel -Seen $entry.Value.Currencies
                    })
            }
        }

        $subCount = if ($Subscriptions) { $Subscriptions.Count } else { 0 }

        # -- Fast path: single subscription in scope ---------------------
        # No management-group resolution needed - the subscription IS the
        # scope. One direct query populates both the aggregate and the
        # single-sub breakdown, avoiding the throttle-prone MG probe loop.
        if ($subCount -eq 1) {
            $only = $Subscriptions[0]
            $queryScope = "/subscriptions/$($only.Id)"
            $subPath = "/subscriptions/$($only.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $body
            $paged = Get-AllCostRow -FirstResponse $subResp -Payload $body -Context "cost trend for $($only.Name)"
            if ($paged.Rows.Count -gt 0) {
                $months = ConvertFrom-TrendCostRow -Rows $paged.Rows -Columns $paged.Columns
                $bySubscription[$only.Id] = @($months | Sort-Object MonthDate)
            }
            else { $noDataSubscriptionIds.Add([string]$only.Id) }
        }
        else {
            # -- Multi-sub path: one grouped MG-scope query ---------------
            # group by SubscriptionId so a single call returns the month x
            # subscription matrix (aggregate + per-sub) in one response.
            # Keep the grouped query filtered to the selected subscriptions.
            $mgScopeId = Resolve-CostMgId -TenantId $TenantId
            $useMgScope = [bool]$mgScopeId
            $groupedOk = $false

            if ($useMgScope) {
                $queryScope = "/providers/Microsoft.Management/managementGroups/$mgScopeId"
                $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $groupedBody
                if ($response.StatusCode -eq 200) {
                    $paged = Get-AllCostRow -FirstResponse $response -Payload $groupedBody -Context 'management-group cost trend'
                    if ($paged.Rows.Count -gt 0) {
                        $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
                        foreach ($entry in @(ConvertFrom-GroupedCostRow -Rows $paged.Rows -Columns $paged.Columns)) { $entries.Add($entry) }
                        if ($entries.Count -gt 0) {
                            # The group omits selected subscriptions outside it and those without cost rows.
                            $returnedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                            foreach ($entry in $entries) { [void]$returnedIds.Add([string]$entry.SubId) }
                            $omittedIds = @($subscriptionNames.Keys | Where-Object { -not $returnedIds.Contains([string]$_) } | Sort-Object)
                            if ($omittedIds.Count -gt 0) {
                                Write-Host "  The management-group response omitted $($omittedIds.Count) selected subscription(s). Querying them individually..." -ForegroundColor Yellow
                            }
                            $i = 0
                            foreach ($subId in $omittedIds) {
                                $i++
                                if ($i -eq 1 -or $i -eq $omittedIds.Count -or ($omittedIds.Count -gt 5 -and $i % [math]::Max(1, [int]($omittedIds.Count / 10)) -eq 0)) {
                                    if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                                        Update-ScanStatus "Querying omitted subscriptions for cost trend ($i/$($omittedIds.Count))..."
                                    }
                                }
                                $individuallyQueriedIds.Add($subId)
                                try {
                                    $subResp = Invoke-AzRestMethodWithRetry -Path "/subscriptions/$subId/providers/Microsoft.CostManagement/query?api-version=2023-11-01" -Method POST -Payload $body
                                    $subPaged = Get-AllCostRow -FirstResponse $subResp -Payload $body -Context "cost trend for $($subscriptionNames[$subId])"
                                    $subMonths = @(ConvertFrom-TrendCostRow -Rows $subPaged.Rows -Columns $subPaged.Columns)
                                }
                                catch {
                                    $queryErrors.Add("$($subscriptionNames[$subId]) [$subId]: $($_.Exception.Message)")
                                    continue
                                }
                                if ($subMonths.Count -eq 0) { $noDataSubscriptionIds.Add($subId); continue }
                                foreach ($subMonth in $subMonths) {
                                    $entries.Add([PSCustomObject]@{ SubId = $subId; Month = $subMonth.Month; MonthDate = $subMonth.MonthDate; Cost = $subMonth.Cost; Currency = $subMonth.Currency })
                                }
                            }
                            if ($queryErrors.Count -gt 0) {
                                Write-Warning "$($queryErrors.Count) individual cost trend queries failed. Those subscriptions stay unverified and aren't counted as zero cost."
                            }
                        }
                        Set-TrendFromGrouped -Entries $entries
                        $groupedOk = ($months.Count -gt 0)
                    }
                }
                else {
                    if ($response.StatusCode -in @(401, 403)) { Set-MgCostScopeFailed }
                    Write-Warning "  MG-scope grouped cost trend returned HTTP $($response.StatusCode) - falling back to per-sub"
                    $useMgScope = $false
                }
            }

            # -- Fallback: per-subscription loop (MG scope unavailable) ---
            if (-not $groupedOk -and $Subscriptions) {
                $queryScope = 'Individual selected-subscription queries'
                $aggTotals = @{}  # used for aggregate if MG scope failed

                $i = 0
                foreach ($sub in $Subscriptions) {
                    $i++
                    if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
                        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                            Update-ScanStatus "Querying cost trend ($i/$subCount subs)..."
                        }
                    }

                    $subPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                    $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $body

                    $paged = Get-AllCostRow -FirstResponse $subResp -Payload $body -Context "cost trend for $($sub.Name)"
                    if ($paged.Rows.Count -gt 0) {
                        $subMonths = ConvertFrom-TrendCostRow -Rows $paged.Rows -Columns $paged.Columns
                        $bySubscription[$sub.Id] = @($subMonths | Sort-Object MonthDate)

                        foreach ($sm in $subMonths) {
                            $key = $sm.MonthDate.ToString('yyyy-MM')
                            if (-not $aggTotals.ContainsKey($key)) {
                                $aggTotals[$key] = @{ Cost = 0; Date = $sm.MonthDate; Currency = $sm.Currency }
                            }
                            if ($aggTotals[$key].Currency -ne $sm.Currency) { throw 'Cost trend cannot combine multiple billing currency values in one monthly total.' }
                            $aggTotals[$key].Cost += $sm.Cost
                        }
                    }
                    else { $noDataSubscriptionIds.Add([string]$sub.Id) }
                }

                if ($months.Count -eq 0 -and $aggTotals.Count -gt 0) {
                    foreach ($entry in $aggTotals.GetEnumerator() | Sort-Object Key) {
                        [void]$months.Add([PSCustomObject]@{
                                Month     = $entry.Value.Date.ToString('MMM yyyy')
                                MonthDate = $entry.Value.Date
                                Cost      = [math]::Round($entry.Value.Cost, 2)
                                Currency  = $entry.Value.Currency
                            })
                    }
                }
            }
        }
    }
    catch {
        throw "Cost trend query failed: $($_.Exception.Message)"
    }

    # Sort by date
    $sorted = @($months | Sort-Object MonthDate)
    $unverifiedSubscriptionIds = @($subscriptionNames.Keys | Where-Object {
            -not $bySubscription.ContainsKey($_) -and $_ -notin $noDataSubscriptionIds
        } | Sort-Object)
    $coverageIncomplete = $subscriptionNames.Count -eq 0 -or $unverifiedSubscriptionIds.Count -gt 0
    $note = if ($subscriptionNames.Count -eq 0) {
        'The selected subscription set was not recorded. These results do not establish whole-tenant coverage.'
    }
    elseif ($unverifiedSubscriptionIds.Count -gt 0) {
        "Trend coverage is not verified for $($unverifiedSubscriptionIds.Count) selected subscription(s). The management-group response omitted them, and their individual queries failed. Missing subscriptions are not treated as zero cost."
    }
    elseif ($noDataSubscriptionIds.Count -gt 0) {
        "$($noDataSubscriptionIds.Count) selected subscription(s) returned no cost rows. No zero-valued months were added for them."
    }
    else { $null }

    return [PSCustomObject]@{
        Months                    = $sorted
        BySubscription            = $bySubscription
        HasData                   = ($sorted.Count -gt 0)
        ScopeKind                 = if ($subscriptionNames.Count -gt 0) { 'Selected subscriptions' } else { 'Management group' }
        TenantId                  = $TenantId
        QueryScope                = $queryScope
        SubscriptionNames         = $subscriptionNames
        SelectedSubscriptionCount = $subscriptionNames.Count
        SubscriptionsWithData     = $bySubscription.Count
        NoDataSubscriptionIds     = $noDataSubscriptionIds.ToArray()
        UnverifiedSubscriptionIds = $unverifiedSubscriptionIds
        IndividuallyQueriedIds    = $individuallyQueriedIds.ToArray()
        QueryErrors               = $queryErrors.ToArray()
        CoverageIncomplete        = $coverageIncomplete
        CostBasis                 = 'ActualCost'
        CostPeriodStartUtc        = $periodStart
        CostPeriodEndUtc          = $periodEnd
        Note                      = $note
    }
}
