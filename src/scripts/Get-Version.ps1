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

    .PARAMETER AsDotNetVersion
    Optional. Indicates that the returned version should be in the format "x.x.x.x". Otherwise, semantic versioning is used. Deafult = false.

    .EXAMPLE
    ./Get-Version

    Gets the current version number.
#>
param(
    [switch]
    $AsDotNetVersion
)

$ver = (Get-Content (Join-Path $PSScriptRoot ../../package.json) | ConvertFrom-Json).version `
    -replace '^[^\d]*((\d+\.\d+)(\.\d+)?(-[a-z]+)?(\.\d+)?)[^\d]*$', '$1' `
    -replace '^(\d+\.\d+)(\.0)(-[a-z]+)?$', '$1$3' `
    -replace '^(\d+\.\d+)(\.0)?(-[a-z]+)?(\.\d+)?$', '$1$3$4' `
    -replace '(-[a-z]+)\.0$', '$1'

if ($AsDotNetVersion -and $ver.Contains('-'))
{
    $arr = (($ver -replace '-[^\.0-9]+', '') -split '\.') + @(0, 0)
    $arr[3] += 1000000000
    return $arr[0..3] -Join '.'
}

return $ver
