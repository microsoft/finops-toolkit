# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a FinOps hub instance.

    .DESCRIPTION
    The Deploy-FinOpsHub command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub.

    Deploy-FinOpsHub calls Initialize-FinOpsHubDeployment before deploying the template.

    .PARAMETER Name
    Required. Name of the FinOps hub instance.

    .PARAMETER ResourceGroupName
    Required. Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
    Required. Azure location to execute the deployment from.

    .PARAMETER KeyVaultId
    Optional. Resource ID of the existing Key Vault instance to use. If not specified, one will be created.

    .PARAMETER Version
    Optional. Version of the FinOps hub template to use. Default = "latest".

    .PARAMETER Preview
    Optional. Indicates that preview releases should also be included. Default = false.

    .PARAMETER StorageSku
    Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default = "Premium_LRS".

    .PARAMETER Tags
    Optional. Tags for all resources.

    .EXAMPLE
    Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyExistingResourceGroup -Location westus

    Deploys a new FinOps hub instance named MyHub to an existing resource group named MyExistingResourceGroup.
    
    .EXAMPLE
    Deploy-FinOpsHub -Name MyHub -Location westus -Version 0.1
    
    Deploys a new FinOps hub instance named MyHub using version 0.1 of the template.

    .EXAMPLE
    Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyExistingResourceGroup -Location westus -KeyVaultId "/subscriptions/###/resourceGroups/###/providers/Microsoft.KeyVault/vaults/foo"

    Deploys a new FinOps hub instance named MyHub using an existing Key Vault instance.

    .LINK
    https://aka.ms/ftk/Deploy-FinOpsHub
#>
function Deploy-FinOpsHub
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultId = '',

        [Parameter()]
        [string]
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [ValidateSet('Premium_LRS', 'Premium_ZRS')]
        [string]
        $StorageSku = 'Premium_LRS',

        [Parameter()]
        [hashtable]
        $Tags
    )

    try
    {
        $resourceGroupObject = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction 'SilentlyContinue'
        if (-not $resourceGroupObject)
        {
            if (Test-ShouldProcess $PSCmdlet $ResourceGroupName 'CreateResourceGroup')
            {
                $resourceGroupObject = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            }
        }

        $toolkitPath = Join-Path $env:temp -ChildPath 'FinOpsToolkit'
        if (Test-ShouldProcess $PSCmdlet $toolkitPath 'CreateTempDirectory')
        {
            New-Directory -Path $toolkitPath
        }
        Initialize-FinOpsHubDeployment -WhatIf:$WhatIfPreference

        if (Test-ShouldProcess $PSCmdlet $Version 'DownloadTemplate')
        {
            Save-FinOpsHubTemplate -Version $Version -Preview:$Preview -Destination $toolkitPath
            $bicepFile = Get-ChildItem -Path $toolkitPath -Include 'main.bicep' -Recurse | Where-Object -FilterScript { $_.FullName -like '*finops-hub-v*' }
            if (-not $bicepFile)
            {
                throw ($LocalizedData.Hub_Deploy_TemplateNotFound -f $toolkitPath)
            }

            $parameterSplat = @{
                TemplateFile            = $bicepFile.FullName
                TemplateParameterObject = @{
                    hubName    = $Name
                    storageSku = $StorageSku
                    existingKeyVaultId = $KeyVaultId
                }
            }

            if ($Tags -and $Tags.Keys.Count -gt 0)
            {
                $parameterSplat.TemplateParameterObject.Add('tags', $Tags)
            }
        }

        if (Test-ShouldProcess $PSCmdlet $ResourceGroupName 'DeployFinOpsHub')
        {
            Write-Verbose -Message ($LocalizedData.Hub_Deploy_Deploy -f $bicepFile.FullName, $resourceGroupObject.ResourceGroupName)
            return New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroupObject.ResourceGroupName
        }
    }
    catch
    {
        throw $_.Exception.Message
    }
    finally
    {
        Remove-Item -Path $toolkitPath -Recurse -Force -ErrorAction 'SilentlyContinue'
    }
}
