# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Import the localized Data
$script:localizedData = Import-LocalizedData -FileName 'FinOpsToolkit.strings.psd1' -BaseDirectory $PSScriptRoot

#region Private functions
<#
    .SYNOPSIS
        Creates a directory if it does not already exist.

    .PARAMETER Path
        Path to create directory.
#>
function New-Directory
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path))
    {
        Write-Verbose -Message ($LocalizedData.NewDirectory -f $Path)
        $null = New-Item -ItemType 'Directory' -Path $Path
    }
}

<#
    .SYNOPSIS
        Saves a released version of the FinOps hub bicep template to local disk.

    .PARAMETER Version
        Version of the FinOps hub to download. Defaults to latest.

    .PARAMETER Destination
        Path to store the download. Defaults to env:temp.

    .EXAMPLE
        Save-FinOpsHubTemplate

        Downloads the latest version of FinOps hub template to current users' temp folder.

    .EXAMPLE
        Save-FinOpsHubTemplate -Version '1.0.0' -Destination 'C:\myHub'

        Downloads version 1.0.0 of FinOpsHub template to c:\myHub directory.
#>
function Save-FinOpsHubTemplate
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [string]
        $Destination = $env:temp
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try
    {
        New-Directory -Path $Destination
        $releases = Get-FinOpsToolkitVersion -Latest:$($Version -eq 'Latest') -Preview:$Preview

        if ($Version -eq 'Latest')
        {
            $release = $releases | Select-Object -First 1
        }
        else
        {
            $release = $releases | Where-Object -FilterScript {$_.Version -eq $Version}
        }

        foreach ($asset in $release.Assets)
        {
            Write-Verbose -Message ($script:localizedData.FoundAsset -f $asset.Name)
            $saveFilePath = Join-Path -Path $Destination -ChildPath $asset.Name
            if (Test-Path -Path $saveFilePath)
            {
                Remove-Item -Path $saveFilePath -Recurse -Force
            }

            $null = Invoke-Webrequest -Uri $asset.Url -OutFile $saveFilePath -Verbose:$false
            if ([System.IO.Path]::GetExtension($saveFilePath) -eq '.zip')
            {
                Write-Verbose -Message ($script:localizedData.ExpandingZip -f $saveFilePath)
                Expand-Archive -Path $saveFilePath -DestinationPath ($saveFilePath -replace '.zip', '')
                Remove-Item -Path $saveFilePath -Recurse -Force
            }
        }
    }
    catch
    {
        throw $_.Exception.Message
    }
    finally
    {
        $ProgressPreference = $progress
    }
}
#endregion Private functions

#region Public functions
<#
    .SYNOPSIS
        Retrieves available version numbers of the FinOps toolkit.

    .PARAMETER Latest
        Will only return the latest version number of the FinOps toolkit.

    .PARAMETER Preview
        Includes pre-releases.

    .EXAMPLE
        Get-FinOpsToolkitVersion

        Returns all available released version numbers of the FinOps toolkit.

    .EXAMPLE
        Get-FinOpsToolkitVersion -Latest

        Returns only the latest version number of the FinOps toolkit.
#>
function Get-FinOpsToolkitVersion
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch]
        $Latest,

        [Parameter()]
        [switch]
        $Preview
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $releaseUri = 'https://api.github.com/repos/microsoft/finops-toolkit/releases'

    try
    {
        [array]$releases = Invoke-WebRequest -Uri $releaseUri | ConvertFrom-Json | Where-Object { ($Preview) -or (-not $_.prerelease) }

        if ($Latest)
        {
            $releases = $releases | Select-Object -First 1
            Write-Verbose -Message ($script:localizedData.FoundLatestRelease -f $releases.tag_name)
        }

        $output = @()
        foreach ($release in $releases)
        {
            $properties = [ordered]@{
                Name       = $release.name
                PreRelease = $release.prerelease
                Version    = $release.tag_name
                Url        = $release.url
                Assets     = @()
            }

            foreach ($asset in $release.assets)
            {
                $properties.Assets += @{
                    Name = $asset.name
                    Url  = $asset.browser_download_url
                }
            }

            $output += New-Object -TypeName 'PSObject' -Property $properties
        }

        return $output
    }
    catch
    {
        throw $_.Exception.Message
    }
    finally
    {
        $ProgressPreference = $progress
    }
}

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
#endregion Public functions

Export-ModuleMember -Function 'Get-FinOpsToolkitVersion', 'Deploy-FinOpsHub'
