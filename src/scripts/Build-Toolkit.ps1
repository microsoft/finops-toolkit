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
$outdir = "../../release"
./New-Directory $outdir

# Generate Bicep Registry modules
Get-ChildItem ..\bicep-registry\$Template* -Directory -ErrorAction SilentlyContinue `
| ForEach-Object {
    $module = $_
    Write-Host "Building Registry module $($module.Name)..."
    ./Build-Bicep $module
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
    ./New-Directory $destDir
    
    # Copy required files
    Write-Host "  Copying files..."
    Copy-Item "$srcDir/*.*" $destDir
    Copy-Item "$srcDir/modules" $destDir
    
    # Generate parameters
    Write-Host "  Generating parameters..."
    bicep generate-params "$srcDir/main.bicep" --outfile "$destDir/azuredeploy.json"

    Write-Host ''
}
