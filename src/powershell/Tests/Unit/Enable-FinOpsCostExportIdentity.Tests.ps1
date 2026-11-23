# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Enable-FinOpsCostExportIdentity' {
        BeforeAll {
            Mock -CommandName 'Get-AzContext' { @{ } }
            Mock -CommandName 'Write-Warning' { }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $exportName = 'ftk-test-Enable-FinOpsCostExportIdentity'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $scope = "/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/0000-0000-000-000"

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $storageId = "/subscriptions/$([Guid]::NewGuid())/resourceGroups/foo/providers/Microsoft.Storage/storageAccounts/bar"

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $mockPrincipalId = [Guid]::NewGuid().ToString()

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $summary = [PSCustomObject]@{
                Name             = $exportName
                Id               = "$scope/providers/Microsoft.CostManagement/exports/$exportName"
                StorageAccountId = $storageId
                StorageContainer = 'msexports'
                IdentityType     = $null
                PrincipalId      = $null
            }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $rawExport = [PSCustomObject]@{
                id         = $summary.Id
                name       = $exportName
                eTag       = '"etag-1"'
                properties = [PSCustomObject]@{
                    format              = 'Parquet'
                    schedule            = [PSCustomObject]@{ status = 'Active'; recurrence = 'Daily' }
                    deliveryInfo        = [PSCustomObject]@{ destination = [PSCustomObject]@{ resourceId = $storageId; container = 'msexports' } }
                    runHistory          = [PSCustomObject]@{ value = @() }
                    nextRunTimeEstimate = '2026-01-02T00:00:00Z'
                }
            }
        }

        BeforeEach {
            Mock -CommandName 'Get-FinOpsCostExport' { $summary }
            Mock -CommandName 'Grant-FinOpsCostExportStorageAccess' { $true }
            Mock -CommandName 'Invoke-Rest' -ParameterFilter { $Method -eq 'GET' } { @{ Success = $true; Content = $rawExport } }
            Mock -CommandName 'Invoke-Rest' -ParameterFilter { $Method -eq 'PUT' } { @{ Success = $true; Content = @{ identity = @{ type = 'SystemAssigned'; principalId = $mockPrincipalId } } } }
        }

        It 'Should fail if no export matches' {
            # Arrange
            Mock -CommandName 'Get-FinOpsCostExport' { $null }

            # Act
            { Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope } | Should -Throw

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 0
        }

        It 'Should update the export in place with identity, location, and eTag' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope -Location 'westeurope'

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                $Method -eq 'PUT' `
                    -and $Uri -eq "$($scope.Trim('/'))/providers/Microsoft.CostManagement/exports/$exportName`?api-version=2025-03-01" `
                    -and $Body.identity.type -eq 'SystemAssigned' `
                    -and $Body.location -eq 'westeurope' `
                    -and $Body.eTag -eq '"etag-1"' `
                    -and $Body.properties.format -eq 'Parquet' `
                    -and $Body.properties.schedule.recurrence -eq 'Daily'
            }
            Should -Invoke -CommandName 'Invoke-Rest' -Times 0 -ParameterFilter { $Method -eq 'DELETE' }
        }

        It 'Should not send read-only properties' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                $Method -eq 'PUT' `
                    -and $null -eq $Body.properties.runHistory `
                    -and $null -eq $Body.properties.nextRunTimeEstimate
            }
        }

        It 'Should default location to global' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                $Method -eq 'PUT' -and $Body.location -eq 'global'
            }
        }

        It 'Should assign the storage role to the new identity' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope

            # Assert
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 1 -ParameterFilter {
                $PrincipalId -eq $mockPrincipalId `
                    -and $StorageAccountId -eq $storageId `
                    -and $StorageContainer -eq 'msexports'
            }
        }

        It 'Should skip the role assignment with -SkipRoleAssignment' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope -SkipRoleAssignment

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter { $Method -eq 'PUT' }
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 0
        }

        It 'Should not update an export that already has an identity' {
            # Arrange
            $withIdentity = $summary.PSObject.Copy()
            $withIdentity.IdentityType = 'SystemAssigned'
            $withIdentity.PrincipalId = $mockPrincipalId
            Mock -CommandName 'Get-FinOpsCostExport' { $withIdentity }

            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 0
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 1 -ParameterFilter { $PrincipalId -eq $mockPrincipalId }
        }

        It 'Should not change anything with -WhatIf' {
            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope -WhatIf

            # Assert
            Should -Invoke -CommandName 'Invoke-Rest' -Times 0
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 0
        }

        It 'Should report an error and skip the role when the update fails' {
            # Arrange
            Mock -CommandName 'Invoke-Rest' -ParameterFilter { $Method -eq 'PUT' } { @{ Success = $false; Failure = $true; Content = @{ error = @{ code = 'PreconditionFailed'; message = 'eTag mismatch' } } } }

            # Act
            Enable-FinOpsCostExportIdentity -Name $exportName -Scope $scope -ErrorAction SilentlyContinue -ErrorVariable errors

            # Assert
            $errors.Count | Should -BeGreaterThan 0
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 0
        }

        It 'Should continue with the next export when a request throws' {
            # Arrange
            $failing = [PSCustomObject]@{
                Name             = 'ftk-failing'
                Id               = "$scope/providers/Microsoft.CostManagement/exports/ftk-failing"
                StorageAccountId = $storageId
                StorageContainer = 'msexports'
                IdentityType     = $null
                PrincipalId      = $null
            }
            Mock -CommandName 'Get-FinOpsCostExport' { @($failing, $summary) }
            Mock -CommandName 'Invoke-Rest' -ParameterFilter { $Method -eq 'GET' -and $Uri -like '*ftk-failing*' } { throw 'Service unavailable' }

            # Act
            Enable-FinOpsCostExportIdentity -Name '*' -Scope $scope -ErrorAction SilentlyContinue -ErrorVariable errors

            # Assert
            $errors.Count | Should -BeGreaterThan 0
            Should -Invoke -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter { $Method -eq 'PUT' -and $Uri -like "*$exportName*" }
            Should -Invoke -CommandName 'Grant-FinOpsCostExportStorageAccess' -Times 1
        }
    }
}
