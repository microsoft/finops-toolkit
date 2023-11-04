# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Hubs' {
    BeforeDiscovery {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
        $requiredRPs = $global:ftk_InitializeTests_Hubs_RequiredRPs

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
        $versions = @('0.0.1', '0.1', '0.1.1') | Sort-Object { [version]$_ }
    }

    BeforeAll {
        # Must be duplicated because pre-discovery vars aren't accessible
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
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
                | Should -Be 'Registered'
            }
        }
    }

    Context 'Deploy-FinOpsHub' {
        BeforeAll {
            # Arrange
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $ftk_ResourceGroup = "ftk-test-integration"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $name = "ftk-test-DeployHub_$($env:USERNAME)"
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $rg = "ftk-test-integration"
            # TODO: Confirm lowercase/space requirement and add handling to avoid the limitation
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $location = "eastus" # must be lowercase with no spaces
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
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

        Context 'Deploy and upgrade' -Skip {
            It 'Should deploy FinOps hubs <_>' -ForEach $versions {
                $ver = $_
            
                # Act
                Monitor "FinOps hubs $ver" -Indent '   ' {
                    Monitor "Deploying..." {
                        [Diagnostics.CodeAnalysis.SuppressMessageAttribute ('PSUseDeclaredVarsMoreThanAssignments', Scope = 'Function', Target = '*')]
                        $script:deployResult = Deploy-FinOpsHub `
                            -Name $name `
                            -Location $location `
                            -ResourceGroupName $rg `
                            -Version $_
                        Report -Object ($script:deployResult ?? '(null)')
                    }

                    Monitor 'Getting instance...' {
                        $script:getResult = Get-FinOpsHub -Name $name -ResourceGroupName $rg
                        Report -Object ($script:getResult ?? '(null)')
                    }
                }

                # Assert RP status
                $requiredRPs | ForEach-Object {
                    Get-AzResourceProvider -ProviderNamespace $_ `
                    | Select-Object -ExpandProperty RegistrationState -First 1 `
                    | Should -BeIn 'Registered', 'Registering' -ErrorAction Continue -Because "RP '$_' should be registered"
                }

                # Assert hub state
                @($script:getResult).Count | Should -Be 1 -ErrorAction Continue -Because "there should only be one hub with name '$name' in resource group '$rg' (v$ver)"
                $script:getResult.Location.ToLower() -replace ' ', '' | Should -Be $location -ErrorAction Continue -Because "hub should be in location '$location' (v$ver)"
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
