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
        }
    }
}
