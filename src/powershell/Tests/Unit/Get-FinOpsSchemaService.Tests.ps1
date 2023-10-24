# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

Describe 'Get-FinOpsSchemaService' {
    BeforeAll {
        . "$PSScriptRoot/../../Private/Get-OpenDataServices.ps1"
        $allServices = Get-OpenDataServices
    }
    Context "No parameters" {
        BeforeAll {
            $actual = Get-FinOpsSchemaService
        }
        It 'Should return all services by default' {
            # Arrange
            $expected = $allServices
            
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
            $expected = $allServices | Where-Object { $_.ConsumedService -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -ConsumedService $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return *network* wildcard ResourceType matches' {
            # Arrange
            $filter = '*network*'
            $expected = $allServices | Where-Object { $_.ResourceType -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -ResourceType $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return C* wildcard ServiceCategory matches' {
            # Arrange
            $filter = 'C*'
            $expected = $allServices | Where-Object { $_.ServiceCategory -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -ServiceCategory $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return D* wildcard ServiceName matches' {
            # Arrange
            $filter = 'D*'
            $expected = $allServices | Where-Object { $_.ServiceName -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -ServiceName $filter
        
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return C* wildcard PublisherCategory matches' {
            # Arrange
            $filter = 'C*'
            $expected = $allServices | Where-Object { $_.PublisherType -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -PublisherCategory $filter
    
            # Assert
            $expected.Count | Should -BeGreaterThan 0
            $actual.Count | Should -Be $expected.Count
        }
        It 'Should return M* wildcard PublisherName matches' {
            # Arrange
            $filter = 'M*'
            $expected = $allServices | Where-Object { $_.PublisherName -like $filter }
    
            # Act
            $actual = Get-FinOpsSchemaService -PublisherName $filter
        
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
            $actual = Get-FinOpsSchemaService -ResourceId "/subscriptions/$([guid]::NewGuid())/providers/$type/foo"
    
            # Assert
            $actual.Count | Should -BeGreaterThan 0
            $actual[0].ServiceName | Should -Be $expected
        }
    }
}
