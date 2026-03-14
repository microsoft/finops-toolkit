# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates a new directory if it doesn't already exist. Does not return an object.

    .PARAMETER Path
    Path of the directory to create.

    .EXAMPLE
    ./New-Directory foo

    Creates the "foo" directory.
#>
Param (
    [string] $Path
)

Test-Path $Path `
| Where-Object { -not $_ } `
| New-Item $Path -ItemType Directory `
| Out-Null
