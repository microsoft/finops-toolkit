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
function Add-CopyrightHeader
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = "$PSScriptRoot/../.."
    )

    $Path = (Resolve-Path -Path $Path).Path    

    # Header lines to add to the top of each file
    $headerLines = @( "Copyright (c) Microsoft Corporation.", "Licensed under the MIT License." )

    # File types to add the copyright header to and their comment characters
    $fileTypes = @{
        bicep = "//"
        ps1   = "#"
        psd1  = "#"
        psm1  = "#"
    }

    $exclude = '*.abf', '*.xml', '*.yml', '*.bim', '.buildignore', '.editorconfig', '.prettierrc', '.gitignore', '*.json', '*.md', '*.pbidataset', '*.pbip', '*.pbir', '*.pbix', '*.png', '*.svg' 
    $newLine = [Environment]::NewLine

    $valid = 0
    $fixed = 0
    $notSupported = 0

    $files = Get-ChildItem -Path $Path -Recurse -Include '*.*' -Exclude $exclude -File
    foreach ($file in $files)
    {
        # Look up the comment character for the file type
        $ext = $file.Extension.TrimStart(".")
        if ($fileTypes.ContainsKey($ext))
        {
            $commentChar = $fileTypes[$file.Extension.TrimStart(".")]
        }
        else
        {
            Write-Information "SKIPPED: [$($file.FullName)]: File type not supported: $ext" -InformationAction Continue
            $notSupported++
            continue
        }
        
        # Build the header
        $header = "$commentChar " + ($headerLines -join "$newLine$commentChar ") + $newLine + $newLine

        # Check if the file already has the header and add it if missing
        $content = Get-Content $file.FullName -Raw
        if ($content.StartsWith($header))
        {
            Write-Information "SKIPPED: [$($file.FullName)]: already has header." -InformationAction Continue
            $valid++
        }
        else
        {
            Set-Content -Path $file -Value ($header + $content) -NoNewline
            Write-Information "ADDED: [$($file.FullName)]" -InformationAction Continue
            $fixed++
        }
    }

    Write-Information "$($valid + $fixed) files checked" -InformationAction Continue
    Write-Information "$fixed file(s) updated" -InformationAction Continue
    Write-Information "$notSupported unsupported file type(s)" -InformationAction Continue
}
