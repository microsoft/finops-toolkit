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
        [object[]]$Subscriptions
    )

    Write-Host "  Querying 6-month cost trend..." -ForegroundColor Cyan

    $endDate   = Get-Date -Day 1  # First of current month
    $startDate = $endDate.AddMonths(-6)
    $fromStr   = $startDate.ToString('yyyy-MM-dd')
    $toStr     = (Get-Date).ToString('yyyy-MM-dd')

    $body = @{
        type      = 'ActualCost'
        timeframe = 'Custom'
        timePeriod = @{
            from = $fromStr
            to   = $toStr
        }
        dataset   = @{
            granularity = 'Monthly'
            aggregation = @{
                totalCost = @{ name = 'Cost'; function = 'Sum' }
            }
        }
    } | ConvertTo-Json -Depth 10

    $months = [System.Collections.Generic.List[PSCustomObject]]::new()
    $bySubscription = @{}   # key = subId, value = sorted list of month entries

    # Grouped variant: one MG-scope call returns the per-subscription matrix
    # (month x subscription) in a single response, avoiding an N-subscription loop.
    $groupedBody = @{
        type      = 'ActualCost'
        timeframe = 'Custom'
        timePeriod = @{
            from = $fromStr
            to   = $toStr
        }
        dataset   = @{
            granularity = 'Monthly'
            aggregation = @{
                totalCost = @{ name = 'Cost'; function = 'Sum' }
            }
            grouping    = @(
                @{ type = 'Dimension'; name = 'SubscriptionId' }
            )
        }
    } | ConvertTo-Json -Depth 10

    # Helper: parse cost query rows into month entries
    function Parse-CostRows {
        param($Rows, $Columns)
        $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
        if (-not $Rows) { return $entries }

        $costIdx = -1; $dateIdx = -1; $currIdx = -1
        if ($Columns) {
            for ($ci = 0; $ci -lt $Columns.Count; $ci++) {
                $n = $Columns[$ci].name.ToLower()
                $t = $Columns[$ci].type.ToLower()
                if ($n -match 'cost|precost|pretaxcost') { $costIdx = $ci }
                elseif ($t -eq 'number' -and $costIdx -eq -1) { $costIdx = $ci }
                elseif ($n -match 'billingmonth|usagedate' -or $t -eq 'datetime') { $dateIdx = $ci }
                elseif ($n -match 'currency|billingcurrency') { $currIdx = $ci }
            }
        }
        if ($costIdx -eq -1) { $costIdx = 0 }
        if ($dateIdx -eq -1) { $dateIdx = 1 }
        if ($currIdx -eq -1) { $currIdx = 2 }

        foreach ($row in $Rows) {
            $cost = [math]::Round([double]$row[$costIdx], 2)
            $dateVal = $row[$dateIdx].ToString()
            $dateClean = $dateVal -replace '[^0-9\-]', ''
            if ($dateClean.Length -eq 8) {
                $parsed = [datetime]::ParseExact($dateClean, 'yyyyMMdd', $null)
            } else {
                $parsed = [datetime]::Parse($dateVal)
            }
            $currency = if ($currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
            [void]$entries.Add([PSCustomObject]@{
                Month     = $parsed.ToString('MMM yyyy')
                MonthDate = $parsed
                Cost      = $cost
                Currency  = $currency
            })
        }
        return $entries
    }

    try {
        # Parse a SubscriptionId-grouped Monthly response into per-sub entries.
        function Parse-GroupedCostRows {
            param($Rows, $Columns)
            $out = [System.Collections.Generic.List[PSCustomObject]]::new()
            if (-not $Rows) { return $out }
            $costIdx = -1; $dateIdx = -1; $currIdx = -1; $subIdx = -1
            if ($Columns) {
                for ($ci = 0; $ci -lt $Columns.Count; $ci++) {
                    $n = $Columns[$ci].name.ToLower()
                    $t = $Columns[$ci].type.ToLower()
                    if ($n -match 'subscriptionid') { $subIdx = $ci }
                    elseif ($n -match 'cost|precost|pretaxcost') { $costIdx = $ci }
                    elseif ($n -match 'billingmonth|usagedate' -or $t -eq 'datetime') { $dateIdx = $ci }
                    elseif ($n -match 'currency|billingcurrency') { $currIdx = $ci }
                    elseif ($t -eq 'number' -and $costIdx -eq -1) { $costIdx = $ci }
                }
            }
            if ($costIdx -eq -1) { $costIdx = 0 }
            if ($dateIdx -eq -1) { $dateIdx = 1 }
            foreach ($row in $Rows) {
                $cost = [math]::Round([double]$row[$costIdx], 2)
                $dateVal = $row[$dateIdx].ToString()
                $dateClean = $dateVal -replace '[^0-9\-]', ''
                if ($dateClean.Length -eq 8) {
                    $parsed = [datetime]::ParseExact($dateClean, 'yyyyMMdd', $null)
                } else {
                    $parsed = [datetime]::Parse($dateVal)
                }
                $currency = if ($currIdx -ge 0 -and $currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
                $subId = if ($subIdx -ge 0 -and $subIdx -lt $row.Count) { [string]$row[$subIdx] } else { '' }
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
                    $agg[$key] = @{ Cost = 0; Date = $e.MonthDate; Currency = $e.Currency }
                }
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
                    Currency  = $entry.Value.Currency
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
            $subPath = "/subscriptions/$($only.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $body
            if ($subResp.StatusCode -eq 200) {
                $subResult = ($subResp.Content | ConvertFrom-Json)
                if ($subResult.properties.rows) {
                    $months = Parse-CostRows -Rows $subResult.properties.rows -Columns $subResult.properties.columns
                    $bySubscription[$only.Id] = @($months | Sort-Object MonthDate)
                }
            } else {
                Write-Warning "  Single-sub cost trend returned HTTP $($subResp.StatusCode)"
            }
        }
        else {
            # -- Multi-sub path: one grouped MG-scope query ---------------
            # group by SubscriptionId so a single call returns the month x
            # subscription matrix (aggregate + per-sub) in one response.
            $mgScopeId  = Resolve-CostMgId -TenantId $TenantId
            $useMgScope = [bool]$mgScopeId
            $groupedOk  = $false

            if ($useMgScope) {
                $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $groupedBody
                if ($response.StatusCode -eq 200) {
                    $result = ($response.Content | ConvertFrom-Json)
                    if ($result.properties.rows) {
                        $entries = Parse-GroupedCostRows -Rows $result.properties.rows -Columns $result.properties.columns
                        Set-TrendFromGrouped -Entries $entries
                        $groupedOk = ($months.Count -gt 0)
                    }
                } else {
                    if ($response.StatusCode -in @(401, 403)) { Set-MgCostScopeFailed }
                    Write-Warning "  MG-scope grouped cost trend returned HTTP $($response.StatusCode) - falling back to per-sub"
                    $useMgScope = $false
                }
            }

            # -- Fallback: per-subscription loop (MG scope unavailable) ---
            if (-not $groupedOk -and $Subscriptions) {
                $sampleErrors = 0
                $sampleSize = [math]::Min(3, $subCount)
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

                    if ($subResp.StatusCode -eq 200) {
                        $subResult = ($subResp.Content | ConvertFrom-Json)
                        if ($subResult.properties.rows) {
                            $subMonths = Parse-CostRows -Rows $subResult.properties.rows -Columns $subResult.properties.columns
                            $bySubscription[$sub.Id] = @($subMonths | Sort-Object MonthDate)

                            foreach ($sm in $subMonths) {
                                $key = $sm.MonthDate.ToString('yyyy-MM')
                                if (-not $aggTotals.ContainsKey($key)) {
                                    $aggTotals[$key] = @{ Cost = 0; Date = $sm.MonthDate; Currency = $sm.Currency }
                                }
                                $aggTotals[$key].Cost += $sm.Cost
                            }
                        }
                    } else {
                        if ($i -le $sampleSize) { $sampleErrors++ }
                    }

                    if ($i -eq $sampleSize -and $sampleErrors -eq $sampleSize -and $subCount -gt $sampleSize) {
                        Write-Host "  All $sampleSize sample subs returned errors - skipping remaining $($subCount - $sampleSize) subs" -ForegroundColor Yellow
                        break
                    }
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
    } catch {
        Write-Warning "Cost trend query failed: $($_.Exception.Message)"
    }

    # Sort by date
    $sorted = @($months | Sort-Object MonthDate)

    return [PSCustomObject]@{
        Months         = $sorted
        BySubscription = $bySubscription
        HasData        = ($sorted.Count -gt 0)
    }
}
