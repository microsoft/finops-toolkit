# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Generates the FOCUS conformance document for a specific FOCUS version.

    .PARAMETER FocusRepo
    Optional. Name of the folder where the FOCUS repo is cloned. Default = FOCUS_Spec.

    .PARAMETER Branch
    Optional. Indicates what branch of FOCUS repository to use when generating the conformance report. Default = v1.2.

    .PARAMETER MetadataOnly
    Optional. Indicates whether to only generate metadata about the release and not the markdown file. Default = False.

    .EXAMPLE
    ./Build-FocusConformance -Version 1.2

    Generates a markdown conformance report for FOCUS 1.2.

    .EXAMPLE
    ./Build-FocusConformance -MetadataOnly

    Generates a collection of metadata about the FOCUS conformance rules from the specification version.
#>
param (
    [string] $FocusRepo = "FOCUS_Spec",
    [string] $Branch = "v1.2",
    [switch] $MetadataOnly
)

$rootDir = "$PSScriptRoot/../.."
$docDir = "$rootDir/docs-mslearn/focus"
$docPath = "$rootDir/docs-mslearn/focus/conformance-full-report.md"

# Find the local repo folder
Write-Debug "Verifying repo..."
$specDir = @($FocusRepo, "FOCUS_Spec", "focus") | ForEach-Object {
    $dir = "$rootDir/../$_/specification"
    if (Test-Path $dir)
    {
        Write-Debug "  Found @ $dir"
        return (Get-Item $dir).FullName
    }
    Write-Debug "  Not @ $dir"
}

# Get the latest tags
Push-Location
Set-Location $specDir
git fetch --all --tags --quiet

# Switch to the tag for the specified version
git checkout $Branch --quiet
$focusVersion = (git describe --tags --exact-match) -replace 'v', ''
Write-Host "Parsing rules from FOCUS $focusVersion..."

# Find all BCP14 requirements
$reqs = Select-String -Pattern '(MUST|REQUIRED|SHALL|SHOULD|RECOMMENDED|MAY|OPTIONAL)' -Path "$specDir/*/*.md" -CaseSensitive -AllMatches
Write-Host "  Found $($reqs.Matches.Length) requirements"
Write-Host

