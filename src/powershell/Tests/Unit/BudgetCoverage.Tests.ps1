# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Budget coverage reporting' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        $script:SubA = '00000000-0000-0000-0000-00000000000a'
        $script:SubB = '00000000-0000-0000-0000-00000000000b'
        $script:TwoSubs = @(
            [PSCustomObject]@{ Id = $script:SubA; Name = 'Sub A' }
            [PSCustomObject]@{ Id = $script:SubB; Name = 'Sub B' }
        )

        $script:OneBudget = @{
            value = @(
                @{ name = 'monthly-budget'; properties = @{ amount = 100; timeGrain = 'Monthly'; category = 'Cost' } }
            )
        } | ConvertTo-Json -Depth 8

        $script:NoBudgets = '{"value":[]}'
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Does not count an unreadable subscription as having no budget' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match $script:SubA) { [PSCustomObject]@{ StatusCode = 200; Content = $script:OneBudget } }
            else { [PSCustomObject]@{ StatusCode = 403; Content = '{}' } }
        }

        $r = Get-BudgetStatus -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        $r.SubsWithBudget | Should -Be 1
        # The denied subscription is unknown, not budget-free.
        $r.SubsWithoutBudget | Should -Be 0
        $r.UnreadableSubs | Should -Be 1
        $r.CoverageIncomplete | Should -BeTrue
        $r.ScannedSubs | Should -Be 1
        $r.TotalSubs | Should -Be 2
    }

    It 'Suppresses the coverage percentage when a subscription could not be read' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match $script:SubA) { [PSCustomObject]@{ StatusCode = 200; Content = $script:OneBudget } }
            else { [PSCustomObject]@{ StatusCode = 500; Content = '{}' } }
        }

        $r = Get-BudgetStatus -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # 1 of 2 would read as 50% measured coverage, which was never measured.
        $r.BudgetCoverage | Should -BeNullOrEmpty
        $r.Note | Should -Match 'could not be queried'
    }

    It 'Treats a thrown query as unreadable rather than budget-free' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match $script:SubA) { [PSCustomObject]@{ StatusCode = 200; Content = $script:OneBudget } }
            else { throw 'network blew up' }
        }

        $r = Get-BudgetStatus -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        $r.UnreadableSubs | Should -Be 1
        $r.SubsWithoutBudget | Should -Be 0
        $r.CoverageIncomplete | Should -BeTrue
    }

    It 'Reports measured coverage when every subscription answered' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match $script:SubA) { [PSCustomObject]@{ StatusCode = 200; Content = $script:OneBudget } }
            else { [PSCustomObject]@{ StatusCode = 200; Content = $script:NoBudgets } }
        }

        $r = Get-BudgetStatus -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # An empty 200 is a real answer: that subscription has no budget.
        $r.SubsWithBudget | Should -Be 1
        $r.SubsWithoutBudget | Should -Be 1
        $r.UnreadableSubs | Should -Be 0
        $r.CoverageIncomplete | Should -BeFalse
        $r.BudgetCoverage | Should -Be 50
        $r.Note | Should -BeNullOrEmpty
    }

    Context 'Budget history month coverage' {

        BeforeAll {
            $script:HistBudget = @(
                [PSCustomObject]@{
                    SubscriptionId = $script:SubA
                    Subscription   = 'Sub A'
                    BudgetName     = 'monthly-budget'
                    Amount         = 100
                    TimeGrain      = 'Monthly'
                }
            )

            $script:Trend2 = [PSCustomObject]@{
                BySubscription = @{ $script:SubA = @(2, 1 | ForEach-Object {
                            [PSCustomObject]@{ MonthDate = (Get-Date).AddMonths(-$_); Cost = 10 }
                        })
                }
            }

            $script:Trend6 = [PSCustomObject]@{
                BySubscription = @{ $script:SubA = @(6, 5, 4, 3, 2, 1 | ForEach-Object {
                            [PSCustomObject]@{ MonthDate = (Get-Date).AddMonths(-$_); Cost = 10 }
                        })
                }
            }
        }

        It 'Queries live cost when cached trend is shorter than the requested window' {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                [PSCustomObject]@{ StatusCode = 403; Content = '{}' }
            }

            { Get-BudgetHistory -Budgets $script:HistBudget -MonthsBack 6 -CostTrend $script:Trend2 -WarningAction SilentlyContinue } |
                Should -Throw '*403*incomplete*'

            # Without the coverage check the four uncovered months would be
            # reported as zero spend and therefore as being under budget.
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly
        }

        It 'Reuses cached trend when it covers the requested window' {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                [PSCustomObject]@{ StatusCode = 403; Content = '{}' }
            }

            $rows = Get-BudgetHistory -Budgets $script:HistBudget -MonthsBack 6 -CostTrend $script:Trend6 -WarningAction SilentlyContinue

            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            @($rows).Count | Should -Be 6
        }

        It 'Includes monthly spend from every page (continuation fails: <PageFails>)' -ForEach @(
            @{ PageFails = $false }
            @{ PageFails = $true }
        ) {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                $isNextPage = $Path -like '*page=2'
                if ($PageFails -and $isNextPage) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                $monthsAgo = if ($isNextPage) { -1 } else { -2 }
                $amount = if ($isNextPage) { 120.0 } else { 40.0 }
                $month = (Get-Date).AddMonths($monthsAgo).ToString('yyyyMM01')
                $properties = @{
                    columns = @(@{ name = 'Cost' }, @{ name = 'BillingMonth' }, @{ name = 'Currency' })
                    rows = @(, @($amount, $month, 'USD'))
                }
                if (-not $isNextPage) { $properties.nextLink = "$Path&page=2" }
                [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
            }

            if ($PageFails) {
                { Get-BudgetHistory -Budgets $script:HistBudget -MonthsBack 2 } | Should -Throw '*incomplete*'
            }
            else {
                $rows = @(Get-BudgetHistory -Budgets $script:HistBudget -MonthsBack 2)
                $rows.Count | Should -Be 2
                ($rows | Measure-Object -Property ActualSpend -Sum).Sum | Should -Be 160
                @($rows | Where-Object Status -EQ 'Over').Count | Should -Be 1
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
                $Path -like '*page=2' -and $Method -eq 'POST' -and ($Payload | ConvertFrom-Json).dataset.granularity -eq 'Monthly'
            }
        }
    }
}
