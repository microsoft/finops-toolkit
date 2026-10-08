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
            It 'Shows missing-module guidance before any Azure calls' {
                Mock Import-Module { }
                Mock Get-Module { $null }
                Mock Write-Host { }
                Mock Get-AzContext { throw 'Azure must not be queried without required modules.' }

                { Start-FinOpsMultitool -NonInteractive -ErrorAction Stop } | Should -Not -Throw

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq '  MISSING REQUIRED MODULES' }
                Should -Invoke Get-AzContext -Times 0 -Exactly
            }

            It 'Rejects Windows PowerShell 5.1 before scanning through <Command>' -Skip:(-not $IsWindows) -ForEach @(
                @{ Command = 'Start-FinOpsMultitool'; Script = '../../Public/Start-FinOpsMultitool.ps1' }
                @{ Command = 'Invoke-FinOpsMultitool'; Script = '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1' }
            ) {
                $entryPath = (Join-Path $PSScriptRoot $Script).Replace("'", "''")
                $scriptText = @"
`$ErrorActionPreference = 'Stop'
. '$entryPath'
try {
    $Command -NonInteractive -Scans Get-TagInventory -DataSource GraphOnly
    throw 'The unsupported host was not rejected.'
}
catch {
    if (`$_.Exception.Message -notmatch 'requires PowerShell 7.*pwsh.*No scan was started') { throw }
    if (Get-Module FinOpsMultitool) { throw 'The scan module was loaded in the unsupported host.' }
    if (Get-Variable FinOpsResults -Scope Global -ErrorAction SilentlyContinue) { throw 'The unsupported host started a scan.' }
    'Rejected before scanning'
}
"@
                $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'))
                $startInfo.UseShellExecute = $false
                $startInfo.RedirectStandardOutput = $true
                $startInfo.RedirectStandardError = $true
                foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) {
                    $startInfo.ArgumentList.Add($argument)
                }
                $process = [System.Diagnostics.Process]::new()
                try {
                    $process.StartInfo = $startInfo
                    [void]$process.Start()
                    $standardOutput = $process.StandardOutput.ReadToEndAsync()
                    $standardError = $process.StandardError.ReadToEndAsync()
                    if (-not $process.WaitForExit(20000)) {
                        $process.Kill()
                        throw 'The unsupported-host check did not finish.'
                    }
                    $process.ExitCode | Should -Be 0 -Because $standardError.GetAwaiter().GetResult()
                    $standardOutput.GetAwaiter().GetResult() | Should -Match 'Rejected before scanning'
                }
                finally { $process.Dispose() }
            }

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
        [switch]$NonInteractive,
        [switch]$Accessible
    )
    [pscustomobject]@{
        SubscriptionId = $SubscriptionId
        OutputPath = $OutputPath
        Scans = $Scans
        DataSource = $DataSource
        NonInteractive = $NonInteractive.IsPresent
        Accessible = $Accessible.IsPresent
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
                @{ Source = 'Export' }
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

            It 'Forwards Accessible when explicitly set to <Enabled>' -Tag 'AccessibleMode' -ForEach @(
                @{ Enabled = $true }
                @{ Enabled = $false }
            ) {
                $result = Start-FinOpsMultitool -Accessible:$Enabled

                $result.Accessible | Should -Be $Enabled
                $result.BoundParameters | Should -Contain 'Accessible'
                $result.NonInteractive | Should -BeFalse
            }
        }

        Context 'Accessible console selection' {
            BeforeEach {
                $tuiPath = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
                $tuiAst = [Management.Automation.Language.Parser]::ParseFile($tuiPath, [ref]$null, [ref]$null)
                foreach ($definition in $tuiAst.FindAll({
                            param($node)
                            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                            $node.Name -in @('Test-FinOpsRichConsole', 'Write-FinOpsConsole')
                        }, $true)) {
                    . ([scriptblock]::Create($definition.Extent.Text))
                }
                $script:PreviousRichConsole = $script:FinOpsRichConsole
                $script:FinOpsRichConsole = $true
                Mock Write-Host { }
            }

            AfterEach { $script:FinOpsRichConsole = $script:PreviousRichConsole }

            It 'Overrides a cached rich console only when Accessible is <Enabled>' -Tag 'AccessibleMode' -ForEach @(
                @{ Enabled = $true }
                @{ Enabled = $false }
            ) {
                Set-Variable -Name Accessible -Value $Enabled -Scope Local

                Test-FinOpsRichConsole | Should -Be (-not $Accessible)
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
                    $context = [Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext]::new()
                    $context.Tenant = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureTenant]::new()
                    $context.Tenant.Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    $context.Account = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureAccount]::new()
                    $context.Account.Id = 'test@example.test'
                    $context
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

            It 'Completes an accessible launch with NonInteractive set to <Unattended>' -Tag 'AccessibleMode' -ForEach @(
                @{ Unattended = $false }
                @{ Unattended = $true }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $answers = [Collections.Generic.Queue[string]]::new()
                $answers.Enqueue('S')
                $answers.Enqueue('1')
                $answers.Enqueue('')
                Mock Read-Host { if ($answers.Count) { $answers.Dequeue() } else { throw 'Unexpected prompt.' } }
                Mock Get-AzTenant {
                    @(
                        [pscustomobject]@{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Name = 'Selected tenant' }
                        [pscustomobject]@{ TenantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Name = 'Other tenant' }
                    )
                }
                Mock Get-AzSubscription {
                    $first = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' }
                    if ($SubscriptionId) { return $first }
                    @($first, [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' })
                }
                $parameters = @{
                    Accessible = $true
                    NonInteractive = $Unattended
                    Scans = @('Get-CostData')
                    DataSource = 'API'
                    OutputPath = (Join-Path $TestDrive 'accessible-reports')
                    ErrorAction = 'Stop'
                }
                if ($Unattended) { $parameters.SubscriptionId = '11111111-1111-1111-1111-111111111111' }

                Start-FinOpsMultitool @parameters

                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result.ContainsKey('_error_Get-CostData') | Should -BeFalse
                $result['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                Should -Invoke Clear-Host -Times 0 -Exactly
                Should -Invoke Read-Host -Times $(if ($Unattended) { 0 } else { 3 }) -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Get-AzSubscription -Times 0 -Exactly -ParameterFilter { $TenantId -ne 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
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

                $runs = @(Get-ChildItem -LiteralPath $reportPath -Directory)
                $runs.Count | Should -Be 1
                $reportPath = $runs[0].FullName
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
                Should -Invoke Set-AzContext -Times 1 -Exactly -ParameterFilter {
                    $SubscriptionId -eq '11111111-1111-1111-1111-111111111111' -and
                    $TenantId -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -and $Scope -eq 'Process'
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

            It 'Offers ordinary exports without a Hub for <Mode>' -Tag 'GenericExportPicker' -ForEach @(
                @{ Mode = 'interactive'; Preselected = $null; Unattended = $false }
                @{ Mode = 'explicit export with Kusto override'; Preselected = 'Export'; Unattended = $true }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = if ($Preselected) { 'https://unused.example.kusto.windows.net' } else { $null }
                Set-Variable -Name NonInteractive -Value $Unattended -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole', 'Test-FinOpsRichConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $answers = [Collections.Generic.Queue[string]]::new()
                $answers.Enqueue('1')
                $answers.Enqueue('1')
                Mock Read-FinOpsAnswer { if ($answers.Count) { $answers.Dequeue() } else { '' } }
                Mock Test-FinOpsRichConsole { $false }
                Mock Resolve-FOHubProvider { throw 'An explicit export choice must not select Kusto.' }
                Mock Find-CostExport {
                    @([pscustomobject]@{ Name = 'example-focus'; Format = 'Csv'; Type = 'FocusCost'; SubId = '11111111-1111-1111-1111-111111111111'; ScopeKind = 'Subscription'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/examplestorage'; Container = 'exports'; RootFolder = 'cost'; LastRunDate = '2026-10-01' })
                }
                Mock Find-CostExportFromStorage { @() }
                Mock Get-ExportStorageCandidates { @() }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected $Preselected

                $choice.Source | Should -Be 'Export'
                $choice.Export.Name | Should -Be 'example-focus'
                $choice.TenantId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                Should -Invoke Find-CostExport -Times 1 -Exactly -ParameterFilter { @($Subscriptions).Count -eq 1 -and $Subscriptions[0].Id -eq '11111111-1111-1111-1111-111111111111' }
                Should -Invoke Find-CostExportFromStorage -Times 1 -Exactly -ParameterFilter { @($Subscriptions).Count -eq 1 -and $Subscriptions[0].Id -eq '11111111-1111-1111-1111-111111111111' }
                Should -Invoke Resolve-FOHubProvider -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Get-AzTenant -Times 0 -Exactly
            }

            It 'Keeps readable export choices and summarizes inaccessible storage without asking for a container' -Tag 'AutomaticExportDiscovery' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Write-FinOpsConsole', 'Read-FinOpsAnswer') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { '1' }
                Mock Find-CostExport { @() }
                Mock Get-ExportStorageCandidates { @() }
                Mock Find-CostExportFromStorage {
                    Write-Warning 'Synthetic storage probe HTTP 403.'
                    Write-Warning 'Synthetic second storage probe HTTP 403.'
                    @([pscustomobject]@{ Name = 'example-focus'; Format = 'Csv'; Type = 'FocusCost'; ScopeKind = 'Storage'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example'; Container = 'billingdata'; RootFolder = 'costs' })
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Export -WarningVariable emittedWarnings

                $choice.Source | Should -Be 'Export'
                $choice.Export.Container | Should -Be 'billingdata'
                Should -Invoke Read-FinOpsAnswer -Times 1 -Exactly
                Should -Invoke Read-FinOpsAnswer -Times 0 -Exactly -ParameterFilter { $Prompt -match 'container name|storage account' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -match 'Storage discovery reported 2 warning' }
            }

            It 'Offers a storage-only export alongside Cost Management definitions' -Tag 'AutomaticExportDiscovery' {
                # A central export can stay invisible to Cost Management while some
                # subscriptions still return definitions, so the storage pass must
                # never be gated behind an empty definition result.
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Write-FinOpsConsole', 'Read-FinOpsAnswer') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { '2' }
                Mock Find-CostExport {
                    @([pscustomobject]@{ Name = 'defined-actual'; Format = 'Csv'; Type = 'ActualCost'; ScopeKind = 'Subscription'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example'; Container = 'exports'; RootFolder = 'costs' })
                }
                Mock Get-ExportStorageCandidates { @() }
                Mock Find-CostExportFromStorage {
                    @([pscustomobject]@{ Name = 'hidden-focus'; Format = 'Csv'; Type = 'FocusCost'; ScopeKind = 'Storage'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example'; Container = 'billingdata'; RootFolder = 'costs' })
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Export

                $choice.Export.Container | Should -Be 'billingdata'
                Should -Invoke Find-CostExportFromStorage -Times 1 -Exactly -ParameterFilter { $KnownKeys.Count -eq 1 -and $KnownKeys.Keys -contains '/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/fixture/providers/microsoft.storage/storageaccounts/example|exports|costs|defined-actual' }
            }

            It 'Rejects <Scenario> export selection without choosing another source' -Tag 'GenericExportPicker' -ForEach @(
                @{ Scenario = 'no candidates'; CandidateCount = 0; Format = 'Csv'; WrongTenant = $false; Expected = '*No export candidates*' }
                @{ Scenario = 'ambiguous candidates'; CandidateCount = 2; Format = 'Csv'; WrongTenant = $false; Expected = '*Multiple export candidates*' }
                @{ Scenario = 'Parquet'; CandidateCount = 1; Format = 'Parquet'; WrongTenant = $false; Expected = '*supports CSV*' }
                @{ Scenario = 'tenant mismatch'; CandidateCount = 1; Format = 'Csv'; WrongTenant = $true; Expected = '*selected tenant*' }
            ) {
                $candidateTotal = $CandidateCount
                $candidateFormat = $Format
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Write-FinOpsConsole') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Find-CostExport {
                    for ($candidateIndex = 0; $candidateIndex -lt $candidateTotal; $candidateIndex++) {
                        [pscustomobject]@{ Name = "example-$candidateIndex"; Format = $candidateFormat; Type = 'FocusCost'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example'; Container = 'exports'; RootFolder = 'costs' }
                    }
                }
                Mock Find-CostExportFromStorage { @() }
                Mock Get-ExportStorageCandidates { @() }
                Mock Get-CostExportData { throw 'No export should be read.' }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example'; TenantId = $(if ($WrongTenant) { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' } else { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }) })

                { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Export } | Should -Throw $Expected

                Should -Invoke Get-CostExportData -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
                if ($WrongTenant) { Should -Invoke Find-CostExport -Times 0 -Exactly; Should -Invoke Find-CostExportFromStorage -Times 0 -Exactly }
            }

            It 'Offers the API only by explicit menu answer when no export is found: <Case>' -Tag 'GenericExportPicker' -ForEach @(
                @{ Case = 'no Hub, answer Y'; HubAvailable = $false; Preselected = $null; Answers = @('1', 'Y'); ExpectedSource = 'API' }
                @{ Case = 'Hub found, answer yes'; HubAvailable = $true; Preselected = $null; Answers = @('2', 'yes'); ExpectedSource = 'API' }
                @{ Case = 'answer N'; HubAvailable = $false; Preselected = $null; Answers = @('1', 'N'); ExpectedSource = $null }
                @{ Case = 'empty answer'; HubAvailable = $false; Preselected = $null; Answers = @('1', ''); ExpectedSource = $null }
                @{ Case = 'explicit Export parameter'; HubAvailable = $false; Preselected = 'Export'; Answers = @(); ExpectedSource = $null }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $answerQueue = [Collections.Generic.Queue[string]]::new([string[]]$Answers)
                Mock Read-FinOpsAnswer { if ($answerQueue.Count) { $answerQueue.Dequeue() } else { throw 'Unexpected prompt.' } }
                Mock Search-AzGraph { if ($HubAvailable) { [pscustomobject]@{ name = 'fixturehub'; resourceGroup = 'fixture' } } else { @() } }
                Mock Resolve-FOHubProvider { throw 'Only the Hub choice may resolve a Hub provider.' }
                Mock Find-CostExport { @() }
                Mock Find-CostExportFromStorage { @() }
                Mock Get-ExportStorageCandidates { @() }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                if ($ExpectedSource) {
                    $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected $Preselected
                    $choice.Source | Should -Be $ExpectedSource
                    $choice.Export | Should -BeNullOrEmpty
                }
                else {
                    { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected $Preselected } | Should -Throw '*No export candidates*'
                }
                Should -Invoke Read-FinOpsAnswer -Times $Answers.Count -Exactly
                Should -Invoke Write-Host -Times $(if ($Preselected) { 0 } else { 1 }) -Exactly -ParameterFilter { $Object -like '*live Cost Management API instead*' }
                Should -Invoke Find-CostExport -Times 1 -Exactly
                Should -Invoke Resolve-FOHubProvider -Times 0 -Exactly
            }

            It 'Asks before scanning more than 100 storage accounts: <Case>' -Tag 'AutomaticExportDiscovery' -ForEach @(
                @{ Case = 'scan all'; StoreCount = 101; Unattended = $false; Answers = @('Y', '1'); ExpectPrompt = $true; ExpectScan = $true }
                @{ Case = 'skip'; StoreCount = 101; Unattended = $false; Answers = @('N'); ExpectPrompt = $true; ExpectScan = $false }
                @{ Case = 'empty answer'; StoreCount = 101; Unattended = $false; Answers = @(''); ExpectPrompt = $true; ExpectScan = $false }
                @{ Case = '100 accounts'; StoreCount = 100; Unattended = $false; Answers = @('1'); ExpectPrompt = $false; ExpectScan = $true }
                @{ Case = 'unattended'; StoreCount = 101; Unattended = $true; Answers = @(); ExpectPrompt = $false; ExpectScan = $true }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $Unattended -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $answerQueue = [Collections.Generic.Queue[string]]::new([string[]]$Answers)
                Mock Read-FinOpsAnswer { if ($answerQueue.Count) { $answerQueue.Dequeue() } else { throw 'Unexpected prompt.' } }
                Mock Find-CostExport { @() }
                Mock Get-ExportStorageCandidates {
                    foreach ($storeIndex in 1..$StoreCount) { [pscustomobject]@{ Name = "store$storeIndex"; ResourceId = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/store$storeIndex"; SubId = '11111111-1111-1111-1111-111111111111' } }
                }
                Mock Find-CostExportFromStorage {
                    @([pscustomobject]@{ Name = 'storage-focus'; Format = 'Csv'; Type = 'FocusCost'; ScopeKind = 'Storage'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/store1'; Container = 'exports'; RootFolder = 'costs' })
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                if ($ExpectScan) {
                    $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Export
                    $choice.Export.Name | Should -Be 'storage-focus'
                }
                else {
                    { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Export } | Should -Throw '*No export candidates*'
                    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*skipped 101 storage accounts by choice*' }
                }
                Should -Invoke Get-ExportStorageCandidates -Times 1 -Exactly
                Should -Invoke Find-CostExportFromStorage -Times $(if ($ExpectScan) { 1 } else { 0 }) -Exactly -ParameterFilter { @($StorageAccounts).Count -eq $StoreCount }
                Should -Invoke Write-Host -Times $(if ($ExpectPrompt) { 1 } else { 0 }) -Exactly -ParameterFilter { $Object -like '*Scan all * storage accounts`?*' }
                Should -Invoke Write-Host -Times $(if ($ExpectScan) { 1 } else { 0 }) -Exactly -ParameterFilter { $Object -like '*Additional exports found directly in storage*' }
                Should -Invoke Read-FinOpsAnswer -Times $Answers.Count -Exactly
            }

            It 'Keeps export cost scans off live APIs (read failure: <ReadFails>)' -Tag 'GenericExportRunner' -ForEach @(
                @{ ReadFails = $false; Partial = $false }
                @{ ReadFails = $true; Partial = $false }
                @{ ReadFails = $false; Partial = $true }
            ) {
                $readFailure = $ReadFails
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Get-CostExportData {
                    if ($readFailure) { throw 'Synthetic export part could not be read; coverage is incomplete.' }
                    $exportRows = @(
                        [pscustomobject]@{ SubAccountId = '11111111-1111-1111-1111-111111111111'; BilledCost = 100; EffectiveCost = 80; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01'; ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/example'; Tags = '{"CostCenter":"example"}' }
                        [pscustomobject]@{ SubAccountId = '99999999-9999-9999-9999-999999999999'; BilledCost = 999; EffectiveCost = 900; BillingCurrency = 'EUR'; ChargePeriodStart = '2026-09-01'; ResourceId = '/subscriptions/99999999-9999-9999-9999-999999999999/resourceGroups/fixture/providers/Microsoft.Compute/disks/outside'; Tags = '{}' }
                        [pscustomobject]@{ SubAccountId = ''; BilledCost = 250; EffectiveCost = 250; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01'; ResourceId = ''; Tags = '{}' }
                    )
                    [pscustomobject]@{ Rows = $exportRows; ColMap = Resolve-ExportColumns -Header $exportRows[0].PSObject.Properties.Name; Currency = 'USD'; CostBasis = 'FocusCost'; DataDate = [datetime]'2026-10-01' }
                }
                Mock Get-CostData { throw 'Live cost calls are prohibited in export mode.' }
                Mock Get-ResourceCosts { throw 'Live cost calls are prohibited in export mode.' }
                Mock Get-CostByTag { throw 'Live cost calls are prohibited in export mode.' }
                Mock Get-CostTrend { throw 'Live cost calls are prohibited in export mode.' }
                Mock Get-UnitEconomics { throw 'Live cost calls are prohibited in export mode.' }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                $source = @{ Source = 'Export'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Environment = 'AzureCloud'; Export = [pscustomobject]@{ Name = 'example-focus'; Format = 'Csv' } }
                if ($Partial) { $subscriptions += [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'No returned rows'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } }
                $modules = @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend', 'Get-UnitEconomics') | ForEach-Object { @{ Fn = $_; Name = $_; Selected = $true } }

                $result = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $source

                if ($ReadFails) {
                    foreach ($scan in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend')) { $result["_error_$scan"] | Should -Match 'export.*incomplete' }
                }
                else {
                    $result['Get-CostData'][$subscriptions[0].Id].Actual | Should -Be 100
                    $result['Get-CostData'].Count | Should -Be 1
                    $result['Get-ResourceCosts'][0].Actual | Should -Be 100
                    $result['Get-CostByTag'].CostByTag.CostCenter[0].Cost | Should -Be 100
                    $result['Get-CostTrend'].Months[0].Cost | Should -Be 100
                    $result['Get-CostTrend'].BySubscription.Count | Should -Be 1
                    $result['Get-CostTrend'].CoverageIncomplete | Should -Be $Partial
                    $result['Get-CostTrend'].SelectedSubscriptionCount | Should -Be $subscriptions.Count
                    $result['_source_Export'].ScannedSubs | Should -Be 1
                    $result['_source_Export'].TotalSubs | Should -Be $subscriptions.Count
                    $result['_source_Export'].UnattributedRowCount | Should -Be 1
                    $result['_source_Export'].Note | Should -Match 'Not included in these subscription totals: 1 export row with no subscription \(USD 250\.00\)'
                    if ($Partial) { $result['Get-CostTrend'].UnverifiedSubscriptionIds | Should -Contain $subscriptions[1].Id }
                }
                $result['_error_Get-UnitEconomics'] | Should -Match 'not supported.*export'
                Should -Invoke Get-CostExportData -Times 1 -Exactly
                foreach ($scan in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend', 'Get-UnitEconomics')) { Should -Invoke $scan -Times 0 -Exactly }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Runs the public launcher from an ordinary export without a Hub or live cost query' -Tag 'GenericExportRunner' {
                $env:FINOPS_HUB_KUSTO_URI = 'https://unused.example.kusto.windows.net'
                Mock Find-CostExport {
                    @([pscustomobject]@{ Name = 'example-export'; Format = 'Csv'; Type = 'ActualCost'; StorageResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Storage/storageAccounts/example'; Container = 'exports'; RootFolder = 'costs' })
                }
                Mock Find-CostExportFromStorage { @() }
                Mock Get-ExportStorageCandidates { @() }
                Mock Get-CostExportData {
                    [pscustomobject]@{ CostBasis = 'ActualCost'; DataDate = [datetime]'2026-10-01'; Rows = @([pscustomobject]@{ SubscriptionId = '11111111-1111-1111-1111-111111111111'; Cost = 125; Currency = 'USD'; Date = '2026-09-30' }) }
                }
                $reportRoot = Join-Path $TestDrive 'ordinary-export-public'

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -DataSource Export -Scans Get-CostData -NonInteractive -OutputPath $reportRoot -ErrorAction Stop

                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                $rows = @(Import-Csv -LiteralPath (Join-Path $run 'Get-CostData.csv'))
                $rows[0].Actual | Should -Be '125'
                $rows[0].ForecastSource | Should -Be 'Unavailable'
                Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw | Should -Match 'Cost Management export \(example-export\)'
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Search-AzGraph -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
            }

            It 'Cancels invalid accessible source input for <Case>' -Tag 'AccessibleMode', 'AccessibleSourceChoice' -ForEach @(
                @{ Case = 'no hub, invalid'; HubAvailable = $false; InputValue = 'x'; Confirmation = $false; Reachable = $true; PromptCount = 3 }
                @{ Case = 'no hub, blank'; HubAvailable = $false; InputValue = ''; Confirmation = $false; Reachable = $true; PromptCount = 3 }
                @{ Case = 'hub, invalid'; HubAvailable = $true; InputValue = 'x'; Confirmation = $false; Reachable = $true; PromptCount = 3 }
                @{ Case = 'hub, blank'; HubAvailable = $true; InputValue = ''; Confirmation = $false; Reachable = $true; PromptCount = 3 }
                @{ Case = 'unreachable hub, invalid confirmation'; HubAvailable = $true; InputValue = 'x'; Confirmation = $true; Reachable = $false; PromptCount = 2 }
                @{ Case = 'unreachable hub, blank confirmation'; HubAvailable = $true; InputValue = ''; Confirmation = $true; Reachable = $false; PromptCount = 2 }
                @{ Case = 'large hub, invalid confirmation'; HubAvailable = $true; InputValue = 'x'; Confirmation = $true; Reachable = $true; PromptCount = 2 }
                @{ Case = 'large hub, blank confirmation'; HubAvailable = $true; InputValue = ''; Confirmation = $true; Reachable = $true; PromptCount = 2 }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name Accessible -Value $true -Scope Local
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            param($node)
                            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                            $node.Name -in @('Select-DataSource', 'Test-FinOpsRichConsole', 'Read-FinOpsAnswer', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $answers = [Collections.Generic.Queue[string]]::new()
                if ($Confirmation) { $answers.Enqueue('1') }
                $answers.Enqueue($InputValue)
                Mock Read-Host { if ($answers.Count) { $answers.Dequeue() } else { $InputValue } }
                Mock Search-AzGraph { if ($HubAvailable) { [pscustomobject]@{ name = 'fixturehub'; resourceGroup = 'fixture' } } else { @() } }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Measure-FinOpsHubSize { @{ Known = $false; Reachable = $Reachable; IsLarge = $true; Display = 'unknown' } }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions } | Should -Throw '*No valid data source was selected*'

                Should -Invoke Read-Host -Times $PromptCount -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Requires Y or N before switching an unreachable Hub to the API: <Case>' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ Case = 'blank then Y'; RichConsole = $true; Answers = @('1', '', 'Y'); ExpectedSource = 'API' }
                @{ Case = 'invalid then N'; RichConsole = $true; Answers = @('1', 'x', 'N'); ExpectedSource = 'Hub' }
                @{ Case = 'yes'; RichConsole = $true; Answers = @('1', 'yes'); ExpectedSource = 'API' }
                @{ Case = 'three blanks in a console that cannot prompt'; RichConsole = $false; Answers = @('1', '', '', ''); ExpectedSource = $null }
                @{ Case = 'three invalid answers in a full terminal'; RichConsole = $true; Answers = @('1', 'x', 'x', 'x'); ExpectedSource = $null }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name Accessible -Value $false -Scope Local
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Select-DataSource', 'Test-FinOpsRichConsole', 'Read-FinOpsAnswer', 'Write-FinOpsConsole') }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $answerQueue = [Collections.Generic.Queue[string]]::new([string[]]$Answers)
                Mock Read-FinOpsAnswer { if ($answerQueue.Count) { $answerQueue.Dequeue() } else { throw 'Unexpected prompt.' } }
                Mock Test-FinOpsRichConsole { $RichConsole }
                Mock Search-AzGraph { [pscustomobject]@{ name = 'fixturehub'; resourceGroup = 'fixture' } }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Measure-FinOpsHubSize { @{ Known = $false; Reachable = $false; IsLarge = $true; Display = 'unknown' } }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                if ($ExpectedSource) {
                    $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                    $choice.Source | Should -Be $ExpectedSource
                }
                else {
                    { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions } | Should -Throw '*No valid data source was selected*'
                }
                Should -Invoke Read-FinOpsAnswer -Times $Answers.Count -Exactly
            }

            It 'Preserves the interactive Kusto choice without rediscovering the provider' -Tag 'SourceSelectionIsolation' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Read-FinOpsAnswer', 'Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { '1' }
                Mock Search-AzGraph { [pscustomobject]@{ name = 'test-hub-storage'; resourceGroup = 'test-hub' } }
                Mock Resolve-FOHubProvider {
                    @{ Found = $true; Mode = 'Kusto'; ClusterUri = 'https://test.eastus.kusto.windows.net'; Database = 'Hub'; UseAuth = $true }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Test subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                $choice.HubProvider.ClusterUri | Should -Be 'https://test.eastus.kusto.windows.net'
                $result = Invoke-SelectedScans -Modules @(@{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true }) -Subscriptions $subscriptions -DataSource $choice

                $result['Get-CostData'][$subscriptions[0].Id].Actual | Should -Be 100
                $choice.HubProvider.Database | Should -Be 'Hub'
                Should -Invoke Resolve-FOHubProvider -Times 1 -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Keeps <ProbeState> Hub discovery in the selected tenant for <Mode>' -Tag 'SourceSelectionIsolation', 'MergeBlockerDiscovery' -ForEach @(
                @{ ProbeState = 'partial'; AllProbesFail = $false; Mode = 'noninteractive'; Unattended = $true; Answer = '1'; ExpectedSource = 'API' }
                @{ ProbeState = 'partial'; AllProbesFail = $false; Mode = 'interactive API'; Unattended = $false; Answer = '2'; ExpectedSource = 'API' }
                @{ ProbeState = 'partial'; AllProbesFail = $false; Mode = 'interactive GraphOnly'; Unattended = $false; Answer = '3'; ExpectedSource = 'GraphOnly' }
                @{ ProbeState = 'failed'; AllProbesFail = $true; Mode = 'noninteractive'; Unattended = $true; Answer = '1'; ExpectedSource = 'API' }
                @{ ProbeState = 'failed'; AllProbesFail = $true; Mode = 'interactive API'; Unattended = $false; Answer = '2'; ExpectedSource = 'API' }
                @{ ProbeState = 'failed'; AllProbesFail = $true; Mode = 'interactive GraphOnly'; Unattended = $false; Answer = '3'; ExpectedSource = 'GraphOnly' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $Unattended -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { $Answer }
                Mock Search-AzGraph {
                    if ($AllProbesFail -or $Subscription -contains '22222222-2222-2222-2222-222222222222') { throw 'Synthetic discovery HTTP 429.' }
                    @()
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Reachable'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Throttled'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                )

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $choice.Source | Should -Be $ExpectedSource
                $choice.HubStorage | Should -BeNullOrEmpty
                Should -Invoke Search-AzGraph -Times 2 -Exactly
                foreach ($selectedId in $subscriptions.Id) {
                    Should -Invoke Search-AzGraph -Times 1 -Exactly -ParameterFilter {
                        @($Subscription).Count -eq 1 -and $Subscription[0] -eq $selectedId -and
                        $DefaultProfile.DefaultContext.Tenant.Id -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -and -not $UseTenantScope
                    }
                }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match 'Hub discovery is incomplete' }
                Should -Invoke Get-AzTenant -Times 0 -Exactly
                Should -Invoke Get-AzSubscription -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Maps source choice <Answer> to <ExpectedSource> when a Hub is <HubState>' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ HubState = 'found'; HubAvailable = $true; Answer = '2'; ExpectedSource = 'Export' }
                @{ HubState = 'found'; HubAvailable = $true; Answer = '3'; ExpectedSource = 'API' }
                @{ HubState = 'found'; HubAvailable = $true; Answer = '4'; ExpectedSource = 'GraphOnly' }
                @{ HubState = 'missing'; HubAvailable = $false; Answer = '1'; ExpectedSource = 'Export' }
                @{ HubState = 'missing'; HubAvailable = $false; Answer = '2'; ExpectedSource = 'API' }
                @{ HubState = 'missing'; HubAvailable = $false; Answer = '3'; ExpectedSource = 'GraphOnly' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Select-ExportSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { $Answer }
                Mock Select-ExportSource { @{ Source = 'Export'; HubStorage = $null } }
                Mock Search-AzGraph { if ($HubAvailable) { [pscustomobject]@{ name = 'fixturehub'; resourceGroup = 'fixture' } } else { @() } }
                Mock Resolve-FOHubProvider { throw 'Only the Hub choice may resolve a Hub provider.' }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                $expectedExportCalls = if ($ExpectedSource -eq 'Export') { 1 } else { 0 }

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $choice.Source | Should -Be $ExpectedSource
                Should -Invoke Read-FinOpsAnswer -Times 1 -Exactly
                Should -Invoke Select-ExportSource -Times $expectedExportCalls -Exactly
                Should -Invoke Resolve-FOHubProvider -Times 0 -Exactly
            }

            It 'Rejects <ScopeProblem> subscription ownership before source discovery' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ ScopeProblem = 'different tenant'; SubscriptionTenant = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
                @{ ScopeProblem = 'unknown tenant'; SubscriptionTenant = $null }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Unverified'; TenantId = $SubscriptionTenant })

                { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions } |
                Should -Throw '*selected tenant*'

                Should -Invoke Search-AzGraph -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Get-AzTenant -Times 0 -Exactly
            }

            It 'Does not search other tenants for an unresolved explicit subscription in <Mode> mode' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ Mode = 'noninteractive'; Unattended = $true }
                @{ Mode = 'interactive'; Unattended = $false }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Get-AzSubscription { $null }
                Mock Get-AzTenant { [pscustomobject]@{ Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' } }

                { Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource API -NonInteractive:$Unattended -ErrorAction Stop } |
                Should -Throw '*current tenant*'

                Should -Invoke Get-AzSubscription -Times 1 -Exactly -ParameterFilter {
                    $SubscriptionId -eq '11111111-1111-1111-1111-111111111111' -and $TenantId -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                }
                Should -Invoke Get-AzTenant -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Search-AzGraph -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Rejects a subscription returned for another tenant before switching context' -Tag 'SourceSelectionIsolation' {
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-Subscription', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Get-AzSubscription {
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Other tenant'; TenantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; State = 'Enabled' }
                }

                { Select-Subscription -PreselectedId '11111111-1111-1111-1111-111111111111' } |
                Should -Throw '*current tenant*'

                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Get-AzTenant -Times 0 -Exactly
            }

            It 'Rejects a <ContextState> context before source discovery' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ ContextState = 'missing'; ContextTenant = $null }
                @{ ContextState = 'different tenant'; ContextTenant = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Get-AzContext {
                    if ($ContextTenant) { [pscustomobject]@{ Tenant = @{ Id = $ContextTenant } } }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected API } |
                Should -Throw '*current Azure context*selected tenant*'

                Should -Invoke Search-AzGraph -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Stops a <ContextState> tenant before subscription enumeration' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ ContextState = 'missing'; InitialTenant = $null; EnumeratingTenant = $null }
                @{ ContextState = 'changed'; InitialTenant = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; EnumeratingTenant = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
            ) {
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-Subscription', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                $contextChecks = @{ Count = 0 }
                Mock Get-AzContext {
                    $contextChecks.Count++
                    $currentTenant = if ($contextChecks.Count -eq 1) { $InitialTenant } else { $EnumeratingTenant }
                    [pscustomobject]@{ Account = @{ Id = 'test@example.test' }; Tenant = @{ Id = $currentTenant } }
                }
                Mock Get-AzTenant { [pscustomobject]@{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } }

                { Select-Subscription } | Should -Throw '*tenant*'

                Should -Invoke Get-AzSubscription -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Keeps an explicit Hub request strict after <ProbeState> discovery failure' -Tag 'SourceSelectionIsolation', 'MergeBlockerDiscovery' -ForEach @(
                @{ ProbeState = 'partial'; AllProbesFail = $false }
                @{ ProbeState = 'complete'; AllProbesFail = $true }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Search-AzGraph {
                    if ($AllProbesFail -or $Subscription -contains '22222222-2222-2222-2222-222222222222') { throw 'Synthetic discovery HTTP 429.' }
                    @()
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                )

                { Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected Hub } |
                Should -Throw '*discovery is incomplete*429*'

                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
            }

            It 'Honors explicit <Source> without running Hub discovery' -Tag 'SourceSelectionIsolation' -ForEach @(
                @{ Source = 'API' }
                @{ Source = 'GraphOnly' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = 'https://unused.example.test'
                Set-Variable -Name NonInteractive -Value $true -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Search-AzGraph { throw 'Explicit choices must not probe.' }
                Mock Resolve-FOHubProvider { throw 'Explicit API/GraphOnly must ignore the configured Hub.' }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions -Preselected $Source

                $choice.Source | Should -Be $Source
                Should -Invoke Search-AzGraph -Times 0 -Exactly
                Should -Invoke Resolve-FOHubProvider -Times 0 -Exactly
            }

            It 'Uses the Hub storage fallback after <FailureKind>' -Tag 'SourceSelectionIsolation', 'MergeBlockerDiscovery' -ForEach @(
                @{ FailureKind = 'a normal Kusto discovery failure'; ProviderThrows = $false }
                @{ FailureKind = 'a provider resolver exception'; ProviderThrows = $true }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Set-Variable -Name NonInteractive -Value $false -Scope Local
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Select-DataSource', 'Read-FinOpsAnswer', 'Write-FinOpsConsole', 'Invoke-SelectedScans', 'Write-SectionHeader')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Read-FinOpsAnswer { '1' }
                Mock Search-AzGraph { [pscustomobject]@{ name = 'test-hub'; resourceGroup = 'test'; subscriptionId = '11111111-1111-1111-1111-111111111111' } }
                Mock Search-AzGraphSafe -ModuleName FinOpsMultitool { throw 'Synthetic Kusto discovery HTTP 429.' }
                if ($ProviderThrows) {
                    Mock Resolve-FOHubProvider { throw 'Synthetic provider resolver exception.' }
                }
                Mock Measure-FinOpsHubSize { @{ Known = $true; Reachable = $true; IsLarge = $false; Display = 'synthetic small Hub' } }
                Mock Invoke-AzRestMethodWithRetry { throw 'The storage fixture must not make live enrichment requests.' }
                Mock Read-FinOpsHubData {
                    [pscustomobject]@{ SubAccountId = '11111111-1111-1111-1111-111111111111'; BilledCost = 100; BillingCurrency = 'USD'; ChargePeriodStart = '2026-08-01'; Tags = '' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })

                $choice = Select-DataSource -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions

                $choice.Source | Should -Be 'Hub'
                $choice.HubStorage.name | Should -Be 'test-hub'
                $choice.HubProvider | Should -BeNullOrEmpty
                $choice.HubProviderResolved | Should -BeTrue

                $scan = Invoke-SelectedScans -Modules @(@{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true }) -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $choice

                $scan.ContainsKey('_error_Get-CostData') | Should -BeFalse
                $scan['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                Should -Invoke Read-FinOpsHubData -Times 1 -Exactly -ParameterFilter { $StorageAccountName -eq 'test-hub' -and @($SubscriptionIds).Count -eq 1 -and $SubscriptionIds[0] -eq '11111111-1111-1111-1111-111111111111' }
                if ($ProviderThrows) {
                    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match 'provider discovery failed.*Synthetic provider resolver exception' }
                    Should -Invoke Resolve-FOHubProvider -Times 1 -Exactly
                }
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Handles runner provider exceptions with <Scenario>' -Tag 'SourceSelectionIsolation', 'MergeBlockerDiscovery' -ForEach @(
                @{ Scenario = 'selected Hub storage'; HasStorage = $true; ConfiguredUri = $null; ExpectedFallback = $true }
                @{ Scenario = 'an explicit Kusto endpoint'; HasStorage = $true; ConfiguredUri = 'https://configured.example.test'; ExpectedFallback = $false }
                @{ Scenario = 'no selected Hub storage'; HasStorage = $false; ConfiguredUri = $null; ExpectedFallback = $false }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $ConfiguredUri
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Resolve-FOHubProvider { throw 'Synthetic runner provider failure.' }
                Mock Invoke-AzRestMethodWithRetry { throw 'The storage fixture must not make live enrichment requests.' }
                Mock Read-FinOpsHubData {
                    [pscustomobject]@{ SubAccountId = '11111111-1111-1111-1111-111111111111'; BilledCost = 100; BillingCurrency = 'USD'; ChargePeriodStart = '2026-08-01'; Tags = '' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                $source = @{ Source = 'Hub'; HubStorage = $(if ($HasStorage) { @{ name = 'test-hub'; resourceGroup = 'test' } } else { $null }) }
                $modules = @(@{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true })

                if ($ExpectedFallback) {
                    $scan = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $source
                    $scan['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                    Should -Invoke Read-FinOpsHubData -Times 1 -Exactly -ParameterFilter { $StorageAccountName -eq 'test-hub' -and @($SubscriptionIds).Count -eq 1 -and $SubscriptionIds[0] -eq '11111111-1111-1111-1111-111111111111' }
                    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match 'provider discovery failed.*Synthetic runner provider failure' }
                }
                else {
                    { Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $source } |
                    Should -Throw '*Synthetic runner provider failure*'
                    Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
                }
                Should -Invoke Resolve-FOHubProvider -Times 1 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
            }

            It 'Completes a scoped API scan after partial automatic Hub discovery failure' -Tag 'SourceSelectionIsolation' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Get-AzTenant { [pscustomobject]@{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; Name = 'Selected tenant' } }
                Mock Get-AzSubscription {
                    @(
                        [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Reachable'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' }
                        [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Throttled'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' }
                    )
                }
                Mock Search-AzGraph {
                    if ($Subscription -contains '22222222-2222-2222-2222-222222222222') { throw 'Synthetic discovery HTTP 429.' }
                    @()
                }
                Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
                    if ($Path -notmatch '^/subscriptions/(11111111-1111-1111-1111-111111111111|22222222-2222-2222-2222-222222222222)/') { throw 'Unexpected query scope.' }
                    $amount = if ($Path -like '*forecast*') { 150.0 } else { 100.0 }
                    $content = @{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @($amount, 'USD')) } } | ConvertTo-Json -Depth 8
                    [pscustomobject]@{ StatusCode = 200; Content = $content }
                }
                $reportRoot = Join-Path $TestDrive 'partial-hub-discovery'

                Start-FinOpsMultitool -Scans Get-CostData -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $runs = @(Get-ChildItem -LiteralPath $reportRoot -Directory)
                $runs.Count | Should -Be 1
                $csvFile = Get-ChildItem -LiteralPath $runs[0].FullName -Filter '*.csv'
                $rows = @(Import-Csv -LiteralPath $csvFile.FullName)
                $rows.Count | Should -Be 2
                $rows.SubscriptionId | Should -Contain '11111111-1111-1111-1111-111111111111'
                $rows.SubscriptionId | Should -Contain '22222222-2222-2222-2222-222222222222'
                $rows | Where-Object { $_.Actual -ne '100' } | Should -BeNullOrEmpty
                Get-Content -LiteralPath (Join-Path $runs[0].FullName 'FinOpsReport.html') -Raw | Should -Match 'Cost data: Cost Management API'
                Should -Invoke Get-AzSubscription -Times 1 -Exactly -ParameterFilter { $TenantId -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 4 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Set-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Completes an automatic scoped API scan when all Hub discovery probes fail' -Tag 'SourceSelectionIsolation', 'MergeBlockerDiscovery' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Search-AzGraph { throw 'Synthetic Resource Graph HTTP 403.' }
                $reportRoot = Join-Path $TestDrive 'all-hub-probes-failed'

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result['Get-CostData'].Count | Should -Be 1
                $result['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                (Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw).Contains('Cost data: Cost Management API') | Should -BeTrue
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match 'Hub discovery is incomplete' }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 2 -Exactly
                Should -Invoke Get-AzTenant -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Attributes a failed Hub converter only to its own scan' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Search-AzGraph { [pscustomobject]@{ name = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111' } }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Read-FinOpsHubData {
                    @([pscustomobject]@{ SubAccountId = '11111111-1111-1111-1111-111111111111'; ResourceId = '/resources/fixture'; ResourceType = 'fixture'; BilledCost = 100; BillingCurrency = 'USD'; Tags = '{"CostCenter":"team"}'; ChargePeriodStart = '2026-08-01' })
                }
                Mock ConvertTo-CostDataFromHub { throw 'Synthetic summary conversion failed.' }
                $reportRoot = Join-Path $TestDrive 'independent-hub-converters'

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag') -DataSource Hub -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result['_error_Get-CostData'] | Should -Match 'Synthetic summary'
                $result.ContainsKey('_error_Get-CostByTag') | Should -BeFalse
                $result.ContainsKey('_error_Get-ResourceCosts') | Should -BeFalse
                $result['Get-CostByTag'].CostByTag.CostCenter[0].Cost | Should -Be 100
                $result['Get-ResourceCosts'][0].Actual | Should -Be 100
            }

            It 'Keeps scanner logs separate from progress when the scan <Outcome>' -ForEach @(
                @{ Outcome = 'succeeds'; FailScan = $false }
                @{ Outcome = 'fails'; FailScan = $true }
            ) {
                $shouldFail = $FailScan
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $launcherAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                            $args[0].Name -in @('Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole')
                        }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
                Mock Get-TagInventory {
                    Write-Information 'Scanner detail on its own line.' -InformationAction Continue
                    if ($shouldFail) { throw "Fixture error on a separate line.`nMore diagnostic detail." }
                    [pscustomobject]@{ TagNames = @{}; TagCount = 0 }
                }

                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })
                $result = Invoke-SelectedScans -Modules @(@{ Name = 'Tag Inventory'; Fn = 'Get-TagInventory'; Selected = $true }) -Subscriptions $subscriptions -DataSource @{ Source = 'API' }

                Should -Invoke Write-Host -Times 0 -Exactly -ParameterFilter { $NoNewline -or "$Object".Contains("`r") }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^  \[.+\] 100%  \(1/1\) Tag Inventory$' }
                if ($shouldFail) {
                    $result['_error_Get-TagInventory'] | Should -Match 'Fixture error'
                    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '    FAILED: Tag Inventory' }
                }
                else {
                    $result.ContainsKey('_error_Get-TagInventory') | Should -BeFalse
                    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^    Completed: Tag Inventory' }
                }
            }

            It 'Does not query Hub costs for a Graph-only run with a Kusto override' {
                $env:FINOPS_HUB_KUSTO_URI = 'http://localhost:8082'
                Mock Get-TagInventory { [pscustomobject]@{ TagNames = @{}; TotalResources = 0; TaggedCount = 0; UntaggedCount = 0; TagCoverage = 0 } }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-TagInventory -DataSource GraphOnly -OutputPath (Join-Path $TestDrive 'graph-only') -NonInteractive -ErrorAction Stop

                Should -Invoke Get-TagInventory -Times 1 -Exactly
                Should -Invoke Invoke-FOHubKustoQuery -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-FinOpsHubData -Times 0 -Exactly
            }

            It 'Does not re-enable <CostScan> or its dependencies in GraphOnly mode' -ForEach @(
                @{ CostScan = 'Get-BudgetHistory' }
                @{ CostScan = 'Get-UnitEconomics' }
                @{ CostScan = 'Get-AIWorkloadMetrics' }
                @{ CostScan = 'Get-MaccCommitment' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Get-TagInventory { [pscustomobject]@{ TagNames = @{}; TotalResources = 0; TaggedCount = 0; UntaggedCount = 0; TagCoverage = 0 } }
                Mock Get-BudgetHistory { throw 'Budget history must not run.' }
                Mock Get-BudgetStatus { throw 'Budgets must not run.' }
                Mock Get-CostTrend { throw 'Cost trend must not run.' }
                Mock Get-UnitEconomics { throw 'Unit economics must not run.' }
                Mock Get-AIWorkloadMetrics { throw 'AI costs must not run.' }
                Mock Get-MaccCommitment { throw 'Commitments must not run.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans @('Get-TagInventory', $CostScan) -DataSource GraphOnly -OutputPath (Join-Path $TestDrive "graph-$CostScan") -NonInteractive -ErrorAction Stop

                foreach ($command in @('Get-BudgetHistory', 'Get-BudgetStatus', 'Get-CostTrend', 'Get-UnitEconomics', 'Get-AIWorkloadMetrics', 'Get-MaccCommitment')) { Should -Invoke $command -Times 0 -Exactly }
                Should -Invoke Get-TagInventory -Times 1 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Requires an existing sign-in for noninteractive runs' {
                Mock Get-AzContext { $null }
                Mock Connect-AzAccount { throw 'Interactive sign-in must not be attempted.' }

                { Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-TagInventory -DataSource GraphOnly -NonInteractive -ErrorAction Stop } | Should -Throw '*NonInteractive*Connect-AzAccount*'

                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Skips orphan cost enrichment in GraphOnly mode' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                Mock Get-OrphanedResources { [pscustomobject]@{ Orphans = @(); TotalCount = 0; HasData = $false } }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-OrphanedResources -DataSource GraphOnly -OutputPath (Join-Path $TestDrive 'graph-orphans') -NonInteractive -ErrorAction Stop

                Should -Invoke Get-OrphanedResources -Times 1 -Exactly -ParameterFilter { $SkipCost }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Rejects an unavailable explicit Hub rather than silently selecting API' {
                $env:FINOPS_HUB_KUSTO_URI = $null

                { Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource Hub -NonInteractive -ErrorAction Stop } |
                Should -Throw '*No FinOps hub*'

                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Keeps scan results in memory when the export destination is unsafe' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $repository = Join-Path $TestDrive 'blocked-report-repository'
                [void](New-Item -ItemType Directory -Path (Join-Path $repository '.git') -Force)

                { Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource API -OutputPath $repository -NonInteractive -ErrorAction Stop } |
                Should -Throw '*report saving failed*Git*Results remain*'

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results['Get-CostData']['11111111-1111-1111-1111-111111111111'].Actual | Should -Be 100
                @(Get-ChildItem -LiteralPath $repository -File -Recurse -Force).Count | Should -Be 0
                Should -Invoke Read-Host -Times 0 -Exactly
            }

            It 'Rejects an explicit <ScanCase> scan list at the <Entry> entry point' -Tag 'EmptyScanSelection' -ForEach @(
                @{ Entry = 'public'; ScanCase = 'empty'; RequestedScans = @() }
                @{ Entry = 'public'; ScanCase = 'null'; RequestedScans = $null }
                @{ Entry = 'public'; ScanCase = 'empty-name'; RequestedScans = @('') }
                @{ Entry = 'public'; ScanCase = 'null-element'; RequestedScans = @('Get-PolicyInventory', $null) }
                @{ Entry = 'private'; ScanCase = 'empty'; RequestedScans = @() }
                @{ Entry = 'private'; ScanCase = 'null'; RequestedScans = $null }
                @{ Entry = 'private'; ScanCase = 'empty-name'; RequestedScans = @('') }
                @{ Entry = 'private'; ScanCase = 'null-element'; RequestedScans = @('Get-PolicyInventory', $null) }
            ) {
                $entryCommand = 'Start-FinOpsMultitool'
                if ($Entry -eq 'private') {
                    $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RealMultitoolRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                    $launcher = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Invoke-FinOpsMultitool' }, $true)
                    . ([scriptblock]::Create($launcher.Extent.Text))
                    $entryCommand = 'Invoke-FinOpsMultitool'
                }
                Mock Import-Module { throw 'Module import must not be reached.' }

                $failure = try { & $entryCommand -Scans $RequestedScans -NonInteractive -DataSource API -ErrorAction Stop } catch { $_ }

                $failure.FullyQualifiedErrorId | Should -Match '^ParameterArgumentValidationError'
                $failure.Exception.Message | Should -Match 'Scans'
                Should -Invoke Import-Module -Times 0 -Exactly
                Should -Invoke Get-AzContext -Times 0 -Exactly
                Should -Invoke Connect-AzAccount -Times 0 -Exactly
            }

            It 'Does not infer missing tags from an incomplete inventory' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive 'incomplete-tag-inventory'
                Mock Get-TagInventory {
                    [pscustomobject]@{ TagNames = @{}; TagCount = 0; TagCoverage = $null; CoverageIncomplete = $true; Note = 'Tag inventory coverage is incomplete.' }
                }
                Mock Get-TagRecommendations { throw 'Incomplete tags must not become missing-tag recommendations.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-TagRecommendations -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results['_error_Get-TagRecommendations'] | Should -Match 'No tags are assumed missing'
                Should -Invoke Get-TagRecommendations -Times 0 -Exactly
                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
                $html | Should -Match 'Coverage: Unverified'
                $html | Should -Not -Match 'Tag coverage is critically low|strong tagging discipline'
            }

            It 'Blocks missing-tag recommendations when Hub tag parsing fails' -Tag 'HubTagReadFailure' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive 'unreadable-hub-tags'
                Mock Search-AzGraph { [pscustomobject]@{ name = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'; location = 'eastus' } }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Read-FinOpsHubData {
                    @([pscustomobject]@{ ResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/fixture/providers/Microsoft.Compute/disks/fixture'; SubAccountId = '11111111-1111-1111-1111-111111111111'; BilledCost = 10; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-01'; Tags = '{"Owner":' })
                }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                Mock Get-TagRecommendations { throw 'Unreadable Hub tags must not become missing-tag recommendations.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-TagRecommendations -DataSource Hub -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results['Get-TagInventory'].CoverageIncomplete | Should -BeTrue
                $results['_error_Get-TagRecommendations'] | Should -Match 'No tags are assumed missing'
                Should -Invoke Get-TagRecommendations -Times 0 -Exactly
                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                (Import-Csv -LiteralPath (Join-Path $run 'Get-TagRecommendations.csv')).Status | Should -Be 'Error'
                Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw | Should -Match 'No tags are assumed missing'
                Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw | Should -Match 'No tags are assumed missing'
            }

            It 'Runs policy recommendations with <AssignmentCount> verified assignments in an <CollectionKind>' -Tag 'PolicyEmptyCollection' -ForEach @(
                @{ AssignmentCount = 0; CollectionKind = 'array' }
                @{ AssignmentCount = 1; CollectionKind = 'array' }
                @{ AssignmentCount = 2; CollectionKind = 'array' }
                @{ AssignmentCount = 0; CollectionKind = 'inventory list' }
                @{ AssignmentCount = 1; CollectionKind = 'inventory list' }
                @{ AssignmentCount = 2; CollectionKind = 'inventory list' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive "policy-assignments-$AssignmentCount-$CollectionKind"
                $definitionIds = @(
                    '/providers/Microsoft.Authorization/policyDefinitions/726aca4c-86e9-4b04-b0c5-073027359532'
                    '/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'
                )
                $fixtureAssignments = @(for ($assignmentIndex = 0; $assignmentIndex -lt $AssignmentCount; $assignmentIndex++) {
                        [pscustomobject]@{
                            PolicyDefId = $definitionIds[$assignmentIndex]
                            AssignmentId = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments/fixture-$assignmentIndex"
                            AssignmentName = "Fixture $assignmentIndex"
                            Scope = '/subscriptions/11111111-1111-1111-1111-111111111111'
                            Effect = 'Audit'; EnforcementMode = 'Default'; Origin = 'Direct'
                        }
                    })
                if ($CollectionKind -eq 'inventory list') {
                    $inventoryAssignments = [Collections.Generic.List[pscustomobject]]::new()
                    foreach ($assignment in $fixtureAssignments) { $inventoryAssignments.Add($assignment) }
                    $fixtureAssignments = $inventoryAssignments
                }
                Mock Get-PolicyInventory {
                    [pscustomobject]@{ Assignments = $fixtureAssignments; AssignmentCount = $fixtureAssignments.Count; CoverageIncomplete = $false; HasComplianceData = $false }
                }
                Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'Direct policy fixtures must not query Azure.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-PolicyRecommendations -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results.ContainsKey('_error_Get-PolicyRecommendations') | Should -BeFalse
                $results['Get-PolicyRecommendations'].Assigned.Count | Should -Be $AssignmentCount
                $results['Get-PolicyRecommendations'].Missing.Count | Should -Be ($results['Get-PolicyRecommendations'].Analysis.Count - $AssignmentCount)
                $results['Get-PolicyInventory'].Assignments.Count | Should -Be $AssignmentCount
                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                $csv = @(Import-Csv -LiteralPath (Join-Path $run 'Get-PolicyRecommendations.csv'))
                $csv.Status | Should -Contain 'Missing'
                foreach ($reportName in @('FinOpsReport.html', 'ScanSummary.txt')) {
                    Get-Content -LiteralPath (Join-Path $run $reportName) -Raw | Should -Not -Match 'Cannot bind argument|No policies are assumed missing'
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
                Should -Invoke Read-Host -Times 0 -Exactly
            }

            It 'Does not declare policies missing when their inventory is <InventoryState>' -Tag 'PolicyEmptyCollection' -ForEach @(
                @{ InventoryState = 'failed' }
                @{ InventoryState = 'incomplete' }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $fixtureInventoryState = $InventoryState
                Mock Get-PolicyInventory {
                    if ($fixtureInventoryState -eq 'failed') { throw '403: policy inventory unavailable' }
                    [pscustomobject]@{ Assignments = @(); CoverageIncomplete = $true; AssignmentErrors = @('Fixture: HTTP 403'); Note = 'Effective assignments could not be read.' }
                }
                Mock Get-PolicyRecommendations { throw 'Recommendations must not consume failed inventory.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-PolicyRecommendations -DataSource API -OutputPath (Join-Path $TestDrive 'policy-inventory-failed') -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                if ($InventoryState -eq 'failed') { $results['_error_Get-PolicyInventory'] | Should -Match '403' }
                else { $results['Get-PolicyInventory'].CoverageIncomplete | Should -BeTrue }
                $results['_error_Get-PolicyRecommendations'] | Should -Match 'No policies are assumed missing'
                $results['Get-PolicyRecommendations'] | Should -BeNullOrEmpty
                Should -Invoke Get-PolicyRecommendations -Times 0 -Exactly
            }

            It 'Preserves <InventoryState> budget inventory evidence in history reports' -Tag 'BudgetHistoryDependency' -ForEach @(
                @{ InventoryState = 'failed'; HasBudgets = $false; Incomplete = $true; ExpectError = $true }
                @{ InventoryState = 'incomplete empty'; HasBudgets = $false; Incomplete = $true; ExpectError = $true }
                @{ InventoryState = 'sampled empty'; HasBudgets = $false; Incomplete = $true; ExpectError = $true }
                @{ InventoryState = 'partial'; HasBudgets = $true; Incomplete = $true; ExpectError = $false }
                @{ InventoryState = 'complete empty'; HasBudgets = $false; Incomplete = $false; ExpectError = $false }
                @{ InventoryState = 'complete'; HasBudgets = $true; Incomplete = $false; ExpectError = $false }
            ) {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive "budget-history-$InventoryState"
                $fixtureInventoryState = $InventoryState
                $fixtureIncomplete = $Incomplete
                $fixtureBudgets = @()
                if ($HasBudgets) {
                    $fixtureBudgets = @([pscustomobject]@{
                            SubscriptionId = '11111111-1111-1111-1111-111111111111'; Subscription = 'Fixture'
                            BudgetName = 'fixture'; Amount = 100; Currency = 'USD'; Category = 'Cost'; TimeGrain = 'Monthly'
                            Scope = '/subscriptions/11111111-1111-1111-1111-111111111111'; Filter = $null
                            TimePeriod = @{ startDate = '2020-01-01'; endDate = '2030-12-31' }
                        })
                }
                $currentMonth = (Get-Date).ToUniversalTime().Date
                $currentMonth = $currentMonth.AddDays(1 - $currentMonth.Day)
                $fixtureHistoryMonths = @(foreach ($monthIndex in 1..6) {
                        [pscustomobject]@{ MonthDate = $currentMonth.AddMonths(-$monthIndex); Month = $currentMonth.AddMonths(-$monthIndex).ToString('MMM yyyy'); Cost = 12.5; Currency = 'USD' }
                    })
                Mock Get-CostData { @{ '11111111-1111-1111-1111-111111111111' = @{ Actual = 12.5; Forecast = $null; Currency = 'USD' } } }
                Mock Get-CostTrend { @{ Months = $fixtureHistoryMonths; BySubscription = @{ '11111111-1111-1111-1111-111111111111' = $fixtureHistoryMonths }; HasData = $true } }
                Mock Get-BudgetStatus {
                    if ($fixtureInventoryState -eq 'failed') { throw 'Synthetic budget inventory failed.' }
                    [pscustomobject]@{ Budgets = $fixtureBudgets; TotalBudgets = $fixtureBudgets.Count; HasData = ($fixtureBudgets.Count -gt 0); CoverageIncomplete = $fixtureIncomplete; Sampled = ($fixtureInventoryState -eq 'sampled empty'); Note = $(if ($fixtureIncomplete) { 'Synthetic budget inventory is incomplete.' } else { $null }) }
                }
                Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'History must use the complete cached fixture.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-BudgetHistory -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results.ContainsKey('_error_Get-BudgetHistory') | Should -Be $ExpectError
                $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
                $csv = @(Import-Csv -LiteralPath (Join-Path $run 'Get-BudgetHistory.csv'))
                $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
                $summary = Get-Content -LiteralPath (Join-Path $run 'ScanSummary.txt') -Raw
                if ($ExpectError) {
                    $results['_error_Get-BudgetHistory'] | Should -Match 'budget inventory'
                    $csv.Status | Should -Be 'Error'
                    $html | Should -Match 'budget inventory'
                    $summary | Should -Match 'Budget History: ERROR:'
                }
                elseif ($HasBudgets) {
                    @($results['Get-BudgetHistory']).Count | Should -Be 6
                    @($results['Get-BudgetHistory'] | Where-Object { $_.ActualSpend -ne 12.5 }).Count | Should -Be 0
                    if ($Incomplete) {
                        $csv.CoverageIncomplete | Should -Contain 'True'
                        $csv.Note | Should -Contain $results['Get-BudgetHistory'][0].Note
                        $html | Should -Match 'Budget history covers only'
                        $summary | Should -Match 'Budget History: Limited data:'
                    }
                    else { $results['Get-BudgetHistory'].CoverageIncomplete | Should -Not -Contain $true }
                }
                else { $csv.Status | Should -Be 'No data'; $summary | Should -Match 'Budget History: No data' }
                Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
            }

            It 'Preserves a caught payload-scan error in every report format' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive 'failed-payload-scan'
                Mock Get-OrphanedResources { throw '403 AuthorizationFailed: orphan fixture.' }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-OrphanedResources -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results['_error_Get-OrphanedResources'] | Should -Be '403 AuthorizationFailed: orphan fixture.'
                @($results['Get-OrphanedResources']).Count | Should -Be 0
                $runs = @(Get-ChildItem -LiteralPath $reportRoot -Directory)
                $runs.Count | Should -Be 1
                $status = Import-Csv -LiteralPath (Join-Path $runs[0].FullName 'Get-OrphanedResources.csv')
                $status.RecordType | Should -Be 'Status'
                $status.Status | Should -Be 'Error'
                $status.Error | Should -Be '403 AuthorizationFailed: orphan fixture.'
                Get-Content -LiteralPath (Join-Path $runs[0].FullName 'FinOpsReport.html') -Raw | Should -Match '403 AuthorizationFailed: orphan fixture'
                Get-Content -LiteralPath (Join-Path $runs[0].FullName 'ScanSummary.txt') -Raw | Should -Match 'ERROR: 403 AuthorizationFailed: orphan fixture'
                Should -Invoke Read-Host -Times 0 -Exactly
            }

            It 'Reports an incomplete AI inventory as an error in every report format' {
                $env:FINOPS_HUB_KUSTO_URI = $null
                $reportRoot = Join-Path $TestDrive 'failed-ai-inventory'
                Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
                    if (-not $SkipToken) { return [pscustomobject]@{ Data = @('partial'); SkipToken = 'next'; Count = 1 } }
                    $null
                }

                Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-AIWorkloadMetrics -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

                $results = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $results['_error_Get-AIWorkloadMetrics'] | Should -Match 'AI workload inventory is incomplete'
                $runs = @(Get-ChildItem -LiteralPath $reportRoot -Directory)
                $runs.Count | Should -Be 1
                $status = Import-Csv -LiteralPath (Join-Path $runs[0].FullName 'Get-AIWorkloadMetrics.csv')
                $status.RecordType | Should -Be 'Status'
                $status.Status | Should -Be 'Error'
                $status.Error | Should -Match 'AI workload inventory is incomplete'
                $html = Get-Content -LiteralPath (Join-Path $runs[0].FullName 'FinOpsReport.html') -Raw
                $html | Should -Match 'AI workload inventory is incomplete'
                $html | Should -Not -Match 'No AI workloads detected'
                Get-Content -LiteralPath (Join-Path $runs[0].FullName 'ScanSummary.txt') -Raw | Should -Match 'ERROR: AI workload inventory is incomplete'
                Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times 0 -Exactly
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

                $runs = @(Get-ChildItem -LiteralPath $reportPath -Directory)
                $runs.Count | Should -Be 1
                $reportPath = $runs[0].FullName
                $result = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
                $result['_error_Get-CostData'] | Should -Match '403'
                $result['Get-CostData'] | Should -BeNullOrEmpty
                $html = Get-Content (Join-Path $reportPath 'FinOpsReport.html') -Raw
                $html | Should -Match ([regex]::Escape($ExpectedRole))
                $html | Should -Match 'Scans Run</div><div class="value">1</div>'
                $html | Should -Match 'Errors</div><div class="value severity-red">1</div>'
                Get-Content (Join-Path $reportPath 'ScanSummary.txt') -Raw | Should -Match 'ERROR:.*403'
                $csvFiles = @(Get-ChildItem -LiteralPath $reportPath -Filter '*.csv')
                $csvFiles.Count | Should -Be 1
                $status = Import-Csv -LiteralPath $csvFiles[0].FullName
                $status.Status | Should -Be 'Error'
                $status.Error | Should -Match '403'
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
                $set.ValidValues | Should -Be @('Hub', 'Export', 'API', 'GraphOnly')
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
