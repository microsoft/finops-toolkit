# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataResourceType' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataResourceType.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/ResourceTypes.csv"

        # Act
        $cmd = Get-OpenDataResourceType

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
