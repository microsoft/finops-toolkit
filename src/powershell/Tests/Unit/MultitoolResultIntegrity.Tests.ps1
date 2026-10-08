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
            @{ Scenario = 'an unrelated single account'; Owner = '99999999-9999-9999-9999-999999999999'; Confirmed = $false }
            @{ Scenario = 'the account that owns the subscription'; Owner = '11111111-1111-1111-1111-111111111111'; Confirmed = $true }
            @{ Scenario = 'unreadable membership'; Owner = $null; Confirmed = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Owner = $Owner; Confirmed = $Confirmed } {
                param($Owner, $Confirmed)
                $fixtureOwner = $Owner
                Mock Invoke-AzRestMethodWithRetry {
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
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '*/billingSubscriptions*' }
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
                            [pscustomobject](@{ recName = 'rec-a'; impactedValue = 'vm-a'; displaySKU = 'Standard_D2s_v5'; annualSavings = '100' } + $fixtureRecommendation)
                            [pscustomobject](@{ recName = 'rec-b'; impactedValue = 'vm-b'; displaySKU = 'Standard_D4s_v5'; annualSavings = 'not available' } + $fixtureRecommendation)
                        ) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -notlike '*/Microsoft.Advisor/recommendations*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    $items = foreach ($fixture in @(@('rec-a', 'vm-a', 'Standard_D2s_v5', '100'), @('rec-b', 'vm-b', 'Standard_D4s_v5', '50'))) {
                        @{ name = $fixture[0]; properties = @{ impact = 'High'; impactedField = 'Microsoft.Compute/virtualMachines'; impactedValue = $fixture[1]; shortDescription = @{ problem = 'Consider virtual machine reserved instances'; solution = 'Buy reserved instances' }; extendedProperties = @{ annualSavingsAmount = $fixture[3]; savingsCurrency = 'USD'; term = 'P1Y'; displaySKU = $fixture[2]; region = 'eastus'; displayQty = '1' } } }
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

    Context 'Report and runner consumers' {
        BeforeAll {
            $launcher = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
            $script:LauncherFunctions = @(([System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$null)).FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Invoke-SelectedScans', 'Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile',
                            'Show-ResultsSummary', 'Show-Banner', 'Write-SectionHeader', 'Write-ColorizedLine', 'Write-FinOpsConsole', 'Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
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
