# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a FinOps hub instance.

    .DESCRIPTION
    The Deploy-FinOpsHub command creates a new FinOps hub instance. The FinOps hub template is downloaded from GitHub.

    Before running this command, register the Microsoft.EventGrid and Microsoft.CostManagementExports providers. Resource provider registration must be done by a subscription contributor.

    .PARAMETER Name
    Required. Name of the FinOps hub instance.

    .PARAMETER ResourceGroupName
    Required. Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
    Required. Azure location to execute the deployment from.

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
            if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'CreateResourceGroup'))
            {
                $resourceGroupObject = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            }
        }

        $toolkitPath = Join-Path $env:temp -ChildPath 'FinOps'
        if ($PSCmdlet.ShouldProcess($toolkitPath, 'CreateDirectory'))
        {
            New-Directory -Path $toolkitPath
        }
        if($PSCmdlet.ShouldProcess('FinOps hub deployment','Initialize'))
        {
            Initialize-FinOpsToolkit 
        }

        if ($PSCmdlet.ShouldProcess($Version, 'DownloadTemplate'))
        {
            Save-FinOpsHubTemplate -Version $Version -Preview:$Preview -Destination $toolkitPath
            $toolkitFile = Get-ChildItem -Path $toolkitPath -Include 'main.bicep' -Recurse | Where-Object -FilterScript {$_.FullName -like '*finops-hub-v*'}
            if (-not $toolkitFile)
            {
                throw ($LocalizedData.TemplateNotFound -f $toolkitPath)
            }

            $parameterSplat = @{
                TemplateFile            = $toolkitFile.FullName
                TemplateParameterObject = @{
                    hubName    = $Name
                    storageSku = $StorageSku
                }
            }

            if ($Tags -and $Tags.Keys.Count -gt 0)
            {
                $parameterSplat.TemplateParameterObject.Add('tags', $Tags)
            }
        }

        if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'DeployFinOpsHub'))
        {
            Write-Verbose -Message ($LocalizedData.DeployFinOpsHub -f $toolkitFile.FullName, $resourceGroupObject.ResourceGroupName)
            $deployment = New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroupObject.ResourceGroupName

            return $deployment
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
