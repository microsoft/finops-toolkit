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
    bicep generate-params "$dir/main.bicep" --outfile "$dir/azuredeploy.parameters.json"
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

    # Get custom build configuration
    $buildConfig = Get-Content "$_/.build.config" -ErrorAction SilentlyContinue | ConvertFrom-Json -Depth 10

    # Backfill config options to avoid null references
    (@{ ignore = @(); combineKql = @{}; rename = @{}; variableExpansion = @() }).PSObject.Properties | ForEach-Object {
        if (-not $buildConfig.PSObject.Properties[$_.Name])
        {
            $buildConfig | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }
    }

    # Create target directory
    $destDir = "$outdir/$templateName"
    Remove-Item $destDir -Recurse -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory" $destDir

    # Copy required files
    Write-Host "  Copying files..."
    Get-ChildItem $srcDir | Copy-Item -Destination $destDir -Recurse -Exclude ".build.config,.buildignore,scaffold.json"

    # Remove ignored files
    $ignoredFiles = (Get-Content "$srcDir/.buildignore" -ErrorAction SilentlyContinue) + $buildConfig.ignore
    if ($ignoredFiles.Length)
    {
        Write-Host "  Removing ignored files..."
        $ignoredFiles `
        | ForEach-Object {
            $file = $_
            if (Test-Path "$destDir/$file")
            {
                Write-Verbose "Removing $file"
                Remove-Item "$destDir/$file" -Recurse -Force
            }
        }
    }

    # Combine KQL files, if specified
    if ($buildConfig.combineKql.Length)
    {
        Write-Host "  Combining KQL files..."
        $buildConfig.combineKql | ForEach-Object {
            $combinedScript = ".execute database script with (ContinueOnErrors=true)`n<|`n//`n"
            $_.files | ForEach-Object {
                $combinedScript += Get-Content "$srcDir/$_" -Raw
            }
            $combinedScript = $combinedScript -replace '(\r?\n)(\r?\n)+', '$1//$1'
            $combinedScript | Out-File "$destDir/../$($_.name)" -Encoding utf8 -Force
            Write-Verbose "Combined $($_.files.Length) files into $($_.name)"
        }
    }

    # Update placeholder variables
    if ($buildConfig.variableExpansion.Length)
    {
        Write-Host "  Expanding variables..."
        $buildConfig.variableExpansion | ForEach-Object {
            if (Test-Path "$destDir/$_")
            {
                Write-Verbose "Updating $_"
                (Get-Content "$destDir/$_" -Raw) `
                    -replace '\$\$ftkver\$\$', $ver `
                    -replace '\$\$build-date\$\$', (Get-Date -Format 'yyyy-MM-dd') `
                    -replace '\$\$build-month\$\$', (Get-Date -Format 'MMMM yyyy') `
                | Out-File "$destDir/$_" -Encoding utf8 -Force
            }
        }
    }

    # Move files, if specified
    if ($buildConfig.move.Length)
    {
        Write-Host "  Moving files..."
        $buildConfig.move `
        | Where-Object { Test-Path "$destDir/$($_.path)" } `
        | ForEach-Object {
            Write-Verbose "Moving $($_.path) to $($_.destination)"
            Move-Item -Path "$destDir/$($_.path)" -Destination "$destDir/$($_.destination)" -Force
            if ($_.ignore.Length)
            {
                Remove-Item -Path "$destDir/*" -Include ($_.ignore -join ',') -Force
            }
        }
    }

    # Build main.bicep, if applicable
    if (Test-Path "$srcDir/main.bicep")
    {
        Build-MainBicep $destDir
    }

    # Update version in ftkver.txt files
    Get-ChildItem $destDir -Include ftkver.txt -Recurse | ForEach-Object { $ver | Out-File $_ -NoNewline }

    Write-Host ''
}
