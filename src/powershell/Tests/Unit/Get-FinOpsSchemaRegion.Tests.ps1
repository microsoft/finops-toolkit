# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

Describe 'Get-FinOpsSchemaRegion' {
    BeforeAll {
        . "$PSScriptRoot/../../Private/Get-OpenDataRegions.ps1"
        $allRegions = Get-OpenDataRegions
    }
    Context "No parameters" {
        BeforeAll {
            $actual = Get-FinOpsSchemaRegion
        }
        It 'Should return all regions by default' {
            # Arrange
            $expected = $allRegions
            
            # Act
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return only RegionId and RegionName properties' {
            # Arrange
            $expected = @('RegionId', 'RegionName')

            # Act
            $actual = $actual[0] `
            | Get-Member -MemberType NoteProperty `
            | ForEach-Object { $_.Name }

            # Assert
            $actual | Should -Be $expected
        }
    }
    Context "Wildcards" {
        It 'Should return wildcard ResourceLocation matches' {
            # Arrange
            $expected = $allRegions | Where-Object { $_.Originalvalue -like 'a*' }
    
            # Act
            $actual = Get-FinOpsSchemaRegion -ResourceLocation a*
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return b* wildcard RegionId matches' {
            # Arrange
            $expected = $allRegions | Where-Object { $_.RegionId -like 'b*' }
    
            # Act
            $actual = Get-FinOpsSchemaRegion -RegionId b*
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return c* wildcard RegionName matches' {
            # Arrange
            $expected = $allRegions | Where-Object { $_.RegionName -like 'c*' }
    
            # Act
            $actual = Get-FinOpsSchemaRegion -RegionName c*
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
    }
    Context "IncludeResourceLocation" {
        It 'Should include ResourceLocation property when true' {
            # Arrange
            $expected = "BR South"

            # Act
            $actual = Get-FinOpsSchemaRegion $expected -IncludeResourceLocation
    
            # Assert
            $actual.Count | Should -Be 1
            $actual.RegionId | Should -Be 'brazilsouth'
            $actual.RegionName | Should -Be 'Brazil South'
            $actual.ResourceLocation | Should -Be $expected
        }    
        It 'Should exclude ResourceLocation property when false' {
            # Arrange
            # Act
            $actual = Get-FinOpsSchemaRegion "br south" -IncludeResourceLocation:$false
    
            # Assert
            $actual.Count | Should -Be 1
            $actual.RegionId | Should -Be 'brazilsouth'
            $actual.RegionName | Should -Be 'Brazil South'
            $actual | Get-Member 'ResourceLocation' | Should -Be $null
        }
    }
}
