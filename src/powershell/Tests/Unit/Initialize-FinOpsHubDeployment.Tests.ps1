# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope FinOpsToolkit {
    Describe 'Initialize-FinOpsHubDeployment' {
        BeforeAll {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $requiredRPs = @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
        }

        Context "Register" {
            It 'Should call Register once' {
                # Arrange
                Mock -CommandName 'Register-FinOpsHubProviders'

                # Act
                Initialize-FinOpsHubDeployment

                # Assert
                Assert-MockCalled -CommandName 'Register-FinOpsHubProviders' -Times 1
            }
        }
    }
}
