# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds all Bicep modules for publishing to the Bicep Registry.

    .PARAMETER Module
    Optional. Name of the module to build. Default = * (all modules).

    .PARAMETER Scope
    Optional. Scope to build. If not specified, all scopes will be built.

    .EXAMPLE
    ./Build-Bicep module-name

    Generates separate modules for each supported scope for the specified module.

    .EXAMPLE
    ./Build-Bicep module-name -Scope subscription

    Generates the module for only one scope (subscription in this case).

    .EXAMPLE
    ./Build-Bicep module-name -Scope subscription -Debug

    Renders main module and test bicep code to the console instead of generating files.
#>
Param (
    [Parameter(Position = 0)][string] $Module = "*",
    [string] $Scope
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

$scopeList = '(subscription|resourceGroup|managementGroup|tenant)'
$scopeDirective = "(//(\s*@$scopeList)+|targetScope = '$scopeList')"

$outDir = "$PSScriptRoot/../../release"
$registryDir = "$PSScriptRoot/../bicep-registry"
$scaffoldDir = "$registryDir/.scaffold"

Get-ChildItem "$registryDir/$Module*" -Directory `
| Where-Object { $_.Name -ne '.scaffold' } `
| ForEach-Object {
    $srcDir = $_

    # List of supported scopes to be updated later
    $script:scopes = @()

    # Generates modules for each supported scope
    function Build-Modules([string] $Path, [switch] $CopySupportingFiles)
    {
        # Confirm path
        if (-not (Test-Path (Join-Path $srcDir $Path)))
        {
            Write-Error "$srcDir/$Path not found"
            return
        }

        # Read code from the bicep file
        $lines = (Get-Content (Join-Path $srcDir $Path))

        # Get the supported scopes
        $script:scopes = [regex]::Matches([regex]::Matches($lines, $scopeDirective).Value, $scopeList).Value `
        | Sort-Object -Unique `
        | Where-Object { $_.ToLower() -eq $Scope.ToLower() -or [string]::IsNullOrWhitespace($Scope) }

        # Loop thru each scope
        $script:scopes `
        | ForEach-Object {
            $currentScope = $_
            $moduleName = "$($currentScope.ToLower())-$($srcDir.Name)"

            if ($CopySupportingFiles)
            {
                Write-Host "  $currentScope..."
            }

            # Init string builder for the scope output
            $sb = [System.Text.StringBuilder]::new()

            # Write debug header
            if ($Debug)
            {
                Write-Host $moduleName
                Write-Host "".PadLeft($moduleName.Length, "=")
            }

            # Use custom iterator to peek at multiple lines
            $i = 0
            $script:lastLineEmpty = $lines.Count -le $i -or [string]::IsNullOrWhiteSpace($lines[$i])
            while ($i -lt ($lines.Count))
            {
                # Helper functions
                $script:isNewLine = $true
                function append([string] $Text, [switch] $NoNewLine)
                {
                    if ($Debug -and $script:isNewLine) { [void]$sb.Append("$($i.ToString().PadLeft(3, ' '))|  ") }
                    if ($NoNewLine) { [void]$sb.Append($Text) } else { [void]$sb.AppendLine($Text) }
                    $script:isNewLine = -not $NoNewLine
                    $script:lastLineEmpty = $Text.Trim() -eq ''
                }

                $line = $lines[$i]

                # Remove empty lines before content starts
                if ($line.Trim() -eq '' -and $script:lastLineEmpty)
                {
                    # Do nothing, skip line
                }
                # Handle targetScope
                elseif ($line -match "^\s*targetScope\s*=\s*'(resourceGroup|subscription|managementGroup|tenant)'\s*($scopeDirective)?\s*$")
                {
                    append "targetScope = '$currentScope'"
                }
                # Handle conditional lines
                elseif ($line -match "[^\s]+\s*$scopeDirective" -and $line.Substring(0, $line.LastIndexOf("//")).Trim().Length -gt 0)
                {
                    # If current scope, remove directive; otherwise, remove line
                    if ($line.Substring($line.LastIndexOf("//")) -match "@$currentScope")
                    {
                        # If line is commented, uncomment it
                        if ($line -match '^\s*//') { $line = ([regex]'//\s*').Replace($line, '', 1) }

                        # Append line without directive
                        append ($line.TrimEnd() -creplace "$scopeDirective$", '')
                    }
                    else
                    {
                        # Do nothing, skip line
                    }
                }
                # Handle conditional blocks
                elseif ($line -match "^\s*$scopeDirective\s*$")
                {
                    # Check to see if the directive is for the current scope
                    $isCurrentScopeBlock = $line.Substring($line.LastIndexOf("//")) -match "@$currentScope"

                    # Loop thru next lines until we find a directive or empty line
                    while ($lines.Count -gt $i + 1 -and -not ($lines[$i + 1] -match "^\s*$scopeDirective\s*$") -and $lines[$i + 1].Trim().Length -gt 0)
                    {
                        # If current scope, uncomment; otherwise, skip line
                        if ($isCurrentScopeBlock)
                        {
                            append ([regex]'//\s*').Replace($lines[++$i], '', 1)
                        }
                        else
                        {
                            $i++
                        }
                    }
                }
                # Append standard code
                else
                {
                    append $line
                }

                # Move to next line
                $i++
            }

            # Write main file
            & "$PSScriptRoot/New-Directory" (Join-Path $outDir $moduleName (Split-Path $Path))
            if ($Debug)
            {
                $sb.ToString()
            }
            else
            {
                $sb.ToString() | Out-File (Join-Path $outDir $moduleName $Path)
            }

            # Write template files, if metadata.json exists
            $scaffoldInputsFile = Join-Path $srcDir scaffold.json
            if ($CopySupportingFiles -and -not $Debug -and (Test-Path $scaffoldInputsFile))
            {
                @('main.json', 'metadata.json', 'README.md', 'version.json') `
                | ForEach-Object {
                    $sourceFile = Join-Path $scaffoldDir $_
                    if (Test-Path $sourceFile)
                    {
                        Copy-Item $sourceFile (Join-Path $outDir $moduleName)
                    }
                }

                function formatString($text)
                {
                    $formatParams = @{
                        resourceGroup   = @{ scopeLowerPlural = "resource groups" }
                        subscription    = @{ scopeLowerPlural = "subscriptions" }
                        managementGroup = @{ scopeLowerPlural = "management groups" }
                        tenant          = @{ scopeLowerPlural = "billing accounts" }
                    }[$currentScope]
                    $formatParams.Keys `
                    | ForEach-Object { $text = $text.Replace("{$_}", $formatParams[$_]) }
                    return $text
                }
                $scaffoldInputs = Get-Content $scaffoldInputsFile | ConvertFrom-Json
                if (-not ($scaffoldInputs.version -match '^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(?:[\da-z\-]+)(?:\.(?:[\da-z\-]+))*)?$'))
                {
                    Write-Error 'Version in scaffold.json must be in the format of "#.#" or "v#.#-x#.x".'
                }

                # Update metadata.json
                $metadataFile = Join-Path $outDir $moduleName metadata.json
                $metadata = Get-Content $metadataFile | ConvertFrom-Json
                $metadata.name = formatString $scaffoldInputs.name
                $metadata.summary = formatString ($scaffoldInputs.text | Where-Object { $_.scopes.Contains($currentScope) }).summary
                $metadata | ConvertTo-Json -Depth 100 | Set-Content $metadataFile
                if ($metadata.summary.Length -gt 120)
                {
                    Write-Error 'Summary in metadata.json cannot be longer than 120 characters.'
                }

                # Update version.json
                $versionFile = Join-Path $outDir $moduleName version.json
                $version = Get-Content $versionFile | ConvertFrom-Json
                $version.version = $scaffoldInputs.version
                $version | ConvertTo-Json -Depth 100 | Set-Content $versionFile

                # Update README.md
                $readmeFile = Join-Path $outDir $moduleName README.md
                $readme = Get-Content $readmeFile
                $desc = formatString (Get-Content (Join-Path $srcDir README.md))
                ("# $($metadata.name)", '', $metadata.summary, '', '## Description', '', $desc, '', $readMe) `
                | Set-Content $readmeFile
            }
        }
    }

    # Generate module and test code
    Write-Host "Building registry module $($srcDir.Name)..."
    Build-Modules main.bicep -CopySupportingFiles
    Build-Modules (Join-Path test main.test.bicep)

    # Copy tests to README.md examples
    if (-not $Debug)
    {
        Get-ChildItem (Join-Path $outDir * test main.test.bicep) `
        | Where-Object { $_.Directory.Parent.Name -match "-$($srcDir.Name)$" } `
        | ForEach-Object {
            $testFile = $_
            $targetModuleName = $testFile.Directory.Parent.Name
            $sb = [System.Text.StringBuilder]::new()
            $writingModule = $false

            Get-Content $testFile `
            | ForEach-Object {
                $line = $_
                # If test comment, write example header
                if ($line -match '^\s*//\s*Test\s')
                {
                    # Parse test number and description
                    $regex = [regex]::Matches($line.Trim(), '^//\s*Test\s*([0-9]+)\s*-\s*(.*)')
                    $number = $regex.Groups[1].Value
                    $text = $regex.Groups[2].Value

                    [void]$sb.AppendLine().AppendLine("### Example $number").AppendLine()
                    [void]$sb.AppendLine($text).AppendLine()
                    [void]$sb.AppendLine('```bicep')
                }
                # If module, adjust the target destination
                elseif ($line -match '^module\s*' -and $line -match '../main.bicep')
                {
                    $version = (Get-Content "$outDir/$targetModuleName/version.json" -Raw | ConvertFrom-Json).PSObject.Properties['version'].Value
                    $line = $line -replace "../main.bicep", "br/public:cost/$($testFile.Directory.Parent.Name):$version"
                    [void]$sb.AppendLine($line)
                    $writingModule = $true
                }
                # If module body, append code
                elseif ($writingModule -and -not ($line -match '^}$'))
                {
                    [void]$sb.AppendLine($line)
                }
                # If end of module, close code block
                elseif ($writingModule -and $line -eq '}')
                {
                    [void]$sb.AppendLine($line).AppendLine('```')
                    $writingModule = $false
                }
            }

            # Append examples to README file
            $sb.ToString() | Out-File (Join-Path (Split-Path $testFile -Parent) '..' 'README.md') -Append
        }
    }

    Write-Host ''
}
