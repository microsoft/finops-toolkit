# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsInstanceSizeFlexibility' {
        BeforeAll {
            $allRows = Get-OpenDataInstanceSizeFlexibility `
            | Select-Object -Property * -Unique
        }
        Context "No parameters" {
            It 'Should return all rows by default' {
                # Arrange
                $expected = $allRows

                # Act
                $actual = Get-FinOpsInstanceSizeFlexibility

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Wildcards" {
            It 'Should return ArmSkuName wildcard matches' {
                # Arrange
                $filter = 'Standard_D*'
                $expected = $allRows | Where-Object { $_.ArmSkuName -like $filter }

                # Act
                $actual = Get-FinOpsInstanceSizeFlexibility -ArmSkuName $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return InstanceSizeFlexibilityGroup wildcard matches' {
                # Arrange
                $filter = $allRows[0].InstanceSizeFlexibilityGroup
                $expected = $allRows | Where-Object { $_.InstanceSizeFlexibilityGroup -like $filter }

                # Act
                $actual = Get-FinOpsInstanceSizeFlexibility -InstanceSizeFlexibilityGroup $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Ratio" {
            It 'Should be a number (not a string)' {
                # Arrange
                # Act
                $actual = Get-FinOpsInstanceSizeFlexibility

                # Assert
                $actual[0].Ratio -is [string] | Should -BeFalse
            }
        }
    }
}
