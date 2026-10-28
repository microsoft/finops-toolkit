# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Validates the built Power BI templates (PBIT) without opening Power BI Desktop.

    A PBIT is a ZIP file. Its DataModelSchema part holds the parameters and Power Query (M)
    queries a person sees when they open the template, so most of what is checked by hand today
    (the parameter prompt, no demo data source, gzip support) can be read from it. This runs on
    any platform.

    The templates are build output (release/pbit, or release/PowerBI-kql.zip and
    release/PowerBI-storage.zip). When none of them have been built, every test is skipped with
    the command that builds them instead of failing, so unit CI does not depend on a build. When
    some are built and some are missing, the missing ones fail.

        ./src/scripts/Build-PowerBI.ps1 -NoPbip

    Expected values come from the sources the build reads (src/power-bi/reports.json and the
    shared datasets), so a deliberate change there does not need a change here.

    Opening the templates in Power BI Desktop is covered by src/scripts/Test-PowerBITemplates.ps1.
#>

BeforeDiscovery {
    $srcDir = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName
    $reports =(Get-Content (Join-Path $srcDir 'power-bi/reports.json') -Raw | ConvertFrom-Json -Depth 10).reports.PSObject.Properties.Name

    # One entry per template that should exist, whether it was built or not
    $templates = foreach ($type in 'kql', 'storage')
    {
        foreach ($name in $reports)
        {
            @{ Name = $name; Type = $type; Label = "$name.$type" }
        }
    }
}

