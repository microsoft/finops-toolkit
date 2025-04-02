# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'New-FinOpsCostExport' {
        BeforeAll {
            Mock -CommandName 'Get-AzContext' { @{ } }
            Mock -CommandName 'Get-AzResourceProvider' { @{ RegistrationState = "Registered" } }
            Mock -CommandName 'Register-AzResourceProvider' { @{ RegistrationState = "Registered" } }
            Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { @{ name = $exportName; etag = "etag" } }
            Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
            Mock -ModuleName FinOpsToolkit -CommandName 'Start-FinOpsCostExport'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $exportName = 'ftk-test-New-FinOpsCostExport'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $scope = "/subscriptions/$([Guid]::NewGuid())"

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $mockExport = @{
                id   = "$scope/providers/Microsoft.CostManagement/exports/$exportName"
                name = $exportName
            }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $newExportParams = @{
                Name             = $exportName
                Scope            = $scope
                StorageAccountId = "$scope/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"
            }
        }

        It 'Should register RP if not registered' {
            # Arrange
            Mock -CommandName 'Get-AzResourceProvider' { @{ RegistrationState = "NotRegistered" } }

            # Act
            New-FinOpsCostExport @newExportParams

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1
            Assert-MockCalled -CommandName 'Register-AzResourceProvider' -Times 1
        }

        It 'Should create export' {
            # Arrange
            # Act
            New-FinOpsCostExport @newExportParams

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 2
            # TODO: Validate request body via parameter filter in Invoke-Rest call
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Start-FinOpsCostExport' -Times 0
        }

        It 'Should create and run scheduled export' {
            # Arrange
            # Act
            New-FinOpsCostExport @newExportParams -Execute

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 2
            # TODO: Validate request body via parameter filter in Invoke-Rest call
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Start-FinOpsCostExport' -Times 1
        }

        It 'Should create and backfill scheduled export' {
            # Arrange
            $backfillMonths = 3

            # Act
            New-FinOpsCostExport @newExportParams -Backfill $backfillMonths

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 2
            # TODO: Validate request body via parameter filter in Invoke-Rest call
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Start-FinOpsCostExport' -Times 1 -ParameterFilter { $Backfill -eq $backfillMonths }
        }

        It 'Should create and run one-time export' {
            # Arrange
            # Act
            New-FinOpsCostExport @newExportParams -OneTime

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 2
            # TODO: Validate request body via parameter filter in Invoke-Rest call
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Start-FinOpsCostExport' -Times 1
        }
    }
}
