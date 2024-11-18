# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-FinOpsRegionsData' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-FinOpsRegionsData.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Regions.csv"

        # Act
        $cmd = Get-FinOpsRegionsData

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
