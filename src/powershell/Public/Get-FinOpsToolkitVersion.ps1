# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
