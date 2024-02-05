# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Updates the current version.

    .PARAMETER Major
    Optional. Updates the major version number (x.0).

    .PARAMETER Minor
    Optional. Updates the minor version number (0.x).

    .PARAMETER Patch
    Optional. Updates the patch version number (0.0.x).

    .PARAMETER Prerelease
    Optional. Updates the prerelease version number (0.0.0-ooo.x).

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Allowed: dev, rc, alpha, preview. Default = "dev".

    .EXAMPLE
    ./Update-Version -Major

    Updates the major version number.

    .EXAMPLE
    ./Update-Version -Prerelease -Label "alpha"

    Updates the prerelease version number with an "alpha" preview label.
#>
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
    [ValidateSet($null, '', 'dev', 'alpha', 'rc', 'preview')]
    [string]
    $Label = 'dev',

    [string]
    $Version
)

$update = if ($Major) { "major" } elseif ($Minor) { "minor" } elseif ($Patch) { "patch" } elseif ($Prerelease) { "prerelease" }
if ($update)
{
    Write-Verbose "Updating $update version."
}
elseif ($Version)
{
    $update = $Version
    Write-Verbose "Updating to version $update."
}

$newLabel = if (-not $Label) { "dev" } else { $Label.ToLower() -replace '[^a-z]', '' }
if ($update -eq "prerelease")
{
    Write-Verbose "Using label '$newLabel'."
}

# Only update version if requested
if ($update -or $Version)
{
    $null = npm --no-git-tag-version --preid $newLabel version $update
}

$ver = & "$PSScriptRoot/Get-Version"

if ($update -or $Version)
{
    Write-Verbose "Updated to version $ver."
}

return $ver
