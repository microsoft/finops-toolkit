# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-COMMITMENTUTILIZATION.PS1
# AZURE FINOPS MULTITOOL - RI & Savings Plan Utilization
###########################################################################
# Purpose: Query existing reservation and savings plan utilization to show
#          how well current commitments are being used. This answers the
#          CFO question: "Are we wasting what we already bought?"
###########################################################################

# Compares two usageDate values so only the newest period per commitment is
# kept. The API returns an ISO string; an unparsable value falls back to an
# ordinal compare, and a missing existing value always loses.
function Test-UsageDateIsNewer {
    param($Candidate, $Existing)

    if ($null -eq $Existing) { return $true }
    if ($null -eq $Candidate) { return $false }

    $c = [datetime]::MinValue
    $e = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Candidate, [ref]$c) -and [datetime]::TryParse([string]$Existing, [ref]$e)) {
        return ($c -gt $e)
    }
    return ([string]$Candidate -gt [string]$Existing)
}

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
    $utilFailures = [System.Collections.Generic.List[string]]::new()
    $savingsPlans = @()
    $subIds = $Subscriptions | ForEach-Object { $_.Id }

    # Set to $true if a reservation/savings-plan query is forbidden (401/403)
    # rather than simply returning no commitments.
    $accessDenied = $false

    # -- Step 0 (MCA/MPA): Resolve billing profiles for this tenant -----
    # Under MCA, reservations and savings plans are scoped to the billing
    # profile, NOT the subscription.  Subscription-level Consumption API
    # calls return empty for MCA agreements.
    $billingProfileIds = @()
    if ($AgreementType -in @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement')) {
        Write-Host "  MCA/MPA detected — resolving billing profiles..." -ForegroundColor Cyan
        # Get billing profiles for the accounts that own a scanned subscription.
        # The previous subscription-scoped lookup used billingInfo/default, which is
        # not a valid resource type, so the account set was always empty and the
        # filter below was skipped entirely - every reachable MCA account was used.
        try {
            $baPath = "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01"
            $baResp = Invoke-AzRestMethodWithRetry -Path $baPath -Method GET
            if ($baResp.StatusCode -eq 200) {
                $baResult = ($baResp.Content | ConvertFrom-Json)
                $mcaAccounts = @($baResult.value | Where-Object { $_.properties.agreementType -in @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement') })
                $scope = Get-FinOpsBillingScope -BillingAccounts $mcaAccounts -Subscriptions $Subscriptions
                if (-not $scope.Resolved) { Write-Warning "  $($scope.Reason)" }
                foreach ($ba in @($scope.Accounts)) {
                    try {
                        $bpPath = "$($ba.id)/billingProfiles?api-version=2024-04-01"
                        $bpResp = Invoke-AzRestMethodWithRetry -Path $bpPath -Method GET
                        if ($bpResp.StatusCode -eq 200) {
                            $bpResult = ($bpResp.Content | ConvertFrom-Json)
                            foreach ($bp in $bpResult.value) { $billingProfileIds += $bp.id }
                        }
                    } catch {
                        Write-Verbose "Billing profile lookup failed: $($_.Exception.Message)"
                    }
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
                elseif ($resp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            } catch {
                if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
                Write-Warning "  Reservation query at billing profile scope failed: $($_.Exception.Message)"
            }
        }
    }

    # For EA / fallback: query at subscription scope
    if ($reservations.Count -eq 0) {
        # Every selected subscription is queried. Stopping at the first one that
        # answers, or at an arbitrary first N, hides reservations that only the
        # remaining subscriptions can see.
        #
        # Two different duplications have to be collapsed before the summary
        # stats are computed. A reservation is reported by every subscription
        # that consumed it, and reservationSummaries returns one record per
        # usage period. Keying on the reservation alone - and keeping only its
        # newest period - leaves exactly one row per commitment, so RICount
        # counts reservations rather than API records and the average is not
        # weighted towards whichever reservation happens to span more months.
        $latestReservation = @{}
        $subTotal = @($Subscriptions).Count
        $subIdx = 0
        foreach ($sub in $Subscriptions) {
            $subIdx++
            if ($subIdx -eq 1 -or $subIdx -eq $subTotal -or ($subTotal -gt 5 -and $subIdx % [math]::Max(1, [int]($subTotal / 10)) -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Querying reservations ($subIdx/$subTotal subs)..."
                }
            }
            try {
                $summaryPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'"
                $resp = Invoke-AzRestMethodWithRetry -Path $summaryPath -Method GET
                if ($resp.StatusCode -eq 200) {
                    $data = ($resp.Content | ConvertFrom-Json)
                    if ($data.value) {
                        foreach ($item in $data.value) {
                            $p = $item.properties
                            $key = "$($p.reservationOrderId)/$($p.reservationId)"
                            if ([string]::IsNullOrWhiteSpace(($key -replace '/', ''))) { continue }
                            $existing = $latestReservation[$key]
                            if ($existing -and -not (Test-UsageDateIsNewer -Candidate $p.usageDate -Existing $existing.UsageDate)) { continue }
                            $latestReservation[$key] = [PSCustomObject]@{
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
                elseif ($resp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            } catch {
                if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
                Write-Warning "  Reservation summaries query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
        $reservations += @($latestReservation.Values)
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
                                } catch {
                                    # Dropping this reservation silently would understate
                                    # the count and read as better coverage than reality.
                                    [void]$utilFailures.Add("$($ri.id.Split('/')[-1]): $($_.Exception.Message)")
                                }
                            }
                        }
                    }
                }
            }
            elseif ($resp.StatusCode -in @(401, 403)) { $accessDenied = $true }
        } catch {
            if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
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
                                    BenefitId       = $p.benefitId
                                    BenefitOrderId  = $p.benefitOrderId
                                    BenefitType     = $p.benefitType
                                    AvgUtilization  = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                                    UsageDate       = $p.usageDate
                                }
                            }
                        }
                    }
                }
                elseif ($spResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            } catch {
                if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
                Write-Warning "  Savings plan query at billing profile scope failed: $($_.Exception.Message)"
            }
        }
    }

    # Fallback: subscription scope (EA, PAYG, etc.)
    if ($savingsPlans.Count -eq 0) {
        # Same coverage rule as reservations: query every selected subscription
        # and de-duplicate, rather than sampling a few and stopping at the first
        # hit. The try sits inside the loop so one unreadable subscription does
        # not abandon the ones after it.
        #
        # Keyed on benefitId, not benefitOrderId: one order can contain several
        # savings plans, so ordering alone would collapse distinct plans into
        # one and drop real commitments. Only the newest period per plan is
        # kept, so SPCount counts plans rather than monthly records.
        $latestSavingsPlan = @{}
        $spTotal = @($Subscriptions).Count
        $spIdx = 0
        foreach ($sub in $Subscriptions) {
            $spIdx++
            if ($spIdx -eq 1 -or $spIdx -eq $spTotal -or ($spTotal -gt 5 -and $spIdx % [math]::Max(1, [int]($spTotal / 10)) -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Querying savings plans ($spIdx/$spTotal subs)..."
                }
            }
            try {
                $spPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/benefitUtilizationSummaries?api-version=2023-11-01&filter=properties/usageDate ge '$(((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd'))'&grain=Monthly"
                $spResp = Invoke-AzRestMethodWithRetry -Path $spPath -Method GET
                if ($spResp.StatusCode -eq 200) {
                    $spData = ($spResp.Content | ConvertFrom-Json)
                    if ($spData.value) {
                        foreach ($item in $spData.value) {
                            $p = $item.properties
                            if ($p.benefitType -eq 'SavingsPlan') {
                                $key = if ($p.benefitId) { [string]$p.benefitId } else { [string]$p.benefitOrderId }
                                if ([string]::IsNullOrWhiteSpace($key)) { continue }
                                $existing = $latestSavingsPlan[$key]
                                if ($existing -and -not (Test-UsageDateIsNewer -Candidate $p.usageDate -Existing $existing.UsageDate)) { continue }
                                $latestSavingsPlan[$key] = [PSCustomObject]@{
                                    BenefitId       = $p.benefitId
                                    BenefitOrderId  = $p.benefitOrderId
                                    BenefitType     = $p.benefitType
                                    AvgUtilization  = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                                    UsageDate       = $p.usageDate
                                }
                            }
                        }
                    }
                }
                elseif ($spResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            } catch {
                if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
                Write-Warning "  Savings plan utilization query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
        $savingsPlans += @($latestSavingsPlan.Values)
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

    $denied = ($accessDenied -and $riCount -eq 0 -and $spCount -eq 0)

    # Human-readable summary so the zeros below are never mistaken for
    # "no commitments / all healthy" when the real cause is no access.
    $note = if ($denied) {
        'Access denied reading reservation/savings-plan utilization (needs Cost Management Reader / billing-scope access). The zero counts below reflect missing access, NOT confirmed absence of commitments.'
    }
    elseif ($riCount -eq 0 -and $spCount -eq 0) {
        'No reservations or savings plans found in scope.'
    }
    else {
        "$riCount reservation(s) avg $riAvgUtil% util; $spCount savings plan(s) avg $spAvgUtil% util."
    }

    if ($utilFailures.Count -gt 0) {
        Write-Warning "  Utilization unavailable for $($utilFailures.Count) reservation(s); counts below exclude them."
        foreach ($f in ($utilFailures | Select-Object -First 3)) { Write-Verbose "    $f" }
    }

    return [PSCustomObject]@{
        Reservations      = $reservations
        SavingsPlans      = $savingsPlans
        RICount           = $riCount
        SPCount           = $spCount
        RIAvgUtilization  = $riAvgUtil
        SPAvgUtilization  = $spAvgUtil
        UnderutilizedRIs  = $underutilized
        HasData           = ($riCount -gt 0 -or $spCount -gt 0)
        AccessDenied      = $denied
        Note              = $note
        # Reservations excluded because their utilization could not be read.
        UtilizationFailures = $utilFailures.Count
        UtilizationFailureDetail = @($utilFailures)
    }
}
