# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds all workbook templates for publishing to Azure Quickstart Templates.

    .PARAMETER Workbook
    Optional. Name of the workbook folder to build.

    .EXAMPLE
    ./Build-Workbook workbook-name

    Generates a template for the specified workbook.
#>
Param (
  [Parameter(Position = 0)][string] $Workbook
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

$outDir = "$PSScriptRoot/../../release/$Workbook-workbook"
$srcDir = "$PSScriptRoot/../workbooks/$Workbook"

if (-not (Test-Path $srcDir)) {
  Write-Verbose "Workbook not found: $srcDir"
  return
}

# Copy scaffold and workbook files
& "$PSScriptRoot/New-Directory" $outDir
Copy-Item "$PSScriptRoot/../workbooks/.scaffold/*" $outDir -Exclude workbook.json
Copy-Item "$srcDir/workbook.json" $outDir
Copy-Item "$srcDir/createUiDefinition.json" $outDir
Copy-Item "$srcDir/README.md" $outDir

# Read workbook
Write-Verbose "Reading workbook: $srcDir/workbook.json"
$workbookJson = Get-Content "$srcDir/workbook.json" -Raw | ConvertFrom-Json

# Replace nested templates
$nestedTemplates = $workbookJson.items.content.items `
| Where-Object {
  $_.content.groupType -eq 'template' `
    -and $_.content.loadFromTemplateId.StartsWith("community-Workbooks") } `
| Select-Object -ExpandProperty content `
| ForEach-Object {
  $template = $_
  # Read template
  $nestedName = $template.loadFromTemplateId.Split('/')[-1]
  if (-not (Test-Path "$srcDir/$nestedName/$nestedName.workbook")) {
    Write-Verbose "Ignoring nested template $nestedName (not found)"
    return
  }
  Write-Verbose "Injecting $nestedName template..."
  $nestedJson = Get-Content "$srcDir/$nestedName/$nestedName.workbook" -Raw | ConvertFrom-Json
  Write-Verbose "...adding $($nestedJson.items.content.items.Count) items"

  # Update workbook
  $templateObjects = ($nestedJson.items.content).items
  $template.loadFromTemplateId = ""
  $templateObjects | ForEach-Object {
    $template.items += $_
  }
  Write-Verbose "...added $($template.items.Count) items"

  # Return so we can count the templates
  return $nestedName
}
$workbookJson | ConvertTo-Json -Depth 100 | Set-Content -Path "$outDir/workbook.json"
Write-Verbose "Saved workbook with $($nestedTemplates.Count) nested templates: $($nestedTemplates -join ', ')"

# Load scaffold config and add workbook version
$scaffoldMetadata = Get-Content (Join-Path $srcDir scaffold.json) | ConvertFrom-Json
$scaffoldMetadata['main.bicep'] | Add-Member version ($workbookJson.version)
$scaffoldMetadata['metadata.json'] | Add-Member itemDisplayName "$($scaffoldMetadata['main.bicep'].displayName) workbook"

# Update template files from scaffold config
$scaffoldMetadata.PSObject.Properties `
| ForEach-Object {
  $file = $_.Name
  $path = Join-Path $outDir $file
  $text = Get-Content $path
  if ($file.EndsWith('.json')) {
    $json = $text | ConvertFrom-Json;
  }
  $_.Value.PSObject.Properties `
  | ForEach-Object {
    $var = $_.Name
    $value = $_.Value
    if ($file.EndsWith('.bicep')) {
      $text = $text -replace "^(param $var string|var $var)( = .*)?$", "`$1 = '$value'"
    } elseif ($file.EndsWith('.json')) {
      $json | Add-Member -MemberType NoteProperty -Name $var -Value $value -Force
    }
  }

  if ($file.EndsWith('.json')) {
    $json | ConvertTo-Json -Depth 100 | Out-File $path
  } else {
    $text -join [Environment]::NewLine | Out-File $path
  }

  # Write the contents of the file if debugging
  if ($Debug) {
    Write-Host ""
    Write-Host "  $file"
    Write-Host "  $($file -replace ".","=")"
    Write-Host ((Get-Content $path) -join [Environment]::NewLine)
  }
}
