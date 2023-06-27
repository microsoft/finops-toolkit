# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
        Adds a standard copyright header to all files in the repository that don't already have it.
    .DESCRIPTION
        Run this from the /src/scripts folder.
    .EXAMPLE
        ./Add-CopyrightHeader

        Loops thru all files in the src folder and adds the header if missing.
#>

# Header lines to add to the top of each file
$headerLines = @( "Copyright (c) Microsoft Corporation.", "Licensed under the MIT License." )

# File types to add the copyright header to and their comment characters
$fileTypes = @{
    "bicep" = "//"
    "ps1"   = "#"
    "psd1"  = "#"
    "psm1"  = "#"
}
$newLine = [Environment]::NewLine

$valid = 0
$fixed = 0
$notSupported = 0

Get-ChildItem -Path ../ -Recurse -Include *.* -Exclude *.json, *.md, *.pbix, *.svg -File `
| ForEach-Object {
    $file = $_

    # Look up the comment character for the file type
    $ext = $file.Extension.TrimStart(".")
    if ($fileTypes.ContainsKey($ext)) {
        $commentChar = $fileTypes[$file.Extension.TrimStart(".")]
    } else {
        Write-Error "File type not supported: $ext"
        $notSupported++
        return
    }
    
    # Build the header
    $header = "$commentChar " + ($headerLines -join "$newLine$commentChar ") + $newLine + $newLine

    # Check if the file already has the header and add it if missing
    $content = Get-Content $file -Raw
    if ($content.StartsWith($header)) {
        Write-Host "✔ $($file.FullName)"
        $valid++
    } else {
        Write-Host "✘ $($file.FullName)" -NoNewline
        Set-Content -Path $file -Value ($header + $content) -NoNewline
        Write-Host " ...added!"
        $fixed++
    }
}

Write-Host ""
Write-Host "$($valid + $fixed) files checked"
Write-Host "$fixed file(s) updated"
Write-Host "$notSupported unsupported file type(s)"
Write-Host ""
