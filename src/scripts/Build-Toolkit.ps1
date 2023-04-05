<#
.SYNOPSIS
    Builds all toolkit modules and templates for publishing to the Bicep Registry and Azure Quickstart Templates.
.DESCRIPTION
    Run this from the /src/scripts folder.
.EXAMPLE
    ./Build-Toolkit
    Builds all FinOps toolkit templates.
#>
Param(
)

# Create output directory
$outDir = "../../release"
./New-Directory $outDir

# Generate Bicep modules
Get-ChildItem ..\bicep-registry\* -Directory `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    $module = $_
    Write-Host "Building module $($module.Name)..."
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

# Generate JSON parameters
Get-ChildItem ..\templates\*\main.bicep `
| ForEach-Object {
    $bicep = $_
    $tmpName = $bicep.Directory.Name
    $tmpDir = "$outDir/$tmpName"
    ./New-Directory $tmpDir

    Write-Host "Generating $tmpName template..."
    bicep build $bicep --outfile "$tmpDir/azuredeploy.json"
    Write-Host ''
    Write-Host "Generating $tmpName parameters..."
    bicep generate-params $bicep --outfile "$tmpDir/azuredeploy.json"
    Write-Host ''
}
