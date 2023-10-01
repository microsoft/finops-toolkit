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
    [Parameter(Position = 0)][string]$Template = "*",
    [switch]$Major,
    [switch]$Minor,
    [switch]$Patch,
    [switch]$Prerelease,
    [string]$Label
)

# Create output directory
$outDir = "../../release"
./New-Directory $outDir

# Update version
Write-Host ''
$ver = ./Invoke-Task Version -Major:$Major -Minor:$Minor -Patch:$Patch -Prerelease:$Prerelease -Label $Label
if ($Major -or $Minor -or $Patch -or $Prerelease) {
    Write-Host "Updated version to $ver"
} else {
    Write-Host "Building version $ver"
}
Write-Host ''

# Generate Bicep Registry modules
Get-ChildItem "..\bicep-registry\$($Template -replace '(subscription|resourceGroup|managementGroup|tenant)-', '')*" -Directory -ErrorAction SilentlyContinue `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    ./Build-Bicep $_.Name
}

# Generate deployment parameters file from main.bicep in the target directory
function Build-MainBicepParameters($dir) {
    Write-Host "  Generating parameters..."
    bicep generate-params "$dir/main.bicep" --outfile "$dir/azuredeploy.json"
    $paramFilePath = "$dir/azuredeploy.parameters.json"
    $params = Get-Content $paramFilePath -Raw | ConvertFrom-Json;
    $params.parameters.psobject.Properties `
    | ForEach-Object {
        # Add placeholder values for required parameters
        # See AQT docs for allowed values: https://github.com/Azure/azure-quickstart-templates/tree/4a6e5eae3c860208bf1731b392ae2b8a5fb24f4b/1-CONTRIBUTION-GUIDE#azure-devops-ci
        if ($_.Name.EndsWith('Name')) { $_.Value.value = "GEN-UNIQUE" }
    }
    $params | ConvertTo-Json -Depth 100 | Out-File $paramFilePath
}

# Generate workbook templates
Get-ChildItem "..\workbooks\$($Template -replace '-workbook$','')*" -Directory `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    $workbook = $_.Name
    Write-Host "Building workbook $workbook..."
    ./Build-Workbook $workbook
    Build-MainBicepParameters "$outdir/$workbook-workbook"
    $ver | Out-File "$outdir/$workbook-workbook/version.txt" -NoNewLine
    Write-Host ''
}
| ForEach-Object { Build-QuickstartTemplate $_ }

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
    Get-ChildItem $srcDir | Copy-Item -Destination $destDir -Recurse -Exclude ".buildignore,scaffold.json"
    
    # Remove ignored files
    Get-Content "$srcDir/.buildignore" `
    | ForEach-Object {
        $file = $_
        if (Test-Path "$destDir/$file") {
            Remove-Item "$destDir/$file" -Recurse -Force
        }
    }
    
    Build-MainBicepParameters $destDir
   
    # Copy version file last to override placeholder
    $ver | Out-File "$destDir/modules/version.txt" -NoNewLine

    Write-Host ''
}
