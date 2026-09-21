# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds Power BI release artifacts: PBIT templates and pruned PBIP projects.

    .DESCRIPTION
    Generates one PBIT template per report and, unless -NoPbip is specified, one self-contained
    PBIP project per report under the release/pbix folder.

    Each generated PBIP contains only the tables, relationships, and queries that its report
    needs. That removes the manual "remove unused queries" step when saving demo PBIX files and
    guarantees the PBIT and the PBIX are built from the same model, because both are rendered
    from a single prune.

    Tables that no report uses are dropped before the model is loaded, so a broken table that
    isn't shipped can never block a release.

    .PARAMETER Name
    Optional. Name of the report to build. Wildcards supported. Default = * (all).

    .PARAMETER KQL
    Optional. Indicates if the KQL reports should be generated. Default = false (will build all if no types are selected).

    .PARAMETER Storage
    Optional. Indicates if the storage reports should be generated. Default = false (will build all if no types are selected).

    .PARAMETER NoPbip
    Optional. Skips generating pruned PBIP projects and only builds PBIT files. Default = false.

    .EXAMPLE
    ./Build-PowerBI

    Generates all PBIT files and pruned PBIP projects.

    .EXAMPLE
    ./Build-PowerBI CostSummary -Storage

    Generates the Cost summary storage PBIT file and PBIP project.

    .EXAMPLE
    ./Build-PowerBI -NoPbip

    Generates PBIT files only.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-powerbi
#>
param(
    [Parameter(Position = 0)]
    [string]
    $Name = "*",

    [switch]
    $KQL,

    [switch]
    $Storage,

    [switch]
    $NoPbip
)

$ErrorActionPreference = 'Stop'

$srcDir = "$PSScriptRoot/../power-bi"
$relDir = "$PSScriptRoot/../../release"
$pbitDir = "$relDir/pbit"
$pbixDir = "$relDir/pbix"

$version = & "$PSScriptRoot/Get-Version.ps1"
$buildDate = Get-Date -Format 'yyyy-MM-dd'

# Report types that ship as demo PBIX files in PowerBI-demo.zip
$demoTypes = @('storage')

if (-not $KQL -and -not $Storage) { $KQL = $Storage = $true }

#region Report metadata

# Tables and queries to keep in each report are defined in src/power-bi/reports.json so the build
# and the lint tests read the same list. Everything not listed there is removed from the PBIT and
# the PBIP.
$reportsConfigPath = "$srcDir/reports.json"
$reportsConfig = Get-Content $reportsConfigPath -Raw | ConvertFrom-Json -Depth 10

# Demo projects are stamped with this data source so a release never depends on whatever the
# source project was last saved with. Templates always ship with the data source set to null.
$demoConnection = @{
    'Storage URL' = $reportsConfig.demo.storageUrl
    'Cluster URL' = $reportsConfig.demo.clusterUrl
}

