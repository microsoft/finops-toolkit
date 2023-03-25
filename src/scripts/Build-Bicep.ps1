<#
.SYNOPSIS
    Builds all toolkit templates for publishing to Azure Quickstart Templates.
.DESCRIPTION
    Run this from the /src/scripts folder.
.EXAMPLE
    ./Build-Bicep ../bicep-registry/module-name
    Generates separate modules for each supported scope for the specified module.
.EXAMPLE
    ./Build-Bicep ../bicep-registry/module-name -Scope subscription
    Generates the module for only one scope (subscription in this case).
.EXAMPLE
    ./Build-Bicep ../bicep-registry/module-name -Scope subscription -Debug
    Renders main module and test bicep code to the console instead of generating files.
.PARAMETER Module
    Path to the module to build.
.PARAMETER Scope
    Optional. Scope to build. If not specified, all scopes will be built.
.PARAMETER Debug
    Optional. Renders main module and test bicep code to the console instead of generating files. Line numbers map to original file.
#>
Param (
    [Parameter(Position = 0)][string] $Module,
    [string] $Scope
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

$outdir = "../../release"
$scopeList = '(subscription|resourceGroup|managementGroup|tenant)';
$scopeDirective = "//(\s*@$scopeList)+";
$dir = Get-Item $Module;

# List of supported scopes to be updated later
$script:scopes = @()

# Generates modules for each supported scope
function Build-Modules([string] $Path, [switch] $CopySupportingFiles) {
    # Confirm path
    if (-not (Test-Path (Join-Path $Module $Path))) {
        return;
    }
    
    # Read code from the bicep file
    $lines = (Get-Content (Join-Path $Module $Path));

    # Get the supported scopes
    $script:scopes = [regex]::Matches([regex]::Matches($lines, $scopeDirective).Value, $scopeList).Value `
    | Sort-Object -Unique `
    | Where-Object { $_.ToLower() -eq $Scope.ToLower() -or [string]::IsNullOrWhitespace($Scope) }

    # Loop thru each scope
    $script:scopes `
    | ForEach-Object { 
        $currentScope = $_
        $moduleName = "$($currentScope.ToLower())-$($dir.Name)"
  
        if ($CopySupportingFiles) {
            Write-Host "  $currentScope..."
        }

        # Init string builder for the scope output
        $sb = [System.Text.StringBuilder]::new()
  
        # Write debug header
        if ($Debug) {
            Write-Host $moduleName
            Write-Host "".PadLeft($moduleName.Length, "=")
        }
  
        # Start on second line to get past the supported scope directive
        $i = 1
        $script:lastLineEmpty = $true
        while ($i -lt ($lines.Count)) {
            # Helper functions
            $script:isNewLine = $true
            function append([string] $Text, [switch] $NoNewLine) {
                if ($Debug -and $script:isNewLine) { [void]$sb.Append("$($i.ToString().PadLeft(3, ' '))|  ") }
                if ($NoNewLine) { [void]$sb.Append($Text) } else { [void]$sb.AppendLine($Text) }
                $script:isNewLine = -not $NoNewLine
                $script:lastLineEmpty = $Text.Trim() -eq ''
            }
  
            $line = $lines[$i]
  
            # Remove empty lines before content starts
            if ($line.Trim() -eq '' -and $script:lastLineEmpty) {
                # Do nothing, skip line
            }
            # Handle targetScope
            elseif ($line -match '^\s*targetScope\s*=\s*''(resourceGroup|subscription|managementGroup|tenant)''\s*$') {
                append ($line -creplace "'(resourceGroup|subscription|managementGroup|tenant)'", "'$currentScope'")
            }
            # Handle conditional lines
            elseif ($line -match "[^\s]+\s*$scopeDirective" -and $line.Substring(0, $line.LastIndexOf("//")).Trim().Length -gt 0) {
                # If current scope, remove directive; otherwise, remove line
                if ($line.Substring($line.LastIndexOf("//")) -match "@$currentScope") {
                    # If line is commented, uncomment it
                    if ($line -match '^\s*//') { $line = ([regex]'//\s*').Replace($line, '', 1) }

                    # Append line without directive
                    append ($line.TrimEnd() -creplace "$scopeDirective$", '')
                } else {
                    # Do nothing, skip line
                }
            }
            # Handle conditional blocks
            elseif ($line -match "^\s*$scopeDirective\s*$") {
                # Check to see if the directive is for the current scope
                $isCurrentScopeBlock = $line.Substring($line.LastIndexOf("//")) -match "@$currentScope"
  
                # Loop thru next lines until we find a directive or empty line
                while (-not ($lines[$i + 1] -match "^\s*$scopeDirective\s*$") -and $lines[$i + 1].Trim().Length -gt 0) {
                    # If current scope, uncomment; otherwise, skip line
                    if ($isCurrentScopeBlock) {
                        append ([regex]'//\s*').Replace($lines[++$i], '', 1)
                    } else {
                        $i++
                    }
                }
            }
            # Append standard code
            else {
                append $line
            }
 
            # Move to next line
            $i++
        }
  
        # Write main file
        ./New-Directory (Join-Path $outdir $moduleName (Split-Path $Path))
        if ($Debug) { 
            $sb.ToString()
        } else {
            $sb.ToString() | Out-File (Join-Path $outdir $moduleName $Path)
        }

        # Write supporting files
        if ($CopySupportingFiles -and -not $Debug) {
            @('main.json', 'metadata.json', 'README.md', 'version.json') `
            | ForEach-Object { Copy-Item (Join-Path $Module $_) (Join-Path $outdir $moduleName) }
        }
    }
}

# Generate module and test code
Build-Modules main.bicep -CopySupportingFiles
Build-Modules (Join-Path test main.test.bicep)

# Copy tests to README.md examples
if (-not $Debug) {    
    Get-ChildItem (Join-Path $outdir * test main.test.bicep) `
    | Where-Object { $_.Directory.Parent.Name -match "-$($dir.Name)$" } `
    | ForEach-Object {
        $testFile = $_
        $sb = [System.Text.StringBuilder]::new()
        $writingModule = $false
        
        Get-Content $testFile `
        | ForEach-Object {
            $line = $_
            # If test comment, write example header
            if ($line -match '^\s*//\s*Test\s') {
                # Parse test number and description
                $regex = [regex]::Matches($line.Trim(), '^//\s*Test\s*([0-9]+)\s*-\s*(.*)');
                $number = $regex.Groups[1].Value
                $text = $regex.Groups[2].Value
    
                [void]$sb.AppendLine().AppendLine("### Example $number").AppendLine()
                [void]$sb.AppendLine($text).AppendLine()
                [void]$sb.AppendLine('```bicep')
            }
            # If module, adjust the target destination
            elseif ($line -match '^module\s*' -and $line -match '../main.bicep') {
                $line = $line -replace "../main.bicep", "br/public:cost/$($testFile.Directory.Parent.Name):1.0"
                [void]$sb.AppendLine($line)
                $writingModule = $true
            }
            # If module body, append code
            elseif ($writingModule -and -not ($line -match '^}$')) {
                [void]$sb.AppendLine($line)
            }
            # If end of module, close code block
            elseif ($writingModule -and $line -eq '}') {
                [void]$sb.AppendLine($line).AppendLine('```')
                $writingModule = $false
            }
        }
    
        # Append examples to README file
        $sb.ToString() | Out-File (Join-Path (Split-Path $testFile -Parent) '..' 'README.md') -Append
    }
}
