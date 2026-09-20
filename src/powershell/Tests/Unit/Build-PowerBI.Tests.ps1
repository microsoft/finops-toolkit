# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Tests the Power BI build helpers in src/scripts/Build-PowerBI.ps1 and the demo report
    validation in src/scripts/Package-PowerBI.ps1.

    Both scripts run top-level build logic, so dot-sourcing them would start a build. Function
    definitions are extracted with the PowerShell parser and defined in the test scope instead.
    None of these tests need the Analysis Services library or Power BI Desktop.
#>

BeforeAll {
    $scriptsDir = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName 'scripts'

    function Import-ScriptFunction([string] $ScriptName)
    {
        $path = Join-Path $scriptsDir $ScriptName
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
        $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) `
        | ForEach-Object { $_.Extent.Text }
    }

    Import-ScriptFunction 'Build-PowerBI.ps1' | ForEach-Object { . ([scriptblock]::Create($_)) }
    Import-ScriptFunction 'Package-PowerBI.ps1' | ForEach-Object { . ([scriptblock]::Create($_)) }
    $script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    function New-TmdlModel([string] $Root, [hashtable] $Tables, [string[]] $Relationships = @(), [string[]] $Expressions = @())
    {
        New-Item "$Root/definition/tables" -ItemType Directory -Force | Out-Null
        $modelLines = @('model Model', '	culture: en-US', '')
        foreach ($name in $Tables.Keys)
        {
            $declared = if ($name -match '^[A-Za-z_][A-Za-z0-9_]*$') { $name } else { "'$($name.Replace("'", "''"))'" }
            $lines = @("table $declared") + ($Tables[$name] | ForEach-Object { "`tcolumn $_" })
            Set-Content "$Root/definition/tables/$name.tmdl" ($lines -join "`n")
            $modelLines += "ref table $declared"
        }
        Set-Content "$Root/definition/model.tmdl" ($modelLines -join "`n")
        Set-Content "$Root/definition/relationships.tmdl" ($Relationships -join "`n")
        Set-Content "$Root/definition/expressions.tmdl" ($Expressions -join "`n")

        $nodes = @($Tables.Keys | ForEach-Object { @{ nodeIndex = $_ } })
        @{ version = '1.1.0'; diagrams = @(@{ name = 'All tables'; nodes = $nodes }) } | ConvertTo-Json -Depth 10 | Set-Content "$Root/diagramLayout.json"
    }

    function New-TestPbix([string] $Path, [hashtable] $Parts)
    {
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
        try
        {
            foreach ($name in $Parts.Keys)
            {
                $entry = $zip.CreateEntry($name)
                $stream = $entry.Open()
                $bytes = $Parts[$name]
                if ($bytes -is [string]) { $bytes = [System.Text.Encoding]::Unicode.GetBytes($bytes) }
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Dispose()
            }
        }
        finally { $zip.Dispose() }
    }

    function New-Layout([int] $ActiveSectionIndex = 0, [string] $Text = 'FinOps toolkit v1.2.3')
    {
        return @{
            config   = (@{ activeSectionIndex = $ActiveSectionIndex } | ConvertTo-Json -Compress)
            sections = @(
                @{ displayName = 'Get started'; ordinal = 0; visualContainers = @(@{ config = (@{ text = $Text } | ConvertTo-Json -Compress) }) }
                @{ displayName = 'Summary'; ordinal = 1 }
            )
        } | ConvertTo-Json -Depth 10 -Compress
    }
}

Describe 'Resolve-Allowlist' {
    It 'Keeps shared entries and entries for the report type' {
        $result = Resolve-Allowlist @('Costs', '[storage]Storage URL', '[kql]Cluster URL') 'storage'
        $result | Should -Be @('Costs', 'Storage URL')
    }

    It 'Returns an empty array when nothing applies' {
        $result = Resolve-Allowlist @('[kql]Cluster URL') 'storage'
        $result.Count | Should -Be 0
    }
}

Describe 'ConvertFrom-TmdlDeclaration' {
    It 'Reads <Expected> from <Text>' -ForEach @(
        @{ Text = 'Costs'; Expected = 'Costs' }
        @{ Text = "'Compliance calculation'"; Expected = 'Compliance calculation' }
        @{ Text = "'It''s quoted' = 1"; Expected = "It's quoted" }
        @{ Text = 'ftk_Storage = () => 1'; Expected = 'ftk_Storage' }
    ) {
        ConvertFrom-TmdlDeclaration $Text | Should -Be $Expected
    }
}

