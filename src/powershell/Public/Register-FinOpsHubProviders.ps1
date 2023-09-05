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

    .Description
    The Register-FinOpsHubProviders command registers the Azure resource providers required to deploy and operate a FinOps hub instance. To register a resource provider, you must have Contributor access (or the /register permission for each resource provider) for the entire subscription. Subscription readers can check the status of the resource providers but cannot register them. If you do not have access to register resource providers, please contact a subscription contributor or owner to run the Register-FinOpsHubProviders command.
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
                    Write-Verbose "WhatIf:"+ $($LocalizedData.RegisterProvider -f $provider)
                }
                else {
                    Write-Verbose -Message $($LocalizedData.RegisterProvider -f $provider)
                    Register-AzResourceProvider -ProviderNamespace $provider   
                }
            }
            # If the provider is already registered, logging a message saying so
            else {
                Write-Verbose -Message $($LocalizedData.ResourceProviderRegistered -f $provider)
            }
        }
    }
    catch {
        Write-Verbose -Message $($LocalizedData.ErrorRegisteringProvider -f $_.Exception.Message)
        throw $_.Exception.Message
    }
}