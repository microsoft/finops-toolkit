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
param(
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
Get-ChildItem "$PSScriptRoot/../workbooks/*" -Directory `
| Where-Object { $_.Name -ne '.scaffold' -and ($Template -eq "*" -or $Template -eq $_.Name -or $Template -eq "$($_.Name)-workbook" -or $Template -eq "finops-workbooks") }
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
Get-ChildItem -Path "$PSScriptRoot/../templates/*", "$PSScriptRoot/../optimization-engine*" -Directory -ErrorAction SilentlyContinue `
| ForEach-Object {
    $srcDir = $_
    $templateName = $srcDir.Name

    # Skip if not the specified template
    if ($Template -ne "*" -and $Template -ne $templateName)
    {
        return
    }

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

    # TODO: Create a way to define file consolidation via config (or maybe a custom build script in the folder)
    if ($templateName -eq "finops-hub")
    {
        @(
            @{
                Database = "Ingestion"
                Scripts  = @(
                    "OpenDataFunctions_resource_type_1.kql",
                    "OpenDataFunctions_resource_type_2.kql",
                    "OpenDataFunctions_resource_type_3.kql",
                    "OpenDataFunctions_resource_type_4.kql",
                    "OpenDataFunctions.kql",
                    "Common.kql",
                    "IngestionSetup.kql"
                )
            }
            @{
                Database = "Hub"
                Scripts  = @(
                    "Common.kql",
                    "HubSetup.kql"
                )
            }
        ) | ForEach-Object {
            $combinedScript = ".execute database script with (ContinueOnErrors=true)`n<|`n//`n"
            $_.Scripts | ForEach-Object {
                $combinedScript += Get-Content "$srcDir/modules/scripts/$_" -Raw
            }
            $combinedScript = $combinedScript -replace '(\r?\n)(\r?\n)+', '$1//$1'
            $combinedScript | Out-File $destDir/../finops-hub-fabric-setup-$($_.Database).kql -Encoding utf8 -Force
            Write-Verbose "  Created finops-hub-fabric-setup-$($_.Database).kql"
        }
    }

    # TODO: Create a way to define required dependencies
    if ($templateName -eq "finops-workbooks")
    {
        Write-Host "  Copying dependencies..."
        & "$PSScriptRoot/New-Directory" "$destDir/workbooks"
        Get-ChildItem "$destDir/../*-workbook" -Directory `
        | ForEach-Object {
            $workbookDir = "$destDir/workbooks/$($_.Name -replace '-workbook', '')"
            Copy-Item -Path $_ -Destination $workbookDir -Recurse
            Remove-Item -Path "$workbookDir/*" -Include azuredeploy*.json, createUiDefinition.json, metadata.json, README.md
        }
    }

    # Build main.bicep, if applicable
    if (Test-Path "$srcDir/main.bicep")
    {
        Build-MainBicep $destDir
    }

    # Update placeholder variables
    # TODO: Genericize this so it can be used for any files
    if (Test-Path "$srcDir/dashboard.json")
    {
        (Get-Content "$destDir/dashboard.json" -Raw) `
            -replace '\$\$ftkver\$\$', $ver `
            -replace '\$\$build-date\$\$', (Get-Date -Format 'yyyy-MM-dd') `
            -replace '\$\$build-month\$\$', (Get-Date -Format 'MMMM yyyy') `
        | Out-File "$destDir/dashboard.json" -Encoding utf8 -Force
    }

    # Update version in ftkver.txt files
    Get-ChildItem $destDir -Include ftkver.txt -Recurse | ForEach-Object { $ver | Out-File $_ -NoNewline }

    Write-Host ''
}
