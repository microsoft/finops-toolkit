# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Commitment utilization de-duplication' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        $script:TwoSubs = @(
            [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000001'; Name = 'Sub one' }
            [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000002'; Name = 'Sub two' }
        )

        # Both APIs are billing-scoped, so the scan first resolves the billing
        # account that owns the scanned subscriptions.
        $script:BillingAccountPayload = @{
            value = @(
                @{ id = '/providers/Microsoft.Billing/billingAccounts/TEST-BA'
                    name = 'TEST-BA'
                    properties = @{ agreementType = 'EnterpriseAgreement' }
                }
            )
        } | ConvertTo-Json -Depth 8

        $script:BillingPropertyPayload = @{
            properties = @{ billingAccountId = '/providers/Microsoft.Billing/billingAccounts/TEST-BA' }
        } | ConvertTo-Json -Depth 8

        # One reservation reported across two usage periods.
        $script:ReservationPayload = @{
            value = @(
                @{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; skuName = 'Standard_D2s_v5'; kind = 'Compute'
                        avgUtilizationPercentage = 50; minUtilizationPercentage = 40; maxUtilizationPercentage = 60
                        reservedHours = 100; usedHours = 50; usageDate = '2026-08-01T00:00:00Z'
                    }
                }
                @{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; skuName = 'Standard_D2s_v5'; kind = 'Compute'
                        avgUtilizationPercentage = 90; minUtilizationPercentage = 80; maxUtilizationPercentage = 95
                        reservedHours = 100; usedHours = 90; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
            )
        } | ConvertTo-Json -Depth 8

        # Two DIFFERENT savings plans that share one benefit order.
        $script:SavingsPlanPayload = @{
            value = @(
                @{ properties = @{ benefitType = 'SavingsPlan'; benefitId = 'plan-a'; benefitOrderId = 'order-1'
                        avgUtilizationPercentage = 70; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
                @{ properties = @{ benefitType = 'SavingsPlan'; benefitId = 'plan-b'; benefitOrderId = 'order-1'
                        avgUtilizationPercentage = 30; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
            )
        } | ConvertTo-Json -Depth 8
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Counts one reservation when it is reported for several months' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match 'billingAccounts\?') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
            elseif ($Path -match 'billingProperty/default') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
            elseif ($Path -match 'reservationSummaries') { [PSCustomObject]@{ StatusCode = 200; Content = $script:ReservationPayload } }
            else { [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' } }
        }

        $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # Two monthly records describe a single commitment.
        $result.RICount | Should -Be 1
        # The newest period wins, so the average is not dragged down by August.
        $result.RIAvgUtilization | Should -Be 90
    }

    It 'Queries billing scope rather than subscription scope' {
        # Subscription-scoped paths answer 404, so a regression back to them
        # would silently report zero commitments.
        $script:SeenPaths = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match 'billingAccounts\?') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
            elseif ($Path -match 'billingProperty/default') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
            elseif ($Path -match 'reservationSummaries') {
                $script:SeenPaths.Add($Path)
                [PSCustomObject]@{ StatusCode = 200; Content = $script:ReservationPayload }
            }
            else { [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' } }
        }

        $null = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        @($script:SeenPaths).Count | Should -BeGreaterThan 0
        foreach ($p in $script:SeenPaths) {
            $p | Should -BeLike '/providers/Microsoft.Billing/billingAccounts/*'
            $p | Should -Not -BeLike '/subscriptions/*'
            # UsageDate is an Edm.DateTimeOffset; a quoted bound fails the compare.
            $p | Should -Not -Match "UsageDate ge '"
        }
    }

    It 'Keeps distinct savings plans that share one benefit order' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match 'billingAccounts\?') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
            elseif ($Path -match 'billingProperty/default') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
            elseif ($Path -match 'benefitUtilizationSummaries') { [PSCustomObject]@{ StatusCode = 200; Content = $script:SavingsPlanPayload } }
            else { [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' } }
        }

        $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # De-duplicating on benefitOrderId alone would collapse these to 1.
        $result.SPCount | Should -Be 2
        $result.SPAvgUtilization | Should -Be 50
    }

    It 'Does not return incomplete utilization after <Endpoint> pagination fails' -ForEach @(
        @{ Endpoint = 'reservationSummaries'; PayloadName = 'ReservationPayload' }
        @{ Endpoint = 'benefitUtilizationSummaries'; PayloadName = 'SavingsPlanPayload' }
    ) {
        $pagedPayload = (Get-Variable -Name $PayloadName -Scope Script -ValueOnly) | ConvertFrom-Json
        $pagedPayload | Add-Member -NotePropertyName nextLink -NotePropertyValue "/providers/Microsoft.Billing/billingAccounts/TEST-BA/$Endpoint`?page=2"
        $firstPageContent = $pagedPayload | ConvertTo-Json -Depth 10
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -like '*page=2') { [PSCustomObject]@{ StatusCode = 503; Content = '{}' } }
            elseif ($Path -match 'billingAccounts\?') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
            elseif ($Path -match 'billingProperty/default') { [PSCustomObject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
            elseif ($Path.Contains($Endpoint)) { [PSCustomObject]@{ StatusCode = 200; Content = $firstPageContent } }
            else { [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' } }
        }

        { Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue } | Should -Throw '*incomplete*'
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
            $Path -like '*page=2' -and $Method -eq 'GET' -and [string]::IsNullOrEmpty($Payload)
        }
    }

    Context 'Commitment metadata and availability' {
        It 'Reads fallback pages without treating partial utilization as complete (page failure: <PageFails>)' -Tag 'CommitmentMetadata' -ForEach @(
            @{ PageFails = $false }
            @{ PageFails = $true }
        ) {
            $failPage = $PageFails
            $reservationPath = '/providers/Microsoft.Capacity/reservationOrders/order-1/reservations/res-1'
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                if ($Path -match 'billingAccounts\?') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
                elseif ($Path -match 'billingProperty/default') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
                elseif ($Path -match '^/providers/Microsoft\.Capacity/reservationOrders\?') {
                    if ($Path -like '*page=2') {
                        [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'order-1'; properties = @{ displayProvisioningState = 'Succeeded'; billingScopeId = '/subscriptions/not-a-kind'; reservations = @(@{ id = $reservationPath }, @{ id = $reservationPath }) } }) } | ConvertTo-Json -Depth 8) }
                    }
                    else { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[],"nextLink":"/providers/Microsoft.Capacity/reservationOrders?api-version=2022-11-01&page=2"}' } }
                }
                elseif ($Path -like "$reservationPath/providers/*") {
                    if ($Path -like '*page=2' -and $failPage) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $older = $Path -like '*page=2'
                    $content = @{ value = @(@{ properties = @{ avgUtilizationPercentage = $(if ($older) { 20 } else { 90 }); usageDate = $(if ($older) { '2026-08-01' } else { '2026-09-01' }) } }) }
                    if (-not $older) { $content.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($content | ConvertTo-Json -Depth 8) }
                }
                elseif ($Path -like "$reservationPath`?*") {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ id = $reservationPath; sku = @{ name = 'Standard_D2s_v5' }; properties = @{ displayName = 'Example reservation'; reservedResourceType = 'VirtualMachines' } } | ConvertTo-Json -Depth 6) }
                }
                else { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
            }

            $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

            $result.CoverageIncomplete | Should -BeTrue
            $result.RIAvgUtilization | Should -BeNullOrEmpty
            if ($PageFails) { $result.RICount | Should -Be 0; $result.UtilizationFailures | Should -Be 1 }
            else {
                $result.RICount | Should -Be 1
                $result.UnscopedFallback | Should -BeTrue
                $result.Reservations[0].AvgUtilization | Should -Be 90
                $result.Reservations[0].SkuName | Should -Be 'Standard_D2s_v5'
                $result.Reservations[0].Kind | Should -Be 'VirtualMachines'
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter { $Path -like '*reservationSummaries*page=2' }
        }

        It 'Retains utilization with <MetadataState> reservation metadata' -Tag 'CommitmentMetadata' -ForEach @(
            @{ MetadataState = 'verified'; StatusCode = 200; Matches = $true }
            @{ MetadataState = 'denied'; StatusCode = 403; Matches = $true }
            @{ MetadataState = 'mismatched'; StatusCode = 200; Matches = $false }
        ) {
            $metadataStatus = $StatusCode
            $matchingMetadata = $Matches
            $reservationPath = '/providers/Microsoft.Capacity/reservationOrders/order-1/reservations/res-1'
            $summary = @{ value = @(@{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; avgUtilizationPercentage = 90; usageDate = '2026-09-01T00:00:00Z' } }) } | ConvertTo-Json -Depth 8
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                if ($Path -match 'billingAccounts\?') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
                elseif ($Path -match 'billingProperty/default') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
                elseif ($Path -match 'reservationSummaries') { [pscustomobject]@{ StatusCode = 200; Content = $summary } }
                elseif ($Path -like "$reservationPath`?*") {
                    [pscustomobject]@{ StatusCode = $metadataStatus; Content = (@{
                        id = $(if ($matchingMetadata) { $reservationPath } else { "$reservationPath-other" }); sku = @{ name = 'Standard_D2s_v5' }
                        properties = @{ displayName = 'Example <reservation>'; reservedResourceType = 'VirtualMachines' }
                    } | ConvertTo-Json -Depth 6) }
                }
                else { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
            }

            $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

            $result.RICount | Should -Be 1
            $result.RIAvgUtilization | Should -Be 90
            $result.SPAvgUtilization | Should -BeNullOrEmpty
            $result.Reservations[0].ResourceId | Should -Be $reservationPath
            $result.Reservations[0].MinUtilization | Should -BeNullOrEmpty
            if ($MetadataState -eq 'verified') {
                $result.Reservations[0].Name | Should -Be 'Example <reservation>'
                $result.Reservations[0].SkuName | Should -Be 'Standard_D2s_v5'
                $result.Reservations[0].Kind | Should -Be 'VirtualMachines'
                $result.MetadataErrors | Should -BeNullOrEmpty
            }
            else {
                $result.Reservations[0].Name | Should -Be 'res-1'
                $result.Reservations[0].SkuName | Should -BeNullOrEmpty
                $result.Reservations[0].Kind | Should -BeNullOrEmpty
                @($result.MetadataErrors).Count | Should -Be 1
            }
        }

        It 'Does not invent utilization for <Scenario>' -Tag 'CommitmentMetadata' -ForEach @(
            @{ Scenario = 'no commitments'; ReturnReservation = $false; Utilization = $null }
            @{ Scenario = 'missing utilization'; ReturnReservation = $true; Utilization = $null }
            @{ Scenario = 'measured zero'; ReturnReservation = $true; Utilization = 0 }
        ) {
            $includeReservation = $ReturnReservation
            $utilizationValue = $Utilization
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                if ($Path -match 'billingAccounts\?') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingAccountPayload } }
                elseif ($Path -match 'billingProperty/default') { [pscustomobject]@{ StatusCode = 200; Content = $script:BillingPropertyPayload } }
                elseif ($Path -match 'reservationSummaries' -and $includeReservation) {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; skuName = 'Standard_D2s_v5'; kind = 'Compute'; avgUtilizationPercentage = $utilizationValue; usageDate = '2026-09-01' } }) } | ConvertTo-Json -Depth 8) }
                }
                else { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
            }

            $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

            $result.SPAvgUtilization | Should -BeNullOrEmpty
            if ($null -eq $Utilization) {
                $result.RIAvgUtilization | Should -BeNullOrEmpty
                $result.UnderutilizedRIs | Should -BeNullOrEmpty
                if ($ReturnReservation) { $result.CoverageIncomplete | Should -BeTrue; $result.Reservations[0].AvgUtilization | Should -BeNullOrEmpty }
            }
            else { $result.RIAvgUtilization | Should -Be 0; $result.UnderutilizedRIs.Count | Should -Be 1 }
        }
    }

    Context 'Usage date comparison' {

        It 'Treats a newer ISO date as newer' {
            Test-UsageDateIsNewer -Candidate '2026-09-01T00:00:00Z' -Existing '2026-08-01T00:00:00Z' | Should -BeTrue
        }

        It 'Treats an older ISO date as not newer' {
            Test-UsageDateIsNewer -Candidate '2026-07-01T00:00:00Z' -Existing '2026-08-01T00:00:00Z' | Should -BeFalse
        }

        It 'Accepts any candidate when nothing was recorded yet' {
            Test-UsageDateIsNewer -Candidate '2026-07-01T00:00:00Z' -Existing $null | Should -BeTrue
        }

        It 'Keeps the recorded row when the candidate has no date' {
            Test-UsageDateIsNewer -Candidate $null -Existing '2026-08-01T00:00:00Z' | Should -BeFalse
        }
    }
}
