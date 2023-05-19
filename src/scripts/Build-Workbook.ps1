# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    Builds all workbook templates for publishing to Azure Quickstart Templates.
.DESCRIPTION
    Run this from the /src/scripts folder.
.EXAMPLE
    ./Build-Workbook workbook-name
    Generates a template the specified workbook.
.PARAMETER Workbook
    Name of the workbook folder.
.PARAMETER Debug
    Optional. Renders main module and test bicep code to the console instead of generating files. Line numbers map to original file.
#>
Param (
    [Parameter(Position = 0)][string] $Workbook
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

$outDir = Join-Path .. .. release "$Workbook-workbook"
$workbookDir = Join-Path .. workbooks $Workbook

if (-not (Test-Path $workbookDir)) {
    return
}

Write-Host "  $Workbook..."

# Copy scaffold and workbook files
./New-Directory $outDir
Copy-Item (Join-Path .. workbooks .scaffold *) $outDir
Copy-Item (Join-Path $workbookDir workbook.json) $outDir

# Read workbook
$workbookText = Get-Content (Join-Path $workbookDir workbook.json)

# Update module with scaffold inputs
$moduleFile = Join-Path $outDir main.bicep
$moduleText = Get-Content $moduleFile 
$scaffoldMetadata = Get-Content (Join-Path $workbookDir scaffold.json) | ConvertFrom-Json
$scaffoldMetadata | Add-Member version (($workbookText | ConvertFrom-Json).version)
$scaffoldMetadata.PSObject.Properties `
| ForEach-Object { 
    $var = $_.Name
    $moduleText = $moduleText -replace "^(param $var string|var $var)( = .*)?$", "`$1 = '$($_.Value)'"
}

# Load workbook.json dynamically (not included in scaffold file due to invalid file reference)
$moduleText = $moduleText -replace "var workbookJson = ''", "var workbookJson = string(loadJsonContent('workbook.json'))"

# Convert module text to json and write to file
$moduleText -join [Environment]::NewLine `
| Out-File $moduleFile
#| ConvertTo-Json -Compress `

if ($Debug) {
    $moduleText
}
