# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'New-Directory' {
        It 'Should create a directory' {
            # Arrange
            $path = Join-Path ([System.IO.Path]::GetTempPath()) 'ftk-test/New-Directory'
            if (Test-Path $path)
            {
                Remove-Item -Path $path -Recurse -Force
            }

            # Act
            New-Directory -Path $path

            # Assert
            Test-Path $path | Should -Be $true

            # Cleanup
            Remove-Item -Path $path -Recurse -Force
        }
    }
}
