# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'FinOps Multitool safety' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:ModuleRoot = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool'
        $script:MultitoolModule = Join-Path $script:ModuleRoot 'FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Every command the module calls actually resolves' {

        # A cleanup commit once deleted a helper and left its caller behind, so
        # the scan threw CommandNotFoundException on its normal success path.
        It 'Has no calls to undefined internal commands' {
            $files = Get-ChildItem -Path $script:ModuleRoot -Recurse -Include *.ps1, *.psm1 -File

            # Sibling private functions live one level up and are legitimate callees.
            $defFiles = Get-ChildItem -Path (Join-Path $script:ModuleRoot '..') -Recurse -Include *.ps1, *.psm1 -File

            $defined = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $optional = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $called = @{}

            foreach ($file in $defFiles) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null)
                foreach ($fn in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
                    [void]$defined.Add($fn.Name)
                }
            }

            foreach ($file in $files) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null)

                foreach ($cmd in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                    $name = $cmd.GetCommandName()
                    if (-not $name) { continue }

                    # A name probed through Get-Command is an optional callback,
                    # so its absence is deliberate rather than a broken call.
                    if ($name -eq 'Get-Command') {
                        foreach ($el in $cmd.CommandElements) {
                            if ($el -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                                [void]$optional.Add($el.Value)
                            }
                        }
                        continue
                    }

                    if (-not $called.ContainsKey($name)) {
                        $called[$name] = '{0}:{1}' -f $file.Name, $cmd.Extent.StartLineNumber
                    }
                }
            }

            # Az cmdlets are excluded so the assertion does not depend on which
            # Az modules happen to be installed on the runner.
            $unresolved = foreach ($name in $called.Keys) {
                if ($defined.Contains($name)) { continue }
                if ($optional.Contains($name)) { continue }
                if ($name -match '^(Az|AzureRm)' -or $name -match '-Az') { continue }
                if (Get-Command -Name $name -ErrorAction SilentlyContinue) { continue }
                '{0}  (called at {1})' -f $name, $called[$name]
            }

            @($unresolved) -join "`n" | Should -BeNullOrEmpty
        }
    }

    Context 'Allocation percentages' {

        It 'Normalizes uneven shares to exactly 100' {
            $r = ConvertTo-AllocationPercentage -Targets @(
                @{ subscriptionId = 'a'; allocatedShared = 33.333 }
                @{ subscriptionId = 'b'; allocatedShared = 33.333 }
                @{ subscriptionId = 'c'; allocatedShared = 33.334 }
            )

            $r.Ok | Should -BeTrue
            ($r.Values | ForEach-Object { $_.percentage } | Measure-Object -Sum).Sum | Should -Be 100
        }

        It 'Reports failure instead of inventing percentages' {
            (ConvertTo-AllocationPercentage -Targets @()).Ok | Should -BeFalse
            (ConvertTo-AllocationPercentage -Targets @(
                    @{ subscriptionId = 'a'; allocatedShared = 0 }
                )).Ok | Should -BeFalse
        }
    }

    Context 'Export amounts parse invariantly' {

        It 'Reads a decimal point as a decimal point regardless of culture' {
            $original = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                # In de-DE '.' is the thousands separator, so a culture-sensitive
                # parse turns 123.45 into 12345.
                [System.Threading.Thread]::CurrentThread.CurrentCulture =
                [System.Globalization.CultureInfo]::new('de-DE')

                ConvertTo-ExportAmount '123.45' | Should -Be 123.45
                ConvertTo-ExportAmount '1,234.56' | Should -Be 1234.56
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $original
            }
        }

        It 'Returns zero for values that are not numbers' {
            ConvertTo-ExportAmount 'not-a-number' | Should -Be 0
            ConvertTo-ExportAmount '' | Should -Be 0
        }
    }

    Context 'KQL literal escaping' {

        It 'Leaves no quote that could terminate the enclosing literal' {
            $escaped = ConvertTo-KqlLiteral "Subscription Id']) | extend injected = true //"
            [regex]::Matches($escaped, "(?<!\\)'").Count | Should -Be 0
        }

        It 'Escapes the backslash before the quote so evasion fails' {
            # Escaping in the other order would leave \' exploitable.
            $escaped = ConvertTo-KqlLiteral "abc\' or 1==1 //"
            [regex]::Matches($escaped, "(?<!\\)'").Count | Should -Be 0
            $escaped | Should -BeExactly "abc\\\' or 1==1 //"
        }
    }

    Context 'Hub subscription scope clause' {

        It 'Returns no clause only when no subscription was requested' {
            Get-FOHubScopeClause -SubscriptionIds @() | Should -BeNullOrEmpty
        }

        It 'Scopes the query to the requested subscriptions' {
            $clause = Get-FOHubScopeClause -SubscriptionIds @('00000000-0000-0000-0000-00000000000a')
            $clause | Should -Match 'SubAccountId has_any'
            $clause | Should -Match '00000000-0000-0000-0000-00000000000a'
        }

        It 'Fails rather than dropping the filter for an unparseable id' {
            # The old character-class check passed 36 hyphens, then an empty
            # clause returned every subscription in the hub.
            { Get-FOHubScopeClause -SubscriptionIds @('------------------------------------') } |
            Should -Throw -ExpectedMessage '*not a subscription GUID*'
            { Get-FOHubScopeClause -SubscriptionIds @('/subscriptions/00000000-0000-0000-0000-00000000000a') } |
            Should -Throw
        }
    }

    Context 'Gzip expansion is bounded' {

        It 'Round-trips content that fits the budget' {
            $text = 'hello world'
            $raw = [System.Text.Encoding]::UTF8.GetBytes($text)
            $ms = [System.IO.MemoryStream]::new()
            $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
            $gz.Write($raw, 0, $raw.Length)
            $gz.Dispose()

            Expand-GzipText -Content $ms.ToArray() | Should -Be $text
        }

        It 'Refuses to expand past the byte ceiling' {
            # Highly compressible input stands in for a hostile blob in the
            # export container.
            $raw = [byte[]]::new(1MB)
            $ms = [System.IO.MemoryStream]::new()
            $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
            $gz.Write($raw, 0, $raw.Length)
            $gz.Dispose()

            Expand-GzipText -Content $ms.ToArray() -MaxBytes 1024 -WarningAction SilentlyContinue |
            Should -BeNullOrEmpty
        }
    }
}

