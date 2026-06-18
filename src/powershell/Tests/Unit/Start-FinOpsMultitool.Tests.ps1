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
                $modules.Count | Should -BeGreaterOrEqual 20
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
