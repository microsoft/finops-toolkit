###########################################################################
# GET-SAVINGSREALIZED.PS1
# AZURE FINOPS MULTITOOL - Savings Already Realized from Commitments
###########################################################################
# Purpose: Calculate how much existing RIs, Savings Plans, and AHB have
#          already saved vs pay-as-you-go. This is the "value delivered"
#          metric that FinOps teams report to leadership.
###########################################################################

function Get-SavingsRealized {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object]$CommitmentData
    )

    Write-Host "  Calculating savings already realized..." -ForegroundColor Cyan

    $riSavings  = 0
    $spSavings  = 0
    $ahbSavings = 0
    $details    = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -- Short-circuit: skip RI/SP queries if no commitments exist -------
    $hasCommitments = $true
    if ($CommitmentData -and $CommitmentData.PSObject.Properties['HasData']) {
        if (-not $CommitmentData.HasData) {
            $hasCommitments = $false
            Write-Host "  No reservations or savings plans detected — skipping commitment savings queries" -ForegroundColor DarkGray
        }
    }

    $gotMgData = $false
    $subCount  = if ($Subscriptions) { $Subscriptions.Count } else { 0 }

    # Map subscription Id -> friendly name so MG-grouped rows keep per-sub attribution
    $subNameById = @{}
    foreach ($s in $Subscriptions) { $subNameById[$s.Id] = $s.Name }

    # Build a Cost Management query body with the requested grouping dimensions
    function New-SavingsQueryBody {
        param([string]$Type, [string[]]$Dimensions)
        @{
            type      = $Type
            timeframe = 'MonthToDate'
            dataset   = @{
                granularity = 'None'
                aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                grouping    = @($Dimensions | ForEach-Object { @{ type = 'Dimension'; name = $_ } })
            }
        } | ConvertTo-Json -Depth 10
    }

    # Resolve named column indices from a Cost Management query result
    function Get-SavingsColMap {
        param($Columns)
        $map = @{ Cost = 0; ChargeType = -1; PricingModel = -1; SubscriptionId = -1 }
        for ($c = 0; $c -lt $Columns.Count; $c++) {
            switch ($Columns[$c].name) {
                'Cost'           { $map.Cost = $c }
                'ChargeType'     { $map.ChargeType = $c }
                'PricingModel'   { $map.PricingModel = $c }
                'SubscriptionId' { $map.SubscriptionId = $c }
            }
        }
        $map
    }

    # Parse an ActualCost result for UnusedReservation waste; returns detail rows
    function Read-SavingsActual {
        param($Result)
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        if (-not $Result -or -not $Result.properties.rows) { return $rows }
        $m = Get-SavingsColMap -Columns $Result.properties.columns
        foreach ($row in $Result.properties.rows) {
            $charge = if ($m.ChargeType -ge 0) { [string]$row[$m.ChargeType] } else { '' }
            if ($charge -match 'UnusedReservation') {
                $sub = 'All (MG scope)'
                if ($m.SubscriptionId -ge 0) {
                    $sid = [string]$row[$m.SubscriptionId]
                    $sub = if ($subNameById.ContainsKey($sid)) { $subNameById[$sid] } else { $sid }
                }
                $rows.Add([PSCustomObject]@{
                    Subscription = $sub
                    Category     = 'Unused Reservation'
                    Amount       = [math]::Round([double]$row[$m.Cost], 2)
                    Type         = 'Waste'
                })
            }
        }
        return $rows
    }

    # Parse an AmortizedCost result for RI/SP benefit; returns rows + savings totals
    function Read-SavingsAmort {
        param($Result)
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        $ri = 0.0; $sp = 0.0
        if ($Result -and $Result.properties.rows) {
            $m = Get-SavingsColMap -Columns $Result.properties.columns
            foreach ($row in $Result.properties.rows) {
                $pm   = if ($m.PricingModel -ge 0) { [string]$row[$m.PricingModel] } else { '' }
                $cost = [math]::Round([double]$row[$m.Cost], 2)
                $sub  = 'All (MG scope)'
                if ($m.SubscriptionId -ge 0) {
                    $sid = [string]$row[$m.SubscriptionId]
                    $sub = if ($subNameById.ContainsKey($sid)) { $subNameById[$sid] } else { $sid }
                }
                if ($pm -match 'Reservation') {
                    $ri += $cost * 0.4
                    $rows.Add([PSCustomObject]@{ Subscription = $sub; Category = 'Reservation Benefit'; Amount = $cost; Type = 'Commitment' })
                }
                elseif ($pm -match 'SavingsPlan') {
                    $sp += $cost * 0.25
                    $rows.Add([PSCustomObject]@{ Subscription = $sub; Category = 'Savings Plan Benefit'; Amount = $cost; Type = 'Commitment' })
                }
            }
        }
        return [PSCustomObject]@{ Rows = $rows; RI = $ri; SP = $sp }
    }

    if ($hasCommitments -and $subCount -eq 1) {
        # -- Strategy 0: single-subscription fast path (skip MG resolution entirely) --
        $only = $Subscriptions[0]
        try {
            Write-Host "  Calculating savings (single subscription, direct scope)..." -ForegroundColor Cyan
            $subPath = "/subscriptions/$($only.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

            $actualResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload (New-SavingsQueryBody -Type 'ActualCost' -Dimensions @('ChargeType'))
            if ($actualResp.StatusCode -eq 200) {
                foreach ($d in (Read-SavingsActual -Result ($actualResp.Content | ConvertFrom-Json))) {
                    $d.Subscription = $only.Name; [void]$details.Add($d)
                }
            }

            $amortResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload (New-SavingsQueryBody -Type 'AmortizedCost' -Dimensions @('PricingModel'))
            if ($amortResp.StatusCode -eq 200) {
                $parsed = Read-SavingsAmort -Result ($amortResp.Content | ConvertFrom-Json)
                foreach ($d in $parsed.Rows) { $d.Subscription = $only.Name; [void]$details.Add($d) }
                $riSavings += $parsed.RI
                $spSavings += $parsed.SP
            }

            $gotMgData = $true
            Write-Host "  Single-subscription savings calculated (2 API calls)" -ForegroundColor Green
        } catch {
            Write-Warning "  Single-subscription savings query failed: $($_.Exception.Message)"
        }
    }
    elseif ($hasCommitments) {
        # -- Strategy 1: MG-scope grouped by SubscriptionId (2 calls, per-sub attribution) --
        $mgScopeId = if ($TenantId) { Resolve-CostMgId -TenantId $TenantId } else { $null }
        if ($mgScopeId) {
            try {
                Write-Host "  Calculating savings (MG scope, grouped by subscription)..." -ForegroundColor Cyan
                $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

                $actualResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload (New-SavingsQueryBody -Type 'ActualCost' -Dimensions @('SubscriptionId', 'ChargeType'))
                if ($actualResp.StatusCode -in @(401, 403)) {
                    Set-MgCostScopeFailed
                    throw "MG-scope savings query returned HTTP $($actualResp.StatusCode)"
                }
                if ($actualResp.StatusCode -eq 200) {
                    foreach ($d in (Read-SavingsActual -Result ($actualResp.Content | ConvertFrom-Json))) { [void]$details.Add($d) }
                }

                $amortResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload (New-SavingsQueryBody -Type 'AmortizedCost' -Dimensions @('SubscriptionId', 'PricingModel'))
                if ($amortResp.StatusCode -eq 200) {
                    $parsed = Read-SavingsAmort -Result ($amortResp.Content | ConvertFrom-Json)
                    foreach ($d in $parsed.Rows) { [void]$details.Add($d) }
                    $riSavings += $parsed.RI
                    $spSavings += $parsed.SP
                }

                $gotMgData = $true
                Write-Host "  MG scope savings calculated (2 API calls)" -ForegroundColor Green
            } catch {
                Write-Warning "  MG-scope savings query failed: $($_.Exception.Message)"
            }
        }
    }

    # -- Strategy 2: Per-subscription fallback (only if MG/direct scope unavailable) --
    if ($hasCommitments -and -not $gotMgData) {
    # -- Step 1: Query amortized vs actual to find RI/SP benefit amounts --
    # The difference between ActualCost and AmortizedCost reveals commitment savings
    $subCount = $Subscriptions.Count
    $i = 0
    foreach ($sub in $Subscriptions) {
        $i++
        if ($subCount -gt 5 -and ($i -eq 1 -or $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
            if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                Update-ScanStatus "Calculating savings ($i/$subCount subs)..."
            }
        }
        try {
            # Get ActualCost MonthToDate
            $actualBody = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                    grouping = @(
                        @{ type = 'Dimension'; name = 'ChargeType' }
                    )
                }
            } | ConvertTo-Json -Depth 10

            $subPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $actualResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $actualBody

            if ($actualResp.StatusCode -eq 200) {
                $actualResult = ($actualResp.Content | ConvertFrom-Json)
                if ($actualResult.properties.rows) {
                    foreach ($row in $actualResult.properties.rows) {
                        $chargeType = $row[1]
                        $cost = [math]::Round([double]$row[0], 2)

                        # RI/SP purchases show as separate charge types
                        if ($chargeType -match 'UnusedReservation') {
                            # This is wasted money — unused RI capacity
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = $sub.Name
                                Category     = 'Unused Reservation'
                                Amount       = $cost
                                Type         = 'Waste'
                            })
                        }
                    }
                }
            }

            # Get benefit usage via the reservation transactions or amortized view
            $amortBody = @{
                type      = 'AmortizedCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                    grouping = @(
                        @{ type = 'Dimension'; name = 'PricingModel' }
                    )
                }
            } | ConvertTo-Json -Depth 10

            $amortResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $amortBody
            if ($amortResp.StatusCode -eq 200) {
                $amortResult = ($amortResp.Content | ConvertFrom-Json)
                if ($amortResult.properties.rows) {
                    foreach ($row in $amortResult.properties.rows) {
                        $pricingModel = $row[1]
                        $cost = [math]::Round([double]$row[0], 2)

                        if ($pricingModel -match 'Reservation') {
                            # Amortized RI cost — the actual RI spend
                            $riSavings += $cost * 0.4  # Approximate: RIs typically save ~40% vs PAYG
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = $sub.Name
                                Category     = 'Reservation Benefit'
                                Amount       = $cost
                                Type         = 'Commitment'
                            })
                        }
                        elseif ($pricingModel -match 'SavingsPlan') {
                            $spSavings += $cost * 0.25  # Approximate: SPs save ~25% on average
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = $sub.Name
                                Category     = 'Savings Plan Benefit'
                                Amount       = $cost
                                Type         = 'Commitment'
                            })
                        }
                    }
                }
            }
        } catch {
            Write-Warning "  Savings query failed for $($sub.Name): $($_.Exception.Message)"
        }
    }
    } # end per-sub fallback

    # -- Step 2: AHB savings estimate from Resource Graph -----------------
    try {
        $ahbQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.licenseType == 'Windows_Server'
| summarize AHBVMs = count()
"@
        $subIds = $Subscriptions | ForEach-Object { $_.Id }
        $ahbResult = Search-AzGraphSafe -Query $ahbQuery -Subscription $subIds
        if ($ahbResult.Data -and $ahbResult.Data.Count -gt 0) {
            $ahbVMCount = $ahbResult.Data[0].AHBVMs
            # Average D2s v3 Windows license cost is ~$100/mo; AHB saves ~$50/mo per VM
            $ahbSavings = $ahbVMCount * 50  # Conservative monthly estimate
            [void]$details.Add([PSCustomObject]@{
                Subscription = 'All'
                Category     = 'Azure Hybrid Benefit (VMs)'
                Amount       = $ahbSavings
                Type         = 'AHB'
            })
        }
    } catch {
        Write-Warning "  AHB count query failed: $($_.Exception.Message)"
    }

    $totalMonthly = [math]::Round($riSavings + $spSavings + $ahbSavings, 2)
    $totalAnnual  = [math]::Round($totalMonthly * 12, 2)

    return [PSCustomObject]@{
        RISavingsMonthly   = [math]::Round($riSavings, 2)
        SPSavingsMonthly   = [math]::Round($spSavings, 2)
        AHBSavingsMonthly  = [math]::Round($ahbSavings, 2)
        TotalMonthly       = $totalMonthly
        TotalAnnual        = $totalAnnual
        Details            = @($details)
        HasData            = ($totalMonthly -gt 0 -or $details.Count -gt 0)
    }
}
