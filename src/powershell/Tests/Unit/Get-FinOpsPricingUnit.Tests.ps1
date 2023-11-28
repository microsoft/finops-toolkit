# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsPricingUnit' {
        BeforeAll {
            $allPricingUnits = Get-OpenDataPricingUnit `
            | Select-Object -Property * -Unique
        }
        Context "No parameters" {
            BeforeAll {
                $actual = Get-FinOpsPricingUnit
            }
            It 'Should return all pricing units by default' {
                # Arrange
                $expected = $allPricingUnits
            
                # Act
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Wildcards" {
            It 'Should return *Hours wildcard UnitOfMeasure matches' {
                # Arrange
                $filter = '*Hours'
                $expected = $allPricingUnits | Where-Object { $_.UnitOfMeasure -like $filter }
    
                # Act
                $actual = Get-FinOpsPricingUnit -UnitOfMeasure $filter
    
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return */Month wildcard DistinctUnits matches' {
                # Arrange
                $filter = '*/Month'
                $expected = $allPricingUnits | Where-Object { $_.DistinctUnits -like $filter }
    
                # Act
                $actual = Get-FinOpsPricingUnit -DistinctUnits $filter
    
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "BlockSize" {
            It 'Should be a number (not a string)' {
                # Arrange
                # Act
                $actual = Get-FinOpsPricingUnit -BlockSize 500
    
                # Assert
                $actual[0].PricingBlockSize -is [string] | Should -BeFalse
                $actual[0].PricingBlockSize -is [int] -or $actual[0].PricingBlockSize -is [double] | Should -BeTrue
            }    
            It 'Should be the same as the filter' {
                # Arrange
                $expected = 500
    
                # Act
                $actual = Get-FinOpsPricingUnit -BlockSize $expected
    
                # Assert
                $actual[0].PricingBlockSize | Should -Be $expected
            }
        }
    }
}
