# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Initialize a FinOps hub deployment in order to enable resource group owners to deployment hubs via the portal.

    .PARAMETER WhatIf
    Optional. Shows what would happen if the command runs without actually running it.

    .EXAMPLE
    Initialize-FinOpsHubDeployment `
    [-WhatIf]

    Shows what would happen if the command runs without actually running it.

    .Description
    The Initialize-FinOpsHubDeployment command performs any initialization tasks required for a resource group contributor to be able to deploy a FinOps hub instance in Azure, like registering resource providers. To view the full list of tasks performed, run the command with the -WhatIf option.
#>


function Initialize-FinOpsHubDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Initialization Tasks for FinOpsHub')) {
        if ($WhatIf) {
            Write-Output 'WhatIf:'+ $LocalizedData.FinOpsHubInitialization
        }
        else {
            # Register required resource providers
            Write-Output $LocalizedData.FinOpsHubInitialization
            Register-FinOpsHubProviders
        }

        # Other initialization tasks go here
    }
}
