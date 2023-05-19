# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Builds all toolkit modules and templates for publishing to the Bicep Registry and Azure Quickstart Templates.
    .DESCRIPTION
        Run this from the /src/scripts folder.
    .PARAMETER Template
        Optional. Name of the module or template to publish. Default = "*" (all templates and modules).
    .EXAMPLE
        ./Build-Toolkit

        Builds all FinOps toolkit modules and templates.
    .EXAMPLE
        ./Build-Toolkit -Template "finops-hub"

        Builds only the finops-hub template.
#>
Param(
    [Parameter(Position = 0)][string]$Template = "*"
)

# Create output directory
$outDir = "../../release"
./New-Directory $outDir

# Generate Bicep Registry modules
Get-ChildItem ..\bicep-registry\$Template* -Directory -ErrorAction SilentlyContinue `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    $module = $_
    Write-Host "Building Registry module $($module.Name)..."
    ./Build-Bicep $module
    Write-Host ''
}

# Generate workbook templates
Get-ChildItem ..\workbooks\* -Directory `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    $workbook = $_.Name
    Write-Host "Building workbook $workbook..."
    ./Build-Workbook $workbook
    Write-Host ''
}

# Package Azure Quickstart Template folders
Get-ChildItem ..\templates\$Template* -Directory -ErrorAction SilentlyContinue `
| ForEach-Object {
    $srcDir = $_
    $templateName = $srcDir.Name

    Write-Host "Building template $templateName..."

    # Create target directory
    $destDir = "$outdir/$templateName"
    Remove-Item $destDir -Recurse -ErrorAction SilentlyContinue
    ./New-Directory $destDir
    
    # Copy required files
    Write-Host "  Copying files..."
    Copy-Item "$srcDir/*.*" $destDir
    Copy-Item "$srcDir/modules/" $destDir -Recurse
    
    # Generate parameters
    Write-Host "  Generating parameters..."
    bicep generate-params "$srcDir/main.bicep" --outfile "$destDir/azuredeploy.json"

    Write-Host ''
}
