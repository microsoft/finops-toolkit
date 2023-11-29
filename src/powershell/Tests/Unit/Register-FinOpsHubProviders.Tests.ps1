# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Register-FinOpsHubProviders' {
        BeforeAll {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $requiredRPs = @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
        }

        Context "WhatIf" {
            It 'Should attempt to register all providers' {
                # Arrange
                Mock -CommandName 'Get-AzResourceProvider' { return @{ RegistrationState = 'NotRegistered' } }
                Mock -CommandName 'Register-AzResourceProvider'

                # Act
                Register-FinOpsHubProviders -WhatIf -Verbose
            
                # Assert
                $requiredRPs | ForEach-Object {
                    Assert-MockCalled -CommandName 'Get-AzResourceProvider' -Times 1 -ParameterFilter { $ProviderNamespace -eq $_ }
                    Assert-MockCalled -CommandName 'Register-AzResourceProvider' -Times 1 -ParameterFilter { $ProviderNamespace -eq $_ -and $WhatIf -eq $true }
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
}
