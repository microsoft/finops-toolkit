# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope FinOpsToolkit {
    Describe 'Save-FinOpsHubTemplate' {
        BeforeAll {
            function mockVersion($ver)
            {
                @{
                    Version = $ver
                    Files   = @(@{ Name = "$ver.txt"; Url = "about:blank" })
                }
            }
        }

        # TODO: Add more Save-FinOpsHubTemplate tests
        It 'Should get the latest version' -Skip {}
        It 'Should get a specific version' -Skip {}
        It 'Should save files' -Skip {}

        It 'Should redirect 0.2 to 0.2.1' {
            # Arrange
            Mock -CommandName 'Get-AzContext' { @{ Environment = 'AzureCloud' } }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Get-FinOpsToolkitVersion' { @((mockVersion '0.2.1'), (mockVersion '0.2'), (mockVersion '0.1.1')) }
            Mock -CommandName 'Test-Path' { $false }
            Mock -CommandName 'Invoke-WebRequest'

            # Act
            Save-FinOpsHubTemplate -Version '0.2'

            # Assert
            Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.2.1.txt') }
        }

        It 'Should redirect 0.2 to 0.1.1 for Azure Gov' {
            # Arrange
            Mock -CommandName 'Get-AzContext' { @{ Environment = 'AzureGov' } }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Get-FinOpsToolkitVersion' { @((mockVersion '0.2.1'), (mockVersion '0.2'), (mockVersion '0.1.1')) }
            Mock -CommandName 'Test-Path' { $false }
            Mock -CommandName 'Invoke-WebRequest'

            # Act
            Save-FinOpsHubTemplate -Version '0.2.1'

            # Assert
            Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.1.1.txt') }
        }

        It 'Should redirect 0.2 to 0.1.1 for Azure China' {
            # Arrange
            Mock -CommandName 'Get-AzContext' { @{ Environment = 'AzureChina' } }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Get-FinOpsToolkitVersion' { @((mockVersion '0.2.1'), (mockVersion '0.2'), (mockVersion '0.1.1')) }
            Mock -CommandName 'Test-Path' { $false }
            Mock -CommandName 'Invoke-WebRequest'

            # Act
            Save-FinOpsHubTemplate -Version '0.2.1'

            # Assert
            Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.1.1.txt') }
        }

        It 'Should support 0.1.1 for Azure Gov' {
            # Arrange
            Mock -CommandName 'Get-AzContext' { @{ Environment = 'AzureGov' } }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Get-FinOpsToolkitVersion' { @((mockVersion '0.2.1'), (mockVersion '0.2'), (mockVersion '0.1.1')) }
            Mock -CommandName 'Test-Path' { $false }
            Mock -CommandName 'Invoke-WebRequest'

            # Act
            Save-FinOpsHubTemplate -Version '0.1.1'

            # Assert
            Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.1.1.txt') }
        }

        It 'Should support 0.1.1 for Azure China' {
            # Arrange
            Mock -CommandName 'Get-AzContext' { @{ Environment = 'AzureChina' } }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Get-FinOpsToolkitVersion' { @((mockVersion '0.2.1'), (mockVersion '0.2'), (mockVersion '0.1.1')) }
            Mock -CommandName 'Test-Path' { $false }
            Mock -CommandName 'Invoke-WebRequest'

            # Act
            Save-FinOpsHubTemplate -Version '0.1.1'

            # Assert
            Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.1.1.txt') }
        }
    }
}
