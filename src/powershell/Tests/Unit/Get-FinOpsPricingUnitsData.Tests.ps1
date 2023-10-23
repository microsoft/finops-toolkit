# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-FinOpsPricingUnitsData' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-FinOpsPricingUnitsData.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/PricingUnits.csv"

        # Act
        $cmd = Get-FinOpsPricingUnitsData

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
