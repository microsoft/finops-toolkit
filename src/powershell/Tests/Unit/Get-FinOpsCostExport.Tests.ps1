# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsCostExport' {
        BeforeAll {
            Mock -CommandName 'Get-AzContext' {
                @{
                    Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' }
                }
            }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $scope = "/subscriptions/00000000-0000-0000-0000-000000000000"
        }

        Context 'RunHistory' {
            It 'Should return run history when -RunHistory is specified' {
                # Arrange
                Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' {
                    @{
                        Success = $true
                        Content = @{
                            Value = @(
                                @{
                                    name  = 'test-export'
                                    id    = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/test-export'
                                    type  = 'Microsoft.CostManagement/exports'
                                    eTag  = 'etag123'
                                    properties = @{
                                        exportDescription = 'Test export'
                                        definition = @{
                                            type      = 'FocusCost'
                                            timeframe = 'MonthToDate'
                                            dataSet   = @{
                                                granularity   = 'Daily'
                                                configuration = @{
                                                    dataVersion = '1.0'
                                                    filter      = $null
                                                }
                                            }
                                            timePeriod = @{ from = $null; to = $null }
                                        }
                                        schedule = @{
                                            status           = 'Active'
                                            recurrence       = 'Daily'
                                            recurrencePeriod = @{ from = '2024-01-01'; to = '2025-01-01' }
                                        }
                                        nextRunTimeEstimate = '2024-06-01T00:00:00Z'
                                        format              = 'Csv'
                                        deliveryInfo = @{
                                            destination = @{
                                                resourceId     = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/sa'
                                                container      = 'exports'
                                                rootFolderPath = 'path'
                                            }
                                        }
                                        dataOverwriteBehavior = 'OverwritePreviousReport'
                                        partitionData         = $false
                                        compressionMode       = 'None'
                                        runHistory = @{
                                            value = @(
                                                @{
                                                    id   = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/test-export/runs/run1'
                                                    name = 'run1'
                                                    properties = @{
                                                        executionType       = 'OnDemand'
                                                        status              = 'Completed'
                                                        submittedBy         = 'user@example.com'
                                                        submittedTime       = '2024-05-01T10:00:00Z'
                                                        processingStartTime = '2024-05-01T10:01:00Z'
                                                        processingEndTime   = '2024-05-01T10:05:00Z'
                                                        fileName            = 'export.csv'
                                                        startDate           = '2024-04-01'
                                                        endDate             = '2024-04-30'
                                                        error               = @{ code = $null; message = $null }
                                                    }
                                                },
                                                @{
                                                    id   = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/test-export/runs/run2'
                                                    name = 'run2'
                                                    properties = @{
                                                        executionType       = 'Scheduled'
                                                        status              = 'Failed'
                                                        submittedBy         = 'system'
                                                        submittedTime       = '2024-05-02T00:00:00Z'
                                                        processingStartTime = '2024-05-02T00:01:00Z'
                                                        processingEndTime   = '2024-05-02T00:02:00Z'
                                                        fileName            = $null
                                                        startDate           = '2024-05-01'
                                                        endDate             = '2024-05-01'
                                                        error               = @{ code = 'BillingError'; message = 'Billing account not found' }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                }

                # Act
                $result = Get-FinOpsCostExport -Scope $scope -RunHistory

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result | Should -HaveCount 1

                # Validate run history is populated (regression test for $_ collision in nested ForEach-Object)
                $result.RunHistory | Should -Not -BeNullOrEmpty
                $result.RunHistory | Should -HaveCount 2

                # Validate first run
                $result.RunHistory[0].RunId | Should -Be 'run1'
                $result.RunHistory[0].ExecutionType | Should -Be 'OnDemand'
                $result.RunHistory[0].Status | Should -Be 'Completed'
                $result.RunHistory[0].SubmittedBy | Should -Be 'user@example.com'
                $result.RunHistory[0].SubmittedTime | Should -Be '2024-05-01T10:00:00Z'
                $result.RunHistory[0].RunStartTime | Should -Be '2024-05-01T10:01:00Z'
                $result.RunHistory[0].RunEndTime | Should -Be '2024-05-01T10:05:00Z'
                $result.RunHistory[0].FileName | Should -Be 'export.csv'
                $result.RunHistory[0].QueryStartDate | Should -Be '2024-04-01'
                $result.RunHistory[0].QueryEndDate | Should -Be '2024-04-30'

                # Validate second run (failed)
                $result.RunHistory[1].RunId | Should -Be 'run2'
                $result.RunHistory[1].Status | Should -Be 'Failed'
                $result.RunHistory[1].ErrorCode | Should -Be 'BillingError'
                $result.RunHistory[1].ErrorMessage | Should -Be 'Billing account not found'
            }

            It 'Should pass RunHistory expand parameter to API' {
                # Arrange
                Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' {
                    @{
                        Success = $true
                        Content = @{ Value = @() }
                    }
                }

                # Act
                Get-FinOpsCostExport -Scope $scope -RunHistory

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Uri -match '\$expand=runHistory'
                }
            }

            It 'Should not expand RunHistory when switch is not specified' {
                # Arrange
                Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' {
                    @{
                        Success = $true
                        Content = @{ Value = @() }
                    }
                }

                # Act
                Get-FinOpsCostExport -Scope $scope

                # Assert
                Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                    $Uri -notmatch '\$expand=runHistory'
                }
            }

            It 'Should handle empty run history' {
                # Arrange
                Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' {
                    @{
                        Success = $true
                        Content = @{
                            Value = @(
                                @{
                                    name  = 'no-history-export'
                                    id    = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/no-history-export'
                                    type  = 'Microsoft.CostManagement/exports'
                                    eTag  = 'etag456'
                                    properties = @{
                                        definition = @{
                                            type      = 'FocusCost'
                                            timeframe = 'MonthToDate'
                                            dataSet   = @{
                                                granularity   = 'Daily'
                                                configuration = @{ dataVersion = '1.0' }
                                            }
                                        }
                                        schedule = @{
                                            status           = 'Active'
                                            recurrence       = 'Daily'
                                            recurrencePeriod = @{}
                                        }
                                        deliveryInfo = @{
                                            destination = @{
                                                resourceId     = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/sa'
                                                container      = 'exports'
                                                rootFolderPath = 'path'
                                            }
                                        }
                                        runHistory = @{ value = @() }
                                    }
                                }
                            )
                        }
                    }
                }

                # Act
                $result = Get-FinOpsCostExport -Scope $scope -RunHistory

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.RunHistory | Should -HaveCount 0
            }
        }
    }
}
