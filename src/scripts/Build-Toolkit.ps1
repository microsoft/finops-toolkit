# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds all toolkit modules and templates for publishing to the Bicep Registry and Azure Quickstart Templates.

    .PARAMETER Template
    Optional. Name of the module or template to build. Default = * (all templates and modules).

    .PARAMETER Major
    Optional. Increments the major version number (x.0).

    .PARAMETER Minor
    Optional. Increments the minor version number (0.x).

    .PARAMETER Patch
    Optional. Increments the patch version number (0.0.x).

    .PARAMETER Prerelease
    Optional. Increments the prerelease version number (0.0.0-ooo.x).

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Allowed: dev, alpha, preview.

    .EXAMPLE
    ./Build-Toolkit

    Builds all FinOps toolkit modules and templates.

    .EXAMPLE
    ./Build-Toolkit -Template "finops-hub"

    Builds only the finops-hub template.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-toolkit
#>

[CmdletBinding()]
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
Write-Verbose "Creating output directory: $outDir"
& "$PSScriptRoot/New-Directory.ps1" $outDir

Write-Verbose "Starting build for template pattern: '$Template'"

# Update version
Write-Host ''
Write-Verbose "Updating version information..."
$ver = & "$PSScriptRoot/Update-Version.ps1" -Major:$Major -Minor:$Minor -Patch:$Patch -Prerelease:$Prerelease -Label $Label
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
Write-Verbose "Searching for Bicep Registry modules..."
$bicepModules = Get-ChildItem "$PSScriptRoot/../bicep-registry/$($Template -replace '(subscription|resourceGroup|managementGroup|tenant)-', '')*" -Directory -ErrorAction SilentlyContinue `
| Where-Object { $_.Name -ne '.scaffold' }

if ($bicepModules)
{
    Write-Verbose "Found $($bicepModules.Count) Bicep Registry module(s) to build"
    $bicepModules | ForEach-Object {
        Write-Verbose "Building Bicep module: $($_.Name)"
        & "$PSScriptRoot/Build-Bicep.ps1" $_.Name
    }
}
else
{
    Write-Verbose "No Bicep Registry modules found matching pattern: $Template"
}

# Generate deployment files from main.bicep in the target directory
function Build-MainBicep($dir)
{
    Write-Host "  Generating parameters..."
    Write-Verbose "    Building Bicep template: $dir/main.bicep"
    bicep build "$dir/main.bicep" --outfile "$dir/azuredeploy.json"
    
    Write-Verbose "    Generating parameter template: $dir/azuredeploy.parameters.json"
    bicep generate-params "$dir/main.bicep" --outfile "$dir/azuredeploy.parameters.json"
    
    $paramFilePath = "$dir/azuredeploy.parameters.json"
    Write-Verbose "    Processing parameter placeholders in: $paramFilePath"
    $params = Get-Content $paramFilePath -Raw | ConvertFrom-Json
    
    $parameterCount = 0
    $params.parameters.psobject.Properties | ForEach-Object {
        # Add placeholder values for required parameters
        # See AQT docs for allowed values: https://github.com/Azure/azure-quickstart-templates/tree/4a6e5eae3c860208bf1731b392ae2b8a5fb24f4b/1-CONTRIBUTION-GUIDE#azure-devops-ci
        if ($_ -and $_.Name.EndsWith('Name'))
        { 
            Write-Verbose "      Setting placeholder for parameter: $($_.Name)"
            $_.Value.value = "GEN-UNIQUE" 
            $parameterCount++
        }
    }
    
    Write-Verbose "    Updated $parameterCount parameter placeholder(s)"
    $params | ConvertTo-Json -Depth 100 | Out-File $paramFilePath
}

# Generate workbook templates
Write-Verbose "Searching for workbook templates..."
$workbooks = Get-ChildItem "$PSScriptRoot/../workbooks/*" -Directory `
| Where-Object { $_.Name -ne '.scaffold' -and ($Template -eq "*" -or $Template -eq $_.Name -or $Template -eq "$($_.Name)-workbook" -or $Template -eq "finops-workbooks") }

if ($workbooks)
{
    Write-Verbose "Found $($workbooks.Count) workbook template(s) to build"
    $workbooks | ForEach-Object {
        $workbook = $_.Name
        Write-Host "Building workbook $workbook..."
        Write-Verbose "  Building workbook: $workbook"
        & "$PSScriptRoot/Build-Workbook.ps1" $workbook
        
        Write-Verbose "  Generating deployment files for: $workbook-workbook"
        Build-MainBicep "$outdir/$workbook-workbook"
        
        Write-Verbose "  Writing version file: $outdir/$workbook-workbook/ftkver.txt"
        $ver | Out-File "$outdir/$workbook-workbook/ftkver.txt" -NoNewline
        Write-Host ''
    }
}
else
{
    Write-Verbose "No workbook templates found matching pattern: $Template"
}

