# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Normalizes a version string so it can be safely cast to [version].

    .DESCRIPTION
    The ConvertTo-NormalizedVersion command appends a ".0" minor version when the given string has no "." in it. This is needed because GitHub release tags in this repo are published as single-component strings (e.g. "13", "14", "15"), but .NET's [version] type requires at least a major.minor value and throws when cast from a single-component string.

    .PARAMETER Version
    Required. Version string to normalize (e.g. "13" or "0.4").

    .EXAMPLE
    ConvertTo-NormalizedVersion -Version '13'

    Returns '13.0'.

    .EXAMPLE
    ConvertTo-NormalizedVersion -Version '0.4'

    Returns '0.4' unchanged.
#>
function ConvertTo-NormalizedVersion
{
    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Version
    )

    if ($Version -notmatch '\.')
    {
        return "$Version.0"
    }

    return $Version
}