$reportMetadata = @{}
$reportsConfig.reports.PSObject.Properties `
| ForEach-Object {
    $reportMetadata[$_.Name] = @{
        Intro       = $_.Value.description
        Tables      = [string[]]@($_.Value.tables)
        Expressions = [string[]]@($_.Value.queries)
    }
}

#endregion Report metadata

#region Helpers

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)


function Write-TextFile($Path, [string[]] $Lines)
{
    [System.IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $script:Utf8NoBom)
}

function Write-UTF16LE($File, $Content, $Json)
{
    Write-Verbose "  Writing UTF-16LE file: $(Split-Path $File -Leaf)..."
    if ($Json) { $Content = [PSCustomObject]$Json | ConvertTo-Json -Depth 5 -Compress }
    [System.IO.File]::WriteAllBytes($File, [System.Text.Encoding]::Unicode.GetBytes($Content))
}

<#
    .SYNOPSIS
    Reads the name from a TMDL declaration (for example, "column 'Foo Bar' = 1" returns "Foo Bar").
#>
function ConvertFrom-TmdlDeclaration([string] $Text)
{
    # Names are either 'quoted' (with '' as an escaped quote) or end at whitespace or "="
    $match = [regex]::Match($Text, "^\s*(?:'(?<quoted>(?:[^']|'')*)'|(?<plain>[^\s=]+))")
    if (-not $match.Success) { return $null }
    if ($match.Groups['quoted'].Success) { return $match.Groups['quoted'].Value.Replace("''", "'") }
    return $match.Groups['plain'].Value
}

<#
    .SYNOPSIS
    Reads the table name from a TMDL column reference (for example, "'My Table'.Col" returns "My Table").
#>
function Get-TmdlReferenceTable([string] $Reference)
{
    # Table names are either 'quoted' (with '' as an escaped quote) or end at "."
    $match = [regex]::Match($Reference, "^\s*(?:'(?<quoted>(?:[^']|'')*)'|(?<plain>[^.\s]+))")
    if (-not $match.Success) { return $null }
    if ($match.Groups['quoted'].Success) { return $match.Groups['quoted'].Value.Replace("''", "'") }
    return $match.Groups['plain'].Value
}

<#
    .SYNOPSIS
    Resolves an allowlist, keeping entries that apply to the specified report type.
#>
function Resolve-Allowlist([string[]] $Entries, [string] $ReportType)
{
    $resolved = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $Entries)
    {
        if ($entry -match '^\[(?<type>[^\]]+)\](?<name>.+)$')
        {
            if ($Matches.type -eq $ReportType) { $resolved.Add($Matches.name) }
        }
        else
        {
            $resolved.Add($entry)
        }
    }
    return , $resolved.ToArray()
}

function ConvertTo-NameSet([string[]] $Names)
{
    return New-Object System.Collections.Generic.HashSet[string]([string[]]$Names, [System.StringComparer]::OrdinalIgnoreCase)
}

<#
    .SYNOPSIS
    Finds names that only differ by case, which Power BI rejects when loading the model.

    .DESCRIPTION
    Tabular models treat names as case-insensitive, so two columns named "region" and "Region"
    cannot coexist. Power BI Desktop and the TMDL text format both allow the file to be saved
    that way, and the failure only shows up when the model is loaded. Detecting it here turns a
    confusing load failure into a specific message that names the file, table, and lines.
#>
function Get-TmdlNameConflict([string] $DefinitionDir)
{
    $conflicts = New-Object System.Collections.Generic.List[object]

    function Add-Conflict($List, $Table, $File, [string] $Text, [System.Text.RegularExpressions.MatchCollection] $Declarations)
    {
        # Group declarations by case-insensitive name without calling functions per name, which is
        # slow in PowerShell for models with hundreds of columns
        $names = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[System.Text.RegularExpressions.Match]]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($declaration in $Declarations)
        {
            $name = if ($declaration.Groups['quoted'].Success) { $declaration.Groups['quoted'].Value.Replace("''", "'") } else { $declaration.Groups['plain'].Value }
            if (-not $names.ContainsKey($name)) { $names[$name] = New-Object 'System.Collections.Generic.List[System.Text.RegularExpressions.Match]' }
            $names[$name].Add($declaration)
        }

        foreach ($group in $names.Values)
        {
            if ($group.Count -lt 2) { continue }
            $scope = if ($Table) { "table '$Table'" } else { 'the query list' }
            $conflicting = ($group | ForEach-Object { if ($_.Groups['quoted'].Success) { $_.Groups['quoted'].Value.Replace("''", "'") } else { $_.Groups['plain'].Value } }) -join ', '
            $lines = ($group | ForEach-Object { [regex]::Matches($Text.Substring(0, $_.Index), "`n").Count + 1 }) -join ', '
            $List.Add([PSCustomObject]@{
                    Table   = $Table
                    File    = $File
                    Message = "$File`: $scope declares names that only differ by case ($conflicting) on lines $lines. Power BI treats names as case-insensitive, so one of them must be renamed or removed."
                })
        }
    }

    $namePattern = "(?:'(?<quoted>(?:[^']|'')*)'|(?<plain>[^\s=]+))"

    Get-ChildItem "$DefinitionDir/tables" -Filter '*.tmdl' -ErrorAction SilentlyContinue `
    | ForEach-Object {
        $file = $_
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $tableMatch = [regex]::Match($text, "(?m)^table\s+$namePattern")
        $tableName = if (-not $tableMatch.Success) { $file.BaseName } elseif ($tableMatch.Groups['quoted'].Success) { $tableMatch.Groups['quoted'].Value.Replace("''", "'") } else { $tableMatch.Groups['plain'].Value }

        # Matching the whole file at once is much faster than reading line by line in PowerShell
        Add-Conflict $conflicts $tableName $file.Name $text ([regex]::Matches($text, "(?m)^\t(?:column|measure)\s+$namePattern"))
    }

    $expressionFile = "$DefinitionDir/expressions.tmdl"
    if (Test-Path $expressionFile)
    {
        $text = [System.IO.File]::ReadAllText($expressionFile)
        Add-Conflict $conflicts $null 'expressions.tmdl' $text ([regex]::Matches($text, "(?m)^expression\s+$namePattern"))
    }

    return , $conflicts.ToArray()
}

<#
    .SYNOPSIS
    Copies a semantic model, keeping only the specified tables.

    .DESCRIPTION
    Tables are removed from disk before the model is loaded so that tables no report ships
    cannot block the build. Relationships that point at a removed table and the matching
    "ref table" entries in model.tmdl are removed at the same time to keep the model loadable.
#>
function Export-PrunedDataset([string] $SourceDir, [string] $TargetDir, [string[]] $KeepTables)
{
    $keep = ConvertTo-NameSet $KeepTables

    Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item (Split-Path $TargetDir -Parent) -ItemType Directory -Force | Out-Null
    Copy-Item $SourceDir $TargetDir -Recurse -Force

    $definitionDir = "$TargetDir/definition"
    $dropped = New-Object System.Collections.Generic.List[string]
    $kept = New-Object System.Collections.Generic.List[string]

    # Remove table files that aren't needed
    Get-ChildItem "$definitionDir/tables" -Filter '*.tmdl' `
    | ForEach-Object {
        $file = $_
        $tableName = $file.BaseName
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName))
        {
            if ($line -match '^table\s+(?<rest>.+)$') { $tableName = ConvertFrom-TmdlDeclaration $Matches.rest; break }
        }

        if ($keep.Contains($tableName))
        {
            $kept.Add($tableName)
        }
        else
        {
            Write-Verbose "  Removing table: $tableName"
            $dropped.Add($tableName)
            Remove-Item $file.FullName -Force
        }
    }

    $droppedSet = ConvertTo-NameSet $dropped

    # Remove "ref table" entries for removed tables
    $modelFile = "$definitionDir/model.tmdl"
    $modelLines = [System.IO.File]::ReadAllLines($modelFile)
    $keptModelLines = $modelLines | Where-Object {
        if ($_ -notmatch '^ref table\s+(?<rest>.+)$') { return $true }
        return -not $droppedSet.Contains((ConvertFrom-TmdlDeclaration $Matches.rest))
    }
    Write-TextFile $modelFile $keptModelLines

    # Remove relationships that point at a removed table
    $removedRelationships = 0
    $relationshipFile = "$definitionDir/relationships.tmdl"
    if (Test-Path $relationshipFile)
    {
        $lines = [System.IO.File]::ReadAllLines($relationshipFile)
        $starts = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -match '^relationship\s' })

        if ($starts.Count -gt 0)
        {
            $output = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $starts[0]; $i++) { $output.Add($lines[$i]) }

            for ($b = 0; $b -lt $starts.Count; $b++)
            {
                $start = $starts[$b]
                $end = if ($b + 1 -lt $starts.Count) { $starts[$b + 1] - 1 } else { $lines.Count - 1 }

                $block = New-Object System.Collections.Generic.List[string]
                $referencesDropped = $false
                for ($i = $start; $i -le $end; $i++)
                {
                    $block.Add($lines[$i])
                    if ($lines[$i] -match '^\s*(from|to)Column:\s*(?<ref>.+)$')
                    {
                        if ($droppedSet.Contains((Get-TmdlReferenceTable $Matches.ref))) { $referencesDropped = $true }
                    }
                }

                if ($referencesDropped)
                {
                    $removedRelationships++
                    continue
                }

                while ($block.Count -gt 0 -and [string]::IsNullOrWhiteSpace($block[$block.Count - 1])) { $block.RemoveAt($block.Count - 1) }
                $block | ForEach-Object { $output.Add($_) }
                $output.Add('')
            }

            Write-TextFile $relationshipFile $output
        }
    }

    # Drop model diagram nodes for removed tables so the diagram matches the model
    $diagramFile = "$TargetDir/diagramLayout.json"
    if (Test-Path $diagramFile)
    {
        $diagram = Get-Content $diagramFile -Raw | ConvertFrom-Json -Depth 100
        foreach ($layout in $diagram.diagrams)
        {
            $layout.nodes = @($layout.nodes | Where-Object { $keep.Contains($_.nodeIndex) })
        }
        $diagram | ConvertTo-Json -Depth 100 | Set-Content $diagramFile -NoNewline
    }

    return [PSCustomObject]@{
        Kept                 = $kept.ToArray()
        Dropped              = $dropped.ToArray()
        RemovedRelationships = $removedRelationships
    }
}

