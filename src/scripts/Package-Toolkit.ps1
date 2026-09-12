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

    .PARAMETER CopyFiles
    Optional. Indicates whether to copy templates and open data files. Default = false.

    .PARAMETER OpenPBI
    Optional. Opens the generated Power BI projects so they can be saved as *.storage.pbix files. Equivalent to Package-PowerBI -Open. Default = false.

    .PARAMETER ZipPBI
    Optional. Validates the saved PBIX files and packages them into PowerBI-demo.zip. Equivalent to Package-PowerBI. Default = false.

    .PARAMETER Preview
    Optional. Indicates that the template(s) should be saved as a preview only. Does not package other files. Default = false.

    .EXAMPLE
    ./Package-Toolkit -CopyFiles

    Generates ZIP files for each template using an existing build.

    .EXAMPLE
    ./Package-Toolkit -CopyFiles -Build

    Builds the latest code and generates ZIP files for each template.

    .EXAMPLE
    ./Package-Toolkit -CopyFiles -Build -OpenPBI

    Builds the latest code, generates ZIP files for each template, and opens Power BI projects to be saved as demo PBIX files.

    .EXAMPLE
    ./Package-Toolkit -ZipPBI

    Validates the saved PBIX files and generates the PowerBI-demo.zip file. Must be run after -OpenPBI.
