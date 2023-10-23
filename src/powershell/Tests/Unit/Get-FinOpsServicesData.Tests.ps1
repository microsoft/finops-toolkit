# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-FinOpsServicesData' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-FinOpsServicesData.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Services.csv"

        # Act
        $cmd = Get-FinOpsServicesData

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
