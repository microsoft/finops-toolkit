# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Initialize-FinOpsHubsDeployment' {
    BeforeAll {
        $requiredRPs = @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
    }

    Context "WhatIf" {
        It 'Should pass the WhatIf parameter to Register-FinOpsHubProviders' {
            # Arrange
            Mock -CommandName 'Get-AzResourceProvider' { return @{ RegistrationState = 'NotRegistered' } }
            Mock -CommandName 'Write-Host'

            # Act
            Initialize-FinOpsHubsDeployment -WhatIf
            
            # Assert
            $requiredRPs | ForEach-Object {
                Assert-MockCalled -CommandName 'Write-Host' -Times 1 -ParameterFilter { $Object.StartsWith('What if: Performing the operation') -and $Object -match "Registering provider.*$_" }
            }
        }
    }

    Context "Register" {
        It 'Should call Register once' {
            # Arrange
            Mock -CommandName 'Register-FinOpsHubProviders'
                
            # Act
            Initialize-FinOpsHubsDeployment

            # Assert
            Assert-MockCalled -CommandName 'Register-FinOpsHubProviders' -Times 1
        }
    }
}
