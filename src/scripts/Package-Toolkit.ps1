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
    Optional. Indicates that Power BI storage projects should be opened so they can be manually saved as *.storage.pbix files. Default = false.

    .PARAMETER ZipPBI
    Optional. Indicates that demo PBIX files should be packaged into PowerBI-demo.zip. Default = false.

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

    Generates the PowerBI-demo.zip file. Must be run after -OpenPBI.
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
    Write-Host "Packaging $(if ($Template) { "$Template v$version template" } else { "v$version templates" })..."

    Write-Verbose "Removing existing ZIP files..."
    Remove-Item "$relDir/*.zip" -Force

    return Get-ChildItem "$relDir/$Template*" -Directory `
    | Where-Object { @('pbit', 'pbix', 'FinOpsToolkit') -notcontains $_.Name } `
    | ForEach-Object {
        Write-Verbose ("Packaging $_" -replace (Get-Item $relDir).FullName, '.')
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
        
        $zip = if ($unversionedZip) {
            Join-Path (Get-Item $relDir) "$templateName.zip"
        } else {
            Join-Path (Get-Item $relDir) "$templateName-v$version.zip"
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
            elseif (Test-Path "$srcPath/azuredeploy.json")
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

# Open or zip Power BI storage reports to generate PowerBI-demo.zip
$pbip = Get-ChildItem -Path "$PSScriptRoot/../power-bi/storage" -Include "*.pbip" -Recurse
if (-not ($OpenPBI -or $ZipPBI))
{
    Write-Host "⚠️ $($pbip.Count) Power BI projects must be manually saved as *.storage.pbix!"
    Write-Host '     To open them, run: ' -NoNewline
    Write-Host './Package-Toolkit -OpenPBI' -ForegroundColor Cyan
}
elseif ($OpenPBI)
{
    # Create temp pbix folder and remove existing storage/demo reports
    & "$PSScriptRoot/New-Directory" "$relDir/pbix"
    Remove-Item -Path "$relDir/pbix/*.storage.pbix" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$relDir/pbix/*.demo.pbix" -Recurse -Force -ErrorAction SilentlyContinue

    # Open Power BI projects
    Write-Host "ℹ️ $($pbip.Count) Power BI projects must be saved as PBIX first... Opening..."
    $pbip | Invoke-Item
    Write-Host '     Save as *.storage.pbix then run: ' -NoNewline
    Write-Host './Package-Toolkit -ZipPBI' -ForegroundColor Cyan
}
elseif ($ZipPBI)
{
    $pbixFiles = Get-ChildItem -Path "$relDir/pbix/*.storage.pbix"

    # TODO: Confirm all files are ready
    if ($pbip.Count -ne $pbixFiles.Count)
    {
        Write-Host "⚠️ Found $($pbip.Count) Power BI projects but $($pbixFiles.Count) *.storage.pbix files. Please confirm all projects are saved as PBIX files first."
        return
    }

    # Clean PBIX files
    Write-Verbose "Processing $($pbixFiles.Count) *.storage.pbix files..."
    $pbixFiles | ForEach-Object {
        # Expand PBIX files for cleanup
        $pbix = $_
        $pbixDir = $pbix.FullName.Replace('.storage.pbix', '.demo')
        Write-Verbose "Expanding $pbixDir..."
        Remove-Item -Path $pbixDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $pbix -DestinationPath $pbixDir

        # Remove _rels, docProps
        Remove-Item -Path "$pbixDir/_rels" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$pbixDir/docProps" -Recurse -Force -ErrorAction SilentlyContinue

        # Remove docProps from Content_Types
        $contentTypes = [xml](Get-Content "$pbixDir/?Content_Types?.xml" -Raw)
        $contentTypes.Types.Override | Where-Object {
            $_.PartName -eq '/docProps/custom.xml' } | ForEach-Object { $contentTypes.Types.RemoveChild($_) | Out-Null
        }
        $contentTypes.Save("$pbixDir/[Content_Types].xml") | Out-Null

        # Remove unneeded tables
        # $diagramLayout = Get-Content "$pbixDir/DiagramLayout" -Raw | ConvertFrom-Json -Depth 100
        # $diagramLayout.diagrams.nodes | Where-Object { $metadata.Tables -contains $_.nodeIndex }
        # TODO: Save as UTF-16LE -- $diagramLayout | ConvertTo-Json -Depth 100

        # TODO: Remove tables from data model
        # pbi-tools extract $pbix
        # TODO: Remove tables
        # pbi-tools compile $pbixDir $pbix

        # Zip as PBIX for demo
        Write-Verbose "Saving demo $pbixDir.pbix..."
        Remove-Item -Path "$pbixDir.pbix" -Recurse -Force -ErrorAction SilentlyContinue
        Compress-Archive -Path $pbixDir -DestinationPath "$pbixDir.pbix"
    }
}

Write-Host '...done!'
Write-Host ''
