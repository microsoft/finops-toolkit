# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

Describe 'Get-FinOpsSchemaPricingUnit' {
    BeforeAll {
        . "$PSScriptRoot/../../Private/Get-OpenDataPricingUnits.ps1"
        $allPricingUnits = Get-OpenDataPricingUnits
    }
    Context "No parameters" {
        BeforeAll {
            $actual = Get-FinOpsSchemaPricingUnit
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
            $actual = Get-FinOpsSchemaPricingUnit -UnitOfMeasure $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return */Month wildcard DistinctUnits matches' {
            # Arrange
            $filter = '*/Month'
            $expected = $allPricingUnits | Where-Object { $_.DistinctUnits -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaPricingUnit -DistinctUnits $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
    }
    Context "BlockSize" {
        It 'Should be a number (not a string)' {
            # Arrange
            # Act
            $actual = Get-FinOpsSchemaPricingUnit -BlockSize 500
    
            # Assert
            $actual[0].PricingBlockSize -is [string] | Should -BeFalse
            $actual[0].PricingBlockSize -is [int] -or $actual[0].PricingBlockSize -is [double] | Should -BeTrue
        }    
        It 'Should be the same as the filter' {
            # Arrange
            $expected = 500
    
            # Act
            $actual = Get-FinOpsSchemaPricingUnit -BlockSize $expected
    
            # Assert
            $actual[0].PricingBlockSize | Should -Be $expected
        }
    }
}