<#
    .SYNOPSIS
    Stamps the version into a report and confirms the Get started page is the active page.
#>
function Get-ReportLayout([string] $ReportDir, [string] $ReportLabel)
{
    $json = (Get-Content "$ReportDir/report.json" -Raw) `
        -replace '\$\$ftkver\$\$', $version `
        -replace '\$\$build-date\$\$', $buildDate

    $report = $json | ConvertFrom-Json -Depth 100

    # Pages are stored in an arbitrary order and displayed by ordinal, so the active page index
    # is an index into the display order, not into the sections array.
    $displayOrder = @($report.sections | Sort-Object @{ Expression = { if ($null -eq $_.ordinal) { 0 } else { $_.ordinal } } })
    $expected = [array]::FindIndex($displayOrder, [Predicate[object]] { param($section) $section.displayName -eq 'Get started' })

    if ($expected -lt 0)
    {
        Write-Warning "$ReportLabel has no 'Get started' page. Leaving the active page unchanged."
        return $json
    }

    $config = $report.config | ConvertFrom-Json -Depth 100
    if ($config.activeSectionIndex -eq $expected) { return $json }

    Write-Warning "$ReportLabel opens on '$($displayOrder[$config.activeSectionIndex].displayName)'. Resetting to 'Get started'."
    $config.activeSectionIndex = $expected
    $report.config = $config | ConvertTo-Json -Depth 100 -Compress
    return ($report | ConvertTo-Json -Depth 100)
}

<#
    .SYNOPSIS
    Lists the table and query names declared in a TMDL model folder without loading the model.
