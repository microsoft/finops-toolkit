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
