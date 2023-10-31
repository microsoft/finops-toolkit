# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Register-FinOpsHubProviders' {
    BeforeAll {
        $requiredRPs = @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
    }

    Context "WhatIf" {
        It 'Should attempt to register all providers' {
            # Arrange
            Mock -CommandName 'Get-AzResourceProvider' { return @{ RegistrationState = 'NotRegistered' } }
            Mock -CommandName 'Write-Host'

            # Act
            Register-FinOpsHubProviders -WhatIf
            
            # Assert
            $requiredRPs | ForEach-Object {
                Assert-MockCalled -CommandName 'Write-Host' -Times 1 -ParameterFilter { $Object.StartsWith('What if: Performing the operation') -and $Object -match "Registering provider.*$_" }
            }
        }
    }

    Context "Register" {
        It 'Should <call> Register when <state>' -ForEach @(
            @{ call = 'call'; state = 'NotRegistered' }
            @{ call = 'not call'; state = 'Registered' }
        ) {
            # Arrange
            Mock -CommandName 'Get-AzResourceProvider' { return @{ RegistrationState = $state } }
            Mock -CommandName 'Register-AzResourceProvider'
                
            # Act
            Register-FinOpsHubProviders

            # Assert
            Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times $requiredRPs.Count
            Assert-MockCalled -CommandName 'Register-AzResourceProvider' -Times ($state -eq 'Registered' ? 0 : $requiredRPs.Count)
        }
    }
}
