# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsCommitmentDiscountEligibility' {
        BeforeAll {
            # MeterId is already unique per row in the source data, so no de-duplication is needed here.
            $allRows = Get-OpenDataCommitmentDiscountEligibility
        }
        Context "No parameters" {
            It 'Should return all rows by default' {
                # Arrange
                $expected = $allRows

                # Act
                $actual = Get-FinOpsCommitmentDiscountEligibility

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Wildcards" {
            It 'Should return MeterId wildcard matches' {
                # Arrange
                $filter = $allRows[0].MeterId
                $expected = $allRows | Where-Object { $_.MeterId -like $filter }

                # Act
                $actual = Get-FinOpsCommitmentDiscountEligibility -MeterId $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Eligibility filters" {
            It 'Should filter by SpendEligibility' {
                # Arrange
                $expected = $allRows | Where-Object { $_.x_CommitmentDiscountSpendEligibility -eq 'Eligible' }

                # Act
                $actual = Get-FinOpsCommitmentDiscountEligibility -SpendEligibility 'Eligible'

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should filter by UsageEligibility' {
                # Arrange
                $expected = $allRows | Where-Object { $_.x_CommitmentDiscountUsageEligibility -eq 'Eligible' }

                # Act
                $actual = Get-FinOpsCommitmentDiscountEligibility -UsageEligibility 'Eligible'

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
    }
}
