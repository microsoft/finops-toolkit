# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'New-Directory' {
        BeforeAll {
            Mock -CommandName 'New-Item'
            $path = 'TestDrive:\FakeDirectory'
        }

        It 'Should not create a directory if it exists' {
            # Arrange
            Mock -CommandName 'Test-Path' -MockWith { return $true }

            # Act
            New-Directory -Path $path

            # Assert
            Should -Invoke -CommandName 'Test-Path'
            Should -Invoke -CommandName 'New-Item' -Times 0
        }

        It 'Should create a directory if it does not exist' {
            # Arrange
            Mock -CommandName 'Test-Path' -MockWith { return $false }

            # Act
            New-Directory -Path $path

            # Assert
            Should -Invoke -CommandName 'Test-Path'
            Should -Invoke -CommandName 'New-Item' -Times 1
        }
    }
}