Describe 'Get-TmdlReferenceTable' {
    It 'Reads <Expected> from <Reference>' -ForEach @(
        @{ Reference = 'Costs.x_ResourceId'; Expected = 'Costs' }
        @{ Reference = "'Compliance calculation'.Id"; Expected = 'Compliance calculation' }
        @{ Reference = "NetworkInterfaces.'properties.virtualMachine.id'"; Expected = 'NetworkInterfaces' }
    ) {
        Get-TmdlReferenceTable $Reference | Should -Be $Expected
    }
}

Describe 'Get-TmdlNameConflict' {
    It 'Reports columns that only differ by case with line numbers' {
        New-TmdlModel "$TestDrive/conflict" @{ Recommendations = @('region', 'name', 'Region') }
        $conflicts = Get-TmdlNameConflict "$TestDrive/conflict/definition"
        $conflicts | Should -HaveCount 1
        $conflicts[0].Table | Should -Be 'Recommendations'
        $conflicts[0].Message | Should -Match 'region, Region'
        $conflicts[0].Message | Should -Match 'lines 2, 4'
    }

    It 'Returns nothing for a valid model' {
        New-TmdlModel "$TestDrive/valid" @{ Costs = @('BilledCost', 'EffectiveCost') }
        $result = Get-TmdlNameConflict "$TestDrive/valid/definition"
        $result.Count | Should -Be 0
    }

    It 'Finds no conflicts in the shipped models' -ForEach @('storage', 'kql') {
        $root = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName "power-bi/$_/Shared.Dataset/definition"
        $result = Get-TmdlNameConflict $root
        $result.Count | Should -Be 0
    }
}

Describe 'Export-PrunedDataset' {
    BeforeAll {
        New-TmdlModel "$TestDrive/source" `
            -Tables @{ Costs = @('SubAccountId'); Subscriptions = @('subscriptionId'); 'Compliance calculation' = @('Id') } `
            -Relationships @(
            'relationship r1', "`tfromColumn: Costs.SubAccountId", "`ttoColumn: Subscriptions.subscriptionId", ''
            'relationship r2', "`tfromColumn: 'Compliance calculation'.Id", "`ttoColumn: Costs.SubAccountId", ''
        )
        $result = Export-PrunedDataset "$TestDrive/source" "$TestDrive/pruned" @('Costs', 'Compliance calculation')
    }

    It 'Removes tables that are not kept' {
        $result.Dropped | Should -Be @('Subscriptions')
        Test-Path "$TestDrive/pruned/definition/tables/Subscriptions.tmdl" | Should -BeFalse
        Test-Path "$TestDrive/pruned/definition/tables/Costs.tmdl" | Should -BeTrue
    }

    It 'Removes model references to removed tables' {
        $model = Get-Content "$TestDrive/pruned/definition/model.tmdl" -Raw
        $model | Should -Not -Match 'ref table Subscriptions'
        $model | Should -Match "ref table 'Compliance calculation'"
    }

    It 'Removes relationships to removed tables and keeps the rest' {
        $result.RemovedRelationships | Should -Be 1
        $relationships = Get-Content "$TestDrive/pruned/definition/relationships.tmdl" -Raw
        $relationships | Should -Not -Match 'relationship r1'
        $relationships | Should -Match 'relationship r2'
    }

    It 'Removes diagram nodes for removed tables' {
        $diagram = Get-Content "$TestDrive/pruned/diagramLayout.json" -Raw | ConvertFrom-Json
        $diagram.diagrams[0].nodes.nodeIndex | Sort-Object | Should -Be @('Compliance calculation', 'Costs')
    }

    It 'Leaves the source untouched' {
        Test-Path "$TestDrive/source/definition/tables/Subscriptions.tmdl" | Should -BeTrue
    }
}

Describe 'Get-ReportEntityReference' {
    BeforeAll {
        $visual = @{
            name          = 'v1'
            singleVisual  = @{ visualType = 'tableEx' }
            prototypeQuery = @{ From = @(@{ Name = 'c'; Entity = 'Costs' }, @{ Name = 'd'; Entity = 'VirtualMachinesDisks' }) }
            # Formatting selectors aren't queries and must be ignored
            objects       = @{ dataPoint = @(@{ selector = @{ data = @(@{ scopeId = @{ Column = @{ Expression = @{ SourceRef = @{ Entity = 'UsageDetails' } } } } }) } }) }
        }
        $report = @{
            filters  = (@(@{ filter = @{ From = @(@{ Name = 'x'; Entity = 'CostDetails' }) } }) | ConvertTo-Json -Depth 10 -Compress)
            sections = @(
                @{ displayName = 'Virtual machines'; config = '{}'; visualContainers = @(@{ config = ($visual | ConvertTo-Json -Depth 20 -Compress) }) }
                @{ displayName = 'Hidden'; config = '{"visibility":1}'; filters = '[{"filter":{"From":[{"Name":"a","Entity":"Advisor"}]}}]' }
            )
        } | ConvertTo-Json -Depth 10
        $references = Get-ReportEntityReference $report
    }

    It 'Finds entities read by visuals, page filters, and report filters' {
        $references.Entity | Sort-Object -Unique | Should -Be @('Advisor', 'CostDetails', 'Costs', 'VirtualMachinesDisks')
    }

    It 'Ignores entity references outside of queries' {
        $references.Entity | Should -Not -Contain 'UsageDetails'
    }

    It 'Records the page, visual, and hidden state' {
        $disk = $references | Where-Object Entity -EQ 'VirtualMachinesDisks'
        $disk.Page | Should -Be 'Virtual machines'
        $disk.Source | Should -Be 'tableEx visual v1'
        $disk.Hidden | Should -BeFalse
        ($references | Where-Object Entity -EQ 'Advisor').Hidden | Should -BeTrue
    }
}

