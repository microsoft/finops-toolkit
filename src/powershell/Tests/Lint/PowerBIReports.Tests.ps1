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

Describe 'Demo data source' {
    It 'Lists the <_> model Storage URL account in the ftk_DemoFilter allowlist' -ForEach @('storage', 'kql') {
        $path = Join-Path $PSScriptRoot "../../../power-bi/$_/Shared.Dataset/definition/expressions.tmdl"
        $text = Get-Content $path -Raw

        # -match, not Should -Match: Should runs in Pester's scope, so $Matches would not be set here
        $hasUrl = $text -match "expression 'Storage URL' = ""https://(?<account>[a-z0-9]+)\.dfs\.core\.windows\.net"
        $hasUrl | Should -BeTrue -Because 'the model should have a Storage URL on the DFS endpoint'
        $account = $Matches['account']

        # Quoted on its own, the account only appears in the allowlist. Without it the demo reports
        # query every subscription the viewer can read.
        $inList = $text -match ('"' + [regex]::Escape($account) + '"')
        $inList | Should -BeTrue -Because "$account should be in the ftk_DemoFilter storage account list"
    }
}

Describe 'Storage incremental refresh' {
    BeforeAll {
        $tablesDir = Join-Path $PSScriptRoot '../../../power-bi/storage/Shared.Dataset/definition/tables'
    }

    It 'Ends the Costs query with a RangeStart/RangeEnd row filter' {
        # Power BI only offers incremental refresh when the table's own query filters rows with RangeStart and RangeEnd
        $text = Get-Content (Join-Path $tablesDir 'Costs.tmdl') -Raw
        $isLastStep = $text -match '(?s)Output\s*=\s*Table\.SelectRows\((?<filter>(?:(?!Table\.SelectRows).)*?)\)\s*in\s+Output\s*\r?\n\s*```'
        $isLastStep | Should -BeTrue -Because 'the final step of the Costs query must be Table.SelectRows so Power BI detects the filter'
        $filter = $Matches['filter']
        $filter | Should -Match '\bRangeStart\b'
        $filter | Should -Match '\bRangeEnd\b'
        $filter | Should -Match 'x_IncrementalRefreshDate'
    }

    It 'Types x_IncrementalRefreshDate as dateTime in <_>' -ForEach @('Costs', 'Prices', 'ReservationDetails', 'ReservationRecommendations', 'ReservationTransactions') {
        $text = Get-Content (Join-Path $tablesDir "$_.tmdl") -Raw
        $isDateTime = $text -match '(?m)^\tcolumn x_IncrementalRefreshDate\r?\n\t\tdataType: dateTime\b'
        $isDateTime | Should -BeTrue -Because 'incremental refresh needs a Date/Time column to compare with RangeStart and RangeEnd'
    }
}