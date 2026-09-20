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
                    Category       = 'Cost'
                    Currency       = 'USD'
                    Filter         = $null
                    TimePeriod     = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-2); endDate = (Get-Date).ToUniversalTime().Date.AddYears(2) }
                }
            )

            $script:Trend2 = [PSCustomObject]@{
                BySubscription = @{ $script:SubA = @(2, 1 | ForEach-Object {
                            [PSCustomObject]@{ MonthDate = (Get-Date).AddMonths(-$_); Cost = 10; Currency = 'USD' }
                        })
                }
            }

            $script:Trend6 = [PSCustomObject]@{
                BySubscription = @{ $script:SubA = @(6, 5, 4, 3, 2, 1 | ForEach-Object {
                            [PSCustomObject]@{ MonthDate = (Get-Date).AddMonths(-$_); Cost = 10; Currency = 'USD' }
                        })
                }
            }
        }

        It 'Calculates history when the budget API returns <FilterCase>' -ForEach @(
            @{ FilterCase = 'no filter property'; FilterJson = $null }
            @{ FilterCase = 'an empty filter object'; FilterJson = '{}' }
        ) {
            $properties = @{
                amount = 100; timeGrain = 'Monthly'; category = 'Cost'
                currentSpend = @{ amount = 10; unit = 'USD' }
                timePeriod = @{ startDate = '2020-01-01T00:00:00Z'; endDate = '2030-12-31T00:00:00Z' }
            }
            if ($null -ne $FilterJson) { $properties.filter = $FilterJson | ConvertFrom-Json }
            $apiResponse = @{ value = @(@{ name = 'monthly-budget'; properties = $properties }) } | ConvertTo-Json -Depth 10
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                if ($Method -ne 'GET' -or $Path -notlike '*Microsoft.Consumption/budgets*') { throw 'Cached unfiltered costs must not issue a cost query.' }
                [pscustomobject]@{ StatusCode = 200; Content = $apiResponse }
            }

            $inventory = Get-BudgetStatus -Subscriptions @($script:TwoSubs[0])
            $history = @(Get-BudgetHistory -Budgets $inventory.Budgets -MonthsBack 6 -CostTrend $script:Trend6)

            $history.Count | Should -Be 6
            foreach ($row in $history) {
                $row.ActualSpend | Should -Be 10
                $row.PctUsed | Should -Be 10
                $row.Status | Should -Be 'Under'
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly
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

        It 'Includes monthly spend from every page (continuation fails: <PageFails>, filtered: <HasFilter>)' -ForEach @(
            @{ PageFails = $false; HasFilter = $false }
            @{ PageFails = $true; HasFilter = $false }
            @{ PageFails = $false; HasFilter = $true }
            @{ PageFails = $true; HasFilter = $true }
        ) {
            $budget = $script:HistBudget[0] | Select-Object *
            if ($HasFilter) { $budget.Filter = @{ tags = @{ name = 'Environment'; operator = 'In'; values = @('Prod') } } }
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                $isNextPage = $Path -like '*page=2'
                if ($PageFails -and $isNextPage) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                $monthsAgo = if ($isNextPage) { -1 } else { -2 }
                $amount = if ($isNextPage) { 120.0 } else { 40.0 }
                $month = (Get-Date).AddMonths($monthsAgo).ToString('yyyyMM01')
                $properties = @{
                    columns = @(@{ name = 'Cost' }, @{ name = 'BillingMonth' }, @{ name = 'Currency' })
                    rows    = @(, @($amount, $month, 'USD'))
                }
                if (-not $isNextPage) { $properties.nextLink = "$Path&page=2" }
                [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
            }

            if ($PageFails) {
                { Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 } | Should -Throw '*incomplete*'
            }
            else {
                $rows = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2)
                $rows.Count | Should -Be 2
                ($rows | Measure-Object -Property ActualSpend -Sum).Sum | Should -Be 160
                @($rows | Where-Object Status -EQ 'Over').Count | Should -Be 1
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
                $dataset = ($Payload | ConvertFrom-Json).dataset
                $filterMatches = if ($HasFilter) { $dataset.filter.tags.name -eq 'Environment' -and $dataset.filter.tags.values[0] -ceq 'Prod' }
                else { $null -eq $dataset.filter }
                $Path -like '*page=2' -and $Method -eq 'POST' -and $dataset.granularity -eq 'Monthly' -and $filterMatches
            }
        }

        It 'Queries costs using the same <FilterCase> as the budget instead of unfiltered cached totals' -ForEach @(
            @{ FilterCase = 'tag filter'; FilterJson = '{"tags":{"name":"Environment","operator":"In","values":["Prod"]}}' }
            @{ FilterCase = 'dimension filter'; FilterJson = '{"dimensions":{"name":"ResourceGroupName","operator":"In","values":["analytics"]}}' }
            @{ FilterCase = 'combined filter'; FilterJson = '{"and":[{"tags":{"name":"Environment","operator":"In","values":["Prod"]}},{"dimensions":{"name":"ResourceGroupName","operator":"In","values":["analytics"]}}]}' }
        ) {
            $budget = $script:HistBudget[0] | Select-Object *
            $budget.Filter = $FilterJson | ConvertFrom-Json
            $capturedQueries = [Collections.Generic.List[object]]::new()
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                $capturedQueries.Add(($Payload | ConvertFrom-Json))
                $rows = @(2, 1 | ForEach-Object { , @(40.0, (Get-Date).AddMonths(-$_).ToString('yyyyMM01'), 'USD') })
                $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'BillingMonth' }, @{ name = 'Currency' }); rows = $rows }
                [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
            }

            $history = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6)

            $history.Count | Should -Be 2
            foreach ($row in $history) { $row.ActualSpend | Should -Be 40; $row.Status | Should -Be 'Under' }
            $capturedQueries.Count | Should -Be 1
            ($capturedQueries[0].dataset.filter | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $FilterJson
            $capturedQueries[0].type | Should -Be 'ActualCost'
            $capturedQueries[0].dataset.granularity | Should -Be 'Monthly'
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Path -like "/subscriptions/$($script:SubA)/providers/Microsoft.CostManagement/query*"
            }
        }

        It 'Caches history by exact filter without mixing distinct tag values or unfiltered totals' {
            $budgets = @(foreach ($name in @('Upper', 'Lower', 'Same filter', 'Unfiltered')) {
                    $budget = $script:HistBudget[0] | Select-Object *
                    $budget.BudgetName = $name
                    if ($name -ne 'Unfiltered') {
                        $budget.Filter = @{ tags = @{ name = 'Environment'; operator = 'In'; values = @($(if ($name -eq 'Lower') { 'prod' } else { 'Prod' })) } }
                    }
                    $budget
                })
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                $filter = ($Payload | ConvertFrom-Json).dataset.filter
                $amount = if ($filter.tags.values[0] -ceq 'Prod') { 40.0 } else { 60.0 }
                $properties = @{
                    columns = @(@{ name = 'Cost' }, @{ name = 'BillingMonth' }, @{ name = 'Currency' })
                    rows    = @(, @($amount, (Get-Date).AddMonths(-1).ToString('yyyyMM01'), 'USD'))
                }
                [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
            }

            $history = @(Get-BudgetHistory -Budgets $budgets -MonthsBack 1 -CostTrend $script:Trend6)

            ($history | Where-Object BudgetName -EQ 'Upper').ActualSpend | Should -Be 40
            ($history | Where-Object BudgetName -EQ 'Lower').ActualSpend | Should -Be 60
            ($history | Where-Object BudgetName -EQ 'Same filter').ActualSpend | Should -Be 40
            ($history | Where-Object BudgetName -EQ 'Unfiltered').ActualSpend | Should -Be 10
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 2 -Exactly
        }

        It 'Leaves a <FilterCase> unavailable without issuing an unfiltered query' -ForEach @(
            @{ FilterCase = 'malformed tag comparison'; FilterJson = '{"tags":{"name":"CostCenter","operator":"In","values":"team"}}' }
            @{ FilterCase = 'missing comparison values'; FilterJson = '{"tags":{"name":"CostCenter","operator":"In","values":[]}}' }
            @{ FilterCase = 'empty AND'; FilterJson = '{"and":[]}' }
            @{ FilterCase = 'empty AND child'; FilterJson = '{"and":[{},{}]}' }
            @{ FilterCase = 'unsupported expression'; FilterJson = '{"or":[{"tags":{"name":"CostCenter","operator":"In","values":["team"]}},{"tags":{"name":"CostCenter","operator":"In","values":["other"]}}]}' }
            @{ FilterCase = 'unknown filter field'; FilterJson = '{"dimensions":{"name":"ResourceGroupName","operator":"In","values":["analytics"]},"unknown":true}' }
        ) {
            $budget = $script:HistBudget[0] | Select-Object *
            $budget.Filter = $FilterJson | ConvertFrom-Json
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'An unrecognized filter must not broaden the request.' }

            $history = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6)

            $history.Count | Should -Be 2
            foreach ($row in $history) {
                $row.ActualSpend | Should -BeNullOrEmpty
                $row.Status | Should -Be 'Unavailable'
                $row.Note | Should -Match 'cannot apply this filter'
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
        }

        It 'Does not replace a failed filtered query with cached subscription spend' {
            $budget = $script:HistBudget[0] | Select-Object *
            $budget.Filter = @{ dimensions = @{ name = 'ResourceGroupName'; operator = 'In'; values = @('analytics') } }
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }

            { Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6 } | Should -Throw '*403*incomplete*'

            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
                ($Payload | ConvertFrom-Json).dataset.filter.dimensions.name -eq 'ResourceGroupName'
            }
        }

        It 'Does not compare subscription history with a <Case> budget' -ForEach @(
            @{ Case = 'unsupported filter'; Change = 'Filter' }
            @{ Case = 'quarterly'; Change = 'Quarter' }
            @{ Case = 'usage'; Change = 'Usage' }
            @{ Case = 'missing amount'; Change = 'Amount' }
            @{ Case = 'unknown currency'; Change = 'Currency' }
            @{ Case = 'unknown validity period'; Change = 'Period' }
        ) {
            $budget = $script:HistBudget[0] | Select-Object *
            switch ($Change) {
                'Filter' { $budget.Filter = @{ tags = @{ name = 'CostCenter'; operator = 'NotIn'; values = @('team') } } }
                'Quarter' { $budget.TimeGrain = 'Quarterly' }
                'Usage' { $budget.Category = 'Usage' }
                'Amount' { $budget.Amount = $null }
                'Currency' { $budget.Currency = $null }
                'Period' { $budget.TimePeriod = $null }
            }
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'Unsupported budgets must not query unfiltered history.' }

            $rows = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6)

            $rows.Count | Should -Be 2
            foreach ($row in $rows) {
                $row.ActualSpend | Should -BeNullOrEmpty
                $row.PctUsed | Should -BeNullOrEmpty
                $row.Status | Should -Be 'Unavailable'
                $row.Note | Should -Not -BeNullOrEmpty
            }
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
        }

        It 'Does not present spend before the budget start as being under budget' {
            $budget = $script:HistBudget[0] | Select-Object *
            $budget.TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddDays(1 - (Get-Date).ToUniversalTime().Day) }
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'No active historical months.' }

            $rows = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6)

            @($rows | Where-Object Status -EQ 'Unavailable').Count | Should -Be 2
            $rows[0].ActualSpend | Should -BeNullOrEmpty
        }

        It 'Rejects a cached currency mismatch instead of relabeling it' {
            $budget = $script:HistBudget[0] | Select-Object *
            $budget.Currency = 'EUR'

            $rows = @(Get-BudgetHistory -Budgets @($budget) -MonthsBack 2 -CostTrend $script:Trend6)

            @($rows | Where-Object Status -EQ 'Unavailable').Count | Should -Be 2
            $rows[0].Note | Should -Match 'currenc'
            $rows[0].ActualSpend | Should -BeNullOrEmpty
        }
    }
}
