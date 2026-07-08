# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Initialize-FinOpsHubLocal' {
        BeforeAll {
            function newQueryResult
            {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [int]
                    $Count
                )

                # Shape matches the real Kusto REST response the function reads:
                # (Invoke-FinOpsHubLocalCommand ...).Tables[0].Rows[0][0]
                return @{ Tables = @(@{ Rows = @(, @($Count)) }) }
            }

            $clusterUri = 'http://localhost:8082'
            $destination = 'TestDrive:\hub-local'

            Mock -CommandName 'New-Directory'
            Mock -CommandName 'Start-Sleep'
            Mock -CommandName 'Invoke-WebRequest'
            Mock -CommandName 'Get-Content' -MockWith {
                if ($Path -like '*opendata*')
                {
                    return 'opendata script $$openDataPath$$'
                }
                elseif ($Path -like '*Hub.kql')
                {
                    return 'hub script content'
                }

                return 'ingestion script $$rawRetentionInDays$$ days'
            }

            # Default: every command call succeeds with an empty response.
            Mock -CommandName 'Invoke-FinOpsHubLocalCommand' -MockWith { return @{} }

            # Every open data table count check reports rows present (no retry needed).
            Mock -CommandName 'Invoke-FinOpsHubLocalCommand' -ParameterFilter { $Endpoint -eq 'query' } -MockWith {
                return (newQueryResult -Count 5)
            }
        }

        Context 'Happy path' {
            It 'Should verify reachability, then create the Ingestion and Hub databases' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'NetDefaultDB' -and $Command -eq '.show version'
                }
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'NetDefaultDB' -and $Command -like '*create database Ingestion*'
                }
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'NetDefaultDB' -and $Command -like '*create database Hub*'
                }
            }

            It 'Should apply the Ingestion and Hub setup scripts' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'Ingestion' -and $Command -like '*ingestion script*'
                }
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'Hub' -and $Command -eq 'hub script content'
                }
            }

            It 'Should download the ingestion, hub, and open data setup scripts' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 3
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 1 -ParameterFilter { $Uri -like '*finops-hub-fabric-setup-Ingestion.kql' }
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 1 -ParameterFilter { $Uri -like '*finops-hub-fabric-setup-Hub.kql' }
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 1 -ParameterFilter { $Uri -like '*finops-hub-local-opendata.kql' }
            }

            It 'Should replace the raw retention placeholder before applying the Ingestion setup script' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -RawRetentionInDays 30 -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'Ingestion' -and $Command -eq 'ingestion script 30 days'
                }
            }

            It 'Should replace the open data path placeholder before loading open data' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -OpenDataPath '/custom/path' -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter {
                    $Database -eq 'Ingestion' -and $Command -eq 'opendata script /custom/path'
                }
            }

            It 'Should thread the requested timeout through every emulator request and download' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -TimeoutSec 45 -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 0 -ParameterFilter { $TimeoutSec -ne 45 }
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 0 -ParameterFilter { $TimeoutSec -ne 45 }
            }

            It 'Should skip downloading and loading open data when requested' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -SkipOpenData -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 0 -ParameterFilter { $Uri -like '*opendata*' }
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 0 -ParameterFilter { $Endpoint -eq 'query' }
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 0 -ParameterFilter { $Command -like '*opendata script*' }
            }
        }

        Context 'Emulator unreachable' {
            It 'Should throw a clear error naming the cluster URI and stop before downloading anything' {
                # Arrange
                Mock -CommandName 'Invoke-FinOpsHubLocalCommand' -MockWith { throw 'connection refused' } -ParameterFilter {
                    $Database -eq 'NetDefaultDB' -and $Command -eq '.show version'
                }

                # Act / Assert
                { Initialize-FinOpsHubLocal -ClusterUri 'http://localhost:1' -Destination $destination } |
                    Should -Throw "*Could not reach the Kusto emulator at 'http://localhost:1'*"
                Should -Invoke -CommandName 'Invoke-WebRequest' -Times 0
            }
        }

        Context 'Download failures' {
            It 'Should throw a clear error naming the asset and release URI' {
                # Arrange
                Mock -CommandName 'Invoke-WebRequest' -MockWith { throw 'network error' } -ParameterFilter {
                    $Uri -like '*finops-hub-fabric-setup-Ingestion.kql'
                }

                # Act / Assert
                { Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination } |
                    Should -Throw "*Could not download asset 'finops-hub-fabric-setup-Ingestion.kql'*"
            }
        }

        Context 'Empty downloaded assets' {
            It 'Should throw a clear error when a downloaded asset is empty' {
                # Arrange
                Mock -CommandName 'Get-Content' -MockWith { return '' }

                # Act / Assert
                { Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination } |
                    Should -Throw "*Downloaded asset 'finops-hub-fabric-setup-Ingestion.kql'*was empty*"
            }
        }

        Context 'Open data retry logic' {
            It 'Should retry loading open data until every table reports rows' {
                # Arrange
                $script:queryCallCount = 0
                Mock -CommandName 'Invoke-FinOpsHubLocalCommand' -ParameterFilter { $Endpoint -eq 'query' } -MockWith {
                    $script:queryCallCount++
                    # First attempt's 4 table checks report empty; second attempt's report filled.
                    if ($script:queryCallCount -le 4)
                    {
                        return (newQueryResult -Count 0)
                    }

                    return (newQueryResult -Count 5)
                }

                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination

                # Assert
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 2 -ParameterFilter {
                    $Database -eq 'Ingestion' -and $Command -like '*opendata script*'
                }
                Should -Invoke -CommandName 'Start-Sleep' -Times 1
            }

            It 'Should throw after the maximum number of attempts if the tables remain empty' {
                # Arrange
                Mock -CommandName 'Invoke-FinOpsHubLocalCommand' -ParameterFilter { $Endpoint -eq 'query' } -MockWith {
                    return (newQueryResult -Count 0)
                }

                # Act / Assert
                { Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination } |
                    Should -Throw '*Open data tables were still empty after 5 attempts*'
                Should -Invoke -CommandName 'Start-Sleep' -Times 4
            }
        }

        Context 'ShouldProcess (-WhatIf)' {
            It 'Should not create databases, apply setup scripts, or load open data' {
                # Act
                Initialize-FinOpsHubLocal -ClusterUri $clusterUri -Destination $destination -WhatIf

                # Assert -- only the reachability check runs; every ShouldProcess-gated call is skipped.
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1
                Should -Invoke -CommandName 'Invoke-FinOpsHubLocalCommand' -Times 1 -ParameterFilter { $Command -eq '.show version' }
            }
        }

        Context 'Parameter validation' {
            It 'Should require a non-empty ClusterUri' {
                { Initialize-FinOpsHubLocal -ClusterUri '' } | Should -Throw
            }

            It 'Should require a non-empty ReleaseUri' {
                { Initialize-FinOpsHubLocal -ReleaseUri '' } | Should -Throw
            }

            It 'Should reject a RawRetentionInDays of 0' {
                { Initialize-FinOpsHubLocal -RawRetentionInDays 0 } | Should -Throw
            }

            It 'Should require a non-empty OpenDataPath' {
                { Initialize-FinOpsHubLocal -OpenDataPath '' } | Should -Throw
            }

            It 'Should require a non-empty Destination' {
                { Initialize-FinOpsHubLocal -Destination '' } | Should -Throw
            }

            It 'Should reject a negative TimeoutSec' {
                { Initialize-FinOpsHubLocal -TimeoutSec -1 } | Should -Throw
            }
        }
    }
}
