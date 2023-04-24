data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
    DeployFinOpsHub = Deploying hub from template '{0}' to resource group '{1}'.
    ExpandingZip = Expanding zip '{0}'.
    FoundAsset = Found asset '{0}'.
    FoundLatestRelease = Found latest release '{0}'.
    NewDirectory = Creating directory '{0}'.
    NotSignedIn = Not logged into Azure. Launching 'Login-AzAccount'.
    VersionNotFound = Could not find version '{0}' of FinOps toolkit. Run 'Get-FinOpsToolkitVersions' for available versions.
'@
}

#region Helpers
<#
    .SYNOPSIS
        Gets Azure context for logged in user. Will prompt for login if not currently logged in.
#>
function Assert-AzContext
{
    [CmdletBinding()]
    param()
    $context = Get-AzContext
    if ($null -eq $context)
    {
        Write-Warning -Message ($LocalizedData.NotSignedIn)
        $null = Login-AzAccount
        $context = Get-AzContext
    }

    Write-Verbose -Message ($LocalizedData.LoggedIn -f $context.Subscription.Name, $context.Subscription.Id)
    return $context
}

<#
    .SYNOPSIS
        Creates a directory if it does not already exist.
        
    .PARAMETER Path
        Path to create directory.
#>
function New-Directory
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path))
    {
        Write-Verbose -Message ($LocalizedData.NewDirectory -f $Destination)
        $null = New-Item -ItemType 'Directory' -Path $Destination
    }
}
#endregion Helpers

#region Public
<#
    .SYNOPSIS
        Retrieves available version numbers of the FinOps Hub template.
        
    .PARAMETER Latest
        Will only return the latest version number of FinOps Hub template.
        
    .EXAMPLE
        Get-FinOpsToolkitVersions
        
        Returns all available version numbers of FinOps Hub templates.
        
    .EXAMPLE
        Get-FinOpsToolkitVersions -Latest
        
        Returns only the latest version number of the FinOps Hub templates.
#>
function Get-FinOpsToolkitVersions
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch]
        $Latest
    )
    
    $releaseUri = 'https://api.github.com/repos/microsoft/cloud-hubs/releases'
    $releases = (Invoke-WebRequest -Uri $releaseUri -Verbose:$false | ConvertFrom-Json)
    
    if ($Latest)
    {
        $releases = $releases | Select-Object -First 1
        Write-Verbose -Message ($LocalizedData.FoundLatestRelease -f $releases.tag_name)
    }
    
    return $release.tag_name
}

<#
    .SYNOPSIS
        Saves a released version of the FinOps hub bicep template to local disk.
        
    .PARAMETER Tag
        Version of the FinOps hub to download. Defaults to latest.
        
    .PARAMETER Destination
        Path to store the download. Defaults to env:temp.
        
    .PARAMETER Force
        Optional. Will overwrite an existing file.

    .EXAMPLE
        Save-FinOpsHubTemplate

        Downloads the latest version of FinOps hub template to current users' temp folder.

    .EXAMPLE
        Save-FinOpsHubTemplate -Tag '1.0.0' -Destination 'C:\myHub' -Force

        Downloads version 1.0.0 of FinOpsHub template to c:\myHub directory. It will overwrite an existing 1.0.0.zip file if it exists.