Describe 'Remove-ExpressionLiteral' {
    It 'Removes M strings and comments but keeps quoted identifiers' {
        $text = Remove-ExpressionLiteral "let a = #`"Storage URL`", b = `"Resources`" // Subscriptions`nin a /* Regions */" 'M'
        $text | Should -Match '#"Storage URL"'
        $text | Should -Not -Match 'Resources|Subscriptions|Regions'
    }

    It 'Removes DAX strings and comments but keeps quoted table names' {
        $text = Remove-ExpressionLiteral "CALCULATE(SUM('Compliance calculation'[Id]), `"Resources`") -- Disks" 'DAX'
        $text | Should -Match "'Compliance calculation'"
        $text | Should -Not -Match 'Resources|Disks'
    }
}

Describe 'Get-MissingDependency' {
    BeforeAll {
        function New-Model([object[]] $Expressions = @(), [object[]] $Tables = @())
        {
            return [PSCustomObject]@{ Model = [PSCustomObject]@{ Expressions = $Expressions; Tables = $Tables } }
        }
        function New-Table([string] $Name, [string] $Source, [object[]] $Measures = @(), [string] $SourceType = 'M')
        {
            return [PSCustomObject]@{
                Name          = $Name
                Partitions    = @([PSCustomObject]@{ SourceType = $SourceType; Source = [PSCustomObject]@{ Expression = $Source } })
                Measures      = $Measures
                Columns       = @()
                RefreshPolicy = $null
            }
        }
    }

    It 'Finds a removed query used by a table' {
        $db = New-Model -Tables @(New-Table 'Resources' 'let Source = ftk_QueryARG("resources") in Source')
        $missing = Get-MissingDependency $db @('ftk_QueryARG')
        $missing | Should -HaveCount 1
        $missing[0].Owner | Should -Be "table 'Resources'"
    }

    It 'Finds a removed parameter referenced with a quoted identifier' {
        $db = New-Model -Expressions @([PSCustomObject]@{ Name = 'ftk_DemoFilter'; Expression = '() => Text.SplitAny(#"Storage URL", "/.")' })
        (Get-MissingDependency $db @('Storage URL')).Owner | Should -Be "query 'ftk_DemoFilter'"
    }

    It 'Finds a removed table used by a measure' {
        $measure = [PSCustomObject]@{ Name = 'Disk count'; Expression = "COUNTROWS(VirtualMachinesDisks) + COUNTROWS('Compliance calculation')" }
        $db = New-Model -Tables @(New-Table 'Costs' 'Source' -Measures @($measure))
        (Get-MissingDependency $db @('VirtualMachinesDisks', 'Compliance calculation')).Name | Should -Be @('VirtualMachinesDisks', 'Compliance calculation')
    }

    It 'Ignores names in strings, comments, record fields, and shadowing variables' {
        $source = @'
let
    // Resources are joined later
    Label = "Subscriptions",
    Regions = Table.FromRecords({}),
    Renamed = Table.SelectColumns(Regions, {"x"}),
    Field = [Disks]
in
    Renamed
'@
        $db = New-Model -Tables @(New-Table 'Costs' $source)
        $result = Get-MissingDependency $db @('Resources', 'Subscriptions', 'Regions', 'Disks')
        $result.Count | Should -Be 0
    }

    It 'Ignores measure and column references' {
        $measure = [PSCustomObject]@{ Name = 'Total'; Expression = 'SUM(Costs[Resources]) + [Disks]' }
        $db = New-Model -Tables @(New-Table 'Costs' 'Source' -Measures @($measure))
        $result = Get-MissingDependency $db @('Resources', 'Disks')
        $result.Count | Should -Be 0
    }
}

Describe 'Test-DemoPbix' {
    BeforeAll {
        $version = '1.2.3'
        $report = [PSCustomObject]@{ tables = @('Costs', 'Prices') }
        $bigModel = New-Object byte[] (1MB + 1)
        $diagram = @{ diagrams = @(@{ nodes = @(@{ nodeIndex = 'Costs' }, @{ nodeIndex = 'Prices' }) }) } | ConvertTo-Json -Depth 5 -Compress

        function New-ValidParts
        {
            return @{
                'DataModel'     = $bigModel
                'Report/Layout' = (New-Layout)
                'Metadata'      = '{}'
                'Settings'      = '{}'
                'Version'       = '1.30'
                'DiagramLayout' = $diagram
            }
        }
    }

    It 'Passes a correctly saved demo report' {
        New-TestPbix "$TestDrive/valid.pbix" (New-ValidParts)
        $result = Test-DemoPbix "$TestDrive/valid.pbix" $report
        $result.Count | Should -Be 0
    }

    It 'Fails a file that is not a PBIX' {
        Set-Content "$TestDrive/bad.pbix" 'not a zip'
        Test-DemoPbix "$TestDrive/bad.pbix" $report | Should -Match "isn't a readable PBIX"
    }

    It 'Fails a report saved without data' {
        $parts = New-ValidParts
        $parts.DataModel = New-Object byte[] 1024
        New-TestPbix "$TestDrive/empty.pbix" $parts
        Test-DemoPbix "$TestDrive/empty.pbix" $report | Should -Match 'saved without loading demo data'
    }

    It 'Fails a report saved on the wrong page' {
        $parts = New-ValidParts
        $parts.'Report/Layout' = New-Layout -ActiveSectionIndex 1
        New-TestPbix "$TestDrive/page.pbix" $parts
        Test-DemoPbix "$TestDrive/page.pbix" $report | Should -Match "opens on 'Summary'"
    }

    It 'Fails a report saved from the source project' {
        $parts = New-ValidParts
        $parts.'Report/Layout' = New-Layout -Text 'FinOps toolkit v$$ftkver$$'
        New-TestPbix "$TestDrive/source.pbix" $parts
        Test-DemoPbix "$TestDrive/source.pbix" $report | Should -Match 'still has version placeholders'
    }

    It 'Fails a report saved from an older version' {
        $parts = New-ValidParts
        $parts.'Report/Layout' = New-Layout -Text 'FinOps toolkit v1.2.2'
        New-TestPbix "$TestDrive/old.pbix" $parts
        Test-DemoPbix "$TestDrive/old.pbix" $report | Should -Match "doesn't mention version 1.2.3"
    }

    It 'Fails a report with tables it does not use' {
        $parts = New-ValidParts
        $parts.DiagramLayout = @{ diagrams = @(@{ nodes = @(@{ nodeIndex = 'Costs' }, @{ nodeIndex = 'Resources' }) }) } | ConvertTo-Json -Depth 5 -Compress
        New-TestPbix "$TestDrive/extra.pbix" $parts
        Test-DemoPbix "$TestDrive/extra.pbix" $report | Should -Match "1 table the report doesn't use \(Resources\)"
    }

    It 'Fails a report saved before the latest build' {
        New-TestPbix "$TestDrive/stale.pbix" (New-ValidParts)
        (Get-Item "$TestDrive/stale.pbix").LastWriteTime = (Get-Date).AddHours(-2)
        Test-DemoPbix "$TestDrive/stale.pbix" $report (Get-Date).AddHours(-1) | Should -Match 'was saved before the latest build'
    }

    It 'Fails a report with the wrong sensitivity label' {
        $parts = New-ValidParts
        $parts.'docProps/custom.xml' = [System.Text.Encoding]::UTF8.GetBytes('<Properties><property name="MSIP_Label_abc_Name"><vt:lpwstr>Confidential</vt:lpwstr></property></Properties>')
        New-TestPbix "$TestDrive/label.pbix" $parts
        Test-DemoPbix "$TestDrive/label.pbix" $report -Label 'Public' | Should -Match "has the 'Confidential' sensitivity label"
    }

    It 'Passes a report with the expected sensitivity label' {
        $parts = New-ValidParts
        $parts.'docProps/custom.xml' = [System.Text.Encoding]::UTF8.GetBytes('<Properties><property name="MSIP_Label_abc_Name"><vt:lpwstr>Public</vt:lpwstr></property></Properties>')
        New-TestPbix "$TestDrive/public.pbix" $parts
        $result = Test-DemoPbix "$TestDrive/public.pbix" $report -Label 'Public'
        $result.Count | Should -Be 0
    }
}
