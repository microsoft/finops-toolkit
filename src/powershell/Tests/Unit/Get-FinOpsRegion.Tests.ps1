# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsRegion' {
        BeforeAll {
            function getAllRegions([string]$ResourceLocation = "*")
            {
                Get-OpenDataRegion `
                | Where-Object { $_.OriginalValue -like $ResourceLocation } `
                | Select-Object -Property RegionId, RegionName -Unique
            }
        }
        Context "No parameters" {
            BeforeAll {
                $actual = Get-FinOpsRegion
            }
            It 'Should return all regions by default' {
                # Arrange
                $expected = getAllRegions
            
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
                $expected = getAllRegions 'a*'
    
                # Act
                $actual = Get-FinOpsRegion -ResourceLocation a*
    
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return b* wildcard RegionId matches' {
                # Arrange
                $expected = getAllRegions | Where-Object { $_.RegionId -like 'b*' }
    
                # Act
                $actual = Get-FinOpsRegion -RegionId b*
    
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return c* wildcard RegionName matches' {
                # Arrange
                $expected = getAllRegions | Where-Object { $_.RegionName -like 'c*' }
    
                # Act
                $actual = Get-FinOpsRegion -RegionName c*
    
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
                $actual = Get-FinOpsRegion $expected -IncludeResourceLocation
    
                # Assert
                $actual.Count | Should -Be 1
                $actual.RegionId | Should -Be 'brazilsouth'
                $actual.RegionName | Should -Be 'Brazil South'
                $actual.ResourceLocation | Should -Be $expected
            }    
            It 'Should exclude ResourceLocation property when false' {
                # Arrange
                # Act
                $actual = Get-FinOpsRegion "br south" -IncludeResourceLocation:$false
    
                # Assert
                $actual.Count | Should -Be 1
                $actual.RegionId | Should -Be 'brazilsouth'
                $actual.RegionName | Should -Be 'Brazil South'
                $actual | Get-Member 'ResourceLocation' | Should -Be $null
            }
        }
    }
}
