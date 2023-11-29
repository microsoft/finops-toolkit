# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataResourceTypes' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataResourceTypes.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/ResourceTypes.csv"

        # Act
        $cmd = Get-OpenDataResourceTypes

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
