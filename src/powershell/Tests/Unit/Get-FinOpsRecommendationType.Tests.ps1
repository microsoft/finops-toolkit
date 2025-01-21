# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsRecommendationType' {
        BeforeAll {
            function getAllRecommendationTypes([string]$Id = "*")
            {
                Get-OpenDataRecommendationType `
                | Where-Object { $_.RecommendationType -like $Id } `
                | Select-Object -Property * -Unique
            }
        }
        Context "No parameters" {
            BeforeAll {
                $actual = Get-FinOpsRecommendationType
            }
            It 'Should return all recommendation types by default' {
                # Arrange
                $expected = getAllRecommendationTypes

                # Act
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Wildcards" {
            It 'Should return wildcard Id matches' {
                # Arrange
                $expected = getAllRecommendationTypes 'a*'

                # Act
                $actual = Get-FinOpsRecommendationType -Id a*

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return wildcard ServiceName matches' {
                # Arrange
                $expected = getAllRecommendationTypes '*App*'

                # Act
                $actual = Get-FinOpsRecommendationType -ServiceName *App*

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return wildcard Key matches' {
                # Arrange
                $expected = getAllRecommendationTypes '*Upgrade*'

                # Act
                $actual = Get-FinOpsRecommendationType -Key *Upgrade*

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            #     -and (
            #         ($Cost -and $_.Category -eq 'Cost') `
            #         -or ($HighAvailability -and $_.Category -eq 'High Availability') `
            #         -or ($OperationalExcellence -and $_.Category -eq 'Operation Excellence') `
            #         -or ($Performance -and $_.Category -eq 'Performance')
            # )
            # -and (
            #         ($High -and $_.Impact -eq 'High') `
            #         -or ($Medium -and $_.Impact -eq 'Medium') `
            #         -or ($Low -and $_.Impact -eq 'Low')
            # )

        }
        Context "Category" {
            It 'Should include all recommendation types when no categories are set' {
                # Arrange
                $expected = getAllRecommendationTypes

                # Act
                $actual = Get-FinOpsRecommendationType

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should include all recommendation types when all categories are set' {
                # Arrange
                $expected = getAllRecommendationTypes
                
                # Act
                $actual = Get-FinOpsRecommendationType -Cost -HighAvailability -OperationalExcellence -Performance
                
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should include all recommendation types when all categories are false' {
                # Arrange
                $expected = getAllRecommendationTypes

                # Act
                $actual = Get-FinOpsRecommendationType -Cost $false -HighAvailability $false -OperationalExcellence $false -Performance $false

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should only include one category when set' {
                # Arrange
                $expected = getAllRecommendationTypes | Where-Object { $_.Category -eq 'Cost' }

                # Act
                $actual = Get-FinOpsRecommendationType -Cost $true

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
                ($actual | Where-Object { $_.Category -ne 'Cost' }).Count | Should -Be 0
            }
            It 'Should only include two recommendation types when set' {
                # Arrange
                $expected = getAllRecommendationTypes | Where-Object { $_.Category -eq 'Cost' -or $_.Category -eq 'Performance' }

                # Act
                $actual = Get-FinOpsRecommendationType -Cost $true -Performance $true

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
                ($actual | Where-Object { $_.Category -ne 'Cost' -and $_.Category -ne 'Performance' }).Count | Should -Be 0
            }
        }
        Context "Impact" {
            It 'Should include all recommendation types when no impacts are set' {
                # Arrange
                $expected = getAllRecommendationTypes

                # Act
                $actual = Get-FinOpsRecommendationType

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should include all recommendation types when all impacts are set' {
                # Arrange
                $expected = getAllRecommendationTypes
                
                # Act
                $actual = Get-FinOpsRecommendationType -High -Medium -Low
                
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should include all recommendation types when all impacts are false' {
                # Arrange
                $expected = getAllRecommendationTypes

                # Act
                $actual = Get-FinOpsRecommendationType -High $false -Medium $false -Low $false

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should only include one category when set' {
                # Arrange
                $expected = getAllRecommendationTypes | Where-Object { $_.Category -eq 'High' }

                # Act
                $actual = Get-FinOpsRecommendationType -High $true

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
                ($actual | Where-Object { $_.Category -ne 'High' }).Count | Should -Be 0
            }
            It 'Should only include two recommendation types when set' {
                # Arrange
                $expected = getAllRecommendationTypes | Where-Object { $_.Category -eq 'High' -or $_.Category -eq 'Low' }

                # Act
                $actual = Get-FinOpsRecommendationType -High $true -Low $true

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
                ($actual | Where-Object { $_.Category -ne 'High' -and $_.Category -ne 'Low' }).Count | Should -Be 0
            }
        }
    }
}
