###########################################################################
# GET-COMMITMENTUTILIZATION.PS1
# AZURE FINOPS MULTITOOL - RI & Savings Plan Utilization
###########################################################################
# Purpose: Query existing reservation and savings plan utilization to show
#          how well current commitments are being used. This answers the
#          CFO question: "Are we wasting what we already bought?"
###########################################################################

function Get-CommitmentUtilization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$AgreementType
    )

    Write-Host "  Querying commitment utilization..." -ForegroundColor Cyan

    $reservations = @()
    $savingsPlans = @()
    $subIds = $Subscriptions | ForEach-Object { $_.Id }

    # -- Step 0 (MCA/MPA): Resolve billing profiles for this tenant -----
    # Under MCA, reservations and savings plans are scoped to the billing
    # profile, NOT the subscription.  Subscription-level Consumption API
    # calls return empty for MCA agreements.
    $billingProfileIds = @()
    if ($AgreementType -in @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement')) {
        Write-Host "  MCA/MPA detected — resolving billing profiles..." -ForegroundColor Cyan
        # Discover billing account IDs linked to scanned subscriptions
        $tenantBillingAccountIds = @{}
        foreach ($sub in @($Subscriptions | Select-Object -First 10)) {
            try {
                $biPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Billing/billingInfo/default?api-version=2024-04-01"
                $biResp = Invoke-AzRestMethodWithRetry -Path $biPath -Method GET
                if ($biResp.StatusCode -eq 200) {
                    $biResult = ($biResp.Content | ConvertFrom-Json)
                    $baId = $biResult.properties.billingAccountId
                    if ($baId) { $tenantBillingAccountIds[$baId] = $true }
                }
            } catch { }
        }

        # Get billing profiles for those accounts
        try {
            $baPath = "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01"
            $baResp = Invoke-AzRestMethodWithRetry -Path $baPath -Method GET
            if ($baResp.StatusCode -eq 200) {
                $baResult = ($baResp.Content | ConvertFrom-Json)
                foreach ($ba in $baResult.value) {
                    if ($tenantBillingAccountIds.Count -gt 0 -and -not $tenantBillingAccountIds.ContainsKey($ba.id)) {
                        # Normalize — try matching on name portion only
                        $baNamePortion = $ba.id -replace '.*/billingAccounts/', ''
                        $matched = $false
                        foreach ($k in $tenantBillingAccountIds.Keys) {
                            $kName = $k -replace '.*/billingAccounts/', ''
                            if ($kName -eq $baNamePortion) { $matched = $true; break }
                        }
                        if (-not $matched) { continue }
                    }
                    if ($ba.properties.agreementType -notin @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement')) { continue }
                    try {
                        $bpPath = "$($ba.id)/billingProfiles?api-version=2024-04-01"
                        $bpResp = Invoke-AzRestMethodWithRetry -Path $bpPath -Method GET
                        if ($bpResp.StatusCode -eq 200) {
                            $bpResult = ($bpResp.Content | ConvertFrom-Json)
                            foreach ($bp in $bpResult.value) { $billingProfileIds += $bp.id }
                        }
                    } catch { }
                }
            }
        } catch {
            Write-Warning "  Billing profile resolution failed: $($_.Exception.Message)"
        }
        Write-Host "  Found $($billingProfileIds.Count) billing profile(s) for MCA commitment queries." -ForegroundColor Cyan
    }

    # -- Step 1: Get all reservations and their utilization --------------
    # For MCA: query at billing-profile scope first
    if ($billingProfileIds.Count -gt 0) {
        foreach ($bpId in $billingProfileIds) {
            try {
                $summaryPath = "$bpId/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'"
                $resp = Invoke-AzRestMethodWithRetry -Path $summaryPath -Method GET
                if ($resp.StatusCode -eq 200) {
                    $data = ($resp.Content | ConvertFrom-Json)
                    if ($data.value) {
                        foreach ($item in $data.value) {
                            $p = $item.properties
                            $reservations += [PSCustomObject]@{
                                ReservationOrderId = $p.reservationOrderId
                                ReservationId      = $p.reservationId
                                SkuName            = $p.skuName
                                Kind               = $p.kind
                                AvgUtilization     = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                                MinUtilization     = [math]::Round([double]$p.minUtilizationPercentage, 1)
                                MaxUtilization     = [math]::Round([double]$p.maxUtilizationPercentage, 1)
                                ReservedHours      = $p.reservedHours
                                UsedHours          = $p.usedHours
                                UsageDate          = $p.usageDate
                            }
                        }
                    }
                }
            } catch {
                Write-Warning "  Reservation query at billing profile scope failed: $($_.Exception.Message)"
            }
        }
    }

    # For EA / fallback: query at subscription scope
    if ($reservations.Count -eq 0) {
        try {
            $summaryPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'"
            $resp = Invoke-AzRestMethodWithRetry -Path $summaryPath -Method GET
            if ($resp.StatusCode -eq 200) {
                $data = ($resp.Content | ConvertFrom-Json)
                if ($data.value) {
                    foreach ($item in $data.value) {
                        $p = $item.properties
                        $reservations += [PSCustomObject]@{
                            ReservationOrderId = $p.reservationOrderId
                            ReservationId      = $p.reservationId
                            SkuName            = $p.skuName
                            Kind               = $p.kind
                            AvgUtilization     = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                            MinUtilization     = [math]::Round([double]$p.minUtilizationPercentage, 1)
                            MaxUtilization     = [math]::Round([double]$p.maxUtilizationPercentage, 1)
                            ReservedHours      = $p.reservedHours
                            UsedHours          = $p.usedHours
                            UsageDate          = $p.usageDate
                        }
                    }
                    break  # Got data from one sub, don't repeat
                }
            }
        } catch {
            Write-Warning "  Reservation summaries query failed: $($_.Exception.Message)"
        }
    }

    # -- Step 2: Try the Reservation Orders API at billing scope --
    if ($reservations.Count -eq 0) {
        try {
            $roPath = "/providers/Microsoft.Capacity/reservationOrders?api-version=2022-11-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $roPath -Method GET
            if ($resp.StatusCode -eq 200) {
                $data = ($resp.Content | ConvertFrom-Json)
                if ($data.value) {
                    foreach ($order in $data.value) {
                        $op = $order.properties
                        if ($op.reservations) {
                            foreach ($ri in $op.reservations) {
                                # Get utilization summary for each reservation
                                try {
                                    $utilPath = "$($ri.id)/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'"
                                    $utilResp = Invoke-AzRestMethodWithRetry -Path $utilPath -Method GET
                                    if ($utilResp.StatusCode -eq 200) {
                                        $utilData = ($utilResp.Content | ConvertFrom-Json)
                                        if ($utilData.value -and $utilData.value.Count -gt 0) {
                                            $latest = $utilData.value | Select-Object -Last 1
                                            $up = $latest.properties
                                            $reservations += [PSCustomObject]@{
                                                ReservationOrderId = $order.name
                                                ReservationId      = $ri.id.Split('/')[-1]
                                                SkuName            = $op.displayProvisioningState
                                                Kind               = $op.billingScopeId
                                                AvgUtilization     = [math]::Round([double]$up.avgUtilizationPercentage, 1)
                                                MinUtilization     = [math]::Round([double]$up.minUtilizationPercentage, 1)
                                                MaxUtilization     = [math]::Round([double]$up.maxUtilizationPercentage, 1)
                                                ReservedHours      = $up.reservedHours
                                                UsedHours          = $up.usedHours
                                                UsageDate          = $up.usageDate
                                            }
                                        }
                                    }
                                } catch { }
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Warning "  Reservation orders query failed: $($_.Exception.Message)"
        }
    }

    # -- Step 3: Savings Plans utilization via Benefit Utilization Summaries --
    # For MCA: query at billing-profile scope first
    if ($billingProfileIds.Count -gt 0 -and $savingsPlans.Count -eq 0) {
        foreach ($bpId in $billingProfileIds) {
            try {
                $spPath = "$bpId/providers/Microsoft.CostManagement/benefitUtilizationSummaries?api-version=2023-11-01&filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'&grain=Monthly"
                $spResp = Invoke-AzRestMethodWithRetry -Path $spPath -Method GET
                if ($spResp.StatusCode -eq 200) {
                    $spData = ($spResp.Content | ConvertFrom-Json)
                    if ($spData.value) {
                        foreach ($item in $spData.value) {
                            $p = $item.properties
                            if ($p.benefitType -eq 'SavingsPlan') {
                                $savingsPlans += [PSCustomObject]@{
                                    BenefitId       = $p.benefitOrderId
                                    BenefitType     = $p.benefitType
                                    AvgUtilization  = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                                    UsageDate       = $p.usageDate
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-Warning "  Savings plan query at billing profile scope failed: $($_.Exception.Message)"
            }
        }
    }

    # Fallback: subscription scope (EA, PAYG, etc.)
    if ($savingsPlans.Count -eq 0) {
        try {
            foreach ($sub in $Subscriptions | Select-Object -First 5) {
            $spPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/benefitUtilizationSummaries?api-version=2023-11-01&filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'&grain=Monthly"
            $spResp = Invoke-AzRestMethodWithRetry -Path $spPath -Method GET
            if ($spResp.StatusCode -eq 200) {
                $spData = ($spResp.Content | ConvertFrom-Json)
                if ($spData.value) {
                    foreach ($item in $spData.value) {
                        $p = $item.properties
                        if ($p.benefitType -eq 'SavingsPlan') {
                            $savingsPlans += [PSCustomObject]@{
                                BenefitId       = $p.benefitOrderId
                                BenefitType     = $p.benefitType
                                AvgUtilization  = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                                UsageDate       = $p.usageDate
                            }
                        }
                    }
                    if ($savingsPlans.Count -gt 0) { break }
                }
            }
            }
        } catch {
            Write-Warning "  Savings plan utilization query failed: $($_.Exception.Message)"
        }
    }

    # -- Step 4: Calculate summary stats --
    $riAvgUtil = 0
    $riCount = $reservations.Count
    if ($riCount -gt 0) {
        $riAvgUtil = [math]::Round(($reservations | Measure-Object -Property AvgUtilization -Average).Average, 1)
    }

    $spAvgUtil = 0
    $spCount = $savingsPlans.Count
    if ($spCount -gt 0) {
        $spAvgUtil = [math]::Round(($savingsPlans | Measure-Object -Property AvgUtilization -Average).Average, 1)
    }

    $underutilized = @($reservations | Where-Object { $_.AvgUtilization -lt 80 })

    return [PSCustomObject]@{
        Reservations      = $reservations
        SavingsPlans      = $savingsPlans
        RICount           = $riCount
        SPCount           = $spCount
        RIAvgUtilization  = $riAvgUtil
        SPAvgUtilization  = $spAvgUtil
        UnderutilizedRIs  = $underutilized
        HasData           = ($riCount -gt 0 -or $spCount -gt 0)
    }
}
