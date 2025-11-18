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

        Describe 'Steps' {
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

        Describe 'Defaults' {
            It 'Should set default API version' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams
    
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Uri -match 'api-version=2025-03-01'
                }
            }

            It 'Should set default dataset to FocusCost' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams
    
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.definition.type -eq 'FocusCost'
                }
            }

            It 'Should set default to not use managed identity' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams
    
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $null -eq $Body.identity
                }
            }

            It 'Should set default state to active' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams
    
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.schedule.status -eq 'Active'
                }
            }

            Describe '<_.dataset> defaults' -ForEach @(
                @{ dataset = 'ActualCost'; version = '2021-10-01'; schedule = 'Daily' },
                @{ dataset = 'AmortizedCost'; version = '2021-10-01'; schedule = 'Daily' },
                @{ dataset = 'FocusCost'; version = '1.2-preview'; schedule = 'Daily' },
                @{ dataset = 'PriceSheet'; version = '2023-05-01'; schedule = 'Daily' },
                @{ dataset = 'ReservationDetails'; version = '2023-03-01'; schedule = 'Daily' },
                @{ dataset = 'ReservationRecommendations'; version = '2023-05-01'; schedule = 'Daily' },
                @{ dataset = 'ReservationTransactions'; version = '2023-05-01'; schedule = 'Daily' }
            ) {
                It 'Should set default <_.dataset> recurrence to <_.grain>' {
                    # Arrange
                    # Act
                    New-FinOpsCostExport @newExportParams -Dataset $_.dataset
    
                    # Assert
                    Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                        $Body.properties.definition.type -eq $_.dataset `
                            -and $Body.properties.schedule.recurrence -eq $_.schedule
                    }
                }

                It 'Should set default <_.dataset> version to <_.version>' {
                    # Arrange
                    # Act
                    New-FinOpsCostExport @newExportParams -Dataset $_.dataset
    
                    # Assert
                    Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                        $Body.properties.definition.type -eq $_.dataset `
                            -and $Body.properties.definition.dataSet.configuration.dataVersion -eq $_.version
                    }
                }
            }
        }

        Describe 'Options' {
            It 'Should set managed identity and default location' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams -SystemAssignedIdentity
    
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.identity.type -eq 'SystemAssigned' `
                        -and $Body.location -eq 'global'
                }
            }

            It 'Should set managed identity and explicit location' {
                # Arrange
                $location = 'eastus'
                
                # Act
                New-FinOpsCostExport @newExportParams -SystemAssignedIdentity -Location $location

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.identity.type -eq 'SystemAssigned' `
                        -and $Body.location -eq $location
                }
            }
        }

        Describe 'Format and compression' {
            It 'Should default to CSV format' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.format -eq 'Csv'
                }
            }

            It 'Should set explicit export format' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams -Format 'Parquet'

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.format -eq 'Parquet'
                }
            }

            It 'Should default to no compression' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.compressionMode -eq 'None'
                }
            }

            It 'Should set explicit compression mode' {
                # Arrange
                # Act
                New-FinOpsCostExport @newExportParams -CompressionMode 'Snappy'

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.compressionMode -eq 'Snappy'
                }
            }
        }

        Describe 'Storage Path Handling' {
            It 'Should use scope as default storage path without colons' {
                # Arrange
                $scopeWithColons = "/providers/Microsoft.Billing/billingAccounts/123:456"
                $paramsWithColons = @{
                    Name             = $exportName
                    Scope            = $scopeWithColons
                    StorageAccountId = "$scope/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"
                }
                
                # Act
                New-FinOpsCostExport @paramsWithColons
                
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.deliveryInfo.destination.rootFolderPath -eq ($scopeWithColons -replace ':','-')
                }
            }

            It 'Should not modify explicit storage path with colons' {
                # Arrange
                $scopeWithColons = "/providers/Microsoft.Billing/billingAccounts/123:456"
                $explicitPathWithColons = "my:custom:path"
                $paramsWithExplicitPath = @{
                    Name             = $exportName
                    Scope            = $scopeWithColons
                    StorageAccountId = "$scope/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"
                    StoragePath      = $explicitPathWithColons
                }
                
                # Act
                New-FinOpsCostExport @paramsWithExplicitPath
                
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.deliveryInfo.destination.rootFolderPath -eq $explicitPathWithColons
                }
            }

            It 'Should handle scope without colons normally' {
                # Arrange
                $scopeWithoutColons = "/subscriptions/12345678-1234-1234-1234-123456789012"
                $paramsWithoutColons = @{
                    Name             = $exportName
                    Scope            = $scopeWithoutColons
                    StorageAccountId = "$scope/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"
                }
                
                # Act
                New-FinOpsCostExport @paramsWithoutColons
                
                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Body.properties.deliveryInfo.destination.rootFolderPath -eq $scopeWithoutColons
                }
            }
        }
    }
}
