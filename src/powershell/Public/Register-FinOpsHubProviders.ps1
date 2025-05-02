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
function Register-FinOpsHubProviders
{
    [Diagnostics.CodeAnalysis.SuppressMessage("PSUseSingularNouns", "", Justification="Action registers multiple providers, so plural is more accurate.")]
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    try
    {
        # Loop through each provider and check if it's already registered
        @('Microsoft.EventGrid', 'Microsoft.CostManagementExports') `
        | ForEach-Object {
            $provider = $_
            $registered = Get-AzResourceProvider -ProviderNamespace $provider

            # If registered, log it; otherwise, register it
            if ($registered.RegistrationState -eq 'Registered')
            {
                Write-Verbose -Message $($LocalizedData.HubProviders_Register_AlreadyRegistered -f $provider)
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.HubProviders_Register_Register -f $provider)
                Register-AzResourceProvider -ProviderNamespace $provider -WhatIf:$WhatIfPreference
            }
        }
    }
    catch
    {
        Write-Verbose -Message $($LocalizedData.HubProviders_Register_RegisterError -f $_.Exception.Message)
        throw
    }
}