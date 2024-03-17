# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Creates a directory if it does not already exist.

    .PARAMETER Path
        Path to create directory.
#>
function New-Directory
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if (-not (Test-Path -Path $Path))
    {
        Write-Verbose -Message ($LocalizedData.NewDirectory_Execute -f $Path)
        $null = New-Item -ItemType 'Directory' -Path $Path
    }
}
