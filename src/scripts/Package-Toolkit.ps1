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
    Optional. Indicates that Power BI projects should be opened as part of the packaging process. Default = false.

    .PARAMETER ZipPBI
    Optional. Indicates that prepared PBIX files should be packaged into release files. Default = false.

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

    Builds the latest code, generates ZIP files for each template, and opens Power BI projects to be saved as PBIX files.
#>
Param(
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
    Write-Host "Packaging $(if ($Template) { "$Template v$version template" } else { "v$version templates" })..."

    Write-Verbose "Removing existing ZIP files..."
    Remove-Item "$relDir/*.zip" -Force

    return Get-ChildItem "$relDir/$Template*" -Directory `
    | Where-Object { $_.Name -ne 'pbix' } `
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
}

function Copy-OpenDataFiles()
{
    Write-Verbose "Copying open data files..."
    Copy-Item "$PSScriptRoot/../open-data/*.csv" $relDir
    Copy-Item "$PSScriptRoot/../open-data/*.json" $relDir
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

$pbip = Get-ChildItem -Path "$PSScriptRoot/../power-bi" -Include "*.pbip" -Recurse
if (-not ($OpenPBI -or $ZipPBI))
{
    Write-Host "⚠️ $($pbip.Count) Power BI projects must be converted manually!"
    Write-Host '     To open them, run: ' -NoNewline
    Write-Host './Package-Toolkit -OpenPBI' -ForegroundColor Cyan
}
elseif ($OpenPBI)
{
    # Recreate temp pbix folder
    Remove-Item -Path "$relDir/pbix" -Recurse -Force -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory" "$relDir/pbix"

    # Open Power BI projects
    Write-Host "ℹ️ $($pbip.Count) Power BI projects must be converted manually... Opening..."
    $pbip | Invoke-Item
    Write-Host '     Save as PBIX then run: ' -NoNewline
    Write-Host './Package-Toolkit -ZipPBI' -ForegroundColor Cyan
}
elseif ($ZipPBI)
{
    # Clean PBIX files
    $pbixFiles = Get-ChildItem -Path "$relDir/pbix/*.pbix"
    Write-Verbose "Processing $($pbixFiles.Count) files..."
    $pbixFiles | ForEach-Object {
        # Expand PBIX files for cleanup
        $pbix = $_
        $pbixDir = $pbix.FullName.Replace('.pbix', '')
        # Write-Verbose "Expanding $pbixDir..."
        # Expand-Archive -Path $pbix -DestinationPath $pbixDir

        # TODO: Remove queries for storage files
        # TODO: Remove sensitivity

        # Zip as PBIX for demo
        if ($pbixDir.EndsWith('.kql'))
        {
            Write-Verbose "Saving demo $pbixDir.pbix..."
            # Compress-Archive -Path $pbixDir -DestinationPath "$pbixDir.kql.pbix"
        }
        
        # TODO: Remove data
        
        # Zip as PBIT
        Write-Verbose "Saving $pbixDir.pbit..."
        # Compress-Archive -Path $pbixDir -DestinationPath "$pbixDir.pbit"
    }

    # Zip release files
    # Compress-Archive -Path "$relDir/pbix/*.storage.pbit" -DestinationPath "$relDir/PowerBI-storage.zip"
    # Compress-Archive -Path "$relDir/pbix/*.kql.pbix" -DestinationPath "$relDir/PowerBI-demo.zip"
    # Compress-Archive -Path "$relDir/pbix/*.kql.pbit" -DestinationPath "$relDir/PowerBI-kql.zip"
}    

Write-Host '...done!'
Write-Host ''