# Package templates
Write-Verbose "Searching for templates to package..."
$templates = Get-ChildItem -Path "$PSScriptRoot/../templates/*", "$PSScriptRoot/../optimization-engine*" -Directory -ErrorAction SilentlyContinue

if ($templates)
{
    Write-Verbose "Found $($templates.Count) template(s) to process"
}
else
{
    Write-Verbose "No templates found to package"
}

$templates | ForEach-Object {
    $srcDir = $_
    $templateName = $srcDir.Name

    # Skip if not the specified template
    if ($Template -ne "*" -and $Template -ne $templateName)
    {
        Write-Verbose "Skipping template '$templateName' (doesn't match pattern '$Template')"
        return
    }

    Write-Host "Building template $templateName..."
    Write-Verbose "  Processing template: $templateName from $($srcDir.FullName)"

    # Get custom build configuration
    Write-Verbose "  Loading build configuration from: $($srcDir.FullName)/.build.config"
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
    Write-Verbose "  Creating target directory: $destDir"
    Remove-Item $destDir -Recurse -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory.ps1" $destDir

    # Copy required files
    Write-Host "  Copying files..."
    $sourceFiles = Get-ChildItem $srcDir | Where-Object { $_.Name -notin @(".build.config", ".buildignore", "scaffold.json") }
    Write-Verbose "    Copying $($sourceFiles.Count) items from source to destination"
    $sourceFiles | Copy-Item -Destination $destDir -Recurse

    # Remove ignored files
    $ignoredFiles = (Get-Content "$srcDir/.buildignore" -ErrorAction SilentlyContinue) + $buildConfig.ignore
    if ($ignoredFiles.Length)
    {
        Write-Host "  Removing ignored files..."
        Write-Verbose "    Processing $($ignoredFiles.Length) ignore pattern(s)"
        $removedCount = 0
        $ignoredFiles | ForEach-Object {
            $file = $_
            if (Test-Path "$destDir/$file")
            {
                Write-Verbose "    Removing: $file"
                Remove-Item "$destDir/$file" -Recurse -Force
                $removedCount++
            }
        }
        Write-Verbose "    Removed $removedCount ignored file(s)"
    }
    else
    {
        Write-Verbose "    No files to ignore"
    }

    # Combine KQL files, if specified
    if ($buildConfig.combineKql.Length)
    {
        Write-Host "  Combining KQL files..."
        Write-Verbose "    Processing $($buildConfig.combineKql.Length) KQL combination(s)"
        $buildConfig.combineKql | ForEach-Object {
            Write-Verbose "    Combining $($_.files.Length) files into $($_.name)"
            $combinedScript = ".execute database script with (ContinueOnErrors=true)`n<|`n//`n"
            $_.files | ForEach-Object {
                Write-Verbose "      Including file: $_"
                $combinedScript += Get-Content "$srcDir/$_" -Raw
            }
            $combinedScript = $combinedScript -replace '(\r?\n)(\r?\n)+', '$1//$1'
            $outputPath = "$destDir/../$($_.name)"
            Write-Verbose "    Writing combined KQL to: $outputPath"
            $combinedScript | Out-File $outputPath -Encoding utf8 -Force
        }
    }
    else
    {
        Write-Verbose "    No KQL files to combine"
    }

    # Update placeholder variables
    if ($buildConfig.variableExpansion.Length)
    {
        Write-Host "  Expanding variables..."
        Write-Verbose "    Processing $($buildConfig.variableExpansion.Length) file(s) for variable expansion"
        $expandedCount = 0
        $buildConfig.variableExpansion | ForEach-Object {
            if (Test-Path "$destDir/$_")
            {
                Write-Verbose "    Expanding variables in: $_"
                (Get-Content "$destDir/$_" -Raw) `
                    -replace '\$\$ftkver\$\$', $ver `
                    -replace '\$\$build-date\$\$', (Get-Date -Format 'yyyy-MM-dd') `
                    -replace '\$\$build-month\$\$', (Get-Date -Format 'MMMM yyyy') `
                | Out-File "$destDir/$_" -Encoding utf8 -Force
                $expandedCount++
            }
            else
            {
                Write-Verbose "    File not found for variable expansion: $_"
            }
        }
        Write-Verbose "    Expanded variables in $expandedCount file(s)"
    }
    else
    {
        Write-Verbose "    No variable expansion configured"
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
        Write-Verbose "  Found main.bicep, generating deployment files"
        Build-MainBicep $destDir
    }
    else
    {
        Write-Verbose "  No main.bicep found, skipping deployment file generation"
    }

    # Update version in ftkver.txt files
    $versionFiles = Get-ChildItem $destDir -Include ftkver.txt -Recurse
    Write-Verbose "  Updating $($versionFiles.Count) version file(s) with version: $ver"
    $versionFiles | ForEach-Object { 
        Write-Verbose "    Updating version in: $($_.FullName)"
        $ver | Out-File $_ -NoNewline 
    }

    Write-Host ''
}
