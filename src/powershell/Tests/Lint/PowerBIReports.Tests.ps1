# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Lint rule: Power BI reports and src/power-bi/reports.json must agree.

    Build-PowerBI removes every table and query that reports.json doesn't list for a report. When a
    visual reads from a table that isn't listed, the template and demo report ship with a broken
    visual (for example, the Governance report's "Virtual machines" page lost its disks table this
    way). Build-PowerBI fails on this too, but it only runs at release time. This test catches it
    in the pull request that causes it.

    Uses the same helpers as Build-PowerBI and only reads files, so it doesn't need the Analysis
    Services library.
#>

BeforeDiscovery {
    $powerBiDir = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName 'power-bi'
    $reportProjects = @(Get-ChildItem $powerBiDir -Recurse -Include '*.kql.pbip', '*.storage.pbip' | ForEach-Object {
            @{ Name = $_.Name.Split('.')[0]; Type = $_.Name.Split('.')[1]; Folder = $_.DirectoryName; Label = $_.BaseName }
        })
}

BeforeAll {
    $srcDir = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName
    $powerBiDir = Join-Path $srcDir 'power-bi'

    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $srcDir 'scripts/Build-PowerBI.ps1'), [ref]$null, [ref]$null)
    $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) `
    | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

    $config = (Get-Content (Join-Path $powerBiDir 'reports.json') -Raw | ConvertFrom-Json -Depth 10).reports
    $modelNames = @{}
    foreach ($type in 'kql', 'storage')
    {
        $modelNames[$type] = ConvertTo-NameSet (Get-TmdlObjectName (Join-Path $powerBiDir "$type/Shared.Dataset/definition"))
    }
}

Describe 'PowerBIReports' {
    Context '<Label>' -ForEach $reportProjects {
        BeforeAll {
            $settings = $config.$Name
            if ($settings)
            {
                $keptTables = Resolve-Allowlist @($settings.tables) $Type
                $keptQueries = Resolve-Allowlist @($settings.queries) $Type
                $kept = ConvertTo-NameSet ($keptTables + $keptQueries)
            }
        }

        It 'Is listed in reports.json' {
            $settings | Should -Not -BeNullOrEmpty -Because "Build-PowerBI needs to know which tables and queries the $Name report keeps"
            $settings.description | Should -Not -BeNullOrEmpty
        }

        It 'Only has visuals that read from tables reports.json keeps' {
            $references = Get-ReportEntityReference (Get-Content (Join-Path $Folder "$Name.Report/report.json") -Raw)
            $broken = @($references `
                | Where-Object { -not $_.Hidden -and $modelNames[$Type].Contains($_.Entity) -and -not $kept.Contains($_.Entity) } `
                | ForEach-Object { "'$($_.Page)' page $($_.Source) reads from '$($_.Entity)'" } `
                | Sort-Object -Unique)
            $broken | Should -BeNullOrEmpty -Because "reports.json removes these tables from the $Label report. Add them to the $Name tables"
        }
    }

    It 'Only lists tables and queries that exist' {
        $unknown = foreach ($report in $config.PSObject.Properties)
        {
            foreach ($entry in @($report.Value.tables) + @($report.Value.queries))
            {
                $prefixed = [regex]::Match($entry, '^\[(?<type>[^\]]+)\](?<name>.+)$')
                $types = if ($prefixed.Success) { @($prefixed.Groups['type'].Value) } else { @('kql', 'storage') }
                $name = if ($prefixed.Success) { $prefixed.Groups['name'].Value } else { $entry }
                if (-not @($types | Where-Object { $modelNames[$_] -and $modelNames[$_].Contains($name) }).Count)
                {
                    "$($report.Name): $entry"
                }
            }
        }
        $unknown | Should -BeNullOrEmpty -Because 'entries that match nothing are misspelled or stale'
    }
}
