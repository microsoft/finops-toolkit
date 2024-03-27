# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'New-ResourceGroup' {
        BeforeAll {
            function Get-AzResourceGroup {}
            function New-AzResourceGroup {}
            
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $rgName = 'ftk-test'
            
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $location = 'eastus'
            
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $tags = @{ Foo = 'Bar' }
        }

        Context "WhatIf" {
            It 'Should run without error' {
                # Arrange
                Mock -CommandName 'Test-ShouldProcess' { return $false }
                Mock -CommandName 'Get-AzResourceGroup' { return $null }

                # Act
                New-ResourceGroup -WhatIf -Name $rgName -Location $location -Tags $tags
            
                # Assert
                Assert-MockCalled -CommandName 'Get-AzResourceGroup' -Times 1
                Assert-MockCalled -CommandName 'Test-ShouldProcess' -Times 1 -ParameterFilter { $Action -eq 'CreateResourceGroup' }
            }
        }

        Context 'Resource groups' {
            It 'Should create RG if it does not exist' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $null }
                Mock -CommandName 'New-AzResourceGroup' -MockWith { }
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'CreateResourceGroup' }

                # Act
                New-ResourceGroup -Name $rgName -Location $location -Tags $tags

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
                New-ResourceGroup -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Assert-MockCalled -CommandName 'Get-AzResourceGroup' -Times 1
                Assert-MockCalled -CommandName 'New-AzResourceGroup' -Times 0
            }
        }
    }
}