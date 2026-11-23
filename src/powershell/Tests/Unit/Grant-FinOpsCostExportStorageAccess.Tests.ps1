# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Grant-FinOpsCostExportStorageAccess' {
        BeforeAll {
            Mock -CommandName 'Start-Sleep' { }
            Mock -CommandName 'Write-Warning' { }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $subscriptionId = [Guid]::NewGuid().ToString()

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $grantParams = @{
                PrincipalId      = [Guid]::NewGuid().ToString()
                StorageAccountId = "/subscriptions/$subscriptionId/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"
                StorageContainer = 'MSExports'
            }
        }

        It 'Should assign Storage Blob Data Contributor on the container' {
            # Arrange
            Mock -CommandName 'Invoke-Rest' { @{ Success = $true } }

            # Act
            $result = Grant-FinOpsCostExportStorageAccess @grantParams

            # Assert
            $result | Should -Be $true
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                $Method -eq 'PUT' `
                    -and $Uri -like "/subscriptions/$subscriptionId/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar/blobServices/default/containers/msexports/providers/Microsoft.Authorization/roleAssignments/*" `
                    -and $Body.properties.roleDefinitionId -eq "/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe" `
                    -and $Body.properties.principalId -eq $grantParams.PrincipalId `
                    -and $Body.properties.principalType -eq 'ServicePrincipal'
            }
        }

        It 'Should use the same assignment name on every run' {
            # Arrange
            $script:uris = @()
            Mock -CommandName 'Invoke-Rest' { $script:uris += $Uri; @{ Success = $true } }

            # Act
            Grant-FinOpsCostExportStorageAccess @grantParams
            Grant-FinOpsCostExportStorageAccess @grantParams

            # Assert
            $script:uris.Count | Should -Be 2
            $script:uris[0] | Should -Be $script:uris[1]
        }

        It 'Should succeed when the assignment already exists' {
            # Arrange
            Mock -CommandName 'Invoke-Rest' { @{ Success = $false; Failure = $true; Content = @{ error = @{ code = 'RoleAssignmentExists'; message = 'exists' } } } }

            # Act
            $result = Grant-FinOpsCostExportStorageAccess @grantParams

            # Assert
            $result | Should -Be $true
            Should -Invoke -CommandName 'Write-Warning' -Times 0
        }

        It 'Should retry while the principal is not found' {
            # Arrange
            $script:calls = 0
            Mock -CommandName 'Invoke-Rest' {
                $script:calls++
                if ($script:calls -lt 3)
                {
                    @{ Success = $false; Failure = $true; Content = @{ error = @{ code = 'PrincipalNotFound'; message = 'not found' } } }
                }
                else
                {
                    @{ Success = $true }
                }
            }

            # Act
            $result = Grant-FinOpsCostExportStorageAccess @grantParams -RetryDelaySeconds 0

            # Assert
            $result | Should -Be $true
            Should -Invoke -CommandName 'Invoke-Rest' -Times 3
        }

        It 'Should warn and return false when the assignment fails' {
            # Arrange
            Mock -CommandName 'Invoke-Rest' { @{ Success = $false; Failure = $true; Content = @{ error = @{ code = 'AuthorizationFailed'; message = 'denied' } } } }

            # Act
            $result = Grant-FinOpsCostExportStorageAccess @grantParams

            # Assert
            $result | Should -Be $false
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1
            Should -Invoke -CommandName 'Write-Warning' -Times 1
        }

        It 'Should not assign the role with -WhatIf' {
            # Arrange
            Mock -CommandName 'Invoke-Rest' { @{ Success = $true } }

            # Act
            $result = Grant-FinOpsCostExportStorageAccess @grantParams -WhatIf

            # Assert
            $result | Should -Be $false
            Should -Invoke -CommandName 'Invoke-Rest' -Times 0
        }
    }
}
