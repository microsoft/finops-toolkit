# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataInstanceSizeFlexibility' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataInstanceSizeFlexibility.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"

        # Act
        $cmd = Get-OpenDataInstanceSizeFlexibility

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