#>
function Get-TmdlObjectName([string] $DefinitionDir)
{
    $names = New-Object System.Collections.Generic.List[string]

    Get-ChildItem "$DefinitionDir/tables" -Filter '*.tmdl' -ErrorAction SilentlyContinue `
    | ForEach-Object {
        foreach ($line in [System.IO.File]::ReadAllLines($_.FullName))
        {
            if ($line -match '^table\s+(?<rest>.+)$') { $names.Add((ConvertFrom-TmdlDeclaration $Matches.rest)); break }
        }
    }

    $expressionFile = "$DefinitionDir/expressions.tmdl"
    if (Test-Path $expressionFile)
    {
        foreach ($line in [System.IO.File]::ReadAllLines($expressionFile))
        {
            if ($line -match '^expression\s+(?<rest>.+)$') { $names.Add((ConvertFrom-TmdlDeclaration $Matches.rest)) }
        }
    }

    return , $names.ToArray()
}

<#
    .SYNOPSIS
    Lists the tables and queries that visuals and filters in a report read from.

    .DESCRIPTION
    Only "From" clauses are read, because those are what Power BI queries. Other entity references,
    like conditional formatting selectors, are ignored when the entity doesn't exist.
#>
function Get-ReportEntityReference([string] $ReportJson)
{
    $references = New-Object System.Collections.Generic.List[object]
    $report = $ReportJson | ConvertFrom-Json -Depth 100

    function Add-Reference($List, [string] $Json, [string] $Page, [bool] $Hidden, [string] $Source)
    {
        if (-not $Json) { return }
        foreach ($from in [regex]::Matches($Json, '"From"\s*:\s*\[(?<items>[^\]]*)\]'))
        {
            foreach ($entity in [regex]::Matches($from.Groups['items'].Value, '"Entity"\s*:\s*"(?<name>(?:[^"\\]|\\.)*)"'))
            {
                $List.Add([PSCustomObject]@{
                        Entity = [regex]::Unescape($entity.Groups['name'].Value)
                        Page   = $Page
                        Hidden = $Hidden
                        Source = $Source
                    })
            }
        }
    }

    Add-Reference $references $report.filters '(all pages)' $false 'report filters'

    foreach ($section in @($report.sections))
    {
        # Configs are JSON strings. Parsing each one is slow, so only the needed values are matched.
        $hidden = "$($section.config)" -match '"visibility"\s*:\s*1\b'
        Add-Reference $references $section.filters $section.displayName $hidden 'page filters'

        foreach ($visual in @($section.visualContainers))
        {
            $visualType = [regex]::Match("$($visual.config)", '"visualType"\s*:\s*"(?<value>[^"]+)"').Groups['value'].Value
            $visualName = [regex]::Match("$($visual.config)", '"name"\s*:\s*"(?<value>[^"]+)"').Groups['value'].Value
            $label = "$visualType visual $visualName".Trim()
            Add-Reference $references $visual.config $section.displayName $hidden $label
            Add-Reference $references $visual.filters $section.displayName $hidden $label
            Add-Reference $references $visual.query $section.displayName $hidden $label
        }
    }

    return , $references.ToArray()
}

<#
    .SYNOPSIS
    Removes comments and string literals from Power Query (M) or DAX so names can be matched safely.

    .DESCRIPTION
    Quoted identifiers are kept: #"Name" in M and 'Name' in DAX.
#>
function Remove-ExpressionLiteral([string] $Expression, [ValidateSet('M', 'DAX')] [string] $Language)
{
    if (-not $Expression) { return '' }

    $pattern = if ($Language -eq 'M')
    {
        '(?<keep>#"(?:[^"]|"")*")|(?<drop>"(?:[^"]|"")*")|(?<drop>//[^\n]*)|(?<drop>/\*.*?\*/)'
    }
    else
    {
        "(?<keep>'(?:[^']|'')*')|(?<drop>`"(?:[^`"]|`"`")*`")|(?<drop>//[^\n]*)|(?<drop>--[^\n]*)|(?<drop>/\*.*?\*/)"
    }

    return [regex]::Replace($Expression, $pattern, {
            param($match)
            if ($match.Groups['keep'].Success) { return $match.Value }
            if ($match.Value.StartsWith('"')) { return '""' }
            return ' '
        }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
}

<#
    .SYNOPSIS
    Finds references to removed tables or queries in the expressions that remain in a model.

    .DESCRIPTION
    A query or measure that references something the allowlist removed loads fine but fails on
    refresh or shows an error in the report. Catching it at build time turns that into a specific
    message instead of a broken demo report or template.
#>
function Get-MissingDependency($Database, [string[]] $RemovedNames)
{
    $missing = New-Object System.Collections.Generic.List[object]
    if (-not $RemovedNames -or $RemovedNames.Count -eq 0) { return , $missing.ToArray() }

    function Test-Reference([string] $Text, [string] $Name, [string] $Language)
    {
        if ($Language -eq 'M')
        {
            $quoted = '#"' + $Name.Replace('"', '""') + '"'
            if ($Text.Contains($quoted)) { return $true }
            if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') { return $false }

            $escaped = [regex]::Escape($Name)
            # A let variable with the same name shadows the query, so it isn't a reference
            if ($Text -match "(?<![\w.#\[])$escaped\s*=(?![=>])") { return $false }
            return $Text -match "(?<![\w.#\[])$escaped(?![\w\]])"
        }

        $quoted = "'" + $Name.Replace("'", "''") + "'"
        if ($Text.Contains($quoted)) { return $true }
        if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { return $false }
        $escaped = [regex]::Escape($Name)
        return $Text -match "(?<![\w'\[])$escaped(?![\w'\]])"
    }

    function Add-Missing($List, [string] $Owner, [string] $Expression, [string] $Language)
    {
        $text = Remove-ExpressionLiteral $Expression $Language
        foreach ($name in $RemovedNames)
        {
            if (Test-Reference $text $name $Language)
            {
                $List.Add([PSCustomObject]@{ Owner = $Owner; Name = $name; Language = $Language })
            }
        }
    }

    foreach ($expression in @($Database.Model.Expressions))
    {
        Add-Missing $missing "query '$($expression.Name)'" $expression.Expression 'M'
    }

    foreach ($table in @($Database.Model.Tables))
    {
        foreach ($partition in @($table.Partitions))
        {
            $language = if ("$($partition.SourceType)" -eq 'Calculated') { 'DAX' } else { 'M' }
            Add-Missing $missing "table '$($table.Name)'" $partition.Source.Expression $language
        }
        if ($table.RefreshPolicy -and $table.RefreshPolicy.SourceExpression)
        {
            Add-Missing $missing "table '$($table.Name)' refresh policy" $table.RefreshPolicy.SourceExpression 'M'
        }
        foreach ($measure in @($table.Measures))
        {
            Add-Missing $missing "measure '$($table.Name)'[$($measure.Name)]" $measure.Expression 'DAX'
        }
        foreach ($column in @($table.Columns | Where-Object { "$($_.Type)" -eq 'Calculated' }))
        {
            Add-Missing $missing "column '$($table.Name)'[$($column.Name)]" $column.Expression 'DAX'
        }
    }

    return , $missing.ToArray()
}

