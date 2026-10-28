# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Multitool result scope, currency, and coverage' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1') -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Mock Write-Host -ModuleName FinOpsMultitool { }
        Mock Write-Progress -ModuleName FinOpsMultitool { }
        Mock Get-AzContext -ModuleName FinOpsMultitool { throw 'Result fixtures must not read an Azure context.' }
        Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Result fixtures must not send HTTP requests.' }
        Mock Invoke-WebRequest -ModuleName FinOpsMultitool { throw 'Result fixtures must not send HTTP requests.' }
        InModuleScope FinOpsMultitool { Reset-CostMgScope }
    }

    Context 'Selected subscription scope' {
        It 'Limits management-group savings to the selected subscriptions' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'fixture-group' }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'resourcecontainers') {
                        return @{ Data = @(
                                [pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; ancestors = @(@{ name = 'fixture-group' }) }
                                [pscustomobject]@{ subscriptionId = '22222222-2222-2222-2222-222222222222'; ancestors = @(@{ name = 'fixture-group' }) }
                            ) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $properties = if ($request.type -eq 'ActualCost') {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'SubscriptionId' }, @{ name = 'ChargeType' }, @{ name = 'Currency' }); rows = @() }
                    }
                    else {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'SubscriptionId' }, @{ name = 'PricingModel' }, @{ name = 'Currency' }); rows = @(
                                @(100.0, '11111111-1111-1111-1111-111111111111', 'Reservation', 'USD'),
                                @(0.0, '22222222-2222-2222-2222-222222222222', 'Reservation', 'USD'),
                                @(900.0, '33333333-3333-3333-3333-333333333333', 'Reservation', 'USD')
                            ) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Selected B' }
                )

                $result = Get-SavingsRealized -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

                $result.RISavingsMonthToDate | Should -Be 66.67
                @($result.Details | Where-Object Subscription -EQ '33333333-3333-3333-3333-333333333333').Count | Should -Be 0
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $Path -like '/providers/Microsoft.Management/*' -and $request.type -eq 'ActualCost' -and $request.dataset.filter.dimensions.name -eq 'SubscriptionId' -and
                    $request.dataset.filter.dimensions.operator -eq 'In' -and
                    (@($request.dataset.filter.dimensions.values | Sort-Object) -join ',') -eq '11111111-1111-1111-1111-111111111111,22222222-2222-2222-2222-222222222222'
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $clauses = @($request.dataset.filter.and)
                    $Path -like '/providers/Microsoft.Management/*' -and $request.type -eq 'AmortizedCost' -and -not $request.dataset.filter.or -and $clauses.Count -eq 2 -and
                    @($clauses | Where-Object { $_.dimensions.name -eq 'ChargeType' -and $_.dimensions.operator -eq 'In' -and (@($_.dimensions.values) -join ',') -eq 'Usage' }).Count -eq 1 -and
                    @($clauses | Where-Object {
                            $_.dimensions.name -eq 'SubscriptionId' -and $_.dimensions.operator -eq 'In' -and
                            (@($_.dimensions.values | Sort-Object) -join ',') -eq '11111111-1111-1111-1111-111111111111,22222222-2222-2222-2222-222222222222'
                        }).Count -eq 1
                }
            }
        }

        It 'Queries savings per subscription when the management group misses a selected subscription' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'fixture-group' }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'resourcecontainers') {
                        return @{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; ancestors = @(@{ name = 'fixture-group' }) }) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $amount = if ($Path -like '/subscriptions/11111111-*') { 100.0 } else { 900.0 }
                    $properties = if ($request.type -eq 'ActualCost') {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'ChargeType' }, @{ name = 'Currency' }); rows = @() }
                    }
                    else {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'PricingModel' }, @{ name = 'Currency' }); rows = @(, @($amount, 'Reservation', 'USD')) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Selected B' }
                )

                $result = Get-SavingsRealized -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

                $result.RISavingsMonthToDate | Should -Be 666.67
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '/providers/Microsoft.Management/*' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 4 -Exactly -ParameterFilter { $Path -like '/subscriptions/*' }
            }
        }

        It 'Computes unit costs from every selected subscription when the management group is partial' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'child-group' }
                Mock Get-VmSizeCapability { [pscustomobject]@{ VCpu = 1; MemGb = 4 } }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'resourcecontainers') {
                        return @{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; ancestors = @(@{ name = 'child-group' }) }) }
                    }
                    if ($Query -match 'virtualmachines') {
                        return @{ Data = @([pscustomobject]@{ cnt = 2; vmSize = 'FixtureSize'; loc = 'eastus'; subId = '11111111-1111-1111-1111-111111111111' }) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $amount = if ($Path -like '/subscriptions/11111111-*') { 100.0 } else { 900.0 }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'MeterCategory' }, @{ name = 'Currency' }); rows = @(, @($amount, 'Virtual Machines', 'USD')) } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'B' }
                )

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $result.CostScope | Should -Be 'per-sub'
                $result.ComputeCost | Should -Be 1000
                $result.CostPerVCpu | Should -Be 500
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '/providers/Microsoft.Management/*' }
            }
        }

        It 'Keeps unattributed hub charges with their own subscription' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '/subscriptions/11111111-1111-1111-1111-111111111111'; SubAccountName = 'A'; ResourceId = ''; ResourceType = 'unattributed'; x_ResourceGroupName = ''; BilledCost = 100; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01'; ChargePeriodEnd = '2026-09-02' }
                    [pscustomobject]@{ SubAccountId = '/subscriptions/22222222-2222-2222-2222-222222222222'; SubAccountName = 'B'; ResourceId = ''; ResourceType = 'unattributed'; x_ResourceGroupName = ''; BilledCost = 900; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01'; ChargePeriodEnd = '2026-09-02' }
                )

                $result = @(ConvertTo-ResourceCostsFromHub -HubData $rows)

                $result.Count | Should -Be 2
                ($result | Where-Object Subscription -EQ 'A').Actual | Should -Be 100
                ($result | Where-Object Subscription -EQ 'B').Actual | Should -Be 900
            }
        }

        It 'Confirms billing account ownership for <Scenario>' -ForEach @(
            @{ Scenario = 'an unrelated single account'; Owner = '99999999-9999-9999-9999-999999999999'; BillingOwner = 'another-account'; Confirmed = $false }
            @{ Scenario = 'the account that owns the subscription'; Owner = '11111111-1111-1111-1111-111111111111'; BillingOwner = 'single-account'; Confirmed = $true }
            @{ Scenario = 'unreadable membership'; Owner = $null; BillingOwner = $null; Confirmed = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Owner = $Owner; BillingOwner = $BillingOwner; Confirmed = $Confirmed } {
                param($Owner, $BillingOwner, $Confirmed)
                $fixtureOwner = $Owner
                $fixtureBillingOwner = $BillingOwner
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*billingProperty/default*') {
                        if (-not $fixtureBillingOwner) { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ billingAccountId = "/providers/Microsoft.Billing/billingAccounts/$fixtureBillingOwner" } } | ConvertTo-Json) }
                    }
                    if ($Path -like '*/billingSubscriptions*' -and -not $fixtureOwner) { return [pscustomobject]@{ StatusCode = 403; Content = '{"error":{"code":"AuthorizationFailed"}}' } }
                    $response = if ($Path -like '*/billingSubscriptions*') {
                        @{ value = @(@{ name = $fixtureOwner; properties = @{ subscriptionId = $fixtureOwner } }) }
                    }
                    elseif ($Path -like '/subscriptions/*') {
                        # Documented Subscriptions - Get shape: subscriptionPolicies is top level.
                        @{ subscriptionId = '11111111-1111-1111-1111-111111111111'; subscriptionPolicies = @{ quotaId = 'EnterpriseAgreement_2014-09-01' } }
                    }
                    else {
                        @{ value = @(@{ name = 'single-account'; properties = @{ displayName = 'Single account'; agreementType = 'EnterpriseAgreement'; accountStatus = 'Active' } }) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = ($response | ConvertTo-Json -Depth 8) }
                }

                $result = @(Get-ContractInfo -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected subscription' }) -WarningAction SilentlyContinue)

                $result[0].AgreementType | Should -Be 'EnterpriseAgreement'
                $result[0].CoverageIncomplete | Should -Be (-not $Confirmed)
                if ($Confirmed) { $result[0].AccountId | Should -Be 'single-account' }
                else {
                    $result[0].AccountId | Should -Not -Be 'single-account'
                    $result[0].Note | Should -Match 'not confirmed'
                }
                $membershipReads = if ($Confirmed) { 0 } else { 1 }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $membershipReads -Exactly -ParameterFilter { $Path -like '*/billingSubscriptions*' }
            }
        }

        It 'Uses the confirmed <Agreement> owner without paging unrelated accounts' -ForEach @(
            @{ Agreement = 'EnterpriseAgreement' }
            @{ Agreement = 'MicrosoftCustomerAgreement' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Agreement = $Agreement } {
                param($Agreement)
                $ownerAgreement = $Agreement
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*billingProperty/default*') {
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"billingAccountId":"/providers/Microsoft.Billing/billingAccounts/selected-owner"}}' }
                    }
                    if ($Path -like '/subscriptions/*') {
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"subscriptionPolicies":{"quotaId":"EnterpriseAgreement"}}' }
                    }
                    if ($Path -like '*/billingSubscriptions*') { throw 'Unrelated billing membership must not be enumerated.' }
                    $accounts = @(
                        @{ name = 'unrelated-one'; properties = @{ agreementType = 'EnterpriseAgreement' } }
                        @{ name = 'unrelated-two'; properties = @{ agreementType = 'EnterpriseAgreement' } }
                        @{ name = 'selected-owner'; properties = @{ displayName = 'Selected owner'; agreementType = $ownerAgreement; accountStatus = 'Active' } }
                    )
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $accounts } | ConvertTo-Json -Depth 6) }
                }

                $result = @(Get-ContractInfo -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected subscription' }))

                $result[0].AccountId | Should -Be 'selected-owner'
                $result[0].AgreementType | Should -Be $Agreement
                $result[0].CoverageIncomplete | Should -BeFalse
                $result[0].ReadErrors | Should -BeNullOrEmpty
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '*billingProperty/default*' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '*/billingSubscriptions*' }
            }
        }

        It 'Does not confirm billing ownership when <Scenario>' -ForEach @(
            @{ Scenario = 'subscription discovery returns no rows'; DiscoveryFails = $false; Selected = @() }
            @{ Scenario = 'subscription discovery fails'; DiscoveryFails = $true; Selected = @() }
            @{ Scenario = 'a selected subscription has no ID'; DiscoveryFails = $false; Selected = @([pscustomobject]@{ Name = 'Missing ID' }) }
            @{ Scenario = 'a selected subscription has a blank ID'; DiscoveryFails = $false; Selected = @([pscustomobject]@{ Id = ' '; Name = 'Blank ID' }) }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ DiscoveryFails = $DiscoveryFails; Selected = $Selected } {
                param($DiscoveryFails, $Selected)
                Mock Get-AzSubscription {
                    if ($DiscoveryFails) { throw 'Subscription discovery denied.' }
                    @()
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '/providers/Microsoft.Billing/billingAccounts*') {
                        $account = @{ name = 'unrelated-account'; properties = @{ displayName = 'Unrelated account'; agreementType = 'EnterpriseAgreement'; accountStatus = 'Active' } }
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($account) } | ConvertTo-Json -Depth 6) }
                    }
                    [pscustomobject]@{ StatusCode = 403; Content = '{}' }
                }

                $result = @(Get-ContractInfo -Subscriptions @($Selected) -WarningAction SilentlyContinue)

                $result.Count | Should -Be 1
                $result[0].AgreementType | Should -Be 'Unknown'
                $result[0].PSObject.Properties['AccountId'] | Should -BeNullOrEmpty
                $result[0].CoverageIncomplete | Should -BeTrue
                ($result[0].ReadErrors -join ' ') | Should -Match 'No subscription ID'
                if ($DiscoveryFails) { ($result[0].ReadErrors -join ' ') | Should -Match 'Subscription discovery denied' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '/providers/Microsoft.Billing/billingAccounts*' -or $Path -like '*billingProperty/default*' }
            }
        }

        It 'Queries resource costs per subscription when the management group misses a selected subscription' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'child-group' }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'resourcecontainers') {
                        return @{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; ancestors = @(@{ name = 'child-group' }) }) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $subscription = if ($Path -like '/subscriptions/11111111-*') { '11111111-1111-1111-1111-111111111111' } else { '22222222-2222-2222-2222-222222222222' }
                    $properties = if ($Path -match '/forecast\?') {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @(100.0, 'USD')) }
                    }
                    else {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = @(, @(100.0, "/subscriptions/$subscription/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk", 'fixture', 'USD')) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'B' }
                )

                $result = @(Get-ResourceCosts -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -RestrictToSelected)

                @($result.SubscriptionId | Sort-Object) | Should -Be @('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '/providers/Microsoft.Management/*' }
            }
        }
    }

    Context 'Currencies and forecasts' {
        It 'Keeps resource forecasts consistent for <Scenario>' -ForEach @(
            @{ Scenario = 'a forecast in another currency'; ActualAmount = 100; ActualCurrency = 'EUR'; ForecastCurrency = 'USD'; ForecastAmount = 200; ExpectedForecast = $null; ExpectedSource = 'Unavailable'; CostData = $null; ForecastCalls = 1 }
            @{ Scenario = 'a flat forecast'; ActualAmount = 100; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 100; ExpectedForecast = 100; ExpectedSource = 'Forecast'; CostData = $null; ForecastCalls = 1 }
            @{ Scenario = 'a forecast for spend not yet incurred'; ActualAmount = 0; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 100; ExpectedForecast = $null; ExpectedSource = 'Unavailable'; CostData = $null; ForecastCalls = 1 }
            @{ Scenario = 'a zero forecast without spend'; ActualAmount = 0; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 0; ExpectedForecast = 0; ExpectedSource = 'Linear projection'; CostData = $null; ForecastCalls = 1 }
            @{ Scenario = 'cost data in another currency'; ActualAmount = 100; ActualCurrency = 'EUR'; ForecastCurrency = 'USD'; ForecastAmount = 200; ExpectedForecast = $null; ExpectedSource = 'Unavailable'; CostData = @{ Actual = 100; Forecast = 150; ForecastSource = 'Forecast'; Currency = 'USD' }; ForecastCalls = 0 }
            @{ Scenario = 'cost data in the same currency'; ActualAmount = 100; ActualCurrency = 'EUR'; ForecastCurrency = 'EUR'; ForecastAmount = 200; ExpectedForecast = 150; ExpectedSource = 'Forecast'; CostData = @{ Actual = 100; Forecast = 150; ForecastSource = 'Forecast'; Currency = ' eur ' }; ForecastCalls = 0 }
            @{ Scenario = 'cost data without currencies'; ActualAmount = 100; ActualCurrency = ''; ForecastCurrency = 'USD'; ForecastAmount = 200; ExpectedForecast = $null; ExpectedSource = 'Unavailable'; CostData = @{ Actual = 100; Forecast = 200; ForecastSource = 'Forecast'; Currency = '' }; ForecastCalls = 0 }
            @{ Scenario = 'cost data forecasting spend not yet incurred'; ActualAmount = 0; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 100; ExpectedForecast = $null; ExpectedSource = 'Unavailable'; CostData = @{ Actual = 0; Forecast = 100; ForecastSource = 'Forecast'; Currency = 'USD' }; ForecastCalls = 0 }
            @{ Scenario = 'cost data without a verified forecast'; ActualAmount = 100; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 180; ExpectedForecast = 180; ExpectedSource = 'Forecast'; CostData = @{ Actual = 100; Forecast = 100; ForecastSource = 'Actual'; Currency = 'USD' }; ForecastCalls = 1 }
            @{ Scenario = 'unavailable cost data'; ActualAmount = 100; ActualCurrency = 'USD'; ForecastCurrency = 'USD'; ForecastAmount = 180; ExpectedForecast = 180; ExpectedSource = 'Forecast'; CostData = @{ Actual = $null; Forecast = $null; ForecastSource = 'Unavailable'; Currency = $null }; ForecastCalls = 1 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ActualAmount = $ActualAmount; ActualCurrency = $ActualCurrency; ForecastCurrency = $ForecastCurrency; ForecastAmount = $ForecastAmount; ExpectedForecast = $ExpectedForecast; ExpectedSource = $ExpectedSource; CostData = $CostData; ForecastCalls = $ForecastCalls } {
                param($ActualAmount, $ActualCurrency, $ForecastCurrency, $ForecastAmount, $ExpectedForecast, $ExpectedSource, $CostData, $ForecastCalls)
                $fixtureActualAmount = [double]$ActualAmount
                $fixtureActualCurrency = $ActualCurrency
                $fixtureForecastCurrency = $ForecastCurrency
                $fixtureForecastAmount = $ForecastAmount
                Mock Resolve-CostMgId { $null }
                Mock Get-Date {
                    if ($Year) { return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [DateTimeKind]::Utc) }
                    [datetime]::new(2026, 9, 15, 0, 0, 0, [DateTimeKind]::Utc)
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $properties = if ($Path -match '/forecast\?') {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @($fixtureForecastAmount, $fixtureForecastCurrency)) }
                    }
                    else {
                        @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = @(, @($fixtureActualAmount, '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk', 'fixture', $fixtureActualCurrency)) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }

                $costDataMap = if ($CostData) { @{ '11111111-1111-1111-1111-111111111111' = $CostData } } else { $null }
                $result = @(Get-ResourceCosts -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -CostData $costDataMap)

                $result.Count | Should -Be 1
                $result[0].Actual | Should -Be $ActualAmount
                $result[0].Currency | Should -Be $ActualCurrency
                $result[0].Forecast | Should -Be $ExpectedForecast
                $result[0].ForecastSource | Should -Be $ExpectedSource
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $ForecastCalls -Exactly -ParameterFilter { $Path -match '/forecast\?' }
            }
        }

        It 'Keeps every subscription''s resource actuals when one forecast request fails' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { $null }
                Mock Get-Date {
                    if ($Year) { return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [DateTimeKind]::Utc) }
                    [datetime]::new(2026, 9, 15, 0, 0, 0, [DateTimeKind]::Utc)
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -match '/forecast\?') { return [pscustomobject]@{ StatusCode = 429; Content = '{}' } }
                    $subscription = [regex]::Match($Path, '^/subscriptions/([^/]+)/').Groups[1].Value
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = @(, @(100.0, "/subscriptions/$subscription/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk", 'fixture', 'USD')) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'B' }
                )
                $costData = @{
                    '11111111-1111-1111-1111-111111111111' = @{ Actual = 100; Forecast = 150; ForecastSource = 'Forecast'; Currency = 'USD' }
                    '22222222-2222-2222-2222-222222222222' = @{ Actual = 100; Forecast = 100; ForecastSource = 'Actual'; Currency = 'USD' }
                }

                $result = @(Get-ResourceCosts -Subscriptions $subscriptions -CostData $costData -WarningVariable forecastWarnings -WarningAction SilentlyContinue)

                $result.Count | Should -Be 2
                $verified = $result | Where-Object SubscriptionId -EQ '11111111-1111-1111-1111-111111111111'
                $verified.Actual | Should -Be 100
                $verified.Forecast | Should -Be 150
                $verified.ForecastSource | Should -Be 'Forecast'
                $verified.PSObject.Properties.Name | Should -Not -Contain 'CostIssue'
                $failed = $result | Where-Object SubscriptionId -EQ '22222222-2222-2222-2222-222222222222'
                $failed.Actual | Should -Be 100
                $failed.Forecast | Should -BeNullOrEmpty
                $failed.ForecastSource | Should -Be 'Unavailable'
                $failed.CostIssue | Should -Match 'for B are unavailable.*429'
                @($forecastWarnings | Where-Object { "$_" -match 'for B are unavailable.*429' }).Count | Should -Be 1
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -match '/forecast\?' }
            }
        }

        It 'Keeps every per-subscription resource cost row, including unattributed charges and IDs that differ only by case' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { $null }
                Mock Get-Date {
                    if ($Year) { return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [DateTimeKind]::Utc) }
                    [datetime]::new(2026, 9, 15, 0, 0, 0, [DateTimeKind]::Utc)
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $disk = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/Fixture/providers/Microsoft.Compute/disks/disk'
                    $rows = @(
                        @(100.0, '', 'rg-a', 'USD'),
                        @(25.0, '', 'rg-b', 'USD'),
                        @(10.0, $disk, 'Fixture', 'USD'),
                        @(5.0, $disk.ToLowerInvariant(), 'fixture', 'USD')
                    )
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = $rows }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $costData = @{ '11111111-1111-1111-1111-111111111111' = @{ Actual = 140; Forecast = 280; ForecastSource = 'Forecast'; Currency = 'USD' } }

                $result = @(Get-ResourceCosts -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -CostData $costData)

                $result.Count | Should -Be 4
                ($result | Measure-Object Actual -Sum).Sum | Should -Be 140
                ($result | Measure-Object Forecast -Sum).Sum | Should -Be 280
                @($result | Where-Object { -not $_.ResourcePath }).Count | Should -Be 2
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -match '/forecast\?' }
            }
        }

        It 'Labels month-to-date projections when more than 50 subscriptions skip the forecast request' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { $null }
                Mock Get-Date {
                    if ($Year) { return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [DateTimeKind]::Utc) }
                    [datetime]::new(2026, 9, 15, 0, 0, 0, [DateTimeKind]::Utc)
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $subscription = [regex]::Match($Path, '^/subscriptions/([^/]+)/').Groups[1].Value
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = @(, @(100.0, "/subscriptions/$subscription/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk", 'fixture', 'USD')) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(1..51 | ForEach-Object { [pscustomobject]@{ Id = ('{0:D8}-1111-1111-1111-111111111111' -f $_); Name = "Subscription $_" } })
                $costData = @{ $subscriptions[0].Id = @{ Actual = $null; Forecast = $null; ForecastSource = 'Unavailable'; Currency = $null } }

                $result = @(Get-ResourceCosts -Subscriptions $subscriptions -CostData $costData)

                $result.Count | Should -Be 51
                @($result | Where-Object { $_.Forecast -ne 200 -or $_.ForecastSource -ne 'Linear projection' }).Count | Should -Be 0
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -match '/forecast\?' }
            }
        }

        It 'Applies cost data forecasts to management-group resource costs for <Scenario>' -ForEach @(
            @{ Scenario = 'a verified forecast'; ActualAmount = 100; CostData = @{ Actual = 100; Forecast = 150; ForecastSource = 'Forecast'; Currency = 'USD' }; ExpectedForecast = 150; ExpectedSource = 'Forecast' }
            @{ Scenario = 'a forecast for spend not yet incurred'; ActualAmount = 0; CostData = @{ Actual = 0; Forecast = 100; ForecastSource = 'Forecast'; Currency = 'USD' }; ExpectedForecast = $null; ExpectedSource = 'Unavailable' }
            @{ Scenario = 'cost data without a verified forecast'; ActualAmount = 100; CostData = @{ Actual = 100; Forecast = 100; ForecastSource = 'Actual'; Currency = 'USD' }; ExpectedForecast = 200; ExpectedSource = 'Linear projection' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ActualAmount = $ActualAmount; CostData = $CostData; ExpectedForecast = $ExpectedForecast; ExpectedSource = $ExpectedSource } {
                param($ActualAmount, $CostData, $ExpectedForecast, $ExpectedSource)
                $fixtureActualAmount = [double]$ActualAmount
                Mock Resolve-CostMgId { 'fixture-group' }
                Mock Test-CostMgCoverage { $true }
                Mock Get-Date {
                    if ($Year) { return [datetime]::new($Year, $Month, $Day, 0, 0, 0, [DateTimeKind]::Utc) }
                    [datetime]::new(2026, 9, 15, 0, 0, 0, [DateTimeKind]::Utc)
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' }); rows = @(, @($fixtureActualAmount, '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk', 'fixture', 'USD')) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }

                $result = @(Get-ResourceCosts -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -CostData @{ '11111111-1111-1111-1111-111111111111' = $CostData })

                $result.Count | Should -Be 1
                $result[0].Forecast | Should -Be $ExpectedForecast
                $result[0].ForecastSource | Should -Be $ExpectedSource
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '/providers/Microsoft.Management/*' }
            }
        }

        It 'Counts a shared billed disk once in the orphan total while retaining both VM rows' {
            InModuleScope FinOpsMultitool {
                $resourceRoot = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute'
                $sharedDiskId = "$resourceRoot/disks/shared"
                Mock Search-AzGraphSafe {
                    if ($Query -match "type = 'Deallocated VM'") {
                        return @{ Data = @(foreach ($number in 1..2) {
                                [pscustomobject]@{
                                    id = "$resourceRoot/virtualMachines/vm-$number"; name = "vm-$number"
                                    resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'
                                    location = 'eastus'; vmSize = 'Standard_D2s_v5'; osDiskId = $null
                                    dataDisks = @(@{ managedDisk = @{ id = if ($number -eq 1) { $sharedDiskId } else { $sharedDiskId.ToUpperInvariant() } } })
                                }
                            }) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' })
                                rows = @(@(100, $sharedDiskId, 'USD'), @(999, "$resourceRoot/disks/unrelated", 'USD'))
                            } } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-OrphanedResources -Subscriptions @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected' }
                )

                $result.TotalCount | Should -Be 2
                $result.CostedCount | Should -Be 2
                $result.CostAvailable | Should -BeTrue
                $result.MonthlyCost | Should -Be 100
                $result.Currency | Should -Be 'USD'
                $result.CostIssue | Should -BeNullOrEmpty
                @($result.Orphans | Where-Object { $_.MonthlyCost -eq 100 -and $_.AttachedCost -eq 100 -and $_.Currency -eq 'USD' }).Count | Should -Be 2
            }
        }

        It 'Bounds orphan public-IP NIC expansion at 256 while retaining joins and native pagination' {
            InModuleScope FinOpsMultitool {
                $queries = [System.Collections.Generic.List[string]]::new()
                Mock Search-AzGraphSafe {
                    [void]$queries.Add($Query)
                    @{ Data = @() }
                }

                $result = Get-OrphanedResources -Subscriptions @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected' }
                ) -SkipCost

                $pipQuery = @($queries | Where-Object { $_ -match "type =~ 'microsoft.network/publicipaddresses'" })
                $pipQuery.Count | Should -Be 1
                $pipQuery[0] | Should -Match '\|\s*mv-expand ipc = properties\.ipConfigurations limit 256'
                $pipQuery[0] | Should -Match '\|\s*project id, name, resourceGroup, subscriptionId'
                @([regex]::Matches($pipQuery[0], '\|\s*join kind=leftouter')).Count | Should -Be 2
                $result.TotalCount | Should -Be 0
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter {
                    $Query -match "type =~ 'microsoft.network/publicipaddresses'" -and $All -and $First -eq 1000 -and
                    @($Subscription).Count -eq 1 -and $Subscription[0] -eq '11111111-1111-1111-1111-111111111111'
                }
            }
        }

        It 'Totals orphaned-resource costs only within one billing currency (<Scenario>)' -ForEach @(
            @{ Scenario = 'mixed currencies'; SecondCurrency = 'USD'; ExpectedTotal = $null; ExpectedCurrency = $null }
            @{ Scenario = 'one currency'; SecondCurrency = 'EUR'; ExpectedTotal = 300; ExpectedCurrency = 'EUR' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ SecondCurrency = $SecondCurrency; ExpectedTotal = $ExpectedTotal; ExpectedCurrency = $ExpectedCurrency } {
                param($SecondCurrency, $ExpectedTotal, $ExpectedCurrency)
                $fixtureSecondCurrency = $SecondCurrency
                Mock Search-AzGraphSafe {
                    if ($Query -match "type = 'Orphaned Disk'") {
                        return @{ Data = @(
                                [pscustomobject]@{ id = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk-a'; subscriptionId = '11111111-1111-1111-1111-111111111111'; name = 'disk-a'; resourceGroup = 'fixture'; location = 'eastus'; diskSizeGb = 100; sku = 'Standard_LRS' }
                                [pscustomobject]@{ id = '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk-b'; subscriptionId = '22222222-2222-2222-2222-222222222222'; name = 'disk-b'; resourceGroup = 'fixture'; location = 'eastus'; diskSizeGb = 100; sku = 'Standard_LRS' }
                            ) }
                    }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $first = $Path -like '/subscriptions/11111111-*'
                    $subscription = if ($first) { '11111111-1111-1111-1111-111111111111' } else { '22222222-2222-2222-2222-222222222222' }
                    $disk = if ($first) { 'disk-a' } else { 'disk-b' }
                    $currency = if ($first) { 'EUR' } else { $fixtureSecondCurrency }
                    $amount = if ($first) { 100 } else { 200 }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' }); rows = @(, @($amount, "/subscriptions/$subscription/resourceGroups/fixture/providers/Microsoft.Compute/disks/$disk", $currency)) } } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-OrphanedResources -Subscriptions @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'B' }
                )

                $result.TotalCount | Should -Be 2
                $result.MonthlyCost | Should -Be $ExpectedTotal
                $result.Currency | Should -Be $ExpectedCurrency
                ($result.Orphans | Where-Object ResourceName -EQ 'disk-b').Currency | Should -Be $SecondCurrency
                ($result.Orphans | Where-Object ResourceName -EQ 'disk-b').MonthlyCost | Should -Be 200
                if ($null -eq $ExpectedTotal) { $result.CostIssue | Should -Match 'multiple billing currencies' }
                else { $result.CostIssue | Should -BeNullOrEmpty }
            }
        }
    }

    Context 'Tag values and allocation' {
        It 'Rounds actual tag costs from decimal input while preserving allocation for <Case>' -ForEach @(
            @{ Case = 'a positive midpoint'; Amount = 1.015; Expected = 1.02 }
            @{ Case = 'a negative midpoint credit'; Amount = -1.015; Expected = -1.02 }
            @{ Case = 'an even midpoint'; Amount = 1.025; Expected = 1.02 }
            @{ Case = 'a measured zero'; Amount = 0.0; Expected = 0.0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Amount = $Amount; Expected = $Expected } {
                param($Amount, $Expected)
                $rgId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture'
                $firstId = "$rgId/providers/Microsoft.Compute/disks/disk-a"
                $secondId = "$rgId/providers/Microsoft.Compute/disks/disk-b"
                $fallbackId = "$rgId/providers/Microsoft.Compute/disks/disk-c"
                $untaggedId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/other/providers/Microsoft.Compute/disks/disk-d'
                Mock Search-AzGraphSafe {
                    if ($Query -match '^resources\s') {
                        return @{ Data = @(
                                [pscustomobject]@{ id = $firstId; tags = @{ CostCenter = 'Prod' } }
                                [pscustomobject]@{ id = $secondId; tags = @{ CostCenter = 'prod' } }
                            ) }
                    }
                    @{ Data = @([pscustomobject]@{ id = $rgId; tags = @{ CostCenter = 'fallback' } }) }
                }
                $fixtureContent = (@{ properties = @{
                            columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' })
                            rows = @(@(10.0, $firstId, 'USD'), @($Amount, $secondId, 'USD'), @(2.0, $fallbackId, 'USD'), @(3.0, $untaggedId, 'USD'), @(-1.0, '', 'USD'))
                        } } | ConvertTo-Json -Depth 8 -Compress).Replace("'", "''")
                $definition = (Get-Command Get-CostByTag).Definition
                $ast = [Management.Automation.Language.Parser]::ParseInput($definition, [ref]$null, [ref]$null)
                $transport = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-ParallelRestCalls' }, $true)
                $transport | Should -Not -BeNullOrEmpty
                $replacement = 'function Invoke-ParallelRestCalls { param([array]$Calls, [int]$TimeoutSeconds); foreach ($call in $Calls) { @{ Call = $call; Result = [pscustomobject]@{ StatusCode = 200; Content = ''' + $fixtureContent + ''' } } } }'
                $scan = [scriptblock]::Create($definition.Remove($transport.Extent.StartOffset, $transport.Extent.EndOffset - $transport.Extent.StartOffset).Insert($transport.Extent.StartOffset, $replacement))

                $result = & $scan -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -ExistingTags @{ CostCenter = [pscustomobject]@{ TotalResources = 4 } }

                $buckets = @($result.CostByTag.CostCenter)
                ($buckets | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 10
                $lower = @($buckets | Where-Object { $_.TagValue -ceq 'prod' })
                if ($Expected -eq 0) { $lower.Count | Should -Be 0 }
                else {
                    $lower.Count | Should -Be 1
                    $lower[0].Cost | Should -Be $Expected
                    $lower[0].Cost | Should -BeOfType ([double])
                }
                ($buckets | Where-Object TagValue -EQ 'fallback').Cost | Should -Be 2
                ($buckets | Where-Object TagValue -EQ '(untagged)').Cost | Should -Be 3
                ($buckets | Where-Object TagValue -EQ '(non-resource charges)').Cost | Should -Be -1
                [math]::Round(($buckets | Measure-Object Cost -Sum).Sum, 2) | Should -Be (14 + $Expected)
                $result.AllocatedCost | Should -Be (12 + $Expected)
                $result.UnallocatedCost | Should -Be 3
                $result.ResourceCostSeen | Should -Be (15 + $Expected)
                [math]::Round(($result.AllocatedCost + $result.UnallocatedCost), 2) | Should -Be $result.ResourceCostSeen
                $result.Currency | Should -Be 'USD'
                @($buckets | Where-Object Currency -NE 'USD').Count | Should -Be 0
                $result.CoverageIncomplete | Should -BeFalse
                $result.SuccessfulSubscriptionIds | Should -Be @('11111111-1111-1111-1111-111111111111')
            }
        }

        It 'Keeps case-distinct tag values and counts <TagName> as an allocation tag' -ForEach @(
            @{ TagName = 'CostCenter' }
            @{ TagName = 'ApplicationName' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ TagName = $TagName } {
                param($TagName)
                $fixtureTagName = $TagName
                $firstId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk-a'
                $secondId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/disk-b'
                Mock Search-AzGraphSafe {
                    if ($Query -match '^resources\s') {
                        return @{ Data = @(
                                [pscustomobject]@{ id = $firstId; tags = @{ $fixtureTagName = 'Prod' } }
                                [pscustomobject]@{ id = $secondId; tags = @{ $fixtureTagName = 'prod' } }
                            ) }
                    }
                    @{ Data = @() }
                }
                # Mocks don't reach the runspaces behind the nested transport, so replace
                # only that transport and keep the scan's own aggregation code.
                $fixtureContent = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' }); rows = @(@(100, $firstId, 'USD'), @(200, $secondId, 'USD')) } } | ConvertTo-Json -Depth 8 -Compress).Replace("'", "''")
                $definition = (Get-Command Get-CostByTag).Definition
                $ast = [Management.Automation.Language.Parser]::ParseInput($definition, [ref]$null, [ref]$null)
                $transport = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-ParallelRestCalls' }, $true)
                $transport | Should -Not -BeNullOrEmpty
                $replacement = 'function Invoke-ParallelRestCalls { param([array]$Calls, [int]$TimeoutSeconds); foreach ($call in $Calls) { @{ Call = $call; Result = [pscustomobject]@{ StatusCode = 200; Content = ''' + $fixtureContent + ''' } } } }'
                $scan = [scriptblock]::Create($definition.Remove($transport.Extent.StartOffset, $transport.Extent.EndOffset - $transport.Extent.StartOffset).Insert($transport.Extent.StartOffset, $replacement))

                $result = & $scan -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -ExistingTags @{ $TagName = [pscustomobject]@{ TotalResources = 2 } }

                @($result.CostByTag[$TagName]).Count | Should -Be 2
                ($result.CostByTag[$TagName] | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 100
                ($result.CostByTag[$TagName] | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 200
                $result.UnallocatedCost | Should -Be 0
                (Get-KpiComputedValue -KpiId 'pct-costs-untagged' -Data $result).Value | Should -Be 0
            }
        }
    }

    Context 'Coverage' {
        It 'Withholds cost per GB when <Failure>' -ForEach @(
            @{ Failure = 'storage capacity is unreadable' }
            @{ Failure = 'storage capacity has no measurement' }
            @{ Failure = 'managed disk inventory is unavailable' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Failure = $Failure } {
                param($Failure)
                $fixtureFailure = $Failure
                Mock Resolve-CostMgId { $null }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'microsoft.compute/disks') {
                        if ($fixtureFailure -eq 'managed disk inventory is unavailable') { return $null }
                        return @{ Data = @([pscustomobject]@{ totalGb = 100 }) }
                    }
                    if ($Query -match 'storageaccounts') { return @{ Data = @([pscustomobject]@{ id = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }) } }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -match 'Microsoft.Insights/metrics') {
                        if ($fixtureFailure -eq 'storage capacity is unreadable') { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                        $average = if ($fixtureFailure -eq 'storage capacity has no measurement') { $null } else { 0 }
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ timeseries = @(@{ data = @(@{ timeStamp = '2026-09-15T00:00:00Z'; average = $average }) }) }) } | ConvertTo-Json -Depth 8) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'MeterCategory' }, @{ name = 'Currency' }); rows = @(, @(1000.0, 'Storage', 'USD')) } } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -WarningAction SilentlyContinue

                $result.StorageCost | Should -Be 1000
                $result.CostPerGb | Should -BeNullOrEmpty
                $result.Note | Should -Match 'cost per GB stored is unavailable'
            }
        }

        It 'Publishes cost per GB when every storage account reports a measured zero' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { $null }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'microsoft.compute/disks') { return @{ Data = @([pscustomobject]@{ totalGb = 100 }) } }
                    if ($Query -match 'storageaccounts') { return @{ Data = @([pscustomobject]@{ id = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }) } }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -match 'Microsoft.Insights/metrics') {
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ timeseries = @(@{ data = @(@{ timeStamp = '2026-09-15T00:00:00Z'; average = 0 }) }) }) } | ConvertTo-Json -Depth 8) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'MeterCategory' }, @{ name = 'Currency' }); rows = @(, @(1000.0, 'Storage', 'USD')) } } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' })

                $result.BlobFileOk | Should -BeTrue
                $result.CostPerGb | Should -Be 10
            }
        }

        It 'Rejects an export run without a manifest when <Signal>' -ForEach @(
            @{ Signal = 'the export is partitioned'; Partitioned = $true; BlobName = 'costs/selected/20260901-20260930/run/data.csv' }
            @{ Signal = 'the run folder is a run ID'; Partitioned = $false; BlobName = 'costs/selected/20260901-20260930/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/data.csv' }
            @{ Signal = 'the file is a partition'; Partitioned = $false; BlobName = 'costs/selected/20260901-20260930/run/part_0.csv' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Partitioned = $Partitioned; BlobName = $BlobName } {
                param($Partitioned, $BlobName)
                $fixtureBlobName = $BlobName
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @([pscustomobject]@{ Name = $fixtureBlobName; LastModified = [datetime]'2026-09-16' }) }
                }
                Mock Get-StorageBlobBytes { throw 'An unverified run must not be downloaded.' }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'FocusCost'; Partitioned = $Partitioned; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }

                { Get-CostExportData -Export $export } | Should -Throw '*no manifest.json*'
                Should -Invoke Get-StorageBlobBytes -Times 0 -Exactly
            }
        }

        It 'Rejects an export run whose manifest declarations are <Defect>' -ForEach @(
            @{ Defect = 'blank'; Parts = @('part_0.csv'); Declared = @('') }
            @{ Defect = 'duplicated'; Parts = @('part_0.csv'); Declared = @('part_0.csv', 'part_0.csv') }
            @{ Defect = 'duplicated with a matching count'; Parts = @('part_0.csv', 'part_1.csv'); Declared = @('part_0.csv', 'part_0.csv') }
            @{ Defect = 'missing a stored part'; Parts = @('part_0.csv', 'part_1.csv'); Declared = @('part_0.csv') }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Parts = $Parts; Declared = $Declared } {
                param($Parts, $Declared)
                $fixtureFolder = 'costs/selected/20260901-20260930/run'
                $fixtureManifest = @{ blobs = @($Declared | ForEach-Object { @{ blobName = $(if ($_) { "$fixtureFolder/$_" } else { '' }) } }) } | ConvertTo-Json -Depth 4
                $fixtureBlobs = @($Parts | ForEach-Object { [pscustomobject]@{ Name = "$fixtureFolder/$_"; LastModified = [datetime]'2026-09-16' } }) +
                [pscustomobject]@{ Name = "$fixtureFolder/manifest.json"; LastModified = [datetime]'2026-09-16' }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList { @{ Listed = $true; Blobs = $fixtureBlobs } }
                Mock Get-StorageBlobBytes {
                    if ($Uri -like '*manifest.json') { return , [Text.Encoding]::UTF8.GetBytes($fixtureManifest) }
                    throw 'An unverified run must not be downloaded.'
                }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'FocusCost'; Partitioned = $true; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }

                { Get-CostExportData -Export $export } | Should -Throw '*incomplete*'
                Should -Invoke Get-StorageBlobBytes -Times 0 -Exactly -ParameterFilter { $Uri -like '*.csv' }
            }
        }

        It 'Reads every part that the manifest lists (<Compression> compression)' -ForEach @(
            @{ Compression = 'no'; Extension = 'csv' }
            @{ Compression = 'Gzip'; Extension = 'csv.gz' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Extension = $Extension } {
                param($Extension)
                $fixtureFolder = 'costs/selected/20260901-20260930/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                $fixtureParts = @("$fixtureFolder/part_0_0001.$Extension", "$fixtureFolder/part_1_0001.$Extension")
                $fixtureManifest = @{ blobs = @($fixtureParts | ForEach-Object { @{ blobName = $_ } }) } | ConvertTo-Json -Depth 4
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(@($fixtureParts + "$fixtureFolder/manifest.json") | ForEach-Object { [pscustomobject]@{ Name = $_; LastModified = [datetime]'2026-09-16' } }) }
                }
                Mock Get-StorageBlobBytes {
                    if ($Uri -like '*manifest.json') { return , [Text.Encoding]::UTF8.GetBytes($fixtureManifest) }
                    $amount = if ($Uri -match 'part_1') { 20 } else { 10 }
                    $bytes = [Text.Encoding]::UTF8.GetBytes("SubscriptionId,BilledCost,BillingCurrency,ChargePeriodStart`n11111111-1111-1111-1111-111111111111,$amount,USD,2026-09-15")
                    if ($Uri -notlike '*.gz') { return , $bytes }
                    $stream = [IO.MemoryStream]::new()
                    $gzip = [IO.Compression.GZipStream]::new($stream, [IO.Compression.CompressionMode]::Compress)
                    $gzip.Write($bytes, 0, $bytes.Length)
                    $gzip.Dispose()
                    , $stream.ToArray()
                }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'FocusCost'; Partitioned = $true; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }

                $data = Get-CostExportData -Export $export

                $data.RowCount | Should -Be 2
                ($data.Rows | Measure-Object -Property BilledCost -Sum).Sum | Should -Be 30
            }
        }

        It 'Reads a legacy export whose name starts with part_ without requiring a manifest' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = 'costs/part_daily/20260901-20260930/part_daily_first.csv'; LastModified = [datetime]'2026-09-15' }
                            [pscustomobject]@{ Name = 'costs/part_daily/20260901-20260930/part_daily_second.csv'; LastModified = [datetime]'2026-09-16' }
                        ) }
                }
                Mock Get-StorageBlobBytes {
                    $amount = if ($Uri -match 'second') { 20 } else { 10 }
                    , [Text.Encoding]::UTF8.GetBytes("SubscriptionId,BilledCost,BillingCurrency,ChargePeriodStart`n11111111-1111-1111-1111-111111111111,$amount,USD,2026-09-15")
                }
                $export = [pscustomobject]@{ Name = 'part_daily'; Format = 'Csv'; Type = 'FocusCost'; Partitioned = $false; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }

                $data = Get-CostExportData -Export $export

                $data.RowCount | Should -Be 1
                Should -Invoke Get-StorageBlobBytes -Times 1 -Exactly -ParameterFilter { $Uri -match 'part_daily_second' }
            }
        }

        It 'Reads the latest hub CSV run for each export scope (<Scenario>)' -ForEach @(
            @{ Scenario = 'separate export scopes'; Expected = 300; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 100 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Parts = @{ 'part_0.csv' = 200 } }
                ) }
            @{ Scenario = 'every part of a run'; Expected = 30; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10; 'part_1.csv' = 20 } }
                ) }
            @{ Scenario = 'a later run in another folder layout'; Expected = 20; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = '202609150100/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'runs without a known order'; Expected = $null; ExpectedError = "*can't be ordered*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = $null; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'runs submitted at the same time'; Expected = $null; ExpectedError = "*can't be ordered*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'a run missing a listed part'; Expected = $null; ExpectedError = "*aren't in msexports*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10; 'part_1.csv' = 20 }; Missing = 'part_1.csv' }
                ) }
            @{ Scenario = 'other datasets and unlisted files'; Expected = 10; ExpectedError = $null; Stray = 'resourceGroups/rg-a/focuscost/20260901-20260930/stray.csv'; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'cccccccc-cccc-cccc-cccc-cccccccccccc'; Submitted = '2026-09-16T01:00:00Z'; Type = 'PriceSheet'; Parts = @{ 'part_0.csv' = 500 } }
                ) }
            @{ Scenario = 'only the newest month'; Expected = 20; ExpectedError = $null; Stray = $false; SkippedDownload = '*20260801-20260831*.csv'; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 20 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-31T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                ) }
            @{ Scenario = 'an empty current month'; Expected = 10; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-01T01:00:00Z'; Empty = $true; Parts = @{ 'part_0.csv' = 0 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-31T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                ) }
            @{ Scenario = 'a run outside a month folder'; Expected = 10; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; OutsideMonthFolder = $true; Parts = @{ 'part_0.csv' = 10 } }
                ) }
            @{ Scenario = 'an earlier month filed in the current month folder'; Expected = 50; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Month = '202610'; Submitted = '2026-10-05T01:00:00Z'; Parts = @{ 'part_0.csv' = 50 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202609'; FolderMonth = '202610'; Submitted = '2026-10-06T01:00:00Z'; Parts = @{ 'part_0.csv' = 900 } }
                ) }
            @{ Scenario = 'two months with an earlier month filed in the current month folder'; Expected = 950; Months = 2; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Month = '202610'; Submitted = '2026-10-05T01:00:00Z'; Parts = @{ 'part_0.csv' = 50 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202609'; FolderMonth = '202610'; Submitted = '2026-10-06T01:00:00Z'; Parts = @{ 'part_0.csv' = 900 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'cccccccc-cccc-cccc-cccc-cccccccccccc'; Month = '202609'; Submitted = '2026-09-30T01:00:00Z'; Parts = @{ 'part_0.csv' = 800 } }
                ) }
            @{ Scenario = 'a later run filed in an earlier month folder'; Expected = 40; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Month = '202610'; Submitted = '2026-10-03T01:00:00Z'; Parts = @{ 'part_0.csv' = 30 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202610'; FolderMonth = '202609'; Submitted = '2026-10-05T01:00:00Z'; Parts = @{ 'part_0.csv' = 40 } }
                ) }
            @{ Scenario = 'an empty later run'; Expected = 300; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 100 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Empty = $true; Parts = @{ 'part_0.csv' = 0 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'cccccccc-cccc-cccc-cccc-cccccccccccc'; Submitted = '2026-09-16T01:00:00Z'; Parts = @{ 'part_0.csv' = 200 } }
                ) }
            @{ Scenario = 'another subscription''s run missing a listed part'; Expected = 10; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'other-subscription'; ExportScope = '/subscriptions/22222222-2222-2222-2222-222222222222'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'a billing account run missing a listed part'; Expected = $null; ExpectedError = "*aren't in msexports*"; Stray = $false; Runs = @(
                    @{ Scope = 'billing'; ExportScope = '/providers/Microsoft.Billing/billingAccounts/fixture'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'an unlisted CSV in a month without manifests'; Expected = 10; ExpectedError = $null; Stray = 'resourceGroups/rg-a/focuscost/20260901-20260930/stray.csv'; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Month = '202608'; Submitted = '2026-08-31T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                ) }
            @{ Scenario = 'an unreadable manifest'; Expected = $null; ExpectedError = "*couldn't be read*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'unknown'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Unreadable = $true; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'an unreadable manifest dated before the months read'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'unknown'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Unreadable = $true; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'an unreadable manifest in a month that is still needed'; Expected = $null; ExpectedError = "*couldn't be read*"; Months = 2; DownloadsBeforeError = $true; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'unknown'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Unreadable = $true; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'invalid counts for a selected scope'; Expected = $null; ExpectedError = '*invalid blob or row counts*'; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; BlobCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'invalid counts dated before the months read'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; BlobCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'invalid counts for another subscription'; Expected = 10; ExpectedError = $null; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'other-subscription'; ExportScope = '/subscriptions/22222222-2222-2222-2222-222222222222'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; BlobCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'a manifest without a dataset type'; Expected = $null; ExpectedError = "*doesn't identify its dataset*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; OmitType = $true; Parts = @{ 'part_0.csv' = 50 } }
                ) }
            @{ Scenario = 'a dataset type that is not text'; Expected = $null; ExpectedError = "*doesn't identify its dataset*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; TypeValue = 123; Parts = @{ 'part_0.csv' = 50 } }
                ) }
            @{ Scenario = 'invalid counts for the read month filed in an earlier folder'; Expected = $null; ExpectedError = '*invalid blob or row counts*'; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; FolderMonth = '202608'; Submitted = '2026-09-16T01:00:00Z'; BlobCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'invalid counts for an earlier month filed in the read folder'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; FolderMonth = '202609'; Submitted = '2026-09-16T01:00:00Z'; BlobCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'an invalid row count'; Expected = $null; ExpectedError = '*invalid blob or row counts*'; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; RowCountValue = 'invalid'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'an unreadable manifest outside a month folder'; Expected = $null; ExpectedError = "*couldn't be read*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'unknown'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Unreadable = $true; OutsideMonthFolder = $true; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
            @{ Scenario = 'an unreadable earlier manifest whose CSV remains'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; UnlistedWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'unknown'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Unreadable = $true; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'more manifests than the reader checks'; Expected = $null; ExpectedError = '*more than the 1 this storage reader checks*'; MaxManifests = 1; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'an oversized manifest in the read month'; Expected = $null; ExpectedError = '*larger than 1 MB*'; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; Oversized = $true; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'an oversized manifest dated before the months read'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; UnlistedWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Oversized = $true; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'a part listed by two export runs'; Expected = $null; ExpectedError = '*counted twice*'; DownloadsBeforeError = $true; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = 'resourceGroups/rg-b'; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Submitted = '2026-09-16T01:00:00Z'; ListedPart = 'resourceGroups/rg-a/focuscost/20260901-20260930/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/part_0.csv'; Parts = @{ 'part_0.csv' = 20 } }
                ) }
            @{ Scenario = 'a scope with control characters'; Expected = $null; ExpectedError = "*doesn't identify its export scope*"; Stray = $false; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; ExportScope = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-a$([char]27)[8m"; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                ) }
            @{ Scenario = 'an unreadable earlier manifest with control characters in its path'; Expected = 10; ExpectedError = $null; Stray = $false; IgnoredWarning = $true; Runs = @(
                    @{ Scope = 'resourceGroups/rg-a'; Run = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Submitted = '2026-09-15T01:00:00Z'; Parts = @{ 'part_0.csv' = 10 } }
                    @{ Scope = "resourceGroups/rg-$([char]27)[8m"; Run = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Month = '202608'; Submitted = '2026-08-16T01:00:00Z'; Unreadable = $true; Parts = @{ 'part_0.csv' = 20 }; Missing = 'part_0.csv' }
                ) }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Runs = $Runs; Expected = $Expected; ExpectedError = $ExpectedError; Stray = $Stray; SkippedDownload = $_.SkippedDownload; Months = $(if ($_.Months) { $_.Months } else { 1 }); IgnoredWarning = [bool]$_.IgnoredWarning; DownloadsBeforeError = [bool]$_.DownloadsBeforeError; UnlistedWarning = [bool]$_.UnlistedWarning; MaxManifests = $_.MaxManifests } {
                param($Runs, $Expected, $ExpectedError, $Stray, $SkippedDownload, $Months, $IgnoredWarning, $DownloadsBeforeError, $UnlistedWarning, $MaxManifests)
                $fixtureSubscription = '11111111-1111-1111-1111-111111111111'
                $fixtureSkippedDownload = $SkippedDownload
                $fixtureFiles = @{}
                $fixtureOversized = [System.Collections.Generic.HashSet[string]]::new()
                foreach ($run in $Runs) {
                    $type = if ($run.Type) { $run.Type } else { 'FocusCost' }
                    $exportName = $type.ToLowerInvariant()
                    $month = if ($run.Month) { $run.Month } else { '202609' }
                    $year = [int]$month.Substring(0, 4)
                    $monthNumber = [int]$month.Substring(4, 2)
                    $folderMonth = if ($run.FolderMonth) { $run.FolderMonth } else { $month }
                    $periodFolder = '{0}01-{0}{1:00}' -f $folderMonth, [datetime]::DaysInMonth([int]$folderMonth.Substring(0, 4), [int]$folderMonth.Substring(4, 2))
                    $folder = if ($run.OutsideMonthFolder) { "$($run.Scope)/$exportName/$($run.Run)" } else { "$($run.Scope)/$exportName/$periodFolder/$($run.Run)" }
                    $exportScope = if ($run.ExportScope) { $run.ExportScope } else { "/subscriptions/$fixtureSubscription/$($run.Scope)" }
                    $blobs = @(foreach ($part in $run.Parts.Keys) {
                            if ($part -ne $run.Missing -and -not $run.Empty) { $fixtureFiles["$folder/$part"] = "BilledCost,BillingCurrency,SubAccountId`n$($run.Parts[$part]),USD,$fixtureSubscription" }
                            @{ blobName = "$folder/$part"; byteCount = 1; dataRowCount = $(if ($run.Empty) { 0 } else { 1 }) }
                        })
                    if ($run.ListedPart) { $blobs = @(@{ blobName = $run.ListedPart; byteCount = 1; dataRowCount = 1 }) }
                    if ($run.Oversized) { [void]$fixtureOversized.Add("$folder/manifest.json") }
                    $fixtureFiles["$folder/manifest.json"] = if ($run.Unreadable) { '{ "blobCount": ' } else {
                        @{
                            manifestVersion = '2024-04-01'; blobCount = $(if ($run.ContainsKey('BlobCountValue')) { $run.BlobCountValue } else { $blobs.Count }); dataRowCount = $(if ($run.ContainsKey('RowCountValue')) { $run.RowCountValue } elseif ($run.Empty) { 0 } else { $blobs.Count })
                            exportConfig = $(if ($run.OmitType) { @{ exportName = $exportName; resourceId = "$exportScope/providers/Microsoft.CostManagement/exports/$exportName" } } else { @{ exportName = $exportName; type = $(if ($run.ContainsKey('TypeValue')) { $run.TypeValue } else { $type }); resourceId = "$exportScope/providers/Microsoft.CostManagement/exports/$exportName" } })
                            runInfo = @{ submittedTime = $run.Submitted; runId = [guid]::NewGuid().ToString(); startDate = ('{0}-{1:00}-01T00:00:00' -f $year, $monthNumber) }
                            blobs = $blobs
                        } | ConvertTo-Json -Depth 6
                    }
                }
                if ($Stray) { $fixtureFiles[$Stray] = "BilledCost,BillingCurrency,SubAccountId`n99,USD,$fixtureSubscription" }
                Mock New-AzStorageContext { $null }
                Mock Write-Warning { }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion') { return @() }
                    foreach ($path in $fixtureFiles.Keys) { [pscustomobject]@{ Name = Split-Path $path -Leaf; Path = $path; IsDirectory = $false; Length = $(if ($fixtureOversized.Contains($path)) { 2MB } else { 100 }) } }
                }
                Mock Get-AzDataLakeGen2ItemContent {
                    if (-not $fixtureFiles.ContainsKey($Path)) { throw "Unexpected download: $Path" }
                    Set-Content -LiteralPath $Destination -Value $fixtureFiles[$Path]
                }

                $readParameters = @{ StorageAccountName = 'fixture'; ResourceGroupName = 'fixture'; Months = $Months; SubscriptionIds = @($fixtureSubscription) }
                if ($MaxManifests) { $readParameters.MaxManifests = $MaxManifests }

                if ($ExpectedError) {
                    # Rows emitted before the error would reach callers that stream the output.
                    $streamed = [System.Collections.Generic.List[object]]::new()
                    { Read-FinOpsHubData @readParameters | ForEach-Object { $streamed.Add($_) } } | Should -Throw $ExpectedError
                    $streamed.Count | Should -Be 0
                    Should -Invoke Get-AzDataLakeGen2ItemContent -Times $(if ($DownloadsBeforeError) { 1 } else { 0 }) -Exactly -ParameterFilter { $Path -like '*.csv' }
                }
                else {
                    $rows = @(Read-FinOpsHubData @readParameters)
                    ($rows | Measure-Object -Property BilledCost -Sum).Sum | Should -Be $Expected
                    Should -Invoke Write-Warning -Times $(if ($IgnoredWarning) { 1 } else { 0 }) -Exactly -ParameterFilter { $Message -like 'Ignored 1 export manifest*dated before the months read*' }
                    Should -Invoke Write-Warning -Times $(if ($Stray -or $UnlistedWarning) { 1 } else { 0 }) -Exactly -ParameterFilter { $Message -like '*no readable export manifest lists*' }
                    if ($fixtureSkippedDownload) { Should -Invoke Get-AzDataLakeGen2ItemContent -Times 0 -Exactly -ParameterFilter { $Path -like $fixtureSkippedDownload } }
                }
                Should -Invoke Get-AzDataLakeGen2ItemContent -Times 0 -Exactly -ParameterFilter { $fixtureOversized.Contains($Path) }
                Should -Invoke Write-Warning -Times 0 -Exactly -ParameterFilter { $Message -match '[\p{Cc}\p{Cf}]' }
            }
        }

        It 'Reads only the newest snapshot from an unpartitioned export folder' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = 'costs/selected/20260901-20260930/selected_first.csv'; LastModified = [datetime]'2026-09-15' }
                            [pscustomobject]@{ Name = 'costs/selected/20260901-20260930/selected_second.csv'; LastModified = [datetime]'2026-09-16' }
                        ) }
                }
                Mock Get-StorageBlobBytes {
                    $amount = if ($Uri -match 'second') { 20 } else { 10 }
                    , [Text.Encoding]::UTF8.GetBytes("SubscriptionId,BilledCost,BillingCurrency,ChargePeriodStart`n11111111-1111-1111-1111-111111111111,$amount,USD,2026-09-15")
                }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'FocusCost'; Partitioned = $false; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/fixturestore' }

                $data = Get-CostExportData -Export $export
                $selected = Select-CostExportData -ExportData $data -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' })

                $data.RowCount | Should -Be 1
                ($selected.Rows | Measure-Object Cost -Sum).Sum | Should -Be 20
                $selected.CoverageIncomplete | Should -BeFalse
                Should -Invoke Get-StorageBlobBytes -Times 1 -Exactly -ParameterFilter { $Uri -match 'selected_second' }
            }
        }

        It 'Retries Advisor through REST after <Failure> (REST status <Status>)' -ForEach @(
            @{ Failure = 'an unreadable page'; Status = 200; ExpectedCount = 2; Incomplete = $false }
            @{ Failure = 'an unreadable page'; Status = 403; ExpectedCount = 0; Incomplete = $true }
            @{ Failure = 'no Resource Graph response'; Status = 200; ExpectedCount = 2; Incomplete = $false }
            @{ Failure = 'a non-numeric savings value'; Status = 200; ExpectedCount = 2; Incomplete = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Failure = $Failure; Status = $Status; ExpectedCount = $ExpectedCount; Incomplete = $Incomplete } {
                param($Failure, $Status, $ExpectedCount, $Incomplete)
                $fixtureFailure = $Failure
                $fixtureStatus = $Status
                Mock Search-AzGraphSafe {
                    if ($fixtureFailure -eq 'no Resource Graph response') { return $null }
                    if ($fixtureFailure -eq 'a non-numeric savings value') {
                        $recommendation = @{ subscriptionId = '11111111-1111-1111-1111-111111111111'; shortDescriptionProblem = 'Right-size underused virtual machines'; shortDescriptionSolution = 'Resize'; impact = 'High'; impactedField = 'Microsoft.Compute/virtualMachines'; savingsAmount = ''; savingsCurrency = 'USD' }
                        return @{ Data = @(
                                [pscustomobject](@{ id = 'rec-a'; impactedValue = 'vm-a'; annualSavings = '100' } + $recommendation)
                                [pscustomobject](@{ id = 'rec-b'; impactedValue = 'vm-b'; annualSavings = 'not available' } + $recommendation)
                            ) }
                    }
                    throw 'Resource Graph query failed after 1 page(s); results are incomplete.'
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($fixtureStatus -ne 200) { return [pscustomobject]@{ StatusCode = $fixtureStatus; Content = '{"error":{"code":"AuthorizationFailed"}}' } }
                    $items = @(
                        @{ properties = @{ impact = 'High'; impactedField = 'Microsoft.Compute/virtualMachines'; impactedValue = 'vm-a'; shortDescription = @{ problem = 'Right-size underused virtual machines'; solution = 'Resize' }; extendedProperties = @{ annualSavingsAmount = '100'; savingsCurrency = 'USD' } } }
                        @{ properties = @{ impact = 'Medium'; impactedField = 'Microsoft.Compute/virtualMachines'; impactedValue = 'vm-b'; shortDescription = @{ problem = 'Right-size underused virtual machines'; solution = 'Resize' }; extendedProperties = @{ annualSavingsAmount = '50'; savingsCurrency = 'USD' } } }
                    )
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $items } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-OptimizationAdvice -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -WarningAction SilentlyContinue

                $result.TotalCount | Should -Be $ExpectedCount
                $result.CoverageIncomplete | Should -Be $Incomplete
                if ($Incomplete) { $result.Note | Should -Match 'incomplete' }
                else { $result.EstimatedAnnualSavings | Should -Be 150 }
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter { $All -and $Query -match 'project id, subscriptionId' }
            }
        }

        It 'Counts each reservation recommendation once when the Resource Graph read fails partway' {
            InModuleScope FinOpsMultitool {
                $fixtureRecommendation = @{ subscriptionId = '11111111-1111-1111-1111-111111111111'; shortDescriptionProblem = 'Consider virtual machine reserved instances'; shortDescriptionSolution = 'Buy reserved instances'; impact = 'High'; impactedField = 'Microsoft.Compute/virtualMachines'; savingsCurrency = 'USD'; term = 'P1Y'; region = 'eastus'; displayQty = '1' }
                Mock Search-AzGraphSafe {
                    @{ SkipToken = $null; Data = @(
                            [pscustomobject](@{ recName = 'rec-a'; impactedValue = 'vm-a'; assessedResourceId = '/subscriptions/fixture/resourceGroups/a/providers/Microsoft.Compute/virtualMachines/vm-a'; displaySKU = 'Standard_D2s_v5'; annualSavings = '100' } + $fixtureRecommendation)
                            [pscustomobject](@{ recName = 'rec-b'; impactedValue = 'vm-b'; assessedResourceId = '/subscriptions/fixture/resourceGroups/a/providers/Microsoft.Compute/virtualMachines/vm-b'; displaySKU = 'Standard_D4s_v5'; annualSavings = 'not available' } + $fixtureRecommendation)
                        ) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -notlike '*/Microsoft.Advisor/recommendations*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    $items = foreach ($fixture in @(@('rec-a', 'vm-a', 'Standard_D2s_v5', '100'), @('rec-b', 'vm-b', 'Standard_D4s_v5', '50'))) {
                        @{ name = $fixture[0]; properties = @{ impact = 'High'; impactedField = 'Microsoft.Compute/virtualMachines'; impactedValue = $fixture[1]; resourceMetadata = @{ resourceId = "/subscriptions/fixture/resourceGroups/a/providers/Microsoft.Compute/virtualMachines/$($fixture[1])" }; shortDescription = @{ problem = 'Consider virtual machine reserved instances'; solution = 'Buy reserved instances' }; extendedProperties = @{ annualSavingsAmount = $fixture[3]; savingsCurrency = 'USD'; term = 'P1Y'; displaySKU = $fixture[2]; region = 'eastus'; displayQty = '1' } } }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items) } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -WarningAction SilentlyContinue

                $result.TotalAdvisorCount | Should -Be 2
                @($result.AdvisorRecommendations | ForEach-Object { $_.DuplicateCount }) | Should -Be @(1, 1)
                $result.EstimatedAnnualSavings | Should -Be 150
            }
        }

        It 'Counts only enabled anomaly rules as detection coverage (<RuleStatus>)' -ForEach @(
            @{ RuleStatus = 'Disabled'; Expected = 0 }
            @{ RuleStatus = 'Enabled'; Expected = 1 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ RuleStatus = $RuleStatus; Expected = $Expected } {
                param($RuleStatus, $Expected)
                $fixtureRuleStatus = $RuleStatus
                Mock Invoke-AzRestMethodWithRetry {
                    $items = if ($Path -like '/subscriptions/11111111-*/providers/Microsoft.CostManagement/scheduledActions*') {
                        @(@{ name = 'fixture-rule'; kind = 'InsightAlert'; properties = @{ status = $fixtureRuleStatus; scope = '/subscriptions/11111111-1111-1111-1111-111111111111'; displayName = 'Fixture rule' } })
                    }
                    else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items) } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-AnomalyAlerts -Subscriptions @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'B' }
                )

                @($result.ConfiguredRules).Count | Should -Be 1
                $result.ConfiguredRuleCount | Should -Be $Expected
                (Get-KpiComputedValue -KpiId 'anomaly-detection-rate' -Data $result).Value | Should -Be $Expected
            }
        }
    }

    Context 'Recommendation source contracts' {
        It 'Falls back from <Shape> ARG data and reports REST status <Status> honestly' -ForEach @(
            @{ Shape = 'null'; Status = 503; Incomplete = $true; Denied = $false }
            @{ Shape = 'missing Data'; Status = 403; Incomplete = $true; Denied = $true }
            @{ Shape = 'null Data'; Status = 401; Incomplete = $true; Denied = $true }
            @{ Shape = 'null'; Status = 408; Incomplete = $true; Denied = $false }
            @{ Shape = 'null'; Status = 200; Incomplete = $false; Denied = $false }
            @{ Shape = 'missing Data'; Status = 204; Incomplete = $false; Denied = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Shape = $Shape; Status = $Status; Incomplete = $Incomplete; Denied = $Denied } {
                param($Shape, $Status, $Incomplete, $Denied)
                $fixtureShape = $Shape
                $fixtureStatus = $Status
                Mock Search-AzGraphSafe {
                    switch ($fixtureShape) {
                        'null' { return $null }
                        'missing Data' { return @{ Count = 0 } }
                        'null Data' { return @{ Data = $null } }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $code = if ($fixtureStatus -eq 204 -and $Path -match 'Microsoft.Advisor') { 200 } else { $fixtureStatus }
                    [pscustomobject]@{ StatusCode = $code; Content = $(if ($code -eq 200) { '{"value":[]}' } else { '' }) }
                }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue

                $result.CoverageIncomplete | Should -Be $Incomplete
                $result.AccessDenied | Should -Be $Denied
                $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
                $result.TotalAdvisorCount | Should -Be 0
                $result.TotalReservationCount | Should -Be 0
                if ($Incomplete) {
                    $result.ReadErrors.Count | Should -BeGreaterThan 0
                    $result.Note | Should -Match 'incomplete'
                }
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter { $All -and $Query -match 'project id, subscriptionId' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -match 'Microsoft.Advisor' }
            }
        }

        It 'Treats <Payload> as incomplete rather than empty recommendation data' -ForEach @(
            @{ Payload = 'no response'; Content = $null }
            @{ Payload = 'invalid JSON'; Content = 'not JSON' }
            @{ Payload = 'missing list'; Content = '{}' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Content = $Content } {
                param($Content)
                $fixtureContent = $Content
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($null -eq $fixtureContent) { return $null }
                    [pscustomobject]@{ StatusCode = 200; Content = $fixtureContent }
                }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue
                $result.CoverageIncomplete | Should -BeTrue
                $result.AccessDenied | Should -BeFalse
                $result.ReadErrors.Count | Should -Be 15
            }
        }

        It 'Follows Advisor and Consumption continuation pages without publishing a failed chain (<FailContinuation>)' -ForEach @(
            @{ FailContinuation = $false }
            @{ FailContinuation = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ FailContinuation = $FailContinuation } {
                param($FailContinuation)
                $fixtureFailure = $FailContinuation
                $fixtureFamilies = [Collections.Generic.HashSet[string]]::new()
                Mock Search-AzGraphSafe { throw 'Use the REST fallback.' }
                Mock Invoke-AzRestMethodWithRetry {
                    $isAdvisor = $Path -match 'Microsoft.Advisor'
                    $isVM = [uri]::UnescapeDataString($Path) -match "resourceType eq 'VirtualMachines'"
                    $isNext = $Path -match '/fixture-next/'
                    if (-not $isAdvisor -and -not $isNext) {
                        $family = [regex]::Match([uri]::UnescapeDataString($Path), "properties/resourceType eq '([^']+)'").Groups[1].Value
                        $null = $fixtureFamilies.Add($family)
                    }
                    if ($isNext -and $fixtureFailure) { return [pscustomobject]@{ StatusCode = 503; Content = '' } }
                    $number = if ($isNext) { 2 } else { 1 }
                    $item = if ($isAdvisor) {
                        @{ name = "advisor-$number"; properties = @{
                                impactedField = 'Microsoft.Compute/virtualMachines'; impactedValue = "vm-$number"
                                resourceMetadata = @{ resourceId = "/subscriptions/fixture/resourceGroups/fixture/providers/Microsoft.Compute/virtualMachines/vm-$number" }
                                recommendationTypeId = 'purchase'
                                shortDescription = @{ problem = 'Reserve instances'; solution = 'Buy reservations' }
                                extendedProperties = @{ annualSavingsAmount = 100; savingsCurrency = 'USD'; term = 'P1Y' }
                            } }
                    }
                    else {
                        @{ name = "purchase-$number"; location = 'eastus'; sku = "VM-$number"; properties = @{ netSavings = 10; term = 'P1Y'; lookBackPeriod = 'Last30Days' } }
                    }
                    $items = if ($isAdvisor -or $isVM -or $isNext) { @($item) } else { @() }
                    $payload = @{ value = @($items | Where-Object { $_ }) }
                    if (-not $isNext -and ($isAdvisor -or $isVM)) {
                        $provider = if ($isAdvisor) { 'Microsoft.Advisor' } else { 'Microsoft.Consumption' }
                        $payload.nextLink = "/fixture-next/$provider"
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = ($payload | ConvertTo-Json -Depth 10) }
                }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue
                $result.CoverageIncomplete | Should -Be $FailContinuation
                if ($FailContinuation) {
                    $result.TotalAdvisorCount | Should -Be 0
                    $result.TotalReservationCount | Should -Be 0
                    $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
                    $result.ReadErrors.Count | Should -Be 2
                }
                else {
                    $result.TotalAdvisorCount | Should -Be 2
                    $result.TotalReservationCount | Should -Be 2
                    $result.EstimatedAnnualSavings | Should -Be 200
                    @($result.AdvisorRecommendations.ResourceName) | Should -Be @('vm-1', 'vm-2')
                    @($result.ReservationRecommendations.SKU) | Should -Be @('VM-1', 'VM-2')
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Path -like '/fixture-next/*' -and $Method -eq 'GET' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 15 -Exactly -ParameterFilter {
                    $Path -like '/subscriptions/fixture/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01&$filter=*' -and
                    $Path -notmatch '\s' -and $Method -eq 'GET' -and
                    [uri]::UnescapeDataString($Path) -match "properties/scope eq 'Single' and properties/resourceType eq '[A-Za-z]+' and properties/lookBackPeriod eq 'Last30Days'"
                }
                @($fixtureFamilies | Sort-Object) | Should -Be @(
                    'VirtualMachines', 'SQLDatabases', 'PostgreSQL', 'ManagedDisk', 'MySQL',
                    'RedHat', 'MariaDB', 'RedisCache', 'CosmosDB', 'SqlDataWarehouse',
                    'SUSELinux', 'AppService', 'BlockBlob', 'AzureDataExplorer', 'VMwareCloudSimple'
                | Sort-Object)
            }
        }

        It 'Retains both valid Advisor records with the invalid record <Position>' -ForEach @(
            @{ Position = 'first' }
            @{ Position = 'middle' }
            @{ Position = 'last' }
            @{ Position = 'absent' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Position = $Position } {
                param($Position)
                $fixturePosition = $Position
                Mock Search-AzGraphSafe { throw 'Use the REST fallback.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -notmatch 'Microsoft.Advisor') { return [pscustomobject]@{ StatusCode = 204; Content = '' } }
                    $first = @{ name = 'first-valid'; savings = 100 }
                    $last = @{ name = 'last-valid'; savings = 200 }
                    $invalid = @{ name = 'invalid'; savings = 'not a number' }
                    $records = switch ($fixturePosition) {
                        'first' { @($invalid, $first, $last) }
                        'middle' { @($first, $invalid, $last) }
                        'last' { @($first, $last, $invalid) }
                        'absent' { @($first, $last) }
                    }
                    $items = @($records | ForEach-Object {
                            @{ name = $_.name; properties = @{
                                    impactedValue = $_.name; impactedField = 'Microsoft.Compute/virtualMachines'
                                    resourceMetadata = @{ resourceId = "/subscriptions/fixture/resourceGroups/a/providers/Microsoft.Compute/virtualMachines/$($_.name)" }
                                    recommendationTypeId = 'purchase'
                                    shortDescription = @{ problem = 'Purchase reservations' }
                                    extendedProperties = @{ annualSavingsAmount = $_.savings; savingsCurrency = 'USD'; term = 'P1Y' }
                                } }
                        })
                    [pscustomobject]@{ StatusCode = 200; Content = (ConvertTo-Json -InputObject @{ value = $items } -Depth 10) }
                }
                $warnings = @()
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue -WarningVariable warnings

                $result.TotalAdvisorCount | Should -Be 2
                @($result.AdvisorRecommendations.ResourceName) | Should -Be @('first-valid', 'last-valid')
                @($result.AdvisorRecommendations.AnnualSavings) | Should -Be @(100, 200)
                $result.AccessDenied | Should -BeFalse
                if ($Position -eq 'absent') {
                    $result.CoverageIncomplete | Should -BeFalse
                    $result.ReadErrors.Count | Should -Be 0
                    $result.EstimatedAnnualSavings | Should -Be 300
                }
                else {
                    $result.CoverageIncomplete | Should -BeTrue
                    $result.ReadErrors.Count | Should -Be 1
                    $result.ReadErrors[0] | Should -Match 'Advisor / Fixture / invalid'
                    $result.Note | Should -Match 'invalid'
                    ($warnings -join "`n") | Should -Match 'Advisor / Fixture / invalid'
                    $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
                    $result.CostIssue | Should -Match 'incomplete'
                }
            }
        }

        It 'Retains successful subscriptions without hiding denied reads or publishing a partial total' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { throw 'Use the REST fallback.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -match '/subscriptions/denied/') { return [pscustomobject]@{ StatusCode = 403; Content = '' } }
                    $items = if ($Path -match 'Microsoft.Advisor') {
                        @(@{ name = 'one'; properties = @{ impactedValue = 'vm'; shortDescription = @{ problem = 'Buy reservations' }; extendedProperties = @{ annualSavingsAmount = 100; savingsCurrency = 'USD' } } })
                    } else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items | Where-Object { $_ }) } | ConvertTo-Json -Depth 8) }
                }
                $result = Get-ReservationAdvice -Subscriptions @(
                    [pscustomobject]@{ Id = 'good'; Name = 'Readable' }
                    [pscustomobject]@{ Id = 'denied'; Name = 'Denied' }
                ) -WarningAction SilentlyContinue
                $result.TotalAdvisorCount | Should -Be 1
                $result.AdvisorRecommendations[0].AnnualSavings | Should -Be 100
                $result.AccessDenied | Should -BeTrue
                $result.CoverageIncomplete | Should -BeTrue
                $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
                $result.Note | Should -Match 'Denied'
                $result.CostIssue | Should -Match 'incomplete'
            }
        }

        It 'Keeps modern Money and legacy scalar amounts with their own currencies, locations, and periods' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    $items = if ([uri]::UnescapeDataString($Path) -match "resourceType eq 'VirtualMachines'") {
                        @(
                            @{ name = 'modern'; kind = 'modern'; properties = @{
                                    skuName = 'ModernVM'; location = 'westus2'; term = 'P3Y'; lookBackPeriod = 60
                                    costWithNoReservedInstances = @{ currency = 'USD'; value = 100.125 }
                                    totalCostWithReservedInstances = @{ currency = 'EUR'; value = 50 }
                                    netSavings = @{ currency = 'USD'; value = 0 }
                                } }
                            @{ name = 'legacy'; location = 'eastus'; sku = 'LegacyVM'; properties = @{
                                    term = 'P1Y'; lookBackPeriod = 'Last30Days'
                                    costWithNoReservedInstances = 100.125; totalCostWithReservedInstances = 50; netSavings = 50.125
                                } }
                        )
                    } else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items | Where-Object { $_ }) } | ConvertTo-Json -Depth 10) }
                }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' })
                $result.CoverageIncomplete | Should -BeFalse
                $result.TotalReservationCount | Should -Be 2
                $modern, $legacy = $result.ReservationRecommendations
                $modern.NetSavings | Should -Be 0
                $modern.Currency | Should -Be 'USD'
                $modern.CostWithoutRICurrency | Should -Be 'USD'
                $modern.CostWithRICurrency | Should -Be 'EUR'
                $modern.CostWithoutRI | Should -Be 100.12
                $modern.Region | Should -Be 'westus2'
                $modern.LookBackPeriod | Should -Be 60
                $modern.Term | Should -Be 'P3Y'
                $legacy.NetSavings | Should -Be 50.12
                $legacy.Currency | Should -Be 'Unknown'
                $legacy.Region | Should -Be 'eastus'
                $legacy.SKU | Should -Be 'LegacyVM'
                $legacy.CostPeriod | Should -Match 'not an annual'
                $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
            }
        }

        It 'Retains valid rows after an invalid Money record and reports the data error' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    $items = if ([uri]::UnescapeDataString($Path) -match "resourceType eq 'VirtualMachines'") {
                        @(
                            @{ name = 'invalid'; properties = @{ netSavings = @{ value = 'not a number'; currency = 'USD' } } }
                            @{ name = 'valid'; properties = @{ netSavings = @{ value = 10; currency = 'USD' } } }
                        )
                    } else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items | Where-Object { $_ }) } | ConvertTo-Json -Depth 8) }
                }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue
                $result.TotalReservationCount | Should -Be 1
                $result.ReservationRecommendations[0].NetSavings | Should -Be 10
                $result.CoverageIncomplete | Should -BeTrue
                $result.Note | Should -Match 'invalid'
            }
        }

        It 'Preserves <Difference> while collapsing only duplicate generation records' -ForEach @(
            @{ Difference = 'independent targets'; ExpectedCount = 2; Total = 200 }
            @{ Difference = 'recommendation types'; ExpectedCount = 2; Total = $null }
            @{ Difference = 'purchase options'; ExpectedCount = 2; Total = $null }
            @{ Difference = 'alternative terms'; ExpectedCount = 2; Total = $null }
            @{ Difference = 'overlapping savings plans'; ExpectedCount = 2; Total = $null }
            @{ Difference = 'duplicate generations'; ExpectedCount = 1; Total = 100 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Difference = $Difference; ExpectedCount = $ExpectedCount; Total = $Total } {
                param($Difference, $ExpectedCount, $Total)
                $first = [pscustomobject]@{
                    subscriptionId = 'fixture'; recName = 'generation-1'; assessedResourceId = '/subscriptions/fixture/resourceGroups/a/providers/Microsoft.Compute/virtualMachines/same-name'
                    impactedValue = 'same-name'; impactedField = 'Microsoft.Compute/virtualMachines'; recommendationTypeId = 'purchase'
                    shortDescriptionProblem = 'Buy reserved instances'; shortDescriptionSolution = 'Purchase reservations'
                    annualSavings = 100; savingsCurrency = 'USD'; term = 'P1Y'; options = @{ scope = 'Single'; commitment = 'one' }
                }
                $second = $first.PSObject.Copy()
                $second.recName = 'generation-2'
                switch ($Difference) {
                    'independent targets' { $second.assessedResourceId = '/subscriptions/fixture/resourceGroups/b/providers/Microsoft.Compute/virtualMachines/same-name' }
                    'recommendation types' { $second.recommendationTypeId = 'renewal' }
                    'purchase options' { $second.options = @{ scope = 'Shared'; commitment = 'two' } }
                    'alternative terms' { $second.term = 'P3Y' }
                    'overlapping savings plans' { $second.shortDescriptionSolution = 'Purchase a savings plan'; $second.assessedResourceId = '/subscriptions/fixture' }
                }
                $fixtureRows = @($first, $second)
                Mock Search-AzGraphSafe { @{ Data = $fixtureRows } }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 204; Content = '' } }
                $result = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' })
                $result.TotalAdvisorCount | Should -Be $ExpectedCount
                $result.EstimatedAnnualSavings | Should -Be $Total
                $result.CoverageIncomplete | Should -BeFalse
                if ($null -eq $Total) { $result.CostIssue | Should -Match 'not additive' }
                if ($ExpectedCount -eq 1) { $result.AdvisorRecommendations[0].DuplicateCount | Should -Be 2 }
            }
        }

        It 'Excludes solution-only commitment advice from optimization in <Source> results' -ForEach @(
            @{ Source = 'ARG' }
            @{ Source = 'REST' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source } {
                param($Source)
                $fixtureSource = $Source
                Mock Search-AzGraphSafe {
                    if ($fixtureSource -eq 'REST') { throw 'Use REST.' }
                    @{ Data = @(
                            [pscustomobject]@{ subscriptionId = 'fixture'; impactedValue = 'commitment'; shortDescriptionProblem = 'Reduce compute costs'; shortDescriptionSolution = 'Purchase a savings plan'; annualSavings = 100; savingsCurrency = 'USD' }
                            [pscustomobject]@{ subscriptionId = 'fixture'; impactedValue = 'resize'; shortDescriptionProblem = 'Reduce compute costs'; shortDescriptionSolution = 'Resize the virtual machine'; annualSavings = 50; savingsCurrency = 'USD' }
                        ) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $items = if ($Path -match 'Microsoft.Advisor') {
                        @(
                            @{ properties = @{ impactedValue = 'commitment'; shortDescription = @{ problem = 'Reduce compute costs'; solution = 'Purchase a savings plan' }; extendedProperties = @{ annualSavingsAmount = 100; savingsCurrency = 'USD' } } }
                            @{ properties = @{ impactedValue = 'resize'; shortDescription = @{ problem = 'Reduce compute costs'; solution = 'Resize the virtual machine' }; extendedProperties = @{ annualSavingsAmount = 50; savingsCurrency = 'USD' } } }
                        )
                    } else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items | Where-Object { $_ }) } | ConvertTo-Json -Depth 8) }
                }
                $result = Get-OptimizationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) -WarningAction SilentlyContinue
                $result.TotalCount | Should -Be 1
                $result.Recommendations[0].ResourceName | Should -Be 'resize'
                $result.EstimatedAnnualSavings | Should -Be 50
            }
        }

        It 'Requests only provisioned vCore SQL AHB candidates and labels entitlement as unverified' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    if ($Query -match "type == 'microsoft.sql/servers/databases'") {
                        return @{ Data = @([pscustomobject]@{ name = 'provisioned'; sku = 'GeneralPurpose / GP_Gen5_2' }) }
                    }
                    @{ Data = @() }
                }
                $result = Get-AHBOpportunities -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' })
                $result.SQLDatabases[0].name | Should -Be 'provisioned'
                $result.TotalOpportunities | Should -Be 1
                $result.Note | Should -Match 'Verify qualifying licenses'
                $result.Summary | Should -Not -Match 'eligible'
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter {
                    $All -and $Query -match "sku.tier in~ \('GeneralPurpose', 'BusinessCritical', 'Hyperscale'\)" -and
                    $Query -match "not\(sku.name matches regex '\(\?i\)\^\(GP\|BC\|HS\)_S_'\)" -and
                    $Query -match "isempty\(properties.computeModel\) or properties.computeModel !~ 'Serverless'" -and
                    $Query -match "isempty\(kind\) or kind !has 'serverless'" -and
                    $Query -match "properties.licenseType !~ 'BasePrice'" -and
                    $Query -match "name !endswith '/master'"
                }
            }
        }

        It 'Does not treat an unreadable AHB inventory as no opportunities' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { $null }
                { Get-AHBOpportunities -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' }) } |
                    Should -Throw '*inventory is incomplete*'
            }
        }
    }

    Context 'Report and runner consumers' {
        BeforeAll {
            $launcher = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
            $script:LauncherFunctions = @(([System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$null)).FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Invoke-SelectedScans', 'Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile',
                            'Show-ResultsSummary', 'Show-PermissionReadout', 'Show-Banner', 'Write-SectionHeader', 'Write-ColorizedLine', 'Write-FinOpsConsole', 'Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
                    }, $true) | ForEach-Object { $_.Extent.Text })
        }

        It 'Reports incomplete Advisor coverage instead of a healthy environment' {
            InModuleScope FinOpsMultitool -Parameters @{ Functions = $script:LauncherFunctions; ReportRoot = (Join-Path $TestDrive 'advisor-coverage') } {
                param($Functions, $ReportRoot)
                foreach ($definition in $Functions) { . ([scriptblock]::Create($definition)) }
                $results = @{ 'Get-OptimizationAdvice' = [pscustomobject]@{ Recommendations = @(); TotalCount = 0; EstimatedAnnualSavings = $null; Currency = $null; CostIssue = $null; CoverageIncomplete = $true; ReadErrors = @('A: 403'); Note = 'Advisor recommendations are incomplete. A: 403' } }
                $modules = @(@{ Fn = 'Get-OptimizationAdvice'; Name = 'Optimization Advice'; Selected = $true; Category = 'Advisor' })

                $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $ReportRoot -ErrorAction Stop

                $run = @(Get-ChildItem -LiteralPath $ReportRoot -Directory)[0].FullName
                $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
                $html | Should -Match 'Advisor recommendations are incomplete'
                $html | Should -Not -Match 'well optimized'
            }
        }

        It 'Preserves recommendation evidence and diagnostics in HTML, CSV, text, raw, and console (<Scenario>)' -ForEach @(
            @{ Scenario = 'purchase only'; Purchase = $true; Incomplete = $false }
            @{ Scenario = 'partial purchase'; Purchase = $true; Incomplete = $true }
            @{ Scenario = 'all failed'; Purchase = $false; Incomplete = $true }
            @{ Scenario = 'complete empty'; Purchase = $false; Incomplete = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{
                Functions = $script:LauncherFunctions; ReportRoot = (Join-Path $TestDrive $Scenario)
                Purchase = $Purchase; Incomplete = $Incomplete
            } {
                param($Functions, $ReportRoot, $Purchase, $Incomplete)
                foreach ($definition in $Functions) { . ([scriptblock]::Create($definition)) }
                $fixturePurchase = $Purchase
                $fixtureIncomplete = $Incomplete
                $fixtureConsole = [Collections.Generic.List[string]]::new()
                Mock Write-FinOpsConsole { $fixtureConsole.Add([string]$Object) }
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($fixtureIncomplete -and [uri]::UnescapeDataString($Path) -match "resourceType eq 'SQLDatabases'") {
                        return [pscustomobject]@{ StatusCode = 403; Content = '' }
                    }
                    $items = if ($fixturePurchase -and [uri]::UnescapeDataString($Path) -match "resourceType eq 'VirtualMachines'") {
                        @(@{ name = 'modern'; properties = @{
                                    skuName = 'FixtureVM'; location = 'westus2'; term = 'P3Y'; lookBackPeriod = 60
                                    costWithNoReservedInstances = @{ currency = 'USD'; value = 100 }
                                    totalCostWithReservedInstances = @{ currency = 'EUR'; value = 40 }
                                    netSavings = @{ currency = 'USD'; value = 60 }
                                } })
                    } else { @() }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($items | Where-Object { $_ }) } | ConvertTo-Json -Depth 10) }
                }
                $advice = Get-ReservationAdvice -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture subscription' }) -WarningAction SilentlyContinue
                $results = @{ 'Get-ReservationAdvice' = $advice }
                $modules = @(@{ Fn = 'Get-ReservationAdvice'; Name = 'Reservation Advice'; Selected = $true; Category = 'Commitments' })
                $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $ReportRoot -ErrorAction Stop

                $run = @(Get-ChildItem -LiteralPath $ReportRoot -Directory)[0].FullName
                $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
                $text = Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw
                $csv = @(Import-Csv -LiteralPath (Join-Path $run 'Get-ReservationAdvice.csv'))
                $console = $fixtureConsole -join "`n"
                $console | Should -Not -Match 'Total findings|\d+ findings'
                $text | Should -Not -Match 'Total findings|\d+ findings'
                $html | Should -Not -Match 'coverage appears sufficient'
                $console | Should -Not -Match 'coverage appears sufficient'
                ($advice | ConvertTo-Json -Depth 15 | ConvertFrom-Json).CoverageIncomplete | Should -Be $Incomplete
                if ($Incomplete) {
                    $html | Should -Match '>Limited data</td>'
                    $html | Should -Match 'Recommendation coverage is incomplete'
                    $text | Should -Match 'Limited data'
                    $console | Should -Match 'incomplete'
                    @($csv | Where-Object { $_.'Summary.CoverageIncomplete' -eq 'True' }).Count | Should -Be $csv.Count
                }
                else {
                    $text | Should -Not -Match 'Limited data'
                }
                if ($Purchase) {
                    $row = @($csv | Where-Object RecordType -EQ 'ReservationRecommendations')[0]
                    $row.NetSavings | Should -Be '60'
                    $row.Currency | Should -Be 'USD'
                    $row.CostWithRICurrency | Should -Be 'EUR'
                    $row.Term | Should -Be 'P3Y'
                    $row.LookBackPeriod | Should -Be '60'
                    $row.CostPeriod | Should -Match 'not an annual'
                    $html | Should -Match '0 Advisor and 1 reservation purchase'
                    $html | Should -Match 'USD 60.00'
                    $html | Should -Match 'EUR 40.00'
                    $html | Should -Match 'not annual savings'
                    $console | Should -Match 'FixtureVM'
                    $console | Should -Match 'Consumption'
                    $console | Should -Match 'USD 60.00'
                    $advice.ReservationRecommendations[0].NetSavings | Should -Be 60
                }
                else { $html | Should -Match 'No recommendation rows were returned' }
                @(Get-KpiInsightsForResult -FunctionName 'Get-ReservationAdvice' -Output $advice | Where-Object status -EQ 'computed').Count | Should -Be 0
            }
        }

        It 'Renders assessed-resource identity from <Source> for same-named targets (different groups: <DifferentGroups>)' -ForEach @(
            @{ Source = 'ARG'; DifferentGroups = $true }
            @{ Source = 'ARG'; DifferentGroups = $false }
            @{ Source = 'REST'; DifferentGroups = $true }
            @{ Source = 'REST'; DifferentGroups = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{
                Functions = $script:LauncherFunctions; ReportRoot = (Join-Path $TestDrive "identity-$Source-$DifferentGroups")
                Source = $Source; DifferentGroups = $DifferentGroups
            } {
                param($Functions, $ReportRoot, $Source, $DifferentGroups)
                foreach ($definition in $Functions) { . ([scriptblock]::Create($definition)) }
                $fixtureSource = $Source
                $firstId = '/subscriptions/fixture/resourceGroups/alpha/providers/Microsoft.Sql/servers/server/databases/same-name'
                $secondId = if ($DifferentGroups) { $firstId.Replace('/alpha/', '/beta/') } else { $firstId }
                $generation = 0
                $fixtureRows = @(
                    foreach ($target in @($firstId, $secondId)) {
                        $generation++
                        $recommendationId = "$target/providers/Microsoft.Advisor/recommendations/generation-$generation"
                        [pscustomobject]@{
                            subscriptionId = 'fixture'; recName = "generation-$generation"; assessedResourceId = $target
                            id = $recommendationId; ResourceId = $recommendationId
                            impactedValue = 'same-name'; impactedField = 'Microsoft.Sql/servers/databases'; recommendationTypeId = 'purchase'
                            shortDescriptionProblem = 'Buy reserved instances'; shortDescriptionSolution = 'Purchase reservations'
                            annualSavings = 100; savingsCurrency = 'USD'; term = 'P1Y'
                            options = @{ annualSavingsAmount = 100; savingsCurrency = 'USD'; term = 'P1Y' }
                        }
                    }
                )
                $fixtureConsole = [Collections.Generic.List[string]]::new()
                Mock Write-FinOpsConsole { $fixtureConsole.Add([string]$Object) }
                Mock Search-AzGraphSafe {
                    if ($fixtureSource -eq 'REST') { throw 'Use the REST fallback.' }
                    @{ Data = $fixtureRows }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -notmatch 'Microsoft.Advisor') { return [pscustomobject]@{ StatusCode = 204; Content = '' } }
                    $items = @($fixtureRows | ForEach-Object {
                            @{ name = $_.recName; properties = @{
                                    impactedValue = $_.impactedValue; impactedField = $_.impactedField
                                    resourceMetadata = @{ resourceId = $_.assessedResourceId }; recommendationTypeId = $_.recommendationTypeId
                                    shortDescription = @{ problem = $_.shortDescriptionProblem; solution = $_.shortDescriptionSolution }
                                    extendedProperties = $_.options
                                } }
                        })
                    [pscustomobject]@{ StatusCode = 200; Content = (ConvertTo-Json -InputObject @{ value = $items } -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture subscription' })
                $advice = Get-ReservationAdvice -Subscriptions $subscriptions -WarningAction SilentlyContinue
                $expectedCount = if ($DifferentGroups) { 2 } else { 1 }
                $advice.TotalAdvisorCount | Should -Be $expectedCount
                $advice.AdvisorRecommendations[0].ResourceId | Should -Be $firstId
                $advice.AdvisorRecommendations[0].RecommendationId | Should -Be 'generation-1'
                @($advice.AdvisorRecommendations.ResourceId | Where-Object { $_ -match '/providers/Microsoft.Advisor/recommendations/' }).Count | Should -Be 0
                $advice.EstimatedAnnualSavings | Should -Be (100 * $expectedCount)
                $advice.CoverageIncomplete | Should -BeFalse
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter {
                    $Query -match 'assessedResourceId\s*=\s*tostring\(properties.resourceMetadata.resourceId\)'
                }
                $modules = @(@{ Fn = 'Get-ReservationAdvice'; Name = 'Reservation Advice'; Selected = $true; Category = 'Commitments' })
                $null = Show-ResultsSummary -Results @{ 'Get-ReservationAdvice' = $advice } -Modules $modules -ExportPath $ReportRoot -Subscriptions $subscriptions -ErrorAction Stop

                $run = @(Get-ChildItem -LiteralPath $ReportRoot -Directory)[0].FullName
                $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
                $advisorTable = [regex]::Match($html, '(?s)<table[^>]+id="table-Get-ReservationAdvice".*?</table>').Value
                $advisorTable | Should -Not -BeNullOrEmpty
                [regex]::Matches($advisorTable, '<tr>').Count | Should -Be ($expectedCount + 1)
                [regex]::Matches($advisorTable, '<summary>Resource ID</summary>').Count | Should -Be $expectedCount
                $advisorTable | Should -Match ([regex]::Escape($firstId))
                $console = $fixtureConsole -join "`n"
                $console | Should -Match ([regex]::Escape($firstId))
                $csv = @(Import-Csv -LiteralPath (Join-Path $run 'Get-ReservationAdvice.csv') | Where-Object RecordType -EQ 'AdvisorRecommendations')
                $csv.Count | Should -Be $expectedCount
                if ($DifferentGroups) {
                    $advisorTable | Should -Match ([regex]::Escape($secondId))
                    $console | Should -Match ([regex]::Escape($secondId))
                    @($csv.ResourceId) | Should -Be @($firstId, $secondId)
                }
                else {
                    $advisorTable | Should -Not -Match '/resourceGroups/beta/'
                    $console | Should -Not -Match '/resourceGroups/beta/'
                    $advice.AdvisorRecommendations[0].DuplicateCount | Should -Be 2
                }
            }
        }

        It 'Passes verified cost data to the resource cost scan' {
            InModuleScope FinOpsMultitool -Parameters @{ Functions = $script:LauncherFunctions } {
                param($Functions)
                foreach ($definition in $Functions) { . ([scriptblock]::Create($definition)) }
                Mock Get-CostData { @{ '11111111-1111-1111-1111-111111111111' = @{ Actual = 100; Forecast = 100; ForecastSource = 'Forecast'; Currency = 'USD' } } }
                Mock Get-ResourceCosts { @() }
                $modules = @(
                    [pscustomobject]@{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true }
                    [pscustomobject]@{ Name = 'Resource Costs'; Fn = 'Get-ResourceCosts'; Selected = $true }
                )

                $null = Invoke-SelectedScans -Modules $modules -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'A' }) -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource @{ Source = 'API' }

                Should -Invoke Get-ResourceCosts -Times 1 -Exactly -ParameterFilter { $CostData -is [hashtable] -and $CostData['11111111-1111-1111-1111-111111111111'].ForecastSource -eq 'Forecast' }
            }
        }
    }
}
