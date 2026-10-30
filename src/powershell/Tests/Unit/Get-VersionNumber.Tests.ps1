# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-VersionNumber' {
    It 'Should return the latest version' {
        # Arrange
        $expected = . "$PSScriptRoot/../../../scripts/Get-Version.ps1"
        . "$PSScriptRoot/../../Private/Get-VersionNumber.ps1"

        # Act
        $actual = Get-VersionNumber

        # Assert
        $actual | Should -Be $expected
    }
}
