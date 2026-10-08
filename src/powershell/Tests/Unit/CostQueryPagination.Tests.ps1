# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Cost Management query pagination' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        function Get-FakeResponse {
            param([int]$StatusCode = 200, [string]$NextLink, [int]$RowCount = 1)
            $rows = @(1..$RowCount | ForEach-Object { , @("/subscriptions/x/r$_", 1.0, 'USD') })
            $payload = @{
                properties = @{
                    columns = @(@{ name = 'ResourceId' }, @{ name = 'Cost' }, @{ name = 'Currency' })
                    rows    = $rows
                }
            }
            if ($NextLink) { $payload.properties.nextLink = $NextLink }
            [PSCustomObject]@{ StatusCode = $StatusCode; Content = ($payload | ConvertTo-Json -Depth 6) }
        }
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Returns the single page when there is no nextLink' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse))
        $pages.Count | Should -Be 1
    }

    It 'Rejects a failed first response' {
        { Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse -StatusCode 403) } |
        Should -Throw '*page 1 failed (403)*incomplete*'
    }

    It 'Rejects missing response content' -ForEach @(
        @{ Content = $null }
        @{ Content = '' }
    ) {
        { Get-CostQueryResponsePage -FirstResponse ([PSCustomObject]@{ StatusCode = 200; Content = $Content }) } |
        Should -Throw '*no content*incomplete*'
    }

    It 'Rejects a null response' {
        { Get-CostQueryResponsePage -FirstResponse $null } | Should -Throw '*no response*incomplete*'
    }

    It 'Rejects a payload that is not valid JSON' {
        $bad = [PSCustomObject]@{ StatusCode = 200; Content = 'not json at all' }
        { Get-CostQueryResponsePage -FirstResponse $bad } | Should -Throw '*invalid JSON*incomplete*'
    }

    It 'Preserves a successful empty result' {
        $empty = [PSCustomObject]@{ StatusCode = 200; Content = '{"properties":{"columns":[],"rows":[],"nextLink":null}}' }
        $pages = @(Get-CostQueryResponsePage -FirstResponse $empty)
        $pages.Count | Should -Be 1
    }

    It 'Preserves the row payload so callers can parse it' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse -RowCount 3))
        $parsed = $pages[0].Content | ConvertFrom-Json
        @($parsed.properties.rows).Count | Should -Be 3
    }

    It 'Rejects a failed continuation without returning partial pages' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ StatusCode = 503; Content = '{}' }
        }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        $returnedPages = [System.Collections.Generic.List[object]]::new()

        {
            Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{"type":"ActualCost"}' |
            ForEach-Object { [void]$returnedPages.Add($_) }
        } | Should -Throw '*incomplete*'

        $returnedPages.Count | Should -Be 0
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly
    }

    It 'Replays the original POST payload and returns both pages exactly once' {
        $nextPage = Get-FakeResponse -RowCount 2
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { $nextPage }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2' -RowCount 3
        $payload = '{"type":"ActualCost","timeframe":"MonthToDate"}'

        $pages = @(Get-CostQueryResponsePage -FirstResponse $firstPage -Payload $payload)

        $pages.Count | Should -Be 2
        @((($pages[0].Content | ConvertFrom-Json).properties.rows)).Count | Should -Be 3
        @((($pages[1].Content | ConvertFrom-Json).properties.rows)).Count | Should -Be 2
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
            $Path -eq '/subscriptions/x/q?page=2' -and $Method -eq 'POST' -and
            $Payload -eq '{"type":"ActualCost","timeframe":"MonthToDate"}'
        }
    }

    It 'Combines complete pages into the parsed query result shape without flattening rows' {
        $nextPage = Get-FakeResponse -RowCount 2
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { $nextPage }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2' -RowCount 3

        $result = Get-CostQueryResult -FirstResponse $firstPage -Payload '{}'

        $result.properties.rows.Count | Should -Be 5
        $result.properties.rows[0].Count | Should -Be 3
        $result.properties.columns.name | Should -Be @('ResourceId', 'Cost', 'Currency')
        $result.properties.nextLink | Should -BeNullOrEmpty
    }

    It 'Rejects an invalid continuation payload (<Case>)' -ForEach @(
        @{ Case = 'empty'; Content = '' }
        @{ Case = 'invalid JSON'; Content = 'not json' }
        @{ Case = 'missing query rows'; Content = '{"properties":{"columns":[]}}' }
        @{ Case = 'missing query columns'; Content = '{"properties":{"rows":[]}}' }
        @{ Case = 'truncated row'; Content = '{"properties":{"columns":[{"name":"ResourceId"},{"name":"Cost"},{"name":"Currency"}],"rows":[["resource",10]]}}' }
    ) {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ StatusCode = 200; Content = $Content }
        }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        { Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' } | Should -Throw '*incomplete*'
    }

    It 'Rejects an unreadable cost before returning any pages (<Case>)' -ForEach @(
        @{ Case = 'null'; Amount = $null }
        @{ Case = 'blank'; Amount = '' }
        @{ Case = 'invalid'; Amount = 'not-a-number' }
        @{ Case = 'NaN'; Amount = 'NaN' }
        @{ Case = 'infinity'; Amount = 'Infinity' }
        @{ Case = 'overflow'; Amount = '1e999' }
    ) {
        $properties = @{
            columns = @(@{ name = 'ResourceId' }, @{ name = 'Cost' }, @{ name = 'Currency' })
            rows    = @(, @('/subscriptions/x/r2', $Amount, 'USD'))
        }
        $badPage = [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { $badPage }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        $returnedPages = [System.Collections.Generic.List[object]]::new()

        {
            Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' |
            ForEach-Object { [void]$returnedPages.Add($_) }
        } | Should -Throw '*cost*incomplete*'
        $returnedPages.Count | Should -Be 0
    }

    It 'Preserves genuine zero and negative costs' -ForEach @(
        @{ Amount = 0.0 }
        @{ Amount = -12.5 }
    ) {
        $properties = @{
            columns = @(@{ name = 'Cost' }, @{ name = 'Currency' })
            rows    = @(, @($Amount, 'USD'))
        }
        $firstPage = [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }

        $result = Get-CostQueryResult -FirstResponse $firstPage -Payload '{}'

        $result.properties.rows[0][0] | Should -Be $Amount
    }

    It 'Rejects changed column order across pages' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            [PSCustomObject]@{
                StatusCode = 200
                Content    = '{"properties":{"columns":[{"name":"Cost"},{"name":"ResourceId"},{"name":"Currency"}],"rows":[[20,"resource","USD"]]}}'
            }
        }
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        { Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' } | Should -Throw '*columns changed*'
    }

    It 'Rejects a repeated continuation link' {
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { $firstPage }
        { Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' } | Should -Throw '*link repeated*'
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly
    }

    It 'Rejects a truncated chain at the page limit' {
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        { Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' -MaxPages 1 } | Should -Throw '*stopped after 1 pages*'
    }

    It 'Rejects an unexpected continuation URL without making a request' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'Must not send this request' }
        $firstPage = Get-FakeResponse -NextLink 'https://example.com/page2'
        { Get-CostQueryResponsePage -FirstResponse $firstPage -Payload '{}' } | Should -Throw '*unexpected nextLink*'
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
    }

    It 'Requires the original payload before following a query continuation' {
        $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
        { Get-CostQueryResponsePage -FirstResponse $firstPage } | Should -Throw '*original POST payload is required*'
    }

    Context 'Actual and forecast totals' {
        It 'Keeps missing actuals unavailable and preserves forecast currency (<QueryPath>)' -ForEach @(
            @{ QueryPath = 'PerSubscription' }
            @{ QueryPath = 'ManagementGroup' }
            @{ QueryPath = 'ManagementGroupFallback' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath } {
                param($QueryPath)
                $fixturePath = $QueryPath
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    $isForecast = $Path -like '*forecast*'
                    if ($fixturePath -eq 'ManagementGroupFallback' -and $isForecast -and $Path -like '/providers/Microsoft.Management/*') {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $properties = @{
                        columns = @(@{ name = 'Currency' }, @{ name = 'SubscriptionId' }, @{ name = 'Cost' })
                        rows    = @()
                    }
                    if ($isForecast) { $properties.rows = @(, @('EUR', '11111111-1111-1111-1111-111111111111', 375.0)) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Forecast only' })

                $result = if ($fixturePath -eq 'PerSubscription') { Get-CostDataPerSubscription -Subscriptions $subscriptions }
                else { Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }

                $entry = $result[$subscriptions[0].Id]
                $entry.Actual | Should -BeNullOrEmpty
                $entry.Forecast | Should -Be 375
                $entry.Currency | Should -Be 'EUR'
                $entry.ForecastSource | Should -Be 'Forecast'
            }
        }

        It 'Preserves measured <Amount> actuals and rejects a different forecast currency (<QueryPath>)' -ForEach @(
            @{ QueryPath = 'PerSubscription'; Amount = 0.0 }
            @{ QueryPath = 'ManagementGroup'; Amount = 0.0 }
            @{ QueryPath = 'PerSubscription'; Amount = -5.25 }
            @{ QueryPath = 'ManagementGroup'; Amount = -5.25 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath; Amount = $Amount } {
                param($QueryPath, $Amount)
                $fixturePath = $QueryPath
                $fixtureAmount = $Amount
                $forecastUnit = 'EUR'
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    $isForecast = $Path -like '*forecast*'
                    $unit = if ($isForecast) { $forecastUnit } else { 'EUR' }
                    $value = if ($isForecast) { 375.0 } else { $fixtureAmount }
                    $properties = @{
                        columns = @(@{ name = 'Currency' }, @{ name = 'SubscriptionId' }, @{ name = 'Cost' })
                        rows    = @(, @($unit, '11111111-1111-1111-1111-111111111111', $value))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result = if ($fixturePath -eq 'PerSubscription') { Get-CostDataPerSubscription -Subscriptions $subscriptions }
                else { Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }

                $result[$subscriptions[0].Id].Actual | Should -Be $fixtureAmount
                $result[$subscriptions[0].Id].Currency | Should -Be 'EUR'
                $result[$subscriptions[0].Id].ActualPeriod | Should -Be 'Month to date (UTC query window)'
                $forecastUnit = 'USD'
                {
                    if ($fixturePath -eq 'PerSubscription') { Get-CostDataPerSubscription -Subscriptions $subscriptions }
                    else { Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                } | Should -Throw '*currency*'
            }
        }

        It 'Retains selected subscriptions absent from both management-group result sets as unavailable' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"columns":[{"name":"Currency"},{"name":"SubscriptionId"},{"name":"Cost"}],"rows":[["EUR","11111111-1111-1111-1111-111111111111",100]]}}' }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Present' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Absent' }
                )

                $result = Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $result.Count | Should -Be 2
                $result[$subscriptions[1].Id].Actual | Should -BeNullOrEmpty
                $result[$subscriptions[1].Id].Forecast | Should -BeNullOrEmpty
                $result[$subscriptions[1].Id].Currency | Should -BeNullOrEmpty
                $result[$subscriptions[1].Id].ForecastSource | Should -Be 'Unavailable'
            }
        }

        It 'Sums complete pages once (<QueryPath>, empty first page: <EmptyFirstPage>)' -ForEach @(
            @{ QueryPath = 'PerSubscription'; EmptyFirstPage = $false }
            @{ QueryPath = 'ManagementGroup'; EmptyFirstPage = $false }
            @{ QueryPath = 'ManagementGroupFallback'; EmptyFirstPage = $false }
            @{ QueryPath = 'ManagementGroupContinuationFallback'; EmptyFirstPage = $false }
            @{ QueryPath = 'PerSubscription'; EmptyFirstPage = $true }
            @{ QueryPath = 'ManagementGroup'; EmptyFirstPage = $true }
            @{ QueryPath = 'ManagementGroupFallback'; EmptyFirstPage = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath; EmptyFirstPage = $EmptyFirstPage } {
                param($QueryPath, $EmptyFirstPage)

                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    $isForecast = $Path -like '*forecast*'
                    $isNextPage = $Path -like '*page=2'
                    $failManagementGroup = $QueryPath -eq 'ManagementGroupFallback' -or ($QueryPath -eq 'ManagementGroupContinuationFallback' -and $isNextPage)
                    if ($failManagementGroup -and $isForecast -and $Path -like '/providers/Microsoft.Management/*') {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $amount = if ($isForecast) { if ($isNextPage) { 100.0 } else { 250.0 } } else { if ($isNextPage) { 25.0 } else { 100.0 } }
                    $body = @{
                        properties = @{
                            columns = @(@{ name = 'Currency' }, @{ name = 'SubscriptionId' }, @{ name = 'Cost' })
                            rows    = @(, @('USD', '11111111-1111-1111-1111-111111111111', $amount))
                        }
                    }
                    if (-not $isNextPage) {
                        $body.properties.nextLink = "$Path&page=2"
                        if ($EmptyFirstPage) { $body.properties.rows = @() }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })

                $result = if ($QueryPath -eq 'PerSubscription') {
                    Get-CostDataPerSubscription -Subscriptions $subscriptions
                }
                else {
                    Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                }

                $entry = $result[$subscriptions[0].Id]
                $entry.Actual | Should -Be $(if ($EmptyFirstPage) { 25 } else { 125 })
                $entry.Forecast | Should -Be $(if ($EmptyFirstPage) { 100 } else { 350 })
                $entry.ForecastSource | Should -Be 'Forecast'
                $continuationCalls = if ($QueryPath -eq 'ManagementGroupContinuationFallback') { 3 } else { 2 }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $continuationCalls -Exactly -ParameterFilter {
                    $Path -like '*page=2' -and $Method -eq 'POST' -and
                    ($Payload | ConvertFrom-Json).dataset.aggregation.totalCost.function -eq 'Sum'
                }
            }
        }

        It 'Returns no cost map when forecast pagination cannot be completed (<QueryPath>, fallback unavailable: <FallbackUnavailable>)' -ForEach @(
            @{ QueryPath = 'PerSubscription'; FallbackUnavailable = $false }
            @{ QueryPath = 'ManagementGroup'; FallbackUnavailable = $false }
            @{ QueryPath = 'ManagementGroup'; FallbackUnavailable = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath; FallbackUnavailable = $FallbackUnavailable } {
                param($QueryPath, $FallbackUnavailable)

                $usePerSubscription = $QueryPath -eq 'PerSubscription'
                $failSubscriptionRetry = $FallbackUnavailable
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    if ($failSubscriptionRetry -and $Path -like '/subscriptions/*/forecast*') {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $isForecast = $Path -like '*forecast*'
                    $amount = if ($isForecast) { 250.0 } else { 100.0 }
                    $body = @{
                        properties = @{
                            columns = @(@{ name = 'Cost' }, @{ name = 'SubscriptionId' }, @{ name = 'Currency' })
                            rows    = @(, @($amount, '11111111-1111-1111-1111-111111111111', 'USD'))
                        }
                    }
                    if ($isForecast) { $body.properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })

                $returnedResults = [System.Collections.Generic.List[object]]::new()
                {
                    $result = if ($usePerSubscription) {
                        Get-CostDataPerSubscription -Subscriptions $subscriptions
                    }
                    else {
                        Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -WarningAction SilentlyContinue
                    }
                    [void]$returnedResults.Add($result)
                } | Should -Throw '*incomplete*'
                $returnedResults.Count | Should -Be 0
            }
        }

        It 'Does not return partial actual cost after a continuation fails' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = '{"properties":{"columns":[{"name":"Cost"},{"name":"Currency"}],"rows":[[100,"USD"]],"nextLink":"/subscriptions/x/query?page=2"}}'
                    }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })
                { Get-CostDataPerSubscription -Subscriptions $subscriptions } | Should -Throw '*incomplete*'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -like '*forecast*' }
            }
        }
    }

    Context 'Resource costs' {
        It 'Preserves explicit UTC periods and honest resource identities for <QueryPath>' -Tag 'ResourceCostMetadata' -ForEach @(
            @{ QueryPath = 'ManagementGroup' }
            @{ QueryPath = 'PerSubscription' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath } {
                param($QueryPath)
                $fixturePath = $QueryPath
                $capturedUtc = [datetime]::new(2026, 10, 1, 0, 30, 0, [DateTimeKind]::Utc)
                $subId = '11111111-1111-1111-1111-111111111111'
                $vmId = "/subscriptions/$subId/resourceGroups/fixture/providers/Microsoft.Compute/virtualMachines/fixture-vm"
                $databaseId = "/subscriptions/$subId/resourceGroups/fixture/providers/Microsoft.Sql/servers/fixture-server/databases/fixture-db"
                $reservationId = '/providers/Microsoft.Capacity/reservationOrders/fixture-order/reservations/fixture-reservation'
                $reservationGroupId = '/providers/Microsoft.Capacity/reservationOrders/fixture-order/reservations/'
                $queryBodies = [Collections.Generic.List[object]]::new()
                Mock Get-Date { $capturedUtc.ToLocalTime() }
                Mock Resolve-CostMgId { if ($fixturePath -eq 'ManagementGroup') { 'fixture-mg' } }
                Mock Test-CostMgCoverage { $true }
                Mock Write-Host { }
                Mock Get-AzContext { throw 'Resource metadata tests must not read Azure context.' }
                Mock Invoke-RestMethod { throw 'Resource metadata tests must not send HTTP requests.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -ne 'POST' -or $Path -notlike '*Microsoft.CostManagement/query*') { throw 'Unexpected resource-cost request.' }
                    [void]$queryBodies.Add(($Payload | ConvertFrom-Json))
                    $rows = @(
                        if ($Path -like '*page=2') {
                            , @(20.0, $databaseId, 'fixture', 'USD')
                            , @(30.0, $reservationId, '', 'USD')
                            , @(40.0, $reservationGroupId, '', 'USD')
                            , @(50.0, '', '', 'USD')
                        }
                        else { , @(10.0, $vmId, 'fixture', 'USD') }
                    )
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' })
                        rows    = $rows
                    }
                    if ($Path -notlike '*page=2') { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = $subId; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                $costData = @{ $subId = @{ Actual = 150; Forecast = 150; ForecastSource = 'Forecast'; Currency = 'USD' } }

                $rows = @(Get-ResourceCosts -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -CostData $costData -RestrictToSelected)

                $rows.Count | Should -Be 5
                ($rows | Measure-Object Actual -Sum).Sum | Should -Be 150
                foreach ($row in $rows) {
                    $row.ActualPeriodStart | Should -Be ([datetime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc))
                    $row.ActualPeriodEnd | Should -Be $capturedUtc
                    $row.ActualPeriodSource | Should -Be 'Query window'
                    $row.ActualPeriod | Should -Match '2026-10-01.*UTC.*query window'
                    $row.Currency | Should -Be 'USD'
                }
                foreach ($body in $queryBodies) {
                    $body.timeframe | Should -Be 'Custom'
                    ([datetime]$body.timePeriod.from).ToUniversalTime() | Should -Be ([datetime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc))
                    ([datetime]$body.timePeriod.to).ToUniversalTime() | Should -Be $capturedUtc
                    $body.type | Should -Be 'ActualCost'
                }
                $vm = $rows | Where-Object ResourcePath -EQ $vmId
                $vm.SubscriptionId | Should -Be $subId
                $vm.Subscription | Should -Be 'Example subscription'
                $vm.ResourceName | Should -Be 'fixture-vm'
                $vm.ResourceType | Should -Be 'Virtual Machine'
                $database = $rows | Where-Object ResourcePath -EQ $databaseId
                $database.ResourceName | Should -Be 'fixture-db'
                $database.ResourceType | Should -Be 'SQL Database'
                $reservation = $rows | Where-Object ResourcePath -EQ $reservationId
                $reservation.ResourceName | Should -Be 'fixture-reservation'
                $reservation.ResourceType | Should -Be 'Reservation charge'
                $reservationGroup = $rows | Where-Object ResourcePath -EQ $reservationGroupId
                $reservationGroup.ResourceName | Should -Be 'Reservation charge (order fixture-order)'
                $reservationGroup.ResourceType | Should -Be 'Reservation charge'
                $unattributed = $rows | Where-Object { [string]::IsNullOrWhiteSpace($_.ResourcePath) }
                $unattributed.ResourceType | Should -Be 'Unattributed charge'
                $unattributed.ResourceName | Should -Be 'No resource ID recorded'
                foreach ($charge in @($reservation, $reservationGroup, $unattributed)) {
                    if ($fixturePath -eq 'ManagementGroup') {
                        $charge.SubscriptionId | Should -BeNullOrEmpty
                        $charge.Subscription | Should -Be 'Not attributed'
                    }
                    else {
                        $charge.SubscriptionId | Should -Be $subId
                        $charge.Subscription | Should -Be 'Example subscription'
                    }
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly
                Should -Invoke Get-AzContext -Times 0 -Exactly
                Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            }
        }

        It 'Reads every resource page without retaining a failed MG attempt (<QueryPath>)' -ForEach @(
            @{ QueryPath = 'PerSubscription' }
            @{ QueryPath = 'ManagementGroup' }
            @{ QueryPath = 'ManagementGroupFallback' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath } {
                param($QueryPath)

                Mock Resolve-CostMgId { if ($QueryPath -ne 'PerSubscription') { 'test-management-group' } }
                Mock Test-CostMgCoverage { $true }
                Mock Get-Date { [datetime]'2026-09-16T12:00:00Z' }
                Mock Get-Date { [datetime]'2026-09-01T00:00:00' } -ParameterFilter { $Day -eq 1 }
                Mock Invoke-AzRestMethodWithRetry {
                    $isNextPage = $Path -like '*page=2'
                    if ($QueryPath -eq 'ManagementGroupFallback' -and $Path -like '/providers/Microsoft.Management/*' -and $isNextPage) {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    if ($Path -like '*forecast*') {
                        $amount = if ($isNextPage) { 100.0 } else { 400.0 }
                        $properties = @{
                            columns = @(@{ name = 'CostStatus' }, @{ name = 'Cost' }, @{ name = 'Currency' })
                            rows    = @(, @('Forecast', $amount, 'USD'))
                        }
                    }
                    else {
                        $amount = if ($isNextPage) { 25.0 } else { 100.0 }
                        $resourceName = if ($isNextPage) { 'second' } else { 'first' }
                        $properties = @{
                            columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' })
                            rows    = @(, @($amount, "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/$resourceName", 'test', 'USD'))
                        }
                    }
                    if (-not $isNextPage) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })

                $result = @(Get-ResourceCosts -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -WarningAction SilentlyContinue)

                $result.Count | Should -Be 2
                ($result | Measure-Object -Property Actual -Sum).Sum | Should -Be 125
                if ($QueryPath -ne 'ManagementGroup') {
                    ($result | Measure-Object -Property Forecast -Sum).Sum | Should -Be 500
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter {
                        $request = $Payload | ConvertFrom-Json
                        $Path -like '*forecast*' -and $Method -eq 'POST' -and $request.timePeriod.from -eq '2026-09-01'
                    }
                }
                $continuationCalls = switch ($QueryPath) { 'ManagementGroup' { 1 } 'ManagementGroupFallback' { 3 } default { 2 } }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $continuationCalls -Exactly -ParameterFilter {
                    $Path -like '*page=2' -and $Method -eq 'POST' -and -not [string]::IsNullOrWhiteSpace($Payload)
                }
            }
        }

        It 'Withholds incomplete per-resource <Operation> results' -ForEach @(
            @{ Operation = 'query' }
            @{ Operation = 'forecast' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Operation = $Operation } {
                param($Operation)

                $failedOperation = $Operation
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' })
                        rows    = @(, @(100.0, '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/first', 'test', 'USD'))
                    }
                    if ($Path.Contains("/$failedOperation`?")) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })
                if ($Operation -eq 'query') {
                    { Get-ResourceCosts -Subscriptions $subscriptions } | Should -Throw '*incomplete*'
                    return
                }

                $result = @(Get-ResourceCosts -Subscriptions $subscriptions -WarningVariable forecastWarnings -WarningAction SilentlyContinue)

                $result.Count | Should -Be 1
                $result[0].Actual | Should -Be 100
                $result[0].Forecast | Should -BeNullOrEmpty
                $result[0].ForecastSource | Should -Be 'Unavailable'
                $result[0].CostIssue | Should -Match 'unavailable.*incomplete'
                @($forecastWarnings | Where-Object { "$_" -match 'unavailable.*incomplete' }).Count | Should -Be 1
            }
        }
    }

    It 'Leaves orphan cost unavailable when its continuation fails' {
        InModuleScope FinOpsMultitool {
            Mock Search-AzGraphSafe {
                $rows = @()
                if ($Query.Contains("properties.diskState == 'Unattached'")) {
                    $rows = @([pscustomobject]@{
                            id = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/first'
                            name = 'first'; resourceGroup = 'test'; subscriptionId = '11111111-1111-1111-1111-111111111111'
                            location = 'eastus'; diskSizeGb = 128; sku = 'Premium_LRS'
                        })
                }
                [pscustomobject]@{ Data = $rows }
            }
            Mock Invoke-AzRestMethodWithRetry {
                if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                $body = @{
                    properties = @{
                        columns  = @(@{ name = 'ResourceId' }, @{ name = 'Cost' })
                        rows     = @(, @('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/first', 100.0))
                        nextLink = "$Path&page=2"
                    }
                }
                [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 10) }
            }
            $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })

            $result = Get-OrphanedResources -Subscriptions $subscriptions

            $result.TotalCount | Should -Be 1
            $result.CostAvailable | Should -BeFalse
            $result.CostedCount | Should -Be 0
            $result.MonthlyCost | Should -BeNullOrEmpty
            $result.Orphans[0].MonthlyCost | Should -BeNullOrEmpty
            $result.CostPeriod | Should -BeNullOrEmpty
            $result.CostIssue | Should -BeLike '*incomplete*'
            Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                $Path -like '*page=2' -and $Method -eq 'POST' -and ($Payload | ConvertFrom-Json).type -eq 'ActualCost'
            }
        }
    }

    Context 'Parsed query consumers' {
        It 'Reconciles scoped AI token totals for <Scenario>' -Tag 'AIReconciliation' -ForEach @(
            @{ Scenario = 'different transaction totals'; SecondTotal = 1200; ExpectedTokens = 2400; ExpectedBasis = 'TokenTransaction'; ExpectedRate = 62.5 }
            @{ Scenario = 'per-deployment fallback'; SecondTotal = $null; ExpectedTokens = 2200; ExpectedBasis = 'Prompt + generated'; ExpectedRate = 68.1818 }
            @{ Scenario = 'measured zero transaction total'; SecondTotal = 0; ExpectedTokens = 1200; ExpectedBasis = 'TokenTransaction'; ExpectedRate = 83.3333 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ SecondTotal = $SecondTotal; ExpectedTokens = $ExpectedTokens; ExpectedBasis = $ExpectedBasis; ExpectedRate = $ExpectedRate } {
                param($SecondTotal, $ExpectedTokens, $ExpectedBasis, $ExpectedRate)
                $secondTransactionTotal = $SecondTotal
                $accountIds = @(
                    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.CognitiveServices/accounts/first'
                    '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/fixture/providers/Microsoft.CognitiveServices/accounts/second'
                )
                Mock Write-Host { }
                Mock Resolve-CostMgId { 'fixture' }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Search-AzGraphSafe {
                    @{ Data = @($accountIds | ForEach-Object { [pscustomobject]@{ id = $_; name = ($_ -split '/')[-1]; type = 'microsoft.cognitiveservices/accounts'; lkind = 'OpenAI'; subscriptionId = ($_ -split '/')[2]; location = 'eastus' } }) }
                }
                Mock Invoke-WebRequest {
                    $transactionTotal = if ($Uri -like '*/accounts/second/*') { $secondTransactionTotal } else { 1200 }
                    $metricValues = @(@{ Name = 'ProcessedPromptTokens'; Total = 800 }, @{ Name = 'GeneratedTokens'; Total = 200 }, @{ Name = 'AzureOpenAIRequests'; Total = 10 })
                    if ($null -ne $transactionTotal) { $metricValues += @{ Name = 'TokenTransaction'; Total = $transactionTotal } }
                    $metrics = @(foreach ($metric in $metricValues) {
                            @{ name = @{ value = $metric.Name }; timeseries = @(@{ metadatavalues = @(@{ name = @{ value = 'ModelDeploymentName' }; value = 'shared-deployment' }); data = @(@{ total = $metric.Total }) }) }
                        })
                    [pscustomobject]@{ Content = (@{ value = $metrics } | ConvertTo-Json -Depth 10) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' }); rows = @(@(100, $accountIds[0], 'USD'), @(50, $accountIds[1], 'USD')) } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }, [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' })

                $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $result.RateIssue | Should -BeNullOrEmpty
                $result.TotalTokens | Should -Be $ExpectedTokens
                ($result.ByAccount | Measure-Object Tokens -Sum).Sum | Should -Be $ExpectedTokens
                ($result.ByModel | Measure-Object TotalTokens -Sum).Sum | Should -Be $ExpectedTokens
                $result.CostPer1KTokens | Should -Be $ExpectedRate
                $result.CostPerRequest | Should -Be 7.5
                $result.ByModel.Count | Should -Be 2
                @($result.ByModel.Deployment | Select-Object -Unique) | Should -Be @('shared-deployment')
                @($result.ByModel.ResourceId | Select-Object -Unique).Count | Should -Be 2
                @($result.ByModel.SubscriptionId | Select-Object -Unique).Count | Should -Be 2
                ($result.ByModel | Where-Object Account -EQ 'second').TokenBasis | Should -Be $ExpectedBasis
                ($result.ByAccount | Where-Object Name -EQ 'second').TokenBasis | Should -Be $ExpectedBasis
            }
        }

        It 'Leaves incomplete AI usage unavailable for <Scenario>' -Tag 'AIReconciliation' -ForEach @(
            @{ Scenario = 'empty response' }
            @{ Scenario = 'missing samples' }
            @{ Scenario = 'missing output and total' }
            @{ Scenario = 'missing requests' }
            @{ Scenario = 'metric error' }
            @{ Scenario = 'invalid sample' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scenario = $Scenario } {
                param($Scenario)
                $fixtureScenario = $Scenario
                $accountId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.CognitiveServices/accounts/example'
                $queries = [Collections.Generic.List[object]]::new()
                Mock Write-Host { }
                Mock Get-Date { [datetime]::new(2026, 10, 1, 0, 30, 0, [DateTimeKind]::Utc).ToLocalTime() }
                Mock Resolve-CostMgId { 'fixture' }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Search-AzGraphSafe { @{ Data = @([pscustomobject]@{ id = $accountId; name = 'example'; type = 'microsoft.cognitiveservices/accounts'; lkind = 'OpenAI'; subscriptionId = '11111111-1111-1111-1111-111111111111' }) } }
                Mock Invoke-WebRequest {
                    $metrics = @(foreach ($metricName in @('ProcessedPromptTokens', 'GeneratedTokens', 'TokenTransaction', 'AzureOpenAIRequests')) {
                            if ($fixtureScenario -eq 'empty response' -or ($fixtureScenario -eq 'missing output and total' -and $metricName -in @('GeneratedTokens', 'TokenTransaction')) -or ($fixtureScenario -eq 'missing requests' -and $metricName -eq 'AzureOpenAIRequests')) { continue }
                            $total = if ($fixtureScenario -eq 'missing samples') { $null } elseif ($fixtureScenario -eq 'invalid sample') { -1 } else { 10 }
                            @{ name = @{ value = $metricName }; errorCode = $(if ($fixtureScenario -eq 'metric error') { 'BadRequest' } else { 'Success' }); timeseries = @(@{ data = @(@{ total = $total }) }) }
                        })
                    [pscustomobject]@{ Content = (@{ value = $metrics } | ConvertTo-Json -Depth 10) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $queries.Add(($Payload | ConvertFrom-Json))
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' }); rows = @(, @(100, $accountId, 'USD')) } } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example' })

                $result.MetricFailures | Should -Be 1
                $result.RateIssue | Should -Match 'incomplete'
                $result.CostPer1KTokens | Should -BeNullOrEmpty
                $result.CostPerRequest | Should -BeNullOrEmpty
                $result.ByAccount[0].CostPer1KTokens | Should -BeNullOrEmpty
                $result.ByAccount[0].MetricsComplete | Should -BeFalse
                if ($fixtureScenario -eq 'missing requests') {
                    $result.ByAccount[0].Requests | Should -BeNullOrEmpty
                    $result.TotalRequests | Should -BeNullOrEmpty
                    $result.HasRequestData | Should -BeFalse
                }
                else {
                    $result.ByAccount[0].Tokens | Should -BeNullOrEmpty
                    $result.TotalTokens | Should -BeNullOrEmpty
                    $result.HasTokenData | Should -BeFalse
                }
                $queries[0].timeframe | Should -Be 'Custom'
                ([datetime]$queries[0].timePeriod.from).ToUniversalTime() | Should -Be ([datetime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc))
                ([datetime]$queries[0].timePeriod.to).ToUniversalTime() | Should -Be $result.UsagePeriodEndUtc
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*timespan=2026-10-01T00:00:00Z/2026-10-01T00:30:00Z*' }
            }
        }

        It 'Keeps Hub model token rows distinct by account without live requests' -Tag 'AIReconciliation' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry { throw 'No live cost calls are allowed.' }
                Mock Invoke-WebRequest { throw 'No live metric calls are allowed.' }
                $hubRows = @(foreach ($accountName in @('first', 'second')) {
                    $subscriptionId = if ($accountName -eq 'first') { '11111111-1111-1111-1111-111111111111' } else { '22222222-2222-2222-2222-222222222222' }
                    [pscustomobject]@{
                        SubAccountId = $subscriptionId; ResourceName = $accountName
                        ResourceId = "/subscriptions/$subscriptionId/resourceGroups/fixture/providers/Microsoft.CognitiveServices/accounts/$accountName"
                        ResourceType = 'microsoft.cognitiveservices/accounts'; EffectiveCost = 100; BilledCost = 100; BillingCurrency = 'USD'
                        ChargePeriodStart = '2026-09-01'; ConsumedQuantity = 10; ConsumedUnit = '1K tokens'; x_SkuMeterName = 'gpt-example input tokens'
                    }
                })

                $result = ConvertTo-AIHubAggregates -HubData $hubRows

                $result.ModelTokens.Count | Should -Be 2
                @($result.ModelTokens.Values.Deployment | Select-Object -Unique).Count | Should -Be 1
                @($result.ModelTokens.Values.ResourceId | Select-Object -Unique).Count | Should -Be 2
                @($result.ModelTokens.Values.SubscriptionId | Select-Object -Unique).Count | Should -Be 2
                ($result.ModelTokens.Values | Measure-Object Total -Sum).Sum | Should -Be $result.TotalTokens
                ($result.AcctTokens.Values | Measure-Object Tokens -Sum).Sum | Should -Be $result.TotalTokens
                $result.TotalTokens | Should -Be 20000
                $result.Currency | Should -Be 'USD'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
                Should -Invoke Invoke-WebRequest -Times 0 -Exactly
            }
        }

        It 'Preserves AI usage without inventing totals for <CurrencyCase> currencies' -ForEach @(
            @{ CurrencyCase = 'mixed'; ExpectedAvailable = $false }
            @{ CurrencyCase = 'missing column'; ExpectedAvailable = $false }
            @{ CurrencyCase = 'blank row'; ExpectedAvailable = $false }
            @{ CurrencyCase = 'matching'; ExpectedAvailable = $true }
            @{ CurrencyCase = 'matching with failed metrics'; ExpectedAvailable = $true }
            @{ CurrencyCase = 'matching with other AI spend'; ExpectedAvailable = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ CurrencyCase = $CurrencyCase; ExpectedAvailable = $ExpectedAvailable } {
                param($CurrencyCase, $ExpectedAvailable)
                $fixtureCurrencyCase = $CurrencyCase
                $accountIds = @(
                    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/first'
                    '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/second'
                )
                Mock Resolve-CostMgId { 'fixture' }
                Mock Search-AzGraphSafe {
                    @{ Data = @($accountIds | ForEach-Object { [pscustomobject]@{ id = $_; name = ($_ -split '/')[-1]; type = 'microsoft.cognitiveservices/accounts'; lkind = 'OpenAI'; subscriptionId = ($_ -split '/')[2]; location = 'eastus' } }) }
                }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Invoke-WebRequest {
                    if ($fixtureCurrencyCase -eq 'matching with failed metrics' -and $Uri -like '*/accounts/second/*') { throw 'Synthetic metrics HTTP 429.' }
                    $metrics = @(foreach ($metric in @(@{ Name = 'ProcessedPromptTokens'; Total = 800 }, @{ Name = 'GeneratedTokens'; Total = 200 }, @{ Name = 'TokenTransaction'; Total = 1000 }, @{ Name = 'AzureOpenAIRequests'; Total = 10 })) {
                            @{ name = @{ value = $metric.Name }; timeseries = @(@{ data = @(@{ total = $metric.Total }) }) }
                        })
                    [pscustomobject]@{ Content = (@{ value = $metrics } | ConvertTo-Json -Depth 10) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' })
                    $rows = @(@(100, $accountIds[0]), @(50, $accountIds[1]))
                    if ($fixtureCurrencyCase -ne 'missing column') {
                        $columns += @{ name = 'Currency' }
                        $rows[0] += 'USD'
                        $rows[1] += $(switch ($fixtureCurrencyCase) { 'mixed' { 'EUR' }; 'blank row' { '' }; default { 'USD' } })
                    }
                    if ($fixtureCurrencyCase -eq 'matching with other AI spend') { $rows += , @(200, ($accountIds[0] -replace '/first$', '/speech'), 'USD') }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = $columns; rows = $rows } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $metricsFailed = $CurrencyCase -eq 'matching with failed metrics'
                $result.TotalTokens | Should -Be $(if ($metricsFailed) { 1000 } else { 2000 })
                $result.TotalRequests | Should -Be $(if ($metricsFailed) { 10 } else { 20 })
                $result.HasData | Should -BeTrue
                if ($ExpectedAvailable) {
                    $result.TotalAICost | Should -Be $(if ($CurrencyCase -eq 'matching with other AI spend') { 350 } else { 150 })
                    $result.Currency | Should -Be 'USD'
                    if ($metricsFailed) {
                        $result.CostPer1KTokens | Should -BeNullOrEmpty
                        $result.CostPerRequest | Should -BeNullOrEmpty
                        $result.RateIssue | Should -Match 'metrics'
                        $result.MetricFailures | Should -Be 1
                    }
                    else {
                        $result.CostPer1KTokens | Should -Be 75
                        $result.CostPerRequest | Should -Be 7.5
                    }
                }
                else {
                    $result.TotalAICost | Should -BeNullOrEmpty
                    $result.CostPer1KTokens | Should -BeNullOrEmpty
                    $result.CostPerRequest | Should -BeNullOrEmpty
                    $result.CostIssue | Should -Match 'currenc'
                    foreach ($account in $result.ByAccount) {
                        $account.Cost | Should -BeNullOrEmpty
                        $account.CostPer1KTokens | Should -BeNullOrEmpty
                    }
                    $requestKpi = Get-KpiComputedValue -KpiId 'cost-per-api-call' -Data $result
                    $requestKpi.Value | Should -BeNullOrEmpty
                    $requestKpi.Display | Should -Match 'Unavailable'
                    $tokenKpi = Get-KpiComputedValue -KpiId 'token-consumption-metrics' -Data $result
                    $tokenKpi.Value | Should -Be 2000
                    $tokenKpi.Display | Should -Not -Match 'for (Mixed|USD|EUR)'
                }
            }
        }

        It 'Requires complete <Scan> cost pages (continuation fails: <PageFails>)' -ForEach @(
            @{ Scan = 'AI'; PageFails = $false }
            @{ Scan = 'AI'; PageFails = $true }
            @{ Scan = 'VM'; PageFails = $false }
            @{ Scan = 'VM'; PageFails = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scan = $Scan; PageFails = $PageFails } {
                param($Scan, $PageFails)

                $failContinuation = $PageFails
                $targetResourceId = if ($Scan -eq 'AI') {
                    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/test'
                }
                else {
                    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/virtualMachines/test'
                }
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Search-AzGraphSafe {
                    [pscustomobject]@{ Data = @([pscustomobject]@{ id = $targetResourceId; type = 'microsoft.cognitiveservices/accounts'; lkind = 'TextAnalytics' }) }
                }
                Mock Resolve-VmAssociation {
                    $associated = [System.Collections.Generic.HashSet[string]]::new()
                    [void]$associated.Add($targetResourceId)
                    [pscustomobject]@{
                        Id = $targetResourceId; Name = 'test'; SubscriptionId = '11111111-1111-1111-1111-111111111111'
                        ResourceGroup = 'test'; Associated = $associated
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $isNextPage = $Path -like '*page=2'
                    if ($failContinuation -and $isNextPage) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $amount = if ($isNextPage) { 25.0 } else { 100.0 }
                    $category = if ($isNextPage) { 'Storage' } else { 'Virtual Machines' }
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'MeterCategory' }, @{ name = 'Currency' }, @{ name = 'UsageQuantity' })
                        rows    = @(, @($amount, $targetResourceId, $category, 'USD', 1.0))
                    }
                    if (-not $isNextPage) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })

                if ($Scan -eq 'AI') {
                    if ($PageFails) {
                        { Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions } | Should -Throw '*incomplete*'
                    }
                    else {
                        $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                        $result.TotalAICost | Should -Be 125
                    }
                }
                else {
                    $result = Get-VmCostBreakdown -VmName 'test' -Subscriptions $subscriptions
                    if ($PageFails) {
                        $result.HasData | Should -BeFalse
                        $result.TotalCost | Should -BeNullOrEmpty
                        $result.Note | Should -BeLike '*incomplete*'
                    }
                    else {
                        $result.HasData | Should -BeTrue
                        $result.TotalCost | Should -Be 125
                    }
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $Path -like '*page=2' -and $Method -eq 'POST' -and ($Payload | ConvertFrom-Json).type -eq 'AmortizedCost'
                }
            }
        }
    }

    Context 'Trend scope metadata' {
        It 'Retains scoped trends and explicit coverage for <Scenario>' -Tag 'ScopedCostTrend' -ForEach @(
            @{ Scenario = 'complete grouped response'; QueryPath = 'ManagementGroup'; IncludeSecond = $true; EmptySingle = $false; IndividualResult = 'None'; ExpectedData = 2; ExpectedUnverified = 0; ExpectedEmpty = 0; ExpectedCalls = 1; ExpectedTotal = 30 }
            @{ Scenario = 'omitted subscription without cost rows'; QueryPath = 'ManagementGroup'; IncludeSecond = $false; EmptySingle = $false; IndividualResult = 'Empty'; ExpectedData = 1; ExpectedUnverified = 0; ExpectedEmpty = 1; ExpectedCalls = 2; ExpectedTotal = 10 }
            @{ Scenario = 'omitted subscription with cost rows'; QueryPath = 'ManagementGroup'; IncludeSecond = $false; EmptySingle = $false; IndividualResult = 'Data'; ExpectedData = 2; ExpectedUnverified = 0; ExpectedEmpty = 0; ExpectedCalls = 2; ExpectedTotal = 30 }
            @{ Scenario = 'failed individual query'; QueryPath = 'ManagementGroup'; IncludeSecond = $false; EmptySingle = $false; IndividualResult = 'Fail'; ExpectedData = 1; ExpectedUnverified = 1; ExpectedEmpty = 0; ExpectedCalls = 2; ExpectedTotal = 10 }
            @{ Scenario = 'empty subscription response'; QueryPath = 'PerSubscription'; IncludeSecond = $false; EmptySingle = $false; IndividualResult = 'None'; ExpectedData = 1; ExpectedUnverified = 0; ExpectedEmpty = 1; ExpectedCalls = 2; ExpectedTotal = 10 }
            @{ Scenario = 'empty single-subscription response'; QueryPath = 'Single'; IncludeSecond = $false; EmptySingle = $true; IndividualResult = 'None'; ExpectedData = 0; ExpectedUnverified = 0; ExpectedEmpty = 1; ExpectedCalls = 1; ExpectedTotal = 0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath; IncludeSecond = $IncludeSecond; EmptySingle = $EmptySingle; IndividualResult = $IndividualResult; ExpectedData = $ExpectedData; ExpectedUnverified = $ExpectedUnverified; ExpectedEmpty = $ExpectedEmpty; ExpectedCalls = $ExpectedCalls; ExpectedTotal = $ExpectedTotal } {
                param($QueryPath, $IncludeSecond, $EmptySingle, $IndividualResult, $ExpectedData, $ExpectedUnverified, $ExpectedEmpty, $ExpectedCalls, $ExpectedTotal)
                $fixturePath = $QueryPath
                $includeSecondRow = $IncludeSecond
                $emptyOnlySubscription = $EmptySingle
                $individualResponse = $IndividualResult
                $firstId = '11111111-1111-1111-1111-111111111111'
                $secondId = '22222222-2222-2222-2222-222222222222'
                $outsideId = '99999999-9999-9999-9999-999999999999'
                $capturedUtc = [datetime]::new(2026, 10, 1, 0, 30, 0, [DateTimeKind]::Utc)
                $queries = [Collections.Generic.List[object]]::new()
                Mock Get-Date { $capturedUtc.ToLocalTime() }
                Mock Write-Host { }
                Mock Resolve-CostMgId { if ($fixturePath -eq 'ManagementGroup') { 'fixture-mg' } }
                Mock Get-AzContext { throw 'Trend fixtures must not read Azure context.' }
                Mock Invoke-RestMethod { throw 'Trend fixtures must not send HTTP requests.' }
                Mock Invoke-AzRestMethodWithRetry {
                    [void]$queries.Add(($Payload | ConvertFrom-Json))
                    $columns = @(@{ name = 'Cost' }, @{ name = 'BillingMonth' }, @{ name = 'Currency' })
                    $rows = @()
                    if ($fixturePath -eq 'ManagementGroup' -and $Path -like '/providers/Microsoft.Management/managementGroups/*') {
                        $columns += @{ name = 'SubscriptionId' }
                        $rows = @(
                            , @(10, '20260901', 'USD', $firstId)
                            if ($includeSecondRow) { , @(20, '20260901', 'USD', $secondId) }
                            , @(999, '20260901', 'EUR', $outsideId)
                        )
                    }
                    elseif ($individualResponse -eq 'Fail' -and $Path -like "*/$secondId/*") {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    elseif ($individualResponse -eq 'Data' -and $Path -like "*/$secondId/*") {
                        $rows = @(, @(20, '20260901', 'USD'))
                    }
                    elseif (-not $emptyOnlySubscription -and $Path -like "*/$firstId/*") {
                        $rows = @(, @(10, '20260901', 'USD'))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = $columns; rows = $rows } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = $firstId; Name = 'Example <first>'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                if ($fixturePath -ne 'Single') { $subscriptions += [pscustomobject]@{ Id = $secondId; Name = 'Example second'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } }

                $result = Get-CostTrend -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $result.ScopeKind | Should -Be 'Selected subscriptions'
                $result.SelectedSubscriptionCount | Should -Be $subscriptions.Count
                $result.SubscriptionsWithData | Should -Be $ExpectedData
                @($result.UnverifiedSubscriptionIds).Count | Should -Be $ExpectedUnverified
                @($result.NoDataSubscriptionIds).Count | Should -Be $ExpectedEmpty
                $result.CoverageIncomplete | Should -Be ($ExpectedUnverified -gt 0)
                $result.BySubscription.ContainsKey($outsideId) | Should -BeFalse
                $result.SubscriptionNames[$firstId] | Should -Be 'Example <first>'
                $result.CostBasis | Should -Be 'ActualCost'
                $result.CostPeriodStartUtc | Should -Be ([datetime]::new(2026, 4, 1, 0, 0, 0, [DateTimeKind]::Utc))
                $result.CostPeriodEndUtc | Should -Be $capturedUtc
                foreach ($query in $queries) {
                    ([datetime]$query.timePeriod.from).ToUniversalTime() | Should -Be $result.CostPeriodStartUtc
                    ([datetime]$query.timePeriod.to).ToUniversalTime() | Should -Be $result.CostPeriodEndUtc
                }
                if ($fixturePath -eq 'ManagementGroup') {
                    $queries[0].dataset.filter.dimensions.values | Should -Be @($firstId, $secondId)
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times $ExpectedCalls -Exactly
                    $result.QueryScope | Should -Be '/providers/Microsoft.Management/managementGroups/fixture-mg'
                    $result.Months[0].Cost | Should -Be $ExpectedTotal
                    $result.Months[0].Currency | Should -Be 'USD'
                    if ($includeSecondRow) { @($result.IndividuallyQueriedIds).Count | Should -Be 0 }
                    else {
                        @($result.IndividuallyQueriedIds) | Should -Be @($secondId)
                        $queries[1].dataset.grouping | Should -BeNullOrEmpty
                        $queries[1].dataset.filter | Should -BeNullOrEmpty
                        Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '/subscriptions/22222222-2222-2222-2222-222222222222/*' }
                    }
                }
                if ($individualResponse -eq 'Fail') {
                    @($result.QueryErrors).Count | Should -Be 1
                    $result.QueryErrors[0] | Should -Match ([regex]::Escape("Example second [$secondId]"))
                    $result.Note | Should -Match 'individual queries failed'
                    $result.BySubscription[$firstId][0].Cost | Should -Be 10
                }
                else { @($result.QueryErrors).Count | Should -Be 0 }
                if ($ExpectedUnverified) {
                    $result.UnverifiedSubscriptionIds | Should -Contain $secondId
                    $result.Note | Should -Match 'not verified'
                }
                if ($emptyOnlySubscription) { $result.HasData | Should -BeFalse; $result.Months | Should -BeNullOrEmpty }
                Should -Invoke Get-AzContext -Times 0 -Exactly
                Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            }
        }
    }

    Context 'Trend currency integrity' {
        It 'Handles <CurrencyCase> through <QueryPath> without inventing a monetary total' -ForEach @(
            @{ QueryPath = 'Fallback'; CurrencyCase = 'mixed'; Valid = $false }
            @{ QueryPath = 'ManagementGroup'; CurrencyCase = 'mixed'; Valid = $false }
            @{ QueryPath = 'Fallback'; CurrencyCase = 'missing'; Valid = $false }
            @{ QueryPath = 'ManagementGroup'; CurrencyCase = 'missing'; Valid = $false }
            @{ QueryPath = 'Single'; CurrencyCase = 'missing'; Valid = $false }
            @{ QueryPath = 'Single'; CurrencyCase = 'blank'; Valid = $false }
            @{ QueryPath = 'Fallback'; CurrencyCase = 'same'; Valid = $true }
            @{ QueryPath = 'ManagementGroup'; CurrencyCase = 'same'; Valid = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath; CurrencyCase = $CurrencyCase; Valid = $Valid } {
                param($QueryPath, $CurrencyCase, $Valid)
                $fixturePath = $QueryPath
                $fixtureCurrency = $CurrencyCase
                Mock Resolve-CostMgId { if ($fixturePath -eq 'ManagementGroup') { 'fixture' } }
                Mock Invoke-AzRestMethodWithRetry {
                    $firstId = '11111111-1111-1111-1111-111111111111'
                    $secondId = '22222222-2222-2222-2222-222222222222'
                    $ids = if ($fixturePath -eq 'ManagementGroup') { @($firstId, $secondId) } elseif ($Path -like "*/$secondId/*") { @($secondId) } else { @($firstId) }
                    $columns = @(@{ name = 'BillingMonth'; type = 'Number' }, @{ name = 'Cost'; type = 'Number' }, @{ name = 'SubscriptionId'; type = 'String' })
                    if ($fixtureCurrency -ne 'missing') { $columns += @{ name = 'Currency'; type = 'String' } }
                    $rows = @(foreach ($subscriptionId in $ids) {
                            $row = @([int](Get-Date).AddMonths(-1).ToString('yyyyMM01'), 100, $subscriptionId)
                            if ($fixtureCurrency -ne 'missing') { $row += $(if ($fixtureCurrency -eq 'blank') { '' } elseif ($fixtureCurrency -eq 'mixed' -and $subscriptionId -eq $secondId) { 'EUR' } else { 'USD' }) }
                            , $row
                        })
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = $columns; rows = $rows } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' })
                if ($fixturePath -ne 'Single') { $subscriptions += [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' } }

                if ($Valid) {
                    $result = Get-CostTrend -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                    $result.Months[0].Cost | Should -Be 200
                    $result.Months[0].Currency | Should -Be 'USD'
                }
                else {
                    { Get-CostTrend -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions } | Should -Throw '*currency*'
                }
            }
        }
    }

    Context 'Cost-only scan failures' {
        It 'Does not return a successful scan after a failed continuation (<Scan>)' -ForEach @(
            @{ Scan = 'Trend' }
            @{ Scan = 'SharedAllocation' }
            @{ Scan = 'Savings' }
            @{ Scan = 'SavingsFallback' }
            @{ Scan = 'UnitEconomics' }
        ) {
            $firstPage = Get-FakeResponse -NextLink '/subscriptions/x/q?page=2'
            InModuleScope FinOpsMultitool -Parameters @{ Scan = $Scan; FirstPage = $firstPage } {
                param($Scan, $FirstPage)

                $scanName = $Scan
                $initialResponse = $FirstPage
                Mock Search-AzGraphSafe { [pscustomobject]@{ Data = @() } }
                Mock Resolve-CostMgId { if ($scanName -eq 'SavingsFallback') { 'test-management-group' } }
                Mock Test-CostMgCoverage { $true }
                Mock Get-StorageAccountUsedGb { 0.0 }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    if ($scanName -eq 'SavingsFallback' -and $Path -like '/subscriptions/*') {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $initialResponse
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })
                if ($scanName -eq 'SavingsFallback') {
                    $subscriptions += [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'second' }
                }
                {
                    switch ($scanName) {
                        'Trend' { Get-CostTrend -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                        'SharedAllocation' { Get-AllocationCostMaps -SubscriptionIds $subscriptions.Id }
                        'Savings' { Get-SavingsRealized -Subscriptions $subscriptions }
                        'SavingsFallback' { Get-SavingsRealized -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                        'UnitEconomics' { Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                    }
                } | Should -Throw '*incomplete*'

                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $Path -like '*page=2' -and $Method -eq 'POST' -and -not [string]::IsNullOrWhiteSpace($Payload)
                }
            }
        }
    }

    Context 'Required first responses' {
        It 'Does not publish totals after a required first response fails (<Scan>)' -ForEach @(
            @{ Scan = 'Trend' }
            @{ Scan = 'TrendPartial' }
            @{ Scan = 'Forecast' }
            @{ Scan = 'Savings' }
            @{ Scan = 'BudgetHistory' }
            @{ Scan = 'AI' }
            @{ Scan = 'UnitEconomics' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scan = $Scan } {
                param($Scan)

                $scanName = $Scan
                Mock Resolve-CostMgId { if ($scanName -ne 'TrendPartial') { 'test-management-group' } }
                Mock Get-StorageAccountUsedGb { 0.0 }
                Mock Search-AzGraphSafe {
                    $rows = if ($scanName -eq 'AI') {
                        @([pscustomobject]@{ type = 'microsoft.cognitiveservices/accounts'; lkind = 'TextAnalytics' })
                    }
                    else { @() }
                    [pscustomobject]@{ Data = $rows }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($scanName -eq 'Forecast' -and $Path -notlike '*forecast*') {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content    = '{"properties":{"columns":[{"name":"Cost"},{"name":"Currency"}],"rows":[[100,"USD"]]}}'
                        }
                    }
                    if ($scanName -eq 'TrendPartial' -and $Path -like '/subscriptions/11111111-*') {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content    = '{"properties":{"columns":[{"name":"Cost","type":"Number"},{"name":"BillingMonth","type":"DateTime"},{"name":"Currency","type":"String"}],"rows":[[100,"2026-08-01","USD"]]}}'
                        }
                    }
                    [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'first' })
                if ($scanName -eq 'TrendPartial') {
                    $subscriptions += [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'second' }
                }
                $budgets = @([pscustomobject]@{
                        SubscriptionId = $subscriptions[0].Id; Subscription = 'first'; Amount = 1000; BudgetName = 'test'; TimeGrain = 'Monthly'
                        Category = 'Cost'; Currency = 'USD'; TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-2) }
                    })

                {
                    switch ($scanName) {
                        { $_ -in 'Trend', 'TrendPartial' } { Get-CostTrend -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                        'Forecast' { Get-CostDataPerSubscription -Subscriptions $subscriptions }
                        'Savings' { Get-SavingsRealized -Subscriptions $subscriptions }
                        'BudgetHistory' { Get-BudgetHistory -Budgets $budgets -MonthsBack 1 }
                        'AI' { Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                        'UnitEconomics' { Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions }
                    }
                } | Should -Throw '*incomplete*'
            }
        }

        It 'Requires a successful cost-by-tag batch response (HTTP <StatusCode>)' -ForEach @(
            @{ StatusCode = 200 }
            @{ StatusCode = 503 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ResponseStatus = $StatusCode } {
                param($ResponseStatus)

                Mock Search-AzGraphSafe { [pscustomobject]@{ Data = @() } }
                $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $sessionState.Variables.Add([System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('FixtureStatus', $ResponseStatus, 'Mock response status'))
                $sessionState.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-AzRestMethod', @'
param($Path, $Method, $Payload)
[pscustomobject]@{
    StatusCode = $FixtureStatus
    Content = '{"properties":{"columns":[{"name":"Cost"},{"name":"ResourceId"},{"name":"Currency"}],"rows":[[125,"/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/test","USD"]]}}'
    Headers = @{}
}
'@))
                $pool = [runspacefactory]::CreateRunspacePool(1, 2, $sessionState, $Host)
                $previousPool = $script:RunspacePool
                try {
                    $pool.Open()
                    $script:RunspacePool = $pool
                    $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'first' })
                    $arguments = @{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Subscriptions = $subscriptions; ExistingTags = @{ CostCenter = @{ TotalResources = 1 } } }
                    if ($ResponseStatus -eq 503) {
                        { Get-CostByTag @arguments } | Should -Throw '*503*incomplete*'
                    }
                    else {
                        $result = Get-CostByTag @arguments
                        ($result.CostByTag.CostCenter | Measure-Object Cost -Sum).Sum | Should -Be 125
                    }
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $pool.Dispose()
                }
            }
        }
    }

    Context 'Cost-by-tag coverage and currency' {
        It 'Handles <Scenario> without presenting invalid whole-scope costs' -ForEach @(
            @{ Scenario = 'denied subscription'; ExpectError = $false }
            @{ Scenario = 'failed continuation'; ExpectError = $false }
            @{ Scenario = 'mixed currencies'; ExpectError = $true }
            @{ Scenario = 'mixed currencies reversed'; ExpectError = $true }
            @{ Scenario = 'missing currency'; ExpectError = $true }
            @{ Scenario = 'matching currencies'; ExpectError = $false }
            @{ Scenario = 'failed tag map'; ExpectError = $true }
            @{ Scenario = 'empty successes with denied subscription'; ExpectError = $false }
            @{ Scenario = 'offsetting charges'; ExpectError = $false }
            @{ Scenario = 'empty current month'; ExpectError = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scenario = $Scenario; ExpectError = $ExpectError } {
                param($Scenario, $ExpectError)
                $fixtureScenario = $Scenario
                Mock Search-AzGraphSafe {
                    if ($fixtureScenario -eq 'failed tag map') { throw 'Synthetic tag map is incomplete.' }
                    [pscustomobject]@{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                $sessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $sessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('FixtureScenario', $Scenario, 'Synthetic response scenario'))
                $sessionState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-AzRestMethod', @'
param($Path, $Method, $Payload)
$subscriptionId = ($Path -split '/')[2]
$second = $subscriptionId -eq '22222222-2222-2222-2222-222222222222'
if ($FixtureScenario -in @('denied subscription', 'empty successes with denied subscription') -and $second) { return [pscustomobject]@{ StatusCode = 403; Content = '{}'; Headers = @{} } }
$columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' })
$amount = if ($second) { 50 } elseif ($subscriptionId -like '11111111-*') { 100 } else { 25 }
$row = @($amount, "/subscriptions/$subscriptionId/resourceGroups/fixture/providers/Microsoft.Compute/disks/fixture")
if ($FixtureScenario -ne 'missing currency') {
    $columns += @{ name = 'Currency' }
    $row += $(if (($FixtureScenario -eq 'mixed currencies' -and $second) -or ($FixtureScenario -eq 'mixed currencies reversed' -and -not $second)) { 'EUR' } else { 'USD' })
}
$properties = @{ columns = $columns; rows = @(,$row) }
if ($FixtureScenario -eq 'empty successes with denied subscription' -or ($FixtureScenario -eq 'empty current month' -and ($Payload | ConvertFrom-Json).timeframe -eq 'MonthToDate')) { $properties.rows = @() }
if ($FixtureScenario -eq 'offsetting charges') { $properties.rows += ,@(-$amount, $row[1], 'USD') }
if ($FixtureScenario -eq 'failed continuation' -and $second) { $properties.nextLink = "$Path&page=2" }
[pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8); Headers = @{} }
'@))
                $pool = [runspacefactory]::CreateRunspacePool(1, 2, $sessionState, $Host)
                $previousPool = $script:RunspacePool
                try {
                    $pool.Open()
                    $script:RunspacePool = $pool
                    $subscriptions = @(
                        [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                        [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                        [pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333'; Name = 'Third' }
                    )
                    $arguments = @{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Subscriptions = $subscriptions; ExistingTags = @{ CostCenter = @{ TotalResources = 3 } } }
                    if ($ExpectError) {
                        $expectedMessage = if ($Scenario -eq 'failed tag map') { '*tag map*incomplete*' } else { '*currenc*' }
                        { Get-CostByTag @arguments } | Should -Throw $expectedMessage
                    }
                    else {
                        $result = Get-CostByTag @arguments
                        $partial = $Scenario -in @('denied subscription', 'failed continuation', 'empty successes with denied subscription')
                        $expectedTotal = if ($Scenario -in @('empty successes with denied subscription', 'offsetting charges')) { 0 } elseif ($partial) { 125 } else { 175 }
                        [double]($result.CostByTag.CostCenter | Measure-Object Cost -Sum).Sum | Should -Be $expectedTotal
                        $result.UsedTimeframe | Should -Be $(if ($Scenario -eq 'empty current month') { 'Custom' } else { 'MonthToDate' })
                        $result.CoverageIncomplete | Should -Be $partial
                        $result.ScannedSubs | Should -Be $(if ($partial) { 2 } else { 3 })
                        $result.TotalSubs | Should -Be 3
                        if ($partial) {
                            @($result.FailedSubscriptions).Count | Should -Be 1
                            $result.FailedSubscriptions[0].SubscriptionId | Should -Be $subscriptions[1].Id
                            $result.SuccessfulSubscriptionIds | Should -Contain $subscriptions[2].Id
                            foreach ($kpiId in @('pct-costs-untagged', 'pct-costs-unallocated', 'tagging-policy-compliant')) {
                                $kpi = Get-KpiComputedValue -KpiId $kpiId -Data $result
                                $kpi.Value | Should -BeNullOrEmpty
                                $kpi.Display | Should -Match 'incomplete'
                            }
                        }
                    }
                }
                finally { $script:RunspacePool = $previousPool; $pool.Dispose() }
            }
        }
    }

    Context 'Paged billing discovery' {
        It 'Retains incomplete membership evidence after a partial <FailurePath> match' -Tag 'CommitmentScopeCoverage' -ForEach @(
            @{ FailurePath = 'membership page' }
            @{ FailurePath = 'subscription lookup' }
            @{ FailurePath = 'empty lookup' }
            @{ FailurePath = 'whitespace lookup' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ FailurePath = $FailurePath } {
                param($FailurePath)
                $fixtureFailurePath = $FailurePath
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )
                $accounts = @('unreadable', 'readable') | ForEach-Object {
                    [pscustomobject]@{ name = $_; id = "/providers/Microsoft.Billing/billingAccounts/$_"; properties = @{ displayName = $_; agreementType = 'EnterpriseAgreement' } }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*billingProperty*') {
                        if ($fixtureFailurePath -ne 'membership page' -and $Path -like '*/22222222-*') {
                            return [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"billingAccountId":"/providers/Microsoft.Billing/billingAccounts/readable"}}' }
                        }
                        if ($fixtureFailurePath -in @('empty lookup', 'whitespace lookup')) {
                            return [pscustomobject]@{ StatusCode = 200; Content = $(if ($fixtureFailurePath -eq 'empty lookup') { '' } else { '   ' }) }
                        }
                        return [pscustomobject]@{ StatusCode = $(if ($fixtureFailurePath -eq 'subscription lookup') { 503 } else { 403 }); Content = '{}' }
                    }
                    if ($Path -like '*billingSubscriptions*') {
                        if ($Path -like '*/unreadable/*') {
                            if ($Path -like '*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                            return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(); nextLink = "$Path&page=2" } | ConvertTo-Json) }
                        }
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"properties":{"subscriptionId":"22222222-2222-2222-2222-222222222222"}}]}' }
                    }
                    if ($Path -match '/billingAccounts\?') {
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($accounts) } | ConvertTo-Json -Depth 7) }
                    }
                    if ($Path -match '/readable/.*reservationSummaries\?') {
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"properties":{"reservationId":"fixture-reservation","reservationOrderId":"fixture-order","skuName":"fixture-sku","kind":"Compute","avgUtilizationPercentage":100,"minUtilizationPercentage":100,"maxUtilizationPercentage":100,"usageDate":"2026-09-01"}}]}' }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' }
                }

                $scope = Get-FinOpsBillingScope -BillingAccounts $accounts -Subscriptions $subscriptions
                $billing = Get-BillingStructure -Subscriptions $subscriptions
                $macc = Get-MaccCommitment -Subscriptions $subscriptions
                $utilization = Get-CommitmentUtilization -Subscriptions $subscriptions

                $scope.Resolved | Should -BeTrue
                $scope.Accounts[0].name | Should -Be 'readable'
                $scope.CoverageIncomplete | Should -BeTrue
                $expectedReason = if ($FailurePath -in @('empty lookup', 'whitespace lookup')) { 'no content' } else { '503' }
                ($scope.ReadErrors -join ' ') | Should -Match $expectedReason
                $billing.CoverageIncomplete | Should -BeTrue
                $billing.Note | Should -Match $expectedReason
                $macc.CoverageIncomplete | Should -BeTrue
                $macc.Reason | Should -Match $expectedReason
                $macc.Reason | Should -Not -Match 'No MACC commitment found'
                $utilization.RICount | Should -Be 1
                $utilization.Reservations[0].AvgUtilization | Should -Be 100
                $utilization.CoverageIncomplete | Should -BeTrue
                $utilization.RIAvgUtilization | Should -BeNullOrEmpty
                $utilization.SPAvgUtilization | Should -BeNullOrEmpty
                $utilization.ScopeResolutionErrors | Should -Not -BeNullOrEmpty
                $utilization.Note | Should -Match $expectedReason
            }
        }

        It 'Correlates a selected subscription from a later billing membership page' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*billingProperty*') { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                    $second = $Path -like '*page=2'
                    $body = @{ value = @(@{ properties = @{ subscriptionId = $(if ($second) { '11111111-1111-1111-1111-111111111111' } else { '22222222-2222-2222-2222-222222222222' }) } }) }
                    if (-not $second) { $body.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 6) }
                }

                $result = Get-FinOpsBillingScope -BillingAccounts @([pscustomobject]@{ Name = 'fixture' }) -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' })

                $result.Resolved | Should -BeTrue
                $result.Accounts[0].Name | Should -Be 'fixture'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '*page=2' -and $Method -eq 'GET' }
            }
        }

        It 'Does not invent MACC amounts when the lot currency is absent' {
            InModuleScope FinOpsMultitool {
                Mock Get-FinOpsBillingScope { @{ Resolved = $true; Accounts = $BillingAccounts } }
                Mock Invoke-AzRestMethodWithRetry {
                    $value = if ($Path -like '*/lots?*') { @(@{ properties = @{ source = 'ConsumptionCommitment'; originalAmount = @{ value = 100 }; closedBalance = @{ value = 25 } } }) }
                    else { @(@{ name = 'fixture'; properties = @{ displayName = 'Fixture'; agreementType = 'EnterpriseAgreement' } }) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($value) } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-MaccCommitment -Subscriptions @([pscustomobject]@{ Id = 'fixture' })

                $result.CoverageIncomplete | Should -BeTrue
                $result.Commitments[0].Currency | Should -BeNullOrEmpty
                $result.Commitments[0].Consumed | Should -BeNullOrEmpty
                $result.Commitments[0].Remaining | Should -BeNullOrEmpty
                $result.Reason | Should -Match 'currency'
            }
        }

        It 'Preserves contract probe failures beside subscription inference' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '/subscriptions/*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"subscriptionPolicies":{"quotaId":"EnterpriseAgreement"}}' } }
                    [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                }

                $result = @(Get-ContractInfo -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }))

                $result[0].AgreementType | Should -Be 'EnterpriseAgreement'
                $result[0].CoverageIncomplete | Should -BeTrue
                $result[0].ReadErrors | Should -Match '503'
                $result[0].Note | Should -Match 'not confirmed'
            }
        }

        It 'Includes all MACC lots or reports incomplete coverage (failed page: <PageFails>)' -ForEach @(
            @{ PageFails = $false }
            @{ PageFails = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ PageFails = $PageFails } {
                param($PageFails)
                $failLots = $PageFails
                Mock Get-FinOpsBillingScope { @{ Resolved = $true; Accounts = $BillingAccounts } }
                Mock Invoke-AzRestMethodWithRetry {
                    $second = $Path -like '*page=2'
                    if ($Path -like '*/lots?*') {
                        if ($second -and $failLots) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                        $amount = if ($second) { 200 } else { 100 }
                        $body = @{ value = @(@{ properties = @{ source = 'ConsumptionCommitment'; originalAmount = @{ value = $amount }; closedBalance = @{ value = 25 }; billingCurrency = 'EUR'; status = 'Active' } }) }
                    }
                    else {
                        $body = @{ value = @(@{ name = 'fixture'; properties = @{ displayName = 'Fixture'; agreementType = $(if ($second) { 'EnterpriseAgreement' } else { 'MicrosoftOnlineServicesProgram' }) } }) }
                    }
                    if (-not $second) { $body.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 8) }
                }

                $result = Get-MaccCommitment -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.CoverageIncomplete | Should -Be $PageFails
                if ($PageFails) {
                    $result.Commitments | Should -BeNullOrEmpty
                    $result.Reason | Should -Match 'incomplete'
                    $result.Reason | Should -Not -Match 'No MACC commitment found'
                }
                else {
                    $result.Commitments.Count | Should -Be 2
                    ($result.Commitments | Measure-Object Commitment -Sum).Sum | Should -Be 300
                    ($result.Commitments | Measure-Object Consumed -Sum).Sum | Should -Be 250
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Path -like '*page=2' -and $Method -eq 'GET' }
            }
        }

        It 'Reads every billing hierarchy page and marks a failed section (failed page: <PageFails>)' -ForEach @(
            @{ PageFails = $false }
            @{ PageFails = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ PageFails = $PageFails } {
                param($PageFails)
                $failSection = $PageFails
                Mock Get-FinOpsBillingScope { @{ Resolved = $true; Accounts = $BillingAccounts } }
                Mock Invoke-AzRestMethodWithRetry {
                    $pageNumber = if ($Path -like '*page=2') { 2 } else { 1 }
                    if ($failSection -and $Path -like '*invoiceSections*page=2') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $name = "fixture-$pageNumber"
                    $properties = @{ displayName = $name; name = $name; agreementType = $(if ($pageNumber -eq 1) { 'EnterpriseAgreement' } else { 'MicrosoftCustomerAgreement' }) }
                    $body = @{ value = @(@{ name = $name; id = (($Path -split '\?')[0] + "/$name"); properties = $properties }) }
                    if ($pageNumber -eq 1) { $body.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 8) }
                }

                $result = Get-BillingStructure -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.BillingAccounts.Count | Should -Be 2
                $result.BillingProfiles.Count | Should -Be 2
                $result.EADepartments.Count | Should -Be 2
                $result.CostAllocationRules.Count | Should -Be 4
                $result.CoverageIncomplete | Should -Be $PageFails
                if ($PageFails) {
                    $result.InvoiceSections | Should -BeNullOrEmpty
                    $result.Note | Should -Match 'invoice sections.*incomplete'
                }
                else { $result.InvoiceSections.Count | Should -Be 4 }
            }
        }

        It 'Reads the requested billing account on page two (failed page: <PageFails>)' -ForEach @(
            @{ PageFails = $false }
            @{ PageFails = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ PageFails = $PageFails } {
                param($PageFails)
                $failPage = $PageFails
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*page=2' -and $failPage) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $name = if ($Path -like '*page=2') { 'second' } else { 'first' }
                    $body = @{ value = @(@{ name = $name; properties = @{ displayName = $name; agreementType = 'EnterpriseAgreement' } }) }
                    if ($name -eq 'first') { $body.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 6) }
                }

                $result = Get-BillingAccount -BillingAccountId 'second' -ProbeAccess $false

                $result.CoverageIncomplete | Should -Be $PageFails
                if ($PageFails) { $result.Accounts | Should -BeNullOrEmpty; $result.Note | Should -Match 'incomplete' }
                else { $result.Accounts[0].Id | Should -Be 'second' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '*page=2' -and $Method -eq 'GET' }
            }
        }

        It 'Bounds management-group probes and reserves the tenant root (listed: <RootListed>, readable: <RootReadable>)' -Tag 'ManagementGroupProbeLimit' -ForEach @(
            @{ RootListed = $false; RootReadable = $true }
            @{ RootListed = $true; RootReadable = $true }
            @{ RootListed = $false; RootReadable = $false }
            @{ RootListed = $true; RootReadable = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ RootListed = $RootListed; RootReadable = $RootReadable } {
                param($RootListed, $RootReadable)
                Reset-CostMgScope
                $fixtureRootListed = $RootListed
                $tenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                $probedIds = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { }
                Mock Write-Warning { }
                Mock Get-AzContext { throw 'Probe fixtures must not read an Azure context.' }
                Mock Invoke-RestMethod { throw 'Probe fixtures must not make HTTP requests.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -eq 'GET') {
                        if ($Path -like '*page=2') {
                            $body = @{ value = @(13..100 | ForEach-Object { @{ name = "denied-$_" } }) }
                        }
                        else {
                            $names = @(if ($fixtureRootListed) { @{ name = $tenantId } }) + @(foreach ($number in 1..12) {
                                    @{ name = "denied-$number" }
                                    @{ name = "DENIED-$number" }
                                })
                            $body = @{ value = $names; nextLink = "$Path&page=2" }
                        }
                        return [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 5) }
                    }
                    $mgId = ($Path -split '/managementGroups/')[1].Split('/')[0]
                    [void]$probedIds.Add($mgId)
                    $status = if ($mgId -eq $tenantId -and $RootReadable) { 200 } elseif ($mgId -eq 'denied-1') { 429 } else { 403 }
                    [pscustomobject]@{ StatusCode = $status; Content = '{}' }
                }
                try {
                    $resolved = Resolve-CostMgId -TenantId $tenantId

                    $probedIds.Count | Should -Be 25
                    $probedIds[-1] | Should -Be $tenantId
                    @($probedIds | Where-Object { $_ -eq $tenantId }).Count | Should -Be 1
                    $probedIds[0] | Should -Be 'denied-1'
                    $probedIds[23] | Should -Be 'denied-24'
                    if ($RootReadable) {
                        $resolved | Should -Be $tenantId
                        Test-MgCostScope | Should -BeTrue
                        Resolve-CostMgId -TenantId $tenantId | Should -Be $tenantId
                    }
                    else {
                        $resolved | Should -BeNullOrEmpty
                        Test-MgCostScope | Should -BeFalse
                        Resolve-CostMgId -TenantId $tenantId | Should -BeNullOrEmpty
                    }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Method -eq 'GET' }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 25 -Exactly -ParameterFilter { $Method -eq 'POST' -and $MaxRetries -eq 2 }
                    Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '25.*tenant root' }
                    Should -Invoke Get-AzContext -Times 0 -Exactly
                    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
                }
                finally { Reset-CostMgScope }
            }
        }

        It 'Stops at the first usable child and reuses its scope without a limit warning' -Tag 'ManagementGroupProbeLimit' {
            InModuleScope FinOpsMultitool {
                Reset-CostMgScope
                Mock Write-Host { }
                Mock Write-Warning { }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -eq 'GET') {
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"denied"},{"name":"readable"},{"name":"unused"}]}' }
                    }
                    [pscustomobject]@{ StatusCode = $(if ($Path -like '*/readable/*') { 200 } else { 403 }); Content = '{}' }
                }
                try {
                    Resolve-CostMgId -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' | Should -Be 'readable'
                    Resolve-CostMgId -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' | Should -Be 'readable'

                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Method -eq 'GET' }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Method -eq 'POST' -and $MaxRetries -eq 2 }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -match '/(unused|aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa)/' }
                    Should -Invoke Write-Warning -Times 0 -Exactly
                }
                finally { Reset-CostMgScope }
            }
        }

        It 'Keeps selected-subscription cost coverage after exhausting the probe budget' -Tag 'ManagementGroupProbeLimit' {
            InModuleScope FinOpsMultitool {
                Reset-CostMgScope
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                )
                Mock Write-Host { }
                Mock Write-Warning { }
                Mock Get-AzContext { throw 'Cost fallback fixtures must not read an Azure context.' }
                Mock Invoke-RestMethod { throw 'Cost fallback fixtures must not make HTTP requests.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -eq 'GET') {
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(1..100 | ForEach-Object { @{ name = "denied-$_" } }) } | ConvertTo-Json -Depth 5) }
                    }
                    if ($Path -like '/providers/Microsoft.Management/managementGroups/*') {
                        return [pscustomobject]@{ StatusCode = 403; Content = '{}' }
                    }
                    if ($Path -notmatch '^/subscriptions/(11111111-1111-1111-1111-111111111111|22222222-2222-2222-2222-222222222222)/') { throw 'Unexpected subscription scope.' }
                    $amount = if ($Path -like '*forecast*') { 150 } else { 100 }
                    $responseContent = @{
                        properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @($amount, 'USD')) }
                    } | ConvertTo-Json -Depth 6
                    [pscustomobject]@{ StatusCode = 200; Content = $responseContent }
                }
                try {
                    $costs = Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -RestrictToSelected

                    $costs.Count | Should -Be 2
                    foreach ($subscription in $subscriptions) {
                        $costs[$subscription.Id].Actual | Should -Be 100
                        $costs[$subscription.Id].Forecast | Should -Be 150
                        $costs[$subscription.Id].Currency | Should -Be 'USD'
                    }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 25 -Exactly -ParameterFilter { $Method -eq 'POST' -and $Path -like '/providers/Microsoft.Management/*' -and $MaxRetries -eq 2 }
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 4 -Exactly -ParameterFilter {
                        $Method -eq 'POST' -and $Path -match '^/subscriptions/(11111111-1111-1111-1111-111111111111|22222222-2222-2222-2222-222222222222)/'
                    }
                    Should -Invoke Get-AzContext -Times 0 -Exactly
                    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
                }
                finally { Reset-CostMgScope }
            }
        }

        It 'Does not reuse a <PreviousState> management-group cache across tenants' -Tag 'ManagementGroupProbeLimit' -ForEach @(
            @{ PreviousState = 'resolved'; FirstStatus = 200 }
            @{ PreviousState = 'failed'; FirstStatus = 403 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ FirstStatus = $FirstStatus } {
                param($FirstStatus)
                Reset-CostMgScope
                $fixtureStatus = $FirstStatus
                Mock Write-Host { }
                Mock Get-AzContext { throw 'Tenant cache fixtures must not read an Azure context.' }
                Mock Invoke-RestMethod { throw 'Tenant cache fixtures must not make HTTP requests.' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -eq 'GET') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    $status = if ($Path -like '*/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/*') { $fixtureStatus } else { 200 }
                    [pscustomobject]@{ StatusCode = $status; Content = '{}' }
                }
                try {
                    $null = Resolve-CostMgId -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

                    Resolve-CostMgId -TenantId 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' | Should -Be 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'

                    Test-MgCostScope | Should -BeTrue
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Method -eq 'GET' }
                    foreach ($expectedTenant in @('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')) {
                        Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                            $Method -eq 'POST' -and $Path -like "*/$expectedTenant/*"
                        }
                    }
                    Should -Invoke Get-AzContext -Times 0 -Exactly
                    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
                }
                finally { Reset-CostMgScope }
            }
        }

        It 'Finds a readable management group after the first page and first twelve candidates' -Tag 'ManagementGroupProbeLimit' {
            InModuleScope FinOpsMultitool {
                Reset-CostMgScope
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Method -eq 'GET') {
                        $body = if ($Path -like '*page=2') { @{ value = @(@{ name = 'readable' }) } }
                        else { @{ value = @(1..12 | ForEach-Object { @{ name = "denied-$_" } }); nextLink = "$Path&page=2" } }
                        return [pscustomobject]@{ StatusCode = 200; Content = ($body | ConvertTo-Json -Depth 5) }
                    }
                    [pscustomobject]@{ StatusCode = $(if ($Path -like '*/readable/*') { 200 } else { 403 }); Content = '{}' }
                }
                try {
                    Resolve-CostMgId -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' | Should -Be 'readable'
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -like '*page=2' -and $Method -eq 'GET' }
                }
                finally { Reset-CostMgScope }
            }
        }
    }

    Context 'Savings and unit totals' {
        It 'Completes <Scan> pages and discards failed MG data (fallback: <UseFallback>)' -ForEach @(
            @{ Scan = 'Savings'; UseFallback = $false }
            @{ Scan = 'Savings'; UseFallback = $true }
            @{ Scan = 'UnitEconomics'; UseFallback = $false }
            @{ Scan = 'UnitEconomics'; UseFallback = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scan = $Scan; UseFallback = $UseFallback } {
                param($Scan, $UseFallback)

                $scanName = $Scan
                $failManagementGroup = $UseFallback
                Mock Search-AzGraphSafe { [pscustomobject]@{ Data = @() } }
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Test-CostMgCoverage { $true }
                Mock Get-StorageAccountUsedGb { 0.0 }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $isNextPage = $Path -like '*page=2'
                    if ($failManagementGroup -and $request.type -eq 'AmortizedCost' -and $Path -like '/providers/Microsoft.Management/*' -and $isNextPage) {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $amount = if ($isNextPage) { 25.0 } else { 100.0 }
                    $dimension = if ($scanName -eq 'UnitEconomics') { 'MeterCategory' } elseif ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = switch ($dimension) {
                        'MeterCategory' { if ($isNextPage) { 'Storage' } else { 'Virtual Machines' } }
                        'ChargeType' { 'UnusedReservation' }
                        'PricingModel' { if ($isNextPage) { 'SavingsPlan' } else { 'Reservation' } }
                    }
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = $dimension }, @{ name = 'Currency' })
                        rows    = @(, @($amount, $category, 'USD'))
                    }
                    if (-not $isNextPage) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'first' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'second' }
                )

                $factor = if ($UseFallback) { 2 } else { 1 }
                if ($Scan -eq 'Savings') {
                    $result = Get-SavingsRealized -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -WarningAction SilentlyContinue
                    $result.CommittedAmortized | Should -Be (125 * $factor)
                    $result.RISavingsMonthToDate | Should -Be ([math]::Round(100 * $factor * 0.4 / 0.6, 2))
                    $result.SPSavingsMonthToDate | Should -Be ([math]::Round(25 * $factor * 0.25 / 0.75, 2))
                    $result.Currency | Should -Be 'USD'
                    $result.TotalAnnual | Should -BeNullOrEmpty
                    $waste = @($result.Details | Where-Object Type -EQ 'Waste')
                    ($waste | Measure-Object -Property Amount -Sum).Sum | Should -Be (125 * $factor)
                    $continuationCalls = if ($UseFallback) { 6 } else { 2 }
                }
                else {
                    $result = Get-UnitEconomics -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -WarningAction SilentlyContinue
                    $result.ComputeCost | Should -Be (100 * $factor)
                    $result.StorageCost | Should -Be (25 * $factor)
                    $result.CostPeriodStartUtc.Kind | Should -Be ([DateTimeKind]::Utc)
                    $result.CostPeriodEndUtc.Kind | Should -Be ([DateTimeKind]::Utc)
                    $expectedStart = $result.CostPeriodStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $expectedEnd = $result.CostPeriodEndUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter {
                        $request = $Payload | ConvertFrom-Json
                        $request.timeframe -ne 'Custom' -or
                        ([datetime]$request.timePeriod.from).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -ne $expectedStart -or
                        ([datetime]$request.timePeriod.to).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -ne $expectedEnd
                    }
                    $continuationCalls = if ($UseFallback) { 3 } else { 1 }
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $continuationCalls -Exactly -ParameterFilter {
                    $Path -like '*page=2' -and $Method -eq 'POST' -and -not [string]::IsNullOrWhiteSpace($Payload)
                }
            }
        }
    }

    Context 'Root-level nextLink' {
        # The Consumption and benefit list APIs return nextLink at the root,
        # while the Cost Management query API nests it under properties.
        BeforeAll {
            $script:RootLinkResponse = [PSCustomObject]@{
                StatusCode = 200
                Content    = (@{ value = @(1); nextLink = 'https://management.azure.com/next?page=2' } | ConvertTo-Json)
            }
        }

        It 'Follows it when RootNextLink is requested' {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                [PSCustomObject]@{ StatusCode = 200; Content = (@{ value = @(2) } | ConvertTo-Json) }
            }

            $pages = @(Get-CostQueryResponsePage -FirstResponse $script:RootLinkResponse -RootNextLink)

            $pages.Count | Should -Be 2
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and [string]::IsNullOrEmpty($Payload)
            }
        }

        It 'Rejects a list response without RootNextLink rather than missing its continuation' {
            { Get-CostQueryResponsePage -FirstResponse $script:RootLinkResponse } | Should -Throw '*missing query rows or columns*'
        }
    }

    Context 'nextLink validation' {
        # nextLink is service-supplied. A relative or malformed value yields an
        # empty PathAndQuery rather than throwing, and a foreign host would be
        # rewritten onto the ARM host, so both are rejected.
        It 'Accepts <Case>' -ForEach @(
            @{ Case = 'an absolute ARM url'; Link = 'https://management.azure.com/subscriptions/x/q?api-version=2023-11-01' }
            @{ Case = 'a rooted relative path'; Link = '/subscriptions/x/q?api-version=2023-11-01' }
        ) {
            Resolve-NextLinkPath -NextLink $Link | Should -Not -BeNullOrEmpty
        }

        It 'Rejects <Case>' -ForEach @(
            @{ Case = 'a foreign host'; Link = 'https://evil.example.com/steal?a=1' }
            @{ Case = 'a non-https scheme'; Link = 'http://management.azure.com/x' }
            @{ Case = 'a malformed value'; Link = 'not a url' }
            @{ Case = 'a protocol-relative URL'; Link = '//example.com/page2' }
            @{ Case = 'a backslash path'; Link = '/\example.com/page2' }
            @{ Case = 'an empty value'; Link = '' }
            @{ Case = 'a null value'; Link = $null }
        ) {
            Resolve-NextLinkPath -NextLink $Link | Should -BeNullOrEmpty
        }

        It 'Strips the host so the request stays on the ARM endpoint' {
            Resolve-NextLinkPath -NextLink 'https://management.azure.com/subscriptions/x/q?a=1' |
            Should -Be '/subscriptions/x/q?a=1'
        }
    }
}
