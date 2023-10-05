# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Deploys a FinOps hub instance.

    .PARAMETER Name
        Name of the FinOps hub instance.

    .PARAMETER ResourceGroup
        Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
        Azure location to execute the deployment from.

    .PARAMETER Version
        Optional. Version of FinOps hub template to use. Defaults = "latest".

    .PARAMETER Preview
        Optional. Indicates that a pre-release version of FinOps hub can be used when -Version is "latest".

    .PARAMETER StorageSku
        Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default = "Premium_LRS".

    .PARAMETER Tags
        Optional. Tags for all resources.

    .EXAMPLE
        Deploy-FinOpsHub -Name MyHub -ResourceGroup MyExistingResourceGroup -Location westus

        Deploys a new FinOps hub instance named MyHub to an existing resource group named MyExistingResourceGroup.

    .EXAMPLE
        Deploy-FinOpsHub -Name MyHub -Location westus -Version 0.0.1

        Deploys a new FinOps hub instance named MyHub using version 0.0.1 of the template.
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
        $ResourceGroup,

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
        $resourceGroupObject = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction 'SilentlyContinue'
        if (-not $resourceGroupObject)
        {
            if ($PSCmdlet.ShouldProcess($ResourceGroup, 'CreateResourceGroup'))
            {
                $resourceGroupObject = New-AzResourceGroup -Name $ResourceGroup -Location $Location
            }
        }

        $toolkitPath = Join-Path $env:temp -ChildPath 'FinOps'
        if ($PSCmdlet.ShouldProcess($toolkitPath, 'CreateDirectory'))
        {
            New-Directory -Path $toolkitPath
        }
        if($PSCmdlet.ShouldProcess('FinOps Toolkit Init','Initialization'))
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

        if ($PSCmdlet.ShouldProcess($ResourceGroup, 'DeployFinOpsHub'))
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
