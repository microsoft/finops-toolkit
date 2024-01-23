# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataPricingUnit' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataPricingUnit.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/PricingUnits.csv"

        # Act
        $cmd = Get-OpenDataPricingUnit

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
