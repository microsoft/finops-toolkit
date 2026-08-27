# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope FinOpsToolkit {
    Describe 'Add-FinOpsHubResourceGraphReader' {
        BeforeAll {
            function Get-AzContext {}
            function Get-FinOpsHub {}
            function Get-AzDataFactoryV2 {}
            function Get-AzRoleAssignment {}
            function New-AzRoleAssignment {}
        }

        BeforeEach {
            Mock Get-AzContext { @{ Tenant = @{ Id = 'tenant-id' } } }
            Mock Get-FinOpsHub {
                @{
                    Resources = @(
                        @{
                            ResourceType = 'Microsoft.DataFactory/factories'
                            ResourceGroupName = 'hub-rg'
                            Name = 'hub-engine'
                        }
                    )
                }
            }
            Mock Get-AzDataFactoryV2 {
                @{ Identity = @{ PrincipalId = 'principal-id' } }
            }
            Mock New-AzRoleAssignment { @{ Id = 'assignment-id' } }
        }

        It 'assigns Reader at a subscription scope when given a subscription ID' {
            $result = Add-FinOpsHubResourceGraphReader -Scope '00000000-0000-0000-0000-000000000000' -Confirm:$false

            Should -Invoke New-AzRoleAssignment -Times 1
            $result.Id | Should -Be 'assignment-id'
        }

        It 'does not create an assignment when Reader already exists' {
            Mock Get-AzRoleAssignment { @{ Id = 'existing-id' } }

            $result = Add-FinOpsHubResourceGraphReader -Scope '/subscriptions/sub-id' -Confirm:$false

            Should -Invoke New-AzRoleAssignment -Times 0
            $result.Id | Should -Be 'existing-id'
        }

        It 'supports management group scopes' {
            Add-FinOpsHubResourceGraphReader -Scope '/providers/Microsoft.Management/managementGroups/contoso' -Confirm:$false

            Should -Invoke New-AzRoleAssignment -Times 1
        }

        It 'rejects unsupported scopes' {
            { Add-FinOpsHubResourceGraphReader -Scope '/resourceGroups/example' -Confirm:$false } | Should -Throw
            Should -Invoke Get-FinOpsHub -Times 0
        }
    }
}
