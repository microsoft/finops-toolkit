# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Hubs' {
    BeforeDiscovery {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $requiredRPs = $global:ftk_InitializeTests_Hubs_RequiredRPs

        # TODO: Automatically validate the last 3 versions only
        # TODO: Automatically validate the last 3 versions only
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $versions = @('0.1.1', '0.3', '0.4', '0.5') | Sort-Object { [version]$_ }
    }

    BeforeAll {
        # Must be duplicated because pre-discovery vars aren't accessible
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $requiredRPs = $global:ftk_InitializeTests_Hubs_RequiredRPs
    }

    Context 'Register-FinOpsHubProviders' {
        It 'Should register all required providers' {
            # Arrange
            # Act
            Register-FinOpsHubProviders

            # Assert
            $requiredRPs | ForEach-Object {
                # TODO: It's possible this could take some time; if this tests fails, add a wait, accept 'Registering', or remove it
                Get-AzResourceProvider -ProviderNamespace $_ `
                | Select-Object -ExpandProperty RegistrationState -First 1 `
                | Should -BeIn @('Registered', 'Registering')
            }
        }
    }

    Context 'Deploy-FinOpsHub' {
        BeforeAll {
            # Arrange
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $ftk_ResourceGroup = "ftk-test-integration"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $ftk_HubName = "ftk-test-DeployHub_$($env:USERNAME)"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $ftk_HubRG = "ftk-test-integration"
            # TODO: Confirm lowercase/space requirement and add handling to avoid the limitation
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $ftk_HubLocation = "eastus" # must be lowercase with no spaces
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $versions = Get-FinOpsToolkitVersion | Select-Object -ExpandProperty Version -Unique | Sort-Object { $_ }
        }

        Context 'Unregister resource providers to verify auto-registration' {
            It "Should unregister the <_> RP" -ForEach $requiredRPs {
                $rp = $_
                Monitor "Unregistering $rp..." -Indent '   ' {
                    Unregister-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue
                    if (-not $?)
                    {
                        Report 'Cannot unregister' -Exception $Error[0].Exception
                        Set-ItResult -Inconclusive -Because "the '$rp' cannot be unregistered"
                        return
                    }
                    else
                    {
                        Report 'Waiting for unregistration to complete...'
                        foreach ($x in 1..5)
                        {
                            Start-Sleep -Seconds 2
                            $state = Get-AzResourceProvider -ProviderNamespace $rp
                            if ($state.RegistrationState -eq 'Unregistered')
                            {
                                Report 'Done'
                                return
                            }
                        }
                        Report 'Not finished after 10s (continuing anyway)'
                        Set-ItResult -Inconclusive -Because "the '$rp' did not finish unregistering within 10s"
                    }
                }
            }
        }

        Context 'Deploy and remove' {
            It 'Should deploy and remove a FinOps hubs instance' {
                Monitor "Deploying latest" -Indent '   ' {
                    Monitor "Deploying..." {
                        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope = 'Function', Target = '*')]
                        $script:deployResult = Deploy-FinOpsHub `
                            -Name $ftk_HubName `
                            -Location $ftk_HubLocation `
                            -ResourceGroupName $ftk_HubRG
                        Report -Object ($script:deployResult ?? '(null)')
                    }

                    Monitor 'Getting instance...' {
                        $script:getResult = Get-FinOpsHub -Name $ftk_HubName -ResourceGroupName $ftk_HubRG
                        Report -Object ($script:getResult ?? '(null)')
                    }

                    Monitor 'Removing instance...' {
                        $script:removeResult = Remove-FinOpsHub -Name $ftk_HubName -ResourceGroupName $ftk_HubRG -Force -Confirm:$false
                        Report -Object ($script:removeResult ?? '(null)')
                    }
                }
            }
        }

        Context 'Deploy and upgrade' -Skip {
            It 'Should deploy FinOps hubs <_>' -ForEach $versions {
                $ver = $_

                # Act
                Monitor "FinOps hubs $ver" -Indent '   ' {
                    Monitor "Deploying..." {
                        [Diagnostics.CodeAnalysis.SuppressMessageAttribute ('PSUseDeclaredVarsMoreThanAssignments', '', Scope = 'Function', Target = '*')]
                        $script:deployResult = Deploy-FinOpsHub `
                            -Name $ftk_HubName `
                            -Location $ftk_HubLocation `
                            -ResourceGroupName $ftk_HubRG `
                            -Version $_
                        Report -Object ($script:deployResult ?? '(null)')
                    }

                    Monitor 'Getting instance...' {
                        $script:getResult = Get-FinOpsHub -Name $ftk_HubName -ResourceGroupName $ftk_HubRG
                        Report -Object ($script:getResult ?? '(null)')
                    }

                    Monitor 'Removing instance...' {
                        $script:removeResult = Remove-FinOpsHub -Name $ftk_HubName -ResourceGroupName $ftk_HubRG -Force -Confirm:$false
                        Report -Object ($script:removeResult ?? '(null)')
                    }
                }

                # Assert RP status
                $requiredRPs | ForEach-Object {
                    Get-AzResourceProvider -ProviderNamespace $_ `
                    | Select-Object -ExpandProperty RegistrationState -First 1 `
                    | Should -BeIn 'Registered', 'Registering' -ErrorAction Continue -Because "RP '$_' should be registered"
                }

                # Assert hub state
                @($script:getResult).Count | Should -Be 1 -ErrorAction Continue -Because "there should only be one hub with name '$ftk_HubName' in resource group '$ftk_HubRG' (v$ver)"
                $script:getResult.Location.ToLower() -replace ' ', '' | Should -Be $ftk_HubLocation -ErrorAction Continue -Because "hub should be in location '$ftk_HubLocation' (v$ver)"
                $script:getResult.Version | Should -Be $ver -ErrorAction Continue
                $script:getResult.Status | Should -Be 'Deployed' -ErrorAction Continue -Because "hub should be in 'Deployed' status (v$ver)"
                $script:getResult.Status | Should -Not -Be 'Unknown' -ErrorAction Continue -Because "hub should not be in 'Unknown' status (v$ver)"
                $script:getResult.Resources.ResourceType.ToLower() | Sort-Object `
                | Should -Be @(
                    'microsoft.datafactory/factories',
                    'microsoft.keyvault/vaults',
                    (if ([version]$ver -ge [version]'0.1') { 'microsoft.managedidentity/userassignedidentities', 'microsoft.managedidentity/userassignedidentities' }),
                    'microsoft.storage/storageaccounts'
                ) -ErrorAction Continue -Because "hub should have expected resources (v$ver)"

                # TODO: Test 'StorageOnly' status
                # TODO: Test 0.0.1 'DeployedWithExtraResources' status = storage + DF + KV + 1???
                # TODO: Test 0.1 'DeployedWithExtraResources' status = storage + DF + KV + 3+???
            }
        }
    }
}
