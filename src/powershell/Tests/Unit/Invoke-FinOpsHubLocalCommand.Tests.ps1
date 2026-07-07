# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope FinOpsToolkit {
    Describe 'Invoke-FinOpsHubLocalCommand' {
        BeforeAll {
            function newKustoErrorRecord($code, $message)
            {
                $body = @{ error = @{ code = $code; message = $message } } | ConvertTo-Json -Compress
                $exception = New-Object System.Exception('Response status code does not indicate success')
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    $exception, 'WebCmdletWebResponseException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null
                )
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($body)
                return $errorRecord
            }
        }

        Context 'Successful call' {
            It 'Should post to the mgmt endpoint by default and return the response' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { return @{ Tables = @() } }

                # Act
                $result = Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command '.show version'

                # Assert
                $result | Should -Not -BeNullOrEmpty
                Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    $Uri -eq 'http://localhost:8082/v1/rest/mgmt' -and
                    $Method -eq 'Post' -and
                    $TimeoutSec -eq 0
                }
            }

            It 'Should post to the query endpoint when requested' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { return @{ Tables = @() } }

                # Act
                Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command 'Costs_v1_2 | count' -Endpoint 'query'

                # Assert
                Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter { $Uri -eq 'http://localhost:8082/v1/rest/query' }
            }

            It 'Should trim a trailing slash from the cluster URI' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { return @{ Tables = @() } }

                # Act
                Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082/' -Database 'Hub' -Command '.show version'

                # Assert
                Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter { $Uri -eq 'http://localhost:8082/v1/rest/mgmt' }
            }

            It 'Should pass the requested timeout through to Invoke-RestMethod' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { return @{ Tables = @() } }

                # Act
                Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command '.show version' -TimeoutSec 45

                # Assert
                Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter { $TimeoutSec -eq 45 }
            }
        }

        Context 'Structured Kusto errors' {
            It 'Should surface the Kusto error message and code' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { throw (newKustoErrorRecord 'BadRequest_SyntaxError' 'Query could not be parsed') }

                # Act / Assert
                { Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command 'invalid |||' } |
                    Should -Throw '*Query could not be parsed*BadRequest_SyntaxError*'
            }
        }

        Context 'Unstructured errors' {
            It 'Should rethrow the original exception when there is no JSON error body' {
                # Arrange
                Mock -CommandName 'Invoke-RestMethod' -MockWith { throw 'Unable to connect to the remote server' }

                # Act / Assert
                { Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command '.show version' } |
                    Should -Throw 'Unable to connect to the remote server'
            }
        }

        Context 'Parameter validation' {
            It 'Should require a non-empty ClusterUri' {
                { Invoke-FinOpsHubLocalCommand -ClusterUri '' -Database 'Hub' -Command '.show version' } | Should -Throw
            }

            It 'Should require a non-empty Database' {
                { Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database '' -Command '.show version' } | Should -Throw
            }

            It 'Should require a non-empty Command' {
                { Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command '' } | Should -Throw
            }

            It 'Should reject a negative TimeoutSec' {
                { Invoke-FinOpsHubLocalCommand -ClusterUri 'http://localhost:8082' -Database 'Hub' -Command '.show version' -TimeoutSec -1 } | Should -Throw
            }
        }
    }
}