Describe 'FinOps Multitool cost math' {

    BeforeAll {
        $script:ModuleRoot = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool'
        Import-Module (Join-Path $script:ModuleRoot 'FinOpsMultitool.psm1') -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Cost column resolution' {

        It 'Resolves Cost and not CostStatus when both are present' {
            InModuleScope FinOpsMultitool {
                $columns = @(
                    [pscustomobject]@{ name = 'Cost' }
                    [pscustomobject]@{ name = 'SubscriptionId' }
                    [pscustomobject]@{ name = 'CostStatus' }
                )
                Get-CostColumnIndex -Columns $columns -Names @('cost', 'pretaxcost', 'costusd') |
                Should -Be 0
            }
        }

        It 'Reports -1 rather than guessing when the column is absent' {
            InModuleScope FinOpsMultitool {
                $columns = @([pscustomobject]@{ name = 'CostStatus' })
                Get-CostColumnIndex -Columns $columns -Names @('cost') | Should -Be -1
            }
        }
    }

    Context 'Forecast requests' {

        It 'Requests the full month before summing actual and forecast rows (<QueryPath>)' -ForEach @(
            @{ QueryPath = 'PerSubscription' }
            @{ QueryPath = 'ManagementGroup' }
            @{ QueryPath = 'ManagementGroupFallback' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath } {
                param($QueryPath)

                Mock Get-Date { [datetime]'2026-09-16T12:00:00Z' }
                Mock Get-Date { [datetime]'2026-09-01T00:00:00' } -ParameterFilter { $Day -eq 1 }
                Mock Resolve-CostMgId { 'mock-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*forecast*') {
                        if ($QueryPath -eq 'ManagementGroupFallback' -and $Path -like '/providers/Microsoft.Management/*') {
                            return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                        }
                        $forecastRequest = $Payload | ConvertFrom-Json
                        $forecastRows = @(, @(250.0, 'Forecast', '11111111-1111-1111-1111-111111111111', 'USD'))
                        if ($forecastRequest.timePeriod.from -eq '2026-09-01') {
                            $forecastRows = @(
                                @(100.0, 'Actual', '11111111-1111-1111-1111-111111111111', 'USD'),
                                @(250.0, 'Forecast', '11111111-1111-1111-1111-111111111111', 'USD')
                            )
                        }
                        $body = @{
                            properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'CostStatus' }, @{ name = 'SubscriptionId' }, @{ name = 'Currency' })
                                rows    = $forecastRows
                            }
                        }
                    }
                    else {
                        $body = @{
                            properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }, @{ name = 'SubscriptionId' })
                                rows    = @(, @(100.0, 'USD', '11111111-1111-1111-1111-111111111111'))
                            }
                        }
                    }
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = ($body | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })
                $result = if ($QueryPath -eq 'PerSubscription') {
                    Get-CostDataPerSubscription -Subscriptions $subs
                }
                else {
                    Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subs
                }

                $entry = $result['11111111-1111-1111-1111-111111111111']
                $entry.Actual | Should -Be 100
                $entry.Forecast | Should -Be 350
                $entry.ForecastSource | Should -Be 'Forecast'
                $forecastCalls = if ($QueryPath -eq 'ManagementGroupFallback') { 2 } else { 1 }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $forecastCalls -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $Path -like '*forecast*' -and $Method -eq 'POST' -and
                    $request.timePeriod.from -eq '2026-09-01' -and
                    $request.timePeriod.to -eq '2026-09-30' -and
                    $request.includeActualCost -eq $true
                }
            }
        }

        It 'Rejects an unavailable forecast instead of returning actual spend as a projection' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*forecast*') {
                        return [pscustomobject]@{ StatusCode = 404; Content = '{}' }
                    }
                    $body = @{
                        properties = @{
                            columns = @(@{ name = 'Cost' }, @{ name = 'Currency' })
                            rows    = @(, @(100.0, 'USD'))
                        }
                    }
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = ($body | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'test' })
                { Get-CostDataPerSubscription -Subscriptions $subs } | Should -Throw '*Forecast*404*incomplete*'
            }
        }
    }

    Context 'Export scope' {

        It 'Ignores rows for subscriptions that were not selected' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'

                $exportData = [pscustomobject]@{
                    Currency = 'USD'
                    ColMap   = [pscustomobject]@{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId'; ResourceId = $null }
                    Rows     = @(
                        [pscustomobject]@{ SubscriptionId = $selected; Cost = '10.00' }
                        [pscustomobject]@{ SubscriptionId = $other; Cost = '999.00' }
                    )
                }
                $subs = @([pscustomobject]@{ Id = $selected; Name = 'selected' })

                $map = ConvertTo-CostDataFromExport -ExportData $exportData -Subscriptions $subs

                $map.Keys | Should -Not -Contain $other
                @($map.Keys).Count | Should -Be 1
                $map[$selected].Actual | Should -Be 10
            }
        }
    }

    Context 'Commitment utilization' {

        It 'Ignores a family that has no commitments' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 10; RIAvgUtilization = 100; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data) | Should -Be @(100)
            }
        }

        It 'Keeps a real 0% when commitments exist' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 3; RIAvgUtilization = 0; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data) | Should -Be @(0)
            }
        }

        It 'Reports nothing when no commitments were found at all' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 0; RIAvgUtilization = 0; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data).Count | Should -Be 0
            }
        }
    }

    Context 'Hourly cost reporting' {
        It 'Uses the UTC month instead of a local calendar that is still in August' {
            InModuleScope FinOpsMultitool {
                Mock Get-Date { [datetime]::new(2026, 9, 1, 2, 0, 0, [DateTimeKind]::Utc) }
                Mock Get-Date { [datetime]::new(2026, 8, 1) } -ParameterFilter { $Day -eq 1 }
                $data = [pscustomobject]@{ CostPerVCpu = 2.0; Currency = 'USD' }

                $result = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $data

                $result.Value | Should -Be 1.0
            }
        }

        It 'Uses the captured cost window when the report is rendered later' {
            InModuleScope FinOpsMultitool {
                Mock Get-Date { [datetime]::new(2026, 10, 2, 0, 0, 0, [DateTimeKind]::Utc) }
                Mock Get-Date { [datetime]::new(2026, 10, 1) } -ParameterFilter { $Day -eq 1 }
                $data = [pscustomobject]@{
                    CostPerVCpu = 384.0
                    Currency = 'USD'
                    CostPeriodStartUtc = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                    CostPeriodEndUtc = [datetime]::new(2026, 9, 17, 0, 0, 0, [DateTimeKind]::Utc)
                }

                $result = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $data

                $result.Value | Should -Be 1.0
                Should -Invoke Get-Date -Times 0 -Exactly
            }
        }
    }
}
