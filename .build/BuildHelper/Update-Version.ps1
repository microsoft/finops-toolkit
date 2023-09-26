# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Updates the current version.

    .PARAMETER Major
    Optional. Updates the major version number.

    .PARAMETER Minor
    Optional. Updates the minor version number.

    .PARAMETER Patch
    Optional. Updates the patch version number.

    .PARAMETER Prerelease
    Optional. Updates the prerelease version number.

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Default = "dev".

    .EXAMPLE
    ./Update-Version -Major

    Updates the major version number.

    .EXAMPLE
    ./Update-Version -Prerelease -Label "alpha"

    Updates the prerelease version number with an "alpha" preview label.
#>
function Update-Version {
    param
    (
        [Parameter()]
        [switch]
        $Major,

        [Parameter()]
        [switch]
        $Minor,

        [Parameter()]
        [switch]
        $Patch,

        [Parameter()]
        [switch]
        $Prerelease,
    
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [ValidateSet($null, '', 'dev', 'alpha', 'preview')]
        [string]
        $Label = 'dev'
    )
    
    $update = if ($Major) { "major" } elseif ($Minor) { "minor" } elseif ($Patch) { "patch" } elseif ($Prerelease) { "prerelease" }
    $label = if (-not $Label) { "dev" } else { $Label.ToLower() -replace '[^a-z]', '' }
    if ($update) {
        $null = npm --no-git-tag-version --preid $Label version $update
    }
    return Get-Version
}
