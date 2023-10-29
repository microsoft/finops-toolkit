# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataRegions' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataRegions.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Regions.csv"

        # Act
        $cmd = Get-OpenDataRegions

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
