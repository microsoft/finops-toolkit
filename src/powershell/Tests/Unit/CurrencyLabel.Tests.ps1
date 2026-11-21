# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Mixed currency detection' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Advisor savings totals' {
        It 'Keeps <Scan> evidence without combining <Case> currencies' -ForEach @(
            @{ Scan = 'Get-OptimizationAdvice'; Case = 'matching'; SecondCurrency = 'USD'; Comparable = $true }
            @{ Scan = 'Get-OptimizationAdvice'; Case = 'mixed'; SecondCurrency = 'EUR'; Comparable = $false }
            @{ Scan = 'Get-OptimizationAdvice'; Case = 'missing'; SecondCurrency = ''; Comparable = $false }
            @{ Scan = 'Get-ReservationAdvice'; Case = 'matching'; SecondCurrency = 'USD'; Comparable = $true }
            @{ Scan = 'Get-ReservationAdvice'; Case = 'mixed'; SecondCurrency = 'EUR'; Comparable = $false }
            @{ Scan = 'Get-ReservationAdvice'; Case = 'missing'; SecondCurrency = ''; Comparable = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scan = $Scan; SecondCurrency = $SecondCurrency; Comparable = $Comparable } {
                param($Scan, $SecondCurrency, $Comparable)
                $fixtureCurrency = $SecondCurrency
                Mock Search-AzGraphSafe {
                    @{ Data = @(
                        [pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; shortDescriptionProblem = 'Resize VM'; shortDescriptionSolution = 'Use a smaller VM'; impact = 'High'; impactedValue = 'first'; annualSavings = 100; savingsCurrency = 'USD' }
                        [pscustomobject]@{ subscriptionId = '22222222-2222-2222-2222-222222222222'; shortDescriptionProblem = 'Resize VM'; shortDescriptionSolution = 'Use a smaller VM'; impact = 'High'; impactedValue = 'second'; annualSavings = 50; savingsCurrency = $fixtureCurrency }
                    ) }
                }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                $result = & $Scan -Subscriptions $subscriptions

                $recommendations = if ($Scan -eq 'Get-OptimizationAdvice') { $result.Recommendations } else { $result.AdvisorRecommendations }
                @($recommendations).Count | Should -Be 2
                $recommendations[0].AnnualSavings | Should -Be 100
                if ($Comparable) {
                    $result.EstimatedAnnualSavings | Should -Be 150
                    $result.Currency | Should -Be 'USD'
                    if ($Scan -eq 'Get-OptimizationAdvice') { $result.ByCategory[0].TotalSavings | Should -Be 150 }
                }
                else {
                    $result.EstimatedAnnualSavings | Should -BeNullOrEmpty
                    if ($Scan -eq 'Get-OptimizationAdvice') { $result.ByCategory[0].TotalSavings | Should -BeNullOrEmpty }
                    $result.CostIssue | Should -Match 'currenc'
                    $result.Summary | Should -Not -Match '\$150|150.*savings'
                }
            }
        }
    }

    Context 'Resolve-CurrencyLabel' {
        It 'Falls back when nothing was recorded' {
            Resolve-CurrencyLabel -Seen @{} | Should -Be 'USD'
        }

        It 'Honors an explicit fallback' {
            Resolve-CurrencyLabel -Seen @{} -Fallback 'EUR' | Should -Be 'EUR'
        }

        It 'Reports the currency when only one was seen' {
            $seen = @{}
            Add-CurrencySeen -Seen $seen -Currency 'USD'
            Resolve-CurrencyLabel -Seen $seen | Should -Be 'USD'
        }

        It 'Reports Mixed when several were seen' {
            $seen = @{}
            Add-CurrencySeen -Seen $seen -Currency 'USD'
            Add-CurrencySeen -Seen $seen -Currency 'EUR'
            Resolve-CurrencyLabel -Seen $seen | Should -Be 'Mixed'
        }
    }

    Context 'Add-CurrencySeen' {
        It 'Treats casing and padding as the same currency' {
            $seen = @{}
            Add-CurrencySeen -Seen $seen -Currency 'usd'
            Add-CurrencySeen -Seen $seen -Currency 'USD'
            Add-CurrencySeen -Seen $seen -Currency ' Usd '
            @($seen.Keys).Count | Should -Be 1
            Test-CurrencyMixed -Seen $seen | Should -BeFalse
        }

        It 'Ignores a null or blank currency rather than counting it' {
            $seen = @{}
            Add-CurrencySeen -Seen $seen -Currency $null
            Add-CurrencySeen -Seen $seen -Currency ''
            Add-CurrencySeen -Seen $seen -Currency '   '
            @($seen.Keys).Count | Should -Be 0
        }
    }

    Context 'Test-CurrencyMixed' {
        It 'Is false for <Case>' -ForEach @(
            @{ Case = 'no currencies'; Currencies = @() }
            @{ Case = 'one currency'; Currencies = @('USD') }
            @{ Case = 'one currency repeated'; Currencies = @('USD', 'USD', 'usd') }
        ) {
            $seen = @{}
            foreach ($c in $Currencies) { Add-CurrencySeen -Seen $seen -Currency $c }
            Test-CurrencyMixed -Seen $seen | Should -BeFalse
        }

        It 'Is true when a tenant bills in more than one currency' {
            $seen = @{}
            foreach ($c in @('USD', 'EUR', 'GBP')) { Add-CurrencySeen -Seen $seen -Currency $c }
            Test-CurrencyMixed -Seen $seen | Should -BeTrue
            Resolve-CurrencyLabel -Seen $seen | Should -Be 'Mixed'
        }
    }
}
