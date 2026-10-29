# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets the current version.

    .DESCRIPTION
    The Get-Version command gets the current version from NPM (stored in package.json).

    After getting the version from NPM, we also do the following to clean up the value:
    1. Remove quotes
    2. Strip control characters
    3. Remove patch version when 0 (keep major.minor and label)

    .PARAMETER AsTag
    Optional. Returns the version as a git tag (e.g., "v13" instead of "13.0"). Default = false.

    .PARAMETER AsSemVer
    Optional. Returns a full three-part semantic version (e.g., "13.0.0" instead of "13.0") for files that require it, like marketplace.json. Default = false.

    .PARAMETER AsDotNetVersion
    Optional. Indicates that the returned version should be in the format "x.x.x.x". Otherwise, semantic versioning is used. Default = false.

    .EXAMPLE
    ./Get-Version

    Gets the current version number.

    .EXAMPLE
    ./Get-Version -AsTag

    Gets the version as a git tag (e.g., "v13" instead of "13.0").
#>
param(
    [switch]
    $AsTag,

    [switch]
    $AsSemVer,

    [switch]
    $AsDotNetVersion
)

$ver = (Get-Content (Join-Path $PSScriptRoot ../../package.json) | ConvertFrom-Json).version `
    -replace '^[^\d]*((\d+\.\d+)(\.\d+)?(-[a-z]+)?(\.\d+)?)[^\d]*$', '$1' `
    -replace '^(\d+\.\d+)(\.0)(-[a-z]+)?$', '$1$3' `
    -replace '^(\d+\.\d+)(\.0)?(-[a-z]+)?(\.\d+)?$', '$1$3$4' `
    -replace '(-[a-z]+)\.0$', '$1'

if ($AsTag)
{
    return 'v' + (($ver -replace '-.*$', '') -replace '\.0$', '')
}

if ($AsSemVer)
{
    # Pad major.minor to major.minor.patch and keep any prerelease label
    $base = ($ver -replace '-.*$', '') -split '\.'
    while ($base.Count -lt 3) { $base += '0' }
    return ($base[0..2] -join '.') + ($ver -replace '^[^-]*', '')
}

if ($AsDotNetVersion -and $ver.Contains('-'))
{
    $arr = (($ver -replace '-[^\.0-9]+', '') -split '\.') + @(0, 0)
    $arr[3] += 1000000000
    return $arr[0..3] -join '.'
}

return $ver
