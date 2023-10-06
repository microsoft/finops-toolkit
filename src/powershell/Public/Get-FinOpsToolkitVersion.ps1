# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets available versions from published FinOps toolkit releases.

    .DESCRIPTION
    The Get-FinOpsToolkitVersions command calls GitHub to retrieve all toolkit releases, then filters the list based on the specified options.

    .PARAMETER Latest
    Optional. Indicates that only the most recent release should be returned. Default = false.

    .PARAMETER Preview
    Optional. Indicates that preview releases should also be included. Default = false.

    .EXAMPLE
    Get-FinOpsToolkitVersion

    Returns all stable (non-preview) release versions.

    .EXAMPLE
    Get-FinOpsToolkitVersion -Latest

    Returns only the latest stable (non-preview) release version.

    .EXAMPLE
    Get-FinOpsToolkitVersion -Preview

    Returns all release versions, including preview releases.

    .LINK
    https://aka.ms/ftk/Get-FinOpsToolkitVersion
#>
function Get-FinOpsToolkitVersion
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Scope='Function')]
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
                Version    = $release.tag_name -replace '^v', ''
                Url        = $release.url
                Files      = @()
            }

            foreach ($asset in $release.assets)
            {
                $properties.Files += @{
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
