# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
param()

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

    # Set to $true if a reservation/savings-plan query is forbidden (401/403)
    # rather than simply returning no commitments.
    $accessDenied = $false

    # Why billing-scope correlation produced nothing, when it produced nothing.
    $scopeResolutionReason = $null

    # -- Step 0: Resolve the billing scopes that own the scanned subscriptions --
    # Both commitment APIs are billing-scoped. A subscription-scoped path answers
    # 404 "Unknown. Please check the request path", which is not an access denial,
    # so the previous per-subscription queries could only ever report zero.
    # EA reads at billing account scope, MCA/MPA at billing profile scope.
    $commitmentScopes = @()
    try {
        $baPath = "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01"
        $baResp = Invoke-AzRestMethodWithRetry -Path $baPath -Method GET
        if ($baResp.StatusCode -eq 200) {
            $allAccounts = @(($baResp.Content | ConvertFrom-Json).value)
            $scope = Get-FinOpsBillingScope -BillingAccounts $allAccounts -Subscriptions $Subscriptions
            if (-not $scope.Resolved) {
                $scopeResolutionReason = $scope.Reason
                Write-Warning "  $($scope.Reason)"
            }

            foreach ($ba in @($scope.Accounts)) {
                # Fall back to the caller's agreement type when the account
                # listing does not carry one.
                $agreement = if ($ba.properties.agreementType) { $ba.properties.agreementType } else { $AgreementType }
                if ($agreement -in @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement')) {
                    try {
                        $bpResp = Invoke-AzRestMethodWithRetry -Path "$($ba.id)/billingProfiles?api-version=2024-04-01" -Method GET
                        if ($bpResp.StatusCode -eq 200) {
                            foreach ($bp in @(($bpResp.Content | ConvertFrom-Json).value)) { $commitmentScopes += $bp.id }
                        }
                        elseif ($bpResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
                    } catch {
                        Write-Warning "  Billing profile lookup failed for $($ba.name): $($_.Exception.Message)"
                    }
                }
                else {
                    $commitmentScopes += $ba.id
                }
            }
        }
        elseif ($baResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
    } catch {
        Write-Warning "  Billing scope resolution failed: $($_.Exception.Message)"
    }
    Write-Host "  Found $($commitmentScopes.Count) billing scope(s) for commitment queries." -ForegroundColor Cyan

    # -- Step 1: Get all reservations and their utilization --------------
    # One row per reservation, not per usage period. The API returns a record
    # per month, so counting records would inflate RICount and weight the
    # average towards whichever reservation happens to span more months.
    $latestReservation = @{}
    $usageFrom = ((Get-Date).AddDays(-30)).ToString('yyyy-MM-dd')
    $usageTo = (Get-Date).ToString('yyyy-MM-dd')
    $scopeTotal = @($commitmentScopes).Count
    $scopeIdx = 0
    foreach ($scopeId in $commitmentScopes) {
        $scopeIdx++
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus "Querying reservations ($scopeIdx/$scopeTotal scopes)..."
        }
        try {
            # UsageDate needs both bounds and must not be quoted: it is an
            # Edm.DateTimeOffset, so a quoted value fails the type comparison.
            $summaryPath = "$scopeId/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/UsageDate ge $usageFrom and properties/UsageDate le $usageTo"
            $resp = Invoke-AzRestMethodWithRetry -Path $summaryPath -Method GET

            if ($resp.StatusCode -eq 200) {
                foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -Context 'reservation utilization' -RootNextLink)) {
                    foreach ($item in @(($page.Content | ConvertFrom-Json).value)) {
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
            else {
                # A non-200 that is not a denial still means this scope produced
                # nothing, which must not be presented as "no reservations".
                [void]$utilFailures.Add("$scopeId : HTTP $($resp.StatusCode)")
            }
        } catch {
            if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
            throw "Reservation summaries query failed for $scopeId : $($_.Exception.Message)"
        }
    }
    $reservations += @($latestReservation.Values)

    # -- Step 2: Try the Reservation Orders API at billing scope --
    # This endpoint is tenant-wide and cannot be filtered to the requested
    # subscriptions, so anything it returns is flagged as unscoped rather than
    # presented as belonging to the scan scope.
    $unscopedFallback = $false
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
                                    $utilPath = "$($ri.id)/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/UsageDate ge $usageFrom and properties/UsageDate le $usageTo"
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
        # This block only runs when the scoped queries returned nothing, so
        # anything present now came from the tenant-wide endpoint.
        if ($reservations.Count -gt 0) {
            $unscopedFallback = $true
            Write-Warning "  Commitments were read from every reservation order this account can see; they are not limited to the scanned subscriptions."
        }
    }

    # -- Step 3: Savings Plans utilization via Benefit Utilization Summaries --
    # Keyed on benefitId, not benefitOrderId: one order can hold several savings
    # plans, so ordering alone would collapse distinct plans into one and drop
    # real commitments. Only the newest period per plan is kept, so SPCount
    # counts plans rather than monthly records.
    $latestSavingsPlan = @{}
    $spIdx = 0
    foreach ($scopeId in $commitmentScopes) {
        $spIdx++
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus "Querying savings plans ($spIdx/$scopeTotal scopes)..."
        }
        try {
            $spPath = "$scopeId/providers/Microsoft.CostManagement/benefitUtilizationSummaries?api-version=2023-11-01&grainParameter=Monthly"
            $spResp = Invoke-AzRestMethodWithRetry -Path $spPath -Method GET

            if ($spResp.StatusCode -eq 200) {
                foreach ($page in (Get-CostQueryResponsePage -FirstResponse $spResp -Context 'savings plan utilization' -RootNextLink)) {
                    foreach ($item in @(($page.Content | ConvertFrom-Json).value)) {
                        $p = $item.properties
                        if ($p.benefitType -ne 'SavingsPlan') { continue }
                        $key = if ($p.benefitId) { [string]$p.benefitId } else { [string]$p.benefitOrderId }
                        if ([string]::IsNullOrWhiteSpace($key)) { continue }
                        $existing = $latestSavingsPlan[$key]
                        if ($existing -and -not (Test-UsageDateIsNewer -Candidate $p.usageDate -Existing $existing.UsageDate)) { continue }
                        $latestSavingsPlan[$key] = [PSCustomObject]@{
                            BenefitId      = $p.benefitId
                            BenefitOrderId = $p.benefitOrderId
                            BenefitType    = $p.benefitType
                            AvgUtilization = [math]::Round([double]$p.avgUtilizationPercentage, 1)
                            UsageDate      = $p.usageDate
                        }
                    }
                }
            }
            elseif ($spResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            else {
                [void]$utilFailures.Add("$scopeId : HTTP $($spResp.StatusCode)")
            }
        } catch {
            if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
            throw "Savings plan utilization query failed for $scopeId : $($_.Exception.Message)"
        }
    }
    $savingsPlans += @($latestSavingsPlan.Values)

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
    $note = if (@($commitmentScopes).Count -eq 0) {
        # Distinct from an access denial: the account list was readable, it just
        # does not contain an account that owns a scanned subscription.
        $detail = if ($scopeResolutionReason) { " $scopeResolutionReason" } else { '' }
        "Reservations and savings plans are billing-scoped, and no billing scope was resolved for the scanned subscriptions, so utilization could not be read.$detail"
    }
    elseif ($denied) {
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
        ScopesQueried     = @($commitmentScopes).Count
        # True when the figures came from the tenant-wide reservation order
        # endpoint, which cannot be filtered to the scanned subscriptions.
        UnscopedFallback  = $unscopedFallback
        Note              = if ($unscopedFallback) {
            'No commitments were readable at the resolved billing scopes, so these figures come from every reservation order this account can see and are not limited to the scanned subscriptions.'
        }
        else { $note }
        # Reservations excluded because their utilization could not be read.
        UtilizationFailures = $utilFailures.Count
        UtilizationFailureDetail = @($utilFailures)
    }
}
