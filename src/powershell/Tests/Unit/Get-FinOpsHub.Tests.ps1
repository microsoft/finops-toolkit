# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

if (-not (Get-Module -Name 'FinOpsToolkit'))
{
    $rootDirectory = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
    $modulePath = (Get-ChildItem -Path $rootDirectory -Include 'FinOpsToolKit.psm1' -Recurse).FullName
    Import-Module -FullyQualifiedName $modulePath
}

InModuleScope 'FinOpsToolkit' {
    BeforeAll {
        function New-MockResource
        {
            [CmdletBinding()]
            param
            (
                [Parameter()]
                [string]
                $SubscriptionId,

                [Parameter()]
                [string]
                $ResourceGroupName,

                [Parameter()]
                [string]
                $Name
            )

            $rg = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"

            return @{
                Id   = "$rg/providers/Microsoft.Storage/storageAccounts/$Name-store"
                Type = 'Microsoft.Storage/storageAccounts'
                Name = "$Name-store"
                Tags = @{
                    'cm-resource-parent' = "$rg/providers/Microsoft.Cloud/hubs/$Name"
                }
            }
        }
    }

    Describe 'Get-FinOpsHub' {
        BeforeAll {
            function Get-AzContext {}
            function Get-AzResource {}
        }

        Context 'AzContext' {
            BeforeAll {
                Mock -CommandName 'Get-AzContext'
            }

            It 'Should throw if Az context is not set' {
                { Get-FinOpsHub } | Should -Throw
            }
        }

        Context 'Tag Filtering' {
            BeforeDiscovery {
                $id = (New-Guid).Guid
                $hubPartial = 'hub'
                $hub1 = 'hub1'
                $hub2 = 'hub2'
                $newHub = 'newHub'
                $hubWild = 'hub*'
                $rgPartial = 'test'
                $rgFull = 'testRg'
                $newRg = 'newRg'
                $rgWild = 'test*'
                $noMatch = 'fake'
                $tagTemplate = "/subscriptions/$id/resourceGroups/{0}/providers/Microsoft.Cloud/hubs/{1}"
            }

            BeforeAll {
                $hubPartial = 'hub'
                $hub1 = 'hub1'
                $hub2 = 'hub2'
                $newHub = 'newHub'
                $hubWild = 'hub*'
                $rgPartial = 'test'
                $rgFull = 'testRg'
                $newRg = 'newRg'
                $rgWild = 'test*'
                $noMatch = 'fake'
                $tagTemplate = "/subscriptions/$id/resourceGroups/{0}/providers/Microsoft.Cloud/hubs/{1}"
                Mock -CommandName 'Get-AzContext' -MockWith { @{Subscription = @{Id = $id } } }
            }

            It "Returns 3 FinOps Hubs: '$hubPartial', '$hub1', '$hub2' [ResourceGroup]: '$rgFull' with [Name filter]: '$hubWild' and [ResourceGroup filter]: 'null'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub1),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub2),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $newRg -Name $newHub)
                    )
                }
                $result = Get-FinOpsHub -Name $hubWild
                $result.Count | Should -Be 3
            }

            It "Returns 1 FinOps Hub: '$hubPartial' [ResourceGroup]: '$rgFull' with [Name filter]: '$hubPartial' and [ResourceGroup filter]: 'null'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub -Name $hubPartial
                $result.Count | Should -Be 1
            }

            It "Returns 0 FinOps Hubs: '' [ResourceGroup]: '' with [Name filter]: '$noMatch' and [ResourceGroup filter]: 'null'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub -Name $noMatch
                $result.Count | Should -Be 0
            }

            It "Returns 4 FinOps Hubs: '$hubPartial', '$newHub', '$hub2', '$hub1' [ResourceGroup]: '$rgFull', 'newRg' with [Name filter]: 'null' and [ResourceGroup filter]: 'null'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $newHub),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub2),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $newRg -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub
                $result.Count | Should -Be 4
            }

            It "Returns 0 FinOps Hubs: '' [ResourceGroup]: '' with [Name filter]: '$noMatch' and [ResourceGroup filter]: 'null'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub -Name $noMatch
                $result.Count | Should -Be 0
            }

            It "Returns 2 FinOps Hubs: '$hubPartial', '$hub1' [ResourceGroup]: '$rgFull', '$rgPartial' with [Name filter]: 'null' and [ResourceGroup filter]: '$rgWild'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgPartial -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub -ResourceGroupName $rgWild
                $result.Count | Should -Be 2
            }

            It "Returns 2 FinOps Hubs: '$hubPartial', '$hub1', '$hub1' [ResourceGroup]: '$rgFull', '$rgPartial' with [Name filter]: '$hubWild' and [ResourceGroup filter]: '$rgWild'" {
                Mock -CommandName Get-AzResource -MockWith {
                    @(
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgFull -Name $hubPartial),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgPartial -Name $hub1),
                        (New-MockResource -SubscriptionId $id -ResourceGroupName $rgPartial -Name $hub1)
                    )
                }
                $result = Get-FinOpsHub -ResourceGroupName $rgWild
                $result.Count | Should -Be 2
            }
        }
    }
}