BeforeAll {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $script:srcDir = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName
    $script:releaseDir = Join-Path (Split-Path $script:srcDir -Parent) 'release'
    $script:powerBiDir = Join-Path $script:srcDir 'power-bi'
    $script:notBuilt = 'Power BI templates are not built. Run ./src/scripts/Build-PowerBI.ps1 -NoPbip to build them.'

    # Reuse the build's own allowlist and TMDL name logic instead of copying it
    $helpers = 'Resolve-Allowlist', 'ConvertFrom-TmdlDeclaration'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:srcDir 'scripts/Build-PowerBI.ps1'), [ref]$null, [ref]$null)
    $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $helpers -contains $node.Name }, $false) `
    | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

    # Find the built templates: release/pbit first, then the release ZIP files
    $script:extractedDir = $null
    $script:templatePath = @{}
    $pbitDir = Join-Path $script:releaseDir 'pbit'
    foreach ($file in @(Get-ChildItem (Join-Path $pbitDir '*.pbit') -ErrorAction SilentlyContinue))
    {
        $script:templatePath[$file.BaseName] = $file.FullName
    }
    if ($script:templatePath.Count -eq 0)
    {
        foreach ($type in 'kql', 'storage')
        {
            $zip = Join-Path $script:releaseDir "PowerBI-$type.zip"
            if (-not (Test-Path $zip)) { continue }

            if (-not $script:extractedDir)
            {
                $script:extractedDir = Join-Path ([System.IO.Path]::GetTempPath()) "ftk-pbit-$([guid]::NewGuid().ToString('N'))"
                New-Item $script:extractedDir -ItemType Directory | Out-Null
            }
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:extractedDir, $true)
        }
        if ($script:extractedDir)
        {
            foreach ($file in @(Get-ChildItem (Join-Path $script:extractedDir '*.pbit')))
            {
                $script:templatePath[$file.BaseName] = $file.FullName
            }
        }
    }
    $script:anyBuilt = $script:templatePath.Count -gt 0

    $script:config = (Get-Content (Join-Path $script:powerBiDir 'reports.json') -Raw | ConvertFrom-Json -Depth 10).reports

    <#
        Reads a part of a PBIT as text. Power BI writes most parts as UTF-16LE, with or without a
        byte order mark, and other parts (like theme files) as UTF-8, so the encoding is detected.
    #>
    function Get-PbitText([System.IO.Compression.ZipArchiveEntry] $Entry)
    {
        $stream = $Entry.Open()
        try
        {
            $buffer = New-Object System.IO.MemoryStream
            $stream.CopyTo($buffer)
            $bytes = $buffer.ToArray()
        }
        finally { $stream.Dispose() }

        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2) }
        # UTF-16LE text that is mostly ASCII has a zero byte in every second position
        if ($bytes.Length -ge 4 -and $bytes[1] -eq 0 -and $bytes[3] -eq 0) { return [System.Text.Encoding]::Unicode.GetString($bytes) }
        return [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
    }

    # Why a template's tests can't run, or nothing when they can. Nothing built skips everything.
    # A template that is missing or unreadable fails once, in "Is built", and skips the rest.
    function Get-SkipReason
    {
        if (-not $script:anyBuilt) { return $script:notBuilt }
        if (-not $script:model) { return "$Label.pbit is missing or unreadable (see the 'Is built' test)." }
        return $null
    }

    # M and DAX are stored as a string or as an array of lines, depending on the writer
    function Get-ExpressionText($Expression)
    {
        return (@($Expression) -join "`n")
    }

    function Test-PbitParameter($Expression)
    {
        return (Get-ExpressionText $Expression) -match 'IsParameterQuery\s*=\s*true'
    }

    function Get-SourceParameter([string] $Type)
    {
        $path = Join-Path $script:powerBiDir "$Type/Shared.Dataset/definition/expressions.tmdl"
        $parameters = @{}
        foreach ($line in [System.IO.File]::ReadAllLines($path))
        {
            if ($line -notmatch "^expression (?:'(?<quoted>(?:[^']|'')+)'|(?<plain>\S+)) = (?<value>.+) meta \[(?<meta>[^\]]*IsParameterQuery=true[^\]]*)\]\s*$") { continue }

            $name = if ($Matches.quoted) { $Matches.quoted.Replace("''", "'") } else { $Matches.plain }
            $parameters[$name] = @{ Value = $Matches.value; Meta = $Matches.meta }
        }
        return $parameters
    }

    # reports.json lists a table for both report types when only one of them has it (for example,
    # Prices only exists in the storage model), so what a template gets is the overlap
    function Get-SourceTable([string] $Type)
    {
        $names = foreach ($file in @(Get-ChildItem (Join-Path $script:powerBiDir "$Type/Shared.Dataset/definition/tables") -Filter '*.tmdl'))
        {
            foreach ($line in [System.IO.File]::ReadAllLines($file.FullName))
            {
                if ($line -match '^table\s+(?<rest>.+)$') { ConvertFrom-TmdlDeclaration $Matches.rest; break }
            }
        }
        return @($names)
    }

    # Normalize spacing, which Power BI Desktop can change when it re-saves a model
    function Format-Expression([string] $Text)
    {
        return ($Text -replace '\s+', ' ').Trim()
    }

    $script:sourceParameters = @{ kql = Get-SourceParameter 'kql'; storage = Get-SourceParameter 'storage' }
    $script:sourceTables = @{ kql = Get-SourceTable 'kql'; storage = Get-SourceTable 'storage' }
}

