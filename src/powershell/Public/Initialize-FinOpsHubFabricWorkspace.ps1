# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a FinOps hub instance.

    .DESCRIPTION
    The Initialize-FinOpsHubFabricWorkspace command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub.

    Initialize-FinOpsHubFabricWorkspace calls Initialize-FinOpsHubDeployment before deploying the template.

    .PARAMETER Name
    Required. Name of the hub. Used to ensure unique resource names.

    .PARAMETER ResourceGroupName
    Required. Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER WorkspaceId
    Required. The Microsoft Fabric workspace ID to grant Data Factory access to.

    .EXAMPLE
    Initialize-FinOpsHubFabricWorkspace -Name MyHub -ResourceGroupName MyNewResourceGroup -WorkspaceId 00000000-0000-0000-0000-000000000000

    Grants the FinOps hub Data Factory instance access to the specified Microsoft Fabric workspace.

    .LINK
    https://aka.ms/ftk/Initialize-FinOpsHubFabricWorkspace
#>
function Initialize-FinOpsHubFabricWorkspace
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0)]
        [string]
        $Name = '*',

        [Parameter()]
        [string]
        $ResourceGroupName = '*',
        
        [Parameter(Required = $true)]
        [string]
        $WorkspaceId
    )

    $hubId = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Cloud/hubs/$Name"

    Write-Verbose -Message "Get Data Factory instance for $Name hub instance in the $ResourceGroupName resource group"
    $adf = Get-AzDataFactoryV2 -ResourceGroupName ftk-mf-fabric | Where-Object { $_.Tags['cm-resource-parent'] -like $hubId }

    if (-not $adf)
    {
        throw ($LocalizedData.HubFabricWorkspace_Initialize_DataFactoryNotFound -f $Name, $ResourceGroupName)
    }

    Invoke-Rest `
        -Method POST `
        -Uri "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/users" `
        -Body (@{
            "identifier"           = $adf.Identity.PrincipalId
            "groupUserAccessRight" = "Admin"
        } | ConvertTo-Json) `
        -CommandName 'Initialize-FinOpsHubFabricWorkspace'
}
