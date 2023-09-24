# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets the current version.

    .DESCRIPTION
    Run this from the /src/scripts folder.

    .PARAMETER Template
    Optional. Name of the template or module to package. Default = * (all).

    .PARAMETER Build
    Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false.

    .EXAMPLE
    ./Package-Toolkit

    Generates ZIP files for each template using an existing build.

    .EXAMPLE
    ./Package-Toolkit -Build

    Builds the latest code and generates ZIP files for each template.
#>
function Get-Version {
    param
    (
        [switch]
        $Major,

        [switch]
        $Minor,

        [switch]
        $Patch,

        [switch]
        $Prerelease,
    
        [AllowEmptyString()]
        [AllowNull()]
        [ValidateSet($null, '', 'dev', 'alpha', 'preview')]
        [string]
        $Label = 'dev'
    )
    
    $update = if ($Major) { "major" } elseif ($Minor) { "minor" } elseif ($Patch) { "patch" }
    $ver = $null
    if ($update) {
        $ver = npm --no-git-tag-version version $update
    } elseif ($Prerelease) {
        $label = if (-not $Label) { "dev" } else { $Label.ToLower() -replace '[^a-z]', '' }
        $ver = npm --no-git-tag-version --preid $Label version prerelease
    } else {
        $ver = (npm pkg get version).Trim('"')
    }

    # Remove trailing 0s from version (keep first 2 + prerelease name)
    return $ver -replace '(\d+\.\d+)(\.\d+\-[^\.]+)?(\.0)?\.0$', '$1$2'
}
