# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Initialize a FinOps hub deployment in order to enable resource group owners to deployment hubs via the portal.

    .EXAMPLE
    Initialize-FinOpsHubDeployment -WhatIf

    Shows what would happen if the command runs without actually running it.

    .DESCRIPTION
    The Initialize-FinOpsHubDeployment command performs any initialization tasks required for a resource group contributor to be able to deploy a FinOps hub instance in Azure, like registering resource providers. To view the full list of tasks performed, run the command with the -WhatIf option.

    .LINK
    https://aka.ms/ftk/Initialize-FinOpsHubDeployment
#>
function Initialize-FinOpsHubDeployment
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Register-FinOpsHubProviders -WhatIf:$WhatIfPreference | Out-Null
}
