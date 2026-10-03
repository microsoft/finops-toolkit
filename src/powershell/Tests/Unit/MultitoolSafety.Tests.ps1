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
        It 'Has no calls to undefined internal commands (<CommandPlatform>)' -ForEach @(
            @{ CommandPlatform = 'host'; HideWindowsCommands = $false }
            @{ CommandPlatform = 'without Windows cmdlets'; HideWindowsCommands = $true }
        ) {
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
                    if ((-not $IsWindows -or $HideWindowsCommands) -and $file.Name -eq 'Read-FinOpsHubData.ps1' -and
                        $name -in @('Get-Acl', 'Get-AuthenticodeSignature')) { continue }

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
                if (-not ($HideWindowsCommands -and $name -in @('Get-Acl', 'Get-AuthenticodeSignature')) -and
                    (Get-Command -Name $name -ErrorAction SilentlyContinue)) { continue }
                '{0}  (called at {1})' -f $name, $called[$name]
            }

            @($unresolved) -join "`n" | Should -BeNullOrEmpty
        }
    }

    Context 'Read-only scanner invariant' {
        BeforeAll {
            function Get-ScannerWriteCommand {
                param([System.Management.Automation.Language.Ast]$Ast)
                foreach ($command in $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                    $name = $command.GetCommandName()
                    if (-not $name) { continue }
                    $name = ($name -split '\\')[-1]
                    if (($name -match '-Az[A-Za-z0-9]*$' -and $name -notmatch '^(Get|Find|Search|Test|Measure|Read|Resolve)-Az' -and
                            $name -notin @('New-AzStorageContext', 'Invoke-AzRestMethod', 'Invoke-AzRestMethodWithRetry', 'Invoke-AzGraphQueryPage', 'Invoke-AzOperationalInsightsQuery')) -or $name -in @('Invoke-Expression', 'iex')) {
                        "$name at line $($command.Extent.StartLineNumber)"
                    }
                    if ($name -in @('Invoke-AzRestMethod', 'Invoke-AzRestMethodWithRetry', 'Invoke-WebRequest', 'Invoke-RestMethod')) {
                        for ($elementIndex = 1; $elementIndex -lt $command.CommandElements.Count; $elementIndex++) {
                            $element = $command.CommandElements[$elementIndex]
                            if ($element -isnot [System.Management.Automation.Language.CommandParameterAst] -or $element.ParameterName -ne 'Method') { continue }
                            $argument = if ($element.Argument) { $element.Argument } elseif ($elementIndex + 1 -lt $command.CommandElements.Count) { $command.CommandElements[$elementIndex + 1] } else { $null }
                            if ($argument -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $argument.Value -in @('PUT', 'PATCH', 'DELETE')) {
                                "$name $($argument.Value) at line $($command.Extent.StartLineNumber)"
                            }
                        }
                    }
                }
            }
        }

        It 'Rejects mutating Azure commands in scanner modules and helpers' -Tag 'DeferredReview' {
            $violations = @(foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:ModuleRoot 'modules') -Filter '*.ps1' -Recurse -File) {
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                    Get-ScannerWriteCommand -Ast $ast | ForEach-Object { "$($file.Name): $_" }
                })
            $violations | Should -BeNullOrEmpty
        }

        It 'Documents every private launcher parameter without executing the launcher' -Tag 'DeferredReview' {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
            $launcher = $ast.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Invoke-FinOpsMultitool' }, $true)
            $help = $launcher.GetHelpContent()
            $help.Synopsis | Should -Match 'local reports'
            foreach ($parameter in $launcher.Body.ParamBlock.Parameters) { $help.Parameters.ContainsKey($parameter.Name.VariablePath.UserPath.ToUpperInvariant()) | Should -BeTrue }
        }

        It 'Recognizes <Code> without executing it' -Tag 'DeferredReview' -ForEach @(
            @{ Code = 'Set-AzVM -Name fixture'; Expected = 1 }
            @{ Code = 'Az.Resources\Remove-AzResource -ResourceId fixture'; Expected = 1 }
            @{ Code = 'Invoke-AzResourceAction -Action restart'; Expected = 1 }
            @{ Code = 'Invoke-AzVMRunCommand -VMName fixture'; Expected = 1 }
            @{ Code = 'Suspend-AzSqlDatabase -Name fixture'; Expected = 1 }
            @{ Code = 'Resume-AzSqlDatabase -Name fixture'; Expected = 1 }
            @{ Code = 'Repair-AzVmss -Name fixture'; Expected = 1 }
            @{ Code = 'Export-AzContext -Path fixture.json'; Expected = 1 }
            @{ Code = 'Select-AzSubscription -SubscriptionId fixture'; Expected = 1 }
            @{ Code = 'iex "Set-AzVM -Name fixture"'; Expected = 1 }
            @{ Code = 'Invoke-AzRestMethod -Method DELETE -Path /fixture'; Expected = 1 }
            @{ Code = 'Invoke-WebRequest -Method:PATCH -Uri https://example.invalid'; Expected = 1 }
            @{ Code = 'New-AzStorageContext -UseConnectedAccount -StorageAccountName fixture'; Expected = 0 }
            @{ Code = 'Invoke-AzRestMethod -Method POST -Path /providers/Microsoft.CostManagement/query'; Expected = 0 }
            @{ Code = 'Get-AzVM; "Set-AzVM is documentation, not a call"'; Expected = 0 }
        ) {
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$null, [ref]$null)
            @(Get-ScannerWriteCommand -Ast $ast).Count | Should -Be $Expected
        }
    }

    Context 'Tag inventory evidence' {
        It 'Distinguishes <Failure> from a complete tag inventory' -ForEach @(
            @{ Failure = 'none'; Incomplete = $false }
            @{ Failure = 'tag values'; Incomplete = $true }
            @{ Failure = 'untagged count'; Incomplete = $true }
            @{ Failure = 'untagged details'; Incomplete = $true }
            @{ Failure = 'total count'; Incomplete = $true }
            @{ Failure = 'locations'; Incomplete = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Failure = $Failure; Incomplete = $Incomplete } {
                param($Failure, $Incomplete)
                $fixtureFailure = $Failure
                Mock Search-AzGraphSafe {
                    if ($Query -like '*ResourceTypes*') {
                        if ($fixtureFailure -eq 'tag values') { throw 'Synthetic tag values failure.' }
                        return @{ Data = @([pscustomobject]@{ tagName = 'CostCenter'; tagValue = 'team'; ResourceCount = 3; ResourceTypes = @('fixture') }) }
                    }
                    if ($Query -like '*by tagName, subscriptionId*') {
                        if ($fixtureFailure -eq 'locations') { throw 'Synthetic locations failure.' }
                        return @{ Data = @([pscustomobject]@{ tagName = 'CostCenter'; subscriptionId = '11111111-1111-1111-1111-111111111111'; resourceGroup = 'fixture' }) }
                    }
                    if ($Query -like '*TotalCount*') {
                        if ($fixtureFailure -eq 'total count') { throw 'Synthetic total count failure.' }
                        return @{ Data = @([pscustomobject]@{ TotalCount = 4 }) }
                    }
                    if ($fixtureFailure -eq 'untagged details') { throw 'Synthetic untagged details failure.' }
                    @{ Data = @([pscustomobject]@{ name = 'untagged'; type = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'; location = 'eastus' }) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $queryText = ($Payload | ConvertFrom-Json).query
                    if (($fixtureFailure -eq 'untagged count' -and $queryText -like '*UntaggedCount*') -or
                        ($fixtureFailure -eq 'total count' -and $queryText -match 'TotalCount|TaggedCount')) {
                        return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                    }
                    $column = if ($queryText -like '*UntaggedCount*') { 'UntaggedCount' } elseif ($queryText -like '*TaggedCount*') { 'TaggedCount' } else { 'TotalCount' }
                    $count = if ($column -eq 'UntaggedCount') { 1 } elseif ($column -eq 'TaggedCount') { 3 } else { 4 }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ data = @(@{ $column = $count }) } | ConvertTo-Json -Depth 5) }
                }

                $result = Get-TagInventory -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.CoverageIncomplete | Should -Be $Incomplete
                if ($Incomplete) {
                    $result.TagCoverage | Should -BeNullOrEmpty
                    $result.ReadErrors.Count | Should -BeGreaterThan 0
                    $result.Note | Should -Match 'incomplete'
                }
                else { $result.TagCoverage | Should -Be 75; $result.TotalResources | Should -Be 4 }
                if ($Failure -ne 'tag values') { $result.TagNames.CostCenter.Values[0].Value | Should -Be 'team' }
            }
        }
    }

    Context 'Anomaly alert evidence' {
        It 'Preserves alert labels and counts only anomaly notification rules' {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                $items = if ($Path -like '*alerts?*') {
                    @(
                        @{ name = 'first'; properties = @{ description = 'Describe this alert'; status = 'Active'; definition = @{ type = 'Anomaly' }; details = @{ amount = 0; currentSpend = 0; unit = 'EUR' } } }
                        @{ name = 'second'; properties = @{ costEntityId = '/budgets/monthly'; definition = @{ type = 'Budget' } } }
                        @{ name = 'third'; properties = @{ definition = @{ category = 'Cost'; type = 'Budget' } } }
                        @{ name = 'fourth'; properties = @{} }
                    )
                }
                else { @(@{ name = 'rule'; kind = 'InsightAlert'; properties = @{} }, @{ name = 'other'; kind = 'Email'; properties = @{} }) }
                [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $items } | ConvertTo-Json -Depth 9) }
            }

            $result = Get-AnomalyAlerts -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

            $result.CoverageIncomplete | Should -BeFalse
            $result.AnomalyAlertCount | Should -Be 1
            $result.BudgetAlertCount | Should -Be 2
            $result.ActiveAlertCount | Should -Be 1
            $result.ConfiguredRuleCount | Should -Be 1
            $result.TriggeredAlerts.AlertLabel | Should -Be @('Describe this alert', 'monthly (Budget)', 'Cost Budget', 'fourth')
            $result.TriggeredAlerts[0].Amount | Should -Be 0
            $result.TriggeredAlerts[1].Amount | Should -BeNullOrEmpty
            $result.TriggeredAlerts[1].Unit | Should -BeNullOrEmpty
        }
    }

    Context 'Carbon measurement evidence' {
        It 'Preserves <Scenario> carbon data without inventing headline values' -ForEach @(
            @{ Scenario = 'complete'; Incomplete = $false }
            @{ Scenario = 'failed headline'; Incomplete = $true }
            @{ Scenario = 'denied probes'; Incomplete = $true }
            @{ Scenario = 'zero baseline'; Incomplete = $false }
            @{ Scenario = 'failed recent probe'; Incomplete = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scenario = $Scenario; Incomplete = $Incomplete } {
                param($Scenario, $Incomplete)
                $fixtureScenario = $Scenario
                $probeState = @{ SummaryCalls = 0; Windows = [Collections.Generic.List[string]]::new() }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    if ($fixtureScenario -eq 'denied probes') { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                    if ($request.reportType -eq 'OverallSummaryReport') {
                        $probeState.SummaryCalls++
                        $probeState.Windows.Add([string]$request.dateRange.end)
                        if ($probeState.SummaryCalls -eq 1) {
                            if ($fixtureScenario -eq 'failed recent probe') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                            return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' }
                        }
                        if ($fixtureScenario -eq 'failed headline' -and $probeState.SummaryCalls -gt 2) { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                        $value = @(@{ latestMonthEmissions = 50; previousMonthEmissions = $(if ($fixtureScenario -eq 'zero baseline') { 0 } else { 25 }) })
                    }
                    elseif ($request.reportType -eq 'ItemDetailsReport') { $value = @(@{ itemName = '11111111-1111-1111-1111-111111111111'; latestMonthEmissions = 50 }) }
                    else { $value = @(@{ date = $request.dateRange.end; totalCarbonEmission = 50 }) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $value } | ConvertTo-Json -Depth 6) }
                }

                $result = Get-CarbonMetrics -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.CoverageIncomplete | Should -Be $Incomplete
                if ($Incomplete) {
                    if ($Scenario -eq 'failed recent probe') { $result.TotalEmissionsKg | Should -Be 50; $result.LatestMonth | Should -Be $probeState.Windows[1].Substring(0, 7) }
                    else { $result.TotalEmissionsKg | Should -BeNullOrEmpty; $result.ChangeRatio | Should -BeNullOrEmpty }
                    $result.Note | Should -Match '403|503'
                }
                else {
                    $result.TotalEmissionsKg | Should -Be 50
                    $result.LatestMonth | Should -Be $probeState.Windows[1].Substring(0, 7)
                    ([datetime]$probeState.Windows[1]) | Should -BeLessThan ([datetime]$probeState.Windows[0])
                    if ($Scenario -eq 'zero baseline') { $result.ChangeRatio | Should -BeNullOrEmpty; $result.ChangeValueKg | Should -Be 50 }
                    else { $result.ChangeRatio | Should -Be 100 }
                }
            }
        }
    }

    Context 'Idle VM metric evidence' {
        It 'Classifies <Case> only from measured CPU and network' -ForEach @(
            @{ Case = 'idle'; Cpu = 2; Network = 1MB; Classification = 'Idle'; Failed = $false }
            @{ Case = 'underutilized'; Cpu = 7; Network = 1MB; Classification = 'Underutilized'; Failed = $false }
            @{ Case = 'network active'; Cpu = 4; Network = 20MB; Classification = 'Underutilized'; Failed = $false }
            @{ Case = 'busy'; Cpu = 20; Network = 1MB; Classification = $null; Failed = $false }
            @{ Case = 'measured zero'; Cpu = 0; Network = 0; Classification = 'Idle'; Failed = $false }
            @{ Case = 'missing CPU'; Cpu = $null; Network = 1MB; Classification = $null; Failed = $true }
            @{ Case = 'missing network'; Cpu = 2; Network = $null; Classification = $null; Failed = $true }
            @{ Case = 'denied'; Cpu = 2; Network = 1MB; Classification = $null; Failed = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Case = $Case; Cpu = $Cpu; Network = $Network; Classification = $Classification; Failed = $Failed } {
                param($Case, $Cpu, $Network, $Classification, $Failed)
                $fixtureCase = $Case
                $fixtureCpu = $Cpu
                $fixtureNetwork = $Network
                Mock Search-AzGraphSafe {
                    @{ Data = @([pscustomobject]@{ name = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'; location = 'eastus'; powerState = 'PowerState/running'; vmSize = 'Standard_D2s_v5' }) }
                }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Invoke-WebRequest {
                    if ($fixtureCase -eq 'denied') { throw 'Synthetic HTTP 403.' }
                    $metrics = @(
                        @{ name = @{ value = 'Percentage CPU' }; timeseries = @(@{ data = @(@{ average = $fixtureCpu }) }) }
                        @{ name = @{ value = 'Network In Total' }; timeseries = @(@{ data = @(@{ total = $fixtureNetwork }) }) }
                        @{ name = @{ value = 'Network Out Total' }; timeseries = @(@{ data = @(@{ total = 0 }) }) }
                    )
                    [pscustomobject]@{ Content = (@{ value = $metrics } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-IdleVMs -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.MetricFailures | Should -Be ([int]$Failed)
                $result.EvaluatedVMs | Should -Be (1 - [int]$Failed)
                if ($Classification) { $result.IdleVMs[0].Classification | Should -Be $Classification }
                else { $result.Count | Should -Be 0 }
                Should -Invoke Invoke-WebRequest -Times 0 -Exactly -ParameterFilter { $MaximumRedirection -ne 0 }
            }
        }

        It 'Skips metrics when all virtual machines are deallocated' {
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool { @{ Data = @([pscustomobject]@{ powerState = 'PowerState/deallocated' }) } }
            Mock Get-PlainAccessToken -ModuleName FinOpsMultitool { throw 'No token should be requested.' }

            $result = Get-IdleVMs -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' })

            $result.TotalVMs | Should -Be 1
            $result.Note | Should -Match 'none are running'
            Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times 0 -Exactly
        }
    }

    Context 'Scanner domain behavior' {
        It 'Calculates AHB rates from matching Windows and Linux consumption meters and caches by SKU and region' -Tag 'DeferredReview' {
            InModuleScope FinOpsMultitool {
                $script:AhbRateCache = @{}
                Mock Invoke-RestMethod {
                    @{ Items = @(
                            @{ skuName = 'Example Spot'; meterName = 'Example Spot'; productName = 'Virtual Machines Example Windows'; unitPrice = 0.01 }
                            @{ skuName = 'Example'; meterName = 'Example Low Priority'; productName = 'Virtual Machines Example'; unitPrice = 0.01 }
                            @{ skuName = 'Example'; meterName = 'Example'; productName = 'Virtual Machines Example Windows'; unitPrice = 0 }
                            @{ skuName = 'Example'; meterName = 'Example'; productName = 'Virtual Machines Example Windows'; unitPrice = 0.4 }
                            @{ skuName = 'Example'; meterName = 'Example'; productName = 'Virtual Machines Example'; unitPrice = 0.2 }
                        )
                    }
                }

                $rates = Get-AhbVmRates -VmSize 'Standard_Example' -Region 'eastus'
                $rates.WindowsRate | Should -Be 0.4
                $rates.LinuxRate | Should -Be 0.2
                $rates.HourlyPremium | Should -Be 0.2
                $rates.Ratio | Should -Be 0.5
                Get-AhbVmSavingsRatio -VmSize 'standard_example' -Region 'EASTUS' | Should -Be 0.5
                $null = Get-AhbVmRates -VmSize 'Standard_Example' -Region 'westus'
                $null = Get-AhbVmRates -VmSize 'Standard_Other' -Region 'eastus'
                Should -Invoke Invoke-RestMethod -Times 3 -Exactly
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { [uri]::UnescapeDataString($Uri) -like "*armRegionName eq 'eastus' and armSkuName eq 'Standard_Example' and priceType eq 'Consumption' and serviceName eq 'Virtual Machines'*" }
            }
        }

        It 'Retains the documented AHB fallback for <Scenario>' -Tag 'DeferredReview' -ForEach @(
            @{ Scenario = 'no prices'; Failure = 'empty' }
            @{ Scenario = 'missing Linux price'; Failure = 'windows only' }
            @{ Scenario = 'invalid premium'; Failure = 'reversed' }
            @{ Scenario = 'lookup failure'; Failure = 'throw' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Failure = $Failure } {
                param($Failure)
                $fixtureFailure = $Failure
                $script:AhbRateCache = @{}
                Mock Invoke-RestMethod {
                    if ($fixtureFailure -eq 'throw') { throw 'Synthetic retail lookup failure.' }
                    $items = @()
                    if ($fixtureFailure -ne 'empty') { $items += @{ skuName = 'Example'; meterName = 'Example'; productName = 'Virtual Machines Example Windows'; unitPrice = 0.4 } }
                    if ($fixtureFailure -eq 'reversed') { $items += @{ skuName = 'Example'; meterName = 'Example'; productName = 'Virtual Machines Example'; unitPrice = 0.8 } }
                    @{ Items = $items }
                }

                Get-AhbVmRates -VmSize 'Standard_Example' -Region 'eastus' | Should -BeNullOrEmpty
                Get-AhbVmSavingsRatio -VmSize 'Standard_Example' -Region 'eastus' | Should -Be 0.6
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            }
        }

        It 'Prioritizes high-impact legacy resources and preserves category counts' {
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                $rows = if ($Query -like '*publicipaddresses*') { @([pscustomobject]@{ name = 'basic-ip'; sku = 'Basic' }) }
                elseif ($Query -like '*microsoft.compute/disks*') { @([pscustomobject]@{ name = 'hdd'; diskSizeGb = 256; sku = 'Standard_LRS' }) }
                else { @() }
                @{ Data = $rows }
            }

            $result = Get-LegacyResources -Subscriptions @([pscustomobject]@{ Id = 'fixture' })

            $result.TotalCount | Should -Be 2
            $result.LegacyResources[0].Impact | Should -Be 'High'
            $result.LegacyResources[1].Detail | Should -Match '256 GB'
            @($result.ByCategory | Where-Object Count -EQ 1).Count | Should -Be 2
        }

        It 'Labels AHB retail estimates and preserves unavailable per-VM rates' {
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                @{ Data = $(if ($Query -like '*microsoft.compute/virtualmachines*') {
                            @([pscustomobject]@{ name = 'priced'; vmSize = 'known'; location = 'eastus' }, [pscustomobject]@{ name = 'unpriced'; vmSize = 'unknown'; location = 'eastus' })
                        }
                        else { @() })
                }
            }
            Mock Get-AhbVmRates -ModuleName FinOpsMultitool { if ($VmSize -eq 'known') { @{ HourlyPremium = 0.1 } } }

            $result = Get-AHBOpportunities -Subscriptions @([pscustomobject]@{ Id = 'fixture' })

            $result.TotalOpportunities | Should -Be 2
            $result.EstMonthlyVMSavings | Should -Be 73
            $result.SavingsCurrency | Should -Be 'USD'
            ($result.WindowsVMs | Where-Object name -EQ 'unpriced').estMonthlySavings | Should -BeNullOrEmpty
        }

        It 'Matches tag spelling and variants without losing the original tag name' {
            $result = Get-TagRecommendations -ExistingTags @{ 'COST-CENTER' = @{}; 'BusinessUnit' = @{} } -TagLocations @{ 'COST-CENTER' = @('Fixture / rg') }

            $result.Present.Count | Should -Be 2
            $result.MissingRequired.Count | Should -Be 5
            $result.CompliancePercent | Should -Be 29
            $costCenter = $result.Analysis | Where-Object TagName -EQ 'CostCenter'
            $costCenter.Status | Should -Match 'Variation found'
            $costCenter.ActualTagName | Should -BeExactly 'COST-CENTER'
            $costCenter.Location | Should -Be 'Fixture / rg'
        }

        It 'Allocates a shared pool once per case-insensitive spoke and reconciles the split' {
            Mock Resolve-SharedCostPool -ModuleName FinOpsMultitool { @([pscustomobject]@{ Id = 'pool'; Name = 'Pool'; Type = 'fixture'; SubscriptionId = 'hub' }) }
            Mock Get-AllocationCostMaps -ModuleName FinOpsMultitool { @{ ByResource = @{ pool = 1000 }; BySub = @{ 'spoke-a' = 200; 'spoke-b' = 300 }; Currency = 'EUR'; Source = 'LiveApi'; Period = 'MonthToDate' } }

            $result = Get-SharedCostAllocation -SharedResourceIds 'pool' -Spokes @('spoke-a', 'spoke-b', 'SPOKE-A') -WeightingValues @{ 'spoke-a' = 3; 'spoke-b' = 1 } -FixedRatio 0.5

            $result.Allocations.Count | Should -Be 2
            ($result.Allocations | Where-Object Spoke -EQ 'spoke-a').AllocatedShared | Should -Be 625
            ($result.Allocations | Where-Object Spoke -EQ 'spoke-b').SolutionCost | Should -Be 675
            ($result.Allocations | Measure-Object AllocatedShared -Sum).Sum | Should -Be 1000
            ($result.RuleTargets | Measure-Object percentage -Sum).Sum | Should -Be 100
            $result.Currency | Should -Be 'EUR'
        }

        It 'Keeps usage-weighted allocation nonnegative and reconciles <Amount> across <Consumers> consumers' -ForEach @(
            @{ Amount = 100; Consumers = 3 }
            @{ Amount = 0.03; Consumers = 5 }
            @{ Amount = 0.01; Consumers = 9 }
        ) {
            $fixtureConsumers = $Consumers
            Mock Get-TelemetryWeighting -ModuleName FinOpsMultitool {
                $weights = @{}
                foreach ($consumer in 1..$fixtureConsumers) { $weights["consumer-$consumer"] = 1 }
                [pscustomobject]@{ Ok = $true; Weights = $weights; ConsumerDimension = 'KubernetesNamespace'; Source = 'Fixture'; Note = '' }
            }
            Mock Resolve-SharedCostPool -ModuleName FinOpsMultitool { throw 'Explicit pools must not query resources.' }

            $result = Get-UsageProportionalAllocation -WorkspaceId 'fixture' -PoolAmount $Amount -PoolCurrency 'EUR' -PoolPeriod '2026-08'

            ($result.Allocations | Measure-Object AllocatedCost -Sum).Sum | Should -Be $Amount
            @($result.Allocations | Where-Object { $_.AllocatedCost -lt 0 }).Count | Should -Be 0
            $result.Currency | Should -Be 'EUR'
            $result.Period | Should -Be '2026-08'
            $result.Mode | Should -Be 'Showback'
            $result.BillingWritable | Should -BeFalse
            $result.RuleTargets | Should -BeNullOrEmpty
            Should -Invoke Resolve-SharedCostPool -ModuleName FinOpsMultitool -Times 0 -Exactly
        }
    }

    Context 'Storage tier metric evidence' {
        It 'Distinguishes <Case> from valid activity measurements' -ForEach @(
            @{ Case = 'empty transactions'; TransactionPoints = @(); CapacityPoints = @(@{ average = 10GB }); ExpectedFailures = 1; ExpectedRecommendations = 0 }
            @{ Case = 'null transactions'; TransactionPoints = @(@{ total = $null }); CapacityPoints = @(@{ average = 10GB }); ExpectedFailures = 1; ExpectedRecommendations = 0 }
            @{ Case = 'invalid transactions'; TransactionPoints = @(@{ total = 'invalid' }); CapacityPoints = @(@{ average = 10GB }); ExpectedFailures = 1; ExpectedRecommendations = 0 }
            @{ Case = 'empty capacity'; TransactionPoints = @(@{ total = 0 }); CapacityPoints = @(); ExpectedFailures = 1; ExpectedRecommendations = 0 }
            @{ Case = 'negative capacity'; TransactionPoints = @(@{ total = 0 }); CapacityPoints = @(@{ average = -1 }); ExpectedFailures = 1; ExpectedRecommendations = 0 }
            @{ Case = 'measured zero transactions'; TransactionPoints = @(@{ total = 0 }); CapacityPoints = @(@{ average = 10GB }); ExpectedFailures = 0; ExpectedRecommendations = 1 }
            @{ Case = 'measured active storage'; TransactionPoints = @(@{ total = 2000 }); CapacityPoints = @(@{ average = 10GB }); ExpectedFailures = 0; ExpectedRecommendations = 0 }
        ) {
            $fixtureTransactions = $TransactionPoints
            $fixtureCapacity = $CapacityPoints
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                @{ Data = @([pscustomobject]@{ name = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'; accessTier = 'Hot'; sku = 'Standard_LRS' }) }
            }
            Mock Get-PlainAccessToken -ModuleName FinOpsMultitool { 'synthetic-token' }
            Mock Invoke-WebRequest -ModuleName FinOpsMultitool {
                $points = if ($Uri -like '*metricnames=Transactions*') { $fixtureTransactions } else { $fixtureCapacity }
                [pscustomobject]@{ Content = (@{ value = @(@{ timeseries = @(@{ data = @($points) }) }) } | ConvertTo-Json -Depth 8) }
            }

            $result = Get-StorageTierAdvice -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

            $result.MetricFailures | Should -Be $ExpectedFailures
            $result.EvaluatedAccounts | Should -Be (1 - $ExpectedFailures)
            @($result.Recommendations).Count | Should -Be $ExpectedRecommendations
            Should -Invoke Invoke-WebRequest -ModuleName FinOpsMultitool -Times 0 -Exactly -ParameterFilter { $MaximumRedirection -ne 0 }
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

    Context 'Automatic report storage' {
        BeforeAll {
            $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
            foreach ($definition in $launcherAst.FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile',
                            'Show-ResultsSummary', 'Show-Banner', 'Write-SectionHeader', 'Write-ColorizedLine', 'Write-FinOpsConsole', 'Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
                    }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }

            function Get-ReportLayoutFixture {
                $subscriptions = @(foreach ($scopeIndex in 1..85) {
                        [pscustomobject]@{
                            Id       = '00000000-0000-0000-0000-{0:D12}' -f $scopeIndex
                            Name     = 'Example subscription {0:D3}' -f $scopeIndex
                            TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                        }
                    })
                $values = @(foreach ($valueIndex in 1..240) {
                        [pscustomobject]@{ Value = 'Example team {0:D3}' -f $valueIndex; ResourceCount = 241 - $valueIndex }
                    })
                $technicalTag = 'hidden-link:/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-synthetic-long-resource-group/providers/Microsoft.Web/sites/synthetic-monitoring-association'
                $tagNames = @{
                    Owner         = [pscustomobject]@{ TotalResources = 28920; Values = $values }
                    CostCenter    = [pscustomobject]@{ TotalResources = 5; Values = @([pscustomobject]@{ Value = 'Example <script>fixture</script>'; ResourceCount = 5 }) }
                    $technicalTag = [pscustomobject]@{ TotalResources = 5; Values = @([pscustomobject]@{ Value = 'Resource'; ResourceCount = 5 }) }
                }
                foreach ($tagIndex in 1..82) {
                    $tagNames[('Example field {0:D3}' -f $tagIndex)] = [pscustomobject]@{ TotalResources = 1; Values = @([pscustomobject]@{ Value = 'Example value'; ResourceCount = 1 }) }
                }
                $assignments = @(foreach ($assignmentIndex in 1..40) {
                        [pscustomobject]@{
                            AssignmentName  = 'Example assignment {0:D3}' -f $assignmentIndex
                            AssignmentId    = "/subscriptions/$($subscriptions[$assignmentIndex - 1].Id)/providers/Microsoft.Authorization/policyAssignments/fixture"
                            Scope           = "/subscriptions/$($subscriptions[$assignmentIndex - 1].Id)"
                            Source          = 'Initiative'
                            EnforcementMode = 'Default'
                        }
                    })
                $costs = @{}
                $resourceCosts = @(foreach ($subscription in $subscriptions) {
                        $costs[$subscription.Id] = @{ Name = $subscription.Name; Actual = 100; Forecast = 120; ForecastSource = 'Forecast'; Currency = 'USD'; ActualPeriod = 'Synthetic month-to-date window' }
                        foreach ($resourceIndex in 1..5) {
                            [pscustomobject]@{ Subscription = $subscription.Name; SubscriptionId = $subscription.Id; ResourcePath = "/subscriptions/$($subscription.Id)/resourceGroups/rg-synthetic/providers/Microsoft.Compute/virtualMachines/example-resource-$resourceIndex"; ResourceType = 'Virtual Machine'; ResourceGroup = 'rg-synthetic'; Actual = 10 * $resourceIndex; Currency = 'USD'; ActualPeriod = 'Synthetic month-to-date window' }
                        }
                    })
                $analysis = @(
                    [pscustomobject]@{
                        DisplayName = 'Example cost-allocation policy'; Status = 'Assigned (Initiative)'; Category = 'Tags'; Priority = 'Required'; DefaultEffect = 'Audit'
                        MatchedAssignments = $assignments; Purpose = 'Track cost allocation across the selected subscriptions.'; Note = 'Synthetic fixture, no Azure queries.'
                    }
                    [pscustomobject]@{
                        DisplayName = 'Example regional governance policy'; Status = 'Missing'; Category = 'Governance'; Priority = 'Recommended'; DefaultEffect = 'Deny'
                        MatchedAssignments = @(); Purpose = 'Review the resource locations allowed by the current assignments.'; Note = 'Example <img src=x onerror=alert(1)> note.'
                    }
                )
                @{
                    Subscriptions = $subscriptions
                    Modules       = @(
                        @{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' }
                        @{ Fn = 'Get-ResourceCosts'; Name = 'Resource Costs'; Selected = $true; Category = 'Cost Analysis' }
                        @{ Fn = 'Get-TagInventory'; Name = 'Tag Inventory'; Selected = $true; Category = 'Governance' }
                        @{ Fn = 'Get-PolicyRecommendations'; Name = 'Policy Recommendations'; Selected = $true; Category = 'Governance' }
                    )
                    Results       = @{
                        'Get-CostData'              = $costs
                        'Get-ResourceCosts'         = $resourceCosts
                        'Get-TagInventory'          = [pscustomobject]@{
                            TagNames = $tagNames; TagCount = 85; SpellingCount = 115; TotalResources = 30000; TaggedCount = 28920; UntaggedCount = 1080; TagCoverage = 96.4; CoverageIncomplete = $false
                            CaseVariants = @(foreach ($variantIndex in 1..30) { [pscustomobject]@{ TagKey = "ExampleTag$variantIndex"; Detail = "ExampleTag$variantIndex (1), EXAMPLETAG$variantIndex (1)" } })
                        }
                        'Get-PolicyRecommendations' = [pscustomobject]@{
                            Analysis = $analysis; Assigned = @($analysis[0]); Missing = @($analysis[1]); TotalRecommended = 2; CompliancePct = 50; CoverageIncomplete = $false
                        }
                    }
                }
            }
        }

        It 'Sorts credits and unavailable values using the actual report JavaScript' -Tag 'ReportGridSorting' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            $source = [IO.File]::ReadAllText((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'))
            $functions = [regex]::Match($source, '(?s)        function parseGridNumber\(text\).*?(?=        function updateRows\(\))').Value
            $functions | Should -Not -BeNullOrEmpty
            $inputData = @{
                source = $functions
                cases  = @(
                    @{ text = '($500.00)'; expected = -500 }
                    @{ text = '-$500.00'; expected = -500 }
                    @{ text = '$-500.00'; expected = -500 }
                    @{ text = 'USD -500.00'; expected = -500 }
                    @{ text = 'USD 2,500.50'; expected = 2500.5 }
                    @{ text = '0%'; expected = 0 }
                    @{ text = 'USD 1E-12'; expected = 1e-12 }
                )
            } | ConvertTo-Json -Depth 5 -Compress
            $runner = @'
const vm = require('node:vm');
const assert = require('node:assert/strict');
const input = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
const context = { sortColumn: 0, sortDirection: 1, collator: new Intl.Collator('en-US', { numeric: true, sensitivity: 'base' }) };
vm.createContext(context);
new vm.Script(input.source).runInContext(context);
for (const sample of input.cases) { assert.equal(context.parseGridNumber(sample.text).value, sample.expected); }
assert.equal(context.parseGridNumber('Unavailable'), null);
const values = ['$20.00', '($500.00)', '-$10.00', '$0.00', 'Unavailable'];
const rows = values.map((text, index) => ({ cells: [{}, { textContent: text }], getAttribute: () => String(index) }));
assert.deepEqual(rows.slice().sort(context.compareCells).map(row => row.cells[1].textContent), ['($500.00)', '-$10.00', '$0.00', '$20.00', 'Unavailable']);
context.sortDirection = -1;
assert.deepEqual(rows.slice().sort(context.compareCells).map(row => row.cells[1].textContent), ['$20.00', '$0.00', '-$10.00', '($500.00)', 'Unavailable']);
console.log('Credit, numeric, and unavailable sorting passed');
'@
            $output = $inputData | node -e $runner
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'sorting passed'
        }

        It 'Keeps a large-tenant HTML report compact without losing exported detail' -Tag 'LargeReportLayout' {
            $fixture = Get-ReportLayoutFixture
            $reportRoot = Join-Path $TestDrive 'large-report-layout'
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local

            $null = Show-ResultsSummary @fixture -ExportPath $reportRoot -DataSourceLabel 'Synthetic fixture, no Azure queries' -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html.Contains('<details class="scope-details">') | Should -BeTrue
            $html.Contains('<summary>85 subscriptions</summary>') | Should -BeTrue
            $html.Contains('Example subscription 085') | Should -BeTrue
            $metadataLine = [regex]::Match($html, '<p class="meta">.*?</p>').Value
            $metadataLine | Should -Match 'Subscriptions: 85 selected'
            $metadataLine | Should -Not -Match 'Example subscription'
            $html.Contains('<details class="tag-case-details">') | Should -BeTrue
            $html.Contains('30 tag-key spelling groups') | Should -BeTrue
            $html.Contains('class="report-table table-tags"') | Should -BeTrue
            $html.Contains('class="report-table table-policies"') | Should -BeTrue
            $html.Contains('data-table-id="table-Get-TagInventory"') | Should -BeTrue
            $html.Contains('id="filter-Get-TagInventory"') | Should -BeTrue
            $html.Contains('data-page-action="next"') | Should -BeTrue
            $html.Contains('data-table-id="table-story-costs"') | Should -BeTrue
            $html.Contains('data-table-id="table-story-resources"') | Should -BeTrue
            $html.Contains('235 more values') | Should -BeTrue
            $html.Contains('Example team 240') | Should -BeTrue
            $html.Contains('40 assignments') | Should -BeTrue
            $html.Contains('Example assignment 040') | Should -BeTrue
            $html.Contains('<script>fixture</script>') | Should -BeFalse
            $html.Contains('&lt;script&gt;fixture&lt;/script&gt;') | Should -BeTrue
            $html.Contains('<img src=x onerror=alert(1)>') | Should -BeFalse
            $html.Contains('&lt;img src=x onerror=alert(1)&gt;') | Should -BeTrue
            [regex]::Matches($html, '<details class="(?:scope-details|tag-case-details|cell-details)"[^>]*\bopen\b').Count | Should -Be 0
            $tagCsv = Get-Content -LiteralPath (Join-Path $run 'Get-TagInventory.csv') -Raw
            $policyCsv = Get-Content -LiteralPath (Join-Path $run 'Get-PolicyRecommendations.csv') -Raw
            $tagCsv.Contains('Example team 240') | Should -BeTrue
            $policyCsv.Contains('Example assignment 040') | Should -BeTrue
            $fixture.Results['Get-TagInventory'].TagNames.Owner.Values.Count | Should -Be 240
            $fixture.Results['Get-PolicyRecommendations'].Analysis[0].MatchedAssignments.Count | Should -Be 40
        }

        It 'Keeps a single selected subscription visible without a scope disclosure' -Tag 'LargeReportLayout' {
            $fixture = Get-ReportLayoutFixture
            $fixture.Subscriptions = @($fixture.Subscriptions[0])
            $reportRoot = Join-Path $TestDrive 'small-report-layout'
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local

            $null = Show-ResultsSummary @fixture -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html.Contains('<details class="scope-details">') | Should -BeFalse
            $html.Contains('Example subscription 001 [00000000-0000-0000-0000-000000000001]') | Should -BeTrue
        }

        It 'Splits formatted table rows cleanly for <LineEnding> output' -Tag 'TableLineEndings' -ForEach @(
            @{ LineEnding = 'CRLF'; Separator = "`r`n" }
            @{ LineEnding = 'LF'; Separator = "`n" }
        ) {
            $splitters = @($launcherAst.FindAll({
                        $args[0] -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                        $args[0].Operator -eq 'Isplit' -and $args[0].Left.Extent.Text -eq '$_.TrimEnd()'
                    }, $true))
            $splitters.Count | Should -Be 3
            $expectedLines = @('Name           Cost', '----           ----', 'demo-resource 12.50')
            $formattedTable = ($expectedLines -join $Separator) + $Separator
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }

            foreach ($splitter in $splitters) {
                $lines = @($formattedTable | ForEach-Object ([scriptblock]::Create($splitter.Extent.Text)))
                $lines | Should -Be $expectedLines
                foreach ($line in $lines) { Write-ColorizedLine -Text $line }
            }

            ($captured -join '') | Should -Not -Match '\\u000[AD]|[\p{Cc}\p{Cf}]'
            Should -Invoke Write-Host -Times 9 -Exactly -ParameterFilter { $Object -ne '' -and $NoNewline }
        }

        It 'Escapes terminal control sequences while preserving host colors' -Tag 'TableLineEndings' {
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $payload = "$([char]27)[2J$([char]27)]52;c;synthetic$([char]7)$([char]0x202E)`r`n"

            Write-FinOpsConsole -Object $payload -ForegroundColor Yellow -NoNewline

            $captured[0] | Should -Not -Match '[\p{Cc}\p{Cf}]'
            $captured[0] | Should -Match '\\u001B\[2J'
            $captured[0] | Should -Match '\\u0007\\u202E'
            $captured[0] | Should -Match '\\u000D\\u000A'
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $ForegroundColor -eq 'Yellow' -and $NoNewline }
        }

        It 'Preserves the banner line layout through safe console output' {
            $captured = [Collections.Generic.List[string]]::new()
            function Get-VersionNumber { '0.0.0' }
            Mock Clear-Host { }
            Mock Write-Host { [void]$captured.Add([string]$Object) }

            Show-Banner

            $captured.Count | Should -BeGreaterThan 15
            ($captured -join '') | Should -Not -Match '\\u000[AD]|[\p{Cc}\p{Cf}]'
        }

        It 'Keeps hostile tag controls out of terminal output without changing scan data' {
            $reportRoot = Join-Path $TestDrive 'terminal-controls'
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $payload = "$([char]27)[2Jsynthetic <script>example</script>"
            $inventory = ConvertTo-TagInventoryFromHub -HubData @([pscustomobject]@{
                    ResourceId = '/resources/fixture'; ResourceType = 'Fixture'; Tags = (@{ CostCenter = $payload } | ConvertTo-Json -Compress)
                })
            $modules = @(@{ Fn = 'Get-TagInventory'; Name = 'Tag Inventory'; Selected = $true; Category = 'Governance' })

            $null = Show-ResultsSummary -Results @{ 'Get-TagInventory' = $inventory } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            ($captured -join '') | Should -Not -Match '[\p{Cc}\p{Cf}]'
            ($captured -join '') | Should -Match '\\u001B\[2J'
            $inventory.TagNames.CostCenter.Values[0].Value | Should -BeExactly $payload
            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match '&lt;script&gt;example&lt;/script&gt;'
            $html | Should -Not -Match '<script>example</script>'
        }

        It 'Keeps incomplete policy and storage evidence visible without healthy guidance' {
            $reportRoot = Join-Path $TestDrive 'partial-evidence'
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $results = @{
                'Get-PolicyInventory'   = [pscustomobject]@{ Assignments = @(); AssignmentCount = 0; CoverageIncomplete = $false; ComplianceCoverageIncomplete = $true; CompliancePct = $null; TotalCompliant = 10; TotalNonCompliant = 0; HasComplianceData = $false; Note = 'Policy compliance coverage is incomplete.' }
                'Get-StorageTierAdvice' = [pscustomobject]@{ Recommendations = @(); TotalHotAccounts = 1; MetricFailures = 1; EvaluatedAccounts = 0; HasData = $false; MetricFailureDetail = @('No transaction measurements.') }
            }
            $modules = @(
                @{ Fn = 'Get-PolicyInventory'; Name = 'Policy Inventory'; Selected = $true; Category = 'Governance' }
                @{ Fn = 'Get-StorageTierAdvice'; Name = 'Storage Tier Advice'; Selected = $true; Category = 'Optimization' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'Policy compliance coverage is incomplete'
            $html | Should -Match 'Storage tier assessment is incomplete'
            [regex]::Matches($html, '>Limited data</td>').Count | Should -Be 2
            $html | Should -Not -Match 'Full policy compliance|All storage accounts are appropriately tiered'
            ($captured -join ' ') | Should -Not -Match 'all are appropriately tiered|Compliance: 100'
            (Import-Csv -LiteralPath (Join-Path $run 'Get-PolicyInventory.csv'))[0].'Summary.ComplianceCoverageIncomplete' | Should -Be 'True'
        }

        It 'Names the unit-cost share denominator and captured period in report output' {
            $reportRoot = Join-Path $TestDrive 'unit-cost-context'
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $data = [pscustomobject]@{
                HasData = $true; Currency = 'USD'; CostAvailable = $true
                ComputeCost = 0.65; StorageCost = 12.26; ComputeSharePct = 5; StorageSharePct = 95
                CostPerVCpu = 0.08125; CostPerGbRam = 0.0203125; CostPerVm = 0.1625; CostPerGb = 0.03892063
                VmCount = 4; TotalVCpu = 8; TotalMemoryGb = 32; DiskGb = 300; BlobFileGb = 15; TotalStorageGb = 315
                CostPeriodStartUtc = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                CostPeriodEndUtc = [datetime]::new(2026, 9, 24, 12, 0, 0, [DateTimeKind]::Utc)
                Period = 'MonthToDate'; ScannedSubs = 1
            }
            $modules = @(@{ Fn = 'Get-UnitEconomics'; Name = 'Unit Economics'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-UnitEconomics' = $data } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            foreach ($outputText in @($html, ($captured -join ' '))) {
                $outputText | Should -Match '5% of VM compute \+ storage spend'
                $outputText | Should -Match 'Subtotal: USD 12\.91'
                $outputText | Should -Match '2026-09-01 00:00.*2026-09-24 12:00.*UTC'
                $outputText | Should -Match 'Amortized cost'
                $outputText | Should -Match 'not an efficiency score'
            }
            $html | Should -Match '<summary>Calculation and thresholds</summary>'
            $html | Should -Match 'current inventory'
            $html | Should -Match 'Other Azure services are excluded'
        }

        It 'Keeps policy definition failures visible in console, HTML, CSV, and text reports' -Tag 'PolicyDefinitionCoverage' {
            $reportRoot = Join-Path $TestDrive 'policy-definition-coverage'
            $captured = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            Mock Write-Warning { }
            Mock Write-Host -ModuleName FinOpsMultitool { }
            Mock Write-Warning -ModuleName FinOpsMultitool { }
            Mock Get-AzContext -ModuleName FinOpsMultitool { throw 'Report fixtures must not read an Azure context.' }
            Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Report fixtures must not make HTTP requests.' }
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                [pscustomobject]@{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; Total = 10; Compliant = 10; NonCompliant = 0 }) }
            }
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                if ($Path -eq '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01') {
                    return [pscustomobject]@{ StatusCode = 200; Content = (@{
                                value = @(@{
                                        id         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments/fixture'
                                        name       = 'fixture'
                                        properties = @{ displayName = 'Policy <fixture>'; policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/unavailable' }
                                    })
                            } | ConvertTo-Json -Depth 8)
                    }
                }
                if ($Path -eq '/providers/Microsoft.Authorization/policyDefinitions/unavailable?api-version=2023-04-01') {
                    return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                }
                throw 'Unexpected request scope.'
            }
            $data = Get-PolicyInventory -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @(
                [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Selected subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
            )
            $results = @{ 'Get-PolicyInventory' = $data }
            $modules = @(@{ Fn = 'Get-PolicyInventory'; Name = 'Policy Inventory'; Selected = $true; Category = 'Governance' })

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $runs = @(Get-ChildItem -LiteralPath $reportRoot -Directory)
            $runs.Count | Should -Be 1
            $html = Get-Content -LiteralPath (Join-Path $runs[0].FullName 'FinOpsReport.html') -Raw
            $summary = Get-Content -LiteralPath (Join-Path $runs[0].FullName 'ScanSummary.txt') -Raw
            $csv = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $runs[0].FullName -Filter '*.csv').FullName -Raw
            $summary | Should -Match 'Policy Inventory: Limited data: Policy definition coverage is incomplete'
            $html | Should -Match 'Limited data'
            foreach ($outputText in @($html, ($captured -join ' '))) {
                $outputText | Should -Match 'Policy definition coverage is incomplete'
                $outputText | Should -Not -Match 'Strong governance posture'
            }
            $html | Should -Match 'Policy &lt;fixture&gt;'
            $html | Should -Not -Match 'Policy <fixture>'
            $csv | Should -Match 'DefinitionCoverageIncomplete'
            $csv | Should -Match 'DefinitionErrors'
            $csv | Should -Match 'HTTP 503'
            $data.AssignmentCount | Should -Be 1
            $data.CompliancePct | Should -Be 100
            $data.ComplianceCoverageIncomplete | Should -BeFalse
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 2 -Exactly
            Should -Invoke Get-AzContext -ModuleName FinOpsMultitool -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName FinOpsMultitool -Times 0 -Exactly
        }

        It 'Explains screening thresholds and separates budget coverage from forecast availability' {
            $reportRoot = Join-Path $TestDrive 'screening-context'
            Mock Write-Host { }
            $budgets = @(foreach ($budgetIndex in 1..6) {
                    [pscustomobject]@{
                        BudgetName = "Budget $budgetIndex"; Amount = 100; ActualSpend = 25; Currency = 'USD'; PctUsed = 25
                        Forecast = $(if ($budgetIndex -le 2) { 40 } else { $null })
                        ForecastSource = $(if ($budgetIndex -le 2) { 'Budget' } else { 'Unavailable' })
                        Risk = $(if ($budgetIndex -le 2) { 'On Track' } else { 'Forecast unavailable' })
                    }
                })
            $results = @{
                'Get-IdleVMs'           = [pscustomobject]@{ IdleVMs = @(); Count = 0; ScannedVMs = 2; EvaluatedVMs = 1; TotalVMs = 4; MetricFailures = 1; HasData = $false }
                'Get-StorageTierAdvice' = [pscustomobject]@{ Recommendations = @(); Count = 0; TotalHotAccounts = 8; EvaluatedAccounts = 7; MetricFailures = 1; HasData = $false }
                'Get-BudgetStatus'      = [pscustomobject]@{ Budgets = $budgets; TotalBudgets = 6; AtRiskCount = 0; OverBudgetCount = 0; BudgetCoverage = 100; SubsWithBudget = 1; TotalSubs = 1; ScannedSubs = 1; CoverageIncomplete = $false }
            }
            $modules = @(
                @{ Fn = 'Get-IdleVMs'; Name = 'Idle VMs'; Selected = $true; Category = 'Optimization' }
                @{ Fn = 'Get-StorageTierAdvice'; Name = 'Storage Tier Advice'; Selected = $true; Category = 'Optimization' }
                @{ Fn = 'Get-BudgetStatus'; Name = 'Budget Status'; Selected = $true; Category = 'Monitoring' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $plain = [System.Net.WebUtility]::HtmlDecode($html)
            $plain | Should -Match 'Evaluated: 1 of 2 running VMs'
            $plain | Should -Match 'CPU <5% AND combined network <1 MiB/day'
            $plain | Should -Match 'CPU <10% AND combined network <10 MiB/day'
            $plain | Should -Match 'Evaluated: 7 of 8 storage accounts'
            $plain | Should -Match 'fewer than 100 blob transactions'
            $plain | Should -Match 'fewer than 1,000 blob transactions'
            $plain | Should -Match 'not per-blob last-access analysis'
            $plain | Should -Match 'Subscriptions with a budget: 100%'
            $plain | Should -Match 'Forecasts available: 2 of 6'
            $plain | Should -Match '4 unavailable'
            $plain | Should -Match 'not an all-clear'
            [regex]::Matches($html, '<summary>Calculation and thresholds</summary>').Count | Should -Be 3
        }

        It 'Lists every KPI with context and honest run states without unsafe report links' {
            $reportRoot = Join-Path $TestDrive 'kpi-reference'
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local
            $catalog = Get-KpiCatalog
            $payload = '<img src=x onerror=alert(1)>'
            $results = @{
                'Get-IdleVMs'             = [pscustomobject]@{ IdleVMs = @(); Count = 0; ScannedVMs = 1; EvaluatedVMs = 1; TotalVMs = 1; MetricFailures = 0; HasData = $false }
                'Get-StorageTierAdvice'   = [pscustomobject]@{ Recommendations = @(); Count = 0; TotalHotAccounts = 1; EvaluatedAccounts = 1; MetricFailures = 0; HasData = $false }
                '_error_Get-BudgetStatus' = "Synthetic failure $payload"
            }
            $modules = @(
                @{ Fn = 'Get-IdleVMs'; Name = 'Idle VMs'; Selected = $true; Category = 'Optimization' }
                @{ Fn = 'Get-StorageTierAdvice'; Name = 'Storage Tier Advice'; Selected = $true; Category = 'Optimization' }
                @{ Fn = 'Get-BudgetStatus'; Name = 'Budget Status'; Selected = $true; Category = 'Monitoring' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'data-target="tab-KpiReference">KPI reference</button>'
            [regex]::Matches($html, 'class="kpi-reference-row"').Count | Should -Be $catalog.kpis.Count
            foreach ($kpi in $catalog.kpis) {
                $html | Should -Match ('id="kpi-' + [regex]::Escape($kpi.id) + '"')
                foreach ($field in @('calculation', 'interpretation', 'limitations')) { $kpi.$field | Should -Not -BeNullOrEmpty }
                $kpi.requiredInputs.Count | Should -BeGreaterThan 0
            }
            $html | Should -Match 'data-kpi-status="Computed"'
            $html | Should -Match 'data-kpi-status="Unavailable"'
            $html | Should -Match 'data-kpi-status="Not run"'
            $html | Should -Match 'data-kpi-status="Informational"'
            $html | Should -Match '0% of running VMs idle'
            $html | Should -Match 'href="#scan-Get-IdleVMs"'
            $html | Should -Not -Match 'href="#scan-Get-UnitEconomics"'
            $html | Should -Match 'id="kpi-search"'
            $html | Should -Match 'id="kpi-status-filter"'
            $html | Should -Match '&lt;img src=x onerror=alert\(1\)&gt;'
            $html | Should -Not -Match '<img src=x|<[^>]+\soninput=|<[^>]+\sonchange='
            $html | Should -Match 'No universal healthy value'
        }

        It 'Keeps informational KPI status when a related scan fails' {
            $results = @{ '_error_Get-StorageTierAdvice' = 'Synthetic storage read failure.' }
            $modules = @(@{ Fn = 'Get-StorageTierAdvice'; Name = 'Storage Tier Advice'; Selected = $true; Category = 'Optimization' })

            $entries = @(Get-FinOpsKpiReference -Results $results -Modules $modules -Insights @() | Where-Object SourceFunction -EQ 'Get-StorageTierAdvice')

            $entries.Count | Should -Be 2
            foreach ($entry in $entries) {
                $entry.Status | Should -Be 'Informational'
                $entry.Value | Should -Match 'does not calculate'
                $entry.Context | Should -Match 'Synthetic storage read failure'
            }
        }

        It 'Keeps all report formats when the KPI catalog throws' {
            $reportRoot = Join-Path $TestDrive 'catalog-failure'
            Mock Write-Host { }
            Mock Get-KpiCatalog { throw 'Synthetic malformed catalog.' }
            Mock Get-KpiCatalog -ModuleName FinOpsMultitool { throw 'Synthetic malformed catalog.' }
            $results = @{ 'Get-CostData' = @{ 'fixture' = @{ Actual = 10; Currency = 'EUR'; Forecast = $null; ForecastSource = 'Unavailable' } } }
            $modules = @(@{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' })

            { $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop } | Should -Not -Throw

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'KPI reference unavailable'
            $html | Should -Match 'Scan results remain available'
            $html | Should -Match 'EUR 10[.,]00'
            Test-Path -LiteralPath (Join-Path $run 'Get-CostData.csv') | Should -BeTrue
            Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw | Should -Match 'KPI reference unavailable'
        }

        It 'Reports incompatible unit costs as unavailable while retaining capacity' {
            $reportRoot = Join-Path $TestDrive 'mixed-unit-costs'
            $data = [pscustomobject]@{
                HasData = $true; Currency = 'Mixed'; CostAvailable = $false; CostIssue = 'Multiple billing currencies cannot be combined.'
                ComputeCost = $null; StorageCost = $null; ComputeSharePct = $null; StorageSharePct = $null
                CostPerVCpu = $null; CostPerGbRam = $null; CostPerVm = $null; CostPerGb = $null
                VmCount = 4; TotalVCpu = 8; TotalMemoryGb = 32; DiskGb = 0; BlobFileGb = 0.9; TotalStorageGb = 0.9
                Note = 'Multiple billing currencies cannot be combined.'
            }
            $modules = @(@{ Fn = 'Get-UnitEconomics'; Name = 'Unit Economics'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-UnitEconomics' = $data } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'Compute: Unavailable \(Unavailable\) over 4 VMs, 8 vCPU, 32 GB RAM'
            $html | Should -Match 'Storage: Unavailable'
            $html | Should -Match '>Limited data</td>'
            $row = @(Import-Csv -LiteralPath (Join-Path $run 'Get-UnitEconomics.csv'))[0]
            $row.ComputeCost | Should -BeNullOrEmpty
            $row.CostPerVCpu | Should -BeNullOrEmpty
            $row.TotalVCpu | Should -Be '8'
        }

        It 'Reports incompatible AI costs without hiding measured usage or inventing a permissions issue' {
            $reportRoot = Join-Path $TestDrive 'mixed-ai-costs'
            $data = [pscustomobject]@{
                HasData = $true; Currency = 'Mixed'; CostAvailable = $false; CostIssue = 'Multiple billing currencies cannot be combined.'
                TotalAICost = $null; CostPer1KTokens = $null; CostPerRequest = $null
                TotalTokens = 2000; TotalRequests = 20; TotalPromptTokens = 1600; TotalGeneratedTokens = 400
                AIFootprint = @{ OpenAIAccounts = 2; AIServices = 0; MLWorkspaces = 0; SearchServices = 0; GpuVmCount = 0 }
                ByModel = @([pscustomobject]@{ Deployment = 'fixture'; TotalTokens = 2000; PromptTokens = 1600; GeneratedTokens = 400; PctOfTokens = 100 })
                Note = 'Multiple billing currencies cannot be combined.'; Period = 'MonthToDate'
            }
            $modules = @(@{ Fn = 'Get-AIWorkloadMetrics'; Name = 'AI Workload Metrics'; Selected = $true; Category = 'AI & ML' })

            $null = Show-ResultsSummary -Results @{ 'Get-AIWorkloadMetrics' = $data } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'AI account cost: Unavailable'
            $html | Should -Match 'Tokens: 2,000.*Requests: 20'
            $html | Should -Match '>Limited data</td>'
            $html | Should -Not -Match 'Grant Cost Management Reader to compute|No AI workloads detected'
            $row = @(Import-Csv -LiteralPath (Join-Path $run 'Get-AIWorkloadMetrics.csv'))[0]
            $row.'Summary.TotalAICost' | Should -BeNullOrEmpty
            $row.'Summary.CostIssue' | Should -Match 'currencies'
        }

        It 'Keeps partial cost-by-tag coverage visible in every report without healthy guidance' {
            $reportRoot = Join-Path $TestDrive 'partial-cost-by-tag'
            $data = [pscustomobject]@{
                CostByTag = @{ CostCenter = @([pscustomobject]@{ TagValue = 'team'; Cost = 125; Currency = 'USD' }) }
                CoverageIncomplete = $true; ScannedSubs = 2; TotalSubs = 3; UsedTimeframe = 'MonthToDate'
                SuccessfulSubscriptionIds = @('first', 'third')
                FailedSubscriptions = @([pscustomobject]@{ SubscriptionId = 'second'; Subscription = 'Second'; StatusCode = 403; Error = 'Cost query returned HTTP 403.' })
                ResourceCostSeen = 125; AllocatedCost = 125; UnallocatedCost = 0
                Note = 'Cost coverage is incomplete: 2 of 3 subscriptions were read. Amounts cover successful subscriptions only.'
            }
            $modules = @(@{ Fn = 'Get-CostByTag'; Name = 'Cost by Tag'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-CostByTag' = $data } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'Cost coverage is incomplete: 2 of 3'
            $html | Should -Match '>Limited data</td>'
            $html | Should -Not -Match 'No positive untagged cost was found'
            $rows = @(Import-Csv -LiteralPath (Join-Path $run 'Get-CostByTag.csv'))
            @($rows | Where-Object { $_.TagValue -eq 'team' })[0].'Summary.CoverageIncomplete' | Should -Be 'True'
            @($rows | Where-Object { $_.SubscriptionId -eq 'second' -and $_.Error -match '403' }).Count | Should -Be 1
            Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw | Should -Match 'Cost by Tag: Limited data: Cost coverage is incomplete'
        }

        It 'Keeps incompatible recommendation savings separate in rendered reports' {
            $reportRoot = Join-Path $TestDrive 'recommendation-currencies'
            $recommendations = @(
                [pscustomobject]@{ Category = 'Rightsize'; Impact = 'High'; ResourceName = 'one'; AnnualSavings = 100; Currency = 'USD'; Problem = 'Resize'; ResourceType = 'VM' }
                [pscustomobject]@{ Category = 'Rightsize'; Impact = 'High'; ResourceName = 'two'; AnnualSavings = 50; Currency = 'EUR'; Problem = 'Resize'; ResourceType = 'VM' }
            )
            $results = @{
                'Get-OptimizationAdvice' = [pscustomobject]@{ Recommendations = $recommendations; TotalCount = 2; EstimatedAnnualSavings = $null; Currency = 'Mixed'; CostIssue = 'Savings in different currencies cannot be combined.' }
                'Get-ReservationAdvice'  = [pscustomobject]@{ AdvisorRecommendations = $recommendations; EstimatedAnnualSavings = $null; Currency = 'Mixed'; CostIssue = 'Savings in different currencies cannot be combined.' }
            }
            $modules = @(
                @{ Fn = 'Get-OptimizationAdvice'; Name = 'Optimization Advice'; Selected = $true; Category = 'Advisor' }
                @{ Fn = 'Get-ReservationAdvice'; Name = 'Reservation Advice'; Selected = $true; Category = 'Commitments' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'Est. annual savings: Unavailable'
            $html | Should -Match 'USD 100'
            $html | Should -Match 'EUR 50'
            $html | Should -Not -Match 'Mixed 150|\$150'
            [regex]::Matches($html, '>Limited data</td>').Count | Should -Be 2
            Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw | Should -Match 'Limited data: Savings in different currencies cannot be combined'
        }

        It 'Does not claim healthy VM utilization or alerting when the reads fail' {
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
            $alerts = Get-AnomalyAlerts -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })
            $reportRoot = Join-Path $TestDrive 'failed-utilization-alerts'
            $results = @{
                'Get-AnomalyAlerts' = $alerts
                'Get-IdleVMs'       = [pscustomobject]@{ IdleVMs = @(); Count = 0; HasData = $false; ScannedVMs = 2; EvaluatedVMs = 0; MetricFailures = 2; MetricFailureDetail = @('HTTP 403'); Note = 'VM utilization coverage is incomplete.' }
            }
            $modules = @(
                @{ Fn = 'Get-AnomalyAlerts'; Name = 'Anomaly Alerts'; Selected = $true; Category = 'Monitoring' }
                @{ Fn = 'Get-IdleVMs'; Name = 'Idle VMs'; Selected = $true; Category = 'Optimization' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $alerts.CoverageIncomplete | Should -BeTrue
            (Get-KpiComputedValue -KpiId 'anomaly-detection-rate' -Data $alerts).Value | Should -BeNullOrEmpty
            (Get-KpiComputedValue -KpiId 'computational-waste' -Data $results['Get-IdleVMs']).Value | Should -BeNullOrEmpty
            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            [regex]::Matches($html, '>Limited data</td>').Count | Should -Be 2
            $html | Should -Not -Match 'actively utilized|Compute spend looks healthy|Monitoring is working|No anomaly detection rules configured'
            Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw | Should -Match 'Idle VMs: Limited data: VM utilization coverage is incomplete'
        }

        It 'Renders billing currency and unavailable carbon measurements explicitly' {
            $reportRoot = Join-Path $TestDrive 'currencies-carbon'
            $results = @{
                'Get-MaccCommitment' = [pscustomobject]@{ Applicable = $true; HasMacc = $true; Commitments = @([pscustomobject]@{ BillingAccount = 'fixture'; Currency = 'EUR'; Commitment = 300; Consumed = 250; Remaining = 50; PctUsed = 83.3; Status = 'Active' }) }
                'Get-CostTrend'      = [pscustomobject]@{ Months = @([pscustomobject]@{ Month = 'Aug 2026'; MonthDate = [datetime]'2026-08-01'; Cost = 30; Currency = 'EUR' }) }
                'Get-CarbonMetrics'  = [pscustomobject]@{ HasData = $true; LatestMonth = '2026-07'; TotalEmissionsKg = $null; ChangeRatio = $null; Unit = 'kgCO2e'; CoverageIncomplete = $true; BySubscription = @([pscustomobject]@{ Subscription = 'fixture'; EmissionsKg = 50 }); Note = 'Overall carbon measurement is unavailable.' }
            }
            $modules = @(
                @{ Fn = 'Get-MaccCommitment'; Name = 'MACC Commitment'; Selected = $true; Category = 'Account' }
                @{ Fn = 'Get-CostTrend'; Name = 'Cost Trend'; Selected = $true; Category = 'Cost Analysis' }
                @{ Fn = 'Get-CarbonMetrics'; Name = 'Carbon Emissions'; Selected = $true; Category = 'Sustainability' }
            )
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { $captured.Add([string]$Object) }

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match 'EUR 300'
            $html | Should -Match 'EUR 30'
            $html | Should -Match 'Latest month \(2026-07\): Unavailable'
            $html | Should -Match 'month over month Unavailable'
            $html | Should -Not -Match '\$300|\$30|month over month 0%'
            ($captured -join ' ') | Should -Match 'EUR 300'
            ($captured -join ' ') | Should -Match 'EUR 30'
        }

        It 'Creates distinct run folders without changing existing reports' {
            $root = Join-Path $TestDrive 'reports'

            $first = New-FinOpsReportDirectory -OutputPath $root
            Write-FinOpsReportFile -Directory $first -Name 'ScanSummary.txt' -Lines @('First run')
            $second = New-FinOpsReportDirectory -OutputPath $root

            $first | Should -Not -Be $second
            Split-Path $first -Parent | Should -Be $root
            Split-Path $second -Parent | Should -Be $root
            Get-Content -LiteralPath (Join-Path $first 'ScanSummary.txt') | Should -Be 'First run'
            { Write-FinOpsReportFile -Directory $first -Name 'ScanSummary.txt' -Lines @('Replacement') } | Should -Throw
            Get-Content -LiteralPath (Join-Path $first 'ScanSummary.txt') | Should -Be 'First run'
        }

        It 'Rejects a <Marker> Git worktree before creating a report folder' -ForEach @(
            @{ Marker = 'directory' }
            @{ Marker = 'file' }
        ) {
            $repository = Join-Path $TestDrive "repository-$Marker"
            [void](New-Item -ItemType Directory -Path $repository)
            $gitMarker = Join-Path $repository '.git'
            if ($Marker -eq 'directory') { [void](New-Item -ItemType Directory -Path $gitMarker) }
            else { Set-Content -LiteralPath $gitMarker -Value 'gitdir: elsewhere' }
            $target = Join-Path $repository 'nested/reports'

            { New-FinOpsReportDirectory -OutputPath $target } | Should -Throw '*Git*'

            Test-Path -LiteralPath $target | Should -BeFalse
        }

        It 'Rejects network and provider paths before writing data (<Destination>)' -ForEach @(
            @{ Destination = '\\server\share\reports' }
            @{ Destination = 'https://example.test/reports' }
            @{ Destination = 'Env:reports' }
        ) {
            { New-FinOpsReportDirectory -OutputPath $Destination } | Should -Throw '*local*'
        }

        It 'Uses per-user local application data rather than the working directory' {
            $base = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData, [Environment+SpecialFolderOption]::DoNotVerify)

            Get-FinOpsReportRoot | Should -Be (Join-Path $base 'FinOpsToolkit/Multitool/Reports')
        }

        It 'Creates the default reports folder for a fresh Linux application-data path' -Skip:(-not $IsLinux) {
            $applicationData = Join-Path $TestDrive 'fresh-application-data'
            $definitions = @('Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile') |
            ForEach-Object { "function $_ { $((Get-Command $_).Definition) }" }
            $scriptText = "`$ErrorActionPreference = 'Stop'`n" + ($definitions -join "`n") + "`nNew-FinOpsReportDirectory"
            $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) {
                $startInfo.ArgumentList.Add($argument)
            }
            $startInfo.Environment['XDG_DATA_HOME'] = $applicationData
            $process = [System.Diagnostics.Process]::new()
            try {
                $process.StartInfo = $startInfo
                [void]$process.Start()
                $standardOutput = $process.StandardOutput.ReadToEndAsync()
                $standardError = $process.StandardError.ReadToEndAsync()
                $process.WaitForExit()
                $process.ExitCode | Should -Be 0 -Because $standardError.GetAwaiter().GetResult()
                $run = $standardOutput.GetAwaiter().GetResult().Trim()
                Split-Path $run -Parent | Should -Be (Join-Path $applicationData 'FinOpsToolkit/Multitool/Reports')
                Test-Path -LiteralPath (Join-Path $run '.gitignore') | Should -BeTrue
            }
            finally { $process.Dispose() }
        }

        It 'Automatically saves all formats without OutputPath or a key press' {
            $localRoot = Join-Path $TestDrive 'automatic-local'
            Mock Get-FinOpsReportRoot { $localRoot }
            Mock Read-Host { throw 'Saving reports must not prompt.' }
            Mock Write-Host { }
            $subscription = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }
            $results = @{ 'Get-CostData' = @{ $subscription.Id = @{ Actual = 10; Currency = 'USD'; Name = 'Fixture'; ForecastSource = 'Unavailable' } } }
            $modules = @(@{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' })

            $returned = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions @($subscription) -ErrorAction Stop

            $runs = @(Get-ChildItem -LiteralPath $localRoot -Directory)
            $runs.Count | Should -Be 1
            foreach ($name in @('Get-CostData.csv', 'FinOpsReport.html', 'ScanSummary.txt', '.gitignore')) {
                Test-Path -LiteralPath (Join-Path $runs[0].FullName $name) | Should -BeTrue
            }
            (Import-Csv -LiteralPath (Join-Path $runs[0].FullName 'Get-CostData.csv')).Actual | Should -Be '10'
            $returned['Get-CostData'][$subscription.Id].Actual | Should -Be 10
            Get-Content -LiteralPath (Join-Path $runs[0].FullName '.gitignore') | Should -Be '*'
            Should -Invoke Read-Host -Times 0 -Exactly
        }

        It 'Starts the HTML story with scoped spend and visible evidence gaps' {
            $reportRoot = Join-Path $TestDrive 'finops-story'
            Mock Write-Host { }
            $permissionInfo = @{ 'Get-CostTrend' = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Cost Management Query' } }
            $subscriptions = @(
                [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Production <east>'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Development'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
            )
            $results = @{
                'Get-CostData'         = @{
                    $subscriptions[0].Id = @{ Actual = 100; Currency = 'EUR'; Name = $subscriptions[0].Name; ActualPeriod = '2026-08-01 to 2026-08-31'; Forecast = $null; ForecastSource = 'Unavailable' }
                    $subscriptions[1].Id = @{ Actual = 200; Currency = 'USD'; Name = $subscriptions[1].Name; ActualPeriod = '2026-09-01 to 2026-09-18'; Forecast = 300; ForecastSource = 'Forecast' }
                }
                'Get-CostTrend'        = @()
                '_error_Get-CostTrend' = '429 Too Many Requests: retry later <script>not markup</script>'
            }
            $modules = @(
                @{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' }
                @{ Fn = 'Get-CostTrend'; Name = 'Cost Trend'; Selected = $true; Category = 'Cost Analysis' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions $subscriptions -ExportPath $reportRoot -DataSourceLabel 'FinOps Hub (fixture)' -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $story = [regex]::Match($html, '(?s)<section id="tab-FinOpsStory"[^>]*>.*?</section>').Value
            $story | Should -Not -BeNullOrEmpty
            $story | Should -Match 'Observed spend'
            $story | Should -Match '2026-08-01 to 2026-08-31'
            $story | Should -Match '2026-09-01 to 2026-09-18'
            $story | Should -Match 'EUR 100.00'
            $story | Should -Match 'USD 200.00'
            $story | Should -Match 'Production &lt;east&gt;'
            $story | Should -Match 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $story | Should -Match 'FinOps Hub \(fixture\)'
            $story | Should -Match 'Scan status'
            $story | Should -Match '429 Too Many Requests'
            $story | Should -Match '&lt;script&gt;not markup&lt;/script&gt;'
            $story | Should -Match 'href="#scan-Get-CostTrend"'
            $html | Should -Match ([regex]::Escape($permissionInfo['Get-CostTrend'].Role))
            $story | Should -Match 'Full-month forecast unavailable'
            $html | Should -Not -Match 'Total Findings|Every measure below is a FinOps Foundation KPI'
            $html | Should -Not -Match 'Current period spend:'
            $story | Should -Not -Match '<script>|Total savings'
        }

        It 'Keeps zero, credits, unavailable amounts, and budget comparison gaps distinct without a KPI catalog' {
            $reportRoot = Join-Path $TestDrive 'story-unknowns'
            Mock Write-Host { }
            Mock Get-KpiCatalog { $null }
            $results = @{
                'Get-CostData'      = @{
                    'zero'    = @{ Actual = 0; Currency = 'USD'; Forecast = 0; ForecastSource = 'Actual'; ActualPeriod = '2026-09-01 to 2026-09-18' }
                    'credit'  = @{ Actual = -5.25; Currency = 'EUR'; ForecastSource = 'Unavailable'; ActualPeriod = '2026-08-01 to 2026-08-31' }
                    'unknown' = @{ Actual = $null; Currency = $null; Forecast = $null; ForecastSource = 'Unavailable' }
                }
                'Get-BudgetHistory' = @([pscustomobject]@{
                        BudgetName = 'Filtered budget'; SubscriptionId = 'zero'; Month = '2026-08'; Budget = 500; ActualSpend = $null
                        PctUsed = $null; Status = 'Unavailable'; Currency = 'USD'; Note = 'Filtered budget history requires costs for the same filter.'
                    })
            }
            $modules = @(
                @{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' }
                @{ Fn = 'Get-BudgetHistory'; Name = 'Budget History'; Selected = $true; Category = 'Cost Analysis' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $story = [regex]::Match($html, '(?s)<section id="tab-FinOpsStory"[^>]*>.*?</section>').Value
            $story | Should -Match '<td>zero</td><td class="numeric-cell">USD 0\.00</td>.*?<td class="numeric-cell">Unavailable</td>'
            $story | Should -Match '<td>credit</td><td class="numeric-cell">EUR -5\.25</td>'
            $story | Should -Match '<td>unknown</td><td class="numeric-cell">Unavailable</td><td>Not recorded</td><td class="numeric-cell">Unavailable</td>'
            $story | Should -Match 'Filtered budget history requires costs for the same filter'
            $story | Should -Match 'Limited data'
            $html | Should -Match '<div class="label">Scans with gaps</div><div class="value">2</div>'
            $story | Should -Not -Match 'Every measure|No budget overruns'
        }

        It 'Explains AI and commitment evidence without inventing rates, utilization, or access failures' -Tag 'ReadableScanEvidence' {
            $reportRoot = Join-Path $TestDrive 'readable-scan-evidence'
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local
            $subscriptionId = '11111111-1111-1111-1111-111111111111'
            $accountId = "/subscriptions/$subscriptionId/resourceGroups/fixture/providers/Microsoft.CognitiveServices/accounts/example"
            $reservationId = '/providers/Microsoft.Capacity/reservationOrders/example-order/reservations/example-reservation'
            $reservation = [pscustomobject]@{ Name = 'Example <reservation>'; ResourceId = $reservationId; ReservationId = 'example-reservation'; SkuName = $null; Kind = $null; AvgUtilization = 0; MinUtilization = $null; UsageDate = '2026-09-01' }
            $results = @{
                'Get-AIWorkloadMetrics'     = [pscustomobject]@{
                    HasData = $true; AIFootprint = @{ OpenAIAccounts = 1; AIServices = 0; MLWorkspaces = 0; SearchServices = 0; GpuVmCount = 0 }
                    TotalTokens = 12345; TotalRequests = $null; TotalAICost = 100; Currency = 'USD'; Period = 'MonthToDate'
                    UsagePeriodStartUtc = [datetime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc); UsagePeriodEndUtc = [datetime]::new(2026, 10, 1, 1, 0, 0, [DateTimeKind]::Utc)
                    RateIssue = 'Request metrics are incomplete.'; MetricFailures = 1; Note = 'Synthetic usage fixture.'
                    ByModel = @([pscustomobject]@{ Account = 'Example <account>'; ResourceId = $accountId; SubscriptionId = $subscriptionId; Deployment = 'shared-deployment'; PromptTokens = 10000; GeneratedTokens = 2345; TotalTokens = 12345; PctOfTokens = 100; TokenBasis = 'TokenTransaction' })
                    ByAccount = @([pscustomobject]@{ Name = 'Example <account>'; ResourceId = $accountId; SubscriptionId = $subscriptionId; Tokens = 12345; Requests = $null; Cost = 100; Currency = 'USD'; CostPer1KTokens = $null; MetricsComplete = $false })
                }
                'Get-CommitmentUtilization' = [pscustomobject]@{ HasData = $true; Reservations = @($reservation); SavingsPlans = @(); UnderutilizedRIs = @($reservation); RICount = 1; SPCount = 0; RIAvgUtilization = $null; SPAvgUtilization = $null; CoverageIncomplete = $true; Note = 'Synthetic incomplete commitment coverage.' }
                'Get-IdleVMs'               = [pscustomobject]@{ IdleVMs = @([pscustomobject]@{ VMName = 'Example VM'; ResourceGroup = 'fixture'; VMSize = 'example'; AvgCPU14d = 2.5; Classification = 'Idle' }); ScannedVMs = 3; EvaluatedVMs = 2; MetricFailures = 1; TotalCount = 1 }
                'Get-BudgetStatus'          = [pscustomobject]@{ Budgets = @(); TotalBudgets = 0; AtRiskCount = 0; OverBudgetCount = 0; CoverageIncomplete = $true; Sampled = $true; ScannedSubs = 10; TotalSubs = 82 }
            }
            $modules = @(
                @{ Fn = 'Get-AIWorkloadMetrics'; Name = 'AI Workload Metrics'; Selected = $true; Category = 'AI & ML' }
                @{ Fn = 'Get-CommitmentUtilization'; Name = 'Commitment Utilization'; Selected = $true; Category = 'Commitments' }
                @{ Fn = 'Get-IdleVMs'; Name = 'Idle VMs'; Selected = $true; Category = 'Optimization' }
                @{ Fn = 'Get-BudgetStatus'; Name = 'Budget Status'; Selected = $true; Category = 'Monitoring' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions @([pscustomobject]@{ Id = $subscriptionId; Name = 'Example subscription' }) -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            foreach ($text in @('Account costs', 'Deployment or model', 'Token basis', '12,345', 'Requests: Unavailable', 'Example &lt;account&gt;', 'Example &lt;reservation&gt;', 'Savings plans: 0 (average Unavailable)', 'Avg CPU (14 days)', '2.5%', 'sampled subscriptions', 'not queried', '2026-10-01 00:00:00 to 2026-10-01 01:00:00 UTC')) { $html.Contains($text) | Should -BeTrue -Because $text }
            foreach ($text in @('Example <account>', 'Example <reservation>', 'Maximum discount realized', 'resolve the access gap')) { $html.Contains($text) | Should -BeFalse -Because $text }
            $html.Contains($reservationId) | Should -BeTrue
            $html.Contains($accountId) | Should -BeTrue
            $html.Contains('shared-deployment') | Should -BeTrue
            $csv = Get-Content -LiteralPath (Join-Path $run 'Get-AIWorkloadMetrics.csv') -Raw
            $csv.Contains($accountId) | Should -BeTrue
            $csv.Contains('TokenTransaction') | Should -BeTrue
        }

        It 'Renders aggregate and subscription trends with <Metadata> coverage' -Tag 'ScopedCostTrend' -ForEach @(
            @{ Metadata = 'recorded'; Recorded = $true; AggregateOnly = $false }
            @{ Metadata = 'legacy unrecorded'; Recorded = $false; AggregateOnly = $false }
            @{ Metadata = 'aggregate only'; Recorded = $false; AggregateOnly = $true }
        ) {
            $reportRoot = Join-Path $TestDrive "scoped-trend-$Metadata"
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local
            $firstId = '11111111-1111-1111-1111-111111111111'
            $emptyId = '22222222-2222-2222-2222-222222222222'
            $missingId = '33333333-3333-3333-3333-333333333333'
            $subscriptions = @(
                [pscustomobject]@{ Id = $firstId; Name = 'Example <platform> "one"' }
                [pscustomobject]@{ Id = $emptyId; Name = 'Example empty' }
                [pscustomobject]@{ Id = $missingId; Name = 'Example unverified' }
            )
            $months = @(
                [pscustomobject]@{ Month = 'Sep 2026'; MonthDate = [datetime]'2026-09-01'; Cost = 100; Currency = 'USD' }
                [pscustomobject]@{ Month = 'Oct 2026'; MonthDate = [datetime]'2026-10-01'; Cost = -20; Currency = 'USD' }
            )
            $trend = @{ Months = $months; BySubscription = @{ $firstId = $months }; HasData = $true }
            if ($AggregateOnly) { $trend.Remove('BySubscription') }
            if ($Recorded) {
                $trend.ScopeKind = 'Selected subscriptions'
                $trend.SelectedSubscriptionCount = 3
                $trend.SubscriptionsWithData = 1
                $trend.NoDataSubscriptionIds = @($emptyId)
                $trend.UnverifiedSubscriptionIds = @($missingId)
                $trend.CoverageIncomplete = $true
                $trend.CostBasis = 'ActualCost'
                $trend.QueryScope = '/providers/Microsoft.Management/managementGroups/fixture-<group>'
                $trend.CostPeriodStartUtc = [datetime]::new(2026, 4, 1, 0, 0, 0, [DateTimeKind]::Utc)
                $trend.CostPeriodEndUtc = [datetime]::new(2026, 10, 1, 0, 30, 0, [DateTimeKind]::Utc)
                $trend.Note = 'Coverage is not verified for one selected subscription. Missing subscriptions are not treated as zero cost.'
            }
            $modules = @(@{ Fn = 'Get-CostTrend'; Name = 'Cost Trend'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-CostTrend' = [pscustomobject]$trend } -Modules $modules -Subscriptions $subscriptions -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html.Contains('id="trend-view-scope"') | Should -BeTrue
            $html.Contains('id="trend-view-subscription"') | Should -BeTrue
            $html.Contains('id="trend-subscription"') | Should -BeTrue
            $html.Contains('data-trend-series="aggregate"') | Should -BeTrue
            foreach ($subscriptionId in @($firstId, $emptyId, $missingId)) {
                $html.Contains("data-trend-series=`"$subscriptionId`"") | Should -BeTrue
                $html.Contains("value=`"$subscriptionId`"") | Should -BeTrue
            }
            $html.Contains('Example &lt;platform&gt; &quot;one&quot;') | Should -BeTrue
            $html.Contains('Example <platform>') | Should -BeFalse
            $expectedSubscriptions = if ($AggregateOnly) { 0 } else { 1 }
            $html.Contains("Returned rows: $expectedSubscriptions of 3 selected subscriptions") | Should -BeTrue
            $html.Contains('USD -20.00') | Should -BeTrue
            $html.Contains('No cost rows were returned for this subscription.') | Should -Be $Recorded
            $html.Contains('Coverage is not verified for this subscription.') | Should -BeTrue
            if ($Recorded) {
                $html.Contains('2026-04-01 00:00:00 to 2026-10-01 00:30:00 UTC') | Should -BeTrue
                $html.Contains('Oct 2026 (partial)') | Should -BeTrue
                $html.Contains('fixture-&lt;group&gt;') | Should -BeTrue
                $html.Contains('Query windows do not establish billing-data completeness.') | Should -BeTrue
            }
            else {
                $html.Contains('Query window not recorded') | Should -BeTrue
                $html.Contains('Coverage metadata not recorded') | Should -BeTrue
                $html.Contains('Oct 2026 (partial)') | Should -BeFalse
            }
            $csv = Get-Content -LiteralPath (Join-Path $run 'Get-CostTrend.csv') -Raw
            $csv.Contains($firstId) | Should -Be (-not $AggregateOnly)
            $csv.Contains('Sep 2026') | Should -BeTrue
            $csv.Contains('Oct 2026') | Should -BeTrue
            $csv.Contains('BySubscription') | Should -Be (-not $AggregateOnly)
            @($trend.BySubscription.Keys | Where-Object { $_ }).Count | Should -Be $expectedSubscriptions
            $trend.Months.Count | Should -Be 2
        }

        It 'Shows policy scope names while retaining escaped raw scope IDs' -Tag 'PolicyScopeMetadata' {
            $reportRoot = Join-Path $TestDrive 'policy-scope-names'
            Mock Write-Host { }
            Set-Variable -Name permissionInfo -Value @{} -Scope Local
            $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
            $assignments = @(
                [pscustomobject]@{ AssignmentName = 'Subscription assignment'; Scope = '/subscriptions/11111111-1111-1111-1111-111111111111'; Effect = 'Audit'; EnforcementMode = 'Default'; Source = 'Direct' }
                [pscustomobject]@{ AssignmentName = 'Management assignment'; Scope = '/providers/Microsoft.Management/managementGroups/fixture-group'; ScopeDisplayName = 'Example <platform> group'; Effect = 'Audit'; EnforcementMode = 'Default'; Source = 'Initiative' }
            )
            $results = @{
                'Get-PolicyInventory'       = [pscustomobject]@{ Assignments = $assignments; AssignmentCount = 2; HasComplianceData = $true; CompliancePct = 100; TotalCompliant = 1; TotalNonCompliant = 0 }
                'Get-PolicyRecommendations' = [pscustomobject]@{
                    Analysis = @([pscustomobject]@{ DisplayName = 'Example policy'; Status = 'Assigned'; Category = 'Governance'; Priority = 'Required'; DefaultEffect = 'Audit'; MatchedAssignments = $assignments; Purpose = 'Synthetic scope names'; Note = '' })
                    Assigned = @([pscustomobject]@{ DisplayName = 'Example policy' }); Missing = @(); TotalRecommended = 1; CompliancePct = 100
                }
            }
            $modules = @(
                @{ Fn = 'Get-PolicyInventory'; Name = 'Policy Inventory'; Selected = $true; Category = 'Governance' }
                @{ Fn = 'Get-PolicyRecommendations'; Name = 'Policy Recommendations'; Selected = $true; Category = 'Governance' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions $subscriptions -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html.Contains('Example &lt;platform&gt; group') | Should -BeTrue
            $html.Contains('Example <platform> group') | Should -BeFalse
            [regex]::Matches($html, '<summary>Scope ID</summary>').Count | Should -Be 4
            $html.Contains('/providers/Microsoft.Management/managementGroups/fixture-group') | Should -BeTrue
            $html.Contains('Example subscription') | Should -BeTrue
            $csv = Get-Content -LiteralPath (Join-Path $run 'Get-PolicyRecommendations.csv') -Raw
            $csv.Contains('/providers/Microsoft.Management/managementGroups/fixture-group') | Should -BeTrue
            $csv.Contains('Example <platform> group') | Should -BeTrue
        }

        It 'Carries resource query-window and identity metadata into HTML and CSV' -Tag 'ResourceCostMetadata' {
            $reportRoot = Join-Path $TestDrive 'resource-metadata-report'
            Mock Write-Host { }
            Mock Write-Host -ModuleName FinOpsMultitool { }
            Mock Resolve-CostMgId -ModuleName FinOpsMultitool { 'fixture-mg' }
            Mock Get-Date -ModuleName FinOpsMultitool { [datetime]::new(2026, 10, 1, 0, 30, 0, [DateTimeKind]::Utc) }
            Mock Get-AzContext -ModuleName FinOpsMultitool { throw 'Resource report fixtures must not read an Azure context.' }
            Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Resource report fixtures must not send HTTP requests.' }
            $resourcePath = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/virtualMachines/example-<vm>'
            $reservationPath = '/providers/Microsoft.Capacity/reservationOrders/fixture-order/reservations/'
            Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                [pscustomobject]@{ StatusCode = 200; Content = (@{
                            properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'ResourceGroupName' }, @{ name = 'Currency' })
                                rows    = @(@(10.0, $resourcePath, 'fixture', 'USD'), @(20.0, $reservationPath, '', 'USD'))
                            }
                        } | ConvertTo-Json -Depth 8)
                }
            }
            $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
            $resourceCosts = @(Get-ResourceCosts -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -RestrictToSelected)
            $modules = @(@{ Fn = 'Get-ResourceCosts'; Name = 'Resource Costs'; Selected = $true; Category = 'Cost Analysis' })
            Set-Variable -Name permissionInfo -Value @{} -Scope Local

            $null = Show-ResultsSummary -Results @{ 'Get-ResourceCosts' = $resourceCosts } -Modules $modules -Subscriptions $subscriptions -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $drivers = [regex]::Match($html, '(?s)<div id="story-cost-drivers">.*?</div><!-- cost-drivers -->').Value
            $drivers.Contains('Cost period') | Should -BeTrue
            $drivers.Contains('UTC (query window)') | Should -BeTrue
            $drivers.Contains('Observed period') | Should -BeFalse
            $drivers.Contains('example-&lt;vm&gt;') | Should -BeTrue
            $drivers.Contains('example-<vm>') | Should -BeFalse
            $drivers.Contains('<summary>Resource ID</summary>') | Should -BeTrue
            $drivers.Contains('Reservation charge (order fixture-order)') | Should -BeTrue
            $drivers.Contains('Not attributed') | Should -BeTrue
            $html.Contains('Query windows are not proof that billing data is complete through the end timestamp.') | Should -BeTrue
            $rows = @(Import-Csv -LiteralPath (Join-Path $run 'Get-ResourceCosts.csv'))
            $rows.Count | Should -Be 2
            foreach ($row in $rows) { $row.ActualPeriodSource | Should -Be 'Query window'; $row.ActualPeriodStart | Should -Match '^2026-10-01T00:00:00'; $row.ActualPeriodEnd | Should -Match '^2026-10-01T00:30:00' }
            ($rows | Where-Object ResourcePath -EQ $resourcePath).ResourceName | Should -Be 'example-<vm>'
            ($rows | Where-Object ResourcePath -EQ $reservationPath).Subscription | Should -Be 'Not attributed'
            Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 1 -Exactly
            Should -Invoke Get-AzContext -ModuleName FinOpsMultitool -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName FinOpsMultitool -Times 0 -Exactly
        }

        It 'Shows the largest resource costs by currency and period with links to every underlying row' {
            $reportRoot = Join-Path $TestDrive 'story-drivers'
            Mock Write-Host { }
            $resources = @(foreach ($index in 1..57) {
                    [pscustomobject]@{
                        Subscription = 'Fixture'; ResourcePath = "/subscriptions/fixture/resources/resource-$index"; ResourceGroup = 'Compute'
                        ResourceType = 'Virtual Machine'; Actual = $index * 10; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
                    }
                })
            $resources += [pscustomobject]@{
                Subscription = 'Fixture'; ResourcePath = '/subscriptions/fixture/resources/euro-storage'; ResourceGroup = 'Storage'
                ResourceType = 'Storage Account'; Actual = 2; Currency = 'EUR'; ActualPeriod = '2026-08-01 to 2026-08-31'
            }
            $resources += [pscustomobject]@{
                Subscription = 'Fixture'; ResourcePath = '/subscriptions/fixture/resources/credit'; ResourceGroup = 'Compute'
                ResourceType = 'Virtual Machine'; Actual = -5; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
            }
            $resources += @(foreach ($index in 1..6) {
                    [pscustomobject]@{
                        Subscription = 'Fixture'; ResourcePath = "/subscriptions/other/resources/other-$index"; ResourceGroup = 'Compute'
                        ResourceType = 'Virtual Machine'; Actual = $index; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
                    }
                })
            $modules = @(@{ Fn = 'Get-ResourceCosts'; Name = 'Resource Costs'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-ResourceCosts' = $resources } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $drivers = [regex]::Match($html, '(?s)<div id="story-cost-drivers">.*?</div><!-- cost-drivers -->').Value
            $drivers | Should -Not -BeNullOrEmpty
            $drivers | Should -Match 'EUR 2.00|2026-08-01 to 2026-08-31'
            $drivers | Should -Match 'USD 570.00|2026-09-01 to 2026-09-18'
            $drivers | Should -Not -Match 'resource-1</td>|resource-2</td>|/resources/credit'
            $drivers | Should -Match '/subscriptions/other/resources/other-2</td>'
            $drivers | Should -Not -Match '/subscriptions/other/resources/other-1</td>'
            [regex]::Matches($drivers, '<tr><td>Fixture</td>').Count | Should -Be 11
            $drivers | Should -Match 'href="#scan-Get-ResourceCosts"'
            $html | Should -Match 'href="#scan-Get-ResourceCosts">Resource Costs</a></td><td class="evidence-state ">Data returned</td>'
            $html | Should -Match '<div class="label">Scans with gaps</div><div class="value">0</div>'
            @((Import-Csv -LiteralPath (Join-Path $run 'Get-ResourceCosts.csv'))).Count | Should -Be 65
            $detail = [regex]::Match($html, '(?s)<h2 id="scan-Get-ResourceCosts".*?</table>').Value
            [regex]::Matches($detail, '<tr><td>Fixture</td>').Count | Should -Be 65
            $detail | Should -Match '/resources/credit</td>|USD -5.00'
            $detail | Should -Match '/resources/resource-1</td>'
            $detail | Should -Match '/resources/euro-storage</td>.*?2026-08-01 to 2026-08-31'
        }

        It 'Exports every Hub tag and its full encoded values in HTML and CSV' {
            $reportRoot = Join-Path $TestDrive 'complete-tag-values'
            Mock Write-Host { }
            $longValue = ('long-value-' * 10) + '<script>example</script>'
            $tags = @{}
            foreach ($index in 1..20) { $tags[('Tag{0:D2}' -f $index)] = 'Fixture' }
            $tags.Tag20 = $longValue
            $hubRows = @([pscustomobject]@{ ResourceId = '/resources/one'; ResourceType = 'fixture'; Tags = ($tags | ConvertTo-Json -Compress) })
            foreach ($index in 1..6) {
                $hubRows += [pscustomobject]@{ ResourceId = "/resources/extra-$index"; ResourceType = 'fixture'; Tags = (@{ Tag20 = "Other-$index" } | ConvertTo-Json -Compress) }
            }
            $inventory = ConvertTo-TagInventoryFromHub -HubData $hubRows
            $modules = @(@{ Fn = 'Get-TagInventory'; Name = 'Tag Inventory'; Selected = $true; Category = 'Governance' })

            $null = Show-ResultsSummary -Results @{ 'Get-TagInventory' = $inventory } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            [regex]::Matches($html, '<tr><td>Tag\d{2}</td>').Count | Should -Be 20
            $tagRow = [regex]::Match($html, '(?s)<tr><td>Tag20</td>.*?</tr>').Value
            $tagRow | Should -Match ([regex]::Escape([System.Net.WebUtility]::HtmlEncode($longValue)))
            foreach ($index in 1..6) { $tagRow | Should -Match "Other-$index" }
            $tagRow | Should -Not -Match '&hellip;|<script>|\+\d+ more'
            $csvRows = @(Import-Csv -LiteralPath (Join-Path $run 'Get-TagInventory.csv') | Where-Object RecordType -EQ 'TagNames')
            $csvRows.Count | Should -Be 20
            $values = @((($csvRows | Where-Object TagKey -EQ 'Tag20').Values) | ConvertFrom-Json)
            $values.Count | Should -Be 7
            $values.Value | Should -Contain $longValue
        }

        It 'Creates private directories and report files' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'private')
            $path = Join-Path $run 'ScanSummary.txt'
            Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt' -Lines @('Fixture')

            if ($IsWindows) {
                $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                try {
                    $directoryAcl = Get-Acl -LiteralPath $run
                    $directoryAcl.AreAccessRulesProtected | Should -BeTrue
                    foreach ($acl in @($directoryAcl, (Get-Acl -LiteralPath $path))) {
                        $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
                        $rules.Count | Should -BeGreaterThan 0
                        foreach ($rule in $rules) { $rule.IdentityReference.Value | Should -Be $identity.User.Value }
                    }
                }
                finally { $identity.Dispose() }
            }
            elseif ('System.IO.UnixFileMode' -as [type]) {
                [int][System.IO.File]::GetUnixFileMode($run) | Should -Be 448
                [int][System.IO.File]::GetUnixFileMode($path) | Should -Be 384
            }
        }

        It 'Rejects a bare Git repository' {
            $repository = Join-Path $TestDrive 'bare'
            [void](New-Item -ItemType Directory -Path (Join-Path $repository 'objects') -Force)
            Set-Content -LiteralPath (Join-Path $repository 'HEAD') -Value 'ref: refs/heads/main'

            { New-FinOpsReportDirectory -OutputPath (Join-Path $repository 'reports') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $repository 'reports') | Should -BeFalse
        }

        It 'Does not create Git metadata from a report destination' {
            $parent = Join-Path $TestDrive 'not-a-repository'
            [void](New-Item -ItemType Directory -Path $parent)

            { New-FinOpsReportDirectory -OutputPath (Join-Path $parent '.git/reports') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $parent '.git') | Should -BeFalse
        }

        It 'Refuses links and junctions in the destination path' {
            $target = Join-Path $TestDrive 'link-target'
            $link = Join-Path $TestDrive 'report-link'
            [void](New-Item -ItemType Directory -Path $target)
            $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            [void](New-Item -ItemType $linkType -Path $link -Target $target)
            try {
                { New-FinOpsReportDirectory -OutputPath (Join-Path $link 'reports') } | Should -Throw '*links or junctions*'
                Test-Path -LiteralPath (Join-Path $target 'reports') | Should -BeFalse
            }
            finally { Remove-Item -LiteralPath $link -Force }
        }

        It 'Rechecks Git ancestry before writing report content' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'became-repository')
            [void](New-Item -ItemType Directory -Path (Join-Path $run '.git'))

            { Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt' -Lines @('Sensitive fixture') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $run 'ScanSummary.txt') | Should -BeFalse
        }

        It 'Rejects path traversal in report file names' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'file-names')

            { Write-FinOpsReportFile -Directory $run -Name '../escaped.txt' -Lines @('Fixture') } | Should -Throw '*file name*'
            { Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt:stream' -Lines @('Fixture') } | Should -Throw '*file name*'
        }
    }

    Context 'CSV export projections' {
        It 'Protects formula text after <PrefixName> while retaining numeric credits' -Tag 'CsvHardening' -ForEach @(
            @{ PrefixName = 'space'; Prefix = ' ' }
            @{ PrefixName = 'tab'; Prefix = "`t" }
            @{ PrefixName = 'line break'; Prefix = "`n" }
            @{ PrefixName = 'invisible format character'; Prefix = [string][char]0xFEFF }
        ) {
            $value = $Prefix + '=1+1'
            $row = @(ConvertTo-FinOpsExportRows -Fn 'Unknown' -Data ([pscustomobject]@{ Name = $value; Credit = [decimal]-20.5 }) | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]
            $row.Name | Should -Be ("'" + $value)
            $row.Credit | Should -Be '-20.5'
        }

        It 'Rejects unsafe generic CSV headers instead of exporting or renaming them' -Tag 'CsvHardening' {
            foreach ($header in @('=1+1', ' @SUM(1,1)', ([string][char]0xFEFF + '+1'))) {
                { ConvertTo-FinOpsExportRows -Fn 'Unknown' -Data ([pscustomobject]@{ $header = 'fixture' }) } | Should -Throw '*CSV column header*'
                $dictionaryRow = @(ConvertTo-FinOpsExportRows -Fn 'Unknown' -Data ([ordered]@{ $header = 'fixture' }))[0]
                $dictionaryRow.Key | Should -Be ("'" + $header)
            }
        }

        BeforeAll {
            $launcher = Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'
            $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$null)
            foreach ($definition in $launcherAst.FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
                    }, $true)) {
                . ([scriptblock]::Create($definition.Extent.Text))
            }
        }

        It 'Uses invariant amounts and ISO dates under <Culture>' -ForEach @(
            @{ Culture = 'en-US' }
            @{ Culture = 'de-DE' }
        ) {
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::GetCultureInfo($Culture)
                $data = @{ 'sub-a' = @{
                        Actual = [decimal]100.25; Credit = -20.5; Currency = 'EUR'; Name = '-formula'
                        ActualPeriodStart = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                        CapturedAt = [datetimeoffset]::new(2026, 9, 2, 3, 4, 5, [timespan]::FromHours(2))
                    }
                }

                $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostData' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

                $row.Actual | Should -Be '100.25'
                $row.Credit | Should -Be '-20.5'
                $row.ActualPeriodStart | Should -Be '2026-09-01T00:00:00.0000000Z'
                $row.CapturedAt | Should -Be '2026-09-02T03:04:05.0000000+02:00'
                $row.Name | Should -Be "'-formula"
                $generic = @(ConvertTo-FinOpsExportRows -Fn 'Unknown' -Data @{ Credit = -20.5 } | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]
                $generic.Value | Should -Be '-20.5'
            }
            finally { [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture }
        }

        It 'Exports tag values, amounts, and currencies from scanner row objects' {
            $data = [pscustomobject]@{
                CostByTag        = @{
                    CostCenter = @(
                        [pscustomobject]@{ TagValue = 'team-a'; Cost = 100.25; Currency = 'EUR' }
                        [pscustomobject]@{ TagValue = 'team-b'; Cost = -20; Currency = 'EUR' }
                    )
                }
                TagsQueried      = @('CostCenter')
                NoTagsFound      = $false
                Source           = 'Kusto'
                ResourceCostSeen = 80.25
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostByTag' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            $tagRows = @($rows | Where-Object RecordType -EQ 'CostByTag')
            $tagRows.TagValue | Should -Be @('team-a', 'team-b')
            $tagRows.Cost | Should -Be @('100.25', '-20')
            $tagRows.Currency | Should -Be @('EUR', 'EUR')
            foreach ($row in $tagRows) {
                $row.RecordType | Should -Be 'CostByTag'
                $row.'Summary.Source' | Should -Be 'Kusto'
                $row.'Summary.ResourceCostSeen' | Should -Be '80.25'
            }
            ($rows | Where-Object RecordType -EQ 'Summary.TagsQueried').Value | Should -Be 'CostCenter'
        }

        It 'Retains metadata for dictionary-backed scan wrappers' {
            $data = @{
                Reservations = @([pscustomobject]@{ ReservationId = 'ri-1'; AvgUtilization = 90 })
                SavingsPlans = @()
                HasData      = $true
                Note         = 'Validated billing scope'
            }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.ReservationId | Should -Be 'ri-1'
            $row.'Summary.Note' | Should -Be 'Validated billing scope'
            $row.'Summary.HasData' | Should -Be 'True'
            $row.PSObject.Properties.Name | Should -Not -Contain 'Summary.Keys'
        }

        It 'Retains tag diagnostics when no tag rows exist' {
            $data = [pscustomobject]@{ CostByTag = @{}; NoTagsFound = $true; Source = 'Kusto'; Note = 'No tag keys in the selected cost data' }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostByTag' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.RecordType | Should -Be 'Status'
            $row.Status | Should -Be 'No data'
            $row.'Summary.NoTagsFound' | Should -Be 'True'
            $row.'Summary.Source' | Should -Be 'Kusto'
            $row.'Summary.Note' | Should -Be $data.Note
        }

        It 'Exports both commitment families and the underutilized view once' {
            $reservation = [pscustomobject]@{ ReservationId = 'ri-1'; SkuName = 'Standard_D2s_v5'; AvgUtilization = 50 }
            $data = [pscustomobject]@{
                Reservations     = @($reservation)
                SavingsPlans     = @([pscustomobject]@{ BenefitId = 'sp-1'; BenefitOrderId = 'order-1'; AvgUtilization = 75 })
                UnderutilizedRIs = @($reservation)
                RICount          = 1
                SPCount          = 1
                HasData          = $true
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            ($rows | Where-Object RecordType -EQ 'Reservations').ReservationId | Should -Be 'ri-1'
            ($rows | Where-Object RecordType -EQ 'SavingsPlans').BenefitId | Should -Be 'sp-1'
            ($rows | Where-Object RecordType -EQ 'SavingsPlans').BenefitOrderId | Should -Be 'order-1'
            @($rows | Where-Object RecordType -EQ 'Summary.UnderutilizedRIs').Count | Should -Be 1
            $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.UnderutilizedRIs'
        }

        It 'Keeps nested summary exports linear in collection size' {
            $sizes = @()
            foreach ($count in @(100, 200)) {
                $reservations = @(foreach ($index in 1..$count) {
                        [pscustomobject]@{ ReservationId = "reservation-$index"; AvgUtilization = 50; SkuName = 'Standard_D2s_v5' }
                    })
                $data = [pscustomobject]@{ Reservations = $reservations; SavingsPlans = @(); UnderutilizedRIs = $reservations; RICount = $count; HasData = $true }

                $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data)
                $csv = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`n"

                @($rows | Where-Object RecordType -EQ 'Reservations').Count | Should -Be $count
                @($rows | Where-Object RecordType -EQ 'Summary.UnderutilizedRIs').Count | Should -Be $count
                $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.UnderutilizedRIs'
                $sizes += $csv.Length
            }
            $sizes[1] | Should -BeLessThan ($sizes[0] * 2.2)
        }

        It 'Exports raw tag records and tag locations once as distinct views' {
            $data = [pscustomobject]@{
                TagNames = @{ CostCenter = @{ TotalResources = 2; Values = @('team') } }
                CaseVariants = @(); UntaggedResources = @(); TagCount = 1
                RawResults = @([pscustomobject]@{ tagName = 'CostCenter'; tagValue = 'team'; ResourceCount = 2 })
                TagLocations = @{ CostCenter = @('sub-a / rg-a', 'sub-b / rg-b') }
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-TagInventory' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            @($rows | Where-Object RecordType -EQ 'TagNames').Count | Should -Be 1
            @($rows | Where-Object RecordType -EQ 'Summary.RawResults').Count | Should -Be 1
            ($rows | Where-Object RecordType -EQ 'Summary.TagLocations').Value | Should -Be @('sub-a / rg-a', 'sub-b / rg-b')
            $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.RawResults'
        }

        It 'Preserves all primary collections for <Scan>' -ForEach @(
            @{ Scan = 'Get-AHBOpportunities'; Collections = @('WindowsVMs', 'SQLVMs', 'SQLDatabases') }
            @{ Scan = 'Get-AIWorkloadMetrics'; Collections = @('ByModel', 'ByAccount') }
            @{ Scan = 'Get-AnomalyAlerts'; Collections = @('TriggeredAlerts', 'ConfiguredRules') }
            @{ Scan = 'Get-BillingStructure'; Collections = @('BillingAccounts', 'BillingProfiles', 'InvoiceSections', 'EADepartments', 'CostAllocationRules') }
            @{ Scan = 'Get-CarbonMetrics'; Collections = @('MonthlyTrend', 'BySubscription') }
            @{ Scan = 'Get-ReservationAdvice'; Collections = @('AdvisorRecommendations', 'ReservationRecommendations') }
        ) {
            $payload = [ordered]@{ HasData = $true; Note = 'Known scope only' }
            foreach ($collection in $Collections) { $payload[$collection] = @([pscustomobject]@{ Id = $collection; Amount = 12.5 }) }

            $rows = @(ConvertTo-FinOpsExportRows -Fn $Scan -Data ([pscustomobject]$payload) | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be $Collections.Count
            $rows.RecordType | Should -Be $Collections
            $rows.Id | Should -Be $Collections
            foreach ($row in $rows) { $row.'Summary.Note' | Should -Be 'Known scope only' }
        }

        It 'Keeps per-subscription monthly trends alongside aggregate months' {
            $data = [pscustomobject]@{
                HasData        = $true
                Months         = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 30; Currency = 'USD' })
                BySubscription = @{
                    'sub-a' = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 10; Currency = 'USD' })
                    'sub-b' = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 20; Currency = 'USD' })
                }
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostTrend' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            ($rows | Where-Object SubscriptionId -EQ 'sub-a').Cost | Should -Be '10'
            ($rows | Where-Object SubscriptionId -EQ 'sub-b').Cost | Should -Be '20'
            ($rows | Where-Object RecordType -EQ 'Months').Cost | Should -Be '30'
        }

        It 'Preserves nested values as JSON and retains zero-result diagnostics' {
            $nested = @{ Owner = @{ Name = 'team'; Contacts = @('one@example.test', 'two@example.test') } }
            $cell = ConvertTo-FinOpsExportCell $nested
            ($cell | ConvertFrom-Json).Owner.Contacts.Count | Should -Be 2
            $cell | Should -Not -Match 'System\.Collections|System\.Object'
            $data = [pscustomobject]@{ Reservations = @(); SavingsPlans = @(); HasData = $false; AccessDenied = $true; Note = 'Missing billing access' }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 1
            $rows[0].RecordType | Should -Be 'Status'
            $rows[0].Status | Should -Be 'Error'
            $rows[0].Error | Should -Be 'Missing billing access'
            $rows[0].'Summary.AccessDenied' | Should -Be 'True'
            $rows[0].'Summary.Note' | Should -Be 'Missing billing access'
        }

        It 'Labels empty wrapper results while preserving summary collections' {
            $data = [pscustomobject]@{
                Orphans = @(); HasData = $false; TotalCount = 0; Note = 'No orphaned resources found'
                CheckedScopes = @('sub-a', 'sub-b')
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-OrphanedResources' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $statusRows = @($rows | Where-Object RecordType -EQ 'Status')
            $statusRows.Count | Should -Be 1
            $statusRows[0].Status | Should -Be 'No data'
            $statusRows[0].Scan | Should -Be 'Get-OrphanedResources'
            $statusRows[0].'Summary.HasData' | Should -Be 'False'
            $statusRows[0].'Summary.Note' | Should -Be $data.Note
            ($rows | Where-Object RecordType -EQ 'Summary.CheckedScopes').Value | Should -Be @('sub-a', 'sub-b')
        }

        It 'Preserves cost source and period while protecting formula text' {
            $data = @{ 'sub-a' = @{ Actual = -25; Forecast = $null; Currency = 'EUR'; ActualPeriod = '2026-08'; ForecastSource = 'Unavailable'; Name = '=1+1' } }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostData' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.Actual | Should -Be '-25'
            $row.ActualPeriod | Should -Be '2026-08'
            $row.ForecastSource | Should -Be 'Unavailable'
            $row.Forecast | Should -Be ''
            $row.Name | Should -Be "'=1+1"
        }
    }

    Context 'Tag cost presentation' {
        It 'Uses aggregate tag rows for guidance when <Case>' -ForEach @(
            @{ Case = 'cost is untagged'; Tagged = 100.0; Untagged = 20.0; Expected = 'Some untagged spend'; HasRows = $true }
            @{ Case = 'an untagged credit exists'; Tagged = 125.0; Untagged = -5.0; Expected = 'credits|negative'; HasRows = $true }
            @{ Case = 'tagged costs include a credit'; Tagged = -5.0; Untagged = 125.0; Expected = 'credits|negative'; HasRows = $true }
            @{ Case = 'net cost is zero'; Tagged = 0.0; Untagged = 0.0; Expected = 'no positive net cost'; HasRows = $true }
            @{ Case = 'no rows are available'; Tagged = 0.0; Untagged = 0.0; Expected = 'No cost data was returned'; HasRows = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot; Tagged = $Tagged; Untagged = $Untagged; Expected = $Expected; HasRows = $HasRows } {
                param($ModuleRoot, $Tagged, $Untagged, $Expected, $HasRows)
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branch = @($switches.Clauses | Where-Object {
                        $_.Item1.Value -eq 'Get-CostByTag' -and $_.Item2.Extent.Text.Contains('No cost data was returned')
                    })
                $branch.Count | Should -Be 1
                $data = [pscustomobject]@{
                    CostByTag = @{ CostCenter = @(if ($HasRows) {
                                [pscustomobject]@{ TagValue = 'team'; Cost = $Tagged; Currency = 'USD' }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = $Untagged; Currency = 'USD' }
                            })
                    }
                }
                $guidanceItems = @()
                $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                . ([scriptblock]::Create("param(`$data)`n$body")) $data

                ($guidanceItems.Message -join ' ') | Should -Match $Expected
                $guidanceItems.Severity | Should -Not -Contain 'Green'
                if ($HasRows) { ($guidanceItems.Message -join ' ') | Should -Not -Match 'No cost data was returned|No CAF allocation tag' }
            }
        }

        It 'Does not score invalid allocation percentages for <Case>' -ForEach @(
            @{ Case = 'negative aggregate untagged cost'; ResourceTotals = $false; Tagged = 125.0; Untagged = -5.0 }
            @{ Case = 'aggregate untagged cost above the total'; ResourceTotals = $false; Tagged = -5.0; Untagged = 125.0 }
            @{ Case = 'zero aggregate cost'; ResourceTotals = $false; Tagged = 0.0; Untagged = 0.0 }
            @{ Case = 'negative per-resource unallocated cost'; ResourceTotals = $true; Tagged = 125.0; Untagged = -5.0 }
            @{ Case = 'per-resource unallocated cost above the total'; ResourceTotals = $true; Tagged = -5.0; Untagged = 125.0 }
            @{ Case = 'zero per-resource cost'; ResourceTotals = $true; Tagged = 0.0; Untagged = 0.0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ResourceTotals = $ResourceTotals; Tagged = $Tagged; Untagged = $Untagged } {
                param($ResourceTotals, $Tagged, $Untagged)
                $data = if ($ResourceTotals) {
                    [pscustomobject]@{ ResourceCostSeen = $Tagged + $Untagged; UnallocatedCost = $Untagged }
                }
                else {
                    [pscustomobject]@{ CostByTag = @{ CostCenter = @(
                                [pscustomobject]@{ TagValue = 'team'; Cost = $Tagged }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = $Untagged }
                            )
                        }
                    }
                }
                $result = Add-KpiInsights -Result @{ tool = 'scan_cost_by_tag'; data = $data }
                foreach ($insight in $result.kpiInsights | Where-Object kpiId -In @('pct-costs-untagged', 'pct-costs-unallocated', 'tagging-policy-compliant')) {
                    $insight.status | Should -Be 'unavailable'
                    $insight.numericValue | Should -BeNullOrEmpty
                    $insight.yourValue | Should -Match 'Unavailable'
                }
            }
        }

        It 'Keeps valid allocation percentages for <Case>' -ForEach @(
            @{ Case = 'aggregate rows'; ResourceTotals = $false }
            @{ Case = 'resource totals'; ResourceTotals = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ResourceTotals = $ResourceTotals } {
                param($ResourceTotals)
                $data = if ($ResourceTotals) {
                    [pscustomobject]@{ ResourceCostSeen = 100.0; UnallocatedCost = 20.0 }
                }
                else {
                    [pscustomobject]@{ CostByTag = @{ CostCenter = @(
                                [pscustomobject]@{ TagValue = 'team'; Cost = 80.0 }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = 20.0 }
                            )
                        }
                    }
                }
                (Get-KpiComputedValue -KpiId 'pct-costs-untagged' -Data $data).Value | Should -Be 20
                (Get-KpiComputedValue -KpiId 'tagging-policy-compliant' -Data $data).Value | Should -Be 80
            }
        }
    }

    Context 'Savings estimate contract' {
        BeforeEach {
            Mock Write-Host -ModuleName FinOpsMultitool { }
            Mock Get-Date -ModuleName FinOpsMultitool { [datetime]::new(2026, 9, 16, 12, 0, 0, [DateTimeKind]::Utc) }
            Mock Resolve-CostMgId -ModuleName FinOpsMultitool { $null }
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                @{ Data = @([pscustomobject]@{ vmSize = 'Standard_D2s_v5'; location = 'eastus' }) }
            }
            Mock Get-AhbVmRates -ModuleName FinOpsMultitool { [pscustomobject]@{ HourlyPremium = 0.1 } }
            Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Savings tests must not access the network.' }
        }

        It 'Separates <BillingCurrency> month-to-date commitments from the USD AHB run rate' -ForEach @(
            @{ BillingCurrency = 'EUR' }
            @{ BillingCurrency = 'USD' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ BillingCurrency = $BillingCurrency } {
                param($BillingCurrency)
                $fixtureCurrency = $BillingCurrency
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    $properties = @{
                        columns = @(@{ name = 'Currency' }, @{ name = $dimension }, @{ name = 'Cost' })
                        rows    = @(, @($fixtureCurrency, $category, 100.0))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result = Get-SavingsRealized -Subscriptions $subscriptions

                $result.Currency | Should -Be $fixtureCurrency
                $result.RISavingsMonthToDate | Should -Be 66.67
                $result.CommitmentSavingsMonthToDate | Should -Be 66.67
                $result.AHBSavingsMonthly | Should -Be 73
                $result.AHBCurrency | Should -Be 'USD'
                $result.AHBPeriod | Should -Match '730'
                $result.TotalMonthly | Should -BeNullOrEmpty
                $result.TotalAnnual | Should -BeNullOrEmpty
                $result.RISavingsMonthly | Should -BeNullOrEmpty
                $result.Period | Should -Be '2026-09-01T00:00:00Z to 2026-09-16T12:00:00Z'
                @($result.Details | Where-Object Type -NE 'AHB').Currency | Select-Object -Unique | Should -Be $fixtureCurrency
                ($result.Details | Where-Object Type -EQ 'AHB').Currency | Should -Be 'USD'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $request.timeframe -eq 'Custom' -and
                    ([datetime]$request.timePeriod.from).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -eq '2026-09-01T00:00:00Z' -and
                    ([datetime]$request.timePeriod.to).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -eq '2026-09-16T12:00:00Z'
                }
                $kpi = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $result
                $kpi.Display | Should -Match "$fixtureCurrency 66.67"
                $kpi.Display | Should -Not -Match '/ month|annual'
            }
        }

        It 'Rejects <Case> rather than guessing or combining currencies' -ForEach @(
            @{ Case = 'missing currency'; First = ''; Second = ''; IncludeColumn = $true }
            @{ Case = 'missing currency column'; First = 'EUR'; Second = 'EUR'; IncludeColumn = $false }
            @{ Case = 'mixed billing currencies'; First = 'EUR'; Second = 'USD'; IncludeColumn = $true }
            @{ Case = 'no-currency code'; First = 'XXX'; Second = 'XXX'; IncludeColumn = $true }
            @{ Case = 'test currency code'; First = 'XTS'; Second = 'XTS'; IncludeColumn = $true }
            @{ Case = 'unsupported currency code'; First = 'ABC'; Second = 'ABC'; IncludeColumn = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ First = $First; Second = $Second; IncludeColumn = $IncludeColumn } {
                param($First, $Second, $IncludeColumn)
                $firstCurrency = $First
                $secondCurrency = $Second
                $hasCurrencyColumn = $IncludeColumn
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    $currency = if ($Path -like '/subscriptions/11111111-*') { $firstCurrency } else { $secondCurrency }
                    $properties = @{ columns = @(@{ name = $dimension }, @{ name = 'Cost' }); rows = @(, @($category, 100.0)) }
                    if ($hasCurrencyColumn) {
                        $properties.columns += @{ name = 'Currency' }
                        $properties.rows = @(, @($category, 100.0, $currency))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                { Get-SavingsRealized -Subscriptions $subscriptions } | Should -Throw '*currenc*'
            }
        }

        It 'Excludes purchases, refunds, and unused commitments before aggregation' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    if ($request.type -eq 'ActualCost') {
                        $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ChargeType' }, @{ name = 'Currency' }); rows = @() }
                    }
                    else {
                        $charges = @(
                            @{ ChargeType = 'Usage'; Cost = 100.0 }
                            @{ ChargeType = 'Refund'; Cost = -90.0 }
                            @{ ChargeType = 'Purchase'; Cost = 1000.0 }
                            @{ ChargeType = 'UnusedReservation'; Cost = 30.0 }
                        )
                        $filter = $request.dataset.filter.dimensions
                        if ($filter.name -eq 'ChargeType' -and $filter.operator -eq 'In') {
                            $charges = @($charges | Where-Object { $_.ChargeType -in $filter.values })
                        }
                        $amount = ($charges | Measure-Object Cost -Sum).Sum
                        $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'PricingModel' }, @{ name = 'Currency' }); rows = @(, @($amount, 'Reservation', 'EUR')) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.CommitmentSavingsMonthToDate | Should -Be 66.67
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $request.type -eq 'AmortizedCost' -and $request.dataset.filter.dimensions.name -eq 'ChargeType' -and
                    $request.dataset.filter.dimensions.operator -eq 'In' -and (@($request.dataset.filter.dimensions.values) -join ',') -eq 'Usage'
                }
            }
        }

        It 'Rejects negative usage adjustments of <Amount> without partial savings' -ForEach @(
            @{ Amount = -100.0 }
            @{ Amount = -0.001 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Adjustment = $Amount } {
                param($Adjustment)
                $fixtureAdjustment = $Adjustment
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = $dimension }, @{ name = 'Currency' }); rows = @() }
                    if ($request.type -eq 'AmortizedCost') { $properties.rows = @(, @($fixtureAdjustment, 'Reservation', 'USD')) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $received = [System.Collections.Generic.List[object]]::new()

                { Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) |
                    ForEach-Object { $received.Add($_) } } | Should -Throw '*negative adjustments*'

                $received.Count | Should -Be 0
            }
        }

        It 'Rejects a currency change on a later page without emitting partial savings' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    $isNext = $Path -like '*page=2'
                    $currency = if ($isNext) { 'USD' } else { 'EUR' }
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = 'ChargeType' }, @{ name = 'Currency' })
                        rows    = @(, @(100.0, 'UnusedReservation', $currency))
                    }
                    if (-not $isNext) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $received = [System.Collections.Generic.List[object]]::new()

                { Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) |
                    ForEach-Object { $received.Add($_) } } | Should -Throw '*multiple billing currencies*'

                $received.Count | Should -Be 0
            }
        }

        It 'Discards a failed management-group attempt including its currency' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $isManagementGroup = $Path -like '/providers/Microsoft.Management/*'
                    if ($isManagementGroup -and $request.type -eq 'AmortizedCost') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $currency = if ($isManagementGroup) { 'GBP' } else { 'EUR' }
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{
                                    columns = @(@{ name = $dimension }, @{ name = 'Currency' }, @{ name = 'Cost' })
                                    rows    = @(, @($category, $currency, 100.0))
                                }
                            } | ConvertTo-Json -Depth 8)
                    }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                $result = Get-SavingsRealized -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -WarningAction SilentlyContinue

                $result.Currency | Should -Be 'EUR'
                $result.CommitmentSavingsMonthToDate | Should -Be 133.33
                $result.Details.Currency | Select-Object -Unique | Should -Be 'EUR'
                @($result.Details | Where-Object Type -EQ 'Waste').Count | Should -Be 2
            }
        }

        It 'Retains an AHB read failure without inventing zero or a commitment currency' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { throw '403: inventory unavailable' }
                Mock Invoke-AzRestMethodWithRetry { throw 'A confirmed empty commitment inventory should skip cost queries.' }

                $result = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) -CommitmentData ([pscustomobject]@{ HasData = $false }) -WarningAction SilentlyContinue

                $result.AHBSavingsMonthly | Should -BeNullOrEmpty
                $result.AHBIssue | Should -Match '403'
                $result.Currency | Should -BeNullOrEmpty
                $result.CommitmentSavingsMonthToDate | Should -BeNullOrEmpty
                $result.HasData | Should -BeFalse
            }
        }

        It 'Does not substitute USD for an unknown savings currency in the KPI' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ CommitmentSavingsMonthToDate = 66.67; Period = 'Month to date'; TotalMonthly = 66.67 }

                $result = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $data

                $result.Value | Should -BeNullOrEmpty
                $result.Display | Should -Match 'Unavailable.*currency'
            }
        }
    }

    Context 'Savings estimate presentation' {
        It 'Labels terminal, guidance, HTML, and KPI output as estimates' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $formatter = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-ColorizedLine' }, $true)
                . ([scriptblock]::Create($formatter.Extent.Text))
                $captured = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { [void]$captured.Add([string]$Object) }
                Mock Write-ColorizedLine { [void]$captured.Add($Text) }
                Mock Get-Date { [datetime]::new(2026, 9, 16, 12, 0, 0, [DateTimeKind]::Utc) }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'Usage' } else { 'Reservation' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{
                                    columns = @(@{ name = 'Cost' }, @{ name = $dimension }, @{ name = 'Currency' })
                                    rows    = @(, @(100.0, $category, 'EUR'))
                                }
                            } | ConvertTo-Json -Depth 8)
                    }
                }
                Mock Search-AzGraphSafe { @{ Data = @([pscustomobject]@{ vmSize = 'Standard_D2s_v5'; location = 'eastus' }) } }
                Mock Get-AhbVmRates { [pscustomobject]@{ HourlyPremium = 0.1 } }
                $data = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })
                $htmlSb = [System.Text.StringBuilder]::new()
                $guidanceItems = @()
                $tableNote = $null
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-SavingsRealized' })
                $branches.Count | Should -Be 3
                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                ($captured -join ' ') | Should -Match 'Estimated savings'
                ($captured -join ' ') | Should -Match 'EUR 66.67'
                ($captured -join ' ') | Should -Match 'USD 73.00'
                ($captured -join ' ') | Should -Not -Match 'Total monthly:|Annual:'
                ($guidanceItems.Message -join ' ') | Should -Match 'Estimated savings'
                ($guidanceItems.Message -join ' ') | Should -Not -Match 'Realizing|Run-level'
                $htmlSb.ToString() | Should -Match 'Estimated commitment savings'
                $htmlSb.ToString() | Should -Match 'EUR 66.67'
                $htmlSb.ToString() | Should -Match 'USD 73.00'
                $htmlSb.ToString() | Should -Match '730-hour'
                $tableNote | Should -Be $data.EstimateBasis
                $kpi = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $data
                $kpi.Display | Should -Match 'estimated savings'
                $kpi.Display | Should -Not -Match 'realized'
                $catalog = Get-Content -LiteralPath (Join-Path $ModuleRoot 'kpi/kpi-catalog.json') -Raw | ConvertFrom-Json
                $definition = $catalog.kpis | Where-Object id -EQ 'effective-savings-rate'
                $definition.unit | Should -Be 'currency/period'
                $definition.plainLanguage | Should -Match 'estimates'
            }
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

        It 'Rejects unreadable values and malformed numeric grouping' {
            { ConvertTo-ExportAmount 'not-a-number' } | Should -Throw '*cost*'
            { ConvertTo-ExportAmount '' } | Should -Throw '*cost*'
            { ConvertTo-ExportAmount '123,45' } | Should -Throw '*grouping*'
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

        # 'CostStatus' contains 'cost'. A substring match picked it up and, because
        # the loop kept going, the later match won -- so the cost index pointed at
        # a column holding the text 'Actual' or 'Forecast'.
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

        # Month-to-date spend presented as a forecast understates the full month,
        # so callers need to be able to tell the two apart.
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

    Context 'Budget spend source' {

        # An annual budget compared against one month of subscription spend reads as
        # roughly a twelfth of its real consumption, so an exhausted budget reports
        # On Track. Azure already computes currentSpend for the budget's own scope,
        # filter and time grain.
        It 'Prefers the budget currentSpend over subscription month-to-date' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'annual-budget'
                    properties = [pscustomobject]@{
                        amount        = 12000
                        timeGrain     = 'Annually'
                        category      = 'Cost'
                        currentSpend  = [pscustomobject]@{ amount = 11400; unit = 'USD' }
                        forecastSpend = [pscustomobject]@{ amount = 13000; unit = 'USD' }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = (@{ value = @($budget) } | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333'; Name = 'test' })
                # Subscription month-to-date is a small fraction of the annual budget.
                $costData = @{ '33333333-3333-3333-3333-333333333333' = @{ Actual = 900; Forecast = 1000 } }

                $res = Get-BudgetStatus -Subscriptions $subs -CostData $costData
                $b = @($res.Budgets)[0]

                $b.SpendSource | Should -Be 'Budget'
                $b.ActualSpend | Should -Be 11400
                # 11400/12000 = 95%, and the forecast exceeds the budget.
                $b.Risk | Should -Be 'Forecast Over'
            }
        }
    }

    Context 'Export scope' {
        It 'Keeps unattributed resource charges in the selected subscription total' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @(
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = 'USD'; ResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.Compute/disks/test" }
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 20; Currency = 'USD'; ResourceId = '' }
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = -5; Currency = 'USD'; ResourceId = $null }
                    )
                }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'test' })

                $rows = @(ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions)

                ($rows | Measure-Object Actual -Sum).Sum | Should -Be 25
                ($rows | Where-Object ResourcePath -EQ '(non-resource charges)').Actual | Should -Be 15
                ($rows | Where-Object ResourcePath -EQ '(non-resource charges)').Subscription | Should -Be 'test'
            }
        }

        It 'Retains each subscription period in <Source> summaries' -ForEach @(
            @{ Source = 'Hub' }
            @{ Source = 'Export' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source } {
                param($Source)
                $currentId = '44444444-4444-4444-4444-444444444444'
                $staleId = '55555555-5555-5555-5555-555555555555'
                $rows = @(
                    [pscustomobject]@{ SubAccountId = $currentId; BilledCost = 10; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-16' }
                    [pscustomobject]@{ SubAccountId = $staleId; BilledCost = 20; BillingCurrency = 'USD'; ChargePeriodStart = '2026-08-31' }
                )
                $result = if ($Source -eq 'Hub') { ConvertTo-CostDataFromHub -HubData $rows }
                else { ConvertTo-CostDataFromExport -ExportData ([pscustomobject]@{ Rows = $rows }) -Subscriptions @([pscustomobject]@{ Id = $currentId }, [pscustomobject]@{ Id = $staleId }) }

                $result[$currentId].ActualPeriod | Should -Be '2026-09-16 to 2026-09-16'
                $result[$staleId].ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                $result[$currentId].Actual | Should -Be 10
                $result[$staleId].Actual | Should -Be 20
            }
        }

        It 'Reports historical actuals without synthesizing a current-month forecast' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $data = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Rows      = @([pscustomobject]@{
                            SubscriptionId = $subscriptionId; Cost = 100; Currency = 'EUR'; Date = '2026-08-31'
                            ResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.Compute/disks/test"
                        })
                }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'test' })

                $summary = (ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions)[$subscriptionId]
                $resource = @(ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions)[0]

                foreach ($entry in @($summary, $resource)) {
                    $entry.Actual | Should -Be 100
                    $entry.Forecast | Should -BeNullOrEmpty
                    $entry.ForecastSource | Should -Be 'Unavailable'
                    $entry.ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                }
            }
        }

        It 'Requires a verified basis for a classic export (<Basis>)' -ForEach @(
            @{ Basis = $null }
            @{ Basis = 'Usage' }
            @{ Basis = 'AmortizedCost' }
            @{ Basis = 'ActualCost' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Basis = $Basis } {
                param($Basis)
                $data = [pscustomobject]@{
                    CostBasis = $Basis; Currency = 'USD'
                    Rows = @([pscustomobject]@{ SubscriptionId = '44444444-4444-4444-4444-444444444444'; CostInBillingCurrency = 100 })
                }
                if ($Basis -eq 'ActualCost') {
                    (Select-CostExportData -ExportData $data).Rows[0].Cost | Should -Be 100
                }
                else { { Select-CostExportData -ExportData $data } | Should -Throw '*actual cost*' }
            }
        }

        # An export is written at its own scope, usually the whole billing account.
        # Treating an unrecognised subscription as a new entry reported cost for
        # every subscription in the file, not the ones the user asked to scan.
        It 'Ignores rows for subscriptions that were not selected' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'

                $exportData = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Currency  = 'USD'
                    ColMap    = [pscustomobject]@{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId'; ResourceId = $null }
                    Rows      = @(
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

        It 'Uses the same selected billed-cost rows for <View>' -ForEach @(
            @{ View = 'Summary' }
            @{ View = 'Resources' }
            @{ View = 'Tags' }
            @{ View = 'Trend' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ View = $View } {
                param($View)
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'
                $rows = @(
                    [pscustomobject]@{ SubscriptionId = $selected; BilledCost = 10; EffectiveCost = 1; BillingCurrency = 'USD'; Date = '2026-09-01'; ResourceId = "/subscriptions/$selected/resourceGroups/test/providers/Microsoft.Compute/disks/one"; Tags = '{"CostCenter":"test"}' }
                    [pscustomobject]@{ SubscriptionId = $other; BilledCost = 990; EffectiveCost = 99; BillingCurrency = 'EUR'; Date = '2026-09-01'; ResourceId = "/subscriptions/$other/resourceGroups/test/providers/Microsoft.Compute/disks/two"; Tags = '{"CostCenter":"other"}' }
                )
                $data = [pscustomobject]@{ Rows = $rows; ColMap = (Resolve-ExportColumns -Header $rows[0].PSObject.Properties.Name); Currency = 'USD' }
                $subscriptions = @([pscustomobject]@{ Id = $selected; Name = 'selected' })
                $total = switch ($View) {
                    'Summary' { (ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions)[$selected].Actual }
                    'Resources' { (ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions | Measure-Object Actual -Sum).Sum }
                    'Tags' { ((ConvertTo-CostByTagFromExport -ExportData $data -Subscriptions $subscriptions).CostByTag.CostCenter | Measure-Object Cost -Sum).Sum }
                    'Trend' { ((ConvertTo-CostTrendFromExport -ExportData $data -Subscriptions $subscriptions).Months | Measure-Object Cost -Sum).Sum }
                }
                $total | Should -Be 10
            }
        }

        It 'Does not report an uncovered selected subscription as zero spend' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $missing = '55555555-5555-5555-5555-555555555555'
                $data = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Currency = 'USD'; ColMap = @{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId' }
                    Rows = @([pscustomobject]@{ Cost = 10; SubscriptionId = $selected })
                }
                $subscriptions = @([pscustomobject]@{ Id = $selected }, [pscustomobject]@{ Id = $missing })
                { ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions } | Should -Throw '*coverage*'
            }
        }

        It 'Rejects unreadable export costs instead of using zero' -ForEach @(
            @{ Value = '' }
            @{ Value = 'bad' }
            @{ Value = 'NaN' }
            @{ Value = 'Infinity' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Value = $Value } {
                param($Value)
                $rawValue = $Value
                { ConvertTo-ExportAmount -Value $rawValue } | Should -Throw '*cost*'
            }
        }

        It 'Merges resource and date aliases using row subscription IDs instead of storage ownership' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'
                Mock Get-CostExportData {
                    $row = if ($Export.Name -eq 'first') {
                        [pscustomobject]@{ SubscriptionId = $selected; BilledCost = 10; Currency = 'USD'; ResourceId = "/subscriptions/$selected/resourceGroups/test/providers/Microsoft.Compute/disks/one"; Date = '2026-09-01' }
                    }
                    else {
                        [pscustomobject]@{ SubAccountId = "/subscriptions/$other"; BilledCost = 20; BillingCurrency = 'USD'; x_ResourceId = "/subscriptions/$other/resourceGroups/test/providers/Microsoft.Compute/disks/two"; ChargePeriodStart = '2026-09-01' }
                    }
                    [pscustomobject]@{ Rows = @($row); ColMap = (Resolve-ExportColumns -Header $row.PSObject.Properties.Name); DataDate = [datetime]'2026-09-15'; Currency = 'USD' }
                }
                $exports = @([pscustomobject]@{ Name = 'first'; SubId = 'storage-owner'; ScopeKind = 'Storage' }, [pscustomobject]@{ Name = 'second'; SubId = 'storage-owner'; ScopeKind = 'Storage' })
                $subscriptions = @([pscustomobject]@{ Id = $selected; Name = 'first' }, [pscustomobject]@{ Id = $other; Name = 'second' })

                $merged = Get-MergedCostExportData -Exports $exports -Subscriptions $subscriptions

                $merged.ExportCount | Should -Be 2
                @($merged.CoveredSubscriptionIds).Count | Should -Be 2
                (ConvertTo-ResourceCostsFromExport -ExportData $merged -Subscriptions $subscriptions | Measure-Object Actual -Sum).Sum | Should -Be 30
                ((ConvertTo-CostTrendFromExport -ExportData $merged).Months | Measure-Object Cost -Sum).Sum | Should -Be 30
            }
        }

        It 'Rejects an unreadable or incompatible export rather than omitting it (<Case>)' -ForEach @(
            @{ Case = 'unreadable'; Currency = $null }
            @{ Case = 'different currency'; Currency = 'EUR' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $secondCurrency = $Currency
                Mock Get-CostExportData {
                    if ($Export.Name -eq 'second' -and -not $secondCurrency) { return [pscustomobject]@{ Rows = @(); NoData = $true; AccessDenied = $true } }
                    $subscriptionId = if ($Export.Name -eq 'first') { '44444444-4444-4444-4444-444444444444' } else { '55555555-5555-5555-5555-555555555555' }
                    $rowCurrency = if ($Export.Name -eq 'first') { 'USD' } else { $secondCurrency }
                    [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @([pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = $rowCurrency }); ColMap = @{ SubscriptionId = 'SubscriptionId'; Cost = 'Cost'; Currency = 'Currency' } }
                }
                { Get-MergedCostExportData -Exports @([pscustomobject]@{ Name = 'first' }, [pscustomobject]@{ Name = 'second' }) } | Should -Throw
            }
        }

        It 'Retains readable exports when another account denies container discovery' -Tag 'AutomaticExportDiscovery' {
            InModuleScope FinOpsMultitool {
                $storagePrefix = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/'
                Mock Get-ExportStorageCandidates {
                    @([pscustomobject]@{ Name = 'deniedstore'; ResourceId = "${storagePrefix}deniedstore"; SubId = '11111111-1111-1111-1111-111111111111' }, [pscustomobject]@{ Name = 'readablestore'; ResourceId = "${storagePrefix}readablestore"; SubId = '11111111-1111-1111-1111-111111111111' })
                }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageContainerList {
                    if ($BlobBase -like '*deniedstore.*') { throw 'Synthetic container listing HTTP 403.' }
                    @{ Listed = $true; Containers = @('exports') }
                }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @([pscustomobject]@{ Name = 'costs/focus/20260901-20260930/run/part.csv'; LastModified = [datetime]'2026-10-01' }) }
                }

                $result = @(Find-CostExportFromStorage -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example' }) -WarningAction SilentlyContinue -WarningVariable discoveryWarnings)

                $result.Count | Should -Be 1
                $result[0].StorageResourceId | Should -Be "${storagePrefix}readablestore"
                @($discoveryWarnings).Count | Should -Be 1
                Should -Invoke Get-StorageContainerList -Times 2 -Exactly
                Should -Invoke Get-StorageBlobList -Times 1 -Exactly -ParameterFilter { $BlobBase -eq 'https://readablestore.blob.core.windows.net' -and $Container -eq 'exports' }
            }
        }

        It 'Stops extended export discovery before requests on a tenant mismatch' -Tag 'AutomaticExportDiscovery' {
            InModuleScope FinOpsMultitool {
                Mock Get-AzContext { [pscustomobject]@{ Tenant = @{ Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' } } }
                Mock Search-AzGraphSafe { throw 'No resource query is allowed.' }
                Mock Invoke-AzRestMethodWithRetry { throw 'No ARM request is allowed.' }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                { Find-CostExport -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -IncludeManagementGroups -IncludeBillingAccounts } | Should -Throw '*verified selected tenant*'

                Should -Invoke Search-AzGraphSafe -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
            }
        }

        It 'Uses container metadata to find exports without probing unrelated account data' -Tag 'AutomaticExportDiscovery' {
            InModuleScope FinOpsMultitool {
                $storagePrefix = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/'
                Mock Get-ExportStorageCandidates {
                    @([pscustomobject]@{ Name = 'applicationstore'; ResourceId = "${storagePrefix}applicationstore"; SubId = '11111111-1111-1111-1111-111111111111' }, [pscustomobject]@{ Name = 'exportstore'; ResourceId = "${storagePrefix}exportstore"; SubId = '11111111-1111-1111-1111-111111111111' })
                }
                Mock Invoke-AzRestMethodWithRetry {
                    $containerName = if ($Path -like '*applicationstore/*') { 'appdata' } else { 'exports' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = '$web' }, @{ name = $containerName }, @{ name = '$logs' }) } | ConvertTo-Json -Depth 5) }
                }
                Mock Get-StorageContainerList { throw 'Blob-service container enumeration must not run when metadata is readable.' }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @([pscustomobject]@{ Name = 'costs/focus/20260901-20260930/run/part.csv'; LastModified = [datetime]'2026-10-01' }) }
                }

                $result = @(Find-CostExportFromStorage -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example' }))

                $result.Count | Should -Be 1
                $result[0].Container | Should -Be 'exports'
                Should -Invoke Get-StorageContainerList -Times 0 -Exactly
                Should -Invoke Get-StorageBlobList -Times 1 -Exactly -ParameterFilter { $BlobBase -eq 'https://exportstore.blob.core.windows.net' -and $Container -eq 'exports' }
                Should -Invoke Get-PlainAccessToken -Times 1 -Exactly
            }
        }

        It 'Finds central exports only at selected-subscription ancestors and linked billing accounts' -Tag 'AutomaticExportDiscovery' {
            InModuleScope FinOpsMultitool {
                $selectedId = '11111111-1111-1111-1111-111111111111'
                Mock Get-AzContext { [pscustomobject]@{ Tenant = @{ Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } } }
                Mock Search-AzGraphSafe {
                    @{ Data = @(
                        [pscustomobject]@{ subscriptionId = $selectedId; ancestors = @(@{ name = 'platform'; displayName = 'Example platform' }, @{ name = 'platform'; displayName = 'Example platform' }) }
                        [pscustomobject]@{ subscriptionId = '99999999-9999-9999-9999-999999999999'; ancestors = @(@{ name = 'unrelated'; displayName = 'Outside scope' }) }
                    ) }
                }
                Mock Get-FinOpsBillingScope {
                    [pscustomobject]@{ Accounts = @($BillingAccounts | Where-Object name -EQ 'linked'); Resolved = $true; CoverageIncomplete = $false }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -eq '/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01') {
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'linked'; id = '/providers/Microsoft.Billing/billingAccounts/linked'; properties = @{ displayName = 'Example billing' } }, @{ name = 'outside'; id = '/providers/Microsoft.Billing/billingAccounts/outside'; properties = @{ displayName = 'Unrelated billing' } }) } | ConvertTo-Json -Depth 6) }
                    }
                    if ($Path -like '/subscriptions/*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    if ($Path -notmatch '/managementGroups/platform/|/billingAccounts/linked/') { throw 'Unexpected wider scope.' }
                    $exportName = if ($Path -match 'managementGroups') { 'management-export' } else { 'billing-export' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = $exportName; properties = @{ format = 'Csv'; definition = @{ type = 'FocusCost' }; deliveryInfo = @{ destination = @{ resourceId = "/subscriptions/$selectedId/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example"; container = 'billingdata'; rootFolderPath = 'costs' } } } }) } | ConvertTo-Json -Depth 9) }
                }
                $subscriptions = @([pscustomobject]@{ Id = $selectedId; Name = 'Example'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $result = @(Find-CostExport -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -IncludeManagementGroups -IncludeBillingAccounts -SkipRunHistory)

                $result.Count | Should -Be 2
                $result.ScopeKind | Should -Contain 'ManagementGroup'
                $result.ScopeKind | Should -Contain 'BillingAccount'
                $result.Container | Select-Object -Unique | Should -Be 'billingdata'
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter { @($Subscription).Count -eq 1 -and $Subscription[0] -eq '11111111-1111-1111-1111-111111111111' -and $All }
                Should -Invoke Get-FinOpsBillingScope -Times 1 -Exactly -ParameterFilter { @($Subscriptions).Count -eq 1 -and $Subscriptions[0].Id -eq '11111111-1111-1111-1111-111111111111' }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly -ParameterFilter { $Path -match '/managementGroups/unrelated/|/billingAccounts/outside/|/managementGroups\?' }
            }
        }

        It 'Uses consistent UTC export months under <CultureName>' -Tag 'GenericExportStorage' -ForEach @(
            @{ CultureName = 'en-US' }
            @{ CultureName = 'en-GB' }
            @{ CultureName = 'de-DE' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ CultureName = $CultureName } {
                param($CultureName)
                $originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
                try {
                    [Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::GetCultureInfo($CultureName)
                    $rows = @(
                        [pscustomobject]@{ SubscriptionId = '11111111-1111-1111-1111-111111111111'; Cost = 10; Currency = 'USD'; Date = '20260930' }
                        [pscustomobject]@{ SubscriptionId = '11111111-1111-1111-1111-111111111111'; Cost = 20; Currency = 'USD'; Date = '2026-10-01T00:30:00+02:00' }
                    )
                    $result = ConvertTo-CostTrendFromExport -ExportData ([pscustomobject]@{ Rows = $rows; CostBasis = 'ActualCost' })
                    $result.Months.Count | Should -Be 1
                    $result.Months[0].Cost | Should -Be 30
                    $result.Months[0].MonthDate | Should -Be ([datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc))
                    $result.Months[0].MonthDate.Kind | Should -Be ([DateTimeKind]::Utc)
                }
                finally { [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture }
            }
        }

        It 'Reads all selected-export parts from the same run (gzip: <Compressed>)' -Tag 'GenericExportStorage' -ForEach @(
            @{ Compressed = $false }
            @{ Compressed = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Compressed = $Compressed } {
                param($Compressed)
                $fixturePartSuffix = if ($Compressed) { '.csv.gz' } else { '.csv' }
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = "costs/selected/20260901-20260930/run/part#1$fixturePartSuffix"; LastModified = [datetime]'2026-10-01' }
                            [pscustomobject]@{ Name = "costs/selected/20260901-20260930/run/part2$fixturePartSuffix"; LastModified = [datetime]'2026-10-01' }
                            [pscustomobject]@{ Name = "costs/selected/20260901-20260930/run/nested/other$fixturePartSuffix"; LastModified = [datetime]'2026-09-01' }
                        )
                    }
                }
                $fixturePartBytes = [Text.Encoding]::UTF8.GetBytes("SubscriptionId,Cost,Currency,Date`n11111111-1111-1111-1111-111111111111,10,USD,2026-09-30")
                if ($Compressed) {
                    $buffer = [IO.MemoryStream]::new()
                    $gzip = [IO.Compression.GZipStream]::new($buffer, [IO.Compression.CompressionMode]::Compress, $true)
                    try { $gzip.Write($fixturePartBytes, 0, $fixturePartBytes.Length) }
                    finally { $gzip.Dispose() }
                    $fixturePartBytes = $buffer.ToArray()
                    $buffer.Dispose()
                }
                Mock Get-StorageBlobBytes { , $fixturePartBytes }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'ActualCost'; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/examplestorage' }

                $result = Get-CostExportData -Export $export

                $result.RowCount | Should -Be 2
                $result.CostBasis | Should -Be 'ActualCost'
                Should -Invoke Get-StorageBlobBytes -Times 2 -Exactly
                Should -Invoke Get-StorageBlobBytes -Times 1 -Exactly -ParameterFilter { $Uri -like '*part%231.csv*' }
                Should -Invoke Get-StorageBlobBytes -Times 0 -Exactly -ParameterFilter { $Uri -like '*nested*' }
            }
        }

        It 'Follows <Kind> discovery pages within the selected subscription' -Tag 'GenericExportStorage' -ForEach @(
            @{ Kind = 'definitions' }
            @{ Kind = 'storage accounts' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Kind = $Kind } {
                param($Kind)
                $discoveryKind = $Kind
                $subscriptionId = '11111111-1111-1111-1111-111111111111'
                Mock Invoke-AzRestMethodWithRetry {
                    $number = if ($Path -like '*page=2') { 2 } else { 1 }
                    $item = if ($discoveryKind -eq 'definitions') {
                        @{ name = "export$number"; properties = @{ format = 'Csv'; definition = @{ type = 'ActualCost' }; deliveryInfo = @{ destination = @{ resourceId = "/subscriptions/$subscriptionId/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example"; container = 'exports'; rootFolderPath = 'costs' } } } }
                    }
                    else { @{ name = "storage$number"; id = "/subscriptions/$subscriptionId/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/storage$number" } }
                    $payload = @{ value = @($item) }
                    if ($number -eq 1) { $payload.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = ($payload | ConvertTo-Json -Depth 10) }
                }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'Example' })

                $result = if ($Kind -eq 'definitions') { @(Find-CostExport -Subscriptions $subscriptions -SkipRunHistory) } else { @(Get-ExportStorageCandidates -Subscriptions $subscriptions) }

                $result.Count | Should -Be 2
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Path -like '/subscriptions/11111111-1111-1111-1111-111111111111/*' }
            }
        }

        It 'Keeps a selected export inside its exact folder' -Tag 'GenericExportStorage' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @([pscustomobject]@{ Name = 'another-export/20260901-20260930/run/part.csv'; LastModified = [datetime]'2026-10-01' }) }
                }
                Mock Get-StorageBlobBytes { throw 'A different export must not be downloaded.' }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/examplestorage' }

                $result = Get-CostExportData -Export $export

                $result.NoData | Should -BeTrue
                Should -Invoke Get-StorageBlobList -Times 1 -Exactly -ParameterFilter { $Prefix -ceq 'costs/selected/' }
                Should -Invoke Get-StorageBlobBytes -Times 0 -Exactly
            }
        }

        It 'Rejects <Failure> storage pagination for <Listing>' -Tag 'GenericExportStorage' -ForEach @(
            @{ Failure = 'failed second page'; Listing = 'blobs'; Repeat = $false }
            @{ Failure = 'repeated marker'; Listing = 'blobs'; Repeat = $true }
            @{ Failure = 'failed second page'; Listing = 'containers'; Repeat = $false }
            @{ Failure = 'repeated marker'; Listing = 'containers'; Repeat = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Listing = $Listing; Repeat = $Repeat } {
                param($Listing, $Repeat)
                $fixtureListing = $Listing
                $repeatMarker = $Repeat
                Mock Invoke-StorageBlobRest {
                    if ($Uri -like '*marker=*' -and -not $repeatMarker) { return $null }
                    '<EnumerationResults><Blobs/><Containers/><NextMarker>next-page</NextMarker></EnumerationResults>'
                }
                {
                    if ($fixtureListing -eq 'blobs') { Get-StorageBlobList -BlobBase 'https://example.blob.core.windows.net' -Container 'exports' -StorageToken 'synthetic-token' }
                    else { Get-StorageContainerList -BlobBase 'https://example.blob.core.windows.net' -StorageToken 'synthetic-token' }
                } | Should -Throw '*listing*'
                Should -Invoke Invoke-StorageBlobRest -Times 2 -Exactly
            }
        }

        It 'Rejects a failed CSV partition instead of returning the readable part' -Tag 'GenericExportStorage' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'test-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = 'export/run/part1.csv'; LastModified = [datetime]'2026-09-15' }
                            [pscustomobject]@{ Name = 'export/run/part2.csv'; LastModified = [datetime]'2026-09-15' }
                        )
                    }
                }
                Mock Get-StorageBlobBytes {
                    if ($Uri -like '*part2.csv') { return $null }
                    [System.Text.Encoding]::UTF8.GetBytes("SubscriptionId,Cost,Currency`n44444444-4444-4444-4444-444444444444,10,USD")
                }
                $export = [pscustomobject]@{ Name = 'export'; Format = 'Csv'; RootFolder = ''; Container = 'exports'; StorageResourceId = '/subscriptions/test/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/test' }
                { Get-CostExportData -Export $export } | Should -Throw '*part2*incomplete*'
            }
        }

        It 'Rejects an export run missing a manifest-declared partition' -Tag 'GenericExportStorage' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'synthetic-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = 'costs/selected/20260901-20260930/run/part_0.csv'; LastModified = [datetime]'2026-10-01' }
                            [pscustomobject]@{ Name = 'costs/selected/20260901-20260930/run/manifest.json'; LastModified = [datetime]'2026-10-01' }
                        )
                    }
                }
                Mock Get-StorageBlobBytes {
                    if ($Uri -like '*manifest.json') {
                        return , ([Text.Encoding]::UTF8.GetBytes('{"blobs":[{"blobName":"costs/selected/20260901-20260930/run/part_0.csv"},{"blobName":"costs/selected/20260901-20260930/run/part_1.csv"}]}'))
                    }
                    , ([Text.Encoding]::UTF8.GetBytes("SubscriptionId,Cost,Currency,Date`n11111111-1111-1111-1111-111111111111,100,USD,2026-09-30"))
                }
                $export = [pscustomobject]@{ Name = 'selected'; Format = 'Csv'; Type = 'ActualCost'; RootFolder = 'costs'; Container = 'exports'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/examplestorage' }

                { Get-CostExportData -Export $export } | Should -Throw '*declares 2 partition*incomplete*'
            }
        }

        It 'Excludes tenant-level export rows with no subscription instead of failing the read' -Tag 'GenericExportStorage' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '11111111-1111-1111-1111-111111111111'
                $exportRows = @(
                    [pscustomobject]@{ SubAccountId = "/subscriptions/$subscriptionId"; BilledCost = 10; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01' }
                    [pscustomobject]@{ SubAccountId = ''; BilledCost = 250; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01' }
                )
                $exportData = [pscustomobject]@{ Rows = $exportRows; ColMap = (Resolve-ExportColumns -Header $exportRows[0].PSObject.Properties.Name); Currency = 'USD'; CostBasis = 'FocusCost'; DataDate = [datetime]'2026-10-01' }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'Example' })

                $result = Select-CostExportData -ExportData $exportData -Subscriptions $subscriptions

                $result.RowCount | Should -Be 1
                $result.UnattributedRowCount | Should -Be 1
            }
        }

        It 'Keeps same-named resources in different subscriptions separate' -Tag 'GenericExportStorage' {
            InModuleScope FinOpsMultitool {
                $first = '11111111-1111-1111-1111-111111111111'
                $second = '22222222-2222-2222-2222-222222222222'
                $exportRows = @(
                    [pscustomobject]@{ SubscriptionId = $first; InstanceName = 'shared-vm'; Cost = 10; Currency = 'USD'; Date = '2026-09-30' }
                    [pscustomobject]@{ SubscriptionId = $second; InstanceName = 'shared-vm'; Cost = 20; Currency = 'USD'; Date = '2026-09-30' }
                )
                $exportData = [pscustomobject]@{ Rows = $exportRows; ColMap = (Resolve-ExportColumns -Header $exportRows[0].PSObject.Properties.Name); Currency = 'USD'; CostBasis = 'ActualCost'; DataDate = [datetime]'2026-10-01' }
                $subscriptions = @(
                    [pscustomobject]@{ Id = $first; Name = 'First' }
                    [pscustomobject]@{ Id = $second; Name = 'Second' }
                )

                $result = @(ConvertTo-ResourceCostsFromExport -ExportData $exportData -Subscriptions $subscriptions)

                $result.Count | Should -Be 2
                @($result | Where-Object { $_.Actual -eq 10 }).Count | Should -Be 1
                @($result | Where-Object { $_.Actual -eq 20 }).Count | Should -Be 1
            }
        }

        It 'Keeps untagged charges and escaped JSON values in the selected tag total' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $rows = @(
                    [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = 'USD'; Tags = '{"CostCenter":"A\"B"}' }
                    [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 20; Currency = 'USD'; Tags = '' }
                )
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = $rows; ColMap = (Resolve-ExportColumns -Header $rows[0].PSObject.Properties.Name) }
                $result = ConvertTo-CostByTagFromExport -ExportData $data -ExistingTags @{ CostCenter = @{} }
                ($result.CostByTag.CostCenter | Measure-Object Cost -Sum).Sum | Should -Be 30
                ($result.CostByTag.CostCenter | Where-Object TagValue -EQ '(untagged)').Cost | Should -Be 20
                ($result.CostByTag.CostCenter | Where-Object TagValue -EQ 'A"B').Cost | Should -Be 10
            }
        }

        It 'Does not present missing date or tag columns as complete empty breakdowns' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @([pscustomobject]@{ SubscriptionId = '44444444-4444-4444-4444-444444444444'; Cost = 10; Currency = 'USD' }) }
                { ConvertTo-CostByTagFromExport -ExportData $data } | Should -Throw '*coverage*'
                { ConvertTo-CostTrendFromExport -ExportData $data } | Should -Throw '*coverage*'
            }
        }
    }

    Context 'Commitment cost basis' {

        # FOCUS records a reservation twice on purpose: once as BilledCost on the
        # Purchase row, and again amortized across the Usage rows it covers, which
        # EC9.1 requires to sum to the same amount. Choosing the cost column per row
        # picked BilledCost on the purchase and EffectiveCost on the usage, so every
        # commitment landed in the total twice.
        It 'Counts a commitment once rather than twice' {
            InModuleScope FinOpsMultitool {
                $sub = '66666666-6666-6666-6666-666666666666'
                $hubData = @(
                    # Reservation purchase: billed in full, zero amortized (EC6).
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 12000; EffectiveCost = 0; BillingCurrency = 'USD'
                    }
                    # Usage the reservation covers: nothing billed, amortized share only.
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 0; EffectiveCost = 9000; BillingCurrency = 'USD'
                    }
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 0; EffectiveCost = 3000; BillingCurrency = 'USD'
                    }
                )

                $map = ConvertTo-CostDataFromHub -HubData $hubData

                # 12000 amortized, not 12000 purchase + 12000 amortized.
                $map[$sub].Actual | Should -Be 12000
            }
        }

        It 'Resolves one cost column for the whole dataset' {
            InModuleScope FinOpsMultitool {
                Resolve-HubCostColumn -Props @('BilledCost', 'EffectiveCost') | Should -Be 'BilledCost'
                Resolve-HubCostColumn -Props @('BilledCost', 'EffectiveCost') -CostBasis 'AmortizedCost' | Should -Be 'EffectiveCost'
                Resolve-HubCostColumn -Props @('CostInBillingCurrency') | Should -Be 'CostInBillingCurrency'
                { Resolve-HubCostColumn -Props @('ResourceId') } | Should -Throw '*cost*'
            }
        }

        It 'Uses billed cost for actual spend even when amortization differs' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 12000; EffectiveCost = 0; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 0; EffectiveCost = 1000; BillingCurrency = 'USD' }
                )

                $result = ConvertTo-CostDataFromHub -HubData $rows

                $result['66666666-6666-6666-6666-666666666666'].Actual | Should -Be 12000
            }
        }

        It 'Rejects an unreadable selected cost without switching bases (<Case>)' -ForEach @(
            @{ Case = 'null'; Amount = $null }
            @{ Case = 'blank'; Amount = '' }
            @{ Case = 'invalid'; Amount = 'invalid' }
            @{ Case = 'NaN'; Amount = 'NaN' }
            @{ Case = 'infinity'; Amount = 'Infinity' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Amount = $Amount } {
                param($Amount)
                $row = [pscustomobject]@{ EffectiveCost = $Amount; BilledCost = 500 }
                { Get-HubCostValue -Row $row -Column 'EffectiveCost' } | Should -Throw '*cost*'
            }
        }

        It 'Rejects a missing selected column on a later row' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 10; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; CostInBillingCurrency = 20; BillingCurrency = 'USD' }
                )
                { ConvertTo-CostDataFromHub -HubData $rows } | Should -Throw '*cost*'
            }
        }

        It 'Preserves a measured zero and negative credit in the selected basis' {
            InModuleScope FinOpsMultitool {
                Get-HubCostValue -Row ([pscustomobject]@{ BilledCost = 0; EffectiveCost = 500 }) -Column 'BilledCost' | Should -Be 0
                Get-HubCostValue -Row ([pscustomobject]@{ BilledCost = -25 }) -Column 'BilledCost' | Should -Be -25
            }
        }

        It 'Keeps billed reporting separate from amortized allocation and unit costs' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '66666666-6666-6666-6666-666666666666'
                $targetResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/test"
                $rows = @([pscustomobject]@{
                        SubAccountId = $subscriptionId; SubAccountName = 'test'; BilledCost = 12000; EffectiveCost = 1000
                        BillingCurrency = 'USD'; ResourceId = $targetResourceId; ResourceType = 'microsoft.cognitiveservices/accounts'
                        Tags = '{"CostCenter":"test"}'; ConsumedQuantity = 0
                        ChargePeriodStart = '2026-08-31T00:00:00Z'
                    })
                Mock Resolve-VmAssociation {
                    $associated = [System.Collections.Generic.HashSet[string]]::new()
                    [void]$associated.Add($targetResourceId)
                    [pscustomobject]@{ Id = $targetResourceId; Name = 'test'; Associated = $associated; SubscriptionId = $subscriptionId }
                }

                @((ConvertTo-ResourceCostsFromHub -HubData $rows))[0].Actual | Should -Be 12000
                (ConvertTo-CostByTagFromHub -HubData $rows).CostByTag.CostCenter[0].Cost | Should -Be 12000
                (Get-AllocationCostMaps -SubscriptionIds @($subscriptionId) -HubData $rows).BySub[$subscriptionId] | Should -Be 1000
                (Get-AllocationCostMaps -SubscriptionIds @($subscriptionId) -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                (Get-VmCostBreakdown -VmName 'test' -HubData $rows).TotalCost | Should -Be 1000
                (Get-VmCostBreakdown -VmName 'test' -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                (ConvertTo-AIHubAggregates -HubData $rows).AICost | Should -Be 1000
                (ConvertTo-AIHubAggregates -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                { Resolve-HubCostColumn -Props @('BilledCost') -CostBasis 'AmortizedCost' } | Should -Throw '*AmortizedCost*EffectiveCost*FOCUS*API*'
                { Resolve-HubCostColumn -Props @('EffectiveCost') -CostBasis 'ActualCost' } | Should -Throw '*ActualCost*'
            }
        }

        It 'Rejects inconsistent currency instead of returning a labeled cost total (<Currency>)' -ForEach @(
            @{ Currency = 'EUR' }
            @{ Currency = '' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 10; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 20; BillingCurrency = $Currency }
                )
                { ConvertTo-CostDataFromHub -HubData $rows } | Should -Throw '*currenc*'
                { ConvertTo-CostByTagFromHub -HubData $rows -ExistingTags @{ CostCenter = @{} } } | Should -Throw '*currenc*'
            }
        }

        It 'Rejects <Currency> Hub allocation currency before returning cost maps' -ForEach @(
            @{ Currency = 'EUR' }
            @{ Currency = '' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '11111111-1111-1111-1111-111111111111'; ResourceId = '/resources/one'; EffectiveCost = 100; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '22222222-2222-2222-2222-222222222222'; ResourceId = '/resources/two'; EffectiveCost = 50; BillingCurrency = $Currency }
                )
                $returned = [Collections.Generic.List[object]]::new()

                { Get-AllocationCostMaps -SubscriptionIds $rows.SubAccountId -HubData $rows | ForEach-Object { $returned.Add($_) } } | Should -Throw '*currenc*'

                $returned.Count | Should -Be 0
            }
        }

        It 'Rejects resource column drift even when the cost column is unchanged' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = 'resource-a' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; x_ResourceId = 'resource-b' }
                )
                { ConvertTo-ResourceCostsFromHub -HubData $rows } | Should -Throw '*schemas differ*'
            }
        }

        It 'Discovers all hub tag keys and keeps case-distinct values' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; Tags = '{"env":"Prod"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; Tags = '{"env":"prod","Project":"test"}' }
                    [pscustomobject]@{ BilledCost = -5; BillingCurrency = 'USD'; Tags = '' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows

                $result.TagsQueried | Should -Contain 'Project'
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 10
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 20
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 25
                ($result.CostByTag.env | Measure-Object Cost -Sum).Sum | Should -Be 25
            }
        }

        It 'Handles case-variant tag keys within the same hub record without double counting' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/one'; Tags = '{"project":"shared","Project":"shared","Environment":"Prod"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/two'; Tags = '{"PROJECT":"shared","Environment":"prod"}' }
                    [pscustomobject]@{ BilledCost = -5; BillingCurrency = 'USD'; ResourceId = ''; Tags = '' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows
                $inventory = ConvertTo-TagInventoryFromHub -HubData $rows

                @($result.TagsQueried | Where-Object { $_ -ieq 'Project' }).Count | Should -Be 1
                ($result.CostByTag.Project | Where-Object TagValue -EQ 'shared').Cost | Should -Be 30
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 25
                ($result.CostByTag.Environment | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 10
                ($result.CostByTag.Environment | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 20
                $inventory.TaggedCount | Should -Be 2
                $inventory.TagNames.Project.TotalResources | Should -Be 2
                @($inventory.TagNames.Environment.Values).Count | Should -Be 2
            }
        }

        It 'Reports conflicting case-variant tag values once instead of choosing one' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/one'; Tags = '{"project":"team-a","Project":"team-b"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/two'; Tags = '"project":"team-a"' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows
                $inventory = ConvertTo-TagInventoryFromHub -HubData $rows

                ($result.CostByTag.Project | Where-Object TagValue -EQ '(conflicting tag values)').Cost | Should -Be 10
                ($result.CostByTag.Project | Where-Object TagValue -EQ 'team-a').Cost | Should -Be 20
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 30
                $inventory.TagNames.Project.TotalResources | Should -Be 2
                ($inventory.TagNames.Project.Values | Where-Object Value -EQ '(conflicting tag values)').ResourceCount | Should -Be 1
            }
        }

        It 'Renders Hub tag values in terminal and HTML using the live-inventory contract' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $hubRows = @(
                    [pscustomobject]@{ ResourceId = '/subscriptions/test/resources/one'; ResourceType = 'fixture'; Tags = '{"Environment":"Prod","CostCenter":"team-a"}' }
                    [pscustomobject]@{ ResourceId = '/subscriptions/test/resources/two'; ResourceType = 'fixture'; Tags = '{"environment":"prod","CostCenter":"team-a"}' }
                )
                $data = ConvertTo-TagInventoryFromHub -HubData $hubRows
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-TagInventory' -and $_.Item2.Extent.Text.Contains('Top values') })
                $branches.Count | Should -Be 2
                $htmlSb = [System.Text.StringBuilder]::new()
                $rows = $null
                $htmlRows = $null
                Mock Write-Host { }

                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                foreach ($projection in @(@{ Rows = $rows }, @{ Rows = $htmlRows })) {
                    ($projection.Rows | Where-Object Tag -EQ 'CostCenter').'Top values' | Should -Be 'team-a (2)'
                    $environment = ($projection.Rows | Where-Object Tag -EQ 'Environment').'Top values'
                    $environment | Should -Match 'Prod \(1\)'
                    $environment | Should -Match 'prod \(1\)'
                    $environment | Should -Not -Match '^\s*\('
                }
                @($data.TagNames.Environment.Values | Where-Object { $_.Value -ceq 'Prod' }).Count | Should -Be 1
                @($data.TagNames.Environment.Values | Where-Object { $_.Value -ceq 'prod' }).Count | Should -Be 1
            }
        }
    }

    Context 'Amortized query currency' {
        It 'Refuses missing or mixed live currencies (<Case>)' -ForEach @(
            @{ Case = 'blank'; Currency = '' }
            @{ Case = 'mixed'; Currency = 'EUR' }
            @{ Case = 'missing column'; Currency = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $targetId = '/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/test/providers/Microsoft.Compute/virtualMachines/test'
                $columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' })
                $rows = @(@(100.0, $targetId, 'USD'), @(100.0, $targetId, $Currency))
                if ($null -eq $Currency) {
                    $columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' })
                    $rows = @(, @(100.0, $targetId))
                }
                $responseContent = @{ properties = @{ columns = $columns; rows = $rows } } | ConvertTo-Json -Depth 10
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 200; Content = $responseContent } }
                Mock Resolve-VmAssociation {
                    $associated = [System.Collections.Generic.HashSet[string]]::new()
                    [void]$associated.Add($targetId)
                    [pscustomobject]@{ Id = $targetId; Name = 'test'; SubscriptionId = '44444444-4444-4444-4444-444444444444'; ResourceGroup = 'test'; Associated = $associated }
                }

                { Get-AllocationCostMaps -SubscriptionIds @('44444444-4444-4444-4444-444444444444') } | Should -Throw '*currency*incomplete*'
                $vm = Get-VmCostBreakdown -VmName 'test'
                $vm.HasData | Should -BeFalse
                $vm.TotalCost | Should -BeNullOrEmpty
                $vm.Note | Should -BeLike '*currency*incomplete*'
            }
        }
    }

    Context 'Hub storage completeness' {
        It 'Labels the actual <Format> reader instead of inferring it from the cost columns' -ForEach @(
            @{ Format = 'CSV' }
            @{ Format = 'Parquet' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ExpectedFormat = $Format } {
                param($ExpectedFormat)
                $useParquet = $ExpectedFormat -eq 'Parquet'
                Mock Write-Host { }
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion') {
                        if ($useParquet) { [pscustomobject]@{ Name = 'part.parquet'; Path = 'Costs/2026/09/part.parquet'; IsDirectory = $false } }
                    }
                    else { [pscustomobject]@{ Name = 'part.csv'; Path = 'export/20260901-20260930/202609180001/run/part.csv'; IsDirectory = $false } }
                }
                Mock Get-AzDataLakeGen2ItemContent { }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; x_SkuTier = 'Premium' } }
                Mock Import-Csv { [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD' } }

                $rows = @(Read-FinOpsHubData -StorageAccountName 'fixture' -ResourceGroupName 'fixture' -Months 1)

                $rows.Count | Should -Be 1
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    "$Object" -match "Total rows from Hub \($ExpectedFormat\): 1"
                }
                $csvReads = if ($useParquet) { 0 } else { 1 }
                Should -Invoke Import-Csv -Times $csvReads -Exactly
            }
        }

        It 'Propagates a Parquet parsing failure instead of returning an empty dataset' {
            $missingFile = Join-Path $TestDrive 'unreadable.parquet'
            { Read-ParquetFile -Path $missingFile } | Should -Throw '*Parquet*incomplete*'
        }

        It 'Only attaches a forecast to current-month hub actuals (<Period>)' -ForEach @(
            @{ Period = 'Current'; ChargeDate = '2026-09-16T00:00:00Z' }
            @{ Period = 'Mixed'; ChargeDate = '2026-09-16T00:00:00Z' }
            @{ Period = 'Stale'; ChargeDate = '2026-08-31T00:00:00Z' }
            @{ Period = 'Unknown'; ChargeDate = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Period = $Period; ChargeDate = $ChargeDate; ModuleRoot = $script:ModuleRoot } {
                param($Period, $ChargeDate, $ModuleRoot)
                $fixtureDate = $ChargeDate
                $mixedPeriods = $Period -eq 'Mixed'
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole') }, $true)) {
                    . ([scriptblock]::Create($definition.Extent.Text))
                }
                Mock Get-Date { [datetime]::new(2026, 9, 17, 12, 0, 0, [DateTimeKind]::Utc) }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Read-FinOpsHubData {
                    [pscustomobject]@{ BilledCost = 310; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444'; ChargePeriodStart = $fixtureDate; Tags = '' }
                    if ($mixedPeriods) {
                        [pscustomobject]@{ BilledCost = 50; BillingCurrency = 'USD'; SubAccountId = '55555555-5555-5555-5555-555555555555'; ChargePeriodStart = '2026-08-31T00:00:00Z'; Tags = '' }
                    }
                }
                Mock ConvertTo-TagInventoryFromHub { [pscustomobject]@{ TagCount = 0; TagCoverage = 0 } }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                Mock Get-CostData { @{ '44444444-4444-4444-4444-444444444444' = @{ Actual = 100; Forecast = 180; ForecastSource = 'Forecast'; Currency = 'USD' } } }
                $modules = @([pscustomobject]@{ Name = 'Costs'; Fn = 'Get-CostData'; Selected = $true })
                $subscriptions = @([pscustomobject]@{ Id = '44444444-4444-4444-4444-444444444444'; Name = 'test' })
                if ($mixedPeriods) { $subscriptions += [pscustomobject]@{ Id = '55555555-5555-5555-5555-555555555555'; Name = 'older' } }

                $result = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource @{ Source = 'Hub'; HubStorage = @{ name = 'test'; resourceGroup = 'test' } }

                $entry = $result['Get-CostData'][$subscriptions[0].Id]
                $entry.Actual | Should -Be 310
                if ($Period -in @('Current', 'Mixed')) {
                    $entry.Forecast | Should -Be 180
                    $entry.ActualPeriod | Should -Match '2026-09'
                    Should -Invoke Get-CostData -Times 1 -Exactly
                    Should -Invoke Get-CostData -Times 1 -Exactly -ParameterFilter {
                        $Subscriptions.Count -eq 1 -and $Subscriptions[0].Id -eq '44444444-4444-4444-4444-444444444444'
                    }
                    if ($mixedPeriods) {
                        $older = $result['Get-CostData']['55555555-5555-5555-5555-555555555555']
                        $older.ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                        $older.Forecast | Should -BeNullOrEmpty
                    }
                }
                else {
                    $entry.Forecast | Should -BeNullOrEmpty
                    $entry.ActualPeriod | Should -Be $(if ($Period -eq 'Stale') { '2026-08-31 to 2026-08-31' } else { 'Unknown' })
                    Should -Invoke Get-CostData -Times 0 -Exactly
                }
            }
        }

        It 'Does not return partial hub data after a <Source> file fails' -ForEach @(
            @{ Source = 'Parquet' }
            @{ Source = 'CSV' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source } {
                param($Source)
                $useCsv = $Source -eq 'CSV'
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion' -and $useCsv) { return @() }
                    if ($FileSystem -eq 'msexports' -and -not $useCsv) { throw 'Unexpected CSV fallback.' }
                    $extension = if ($useCsv) { 'csv' } else { 'parquet' }
                    @(
                        [pscustomobject]@{ Name = "part1.$extension"; Path = "export/20260901-20260930/202609170001/run/part1.$extension"; IsDirectory = $false }
                        [pscustomobject]@{ Name = "part2.$extension"; Path = "export/20260901-20260930/202609170001/run/part2.$extension"; IsDirectory = $false }
                    )
                }
                Mock Get-AzDataLakeGen2ItemContent { if ($Path -like '*part2*') { throw 'Simulated download failure.' } }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }
                Mock Import-Csv { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }

                { Read-FinOpsHubData -StorageAccountName 'test' -ResourceGroupName 'test' -SubscriptionIds @('44444444-4444-4444-4444-444444444444') } |
                Should -Throw '*incomplete*'
            }
        }

        It 'Does not accept missing selected subscriptions as complete hub coverage' {
            InModuleScope FinOpsMultitool {
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem { [pscustomobject]@{ Name = 'one.parquet'; Path = 'one.parquet'; IsDirectory = $false } }
                Mock Get-AzDataLakeGen2ItemContent { }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }

                { Read-FinOpsHubData -StorageAccountName 'test' -ResourceGroupName 'test' -SubscriptionIds @('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555') } |
                Should -Throw '*coverage*'
            }
        }

        It 'Keeps a <Source> hub failure visible to the scan runner without an API fallback' -ForEach @(
            @{ Source = 'Storage' }
            @{ Source = 'Kusto' }
            @{ Source = 'KustoAI' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source; ModuleRoot = $script:ModuleRoot } {
                param($Source, $ModuleRoot)
                $sourceName = $Source
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $runner = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Invoke-SelectedScans' }, $true)
                . ([scriptblock]::Create($runner.Extent.Text))
                $sectionHeader = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-SectionHeader' }, $true)
                . ([scriptblock]::Create($sectionHeader.Extent.Text))
                Mock Resolve-FOHubProvider { @{ Found = ($sourceName -in @('Kusto', 'KustoAI')); Mode = 'Kusto' } }
                Mock Read-FinOpsHubData { throw 'Hub coverage incomplete.' }
                Mock Get-FOHubCostSummary { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-FOHubResourceCosts { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-FOHubCostByTag { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-CostData { @{ unexpected = @{ Actual = 100; Currency = 'USD' } } }
                Mock Get-AIWorkloadMetrics { [pscustomobject]@{ HasData = $true; TotalAICost = 100; Source = 'API' } }
                $scanName = if ($Source -eq 'KustoAI') { 'Get-AIWorkloadMetrics' } else { 'Get-CostData' }
                $modules = @([pscustomobject]@{ Name = 'Costs'; Fn = $scanName; Selected = $true })
                $subscriptions = @([pscustomobject]@{ Id = '44444444-4444-4444-4444-444444444444'; Name = 'test' })
                $dataSource = @{ Source = 'Hub'; HubStorage = @{ name = 'test'; resourceGroup = 'test' } }

                $result = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $dataSource

                $expectedError = if ($Source -eq 'KustoAI') { '*unavailable*selected Kusto hub source*' } else { '*coverage incomplete*' }
                $result["_error_$scanName"] | Should -BeLike $expectedError
                @($result[$scanName]).Count | Should -Be 0
                Should -Invoke Get-CostData -Times 0 -Exactly
                Should -Invoke Get-AIWorkloadMetrics -Times 0 -Exactly
            }
        }

        It 'Keeps a measured zero AI hub result on the selected source' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    @{ Data = @([pscustomobject]@{ type = 'microsoft.cognitiveservices/accounts'; lkind = 'OpenAI'; id = '/subscriptions/test/providers/Microsoft.CognitiveServices/accounts/ai'; name = 'ai' }) }
                }
                Mock Invoke-AzRestMethodWithRetry { throw 'A hub result must not call the live cost API.' }
                Mock Get-PlainAccessToken { throw 'A hub result must not call live metrics.' }
                $hubRows = @([pscustomobject]@{ EffectiveCost = 0; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/providers/Microsoft.CognitiveServices/accounts/ai'; ResourceType = 'microsoft.cognitiveservices/accounts'; ChargePeriodStart = '2026-08-31'; ConsumedQuantity = 0 })

                $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -HubData $hubRows

                $result.Source | Should -Be 'FinOpsHub'
                $result.TotalAICost | Should -Be 0
                $result.Period | Should -Be '2026-08-31 to 2026-08-31'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
                Should -Invoke Get-PlainAccessToken -Times 0 -Exactly
            }
        }
    }

    Context 'Commitment utilization' {

        # Get-CommitmentUtilization seeds both averages to 0 and only fills the ones
        # it found. Treating that 0 as a measurement halves the score for anyone who
        # owns reservations but no savings plans, and reports 100% waste when the
        # utilization read was denied.
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

    Context 'Cost trend guidance' {
        It 'Uses comparable completed months for <Case>' -ForEach @(
            @{ Case = 'the reported September data'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-05-01', '2026-07-01', '2026-08-01', '2026-09-01'); Costs = @(1359.56, 1205.47, 751.48, 441.78); Currencies = @('USD', 'USD', 'USD', 'USD'); Expected = 'decreased 37.7% from Jul 2026 to Aug 2026' }
            @{ Case = 'a year boundary'; Now = '2026-02-18T12:00:00Z'; Dates = @('2025-12-01', '2026-01-01', '2026-02-01'); Costs = @(100, 110, 10); Currencies = @('EUR', 'EUR', 'EUR'); Expected = 'increased 10% from Dec 2025 to Jan 2026' }
            @{ Case = 'only one completed month'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-08-01', '2026-09-01'); Costs = @(100, 10); Currencies = @('USD', 'USD'); Expected = 'needs two completed months' }
            @{ Case = 'a missing calendar month'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-05-01', '2026-08-01'); Costs = @(100, 10); Currencies = @('USD', 'USD'); Expected = 'two consecutive completed months' }
            @{ Case = 'different billing currencies'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-07-01', '2026-08-01'); Costs = @(100, 10); Currencies = @('EUR', 'USD'); Expected = 'unknown or different currencies' }
            @{ Case = 'a zero baseline'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-07-01', '2026-08-01'); Costs = @(0, 10); Currencies = @('USD', 'USD'); Expected = 'no positive net cost' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot; Now = $Now; Dates = $Dates; Costs = $Costs; Currencies = $Currencies; Expected = $Expected } {
                param($ModuleRoot, $Now, $Dates, $Costs, $Currencies, $Expected)
                $fixtureNow = [datetime]::Parse($Now, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                Mock Get-Date { $fixtureNow }
                $months = @(for ($index = 0; $index -lt $Dates.Count; $index++) {
                        $monthDate = [datetime]::ParseExact($Dates[$index], 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
                        [pscustomobject]@{ Month = $monthDate.ToString('MMM yyyy'); MonthDate = $monthDate; Cost = $Costs[$index]; Currency = $Currencies[$index] }
                    })
                $data = [pscustomobject]@{ Months = $months }
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branch = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-CostTrend' -and $_.Item2.Extent.Text.Contains('$guidanceItems') })
                $branch.Count | Should -Be 1
                $guidanceItems = @()
                $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"

                . ([scriptblock]::Create("param(`$data)`n$body")) $data

                ($guidanceItems.Message -join ' ') | Should -Match ([regex]::Escape($Expected))
                ($guidanceItems.Message -join ' ') | Should -Not -Match '67.5%|Optimization efforts are working|Good cost discipline'
                $guidanceItems.Severity | Should -Not -Contain 'Green'
            }
        }
    }

    Context 'Hourly cost reporting' {
        It 'Retains a measured zero for the <KpiId> unit KPI' -ForEach @(
            @{ KpiId = 'cost-per-gb-stored' }
            @{ KpiId = 'hourly-cost-per-cpu-core' }
            @{ KpiId = 'effective-avg-compute-cost-per-core' }
        ) {
            $data = [pscustomobject]@{
                Currency = 'EUR'; CostPerVCpu = 0.0; CostPerGb = 0.0
                CostPeriodStartUtc = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                CostPeriodEndUtc = [datetime]::new(2026, 9, 24, 12, 0, 0, [DateTimeKind]::Utc)
            }

            $result = Get-KpiComputedValue -KpiId $KpiId -Data $data

            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be 0
            $result.Display | Should -Match '^EUR 0 per '
        }

        It 'Keeps capacity but suppresses incompatible <CurrencyCase> unit costs through <CostPath>' -ForEach @(
            @{ CostPath = 'management group'; CurrencyCase = 'mixed'; SecondCurrency = 'EUR' }
            @{ CostPath = 'per subscription'; CurrencyCase = 'mixed'; SecondCurrency = 'EUR' }
            @{ CostPath = 'management group'; CurrencyCase = 'missing'; SecondCurrency = $null }
            @{ CostPath = 'per subscription'; CurrencyCase = 'missing'; SecondCurrency = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ CostPath = $CostPath; SecondCurrency = $SecondCurrency } {
                param($CostPath, $SecondCurrency)
                $fixtureCostPath = $CostPath
                $fixtureCurrency = $SecondCurrency
                Mock Write-Host { }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'virtualmachines') {
                        @{ Data = @([pscustomobject]@{ cnt = 4; vmSize = 'Standard_D2s_v5'; loc = 'eastus'; subId = '11111111-1111-1111-1111-111111111111' }) }
                    }
                    else { @{ Data = @([pscustomobject]@{ totalGb = 0 }) } }
                }
                Mock Get-VmSizeCapability { @{ VCpu = 2; MemGb = 8 } }
                Mock Get-StorageAccountUsedGb { 0.9 }
                Mock Resolve-CostMgId { if ($fixtureCostPath -eq 'management group') { 'fixture' } else { $null } }
                Mock Invoke-AzRestMethodWithRetry {
                    $rows = @()
                    if ($Path -like '*/managementGroups/*' -or $Path -like '*/11111111-1111-1111-1111-111111111111/*') { $rows += , @(100, 'Virtual Machines', 'USD') }
                    if ($Path -like '*/managementGroups/*' -or $Path -like '*/22222222-2222-2222-2222-222222222222/*') { $rows += , @(50, 'Storage', $fixtureCurrency) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'MeterCategory' }, @{ name = 'Currency' }); rows = $rows } } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $result.VmCount | Should -Be 4
                $result.TotalVCpu | Should -Be 8
                $result.TotalMemoryGb | Should -Be 32
                $result.TotalStorageGb | Should -Be 0.9
                $result.HasData | Should -BeTrue
                foreach ($field in @('ComputeCost', 'StorageCost', 'CostPerVCpu', 'CostPerGbRam', 'CostPerVm', 'CostPerGb', 'ComputeSharePct', 'StorageSharePct')) {
                    $result.$field | Should -BeNullOrEmpty -Because "$field requires comparable currencies"
                }
                $result.CostIssue | Should -Match 'currenc'
                foreach ($kpiId in @('cost-per-gb-stored', 'hourly-cost-per-cpu-core', 'effective-avg-compute-cost-per-core')) {
                    $value = Get-KpiComputedValue -KpiId $kpiId -Data $result
                    $value.Value | Should -BeNullOrEmpty
                    $value.Display | Should -Match 'Unavailable'
                }
            }
        }

        It 'Keeps small unit costs and hourly rates above zero' {
            InModuleScope FinOpsMultitool {
                Mock Write-Host { }
                Mock Get-Date { [datetime]::new(2026, 9, 17, 0, 0, 0, [DateTimeKind]::Utc) }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'virtualmachines') {
                        @{ Data = @([pscustomobject]@{ cnt = 4; vmSize = 'Standard_D2s_v5'; loc = 'eastus'; subId = '11111111-1111-1111-1111-111111111111' }) }
                    }
                    else { @{ Data = @([pscustomobject]@{ totalGb = 0 }) } }
                }
                Mock Get-VmSizeCapability { @{ VCpu = 2; MemGb = 8 } }
                Mock Get-StorageAccountUsedGb { 0.9 }
                Mock Resolve-CostMgId { $null }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"columns":[{"name":"Cost"},{"name":"MeterCategory"},{"name":"Currency"}],"rows":[[0.12,"Virtual Machines","USD"],[9.08,"Storage","USD"]]}}' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                $hourly = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $result

                $result.CostPerVCpu | Should -Be 0.015
                $result.CostPerGbRam | Should -Be 0.00375
                $result.CostPerVm | Should -Be 0.03
                (Format-FinOpsUnitRate -Value $result.CostPerGbRam -Currency $result.Currency) | Should -Be 'USD 0.00375'
                $hourly.Value | Should -Be 0.0000390625
                $hourly.Display | Should -Be 'USD 0.00003906 per vCPU / hour'
                (Format-FinOpsUnitRate -Value 0.000000000001 -Currency 'USD') | Should -Be 'USD 1E-12'
                (Format-FinOpsUnitRate -Value 0 -Currency 'USD') | Should -Be 'USD 0'
            }
        }

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
                    CostPerVCpu        = 384.0
                    Currency           = 'USD'
                    CostPeriodStartUtc = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                    CostPeriodEndUtc   = [datetime]::new(2026, 9, 17, 0, 0, 0, [DateTimeKind]::Utc)
                }

                $result = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $data

                $result.Value | Should -Be 1.0
                Should -Invoke Get-Date -Times 0 -Exactly
            }
        }
    }

    Context 'Budget KPI completeness' {
        It 'Does not label an unavailable budget KPI as computed' {
            InModuleScope FinOpsMultitool {
                Mock Get-KpiCatalog {
                    @{ kpis = @([pscustomobject]@{ id = 'variance-budget-vs-actual'; sourceTool = 'scan_budget_status'; compute = $true }) }
                }
                $result = Add-KpiInsights -Result @{ tool = 'scan_budget_status'; data = @{ CoverageIncomplete = $true; Budgets = @() } }

                $result.kpiInsights[0].status | Should -Be 'unavailable'
                $result.kpiInsights[0].numericValue | Should -BeNullOrEmpty
                $result.kpiInsights[0].yourValue | Should -BeLike '*Unavailable*'
            }
        }

        It 'Leaves combined KPIs unscored for <Case>' -ForEach @(
            @{ Case = 'unknown spend'; Change = 'Unknown' }
            @{ Case = 'mixed currencies'; Change = 'Currency' }
            @{ Case = 'different periods'; Change = 'Period' }
            @{ Case = 'overlapping scopes'; Change = 'Scope' }
            @{ Case = 'incomplete inventory'; Change = 'Coverage' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Change = $Change } {
                param($Change)
                $first = [pscustomobject]@{ Amount = 1000; ActualSpend = 500; PctUsed = 50; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'one'; SpendSource = 'Budget' }
                $second = [pscustomobject]@{ Amount = 9000; ActualSpend = 4500; PctUsed = 50; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'two'; SpendSource = 'Budget' }
                $first | Add-Member -NotePropertyName TimePeriod -NotePropertyValue @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) }
                $second | Add-Member -NotePropertyName TimePeriod -NotePropertyValue @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) }
                switch ($Change) {
                    'Unknown' { $second.ActualSpend = $null; $second.PctUsed = $null; $second.SpendSource = 'Unavailable' }
                    'Currency' { $second.Currency = 'USD' }
                    'Period' { $second.TimeGrain = 'Annually' }
                    'Scope' { $second.SubscriptionId = 'one' }
                }
                $data = [pscustomobject]@{ Budgets = @($first, $second); CoverageIncomplete = ($Change -eq 'Coverage') }

                $variance = Get-KpiComputedValue -KpiId 'variance-budget-vs-actual' -Data $data
                $burn = Get-KpiComputedValue -KpiId 'budget-burn-rate' -Data $data

                $variance.Value | Should -BeNullOrEmpty
                $burn.Value | Should -BeNullOrEmpty
                $variance.Display | Should -Match 'Unavailable'
            }
        }

        It 'Reports comparable known budgets using their currency' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ Budgets = @(
                        [pscustomobject]@{ Amount = 1000; ActualSpend = 500; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'one'; TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) } }
                        [pscustomobject]@{ Amount = 1000; ActualSpend = 1500; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'two'; TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) } }
                    )
                }
                $variance = Get-KpiComputedValue -KpiId 'variance-budget-vs-actual' -Data $data
                $burn = Get-KpiComputedValue -KpiId 'budget-burn-rate' -Data $data

                $variance.Value | Should -Be 0
                $variance.Display | Should -Match 'EUR'
                $variance.Display | Should -Not -Match 'USD'
                $burn.Value | Should -Be 100
            }
        }
    }

    Context 'Observed-period reporting' {
        It 'Uses the AI result period in terminal, HTML, guidance, and KPI text' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($formatter in $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Write-ColorizedLine', 'Format-ReportMetric') }, $true)) {
                    . ([scriptblock]::Create($formatter.Extent.Text))
                }
                $switches = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-AIWorkloadMetrics' -and $_.Item2.Extent.Text.Contains('$data.HasData') })
                $branches.Count | Should -Be 3
                $captured = [System.Collections.Generic.List[string]]::new()
                Mock Write-ColorizedLine { [void]$captured.Add($Text) }
                $data = [pscustomobject]@{
                    HasData = $true; Period = '2026-08-01 to 2026-08-31'; Currency = 'EUR'; TotalTokens = 1000; TotalAICost = 25; CostPer1KTokens = 25
                    TotalPromptTokens = 800; TotalGeneratedTokens = 200; TotalRequests = 0; CostPerRequest = $null
                    AIFootprint = @{ OpenAIAccounts = 1; AIServices = 0; MLWorkspaces = 0; SearchServices = 0; GpuVmCount = 0 }
                }
                $htmlSb = [System.Text.StringBuilder]::new()
                $guidanceItems = @()
                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                ($captured -join ' ') | Should -Match '2026-08-01 to 2026-08-31'
                ($captured -join ' ') | Should -Not -Match 'MTD'
                $htmlSb.ToString() | Should -Match '2026-08-01 to 2026-08-31'
                $htmlSb.ToString() | Should -Not -Match 'MTD'
                ($guidanceItems.Message -join ' ') | Should -Match '2026-08-01 to 2026-08-31'
                $kpi = Get-KpiComputedValue -KpiId 'token-consumption-metrics' -Data $data
                $kpi.Display | Should -Match '2026-08-01 to 2026-08-31'
                $kpi.Display | Should -Not -Match 'MTD'
            }
        }
    }

    Context 'Budget reporting' {

        It 'Does not call budgets healthy when forecasts are unavailable' {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
            $switches = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
            $branch = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-BudgetStatus' -and $_.Item2.Extent.Text.Contains('$bCoverage') })
            $branch.Count | Should -Be 1
            $data = [pscustomobject]@{
                AtRiskCount = 0; OverBudgetCount = 0; BudgetCoverage = 100; CoverageIncomplete = $false
                Budgets = @([pscustomobject]@{ Amount = 1000; ActualSpend = 500; Forecast = $null; Risk = 'Forecast unavailable' })
            }
            $guidanceItems = @()
            $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"

            . ([scriptblock]::Create("param(`$data)`n$body")) $data

            $guidanceItems.Count | Should -BeGreaterThan 0
            @($guidanceItems | Where-Object Severity -EQ 'Green').Count | Should -Be 0
            $guidanceItems[0].Message | Should -Match 'unavailable'
        }

        It 'Displays unknown amounts explicitly while preserving known currency and zero' {
            InModuleScope FinOpsMultitool {
                Format-BudgetAmount -Value $null -Currency 'USD' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 500 -Currency '' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 'NaN' -Currency 'USD' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 0 -Currency 'EUR' | Should -Match '^EUR 0[.,]00$'
                Format-BudgetAmount -Value 500 -Currency 'EUR' | Should -Match '^EUR '
            }
        }

        It 'Keeps an unavailable forecast separate from known current spend' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"monthly","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","currentSpend":{"amount":500,"unit":"EUR"}}}]}' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888'; Name = 'test' })

                $budget = (Get-BudgetStatus -Subscriptions $subscriptions).Budgets[0]

                $budget.ActualSpend | Should -Be 500
                $budget.PctUsed | Should -Be 50
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.PctForecast | Should -BeNullOrEmpty
                $budget.ForecastSource | Should -Be 'Unavailable'
                $budget.Risk | Should -Not -Be 'On Track'
                $budget.Currency | Should -Be 'EUR'
            }
        }

        It 'Explains missing budget evidence in the same order as risk classification' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"monthly","properties":{"amount":100,"timeGrain":"Monthly","category":"Cost","forecastSpend":{"amount":95,"unit":"USD"}}}]}' }
                }

                $result = Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888'; Name = 'Fixture' })
                $context = Get-FinOpsScanContext -FunctionName 'Get-BudgetStatus' -Data $result

                $result.Budgets[0].Risk | Should -Be 'Unknown'
                $result.Budgets[0].PctForecast | Should -Be 95
                $rules = $context.Details -join ' '
                $rules | Should -Match 'invalid budget amount.*Unknown.*actual >100%.*forecast >100%.*missing current spend.*Unknown.*forecast >90%'
                $rules | Should -Match 'unavailable forecast.*Forecast unavailable'
            }
        }

        It 'Does not turn an invalid budget denominator into an on-track budget (<Case>)' -ForEach @(
            @{ Case = 'missing'; Amount = $null }
            @{ Case = 'zero'; Amount = 0 }
            @{ Case = 'negative'; Amount = -1 }
            @{ Case = 'NaN'; Amount = 'NaN' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Amount = $Amount } {
                param($Amount)
                $properties = @{ amount = $Amount; timeGrain = 'Monthly'; category = 'Cost'; currentSpend = @{ amount = 500; unit = 'USD' } }
                $content = @{ value = @(@{ name = 'test'; properties = $properties }) } | ConvertTo-Json -Depth 8
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 200; Content = $content } }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.Amount | Should -BeNullOrEmpty
                $budget.PctUsed | Should -BeNullOrEmpty
                $budget.Risk | Should -Be 'Unknown'
                $budget.Note | Should -BeLike '*amount*'
            }
        }

        It 'Does not compare a forecast denominated in another unit to the budget' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"monthly","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","currentSpend":{"amount":500,"unit":"USD"},"forecastSpend":{"amount":1500,"unit":"EUR"}}}]}' }
                }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.Currency | Should -Be 'USD'
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.Risk | Should -Not -Be 'Forecast Over'
                $budget.Note | Should -BeLike '*unit*'
            }
        }

        It 'Preserves the budget filter and leaves unknown spend null' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"filtered","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","filter":{"tags":{"name":"CostCenter","operator":"In","values":["team"]}},"timePeriod":{"startDate":"2026-01-01T00:00:00Z","endDate":"2026-12-31T00:00:00Z"}}}]}' }
                }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.ActualSpend | Should -BeNullOrEmpty
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.Filter.tags.name | Should -Be 'CostCenter'
                $budget.TimePeriod.startDate | Should -Not -BeNullOrEmpty
                $budget.Currency | Should -BeNullOrEmpty
            }
        }

        # A budget whose spend could not be read must not average into burn-rate KPIs
        # as though it were untouched.
        It 'Leaves percentages null when spend is unknown' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'quarterly-filtered'
                    properties = [pscustomobject]@{
                        amount = 5000; timeGrain = 'Quarterly'; category = 'Cost'
                        filter = [pscustomobject]@{ tags = @{} }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($budget) } | ConvertTo-Json -Depth 10) }
                }

                $subs = @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888'; Name = 'test' })
                $costData = @{ '88888888-8888-8888-8888-888888888888' = @{ Actual = 900; Forecast = 1000; Currency = 'USD' } }

                $b = @((Get-BudgetStatus -Subscriptions $subs -CostData $costData).Budgets)[0]
                $b.SpendSource | Should -Be 'Unavailable'
                $b.Risk | Should -Be 'Unknown'
                $b.PctUsed | Should -BeNullOrEmpty
            }
        }

        # currentSpend carries its own unit; the subscription's currency may differ.
        It 'Reports the currency that belongs to the budget amount' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'eur-budget'
                    properties = [pscustomobject]@{
                        amount = 1000; timeGrain = 'Monthly'; category = 'Cost'
                        currentSpend = [pscustomobject]@{ amount = 500; unit = 'EUR' }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($budget) } | ConvertTo-Json -Depth 10) }
                }

                $subs = @([pscustomobject]@{ Id = '99999999-9999-9999-9999-999999999999'; Name = 'test' })
                $b = @((Get-BudgetStatus -Subscriptions $subs -CostData @{}).Budgets)[0]
                $b.Currency | Should -Be 'EUR'
            }
        }
    }
}
