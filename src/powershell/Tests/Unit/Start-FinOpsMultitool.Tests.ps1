# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Start-FinOpsMultitool' {

        Context 'Command availability' {
            It 'Should be exported as a public command' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit' -ErrorAction SilentlyContinue
                $cmd | Should -Not -BeNullOrEmpty
            }

            It 'Should have CmdletBinding attribute' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit'
                $cmd.CmdletBinding | Should -BeTrue
            }
        }

        Context 'File dependencies' {
            It 'Should have the Multitool TUI launcher' {
                $tuiPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
                Test-Path -Path $tuiPath | Should -BeTrue
            }

            It 'Should have the Multitool module loader' {
                $psm1Path = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
                Test-Path -Path $psm1Path | Should -BeTrue
            }

            It 'Should have all scanner module files' {
                $modulesPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/modules'
                $modules = Get-ChildItem -Path $modulesPath -Filter '*.ps1'
                # Exact count so a deleted scanner fails the build instead of
                # silently passing a loose lower bound.
                $modules.Count | Should -Be 30
            }

            It 'Should dot-source every scanner module file from the loader' {
                $psm1Path = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
                $modulesPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/modules'
                $loader = Get-Content -Path $psm1Path -Raw
                foreach ($m in (Get-ChildItem -Path $modulesPath -Filter '*.ps1')) {
                    $loader | Should -Match ([regex]::Escape($m.Name))
                }
            }
        }

        Context 'Behavior' {
            It 'Should write an error when the TUI launcher is missing' {
                Mock Test-Path { $false }
                { Start-FinOpsMultitool -ErrorAction Stop } | Should -Throw '*installation may be incomplete*'
            }

            It 'Should not attempt to launch the TUI when the launcher is missing' {
                Mock Test-Path { $false }
                # Returns instead of dot-sourcing; a throw here would be a
                # CommandNotFoundException for the never-loaded TUI function.
                Start-FinOpsMultitool -ErrorAction SilentlyContinue
                Should -Invoke Test-Path -Times 1 -Exactly
            }
        }

        Context 'Successful public launch' {
            BeforeEach {
                $fixtureRoot = Join-Path $TestDrive 'launcher'
                [void](New-Item -ItemType Directory -Path $fixtureRoot -Force)
                $fixtureLauncher = Join-Path $fixtureRoot 'Invoke-FinOpsMultitool.ps1'
                @'
function Invoke-FinOpsMultitool {
    [CmdletBinding()]
    param(
        [string]$SubscriptionId,
        [string]$OutputPath,
        [string[]]$Scans,
        [string]$DataSource,
        [switch]$NonInteractive
    )
    [pscustomobject]@{
        SubscriptionId = $SubscriptionId
        OutputPath = $OutputPath
        Scans = $Scans
        DataSource = $DataSource
        NonInteractive = $NonInteractive.IsPresent
        BoundParameters = @($PSBoundParameters.Keys)
    }
}
'@ | Set-Content -LiteralPath $fixtureLauncher -Encoding utf8
                Mock Join-Path { [System.IO.Path]::Combine([string]$Path, [string]$ChildPath) }
                Mock Join-Path { $fixtureRoot } -ParameterFilter { $ChildPath -eq '../Private/FinOpsMultitool' }
            }

            It 'Forwards the complete public call to the launcher for <Source>' -ForEach @(
                @{ Source = 'API' }
                @{ Source = 'Hub' }
                @{ Source = 'GraphOnly' }
            ) {
                $outputDirectory = Join-Path $TestDrive 'reports with spaces'
                $scans = @('Get-CostData', 'Get-ResourceCosts')

                $result = Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -OutputPath $outputDirectory -Scans $scans -DataSource $Source -NonInteractive

                $result.SubscriptionId | Should -Be '11111111-1111-1111-1111-111111111111'
                $result.OutputPath | Should -Be $outputDirectory
                $result.Scans | Should -Be $scans
                $result.DataSource | Should -Be $Source
                $result.NonInteractive | Should -BeTrue
                $result.BoundParameters.Count | Should -Be 5
            }

            It 'Leaves omitted choices to the launcher defaults' {
                $result = Start-FinOpsMultitool

                $result.BoundParameters.Count | Should -Be 0
                $result.SubscriptionId | Should -BeNullOrEmpty
                $result.Scans | Should -BeNullOrEmpty
                $result.NonInteractive | Should -BeFalse
            }

            It 'Preserves an explicitly disabled NonInteractive switch' {
                $result = Start-FinOpsMultitool -NonInteractive:$false

                $result.NonInteractive | Should -BeFalse
                $result.BoundParameters | Should -Contain 'NonInteractive'
            }
        }

        Context 'Public source smoke tests' {
            BeforeAll {
                $script:RealMultitoolRoot = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool'
                Import-Module (Join-Path $script:RealMultitoolRoot 'FinOpsMultitool.psm1') -Force -Global
            }

            BeforeEach {
                $script:PreviousHubUri = $env:FINOPS_HUB_KUSTO_URI
                $script:PreviousHubDatabase = $env:FINOPS_HUB_KUSTO_DB
                $script:PreviousFinOpsResults = Get-Variable -Name FinOpsResults -Scope Global -ErrorAction SilentlyContinue
                Mock Import-Module { }
                Mock Get-Module { [pscustomobject]@{ Name = $Name } }
                Mock Clear-Host { }
                Mock Write-Host { }
                Mock Read-Host { throw 'Noninteractive launch must not prompt.' }
                Mock Connect-AzAccount { throw 'An existing test context must not trigger sign-in.' }
                Mock Get-AzTenant { throw 'Explicit subscription scope must not enumerate tenants.' }
                Mock Get-AzContext {
                    [pscustomobject]@{ Account = @{ Id = 'test@example.test' }; Tenant = @{ Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } }
                }
                Mock Get-AzSubscription {
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Test subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' }
                }
                Mock Set-AzContext { }
                Mock Search-AzGraph { @() }
                Mock Resolve-CostMgId -ModuleName FinOpsMultitool { $null }
                Mock Get-PlainAccessToken -ModuleName FinOpsMultitool { 'test-token' }
                Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Unexpected external HTTP request.' }
                Mock Invoke-WebRequest -ModuleName FinOpsMultitool { throw 'Unexpected external HTTP request.' }
                Mock Read-FinOpsHubData { throw 'Kusto smoke tests must not fall back to storage.' }
                Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                    if ($Path -notlike '/subscriptions/11111111-1111-1111-1111-111111111111/*') { throw 'Unexpected query scope.' }
                    $amount = if ($Path -like '*forecast*') { 150.0 } else { 100.0 }
                    $content = @{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @($amount, 'USD')) } } | ConvertTo-Json -Depth 8
                    [pscustomobject]@{ StatusCode = 200; Content = $content }
                }
                Mock Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool {
                    $validation = [pscustomobject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 1; _MissingSubscriptions = 0 }
                    $rows = if ($Query.Contains('ResourcePath = ResourceId')) {
                        @([pscustomobject]@{ Actual = 100.0; Currency = 'USD'; Subscription = 'Test subscription'; ResourcePath = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test/providers/Microsoft.Compute/disks/test'; ResourceType = 'microsoft.compute/disks'; ResourceGroup = 'test' })
                    }
                    elseif ($Query.Contains("TagKey = '*TOTAL*'")) {
                        @([pscustomobject]@{ Cost = 100.0; Currency = 'USD'; TagKey = '*TOTAL*'; TagValue = '*TOTAL*' })
                    }
                    else {
                        @([pscustomobject]@{ _sub = '11111111-1111-1111-1111-111111111111'; Name = 'Test subscription'; Actual = 100.0; Currency = 'USD'; ActualPeriodStart = '2026-09-01'; ActualPeriodEnd = '2026-09-16' })
                    }
                    @{ Ok = $true; Rows = @($validation) + $rows; Error = $null }
                }
            }

            AfterEach {
                $env:FINOPS_HUB_KUSTO_URI = $script:PreviousHubUri
                $env:FINOPS_HUB_KUSTO_DB = $script:PreviousHubDatabase
                if ($script:PreviousFinOpsResults) {
                    Set-Variable -Name FinOpsResults -Scope Global -Value $script:PreviousFinOpsResults.Value
                }
                else { Remove-Variable -Name FinOpsResults -Scope Global -ErrorAction SilentlyContinue }
            }

            AfterAll {
                Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
            }

            It 'Runs the real public launcher and exports reports for <Mode>' -ForEach @(
                @{ Mode = 'API'; Source = 'API'; HubUri = $null; NeedsToken = $false }
                @{ Mode = 'ApiWithKustoOverride'; Source = 'API'; HubUri = 'http://localhost:8082'; NeedsToken = $false }
                @{ Mode = 'OnlineHub'; Source = 'Hub'; HubUri = 'https://test.eastus.kusto.windows.net'; NeedsToken = $true }
                @{ Mode = 'LocalHub'; Source = 'Hub'; HubUri = 'http://localhost:8082'; NeedsToken = $false }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $HubUri
                $env:FINOPS_HUB_KUSTO_DB = 'Hub'
                $reportPath = Join-Path $TestDrive $Mode

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource $Source -OutputPath $reportPath -NonInteractive -ErrorAction Stop

                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result.ContainsKey('_error_Get-CostData') | Should -BeFalse
                $result['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                Test-Path (Join-Path $reportPath 'FinOpsReport.html') | Should -BeTrue
                Get-Content (Join-Path $reportPath 'FinOpsReport.html') -Raw | Should -Match 'Scans Run</div><div class="value">1</div>'
                Get-Content (Join-Path $reportPath 'ScanSummary.txt') -Raw | Should -Not -Match 'ERROR:'
                $csvFiles = @(Get-ChildItem -LiteralPath $reportPath -Filter '*.csv')
                $csvFiles.Count | Should -Be 1
                $rows = @(Import-Csv -LiteralPath $csvFiles[0].FullName)
                $rows.Count | Should -Be 1
                $rows[0].SubscriptionId | Should -Be '11111111-1111-1111-1111-111111111111'
                $rows[0].Actual | Should -Be '100'
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -match 'RUNNING 1 SCANS' }
                Should -Invoke Read-Host -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Get-AzTenant -Times 0 -Exactly
                Should -Invoke Get-AzSubscription -Times 1 -Exactly -ParameterFilter {
                    $SubscriptionId -eq '11111111-1111-1111-1111-111111111111' -and $TenantId -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                }
                if ($Source -eq 'API') {
                    $rows[0].Forecast | Should -Be '150'
                    Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 2 -Exactly
                    Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                }
                else {
                    $rows[0].ForecastSource | Should -Be 'Unavailable'
                    Get-Content (Join-Path $reportPath 'FinOpsReport.html') -Raw | Should -Match ([regex]::Escape("Cost data: FinOps Hub ($HubUri, Hub)"))
                    Should -Invoke Search-AzGraph -Times 0 -Exactly
                    Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 3 -Exactly -ParameterFilter {
                        $ClusterUri -eq $HubUri -and $Database -eq 'Hub' -and $Query.Contains('11111111-1111-1111-1111-111111111111')
                    }
                    Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                }
                $tokenCalls = if ($NeedsToken) { 3 } else { 0 }
                Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times $tokenCalls -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Preserves the interactive Kusto choice without rediscovering the provider' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $args[0].Name -in @('Select-DataSource', 'Read-FinOpsAnswer', 'Invoke-SelectedScans', 'Write-SectionHeader')
                }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { '1' }
                Mock Search-AzGraph { [pscustomobject]@{ name = 'test-hub-storage'; resourceGroup = 'test-hub' } }
                Mock Resolve-FOHubProvider {
                    @{ Found = $true; Mode = 'Kusto'; ClusterUri = 'https://test.eastus.kusto.windows.net'; Database = 'Hub'; UseAuth = $true }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Test subscription' })

                $choice = Select-DataSource -Subscriptions $subscriptions
                $choice.HubProvider.ClusterUri | Should -Be 'https://test.eastus.kusto.windows.net'
                $result = Invoke-SelectedScans -Modules @(@{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true }) -Subscriptions $subscriptions -DataSource $choice

                $result['Get-CostData'][$subscriptions[0].Id].Actual | Should -Be 100
                $choice.HubProvider.Database | Should -Be 'Hub'
                Should -Invoke Resolve-FOHubProvider -Times 1 -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Does not query Hub costs for a Graph-only run with a Kusto override' {
                $env:FINOPS_HUB_KUSTO_URI = 'http://localhost:8082'
                Mock Get-TagInventory { [pscustomobject]@{ TagNames = @{}; TotalResources = 0; TaggedCount = 0; UntaggedCount = 0; TagCoverage = 0 } }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-TagInventory -DataSource GraphOnly -NonInteractive -ErrorAction Stop

                Should -Invoke Get-TagInventory -Times 1 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Rejects an unavailable explicit Hub rather than silently selecting API' {
                $env:FINOPS_HUB_KUSTO_URI = $null

                { Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource Hub -NonInteractive -ErrorAction Stop } |
                    Should -Throw '*No FinOps hub*'

                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Keeps selected-source failure details for <Mode>' -ForEach @(
                @{ Mode = 'ApiDenied'; Source = 'API'; HubUri = $null; ExpectedRole = 'Cost Management Reader' }
                @{ Mode = 'StorageHubDenied'; Source = 'Hub'; HubUri = $null; ExpectedRole = 'Storage Blob Data Reader' }
                @{ Mode = 'KustoHubDenied'; Source = 'Hub'; HubUri = 'https://test.eastus.kusto.windows.net'; ExpectedRole = 'Database Viewer' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $HubUri
                $env:FINOPS_HUB_KUSTO_DB = 'Hub'
                $reportPath = Join-Path $TestDrive $Mode
                Mock Search-AzGraph {
                    [pscustomobject]@{ name = 'test-hub-storage'; resourceGroup = 'test-hub'; subscriptionId = '11111111-1111-1111-1111-111111111111' }
                }
                if (-not $HubUri) {
                    Mock Resolve-FOHubProvider { @{ Found = $false } }
                }
                Mock Read-FinOpsHubData { throw '403 Forbidden: storage fixture.' }
                Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw '403 Forbidden: API fixture.' }
                Mock Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool { @{ Ok = $false; Rows = @(); Error = '403 Forbidden: Kusto fixture.' } }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource $Source -OutputPath $reportPath -NonInteractive -ErrorAction Stop

                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result['_error_Get-CostData'] | Should -Match '403'
                $result['Get-CostData'] | Should -BeNullOrEmpty
                $html = Get-Content (Join-Path $reportPath 'FinOpsReport.html') -Raw
                $html | Should -Match ([regex]::Escape($ExpectedRole))
                $html | Should -Match 'Scans Run</div><div class="value">1</div>'
                $html | Should -Match 'Errors</div><div class="value severity-red">1</div>'
                Get-Content (Join-Path $reportPath 'ScanSummary.txt') -Raw | Should -Match 'ERROR:.*403'
                @(Get-ChildItem -LiteralPath $reportPath -Filter '*.csv').Count | Should -Be 0
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match "Required role:\s+$([regex]::Escape($ExpectedRole))" }
                Should -Invoke Read-Host -Times 0 -Exactly
                if ($Source -eq 'Hub') {
                    Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                    $html | Should -Not -Match 'Cost Management Reader'
                }
            }
        }

        Context 'Parameters' {
            It 'Should expose an optional SubscriptionId parameter' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit'
                $cmd.Parameters.ContainsKey('SubscriptionId') | Should -BeTrue
            }

            It 'Should expose an optional OutputPath parameter' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit'
                $cmd.Parameters.ContainsKey('OutputPath') | Should -BeTrue
            }

            It 'Should expose Scans, DataSource, and NonInteractive parameters' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit'
                foreach ($p in 'Scans', 'DataSource', 'NonInteractive') {
                    $cmd.Parameters.ContainsKey($p) | Should -BeTrue -Because "$p is documented as a parameter"
                }
            }

            It 'Should constrain DataSource to the supported sources' {
                $cmd = Get-Command -Name 'Start-FinOpsMultitool' -Module 'FinOpsToolkit'
                $set = $cmd.Parameters['DataSource'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $set.ValidValues | Should -Be @('Hub', 'API', 'GraphOnly')
            }
        }

        Context 'Variable safety' {
            # A local named like a validated parameter is the same variable, because
            # PowerShell names are case-insensitive. Assigning a different type to it
            # throws ValidationMetadataException at runtime and breaks every code path,
            # which unit tests that never enter the main flow will not catch.
            It 'Should not assign to any validated parameter of Invoke-FinOpsMultitool' {
                $tuiPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($tuiPath, [ref]$null, [ref]$null)

                $fn = $ast.FindAll({
                        param($n)
                        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $n.Name -eq 'Invoke-FinOpsMultitool'
                    }, $true) | Select-Object -First 1
                $fn | Should -Not -BeNullOrEmpty

                $guarded = $fn.Body.ParamBlock.Parameters |
                Where-Object { $_.Attributes.TypeName.Name -contains 'ValidateSet' } |
                ForEach-Object { $_.Name.VariablePath.UserPath }
                $guarded | Should -Not -BeNullOrEmpty -Because 'DataSource carries a ValidateSet'

                $assigned = $fn.FindAll({
                        param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst]
                    }, $true) |
                ForEach-Object { $_.Left } |
                Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] } |
                ForEach-Object { $_.VariablePath.UserPath }

                foreach ($p in $guarded) {
                    $assigned | Should -Not -Contain $p -Because "assigning to `$$p reuses the validated parameter"
                }
            }
        }
    }
}
