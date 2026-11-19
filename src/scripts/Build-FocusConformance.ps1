# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Generates the FOCUS conformance document for a specific FOCUS version.

    .PARAMETER FocusRepo
    Optional. Name of the folder where the FOCUS repo is cloned. Default = FOCUS_Spec.

    .PARAMETER Branch
    Optional. Indicates what branch of FOCUS repository to use when generating the conformance report. Default = v1.4.

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
    [string] $Branch = "v1.4",
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
} | Select-Object -First 1

# Get the latest tags
Push-Location
Set-Location $specDir
git fetch --all --tags --quiet

# Switch to the tag for the specified version
git checkout $Branch --quiet
$focusVersion = (git describe --tags --exact-match) -replace 'v', ''
Write-Host "Parsing rules from FOCUS $focusVersion..."

# Find all BCP14 requirements
# NOTE: FOCUS 1.2 and earlier defined columns in <spec>/columns/*.md; FOCUS 1.3+ moved them to <spec>/datasets/<dataset>/columns/*.md and added dataset-level requirements in <spec>/datasets/<dataset>/dataset.md
$specFiles = @(
    Get-Item -Path "$specDir/*/*.md" -ErrorAction SilentlyContinue
    Get-Item -Path "$specDir/datasets/*/dataset.md" -ErrorAction SilentlyContinue
    Get-Item -Path "$specDir/datasets/*/columns/*.md" -ErrorAction SilentlyContinue
)
$reqs = Select-String -Pattern '(MUST|REQUIRED|SHALL|SHOULD|RECOMMENDED|MAY|OPTIONAL)' -Path $specFiles.FullName -CaseSensitive -AllMatches
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

    # Capitalize the first word, lowercase the rest, and preserve acronyms
    $words = for ($i = 0; $i -lt $words.Count; $i++)
    {
        $word = $words[$i]
        if (Is-Acronym $word)
        {
            $word
        }
        elseif ($i -eq 0)
        {
            $word.Substring(0, 1).ToUpper() + $word.Substring(1)
        }
        else
        {
            $word.ToLower()
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
    $specDataset = $null
    if ($path.StartsWith('columns')) { $specType = 'Column' }
    elseif ($path -match '^datasets/([^/]+)/columns/') { $specType = 'Column'; $specDataset = Format-FileNameAsTitleCase $Matches[1] }
    elseif ($path -match '^datasets/([^/]+)/dataset\.md$') { $specType = 'Dataset'; $specDataset = Format-FileNameAsTitleCase $Matches[1] }
    elseif ($path.StartsWith('attributes')) { $specType = 'Attribute' }
    else { $specType = $path.Split('/')[0] }

    # Read ID and name
    # NOTE: FOCUS 1.3+ uses "Attribute Name" instead of "Display Name" for attributes and appends <!--SkipTOC--> comments to some dataset headers
    $content = (Get-Content -Path $line.Path -Raw)
    $idAndName = [regex]::Matches($content, "## (?:Column ID|Attribute ID|Dataset ID|Display Name|Attribute Name)(?:<!--SkipTOC-->)?\s*(?:\r?\n?){2}([^\r\n]+)")
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
    $desc = [regex]::Matches($content, "## Description(?:<!--SkipTOC-->)?\s*(?:\r?\n?){2}([^\r\n]+)")
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
            specDataset      = $specDataset
            specDesc         = $specDesc ? [regex]::Replace($specDesc.Trim('* ').Replace('*', ''), '\[([^\]]+)\]\([^)]+\)', '$1') : $null
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

# Statuses and notes curated in the existing conformance document, keyed by "<section type>|<dataset>|<rule type>|<criteria>"
# Populated before regenerating the document so previously evaluated requirements keep their curated status
$script:curatedStatuses = @{}

function Get-CuratedStatus($SectionType, $Dataset, $RuleType, $Criteria)
{
    $criteriaKey = ($Criteria -replace '\s+', ' ').Trim()
    $datasetKey = ($SectionType -eq 'Column' -and $Dataset) ? $Dataset.ToLower() : ''

    # Look for a status curated for the same dataset (or no dataset for attributes and dataset-level requirements)
    $lookupKey = "$SectionType|$datasetKey|$RuleType|$criteriaKey"
    if ($script:curatedStatuses.ContainsKey($lookupKey))
    {
        return $script:curatedStatuses[$lookupKey]
    }

    # Fall back to statuses curated before FOCUS 1.3 restructured columns under datasets, but only for attributes and
    # Cost and Usage columns (the only dataset that existed then); other datasets must be evaluated separately
    if ($SectionType -eq 'Attribute' -or ($SectionType -eq 'Column' -and (-not $Dataset -or $Dataset -eq 'Cost and Usage')))
    {
        $lookupKey = "$SectionType||$RuleType|$criteriaKey"
        if ($script:curatedStatuses.ContainsKey($lookupKey))
        {
            return $script:curatedStatuses[$lookupKey]
        }
    }

    return [PSCustomObject]@{ conformance = 'Not Evaluated'; notes = '' }
}

function Group-Rules($specType)
{
    # Dictionary to keep track of used keys
    $seen = @{}

    $rules `
    | Where-Object { ($_.specType -eq $specType) -or ($null -eq $specType -and $_.specType -ne 'Attribute' -and $_.specType -ne 'Column' -and $_.specType -ne 'Dataset') } `
    | Group-Object -Property sourceFile `
    | ForEach-Object {
        # Generate a unique key for each file
        $id = $_.Group[0].specId
        $dataset = $_.Group[0].specDataset

        # Prefix column keys with the dataset abbreviation to keep keys unique across datasets (FOCUS 1.3+)
        $dsPrefix = ($dataset -and $_.Group[0].specType -eq 'Column') ? "$(($dataset -split '').Where{ $_ -cmatch '[A-Z]' } -join '')-" : ''

        $caps = ($id -split '').Where{ $_ -cmatch '[A-Z]' } -join ''
        $base = "$dsPrefix$caps"
        if ($seen.ContainsKey($base))
        {
            # Get second letter of the first word to disambiguate
            $firstWord = ([regex]::Matches($id, '[A-Z][a-z]*') | ForEach-Object { $_.Value })[0]
            $key = "$dsPrefix$($firstWord.Substring(0, 2))$($caps.Substring(1))"

            # Get second letter of the second word to disambiguate further if needed
            if ($seen.ContainsKey($key))
            {
                $secondWord = ([regex]::Matches($id, '[A-Z][a-z]*') | ForEach-Object { $_.Value })[1]
                $key = "$dsPrefix$($caps[0])$($secondWord.Substring(0, 2))$($caps.Substring(2))"
            }
        }
        else
        {
            $key = $base
        }
        $seen[$base] = $true
        $seen[$key] = $true

        return [PSCustomObject]@{
            id         = $id
            key        = $key
            name       = $_.Group[0].specName
            dataset    = $dataset
            desc       = $_.Group[0].specDesc
            sourceFile = $_.Name
            rules      = $_.Group | ForEach-Object {
                $curated = Get-CuratedStatus -SectionType $specType -Dataset $dataset -RuleType $_.ruleType -Criteria $_.ruleText
                return [PSCustomObject]@{
                    type        = $_.ruleType
                    criteria    = $_.ruleText
                    level       = $_.ruleLevel
                    sourceLine  = $_.sourceLineNumber
                    conformance = $curated.conformance
                    notes       = $curated.notes
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
                type  = 'Datasets'
                specs = Group-Rules 'Dataset'
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

    # Parse curated statuses and notes from the existing generated sections so unchanged requirements keep their evaluation
    $('Attributes', 'Columns', 'Datasets') | ForEach-Object {
        $sectionType = $_.TrimEnd('s')
        if (-not $sections.Contains($_)) { return }
        $currentDataset = ''
        ($sections[$_] -split "`r?`n") | ForEach-Object {
            # Track the dataset from column headings (e.g., "### Billed cost (Cost and usage)") to keep statuses dataset-specific
            if ($_ -match '^###\s')
            {
                $currentDataset = $_ -match '\(([^)]+)\)\s*$' ? $Matches[1].ToLower() : ''
                return
            }
            $cells = $_.Split('|')
            if ($cells.Count -lt 6) { return }
            $ruleType = $cells[2].Trim()
            if ($ruleType -cnotmatch '^(MUST|REQUIRED|SHALL|SHOULD|RECOMMENDED|MAY|OPTIONAL)$') { return }
            $criteria = ($cells[3] -replace '\s+', ' ').Trim()
            $script:curatedStatuses["$sectionType|$currentDataset|$ruleType|$criteria"] = [PSCustomObject]@{
                conformance = $cells[4].Trim()
                notes       = ($cells[5..($cells.Count - 2)] -join '|').Trim()
            }
        }
    }
    Write-Host "Found $($script:curatedStatuses.Count) curated statuses in the existing document"

    $('Attribute', 'Dataset', 'Column') | ForEach-Object {
        $sectionType = $_
        $headerText = "$($_)s"
        $groups = @(Group-Rules $_)
        if ($groups.Count -eq 0)
        {
            # Skip empty sections (e.g., datasets don't exist before FOCUS 1.3)
            return
        }
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("## $headerText")
        $groups | ForEach-Object {
            $file = $_
            $key = $file.key
            $ruleNumber = @(0)
            $displayName = Format-DisplayNameAsSentenceCase $file.name
            if ($file.dataset -and $sectionType -eq 'Column')
            {
                $displayName += " ($(Format-DisplayNameAsSentenceCase $file.dataset))"
            }
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("### $displayName")
            [void]$sb.AppendLine('')
            if ($file.desc)
            {
                [void]$sb.AppendLine($file.desc)
                [void]$sb.AppendLine('')
            }
            [void]$sb.AppendLine("Source: [$($file.sourceFile)](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/$Branch/specification/$($file.sourceFile))")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('| ID | Type | Criteria | Status | Notes |')
            [void]$sb.AppendLine('|----|------|----------|--------|-------|')
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
        if ($sections.Contains($headerText))
        {
            $sections.$headerText = $sb.ToString()
        }
        else
        {
            # Insert new sections before the Columns section (e.g., Datasets, which didn't exist before FOCUS 1.3)
            $insertIndex = [array]::IndexOf(@($sections.Keys), 'Columns')
            if ($insertIndex -lt 0) { $insertIndex = $sections.Count }
            $sections.Insert($insertIndex, $headerText, $sb.ToString())
        }
    }

    # Write each section's content (value only) to the file
    $sb = [System.Text.StringBuilder]::new()
    $sections.GetEnumerator() | ForEach-Object { [void]$sb.Append($_.Value) }
    # NoNewline because each section already ends with a newline
    $sb.ToString() | Out-File $docPath -Encoding utf8 -Force -NoNewline
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
