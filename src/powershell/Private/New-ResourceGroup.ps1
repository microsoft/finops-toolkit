# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates a new resource group.

    .EXAMPLE
    New-ResourceGroup -WhatIf

    Shows what would happen if the command runs without actually running it.

    .DESCRIPTION
    The New-ResourceGroup command performs any initialization tasks required for a resource group contributor to be able to deploy a FinOps hub instance in Azure, like registering resource providers. To view the full list of tasks performed, run the command with the -WhatIf option.
#>
function New-ResourceGroup
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        [Parameter()]
        [hashtable]
        $Tags
    )

    $resourceGroupObject = Get-AzResourceGroup -Name $Name -ErrorAction 'SilentlyContinue'
    if (-not $resourceGroupObject)
    {
        if (Test-ShouldProcess $PSCmdlet $Name 'CreateResourceGroup')
        {
            $resourceGroupObject = New-AzResourceGroup -Name $Name -Location $Location -Tags $Tags
        }
    }
}
