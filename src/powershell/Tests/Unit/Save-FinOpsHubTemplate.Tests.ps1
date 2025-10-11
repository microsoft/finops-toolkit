# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope FinOpsToolkit {
    Describe 'Save-FinOpsHubTemplate' {
        BeforeAll {
            function mockVersionUrl($ver)
            {
                return "https://aka.ms/ftk/$ver.zip"
            }
            function mockVersion($ver)
            {
                @{
                    Version = $ver
                    Files   = @(@{ Name = "$ver.zip"; Url = (mockVersionUrl $ver) })
                }
            }
            function mockVersionList($versions)
            {
                @($versions | ForEach-Object { mockVersion $_ })
            }

            Mock -CommandName 'Expand-Archive'
            Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { mockVersion '1.0.0' }
            Mock -CommandName 'Invoke-WebRequest' -MockWith { Write-Host "Invoke-WebRequest $Uri" }
            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Remove-Item'
            Mock -CommandName 'Test-Path' { $false }
        }

        Context 'No releases found' {
            It 'Should stop processing if no assets found' {
                # Arrange
                Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { return @() }

                # Act
                Save-FinOpsHubTemplate

                # Assert
                Assert-MockCalled -CommandName 'Get-FinOpsToolkitVersion' -Times 1
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 0
            }
        }

        Context 'Releases found' {
            It 'Should download each asset found' {
                # Arrange
                Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith {
                    $val = mockVersionList '1.0.0'
                    Write-Host "Releases found / Should download each asset found / Get-FTKVersion / Mock value..."
                    Write-Host ($val | ConvertTo-Json -Depth 5)
                    return $val
                }
                Mock -CommandName 'Test-Path' -MockWith { return $true }

                # Act
                Save-FinOpsHubTemplate

                # Assert
                Assert-MockCalled -CommandName 'Get-FinOpsToolkitVersion' -Times 1
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }
        }

        Context 'Release filtering' {
            It 'Should only download version specified' {
                # Arrange
                $downloadVersion = '2.0.0'
                $downloadUrl = mockVersionUrl $downloadVersion
                Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { mockVersionList '1.0.0', $downloadVersion }

                # Act
                Save-FinOpsHubTemplate -Version $downloadVersion

                # Assert
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1 -ParameterFilter { $Uri -eq $downloadUrl }
                Assert-MockCalled -CommandName 'Expand-Archive' -Times 1
                Assert-MockCalled -CommandName 'Remove-Item' -Times 1
            }
        }

        Context 'Failures' {
            BeforeAll {
                Mock -CommandName 'Get-FinOpsToolKitVersion' -MockWith { throw 'failue' }
            }

            It 'Should throw' {
                { Save-FinOpsHubTemplate } | Should -Throw
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 0
            }
        }

        Context 'Version redirection' {
            It 'Should redirect 0.2 to 0.3' {
                # Arrange
                Mock -CommandName 'Get-AzContext' { @{ Environment = @{ Name = 'AzureCloud' } } }
                Mock -CommandName 'Get-FinOpsToolkitVersion' { mockVersionList '0.3', '0.2', '0.1.1' }

                # Act
                Save-FinOpsHubTemplate -Version '0.2'

                # Assert
                Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.3.zip') }
            }
    
            It 'Should not redirect 0.2 to 0.1.1 for Azure Gov' {
                # Arrange
                Mock -CommandName 'Get-AzContext' { @{ Environment = @{ Name = 'AzureGov' } } }
                Mock -CommandName 'Get-FinOpsToolkitVersion' { mockVersionList '0.3', '0.2', '0.1.1' }

                # Act
                Save-FinOpsHubTemplate -Version '0.3'

                # Assert
                Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.3.zip') }
            }

            It 'Should not redirect 0.2 to 0.1.1 for Azure China' {
                # Arrange
                Mock -CommandName 'Get-AzContext' { @{ Environment = @{ Name = 'AzureChina' } } }
                Mock -CommandName 'Get-FinOpsToolkitVersion' { mockVersionList '0.3', '0.2', '0.1.1' }

                # Act
                Save-FinOpsHubTemplate -Version '0.3'

                # Assert
                Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.3.zip') }
            }
    
            It 'Should support 0.3 for Azure Gov' {
                # Arrange
                Mock -CommandName 'Get-AzContext' { @{ Environment = @{ Name = 'AzureGov' } } }
                Mock -CommandName 'Get-FinOpsToolkitVersion' { mockVersionList '0.3', '0.2', '0.1.1' }

                # Act
                Save-FinOpsHubTemplate -Version '0.3'
    
                # Assert
                Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.3.zip') }
            }
    
            It 'Should support 0.3 for Azure China' {
                # Arrange
                Mock -CommandName 'Get-AzContext' { @{ Environment = @{ Name = 'AzureChina' } } }
                Mock -CommandName 'Get-FinOpsToolkitVersion' { mockVersionList '0.3', '0.2', '0.1.1' }

                # Act
                Save-FinOpsHubTemplate -Version '0.3'
    
                # Assert
                Assert-MockCalled -CommandName 'Test-Path' -Times 1 -ParameterFilter { $Path.EndsWith('0.3.zip') }
            }
        }
    }
}
