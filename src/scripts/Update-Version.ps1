# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Updates the current version.

    .PARAMETER Major
    Optional. Increments the major version number (x.0).

    .PARAMETER Minor
    Optional. Increments the minor version number (0.x).

    .PARAMETER Patch
    Optional. Increments the patch version number (0.0.x).

    .PARAMETER Prerelease
    Optional. Increments the prerelease version number (0.0.0-ooo.x).

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Allowed: dev, rc, alpha, preview. Default = "dev".

    .PARAMETER Version
    Optional. Sets the version number to an explicit value.

    .EXAMPLE
    ./Update-Version -Major

    Increments the major version number.

    .EXAMPLE
    ./Update-Version -Prerelease -Label "alpha"

    Increments the prerelease version number with an "alpha" preview label.
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

# Calculate new version number
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

# Determine label
$newLabel = if (-not $Label) { "dev" } else { $Label.ToLower() -replace '[^a-z]', '' }
if ($update -eq "prerelease")
{
    Write-Verbose "Using label '$newLabel'."
}

# Only update version if requested
if ($update -or $Version)
{
    # Update version in NPM
    Write-Verbose "Updating NPM version..."
    $null = npm --no-git-tag-version --preid $newLabel version $update
}

$ver = & "$PSScriptRoot/Get-Version"

if ($update -or $Version)
{
    Write-Verbose "Updated to version $ver."
}

# Update version in secondary files, if needed
if ($update -or $Version)
{
    # Update version in ftkver.txt files (templates, modules, docs)
    Write-Verbose "Updating ftkver.txt files..."
    Get-ChildItem ../.. -Include ftkver.txt -Recurse `
    | ForEach-Object {
        Write-Verbose "- $($_.FullName.Replace((Get-Item ../..).FullName + [IO.Path]::DirectorySeparatorChar, ''))"
        $ver | Out-File $_ -NoNewline
    }

    # Update version in PowerShell
    Write-Verbose "Updating PowerShell Get-VersionNumber..."
    & {
        Write-Output "# Copyright (c) Microsoft Corporation."
        Write-Output "# Licensed under the MIT License."
        Write-Output ""
        Write-Output "function Get-VersionNumber"
        Write-Output "{"
        Write-Output "    param()"
        Write-Output "    return '$ver'"
        Write-Output "}"
    } | Out-File "$PSScriptRoot/../PowerShell/Private/Get-VersionNumber.ps1" -Encoding ascii -Append:$false
}

return $ver
