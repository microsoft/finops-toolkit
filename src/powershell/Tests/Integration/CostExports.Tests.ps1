# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'CostExports' {
    It 'Create-Read-Update-Delete exports' -Skip {
        # TODO: Add integration tests after the New-FinOpsCostExport is in
    }

    It 'Should get all exports' {
        # Arrange
        # Act
        $result = Get-FinOpsCostExport

        # Assert
        $result.Count | Should -BeGreaterThan 0
    }
}