#>
function Save-FinOpsHubTemplate
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Tag = 'latest',

        [Parameter()]
        [string]
        $Destination = $env:temp,

        [Parameter()]
        [switch]
        $Force
    )
    
    New-Directory -Path $Destination

    $lookupUri = 'https://api.github.com/repos/microsoft/cloud-hubs/releases'
    $releases = (Invoke-WebRequest -Uri $lookupUri -Verbose:$false | ConvertFrom-Json)

    if ($Tag -eq 'Latest')
    {
        $release = $releases | Select-Object -First 1
        $Tag = $release.tag_name
        Write-Verbose -Message ($LocalizedData.FoundLatestRelease -f $Tag)
    }
    else
    {
        $release = $releases | Where-Object -FilterScript {$_.tag_name -eq $Tag}
    }

    $downloadFile = $release.assets.name
    Write-Verbose -Message ($LocalizedData.FoundAsset -f $downloadFile)
    if ([System.IO.Path]::GetExtension($downloadFile) -eq '.nupkg')
    {
        $saveFileName = $downloadFile -replace '.nupkg', '.zip'
    }
    else
    {
        $saveFileName = $downloadFile
    }

    $saveFilePath = Join-Path -Path $Destination -ChildPath $saveFileName
    if ($Force -and (Test-Path -Path $saveFilePath))
    {
        Remove-Item -Path $saveFilePath
    }

    $downloadUri = $release.assets.browser_download_url
    $null = Invoke-Webrequest -Uri $downloadUri -OutFile $saveFilePath -Verbose:$false
    if ([System.IO.Path]::GetExtension($saveFilePath) -eq '.zip')
    {
        Write-Verbose -Message ($LocalizedData.ExpandingZip -f $saveFilePath)
        Expand-Archive -Path $saveFilePath -DestinationPath ($saveFilePath -replace '.zip', '')
        Remove-Item -Path $saveFilePath -Recurse -Force
    }
}

<#
    .SYNOPSIS
        Deploys a FinOps hub instance.

    .PARAMETER HubName
        Name of the FinOps hub instance.

    .PARAMETER ResourceGroupName
        Name of the resource group to deploy to. Will be created if it doesn't exist. Only used for ResourceGroup scope.

    .PARAMETER Location
        Azure location to execute the deployment from.

    .PARAMETER HubVersion
        Defaults to latest. Version of FinOps hub template to use.

    .PARAMETER StorageSku
        Optional. Storage account SKU. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage.

    .PARAMETER Tags
        Optional. Tags for all resources.

    .PARAMETER ExportScopes
        Optional. List of scope IDs to create exports for.

    .EXAMPLE
        Deploy-FinOpsHub -HubName MyHub -ResourceGroupName MyExistingResourceGroup -Location westus
        
        Deploys a new FinOps hub instance named MyHub to an existing resource group name MyExistingResourceGroup.
    
    .EXAMPLE
        Deploy-FinOpsHub -HubName MyHub -Location westus -HubVersion 1.0.0
        
        Deploys a new FinOps hub instance named MyHub using version 1.0.0 of the template.
#>
function Deploy-FinOpsHub
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $HubName,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        [Parameter()]
        [string]
        $HubVersion = 'latest',

        [Parameter()]
        [ValidateSet('Premium_LRS', 'Premium_ZRS')]
        [string]
        $StorageSku,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [array]
        $ExportScopes
    )

    $toolkitPath = Join-Path -Path $env:temp -ChildPath 'FinOpsHub'
    $availableVersions = Get-FinOpsToolkitVersions
    if ($HubVersion -ne 'latest' -and $availableVersions -notcontains $HubVersion)
    {
        throw ($LocalizedData.VersionNotFound -f $HubVersion)
    }

    Save-GitHubRelease -RepositoryName 'microsoft/cloud-hubs' -Tag $HubVersion -Destination $toolkitPath
    $toolkitFile = Get-ChildItem -Path $toolkitPath -Include 'finops-hub/main.bicep' -Recurse
    $parameterSplat = @{
        TemplateFile            = $toolkitFile.FullName
        TemplateParameterObject = @{
            HubName = $HubName
        }
    }

    foreach ($parameter in @('StorageSku', 'Tags', 'ExportScopes'))
    {
        if ($PSBoundParameters.ContainsKey($parameter))
        {
            $parameterSplat.TemplateParameterObject.Add($parameter, $PSBoundParameters[$parameter])
        }
    }

    try
    {
        $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction 'Stop'
    }
    catch
    {
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
    
    try
    {
        Write-Verbose -Message ($LocalizedData.DeployFinOpsHub -f $Path, $resourceGroup.ResourceGroupName)
        $deployment = New-AzResourceGroupDeployment @parameterSplat -ResourceGroupName $resourceGroup.ResourceGroupName

        return $deployment
    }
    catch
    {
        throw $_.Exception
    }
    finally
    {
        Remove-Item -Path $toolkitPath
    }
}
#endregion

Export-ModuleMember -Function 'Deploy-FinOpsHub', 'Get-FinOpsToolkitVersions', 'Save-FinOpsHubTemplate'