function Format-FileNameAsPascalCase($fileName)
{
    return ($fileName.Replace('.md', '').Split('_') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
}
function Format-FileNameAsTitleCase($fileName)
{
    if ($fileName.Length -eq 0) { return }
    return ($fileName.Replace('.md', '').Split('_') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ' ' -replace ' And ', ' and '
}
function Format-DisplayNameAsSentenceCase
{
    param (
        [Parameter(Mandatory)]
        [string]$InputString
    )

    # Split the string into words
    $words = $InputString -split '\s+'

    if ($words.Count -eq 0) { return '' }

    # Define a helper to detect acronyms (all caps, 2+ letters)
    function Is-Acronym($word)
    {
        return $word -cmatch '^[A-Z]{2,}$'
    }

    # Lowercase the first non-acronym word and preserve acronyms
    $words = $words | ForEach-Object -Begin {
        $i = 0
    } -Process {
        if (Is-Acronym $_)
        {
            return $_
        }
        elseif ($i -eq 0)
        {
            $i++
            return $words[0].Substring(0, 1).ToUpper() + $words[0].Substring(1)
        }
        else
        {
            return $_.ToLower()
        }
    }

    return ($words -join ' ')
}

$script:currSpec = ''
$script:currRuleCount = 0
function Write-ParsingProgress($Id, $NewRules)
{
    if ($script:currSpec -eq $Id)
    {
        $script:currRuleCount += $NewRules
    }
    else
    {
        if (-not [string]::IsNullOrWhitespace($script:currSpec))
        {
            Write-Host "  $script:currSpec = $script:currRuleCount rule$(if ($script:currRuleCount -ne 1) { "s" })"
        }
        $script:currSpec = $Id
        $script:currRuleCount = $NewRules
    }
}

# Create rules object
$rules = $reqs | Select-Object -Property Path, FileName, LineNumber, Line, Matches | ForEach-Object {
    # Save file attributes
    $line = $_
    $path = $line.Path.Replace($specDir, '').Replace('\', '/').Trim('/')
    if ($path.StartsWith('columns')) { $specType = 'Column' } 
    elseif ($path.StartsWith('attributes')) { $specType = 'Attribute' } 
    else { $specType = $path.Split('/')[0] }
    
    # Read ID and name
    $content = (Get-Content -Path $line.Path -Raw)
    $idAndName = [regex]::Matches($content, "## (?:Column ID|Attribute ID|Display Name)\s*(?:\r?\n?){2}([^\r\n]+)")    
    if ($idAndName.Count -eq 2)
    {
        $specId = $idAndName[0].Groups[1]
        $specName = $idAndName[1].Groups[1]
    }
    else
    {
        $specId = Format-FileNameAsPascalCase $line.FileName
        $specName = Format-FileNameAsTitleCase $line.FileName
    }
    
    # Read description
    $desc = [regex]::Matches($content, "## Description\s*(?:\r?\n?){2}([^\r\n]+)")    
    if ($desc.Count -gt 0)
    {
        $specDesc = $desc[0].Groups[1].ToString()
    }
    else
    {
        $specDesc = $null
    }
    
    Write-ParsingProgress -Id "$specName $specType" -NewRules $line.Matches.Length

    # Loop thru matches
    $line.Matches | ForEach-Object {
        $start = $line.Line.Substring(0, $_.Index).IndexOf('. ') + 1
        $start = $start -eq 0 ? $start : ($start + 1)
        $end = $line.Line.IndexOf('. ', $_.Index) + 1
        $sentence = ($end -eq 0 ? $line.Line.Substring($start) : $line.Line.Substring($start, $end - $start)) -replace '\[([^\]]+)\]\([^\)]+\)', '$1'
        [PSCustomObject]@{
            specId           = $specId
            specType         = $specType
            specName         = $specName
            specDesc         = [regex]::Replace($specDesc.Trim('* ').Replace('*', ''), '\[([^\]]+)\]\([^)]+\)', '$1')
            ruleType         = $_.Value
            ruleText         = [regex]::Replace($sentence.Trim('* ').Replace('*', ''), '\[([^\]]+)\]\([^)]+\)', '$1')
            ruleLevel        = ($sentence.Length - $sentence.Trim('* ').Length)  # Count indentation level
            sourceFile       = $path
            sourceLineNumber = $line.LineNumber
            sourceLine       = $line.Line
        }
    }
}

Write-ParsingProgress
Write-Host "Generated $($rules.Length) rules"

$flatList = ([PSCustomObject]@{
        version = $focusVersion
        rules   = $rules
    })

function Group-Rules($specType)
{
    # Dictionary to keep track of used keys
    $seen = @{}

    $rules `
    | Where-Object { ($_.specType -eq $specType) -or ($null -eq $specType -and $_.specType -ne 'Attribute' -and $_.specType -ne 'Column') } `
    | Group-Object -Property sourceFile `
    | ForEach-Object {
        # Generate a unique key for each file
        $id = $_.Group[0].specId
        $base = ($id -split '').Where{ $_ -cmatch '[A-Z]' } -join ''
        if ($seen.ContainsKey($base))
        {
            # Get second letter of the first word to disambiguate
            $firstWord = ([regex]::Matches($id, '[A-Z][a-z]*') | ForEach-Object { $_.Value })[0]
            $key = "$($firstWord.Substring(0, 2))$($base.Substring(1))"
            
            # Get second letter of the second word to disambiguate further if needed
            if ($seen.ContainsKey($key))
            {
                $secondWord = ([regex]::Matches($id, '[A-Z][a-z]*') | ForEach-Object { $_.Value })[1]
                $key = "$($base[0])$($secondWord.Substring(0, 2))$($base.Substring(2))"
            }
        }
        else
        {
            $key = $base
        }
        $seen[$base] = $true

        return [PSCustomObject]@{
            id         = $id
            key        = $key
            name       = $_.Group[0].specName
            desc       = $_.Group[0].specDesc
            sourceFile = $_.Name
            rules      = $_.Group | ForEach-Object {
                return [PSCustomObject]@{
                    type        = $_.ruleType
                    criteria    = $_.ruleText
                    level       = $_.ruleLevel
                    sourceLine  = $_.sourceLineNumber
                    conformance = 'Supports/Partially Supports/Does Not Support/Not Applicable/Not Evaluated'
                    notes       = ''
                }
            }
        }
    }
}

if ($MetadataOnly)
{
    return ([PSCustomObject]@(
            [PSCustomObject]@{
                type  = 'Attribute'
                specs = Group-Rules 'Attribute'
            }
            [PSCustomObject]@{
                type  = 'Columns'
                specs = Group-Rules 'Column'
            }
            [PSCustomObject]@{
                type  = 'Others'
                specs = Group-Rules
            }
        )) | Where-Object { $_.specs.Length -gt 0 } #| ConvertTo-Json -Depth 5
}
else
{
    # Read current conformance document
    $lines = Get-Content $docPath
    $sections = [ordered]@{}
    $headerText = "Preamble"
    $sb = [System.Text.StringBuilder]::new()
    foreach ($line in $lines)
    {
        # If line is a header, write previous section and start a new one
        if ($line -match '^(##?)\s+(.*)')
        {
            $sections.$headerText = $sb.ToString()
            $headerText = $Matches[2]
            $sb = [System.Text.StringBuilder]::new()
        }
        
        # Append line to current section
        [void]$sb.AppendLine($line)
    }

    # Write the last section (since there are no more headers)
    $sections.$headerText = $sb.ToString()

    # Output the dictionary-style content
    Write-Host
    Write-Host "Sections in the conformance document:"
    $sections.GetEnumerator() | ForEach-Object {
        Write-Host "- $($_.Key)"
    }

    $('Attribute', 'Column') | ForEach-Object {
        $headerText = "$($_)s"
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("## $headerText")
        Group-Rules $_ | ForEach-Object {
            $file = $_
            $key = $file.key
            $ruleNumber = @(0)
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("### $(Format-DisplayNameAsSentenceCase $file.name)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("<sup>Source: [$($file.sourceFile)](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/$Branch/specification/$($file.sourceFile))</sup>")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('| ID | Type | Criteria | Status | Notes |')
            [void]$sb.AppendLine('|----|------|----------|--------|-------|')
            if ($file.desc)
            {
                [void]$sb.AppendLine("| $($key)0 | (None) | Description: $($file.desc) |  |  |")
            }
            $file.rules | ForEach-Object {
                # Add levels to the rule number if needed
                if ($ruleNumber.Count -lt ($_.level + 1))
                {
                    Write-Verbose "  $($key): Adding L$($_.level) = ($ruleNumber) + $($_.level + 1 - $ruleNumber.Count) levels"
                    $ruleNumber += (@(0) * ($_.level + 1 - $ruleNumber.Count))
                }

                # Increment the rule number and remove nested levels
                $ruleNumber = $ruleNumber[0..$_.level]
                $ruleNumber[$_.level] += 1
                
                [void]$sb.AppendLine("| $key$(($ruleNumber | Where-Object { $_ -ne 0 }) -join '.') | $($_.type) | $($_.criteria) | $($_.conformance) | $($_.notes) |")
            }
        }
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('<br>')
        [void]$sb.AppendLine('')
        $sections.$headerText = $sb.ToString()
    }

    # Write each section's content (value only) to the file
    $sb = [System.Text.StringBuilder]::new()
    $sections.GetEnumerator() | ForEach-Object { [void]$sb.Append($_.Value) }
    $sb.ToString() | Out-File $docPath -Encoding utf8 -Force
}

# TODO: Write to doc file
# ## Terms
# The terms used in the Conformance Level information are defined as follows:
# - Supports: The functionality of the product has at least one method that meets the criterion without known defects or meets with equivalent facilitation.
# - Partially Supports: Some functionality of the product does not meet the criterion.
# - Does Not Support: The majority of product functionality does not meet the criterion.
# - Not Applicable: The criterion is not relevant to the product.
# - Not Evaluated: The product has not been evaluated against the criterion. This can only be used in WCAG Level AAA criteria.
#
# Note: For criteria marked “Supports, ” substantial conformance with the criterion by the product or service has been determined through the Evaluation Testing, which includes a mix of automated and manual testing, as described above.
#
# Note: In the tables below, for all criteria marked “Not Applicable, ” the specific feature covered by that criterion is not part of the product. For example:
# - If pre-recorded audio-only or video-only content is not part of a product, then WCAG criterion 1.2.1 Audio-only and Video-only (Prerecorded) will be marked “Not Applicable.”
# - If the product is software only, then all EN 301 549 Chapter 8 Hardware criteria will be marked “Not Applicable.”

# Return to previous folder
Pop-Location
