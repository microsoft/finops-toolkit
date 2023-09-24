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

# Worbkooks' templates placeholders
$placeholders = @(
    [PSCustomObject]@{
        optimization = @{
            "Compute"    = "computeGroupPlaceholder"
            "Storage"    = "storageGroupPlaceholder"
            "Networking" = "networkingGroupPlaceholder"
            "AHUB"       = "AHUBGroupPlaceholder"
        }
    }
)

if (-not (Test-Path $workbookDir)) {
    return
}

# Check if the workbook is using templates
if (Test-Path -Path $workbookDir -PathType Container) {
  # Get all directories within the workbook folder
  $templates = Get-ChildItem -Path $workbookDir -Directory

  # Check if any templates were found
  if ($templates) {
      $workbookTemplate = Join-Path $workbookDir "workbook_template.json"
      $newTemplate = "$workbookDir\workbook.json"
      ## Create a new template
      Copy-Item $workbookTemplate $newTemplate -Force

      ## Get contents of each sub-template
      foreach ($template in $templates) {
          $templateName = $template.Name
          $tempTemplate = Get-Content "$workbookDir/$templateName/CostWorkbook$templateName.workbook" -Raw
          $templateJson = $tempTemplate | ConvertFrom-Json
          $templateObjects = ($templateJson.items.content).items
          $replacedTemplate = $placeholders.$workbook[$templateName]
          $newWorbook = get-content $newTemplate
          $newWorbook -replace $replacedTemplate, ($templateObjects[2..$templateObjects.Count] | ConvertTo-Json -Depth 20) | Set-Content $newTemplate
      }
  }
}

# Copy scaffold and workbook files
./New-Directory $outDir
Copy-Item (Join-Path .. workbooks .scaffold *) $outDir -Exclude workbook.json
Copy-Item (Join-Path $workbookDir workbook.json) $outDir
Copy-Item (Join-Path $workbookDir createUiDefinition.json) $outDir
Copy-Item (Join-Path $workbookDir README.md) $outDir

# Read workbook
$workbookText = Get-Content (Join-Path $workbookDir workbook.json)

# Load scaffold config and add workbook version
$scaffoldMetadata = Get-Content (Join-Path $workbookDir scaffold.json) | ConvertFrom-Json
$scaffoldMetadata['main.bicep'] | Add-Member version (($workbookText | ConvertFrom-Json).version)
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
        $json | ConvertTo-Json | Out-File $path
    } else {
        $text -join [Environment]::NewLine | Out-File $path
    }

    if ($Debug) {
        Write-Host ""
        Write-Host "  $file"
        Write-Host "  $($file -replace ".","=")"
        Write-Host ((Get-Content $path) -join [Environment]::NewLine)
    }
}

# Delete workook.json file
Remove-Item $workbookDir/workbook.json -Force
