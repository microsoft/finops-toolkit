# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

Describe 'Get-FinOpsResourceType' {
    BeforeAll {
        . "$PSScriptRoot/../../Private/Get-OpenDataResourceTypes.ps1"
        function getAllResourceTypes([string]$ResourceType = "*")
        {
            Get-OpenDataResourceTypes `
            | Where-Object { $_.ResourceType -like $ResourceType } `
            | Select-Object -Property * -Unique
        }
    }
    Context "No parameters" {
        BeforeAll {
            $actual = Get-FinOpsResourceType
        }
        It 'Should return all resource types by default' {
            # Arrange
            $expected = getAllResourceTypes

            # Act
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
    }
    Context "Wildcards" {
        It 'Should return wildcard ResourceType matches' {
            # Arrange
            $expected = getAllResourceTypes 'a*'

            # Act
            $actual = Get-FinOpsResourceType -ResourceType a*

            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
    }
    Context "ExcludePreview" {
        It 'Should include all resource types when not set' {
            # Arrange
            $expected = getAllResourceTypes

            # Act
            $actual = Get-FinOpsResourceType

            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should exclude non-preview resource types when true' {
            # Arrange
            $expected = getAllResourceTypes | Where-Object { $_.IsPreview -eq $true }

            # Act
            $actual = Get-FinOpsResourceType -IsPreview $true

            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should exclude preview resource types when false' {
            # Arrange
            $expected = getAllResourceTypes | Where-Object { $_.IsPreview -ne $true }

            # Act
            $actual = Get-FinOpsResourceType -IsPreview $false

            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
    }
}
