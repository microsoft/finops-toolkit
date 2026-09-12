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

if (-not $KQL -and -not $Storage) { $KQL = $Storage = $true }

#region Report metadata

# Tables and queries to keep in each report. Prefix a name with [kql] or [storage] to keep it
# for that report type only. Everything not listed here is removed from the PBIT and the PBIP.
$reportMetadata = @{
    CostSummary          = @{
        Intro       = "The Cost summary report provides several summaries of your effective (amortized) and billed costs based on the FinOps Open Cost and Usage Specification (FOCUS). Amortization breaks down reservation and savings plan purchases and allocates costs to the resources that received the benefit. Effective costs will not match your invoice."
        Tables      = @("Costs", "Prices", "PricingUnits")
        Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
    }
    Invoicing            = @{
        Intro       = "The Invoicing and chargeback report provides several summaries of your billed cost to facilitate invoice reconciliation for Microsoft Customer Agreement (MCA) and Enterprise Agreement (EA) accounts or to perform chargeback using effective (amortized) costs."
        Tables      = @("Costs", "Prices", "PricingUnits")
        Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
    }
    DataIngestion        = @{
        Intro       = "The Data ingestion report provides details about the data you've ingested into your FinOps hub storage account."
        Tables      = @("Costs", "HubScopes", "HubSettings", "Prices", "PricingUnits", "StorageData", "StorageErrors")
        Expressions = @("▶️  START HERE", "Cluster URL", "Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
    }
    Governance           = @{
        Intro       = "The Governance, policy, and risk report summarizes your Microsoft Cloud governance posture. It offers the standard metrics aligned with the Cloud Adoption Framework to facilitate identifying issues, applying recommendations, and resolving compliance gaps."
        Tables      = @("AdvisorRecommendations", "Compliance calculation", "Costs", "Disks", "ManagementGroups", "NetworkInterfaces", "NetworkSecurityGroups", "PolicyAssignments", "PolicyStates", "Prices", "PricingUnits", "PublicIPAddresses", "Regions", "Resources", "ResourceTypes", "SqlDatabases", "Subscriptions", "VirtualMachines")
        Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "PolicyDefinitions", "Remove Duplicate Resource IDs", "Deprecated: Perform Extra Query Optimizations", "ftk_ARGBatchSize", "ftk_DemoFilter", "ftk_QueryARG", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
    }
    RateOptimization     = @{
        Intro       = "The Rate optimization report provides insights into any rate optimization opportunities, like reservations, savings plans, and Azure Hybrid Benefit. This report uses effective cost, which amortizes and breaks reservation and savings plan purchases down and allocates costs out to the resources that received the benefit. Effective cost will not match your invoice."
        Tables      = @("Costs", "InstanceSizeFlexibility", "Prices", "PricingUnits", "ReservationRecommendations")
        Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Deprecated: Perform Extra Query Optimizations", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
    }
    WorkloadOptimization = @{
        Intro       = "The Usage optimization report provides insights into resource utilization and efficiency opportunities based on historical usage patterns. Use this report to determine if resources can be scaled down or even shut down during off-peak hours to minimize wasteful usage and spending. Also consider cheaper alternatives when available and ensure all workloads have some direct or indirect link to business value to avoid unnecessary usage and costs that don't contribute to the mission."
        Tables      = @("AdvisorRecommendations", "Costs", "Disks", "Prices", "PricingUnits", "Resources", "Subscriptions")
        Expressions = @("▶️  START HERE", "Cluster URL", "[storage]Storage URL", "Default Granularity", "Number of Months", "RangeStart", "RangeEnd", "Experimental: Add Missing Prices", "Remove Duplicate Resource IDs", "Deprecated: Perform Extra Query Optimizations", "ftk_ARGBatchSize", "ftk_DemoFilter", "ftk_QueryARG", "ftk_DatetimeToJulianDate", "ftk_ImpalaToJulianDate", "ftk_Metadata", "ftk_ParseResourceId", "ftk_ParseResourceName", "ftk_ParseResourceType", "ftk_Storage")
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
    $value = $Text.Trim()
    if ($value.StartsWith("'"))
    {
        for ($i = 1; $i -lt $value.Length; $i++)
        {
            if ($value[$i] -ne "'") { continue }
            if ($i + 1 -lt $value.Length -and $value[$i + 1] -eq "'") { $i++; continue }
            return $value.Substring(1, $i - 1).Replace("''", "'")
        }
        return $null
    }

    $stop = $value.IndexOfAny([char[]]@(' ', "`t", '='))
    if ($stop -lt 0) { return $value }
    return $value.Substring(0, $stop)
}

<#
    .SYNOPSIS
    Reads the table name from a TMDL column reference (for example, "'My Table'.Col" returns "My Table").
#>
function Get-TmdlReferenceTable([string] $Reference)
{
    $value = $Reference.Trim()
    if ($value.StartsWith("'"))
    {
        for ($i = 1; $i -lt $value.Length; $i++)
        {
            if ($value[$i] -ne "'") { continue }
            if ($i + 1 -lt $value.Length -and $value[$i + 1] -eq "'") { $i++; continue }
            return $value.Substring(1, $i - 1).Replace("''", "'")
        }
        return $null
    }

    $dot = $value.IndexOf('.')
    if ($dot -lt 0) { return $value }
    return $value.Substring(0, $dot)
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

    function Add-Conflict($List, $Table, $File, $Names)
    {
        $Names.GetEnumerator() `
        | Where-Object { $_.Value.Count -gt 1 } `
        | ForEach-Object {
            $scope = if ($Table) { "table '$Table'" } else { 'the query list' }
            $conflicting = ($_.Value | ForEach-Object { $_.Name }) -join ', '
            $lines = ($_.Value | ForEach-Object { $_.Line }) -join ', '
            $List.Add([PSCustomObject]@{
                    Table   = $Table
                    File    = $File
                    Message = "$File`: $scope declares names that only differ by case ($conflicting) on lines $lines. Power BI treats names as case-insensitive, so one of them must be renamed or removed."
                })
        }
    }

    Get-ChildItem "$DefinitionDir/tables" -Filter '*.tmdl' -ErrorAction SilentlyContinue `
    | ForEach-Object {
        $file = $_
        $lines = [System.IO.File]::ReadAllLines($file.FullName)
        $tableName = $file.BaseName
        $members = @{}

        for ($i = 0; $i -lt $lines.Count; $i++)
        {
            $line = $lines[$i]
            if ($line -match '^table\s+(?<rest>.+)$')
            {
                $tableName = ConvertFrom-TmdlDeclaration $Matches.rest
            }
            elseif ($line -match '^\t(?<kind>column|measure)\s+(?<rest>.+)$')
            {
                $memberName = ConvertFrom-TmdlDeclaration $Matches.rest
                if (-not $memberName) { continue }
                $key = $memberName.ToLowerInvariant()
                if (-not $members.ContainsKey($key)) { $members[$key] = New-Object System.Collections.Generic.List[object] }
                $members[$key].Add([PSCustomObject]@{ Name = $memberName; Line = $i + 1 })
            }
        }

        Add-Conflict $conflicts $tableName $file.Name $members
    }

    $expressionFile = "$DefinitionDir/expressions.tmdl"
    if (Test-Path $expressionFile)
    {
        $lines = [System.IO.File]::ReadAllLines($expressionFile)
        $expressions = @{}
        for ($i = 0; $i -lt $lines.Count; $i++)
        {
            if ($lines[$i] -notmatch '^expression\s+(?<rest>.+)$') { continue }
            $expressionName = ConvertFrom-TmdlDeclaration $Matches.rest
            if (-not $expressionName) { continue }
            $key = $expressionName.ToLowerInvariant()
            if (-not $expressions.ContainsKey($key)) { $expressions[$key] = New-Object System.Collections.Generic.List[object] }
            $expressions[$key].Add([PSCustomObject]@{ Name = $expressionName; Line = $i + 1 })
        }
        Add-Conflict $conflicts $null 'expressions.tmdl' $expressions
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
    & "$PSScriptRoot/New-Directory.ps1" (Split-Path $TargetDir -Parent)
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
    if (-not $metadata) { throw "No build metadata is defined for the '$reportName' report. Add it to the `$reportMetadata table in Build-PowerBI.ps1." }

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

    if (-not $NoPbip)
    {
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

    # DataModelSchema
    $modelJson = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($db) | ConvertFrom-Json -Depth 100 -AsHashtable
    $modelJson.name = [guid]::NewGuid()

    # Templates ship without a data source so customers supply their own. The PBIP keeps the
    # demo values so demo PBIX files can still refresh.
    $modelJson.model.expressions `
    | ForEach-Object {
        $exp = $_
        if ($exp.name.EndsWith(' URL'))
        {
            $exp.expression = $exp.expression -replace '^"[^"]*" meta ', 'null meta '
        }
        if ($exp.name -eq 'ftk_DemoFilter')
        {
            $exp.expression = '() => "" // To filter out subscriptions, replace with: "| where subscriptionId in (''<sub1>'', ''<sub2>'')"'
        }
    }

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

    if (-not $NoPbip)
    {
        $manifest.Add([PSCustomObject]@{
                name        = $reportName
                type        = $reportType
                base        = $baseName
                pbip        = "$baseName.pbip"
                pbix        = "$baseName.pbix"
                pbit        = "$baseName.pbit"
                tables      = @($db.Model.Tables | ForEach-Object { $_.Name } | Sort-Object)
                expressions = @($db.Model.Expressions | ForEach-Object { $_.Name } | Sort-Object)
            })
    }
    else
    {
        Remove-Item $stagedDataset -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#endregion Build

#region Package

$genAllReports = $Name -eq '*'
if ($KQL -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.kql.pbit" -DestinationPath "$relDir/PowerBI-kql.zip" -Force }
if ($Storage -and $genAllReports) { Compress-Archive -Path "$pbitDir/*.storage.pbit" -DestinationPath "$relDir/PowerBI-storage.zip" -Force }

if (-not $NoPbip -and $manifest.Count -gt 0)
{
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
if (-not $NoPbip) { Write-Host "✅ $($manifest.Count) PBIP project$(if ($manifest.Count -ne 1) { 's' }) in release/pbix" }

#endregion Package
