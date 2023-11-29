# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataService' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataService.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Services.csv"

        # Act
        $cmd = Get-OpenDataService

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