function Assert-NoMissingDependency($Database, [string[]] $RemovedNames, [string] $Label, [string] $ReportName)
{
    $dependencies = Get-MissingDependency $Database $RemovedNames
    if ($dependencies.Count -eq 0) { return }

    $details = ($dependencies | ForEach-Object { "    $($_.Owner) uses '$($_.Name)'" }) -join "`n"
    $names = ($dependencies | ForEach-Object { "'$($_.Name)'" } | Sort-Object -Unique) -join ', '
    throw "$Label needs $names, which reports.json removes:`n$details`nAdd the missing names to the $ReportName report in src/power-bi/reports.json, or remove the reference."
}

#endregion Helpers

#region Setup

& "$PSScriptRoot/New-Directory.ps1" $relDir
& "$PSScriptRoot/New-Directory.ps1" $pbitDir

# Cleanup
Write-Verbose "Removing existing ZIP files..."
if ($KQL)
{
    Remove-Item "$relDir/PowerBI-kql.zip" -Force -ErrorAction SilentlyContinue
    Remove-Item "$pbitDir/*.kql.pbit" -Force -ErrorAction SilentlyContinue
}
if ($Storage)
{
    Remove-Item "$relDir/PowerBI-storage.zip" -Force -ErrorAction SilentlyContinue
    Remove-Item "$pbitDir/*.storage.pbit" -Force -ErrorAction SilentlyContinue
}

# Remove generated projects from earlier builds, but never saved PBIX files. Package-PowerBI
# detects PBIX files saved from an older build and asks for them to be saved again.
if (Test-Path $pbixDir)
{
    $selectedTypes = @(if ($KQL) { 'kql' }) + @(if ($Storage) { 'storage' })
    Get-ChildItem $pbixDir -Force `
    | Where-Object { $_.Name -match '^(?<name>[^.]+)\.(?<type>kql|storage)\.(pbip|Report|Dataset)$' -and $selectedTypes -contains $Matches.type -and $Matches.name -like "*$Name*" } `
    | Remove-Item -Recurse -Force
    if ($Name -eq '*' -and $KQL -and $Storage) { Remove-Item "$pbixDir/.manifest.json" -Force -ErrorAction SilentlyContinue }
}

# Select report types
$types = @()
if ($KQL) { $types += "*$Name*.kql.pbip" } # cSpell:ignore PBIP
if ($Storage) { $types += "*$Name*.storage.pbip" }

# Get reports
$reports = @(Get-ChildItem $srcDir -Recurse -Include $types | Sort-Object FullName)
if ($reports.Count -eq 0)
{
    throw "No Power BI projects matched '$Name'. Confirm the report name."
}
Write-Host "Building $($reports.Count) Power BI report$(if ($reports.Count -ne 1) { 's' })..."

# Setup dependencies
if (-not (Get-Package Microsoft.AnalysisServices -ErrorAction SilentlyContinue))
{
    Write-Verbose "  Installing the Analysis Services package..."
    Write-Verbose "  PRO TIP: Install via an admin prompt to speed up future runs!"
    Install-Package -Name Microsoft.AnalysisServices -ProviderName NuGet -Scope CurrentUser -Force
}

$dllPath = "$((Get-Item (Get-Package Microsoft.AnalysisServices).Source).Directory)/lib/net8.0/Microsoft.AnalysisServices.Tabular.dll"
Write-Verbose "  Adding type from $dllPath"
Add-Type -Path $dllPath

#endregion Setup

#region Build

$conflictCache = @{}
$sourceNameCache = @{}
$manifest = New-Object System.Collections.Generic.List[object]
$allowlistEntries = New-Object System.Collections.Generic.HashSet[string]
$allowlistMatches = New-Object System.Collections.Generic.HashSet[string]

