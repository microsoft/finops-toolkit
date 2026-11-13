# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsService' {
        BeforeAll {
            function getAllServices([string]$ConsumedService = "*", [string]$ResourceType = "*")
            {
                Get-OpenDataService `
                | Where-Object { $_.ConsumedService -like $ConsumedService -and $_.ResourceType -like $ResourceType } `
                | Select-Object -Property Environment, ServiceModel, ServiceCategory, ServiceName, PublisherName, PublisherType -Unique
            }
        }
        Context "No parameters" {
            BeforeAll {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
                $actual = Get-FinOpsService
            }
            It 'Should return all services by default' {
                # Arrange
                $expected = getAllServices

                # Act
                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "Wildcards" {
            It 'Should return Microsoft.A* wildcard ConsumedService matches' {
                # Arrange
                $filter = 'Microsoft.A*'
                $expected = getAllServices -ConsumedService $filter

                # Act
                $actual = Get-FinOpsService -ConsumedService $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return *network* wildcard ResourceType matches' {
                # Arrange
                $filter = '*network*'
                $expected = getAllServices -ResourceType $filter

                # Act
                $actual = Get-FinOpsService -ResourceType $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return H* wildcard Environment matches' {
                # Arrange
                $filter = 'H*'
                $expected = getAllServices | Where-Object { $_.Environment -like $filter }

                # Act
                $actual = Get-FinOpsService -Environment $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return P* wildcard ServiceModel matches' {
                # Arrange
                $filter = 'P*'
                $expected = getAllServices | Where-Object { $_.ServiceModel -like $filter }

                # Act
                $actual = Get-FinOpsService -ServiceModel $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return C* wildcard ServiceCategory matches' {
                # Arrange
                $filter = 'C*'
                $expected = getAllServices | Where-Object { $_.ServiceCategory -like $filter }

                # Act
                $actual = Get-FinOpsService -ServiceCategory $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return D* wildcard ServiceName matches' {
                # Arrange
                $filter = 'D*'
                $expected = getAllServices | Where-Object { $_.ServiceName -like $filter }

                # Act
                $actual = Get-FinOpsService -ServiceName $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return C* wildcard PublisherCategory matches' {
                # Arrange
                $filter = 'C*'
                $expected = getAllServices | Where-Object { $_.PublisherType -like $filter }

                # Act
                $actual = Get-FinOpsService -PublisherCategory $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
            It 'Should return M* wildcard PublisherName matches' {
                # Arrange
                $filter = 'M*'
                $expected = getAllServices | Where-Object { $_.PublisherName -like $filter }

                # Act
                $actual = Get-FinOpsService -PublisherName $filter

                # Assert
                $expected.Count | Should -BeGreaterThan 0
                $actual.Count | Should -Be $expected.Count
            }
        }
        Context "ResourceId" {
            It 'Should get a resource type from a resource ID' {
                # Arrange
                $type = 'Microsoft.Storage/storageAccounts'
                $expected = "Storage Accounts"

                # Act
                $actual = Get-FinOpsService -ResourceId "/subscriptions/$([guid]::NewGuid())/providers/$type/foo"

                # Assert
                $actual.Count | Should -BeGreaterThan 0
                $actual[0].ServiceName | Should -Be $expected
            }
        }
    }
}