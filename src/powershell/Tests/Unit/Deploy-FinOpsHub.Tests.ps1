# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Deploy-FinOpsHub' {
        BeforeAll {
            function Get-AzResourceGroup {}
            function New-AzResourceGroup {}
            function New-AzResourceGroupDeployment {}

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $hubName = 'ftk-test-Deploy-FinOpsHub'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $rgName = 'ftk-test'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $location = 'eastus'
        }

        Context "WhatIf" {
            It 'Should run without error' {
                # Arrange
                Mock -CommandName 'Test-ShouldProcess' { return $false }
                Mock -CommandName 'Get-AzResourceGroup' { return $null }
                Mock -CommandName 'Initialize-FinOpsHubDeployment' { }

                # Act
                Deploy-FinOpsHub -WhatIf -Name $hubName -ResourceGroupName $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'Initialize-FinOpsHubDeployment' -Times 1 -ParameterFilter { $WhatIf -eq $true }
                @('CreateResourceGroup', 'CreateTempDirectory', 'DownloadTemplate', 'DeployFinOpsHub') | ForEach-Object {
                    Assert-MockCalled -CommandName 'Test-ShouldProcess' -Times 1 -ParameterFilter { $Action -eq $_ }
                }
            }
        }

        Context 'Resource groups' {
            It 'Should create RG if it does not exist' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $null }
                Mock -CommandName 'New-AzResourceGroup' -MockWith { }
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'CreateResourceGroup' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'Get-AzResourceGroup' -Times 1
                Assert-MockCalled -CommandName 'New-AzResourceGroup' -Times 1
            }

            It 'Should use RG if it exists' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'New-AzResourceGroup' -MockWith { }
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'CreateResourceGroup' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'Get-AzResourceGroup' -Times 1
                Assert-MockCalled -CommandName 'New-AzResourceGroup' -Times 0
            }
        }

        Context 'Initialize' {
            It 'Should call Initialize-FinOpsHubDeployment' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $false }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'Initialize-FinOpsHubDeployment' -Times 1
            }
        }

        Context 'Download template' {
            It 'Should save the template from GitHub' -Skip {
            }
            It 'Should clean up template after deployment' -Skip {
            }
        }

        Context 'Deploy' {
            It 'Should deploy the template' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'New-AzResourceGroupDeployment'
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'DeployFinOpsHub' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -Times 1
            }
            It 'Should add tags to the deployment' -Skip {
            }
            It 'Should deploy' -Skip {
            }
        }

        Context 'Old tests' {
            BeforeAll {
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return @{ ResourceGroupName = $rgName } }
                Mock -CommandName 'New-AzResourceGroup'
                Mock -CommandName 'Save-FinOpsHubTemplate'
            }

            It 'Should throw if template file is not found' {
                Mock -CommandName 'Get-ChildItem'
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Throw
                Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
            }

            Context 'More' {
                BeforeAll {
                    $templateFile = Join-Path -Path $env:temp -ChildPath 'FinOps\finops-hub-v1.0.0\main.bicep'
                    Mock -CommandName 'Get-ChildItem' -MockWith { return @{ FullName = $templateFile } }
                    Mock -CommandName 'New-AzResourceGroupDeployment'
                }

                It 'Should deploy the template without throwing' {
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Not -Throw
                    Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                    Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter { @{ TemplateFile = $templateFile } } -Times 1
                }

                It 'Should deploy the template with tags' {
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Tags @{ Test = 'Tag' } -Version 'latest' } | Should -Not -Throw
                    Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                    Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        @{
                            TemplateParameterObject = @{
                                tags = @{
                                    Test = 'Tag'
                                }
                            }
                        }
                    } -Times 1
                }

                It 'Should deploy the template with StorageSku' {
                    $storageSku = 'Premium_ZRS'
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -StorageSku $storageSku -Version 'latest' } | Should -Not -Throw
                    Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                    Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        @{
                            TemplateParameterObject = @{
                                storageSku = $storageSku
                            }
                        }
                    } -Times 1
                }
            }
        }
    }
}