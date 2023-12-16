# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"
$global:ftk_ResourceGroup = "ftk-test-integration"

Describe 'Hubs' {
    # TODO: Make this more robust
    It 'Should upgrade from 0.0.1 hub instance' {
        # Arrange
        $requiredRPs = @('Microsoft.CostManagementExports', 'Microsoft.EventGrid')
        $name = "ftk-test-DeployHub_$($env:USERNAME)"
        $rg = "ftk-test-integration"
        $location = "eastus" # must be lowercase with no spaces
        $versions = Get-FinOpsToolkitVersion | Select-Object -ExpandProperty Version -Unique | Sort-Object { $_ }

        # Unregister RPs before deploying
        $requiredRPs | ForEach-Object {
            Write-Host "  Unregistering $_..." -NoNewline
            try
            {
                Unregister-AzResourceProvider -ProviderNamespace $_
                Write-Host 'in progress...' -NoNewline
                foreach ($x in 1..5)
                {
                    Start-Sleep -Seconds 2
                    $rp = Get-AzResourceProvider -ProviderNamespace $_
                    if ($rp.RegistrationState -eq 'Unregistered')
                    {
                        break
                    }
                }
                if ($rp.RegistrationState -eq 'Unregistered')
                {
                    Write-Host 'done'
                }
                else
                {
                    Write-Host 'not done (continuing anyway)'
                }
            }
            catch
            {
                Write-Host 'cannot unregister'
            }
        }

        # Loop thru each version
        $versions | ForEach-Object {
            # Act
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute ('PSUseDeclaredVarsMoreThanAssignments', Scope = 'Function', Target = '*')]
            $result = Deploy-FinOpsHub `
                -Name $name `
                -Location $location `
                -ResourceGroupName $rg `
                -Version $_
            $hub = Get-FinOpsHub -Name $name -ResourceGroupName $rg

            # Assert RP status
            $requiredRPs | ForEach-Object {
                $rp = Get-AzResourceProvider -ProviderNamespace $_
                $rp.RegistrationState | Should -BeIn 'Registered', 'Registering' -Because "RP '$_' should be registered" -inc
            }

            # Assert hub state
            @($hub).Count | Should -Be 1 -Because "there should only be one hub with name '$name' in resource group '$rg' (v$_)"
            $hub.Location.ToLower() -replace ' ', '' | Should -Be $location -Because "hub should be in location '$location' (v$_)"
            $hub.Version | Should -Be $_
            $hub.Status | Should -Be 'Deployed' -Because "hub should be in 'Deployed' status (v$_)"
            $hub.Status | Should -Not -Be 'Unknown' -Because "hub should not be in 'Unknown' status (v$_)"
            $hub.Resources.ResourceType.ToLower() | Sort-Object `
            | Should -Be @(
                'microsoft.datafactory/factories',
                'microsoft.keyvault/vaults',
                (if ([version]$_ -ge [version]'0.1') { 'microsoft.managedidentity/userassignedidentities', 'microsoft.managedidentity/userassignedidentities' }),
                'microsoft.storage/storageaccounts'
            ) -Because "hub should have expected resources (v$_)"

            # TODO: Test 'StorageOnly' status
            # TODO: Test 0.0.1 'DeployedWithExtraResources' status = storage + DF + KV + 1???
            # TODO: Test 0.1 'DeployedWithExtraResources' status = storage + DF + KV + 3+???
        }

        # TODO: Deploy local version to verify upgrade still works
    }
}
