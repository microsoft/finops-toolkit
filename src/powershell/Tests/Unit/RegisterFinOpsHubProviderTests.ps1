# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Register-FinOpsHubProviders" {
    Context "When the resource providers are not registered" {
        It "Should register the resource providers" {
            # Arrange
            $expectedOutput = "Registering resource provider Microsoft.EventGrid", "Registering resource provider Microsoft.CostManagementExports"
            $mockOutput = @()

            # Mock the Register-AzResourceProvider cmdlet to capture its output
            Mock Register-AzResourceProvider { $mockOutput += "Registering resource provider $($args[0].ProviderNamespace)" }

            # Act
            Register-FinOpsHubProviders

            # Assert
            $mockOutput | Should -Be $expectedOutput
        }
    }

    Context "When the resource providers are already registered" {
        It "Should not try to register again rather log a Verbose message saying it's already registered" {
            # Arrange
            $expectedOutput = "Resource provider Microsoft.EventGrid is already registered", "Resource provider Microsoft.CostManagementExports is already registered"
            $mockOutput = @()

            # Mock the Get-AzResourceProvider cmdlet to return registered providers
            Mock Get-AzResourceProvider { @{ RegistrationState = "Registered" } }

            # Act
            Register-FinOpsHubProviders

            # Assert
            $mockOutput | Should -Be $expectedOutput
        }
    }
}