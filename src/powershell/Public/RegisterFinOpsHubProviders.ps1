# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
<#
.SYNOPSIS
    Registers Azure resource providers required for FinOps hub.

.PARAMETER WhatIf
    Optional. Shows what would happen if the command runs without actually running it.

.EXAMPLE
    Register-FinOpsHubProviders -WhatIf

    Shows what would happen if the command runs without actually running it.

.NOTES
    This command registers the following Azure resource providers required for FinOps hub:
    - Microsoft.EventGrid
    - Microsoft.CostManagementExports
#>
function Register-FinOpsHubProviders {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # Define the resource providers to register
    $providers = "Microsoft.EventGrid", "Microsoft.CostManagementExports"

    try {
        # Loop through each provider and check if it's already registered
        foreach ($provider in $providers) {
            $registered = Get-AzResourceProvider -ProviderNamespace $provider 

            # If the provider is not registered, register it
            if ($registered.RegistrationState -eq "NotRegistered") {
                
                if ($WhatIf) {
                    Write-Output "WhatIf: Registering resource provider $provider"
                }
                else {
                    Write-Verbose "Registering resource provider $provider"
                    Register-AzResourceProvider -ProviderNamespace $provider   
                }
            }
            # If the provider is already registered, log a message saying so
            else {
                Write-Verbose "Resource provider $provider is already registered"
            }
        }
    }
    finally {
        # Clean up any resources that were used
        $registered = $null
    }
}
