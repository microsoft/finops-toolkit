# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-OpenDataCommitmentDiscountEligibility' {
    It 'Should return same rows as the CSV file' {
        # Arrange
        . "$PSScriptRoot/../../Private/Get-OpenDataCommitmentDiscountEligibility.ps1"
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/CommitmentDiscountEligibility.csv"

        # Act
        $cmd = Get-OpenDataCommitmentDiscountEligibility

        # Assert
        $cmd.Count | Should -Be $csv.Count
    }
}
