# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataRegion' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataRegion.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Regions.csv"

        # Act
        $cmd = Get-OpenDataRegion

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
