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
    $metadataErrors = [System.Collections.Generic.List[string]]::new()
    $savingsPlans = @()

    function ConvertTo-CommitmentPercentage {
        param($Value)
        $percentage = 0.0
        if ($null -eq $Value -or -not [double]::TryParse([Convert]::ToString($Value, [cultureinfo]::InvariantCulture), [Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref]$percentage) -or
            [double]::IsNaN($percentage) -or [double]::IsInfinity($percentage) -or $percentage -lt 0 -or $percentage -gt 100) { return $null }
        [math]::Round($percentage, 1)
    }

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
            $allAccounts = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $baResp -Context 'commitment billing accounts' -RootNextLink)) { ($page.Content | ConvertFrom-Json).value })
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
                            foreach ($page in (Get-CostQueryResponsePage -FirstResponse $bpResp -Context 'commitment billing profiles' -RootNextLink)) {
                                foreach ($bp in @(($page.Content | ConvertFrom-Json).value)) { $commitmentScopes += $bp.id }
                            }
                        }
                        elseif ($bpResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
                        else { $utilFailures.Add("Billing profiles for $($ba.name): HTTP $($bpResp.StatusCode)") }
                    }
                    catch {
                        $utilFailures.Add("Billing profiles for $($ba.name): $($_.Exception.Message)")
                        Write-Warning "  Billing profile lookup failed for $($ba.name): $($_.Exception.Message)"
                    }
                }
                else {
                    $commitmentScopes += $ba.id
                }
            }
        }
        elseif ($baResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
        else { $utilFailures.Add("Billing accounts: HTTP $($baResp.StatusCode)") }
    }
    catch {
        $utilFailures.Add("Billing scope resolution: $($_.Exception.Message)")
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
                            AvgUtilization     = ConvertTo-CommitmentPercentage $p.avgUtilizationPercentage
                            MinUtilization     = ConvertTo-CommitmentPercentage $p.minUtilizationPercentage
                            MaxUtilization     = ConvertTo-CommitmentPercentage $p.maxUtilizationPercentage
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
        }
        catch {
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
                $orders = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -Context 'reservation orders' -RootNextLink)) { ($page.Content | ConvertFrom-Json).value })
                $seenReservations = @{}
                if ($orders) {
                    foreach ($order in $orders) {
                        $op = $order.properties
                        if ($op.reservations) {
                            foreach ($ri in $op.reservations) {
                                if ($ri.id -notmatch '^/providers/Microsoft\.Capacity/reservationOrders/[a-zA-Z0-9-]+/reservations/[a-zA-Z0-9-]+$') {
                                    $utilFailures.Add('A reservation order returned an invalid reservation resource ID.')
                                    continue
                                }
                                if ($seenReservations.ContainsKey($ri.id)) { continue }
                                $seenReservations[$ri.id] = $true
                                # Get utilization summary for each reservation
                                try {
                                    $utilPath = "$($ri.id)/providers/Microsoft.Consumption/reservationSummaries?grain=monthly&api-version=2023-05-01&`$filter=properties/UsageDate ge $usageFrom and properties/UsageDate le $usageTo"
                                    $utilResp = Invoke-AzRestMethodWithRetry -Path $utilPath -Method GET
                                    if ($utilResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
                                    $usageRows = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $utilResp -Context 'reservation fallback utilization' -RootNextLink)) { ($page.Content | ConvertFrom-Json).value })
                                    if ($utilResp.StatusCode -eq 200) {
                                        if ($usageRows.Count -gt 0) {
                                            $latest = $null
                                            foreach ($usageRow in $usageRows) {
                                                if (-not $latest -or (Test-UsageDateIsNewer -Candidate $usageRow.properties.usageDate -Existing $latest.properties.usageDate)) { $latest = $usageRow }
                                            }
                                            $up = $latest.properties
                                            $reservations += [PSCustomObject]@{
                                                ReservationOrderId = $order.name
                                                ReservationId      = $ri.id.Split('/')[-1]
                                                SkuName            = $up.skuName
                                                Kind               = $up.kind
                                                AvgUtilization     = ConvertTo-CommitmentPercentage $up.avgUtilizationPercentage
                                                MinUtilization     = ConvertTo-CommitmentPercentage $up.minUtilizationPercentage
                                                MaxUtilization     = ConvertTo-CommitmentPercentage $up.maxUtilizationPercentage
                                                ReservedHours      = $up.reservedHours
                                                UsedHours          = $up.usedHours
                                                UsageDate          = $up.usageDate
                                            }
                                        }
                                    }
                                }
                                catch {
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
            else { $utilFailures.Add("Reservation orders: HTTP $($resp.StatusCode)") }
        }
        catch {
            $utilFailures.Add("Reservation orders: $($_.Exception.Message)")
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
                            AvgUtilization = ConvertTo-CommitmentPercentage $p.avgUtilizationPercentage
                            UsageDate      = $p.usageDate
                        }
                    }
                }
            }
            elseif ($spResp.StatusCode -in @(401, 403)) { $accessDenied = $true }
            else {
                [void]$utilFailures.Add("$scopeId : HTTP $($spResp.StatusCode)")
            }
        }
        catch {
            if ("$($_.Exception.Message)" -match '403|Forbidden|Authorization|AuthorizationFailed|access') { $accessDenied = $true }
            throw "Savings plan utilization query failed for $scopeId : $($_.Exception.Message)"
        }
    }
    $savingsPlans += @($latestSavingsPlan.Values)

    $metadataById = @{}
    foreach ($reservation in $reservations) {
        $orderId = ([string]$reservation.ReservationOrderId).TrimEnd('/').Split('/')[-1]
        $reservationId = ([string]$reservation.ReservationId).TrimEnd('/').Split('/')[-1]
        $resourceId = "/providers/Microsoft.Capacity/reservationOrders/$orderId/reservations/$reservationId"
        $reservation | Add-Member -NotePropertyName ResourceId -NotePropertyValue $resourceId
        $reservation | Add-Member -NotePropertyName Name -NotePropertyValue $reservationId
        if ($orderId -notmatch '^[a-zA-Z0-9-]+$' -or $reservationId -notmatch '^[a-zA-Z0-9-]+$') {
            $metadataErrors.Add('Reservation metadata was not requested because an identifier was invalid.')
            continue
        }
        if (-not $reservation.SkuName -or -not $reservation.Kind) {
            if (-not $metadataById.ContainsKey($resourceId)) {
                $metadataById[$resourceId] = $null
                try {
                    $metadataResponse = Invoke-AzRestMethodWithRetry -Path "$resourceId`?api-version=2022-11-01" -Method GET
                    if ($metadataResponse.StatusCode -ne 200) { throw "HTTP $($metadataResponse.StatusCode)" }
                    $metadata = $metadataResponse.Content | ConvertFrom-Json -ErrorAction Stop
                    if ($metadata.id -ine $resourceId -or -not $metadata.properties) { throw 'Reservation metadata did not match the requested resource.' }
                    $metadataById[$resourceId] = $metadata
                }
                catch { $metadataErrors.Add("$resourceId : $($_.Exception.Message)") }
            }
            $metadata = $metadataById[$resourceId]
            if ($metadata) {
                if ($metadata.properties.displayName) { $reservation.Name = [string]$metadata.properties.displayName }
                if (-not $reservation.SkuName -and $metadata.sku.name) { $reservation.SkuName = [string]$metadata.sku.name }
                if (-not $reservation.Kind -and $metadata.properties.reservedResourceType) { $reservation.Kind = [string]$metadata.properties.reservedResourceType }
            }
        }
    }
    foreach ($commitment in @($reservations) + @($savingsPlans)) {
        if ($null -eq $commitment.AvgUtilization) {
            $identity = if ($commitment.ReservationId) { $commitment.ReservationId } else { $commitment.BenefitId }
            $utilFailures.Add("$identity : Average utilization is missing or invalid.")
        }
    }
    $coverageIncomplete = $accessDenied -or $utilFailures.Count -gt 0 -or @($commitmentScopes).Count -eq 0 -or $unscopedFallback

    # -- Step 4: Calculate summary stats --
    $riAvgUtil = $null
    $riCount = $reservations.Count
    if ($riCount -gt 0 -and -not $coverageIncomplete) {
        $riAvgUtil = [math]::Round(($reservations | Measure-Object -Property AvgUtilization -Average).Average, 1)
    }

    $spAvgUtil = $null
    $spCount = $savingsPlans.Count
    if ($spCount -gt 0 -and -not $coverageIncomplete) {
        $spAvgUtil = [math]::Round(($savingsPlans | Measure-Object -Property AvgUtilization -Average).Average, 1)
    }

    $underutilized = @($reservations | Where-Object { $null -ne $_.AvgUtilization -and $_.AvgUtilization -lt 80 })

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
    elseif ($coverageIncomplete) {
        'Commitment coverage is incomplete. Missing results do not establish the absence of reservations or savings plans.'
    }
    elseif ($riCount -eq 0 -and $spCount -eq 0) {
        'No reservations or savings plans found in scope.'
    }
    else {
        $riLabel = if ($null -ne $riAvgUtil) { "$riAvgUtil%" } else { 'unavailable' }
        $spLabel = if ($null -ne $spAvgUtil) { "$spAvgUtil%" } else { 'unavailable' }
        "$riCount reservation(s), average utilization $riLabel; $spCount savings plan(s), average utilization $spLabel. Averages are unweighted and use the latest returned period per commitment."
    }
    if ($coverageIncomplete) { $note = "$note Coverage is incomplete; overall utilization averages are unavailable." }

    if ($utilFailures.Count -gt 0) {
        Write-Warning "  Utilization unavailable for $($utilFailures.Count) reservation(s); counts below exclude them."
        foreach ($f in ($utilFailures | Select-Object -First 3)) { Write-Verbose "    $f" }
    }

    return [PSCustomObject]@{
        Reservations             = $reservations
        SavingsPlans             = $savingsPlans
        RICount                  = $riCount
        SPCount                  = $spCount
        RIAvgUtilization         = $riAvgUtil
        SPAvgUtilization         = $spAvgUtil
        CoverageIncomplete       = $coverageIncomplete
        MetadataErrors           = $metadataErrors.ToArray()
        AverageBasis             = 'Unweighted mean of the latest returned period per commitment'
        UnderutilizedRIs         = $underutilized
        HasData                  = ($riCount -gt 0 -or $spCount -gt 0)
        AccessDenied             = $denied
        ScopesQueried            = @($commitmentScopes).Count
        # True when the figures came from the tenant-wide reservation order
        # endpoint, which cannot be filtered to the scanned subscriptions.
        UnscopedFallback         = $unscopedFallback
        Note                     = if ($unscopedFallback) {
            'No commitments were readable at the resolved billing scopes, so these figures come from every reservation order this account can see and are not limited to the scanned subscriptions.'
        }
        else { $note }
        # Reservations excluded because their utilization could not be read.
        UtilizationFailures      = $utilFailures.Count
        UtilizationFailureDetail = @($utilFailures)
    }
}
