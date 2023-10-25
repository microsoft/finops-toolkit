# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Packages all toolkit templates for release.

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
Param(
    [Parameter(Position = 0)][string]$Template = "*",
    [switch]$Build
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Build toolkit if requested
if ($Build) {
    Write-Verbose "Building $(if ($Template -eq "*") { "all templates" } else { "the $Template template" })..."
    & "$PSScriptRoot/Build-Toolkit" $Template
}

$relDir = "$PSScriptRoot/../../release"

# Validate template
if ($Template -ne "*" -and -not (Test-Path $relDir)) {
    Write-Error "$Template template not found. Please confirm template name."
    return
}

Write-Host "Packaging templates..."

# Package templates
$version = & "$PSScriptRoot/Get-Version"

Write-Verbose "Removing existing ZIP files..."
Remove-Item "$relDir/*-$version.zip" -Force

$templates = Get-ChildItem $relDir -Directory `
| ForEach-Object {
    Write-Verbose ("Packaging $_" -replace (Get-Item $relDir).FullName, '.')
    $path = $_
    $versionSubFolder = (Join-Path $path $version)
    $zip = Join-Path (Get-Item $relDir) "$($path.Name)-$version.zip"

    Write-Verbose "Checking for a nested version folder: $versionSubFolder"
    if ((Test-Path -Path $versionSubFolder -PathType Container) -eq $true) {
        Write-Verbose "  Switching to sub folder"
        $path = $versionSubFolder
    }
    
    # Skip if template is a Bicep Registry module
    Write-Verbose "Checking version.json to see if it's targeting the Bicep Registry"
    if (Test-Path $path/version.json) {
        $versionSchema = (Get-Content "$path\version.json" -Raw | ConvertFrom-Json | Select-Object -ExpandProperty '$schema')
        if ($versionSchema -like '*bicep-registry-module*') {
            Write-Verbose "Skipping Bicep Registry module (not included in releases)"
            return;
        }
    }

    Write-Verbose ("Compressing $path to $zip" -replace (Get-Item $relDir).FullName, '.')
    Compress-Archive -Path "$path/*" -DestinationPath $zip
    return $zip
}
Write-Host "✅ $($templates.Count) templates"

# Copy open data files
Write-Verbose "Copying open data files..."
Copy-Item "$PSScriptRoot/../open-data/*.csv" $relDir
Write-Host "✅ $((Get-ChildItem "$relDir/*.csv").Count) open data files"

# Open Power BI reports
$pbi = Get-ChildItem "$PSScriptRoot/../power-bi/*.pbip"
Write-Host "⚠️ $($pbi.Count) Power BI reports must be converted manually... Opening..."
$pbi | Invoke-Item

Write-Host '...done!'
Write-Host ''
