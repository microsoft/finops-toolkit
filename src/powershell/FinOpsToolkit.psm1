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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
        $Version = 'latest',

        [Parameter()]
        [switch]
        $Preview,

        [Parameter()]
        [string]
        $Destination = $env:temp,

        [Parameter()]
        [switch]
        $Force
    )

    New-Directory -Path $Destination
    $releases = Get-FinOpsToolkitVersion -Latest:$($Version -eq 'Latest') -Preview:$Preview

    if ($Version -eq 'Latest')
    {
        $release = $releases | Select-Object -First 1
        Write-Verbose -Message ($script:localizedData.FoundLatestRelease -f $release.Version)
    }
    else
    {
        $release = $releases | Where-Object -FilterScript {$_.Version -eq $Version}
    }

    foreach ($asset in $release.Assets)
    {
        Write-Verbose -Message ($script:localizedData.FoundAsset -f $asset.Name)
        if ([System.IO.Path]::GetExtension($asset.Name) -eq '.nupkg')
        {
            $saveFileName = $asset.Name -replace '.nupkg', '.zip'
        }
        else
        {
            $saveFileName = $asset.Name
        }

        $saveFilePath = Join-Path -Path $Destination -ChildPath $saveFileName
        if ($Force -and (Test-Path -Path $saveFilePath))
        {
            Remove-Item -Path $saveFilePath
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
        Get-FinOpsToolkitVersions

        Returns all available released version numbers of the FinOps toolkit.

    .EXAMPLE
        Get-FinOpsToolkitVersions -Latest

        Returns only the latest version number of the FinOps toolkit.
#>
function Get-FinOpsToolkitVersion
{
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

    $releaseUri = 'https://api.github.com/repos/microsoft/cloud-hubs/releases'
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
#endregion Public functions

Export-ModuleMember -Function 'Get-FinOpsToolkitVersions'
