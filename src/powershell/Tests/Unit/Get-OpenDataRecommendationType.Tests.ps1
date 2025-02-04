# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataRecommendationType' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataRecommendationType.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/RecommendationTypes.csv"

        # Act
        $cmd = Get-OpenDataRecommendationType

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
