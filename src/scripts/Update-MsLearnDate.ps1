# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Updates the ms.date field in Microsoft Learn documentation files.

    .DESCRIPTION
    The Update-MsLearnDate command updates the ms.date field in markdown files within the docs-mslearn folder.
    It searches for lines that match exactly 'ms.date: MM/dd/yyyy' and updates the date to the current date.
    Only lines with this exact pattern are updated - no more, no less content on the line.

    .PARAMETER Path
    Optional. Specifies the path to search for markdown files. Default is 'docs-mslearn' relative to the repository root.

    .PARAMETER WhatIf
    Optional. Shows what would be updated without making changes.

    .EXAMPLE
    ./Update-MsLearnDate

    Updates ms.date fields in all markdown files in the docs-mslearn folder.

    .EXAMPLE
    ./Update-MsLearnDate -Path "docs-mslearn/framework" -WhatIf

    Shows what ms.date fields would be updated in the framework subfolder without making changes.
#>
param(
    [Parameter()]
    [string]
    $Path = "docs-mslearn",

    [Parameter()]
    [switch]
    $WhatIf
)

# Get the repository root directory (two levels up from this script)
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")

# Handle absolute vs relative paths
if ([System.IO.Path]::IsPathRooted($Path)) {
    $targetPath = $Path
} else {
    $targetPath = Join-Path $repoRoot $Path
}

if (-not (Test-Path $targetPath)) {
    Write-Error "Path not found: $targetPath"
    exit 1
}

Write-Host "Searching for markdown files in: $targetPath"

# Get current date in MM/dd/yyyy format
$currentDate = Get-Date -Format "MM/dd/yyyy"
Write-Host "Current date: $currentDate"

# Pattern to match exactly 'ms.date: MM/dd/yyyy' (no extra content on the line)
$datePattern = "^ms\.date:\s+\d{2}/\d{2}/\d{4}\s*$"
$replacementPattern = "ms.date: $currentDate"

# Find all markdown files
$markdownFiles = Get-ChildItem -Path $targetPath -Filter "*.md" -Recurse

$updatedFiles = @()
$totalFilesProcessed = 0

foreach ($file in $markdownFiles) {
    $totalFilesProcessed++
    $relativePath = $file.FullName.Replace($repoRoot.Path + [IO.Path]::DirectorySeparatorChar, "")
    
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName
    
    $updatedLines = @()
    $fileChanged = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        if ($line -match $datePattern) {
            $oldLine = $line
            $newLine = $replacementPattern
            
            if ($oldLine -ne $newLine) {
                $fileChanged = $true
                Write-Host "  Found match in $relativePath (line $($i + 1)): '$oldLine' -> '$newLine'"
                
                if (-not $WhatIf) {
                    $updatedLines += $newLine
                } else {
                    $updatedLines += $oldLine
                }
            } else {
                $updatedLines += $line
            }
        } else {
            $updatedLines += $line
        }
    }
    
    if ($fileChanged) {
        $updatedFiles += $file
        
        if (-not $WhatIf) {
            # Write the updated content back to the file
            $updatedLines | Set-Content $file.FullName -Encoding UTF8
            Write-Host "  Updated: $relativePath"
        } else {
            Write-Host "  Would update: $relativePath"
        }
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Files processed: $totalFilesProcessed"
Write-Host "  Files with ms.date updates: $($updatedFiles.Count)"

if ($WhatIf) {
    Write-Host "  (No changes made - WhatIf mode)"
} elseif ($updatedFiles.Count -gt 0) {
    Write-Host "  Files updated successfully"
} else {
    Write-Host "  No files needed updating"
}