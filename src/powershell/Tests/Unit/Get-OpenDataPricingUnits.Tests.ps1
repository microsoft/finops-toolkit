# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataPricingUnits' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataPricingUnits.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/PricingUnits.csv"

        # Act
        $cmd = Get-OpenDataPricingUnits

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
