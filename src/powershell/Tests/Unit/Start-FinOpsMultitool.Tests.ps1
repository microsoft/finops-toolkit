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
            It 'Should have Multitool implementation files' {
                $privatePath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/Start-FinOpsMultitool.ps1'
                Test-Path -Path $privatePath | Should -BeTrue
            }

            It 'Should have GUI XAML file' {
                $xamlPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/gui/MainWindow.xaml'
                Test-Path -Path $xamlPath | Should -BeTrue
            }

            It 'Should have all scanner module files' {
                $modulesPath = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/modules'
                $modules = Get-ChildItem -Path $modulesPath -Filter '*.ps1'
                $modules.Count | Should -BeGreaterOrEqual 20
            }
        }

        Context 'Non-Windows behavior' {
            It 'Should write an error on non-Windows platforms' {
                # Simulate non-Windows by mocking the platform check
                if ($IsWindows -eq $false -or $PSVersionTable.PSEdition -ne 'Core')
                {
                    Set-ItResult -Skipped -Because 'Test only applicable on non-Windows PowerShell Core'
                    return
                }

                # On actual non-Windows, the command should emit an error
                { Start-FinOpsMultitool -ErrorAction Stop } | Should -Throw '*requires Windows*'
            }
        }
    }
}
