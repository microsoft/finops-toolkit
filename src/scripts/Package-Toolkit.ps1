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

    .PARAMETER PowerBI
    Optional. Indicates whether to open Power BI files as part of the packaging process. Default = false.

    .PARAMETER Preview
    Optional. Indicates that the template(s) should be saved as a preview only. Does not package other files. Default = false.

    .EXAMPLE
    ./Package-Toolkit

    Generates ZIP files for each template using an existing build.

    .EXAMPLE
    ./Package-Toolkit -Build

    Builds the latest code and generates ZIP files for each template.

    .EXAMPLE
    ./Package-Toolkit -Build -PowerBI

    Builds the latest code, generates ZIP files for each template, and opens Power BI projects to be saved as PBIX files.
#>
Param(
    [Parameter(Position = 0)][string]$Template = "*",
    [switch]$Build,
    [switch]$PowerBI,
    [switch]$Preview
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Build toolkit if requested
if ($Build)
{
    Write-Verbose "Building $(if ($Template -eq "*") { "all templates" } else { "the $Template template" })..."
    & "$PSScriptRoot/Build-Toolkit" $Template
}

$relDir = "$PSScriptRoot/../../release"
$deployDir = "$PSScriptRoot/../../docs/deploy"

# Validate template
if ($Template -ne "*" -and -not (Test-Path $relDir))
{
    Write-Error "$Template template not found. Please confirm template name."
    return
}

# Package templates
$version = & "$PSScriptRoot/Get-Version"
Write-Host "Packaging $(if ($Template) { "$Template v$version template" } else { "v$version templates" })..."

$isPrerelease = $version -like '*-*'

Write-Verbose "Removing existing ZIP files..."
Remove-Item "$relDir/*.zip" -Force

$templates = Get-ChildItem "$relDir/$Template*" -Directory `
| ForEach-Object {
    Write-Verbose ("Packaging $_" -replace (Get-Item $relDir).FullName, '.')
    $srcPath = $_
    $templateName = $srcPath.Name
    $versionSubFolder = (Join-Path $srcPath $version)
    $zip = Join-Path (Get-Item $relDir) "$templateName-v$version.zip"

    Write-Verbose "Checking for a nested version folder: $versionSubFolder"
    if ((Test-Path -Path $versionSubFolder -PathType Container) -eq $true)
    {
        Write-Verbose "  Switching to sub folder"
        $srcPath = $versionSubFolder
    }

    # Skip if template is a Bicep Registry module
    Write-Verbose "Checking version.json to see if it's targeting the Bicep Registry"
    if (Test-Path $srcPath/version.json)
    {
        $versionSchema = (Get-Content "$srcPath\version.json" -Raw | ConvertFrom-Json | Select-Object -ExpandProperty '$schema')
        if ($versionSchema -like '*bicep-registry-module*')
        {
            Write-Verbose "Skipping Bicep Registry module (not included in releases)"
            return
        }
    }

    Write-Verbose "Updating $templateName deployment files in docs..."

    function Copy-DeploymentFiles($suffix)
    {
        $packageManifestPath = "$srcPath/package-manifest.json"
        if (Test-Path $packageManifestPath)
        {
            # Read files/directories from package-manifest.json
            $packageManifest = Get-Content $packageManifestPath -Raw | ConvertFrom-Json

            # Create release directory
            $targetDir = "$deployDir/$templateName/$suffix"
            & "$PSScriptRoot/New-Directory" $targetDir
            
            # Copy files and directories
            $packageManifest.deployment.Files | ForEach-Object { Copy-Item "$srcPath/$($_.source)" "$targetDir/$($_.destination)" -Force }
            $packageManifest.deployment.Directories | ForEach-Object {
                & "$PSScriptRoot/New-Directory" "$targetDir/$($_.destination)"
                Get-ChildItem "$srcPath/$($_.source)" | Copy-Item -Destination "$targetDir/$($_.destination)" -Recurse -Force
            }
        }
        else
        {
            # Copy azuredeploy.json to docs/deploy folder
            Copy-Item "$srcPath/azuredeploy.json" "$deployDir/$templateName-$suffix.json"
            Copy-Item "$srcPath/createUiDefinition.json" "$deployDir/$templateName-$suffix.ui.json"
        }
    }

    if ($Preview)
    {
        Copy-DeploymentFiles "preview"
    }
    else
    {
        Copy-DeploymentFiles $version
        Copy-DeploymentFiles "latest"
    }

    Write-Verbose ("Compressing $srcPath to $zip" -replace (Get-Item $relDir).FullName, '.')
    Compress-Archive -Path "$srcPath/*" -DestinationPath $zip
    return $zip
}
Write-Host "✅ $($templates.Count) template$(if ($templates.Count -ne 1) { 's' })"
Write-Host "ℹ️ Deployment files updated... Please commit the changes manually..."

# Only package remaining files if not preview
if (-not $Preview)
{
    # Copy open data files
    Write-Verbose "Copying open data files..."
    Copy-Item "$PSScriptRoot/../open-data/*.csv" $relDir
    Copy-Item "$PSScriptRoot/../open-data/*.json" $relDir
    Write-Host "✅ $((@(Get-ChildItem "$relDir/*.csv") + @(Get-ChildItem "$relDir/*.json")).Count) open data files"
    
    # Package sample data files together
    Write-Verbose "Packaging open data files..."
    Get-ChildItem -Path "$PSScriptRoot/../open-data" -Directory `
    | ForEach-Object {
        $dir = $_
        Compress-Archive -Path "$dir/*.*" -DestinationPath "$relDir/$($dir.BaseName).zip"
        Write-Host "✅ $((Get-ChildItem "$dir/*.*").Count) $($dir.BaseName) files"
    }
    
    # Copy PBIX files
    Write-Verbose "Copying PBIX files..."
    Copy-Item "$PSScriptRoot/../power-bi/*.pbix" $relDir -Force
    Write-Host "✅ $((Get-ChildItem "$PSScriptRoot/../power-bi/*.pbix").Count) PBIX files"
    
    # Open Power BI projects
    $pbi = Get-ChildItem "$PSScriptRoot/../power-bi/*.pbip"
    if ($PowerBI)
    {
        Write-Host "ℹ️ $($pbi.Count) Power BI projects must be converted manually... Opening..."
        $pbi | Invoke-Item
    }
    elseif ($isPrerelease)
    {
        Write-Host "✖️ Skipping $($pbi.Count) Power BI projects for prerelease version"
    }
    else
    {
        Write-Host "⚠️ $($pbi.Count) Power BI projects must be converted manually!"
        Write-Host '     To open them, run: ' -NoNewline
        Write-Host './Package-Toolkit -PowerBI' -ForegroundColor Cyan
    }
    
    # Update version in docs
    $docVersionPath = "$PSScriptRoot/../../docs/_includes/ftkver.txt"
    $versionInDocs = Get-Content $docVersionPath -Raw
    if ($versionInDocs -eq $version)
    {
        Write-Host "✅ Version in docs ($versionInDocs) already up-to-date"
    }
    else
    {
        Write-Verbose "Updating version in docs..."
        $version | Out-File $docVersionPath -NoNewline
        Write-Host "ℹ️ Version updated in docs... Please commit the changes manually..."
    }
}

Write-Host '...done!'
Write-Host ''
