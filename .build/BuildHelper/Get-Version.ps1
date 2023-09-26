# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets the current version.

    .EXAMPLE
    ./Get-Version

    Gets the current version number.
#>
function Get-Version {
    # Remove trailing 0s from version (keep first 2 + prerelease name)
    return (Get-Content (Join-Path $tmp ../../package.json) | ConvertFrom-Json).version -replace '(\d+\.\d+)(\.\d+\-[^\.]+)?(\.0)?\.0$', '$1$2'
}
