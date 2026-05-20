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
    $useMgScope = Test-MgCostScope
    $mgPath = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

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
        # Try MG scope for aggregate totals
        if ($useMgScope) {
            $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body
            if ($response.StatusCode -eq 200) {
                $result = ($response.Content | ConvertFrom-Json)
                if ($result.properties.rows) {
                    $months = Parse-CostRows -Rows $result.properties.rows -Columns $result.properties.columns
                }
            } else {
                if ($response.StatusCode -in @(401, 403)) { Set-MgCostScopeFailed }
                Write-Warning "  MG-scope cost trend returned HTTP $($response.StatusCode) - falling back to per-sub"
                $useMgScope = $false
            }
        }

        # Always query per-subscription for the subscription dropdown
        if ($Subscriptions) {
            $subCount = $Subscriptions.Count
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

                        # Build aggregate if MG scope didn't work
                        if (-not $useMgScope -or $months.Count -eq 0) {
                            foreach ($sm in $subMonths) {
                                $key = $sm.MonthDate.ToString('yyyy-MM')
                                if (-not $aggTotals.ContainsKey($key)) {
                                    $aggTotals[$key] = @{ Cost = 0; Date = $sm.MonthDate; Currency = $sm.Currency }
                                }
                                $aggTotals[$key].Cost += $sm.Cost
                            }
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

            # Use aggregated per-sub data if MG scope had no data
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