AfterAll {
    if ($script:extractedDir) { Remove-Item $script:extractedDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Power BI templates' {
    It 'Has the expected source parameters to compare against' {
        # Guards the tests below, which would otherwise pass with nothing to compare
        $script:sourceParameters.kql.Keys | Should -Contain 'Cluster URL'
        $script:sourceParameters.storage.Keys | Should -Contain 'Storage URL'
    }

    It 'Has 6 <_> templates' -ForEach 'kql', 'storage' {
        if (-not $script:anyBuilt) { Set-ItResult -Skipped -Because $script:notBuilt; return }

        # One template per report in reports.json, named <report>.<type>
        $type = $_
        $expected = @($script:config.PSObject.Properties.Name | ForEach-Object { "$_.$type" } | Sort-Object)
        $built = @($script:templatePath.Keys | Where-Object { $_.EndsWith(".$type") } | Sort-Object)
        $built | Should -Be $expected
        $built.Count | Should -Be 6
    }

    It 'Has a PowerBI-<_>.zip with the same 6 templates' -ForEach 'kql', 'storage' {
        $zip = Join-Path $script:releaseDir "PowerBI-$_.zip"
        if (-not (Test-Path $zip)) { Set-ItResult -Skipped -Because "release/PowerBI-$_.zip is not built. $script:notBuilt"; return }

        $type = $_
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try { $entries = @($archive.Entries | ForEach-Object { $_.FullName } | Where-Object { $_ -like '*.pbit' } | Sort-Object) }
        finally { $archive.Dispose() }

        $expected = @($script:config.PSObject.Properties.Name | ForEach-Object { "$_.$type.pbit" } | Sort-Object)
        $entries | Should -Be $expected
    }
}

Describe 'Power BI template <Label>' -ForEach $templates {
    BeforeAll {
        $script:model = $null
        $script:allText = ''
        $script:loadError = $null

        $path = $script:templatePath[$Label]
        if ($path)
        {
            try
            {
                $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
                try
                {
                    $parts = @($archive.Entries | Where-Object { $_.Length -gt 0 -and $_.FullName -notmatch '\.(png|svg|jpg|jpeg|gif)$' })
                    $schemaEntry = $parts | Where-Object { $_.FullName -eq 'DataModelSchema' } | Select-Object -First 1
                    if (-not $schemaEntry) { throw 'The template has no DataModelSchema part.' }

                    # -AsHashtable because Power BI writes some properties with empty names
                    $schemaText = Get-PbitText $schemaEntry
                    $script:model = ($schemaText | ConvertFrom-Json -Depth 100 -AsHashtable).model

                    # Everything a person could see, for the demo data checks
                    $script:allText = (@($parts | ForEach-Object { if ($_.FullName -eq 'DataModelSchema') { $schemaText } else { Get-PbitText $_ } })) -join "`n"
                }
                finally { $archive.Dispose() }
            }
            catch { $script:loadError = $_.Exception.Message }
        }

        $settings = $script:config.$Name
        $script:keptTables = Resolve-Allowlist @($settings.tables) $Type
        $script:keptQueries = Resolve-Allowlist @($settings.queries) $Type
        $script:tables = @{}
        $script:expressions = @{}
        if ($script:model)
        {
            foreach ($table in @($script:model.tables)) { $script:tables[$table.name] = $table }
            foreach ($expression in @($script:model.expressions)) { $script:expressions[$expression.name] = Get-ExpressionText $expression.expression }
        }
        $script:parameters = @($script:expressions.Keys | Where-Object { Test-PbitParameter $script:expressions[$_] })
    }

    It 'Is built' {
        if (-not $script:anyBuilt) { Set-ItResult -Skipped -Because $script:notBuilt; return }

        $script:templatePath[$Label] | Should -Not -BeNullOrEmpty -Because "$Label.pbit should be built. Run ./src/scripts/Build-PowerBI.ps1 -NoPbip"
        $script:loadError | Should -BeNullOrEmpty
        $script:model | Should -Not -BeNullOrEmpty
    }

    It 'Has the tables reports.json keeps' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        # Parameters and functions that do not load a table are listed under queries, not tables
        $expected = @($script:keptTables | Where-Object { $script:sourceTables[$Type] -contains $_ } | Sort-Object -Unique)
        $expected | Should -Not -BeNullOrEmpty -Because "reports.json lists tables for $Name"
        @($script:tables.Keys | Sort-Object) | Should -Be $expected
    }

    It 'Prompts for the parameters the shared dataset defines for the report' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        $source = $script:sourceParameters[$Type]
        $expected = @($source.Keys | Where-Object { $script:keptQueries -contains $_ } | Sort-Object)
        @($script:parameters | Sort-Object) | Should -Be $expected
    }

    It 'Prompts for the required parameters' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        # Names only: values come from the shared dataset in the next test
        $required = if ($Type -eq 'storage')
        {
            'Storage URL', 'RangeStart', 'RangeEnd', 'Number of Months', 'Default Granularity', 'Experimental: Add Missing Prices', 'Deprecated: Perform Extra Query Optimizations'
        }
        else
        {
            'Cluster URL', 'Number of Months', 'Default Granularity'
        }
        foreach ($name in $required) { $script:parameters | Should -Contain $name }
    }

    It 'Asks for Remove Duplicate Resource IDs only when reports.json keeps it' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        $kept = $script:keptQueries -contains 'Remove Duplicate Resource IDs'
        ($script:parameters -contains 'Remove Duplicate Resource IDs') | Should -Be $kept
    }

    It 'Has the same default for each parameter as the shared dataset, with data sources emptied' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        $source = $script:sourceParameters[$Type]
        $wrong = foreach ($name in $script:parameters)
        {
            if (-not $source.ContainsKey($name)) { continue }

            # Data source URLs ship empty so people supply their own. Everything else is unchanged.
            $value = if ($name.EndsWith(' URL')) { 'null' } else { $source[$name].Value }
            $expected = Format-Expression "$value meta [$($source[$name].Meta)]"
            $actual = Format-Expression $script:expressions[$name]
            if ($actual -ne $expected) { "'$name' is '$actual', expected '$expected'" }
        }
        $wrong | Should -BeNullOrEmpty
    }

    It 'Has empty data source parameters' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        $empty = @($script:parameters | Where-Object { $_.EndsWith(' URL') -or $_ -in 'RangeStart', 'RangeEnd' })
        $empty | Should -Not -BeNullOrEmpty -Because 'every template has a Storage URL or Cluster URL parameter'
        $notEmpty = $empty | Where-Object { $script:expressions[$_] -notmatch '^\s*null\s+meta\s*\[' } | ForEach-Object { "'$_' is $($script:expressions[$_])" }
        $notEmpty | Should -BeNullOrEmpty

        # The demo filter limits demo reports to the demo hub. Templates ship it empty.
        if ($script:expressions.ContainsKey('ftk_DemoFilter'))
        {
            $script:expressions['ftk_DemoFilter'] | Should -Match '^\s*\(\)\s*=>\s*""'
        }
    }

    It 'Has no hard-coded storage account or cluster' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        # A name in front of the endpoint is an account. Help text only mentions the bare endpoint.
        $pattern = '(?i)[a-z0-9][a-z0-9-]*\.(?:dfs|blob)\.core\.windows\.net|[a-z0-9][a-z0-9-]*\.[a-z0-9]+\.kusto\.windows\.net'
        $found = [regex]::Matches($script:allText, $pattern) | ForEach-Object { $_.Value } | Sort-Object -Unique
        $found | Should -BeNullOrEmpty -Because 'templates ship without a data source'
    }

    It 'Has no demo hub or demo storage account' {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        $found = [regex]::Matches($script:allText, '(?i)ftk-?demo[a-z0-9-]*') | ForEach-Object { $_.Value } | Sort-Object -Unique
        $found | Should -BeNullOrEmpty -Because 'demo data sources belong in the demo reports, not the templates'
    }

    It 'Reads gzip-compressed exports' -Skip:($Type -ne 'storage') {
        if ($reason = Get-SkipReason) { Set-ItResult -Skipped -Because $reason; return }

        # Costs reads exports through ftk_Storage, so the .gz handling lives there. Booleans, not
        # Should -Match, because these queries are long and a failure would print all of one.
        $costs = Get-ExpressionText $script:tables['Costs'].partitions[0].source.expression
        ($costs -match 'ftk_Storage\s*\(\s*"focuscost"') | Should -BeTrue -Because 'the Costs query should read focuscost exports through ftk_Storage'

        $storage = $script:expressions['ftk_Storage']
        $storage | Should -Not -BeNullOrEmpty -Because 'the Costs query depends on ftk_Storage'
        $storage.Contains('[Extension] = ".gz"') | Should -BeTrue -Because 'ftk_Storage should include .gz files, like [Extension] = ".gz"'
        ($storage -match 'Binary\.Decompress\(\[Content\], Compression\.GZip\)') | Should -BeTrue -Because 'ftk_Storage should decompress .gz files'
    }
}