#>
param(
    [Parameter(Position = 0)][string]$Template = "*",
    [switch]$Build,
    [switch]$CopyFiles,
    [switch]$OpenPBI,
    [switch]$ZipPBI,
    [switch]$Preview
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Build toolkit if requested
if ($Build)
{
    Write-Verbose "Building $(if ($Template -eq "*") { "all templates" } else { "the $Template template" })..."
    & "$PSScriptRoot/Build-Toolkit" $Template

    if (@("*", "pbi", "pbit") -contains $Template)
    {
        Write-Verbose "Building Power BI templates..."
        & "$PSScriptRoot/Build-PowerBI"
    }
}

$relDir = "$PSScriptRoot/../../release"
$deployDir = "$PSScriptRoot/../../docs/deploy"

# Validate template
if ($Template -ne "*" -and -not (Test-Path $relDir))
{
    Write-Error "$Template template not found. Please confirm template name."
    return
}

function Copy-TemplateFiles()
{
    Write-Host "Packaging $(if ($Template -ne "*") { "$Template $version template" } else { "$version templates" })..."

    if ($Template -eq "*")
    {
        Write-Verbose "Removing existing ZIP files..."
        # Power BI ZIP files are managed by Build-PowerBI and Package-PowerBI. Deleting them here
        # would throw away the templates that -Build just generated.
        Remove-Item "$relDir/*.zip" -Force -Exclude 'PowerBI-*.zip'
    }

    return Get-ChildItem "$relDir/$Template*" -Directory `
    | Where-Object { @('pbit', 'pbix', 'FinOpsToolkit') -notcontains $_.Name } `
    | ForEach-Object {
        Write-Verbose ("Packaging $_" -replace [regex]::Escape((Get-Item $relDir).FullName), '.')
        $srcPath = $_
        $templateName = $srcPath.Name
        $versionSubFolder = (Join-Path $srcPath $version)

        # Check if template should use an unversioned ZIP filename
        $buildConfigPath = Join-Path $PSScriptRoot ".." "templates" $templateName ".build.config"
        $unversionedZip = $false
        if (Test-Path $buildConfigPath)
        {
            try
            {
                $buildConfig = Get-Content $buildConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $unversionedZip = $buildConfig.unversionedZip -eq $true
            }
            catch
            {
                Write-Warning "Failed to read .build.config for $templateName : $_"
            }
        }

        $zip = if ($unversionedZip)
        {
            Join-Path (Get-Item $relDir) "$templateName.zip"
        }
        else
        {
            Join-Path (Get-Item $relDir) "$templateName-$tag.zip"
        }

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
            function Copy-FlatDeploymentFiles()
            {
                if (Test-Path "$srcPath/azuredeploy.json")
                {
                    # Copy azuredeploy.json to docs/deploy folder
                    Copy-Item "$srcPath/azuredeploy.json" "$deployDir/$templateName-$suffix.json"
                    Copy-Item "$srcPath/createUiDefinition.json" "$deployDir/$templateName-$suffix.ui.json"
                }
            }

            $packageManifestPath = "$srcPath/package-manifest.json"
            if (Test-Path $packageManifestPath)
            {
                # Read files/directories from package-manifest.json
                $packageManifest = Get-Content $packageManifestPath -Raw | ConvertFrom-Json

                # Create release directory
                $targetDir = "$deployDir/$templateName/$suffix"
                & "$PSScriptRoot/New-Directory" $targetDir

                # Copy files and directories
                $packageManifest.deployment.Files | ForEach-Object {
                    $destPath = $_.destination
                    $srcFolder = "$($srcPath.FullName)/$($_.sourceFolder)/".Replace("//", "/")
                    if (-not (Test-Path $srcFolder))
                    {
                        throw "Package manifest references source folder '$($_.sourceFolder)' that does not exist: $srcFolder"
                    }
                    $filesToCopy = @(Get-ChildItem "$srcFolder/*" -Include $_.source -Recurse:$_.recurse)
                    Write-Debug "Found $($filesToCopy.Count) files matching '$($_.source)' in $srcFolder"
                    $filesToCopy | ForEach-Object {
                        Write-Debug "Copying file: $($_.Name)"
                        if ($destPath -eq '*')
                        {
                            $normalizedSrc = $srcFolder.Replace('\', '/')
                            $normalizedFull = $_.FullName.Replace('\', '/')
                            $relativeDest = "$targetDir/$($normalizedFull.Replace($normalizedSrc, ''))"
                            $destDir = Split-Path $relativeDest -Parent
                            if ($destDir) { & "$PSScriptRoot/New-Directory" $destDir }
                            Copy-Item $_ $relativeDest -Force
                        }
                        else
                        {
                            Copy-Item $_ "$targetDir/$destPath" -Force
                        }
                    }
                }
                if ($packageManifest.deployment.Directories)
                {
                    Write-Debug "Processing $($packageManifest.deployment.Directories.Count) directory entries"
                    $packageManifest.deployment.Directories | ForEach-Object {
                        Write-Debug "Copying directory: $($_.source) -> $($_.destination)"
                        & "$PSScriptRoot/New-Directory" "$targetDir/$($_.destination)"
                        Get-ChildItem "$srcPath/$($_.source)" | Copy-Item -Destination "$targetDir/$($_.destination)" -Recurse -Force
                    }
                }
                else
                {
                    Write-Debug "No directory entries in manifest"
                }

                Copy-FlatDeploymentFiles
            }
            else
            {
                Copy-FlatDeploymentFiles
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

        Write-Verbose ("Compressing $srcPath to $zip" -replace [regex]::Escape((Get-Item $relDir).FullName), '.')
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Get-ChildItem $srcPath -Force | Compress-Archive -DestinationPath $zip
        return $zip
    }
}

function Copy-OpenDataFiles()
{
    Write-Verbose "Copying open data files..."
    Copy-Item "$PSScriptRoot/../open-data/*.csv" $relDir
    # Exclude *.familycounts.json: these are internal operational baselines for the
    # eligibility completeness guard (not reference data), so they must not ship in
    # the public release package alongside legitimate open data.
    Copy-Item "$PSScriptRoot/../open-data/*.json" $relDir -Exclude '*.familycounts.json'
}

function Copy-OpenDataFolders()
{
    Write-Verbose "Packaging open data files..."
    Get-ChildItem -Path "$PSScriptRoot/../open-data" -Directory `
    | ForEach-Object {
        $dir = $_
        Compress-Archive -Path "$dir/*.*" -DestinationPath "$relDir/$($dir.BaseName).zip"
        Write-Host "✅ $((Get-ChildItem "$dir/*.*").Count) $($dir.BaseName) files"
    }
}

$version = & "$PSScriptRoot/Get-Version"
$tag = & "$PSScriptRoot/Get-Version" -AsTag

if ($CopyFiles -or $Build -or $Preview -or -not ($OpenPBI -or $ZipPBI))
{
    # Package templates
    $templates = Copy-TemplateFiles
    Write-Host "✅ $($templates.Count) template$(if ($templates.Count -ne 1) { 's' })"
    Write-Host "ℹ️ Deployment files updated... Please commit the changes manually..."

    # Only package remaining files if not preview
    if (-not $Preview)
    {
        # Copy open data files
        Copy-OpenDataFiles
        Write-Host "✅ $((@(Get-ChildItem "$relDir/*.csv") + @(Get-ChildItem "$relDir/*.json")).Count) open data files"

        # Package sample data files together
        Copy-OpenDataFolders

        # Copy PBIX files
        Write-Verbose "Copying PBIX files..."
        Copy-Item "$PSScriptRoot/../power-bi/cm-connector/*.pbix" "$relDir" -Force
        Write-Host "✅ $((Get-ChildItem "$PSScriptRoot/../power-bi/cm-connector/*.pbix").Count) PBIX files"

        # Copy calendar files
        Write-Verbose "Copying calendar files..."
        Copy-Item "$PSScriptRoot/../../docs/*.ics" "$relDir" -Force
        Write-Host "✅ $((Get-ChildItem "$PSScriptRoot/../../docs/*.ics").Count) calendar files"

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
}

# Power BI files are packaged by Package-PowerBI, which reports what's left to do
if ($OpenPBI)
{
    & "$PSScriptRoot/Package-PowerBI.ps1" -Open
}
elseif ($ZipPBI)
{
    & "$PSScriptRoot/Package-PowerBI.ps1"
}
elseif (-not $Preview)
{
    & "$PSScriptRoot/Package-PowerBI.ps1" -Status
    Write-Host '     To continue, run: ' -NoNewline
    Write-Host './Package-PowerBI' -ForegroundColor Cyan
}

Write-Host '...done!'
Write-Host ''
