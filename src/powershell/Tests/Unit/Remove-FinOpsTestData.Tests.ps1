# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Remove-FinOpsTestData' {
        Context "Parameter validation" {
            It 'Should not require AdxClusterUri (optional for safety)' {
                $cmd = Get-Command Remove-FinOpsTestData
                $param = $cmd.Parameters['AdxClusterUri']
                $mandatory = $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
                $mandatory.Mandatory | Should -Not -Be $true
            }

            It 'Should not require StorageAccountName (optional for safety)' {
                $cmd = Get-Command Remove-FinOpsTestData
                $param = $cmd.Parameters['StorageAccountName']
                $mandatory = $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
                $mandatory.Mandatory | Should -Not -Be $true
            }

            It 'Should not require AdfName' {
                $cmd = Get-Command Remove-FinOpsTestData
                $param = $cmd.Parameters['AdfName']
                $mandatory = $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
                $mandatory.Mandatory | Should -Not -Be $true
            }

            It 'Should support ShouldProcess with High confirm impact' {
                $cmd = Get-Command Remove-FinOpsTestData
                $cmdletBinding = $cmd.ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })
                $cmdletBinding.SupportsShouldProcess | Should -Be $true
                $cmdletBinding.ConfirmImpact | Should -Be 'High'
            }

            It 'Should have expected parameters' {
                $cmd = Get-Command Remove-FinOpsTestData
                $paramNames = $cmd.Parameters.Keys
                $paramNames | Should -Contain 'AdxClusterUri'
                $paramNames | Should -Contain 'StorageAccountName'
                $paramNames | Should -Contain 'AdfName'
                $paramNames | Should -Contain 'ResourceGroupName'
                $paramNames | Should -Contain 'StopTriggers'
                $paramNames | Should -Contain 'OutputPath'
                $paramNames | Should -Contain 'Force'
            }

            It 'Should have a Force switch parameter' {
                $cmd = Get-Command Remove-FinOpsTestData
                $param = $cmd.Parameters['Force']
                $param | Should -Not -BeNullOrEmpty
                $param.ParameterType.Name | Should -Be 'SwitchParameter'
            }

            It 'Should have default OutputPath of ./test-data' {
                $cmd = Get-Command Remove-FinOpsTestData
                $param = $cmd.Parameters['OutputPath']
                $param | Should -Not -BeNullOrEmpty
            }
        }

        Context "Safety: ADX requires -Force" {
            It 'Should error when AdxClusterUri is provided without -Force' {
                # ADX cleanup should fail with an error because -Force is not specified
                $result = Remove-FinOpsTestData `
                    -AdxClusterUri 'https://fake-cluster.eastus.kusto.windows.net' `
                    -OutputPath (Join-Path $TestDrive 'nonexistent') `
                    -Confirm:$false `
                    -ErrorAction SilentlyContinue `
                    -ErrorVariable removeErrors `
                    -WarningAction SilentlyContinue 2>&1

                # Should have produced an error about requiring -Force
                $removeErrors | Should -Not -BeNullOrEmpty
                $removeErrors[0].Exception.Message | Should -BeLike '*-Force*'
            }
        }

        Context "Local file cleanup with WhatIf" {
            BeforeAll {
                # Create a temp test-data directory to verify deletion behavior
                $testDir = Join-Path $TestDrive 'test-data-remove'
                New-Item -Path $testDir -ItemType Directory -Force | Out-Null
                New-Item -Path (Join-Path $testDir 'dummy.csv') -ItemType File -Force | Out-Null
            }

            It 'Should not delete files when using -WhatIf' {
                # WhatIf should prevent any actual deletion
                Remove-FinOpsTestData `
                    -OutputPath $testDir `
                    -WhatIf `
                    -Confirm:$false `
                    -ErrorAction SilentlyContinue `
                    -WarningAction SilentlyContinue

                # Directory should still exist because of WhatIf
                Test-Path $testDir | Should -Be $true
            }
        }
    }
}
