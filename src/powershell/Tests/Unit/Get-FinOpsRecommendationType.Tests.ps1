# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsRecommendationType' {
        BeforeAll {
            function getAllRecommendationTypes(
                [string]$RecommendationTypeId = "*",
                [string]$Category = "*",
                [string]$Impact = "*",
                [string]$ServiceName = "*",
                [string]$ResourceType = "*"
            )
            {
                Get-OpenDataRecommendationType `
                | Where-Object {
                    $_.RecommendationTypeId -like $RecommendationTypeId `
                        -and $_.Category -like $Category `
                        -and $_.Impact -like $Impact `
                        -and $_.ServiceName -like $ServiceName `
                        -and $_.ResourceType -like $ResourceType
                } `
                | Select-Object -Property RecommendationTypeId, Category, Impact, ServiceName, ResourceType, DisplayName, LearnMoreLink -Unique
            }
        }
        Context "No parameters" {
            BeforeAll {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
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
            It 'Should return Cost category matches' {
                # Arrange
                $filter = 'Cost'
                $expected = getAllRecommendationTypes -Category $filter

                # Act
                $actual = Get-FinOpsRecommendationType -Category $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return High impact matches' {
                # Arrange
                $filter = 'High'
                $expected = getAllRecommendationTypes -Impact $filter

                # Act
                $actual = Get-FinOpsRecommendationType -Impact $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return Virtual* wildcard ServiceName matches' {
                # Arrange
                $filter = 'Virtual*'
                $expected = getAllRecommendationTypes -ServiceName $filter

                # Act
                $actual = Get-FinOpsRecommendationType -ServiceName $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return *virtualmachines wildcard ResourceType matches' {
                # Arrange
                $filter = '*virtualmachines'
                $expected = getAllRecommendationTypes -ResourceType $filter

                # Act
                $actual = Get-FinOpsRecommendationType -ResourceType $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Specific recommendations" {
            It 'Should return a specific recommendation by ID' {
                # Arrange
                $id = 'a06456ed-afb7-4d16-86fd-0054e25268ed'
                $expected = getAllRecommendationTypes -RecommendationTypeId $id

                # Act
                $actual = Get-FinOpsRecommendationType -RecommendationTypeId $id

                # Assert
                $expected.Count | Should -Be 1
                $actual.Count | Should -Be $expected.Count
                $actual[0].RecommendationTypeId | Should -Be $id
            }
        }
    }
}