foreach ($inputFile in $reports)
{
    $reportName = $inputFile.Name.Split('.')[0]
    $reportType = $inputFile.Name.Split('.')[1] # Extract "kql" or "storage" from filename
    $baseName = "$reportName.$reportType"
    $folder = $inputFile.DirectoryName
    $reportDir = "$folder/$reportName.Report"
    $datasetDir = "$folder/Shared.Dataset"

    Write-Host "  $baseName..."

    $metadata = $reportMetadata[$reportName]
    if (-not $metadata) { throw "No build metadata is defined for the '$reportName' report. Add it to src/power-bi/reports.json." }

    $keepTables = Resolve-Allowlist $metadata.Tables $reportType
    $keepExpressions = Resolve-Allowlist $metadata.Expressions $reportType

    # Fail on name conflicts this report ships; report the rest once per model
    if (-not $conflictCache.ContainsKey($datasetDir))
    {
        $conflictCache[$datasetDir] = Get-TmdlNameConflict "$datasetDir/definition"
        $conflictCache[$datasetDir] | ForEach-Object { Write-Warning "$($_.Message) It was left out of this build." }
    }
    foreach ($conflict in $conflictCache[$datasetDir])
    {
        if ($conflict.Table -and -not ($keepTables -contains $conflict.Table)) { continue }
        throw "$($conflict.Message) The $baseName report needs it, so the build cannot continue."
    }

    # Prune the model on disk, then load it
    $stagedDataset = "$pbixDir/$baseName.Dataset"
    $pruned = Export-PrunedDataset $datasetDir $stagedDataset $keepTables
    Write-Verbose "  Kept $($pruned.Kept.Count) tables, dropped $($pruned.Dropped.Count), removed $($pruned.RemovedRelationships) relationships"

    $db = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeDatabaseFromFolder("$stagedDataset/definition") # cSpell:ignore TMDL

    # Remove queries this report doesn't use
    $keepExpressionSet = ConvertTo-NameSet $keepExpressions
    @($db.Model.Expressions) `
    | Where-Object { -not $keepExpressionSet.Contains($_.Name) } `
    | ForEach-Object {
        Write-Verbose "  Removing query: $($_.Name)"
        $db.Model.Expressions.Remove($_) | Out-Null
    }

    if (-not $sourceNameCache.ContainsKey($datasetDir)) { $sourceNameCache[$datasetDir] = Get-TmdlObjectName "$datasetDir/definition" }
    $sourceNames = $sourceNameCache[$datasetDir]
    $survivingNames = ConvertTo-NameSet (@($db.Model.Tables | ForEach-Object { $_.Name }) + @($db.Model.Expressions | ForEach-Object { $_.Name }))
    $removedNames = @($sourceNames | Where-Object { -not $survivingNames.Contains($_) })
    $isDemo = $demoTypes -contains $reportType

    # Confirm every visual reads from something the model still has
    $sourceNameSet = ConvertTo-NameSet $sourceNames
    $brokenVisuals = New-Object System.Collections.Generic.List[string]
    $entityReferences = Get-ReportEntityReference (Get-Content "$reportDir/report.json" -Raw)
    $removedReferences = @($entityReferences | Where-Object { -not $survivingNames.Contains($_.Entity) })

    # Stale references to tables that no longer exist anywhere are ignored by Power BI
    $removedReferences `
    | Where-Object { -not $sourceNameSet.Contains($_.Entity) } `
    | Group-Object Entity `
    | ForEach-Object { Write-Verbose "  $($_.Count) references to '$($_.Name)', which isn't in the model." }

    # Hidden pages can't be seen, so a broken visual there is reported without failing the build
    $removedReferences `
    | Where-Object { $sourceNameSet.Contains($_.Entity) -and $_.Hidden } `
    | Group-Object Page `
    | ForEach-Object {
        $entities = ($_.Group.Entity | Sort-Object -Unique | ForEach-Object { "'$_'" }) -join ', '
        Write-Warning "$baseName hidden '$($_.Name)' page reads from $entities, which reports.json removes. The build continues because the page is hidden."
    }

    $removedReferences `
    | Where-Object { $sourceNameSet.Contains($_.Entity) -and -not $_.Hidden } `
    | Group-Object Entity, Page, Source `
    | ForEach-Object { $brokenVisuals.Add("    '$($_.Group[0].Page)' page $($_.Group[0].Source) reads from '$($_.Group[0].Entity)'") }

    if ($brokenVisuals.Count -gt 0)
    {
        throw "$baseName has visuals that read from tables reports.json removes:`n$($brokenVisuals -join "`n")`nAdd the tables to the $reportName report in src/power-bi/reports.json."
    }

    # Track allowlist entries that match nothing. These are only reported once every report type
    # has been built, because most entries only exist in one of the two models by design.
    $modelNames = ConvertTo-NameSet (@($db.Model.Tables | ForEach-Object { $_.Name }) + @($db.Model.Expressions | ForEach-Object { $_.Name }))
    foreach ($entry in @($keepTables + $keepExpressions))
    {
        $null = $allowlistEntries.Add("$reportName|$entry")
        if ($modelNames.Contains($entry)) { $null = $allowlistMatches.Add("$reportName|$entry") }
    }

    # Rebuild the query pane order from what survived
    $queryOrder = $db.Model.Annotations | Where-Object { $_.Name -eq 'PBI_QueryOrder' } | Select-Object -First 1
    if ($queryOrder)
    {
        $surviving = @($db.Model.Expressions | ForEach-Object { $_.Name }) + @($db.Model.Tables | ForEach-Object { $_.Name })
        $survivingSet = ConvertTo-NameSet $surviving

        $previous = @()
        try { $previous = @($queryOrder.Value | ConvertFrom-Json) } catch { Write-Verbose "  Could not read the existing query order; rebuilding it." }

        $ordered = New-Object System.Collections.Generic.List[string]
        $previous | Where-Object { $survivingSet.Contains($_) } | ForEach-Object { $ordered.Add($_) }
        $surviving | Where-Object { $ordered -notcontains $_ } | ForEach-Object { $ordered.Add($_) }

        $queryOrder.Value = $ordered | ConvertTo-Json -Depth 1 -Compress -AsArray
    }

    #region PBIP project

    # Only report types that ship as demo PBIX files need a project to save from
    if ($isDemo -and -not $NoPbip)
    {
        # The demo project keeps the demo data source, so check it before template changes
        Assert-NoMissingDependency $db $removedNames "The $baseName demo project" $reportName

        foreach ($exp in @($db.Model.Expressions | Where-Object { $demoConnection.ContainsKey($_.Name) }))
        {
            $value = $demoConnection[$exp.Name]
            if (-not $value) { throw "reports.json doesn't set a demo data source for '$($exp.Name)', which the $baseName demo project needs." }

            if ($exp.Expression -notmatch '^"[^"]*"') { throw "Could not set '$($exp.Name)' in the $baseName demo project. Its value isn't a text literal: $($exp.Expression)" }
            Write-Verbose "  Demo $($exp.Name): $value"
            $exp.Expression = $exp.Expression -replace '^"[^"]*"', ('"' + $value.Replace('"', '""') + '"')
        }

        # The source filter keys off a hardcoded list of storage account names, which silently
        # stops filtering when the demo hub changes. Demo projects get the subscriptions from
        # reports.json instead, so what ships is what's configured.
        $demoFilter = @($db.Model.Expressions | Where-Object { $_.Name -eq 'ftk_DemoFilter' })
        if ($demoFilter.Count -gt 0)
        {
            $subscriptions = @($reportsConfig.demo.subscriptionIds)
            if ($subscriptions.Count -gt 0)
            {
                $list = ($subscriptions | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', '
                $demoFilter[0].Expression = "() => `"| where subscriptionId in ($list)`""
            }
            else
            {
                $demoFilter[0].Expression = '() => ""'
                Write-Warning "$baseName is not filtered to any subscriptions, so every subscription in the demo hub ships in PowerBI-demo.zip. Set demo.subscriptionIds in src/power-bi/reports.json to limit it."
            }
        }

        # Re-serialize the pruned model so the PBIP matches what the PBIT ships
        Remove-Item "$stagedDataset/definition" -Recurse -Force
        [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($db, "$stagedDataset/definition")

        $platformFile = "$stagedDataset/.platform"
        if (Test-Path $platformFile)
        {
            $platform = Get-Content $platformFile -Raw | ConvertFrom-Json
            $platform.metadata.displayName = $baseName
            $platform.config.logicalId = [guid]::NewGuid().ToString()
            $platform | ConvertTo-Json -Depth 10 | Set-Content $platformFile -NoNewline
        }

        # Report
        $stagedReport = "$pbixDir/$baseName.Report"
        Remove-Item $stagedReport -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item $reportDir $stagedReport -Recurse -Force

        [System.IO.File]::WriteAllText("$stagedReport/report.json", (Get-ReportLayout $reportDir $baseName), $script:Utf8NoBom)

        @{
            '$schema'        = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/1.0.0/schema.json'
            version          = '4.0'
            datasetReference = @{ byPath = @{ path = "../$baseName.Dataset" } }
        } | ConvertTo-Json -Depth 10 | Set-Content "$stagedReport/definition.pbir" -NoNewline

        $reportPlatformFile = "$stagedReport/.platform"
        if (Test-Path $reportPlatformFile)
        {
            $reportPlatform = Get-Content $reportPlatformFile -Raw | ConvertFrom-Json
            $reportPlatform.metadata.displayName = $baseName
            $reportPlatform.config.logicalId = [guid]::NewGuid().ToString()
            $reportPlatform | ConvertTo-Json -Depth 10 | Set-Content $reportPlatformFile -NoNewline
        }

        # Project file
        @{
            '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json'
            version   = '1.0'
            artifacts = @(@{ report = @{ path = "$baseName.Report" } })
            settings  = @{ enableAutoRecovery = $true }
        } | ConvertTo-Json -Depth 10 | Set-Content "$pbixDir/$baseName.pbip" -NoNewline
    }

    #endregion PBIP project

    #region PBIT template

    $targetFile = "$pbitDir/$baseName"
    Remove-Item $targetFile -Recurse -Force -ErrorAction SilentlyContinue
    & "$PSScriptRoot/New-Directory.ps1" $targetFile
    & "$PSScriptRoot/New-Directory.ps1" "$targetFile/Report"

    # Templates ship without a data source so customers supply their own. The PBIP was already
    # written with the demo values so demo PBIX files can still refresh.
    foreach ($exp in @($db.Model.Expressions))
    {
        if ($exp.Name.EndsWith(' URL'))
        {
            $exp.Expression = $exp.Expression -replace '^"[^"]*" meta ', 'null meta '
        }
        if ($exp.Name -eq 'ftk_DemoFilter')
        {
            $exp.Expression = '() => "" // To filter out subscriptions, replace with: "| where subscriptionId in (''<sub1>'', ''<sub2>'')"'
        }
    }
    Assert-NoMissingDependency $db $removedNames "The $baseName template" $reportName

    # DataModelSchema
    $modelJson = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($db) | ConvertFrom-Json -Depth 100 -AsHashtable
    $modelJson.name = [guid]::NewGuid()

    Write-UTF16LE -File "$targetFile/DataModelSchema" -Content ($modelJson | ConvertTo-Json -Depth 100)

    # DiagramLayout (from the pruned model so it doesn't reference tables that were removed)
    Write-UTF16LE -File "$targetFile/DiagramLayout" -Json (Get-Content "$stagedDataset/diagramLayout.json" -Raw | ConvertFrom-Json -Depth 100)

    # Report/Layout
    Write-UTF16LE -File "$targetFile/Report/Layout" -Json ((Get-ReportLayout $reportDir $baseName) | ConvertFrom-Json -Depth 100)

    # Report/StaticResources
    Copy-Item "$reportDir/StaticResources" "$targetFile/Report/StaticResources" -Recurse -Force

    # Metadata
    $desktopVersion = $modelJson.model.annotations | Where-Object { $_.name -eq 'PBIDesktopVersion' } | ForEach-Object { $_.value }
    Write-Verbose "  Desktop version: '$desktopVersion'"
    Write-UTF16LE -File "$targetFile/Metadata" -Json @{
        Version                  = 5
        AutoCreatedRelationships = @()
        FileDescription          = "$($metadata.Intro)`n`nTo customize queries or data source settings, select the Edit option in the Load button.`n`nLearn more at https://aka.ms/ftk/pbi/$reportName"
        CreatedFrom              = "Cloud"
        CreatedFromRelease       = "20$($desktopVersion -replace '^[^\(]+\(([0-9]{2}\.[0-2][0-9])\)[^\)]+$', '$1')"
    }

    # Settings
    $editorSettings = Get-Content "$datasetDir/.pbi/editorSettings.json" | ConvertFrom-Json
    Write-UTF16LE -File "$targetFile/Settings" -Json @{
        Version         = 4
        ReportSettings  = @{
            UserConsentsToCompositeModels            = $true
            ShouldNotifyUserOfNameConflictResolution = $false
        }
        QueriesSettings = @{
            TypeDetectionEnabled      = $editorSettings.typeDetectionEnabled
            RelationshipImportEnabled = $editorSettings.relationshipImportEnabled
            Version                   = $desktopVersion.Split(' ')[0]
        }
    }

    # Version
    Write-UTF16LE -File "$targetFile/Version" -Content "1.30"

    # [Content_Types].xml
    @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
        '<Default Extension="svg" ContentType="" />',
        '<Default Extension="png" ContentType="" />',
        '<Default Extension="json" ContentType="" />',
        '<Override PartName="/Version" ContentType="" />',
        '<Override PartName="/DataModelSchema" ContentType="" />',
        '<Override PartName="/DiagramLayout" ContentType="" />',
        '<Override PartName="/Report/Layout" ContentType="" />',
        '<Override PartName="/Settings" ContentType="application/json" />',
        '<Override PartName="/Metadata" ContentType="application/json" />',
        '</Types>'
    ) -join , '' `
    | Out-File -LiteralPath "$targetFile/[Content_Types].xml" -Encoding utf8

    # Create PBIT file
    Compress-Archive -Path "$targetFile/*" -DestinationPath "$targetFile.pbit" -Force
    Remove-Item $targetFile -Recurse -Force

    #endregion PBIT template

    $manifest.Add([PSCustomObject]@{
            name        = $reportName
            type        = $reportType
            base        = $baseName
            demo        = $isDemo
            pbip        = if ($isDemo -and -not $NoPbip) { "$baseName.pbip" } else { $null }
            pbix        = if ($isDemo) { "$baseName.pbix" } else { $null }
            pbit        = "$baseName.pbit"
            tables      = @($db.Model.Tables | ForEach-Object { $_.Name } | Sort-Object)
            expressions = @($db.Model.Expressions | ForEach-Object { $_.Name } | Sort-Object)
        })

    # The staged model is only kept when it's part of a demo project
    if (-not $isDemo -or $NoPbip)
    {
        Remove-Item $stagedDataset -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#endregion Build

#region Package

$genAllReports = $Name -eq '*'
if ($KQL -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.kql.pbit" -DestinationPath "$relDir/PowerBI-kql.zip" -Force }
if ($Storage -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.storage.pbit" -DestinationPath "$relDir/PowerBI-storage.zip" -Force }

# Package-PowerBI reads the manifest to know what was built and what needs to be saved. Partial
# builds don't write one, so a single-report build never looks like a complete release.
$demoProjects = @($manifest | Where-Object { $_.pbip })
if (-not $NoPbip -and $genAllReports -and $KQL -and $Storage)
{
    & "$PSScriptRoot/New-Directory.ps1" $pbixDir
    @{
        version = $version
        built   = (Get-Date -Format 'o')
        reports = $manifest.ToArray()
    } | ConvertTo-Json -Depth 10 | Set-Content "$pbixDir/.manifest.json"
}

# Allowlist entries that matched nothing in any model built are stale or misspelled
if ($KQL -and $Storage -and $Name -eq '*')
{
    $allowlistEntries `
    | Where-Object { -not $allowlistMatches.Contains($_) } `
    | Sort-Object `
    | ForEach-Object {
        $parts = $_.Split('|')
        Write-Warning "$($parts[0]) lists '$($parts[1])' but no model has a table or query with that name."
    }
}

Write-Host "✅ $($reports.Count) PBIT template$(if ($reports.Count -ne 1) { 's' })"
if ($genAllReports)
{
    if ($KQL) { Write-Host "✅ PowerBI-kql.zip" }
    if ($Storage) { Write-Host "✅ PowerBI-storage.zip" }
}
if ($demoProjects.Count -gt 0) { Write-Host "✅ $($demoProjects.Count) demo PBIP project$(if ($demoProjects.Count -ne 1) { 's' }) in release/pbix" }

#endregion Package
