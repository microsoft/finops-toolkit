# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds all toolkit modules and templates for publishing to the Bicep Registry and Azure Quickstart Templates.

    .PARAMETER Template
    Optional. Name of the module or template to publish. Default = "*" (all templates and modules).

    .EXAMPLE
    ./Build-Toolkit

    Builds all FinOps toolkit modules and templates.

    .EXAMPLE
    ./Build-Toolkit -Template "finops-hub"

    Builds only the finops-hub template.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-toolkit
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
$outDir = "$PSScriptRoot/../../release"
& "$PSScriptRoot/New-Directory" $outDir

# Update version
Write-Host ''
$ver = & "$PSScriptRoot/Update-Version" -Major:$Major -Minor:$Minor -Patch:$Patch -Prerelease:$Prerelease -Label $Label
if ($Major -or $Minor -or $Patch -or $Prerelease)
{
    Write-Host "Updated version to $ver"
}
else
{
    Write-Host "Building version $ver"
}
Write-Host ''

# Generate Bicep Registry modules
Get-ChildItem "$PSScriptRoot/../bicep-registry/$($Template -replace '(subscription|resourceGroup|managementGroup|tenant)-', '')*" -Directory -ErrorAction SilentlyContinue `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    ./Build-Bicep $_.Name
}

# Generate deployment files from main.bicep in the target directory
function Build-MainBicep($dir)
{
    Write-Host "  Generating parameters..."
    bicep build "$dir/main.bicep" --outfile "$dir/azuredeploy.json"
    bicep generate-params "$dir/main.bicep" --outfile "$dir/azuredeploy.json"
    $paramFilePath = "$dir/azuredeploy.parameters.json"
    $params = Get-Content $paramFilePath -Raw | ConvertFrom-Json
    $params.parameters.psobject.Properties `
    | ForEach-Object {
        # Add placeholder values for required parameters
        # See AQT docs for allowed values: https://github.com/Azure/azure-quickstart-templates/tree/4a6e5eae3c860208bf1731b392ae2b8a5fb24f4b/1-CONTRIBUTION-GUIDE#azure-devops-ci
        if ($_ -and $_.Name.EndsWith('Name')) { $_.Value.value = "GEN-UNIQUE" }
    }
    $params | ConvertTo-Json -Depth 100 | Out-File $paramFilePath
}

# Generate workbook templates
Get-ChildItem "$PSScriptRoot/../workbooks/$($Template -replace '-workbook$','')*" -Directory `
| Where-Object { $_.Name -ne '.scaffold' }
| ForEach-Object {
    $workbook = $_.Name
    Write-Host "Building workbook $workbook..."
    & "$PSScriptRoot/Build-Workbook" $workbook
    Build-MainBicep "$outdir/$workbook-workbook"
    $ver | Out-File "$outdir/$workbook-workbook/ftkver.txt" -NoNewline
    Write-Host ''
}
| ForEach-Object { Build-QuickstartTemplate $_ }

# Package templates
Get-ChildItem "$PSScriptRoot/../templates/$Template*" -Directory -ErrorAction SilentlyContinue `
| ForEach-Object {
    $srcDir = $_
    $templateName = $srcDir.Name

    Write-Host "Building template $templateName..."

    # Create target directory
    $destDir = "$outdir/$templateName"
    Remove-Item $destDir -Recurse -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory" $destDir

    # Copy required files
    Write-Host "  Copying files..."
    Get-ChildItem $srcDir | Copy-Item -Destination $destDir -Recurse -Exclude ".buildignore,scaffold.json"

    # Remove ignored files
    Get-Content "$srcDir/.buildignore" `
    | ForEach-Object {
        $file = $_
        if (Test-Path "$destDir/$file")
        {
            Remove-Item "$destDir/$file" -Recurse -Force
        }
    }

    Build-MainBicep $destDir

    # Copy version file last to override placeholder
    $ver | Out-File "$destDir/modules/ftkver.txt" -NoNewline

    Write-Host ''
}

# TODO: review build logic to make it more generic across all toolkit components
# Package optimization engine
$srcDir = "$PSScriptRoot/../optimization-engine"
Write-Host "Building optimization engine..."

# Create target directory
$destDir = "$outdir/optimization-engine"
Remove-Item $destDir -Recurse -ErrorAction SilentlyContinue
& "$PSScriptRoot/New-Directory" $destDir

# Copy required files
Write-Host "  Copying files..."
Get-ChildItem $srcDir | Copy-Item -Destination $destDir -Recurse -Exclude ".buildignore"

# Remove ignored files
Get-Content "$srcDir/.buildignore" `
| ForEach-Object {
    $file = $_
    if (Test-Path "$destDir/$file")
    {
        Remove-Item "$destDir/$file" -Recurse -Force
    }
}

$ver | Out-File "$destDir/ftkver.txt" -NoNewline
