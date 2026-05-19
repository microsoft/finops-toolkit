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

    # -- Strategy 1: MG-scope queries (2 API calls instead of N*2) ------
    if ($hasCommitments -and $TenantId -and (Test-MgCostScope)) {
        try {
            Write-Host "  Calculating savings (MG scope)..." -ForegroundColor Cyan
            $mgPath = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

            # ActualCost by ChargeType
            $actualBody = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping = @( @{ type = 'Dimension'; name = 'ChargeType' } )
                }
            } | ConvertTo-Json -Depth 10

            $actualResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $actualBody
            if ($actualResp.StatusCode -in @(401, 403)) {
                Set-MgCostScopeFailed
                throw "MG-scope savings query returned HTTP $($actualResp.StatusCode)"
            }
            if ($actualResp.StatusCode -eq 200) {
                $actualResult = ($actualResp.Content | ConvertFrom-Json)
                if ($actualResult.properties.rows) {
                    foreach ($row in $actualResult.properties.rows) {
                        $chargeType = $row[1]
                        $cost = [math]::Round([double]$row[0], 2)
                        if ($chargeType -match 'UnusedReservation') {
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = 'All (MG scope)'
                                Category     = 'Unused Reservation'
                                Amount       = $cost
                                Type         = 'Waste'
                            })
                        }
                    }
                }
            }

            # AmortizedCost by PricingModel
            $amortBody = @{
                type      = 'AmortizedCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping = @( @{ type = 'Dimension'; name = 'PricingModel' } )
                }
            } | ConvertTo-Json -Depth 10

            $amortResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $amortBody
            if ($amortResp.StatusCode -eq 200) {
                $amortResult = ($amortResp.Content | ConvertFrom-Json)
                if ($amortResult.properties.rows) {
                    foreach ($row in $amortResult.properties.rows) {
                        $pricingModel = $row[1]
                        $cost = [math]::Round([double]$row[0], 2)
                        if ($pricingModel -match 'Reservation') {
                            $riSavings += $cost * 0.4
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = 'All (MG scope)'
                                Category     = 'Reservation Benefit'
                                Amount       = $cost
                                Type         = 'Commitment'
                            })
                        }
                        elseif ($pricingModel -match 'SavingsPlan') {
                            $spSavings += $cost * 0.25
                            [void]$details.Add([PSCustomObject]@{
                                Subscription = 'All (MG scope)'
                                Category     = 'Savings Plan Benefit'
                                Amount       = $cost
                                Type         = 'Commitment'
                            })
                        }
                    }
                }
            }

            $gotMgData = $true
            Write-Host "  MG scope savings calculated (2 API calls)" -ForegroundColor Green
        } catch {
            Write-Warning "  MG-scope savings query failed: $($_.Exception.Message)"
        }
    }

    # -- Strategy 2: Per-subscription fallback ---------------------------
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
