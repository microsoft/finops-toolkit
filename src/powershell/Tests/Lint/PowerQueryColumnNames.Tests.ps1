# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Lint rule: Power Query column names in Power BI datasets must refer to columns that exist.

    Nothing in CI runs Power Query, so a mistyped column name in a .tmdl partition ships and only
    surfaces as a refresh failure on a customer's report. That is exactly what happened with
    issue #2332: the FOCUS 1.2 branch of the Costs query passed {"SkuMeterName"} as the
    columnsToSearch of Table.ReplaceValue, but the column FOCUS 1.2 emits is SkuMeter. The typo
    was introduced in fa19ad68 and survived because the 1.2 branch was never exercised.

    Two rules, both static:

    1. Known columns - every columnsToSearch literal in Table.ReplaceValue must be a column that
       exists: one of the Cost Management export schemas, one the query creates itself via
       Table.AddColumn / Table.RenameColumns, or a column declared on the model table.

    2. Version-dropped columns - FOCUS 1.2 removes three columns that earlier versions carry
       (x_InvoiceId and x_PricingCurrency were promoted to InvoiceId / PricingCurrency,
       x_SkuMeterName was renamed to SkuMeter). ftk_Storage does no backfill for focuscost
       (CleanColumns passes ExtractColumns straight through), so the columns available are exactly
       the union of what the export files contain. Referencing a dropped column without a
       Table.HasColumns / _exists guard fails on a container that holds only 1.2 exports.

       Verified 2026-09-21 against a real FocusCost export (dataVersion 1.2-preview, 105 columns):
       InvoiceId, PricingCurrency and SkuMeter are present; x_InvoiceId, x_PricingCurrency and
       x_SkuMeterName are absent. Note that docs-mslearn/focus/metadata.md is not a reliable
       source for this - it listed x_SkuMeterName under 1.2-preview until this change corrected it.
       The ADF mappings under Exports/schemas are authoritative and are what this rule reads.

    Rule 2 is baselined per file as a ratchet:
    - Guarding a reference REQUIRES lowering the count here (the test fails on stale entries).
    - Adding a new unguarded reference is never allowed.
#>

Describe 'PowerQueryColumnNames' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

        # Power Query lives in the `source = ```...``` ` partition blocks of the dataset .tmdl files.
        $partitionPattern = [regex]'(?s)source = \x60{3}(.*?)\x60{3}'

        $scanFiles = @(
            Get-ChildItem -Path (Join-Path $repoRoot 'src/power-bi') -Filter '*.tmdl' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $partitionPattern.IsMatch((Get-Content -Path $_.FullName -Raw)) } |
                Sort-Object FullName |
                ForEach-Object {
                    @{ FullName = $_.FullName; RelPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') }
                }
        )
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $schemaDir = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.CostManagement/Exports/schemas'

        # Every column name any Cost Management export can deliver, across all dataset types and
        # FOCUS versions. Both sides of the mapping count: `source` is the export column, `sink` is
        # the name the hub stores it under, and queries legitimately reference either.
        function Get-SchemaColumn([string] $path)
        {
            $mappings = (Get-Content -Path $path -Raw | ConvertFrom-Json).translator.mappings
            return @($mappings | ForEach-Object { $_.source.name; $_.sink.name } | Where-Object { $_ } | Sort-Object -Unique)
        }

        $schemaFiles = @(Get-ChildItem -Path $schemaDir -Filter '*.json' -File)
        $knownColumns = [System.Collections.Generic.HashSet[string]]::new([string[]]@($schemaFiles | ForEach-Object { Get-SchemaColumn $_.FullName }), [StringComparer]::Ordinal)

        # Columns an earlier FOCUS version carries that 1.2 does not. Derived from the schemas
        # rather than hard-coded so a future FOCUS version updates the rule automatically.
        $focus10 = Get-SchemaColumn (Join-Path $schemaDir 'focuscost_1.0r2.json')
        $focus12 = @(
            (Get-SchemaColumn (Join-Path $schemaDir 'focuscost_1.2-preview.json'))
            (Get-SchemaColumn (Join-Path $schemaDir 'focuscost_1.2.json'))
        ) | Sort-Object -Unique
        $droppedInFocus12 = @($focus10 | Where-Object { $_ -notin $focus12 })

        $partitionPattern = [regex]'(?s)source = \x60{3}(.*?)\x60{3}'
        # Last argument of Table.ReplaceValue: the columns the replacement searches.
        $columnsToSearchPattern = [regex]'Replacer\.\w+\s*,\s*\{([^}]*)\}'
        $quotedNamePattern = [regex]'"([A-Za-z_][A-Za-z0-9_]*)"'
        $addColumnPattern = [regex]'Table\.AddColumn\(\s*[^,]+,\s*"([^"]+)"'
        $renamePairPattern = [regex]'\{\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\}'
        $modelColumnPattern = [regex]'(?m)^\s*sourceColumn:\s*(\S+)'

        # Unguarded references to columns FOCUS 1.2 drops, counted per repo-relative path.
        # Ratchet only: lower on fix, never raise.
        #
        # Costs.tmdl: the "Handle columns renamed in FOCUS 1.2 gracefully" block reads
        # [x_InvoiceId], [x_PricingCurrency] and [x_SkuMeterName], and Align12 passes all three as
        # columnsToSearch. On a container holding only 1.2 exports none of them exist. Guard the
        # block with the _exists / _swapCol helpers already defined at the top of the query, then
        # lower this entry. Tracked on issue #2332 / PR #2333.
        $baseline = @{
            'src/power-bi/storage/Shared.Dataset/definition/tables/Costs.tmdl' = 3
        }
    }

    It 'Should find the export schemas and the dataset partitions' {
        $knownColumns.Count | Should -BeGreaterThan 100 -Because 'the Cost Management export schemas define the column vocabulary this rule checks against'
        $droppedInFocus12.Count | Should -BeGreaterThan 0 -Because 'FOCUS 1.2 renames or promotes columns that earlier versions carry; if this is empty the schema files moved or changed shape'
    }

    It 'Should only search columns that exist: <RelPath>' -ForEach $scanFiles {
        $content = Get-Content -Path $FullName -Raw
        $partitions = @($partitionPattern.Matches($content) | ForEach-Object { $_.Groups[1].Value })

        # Columns the query builds for itself are just as valid as exported ones.
        $created = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($partition in $partitions)
        {
            foreach ($match in $addColumnPattern.Matches($partition)) { [void] $created.Add($match.Groups[1].Value) }
            foreach ($match in $renamePairPattern.Matches($partition)) { [void] $created.Add($match.Groups[2].Value) }
        }
        foreach ($match in $modelColumnPattern.Matches($content)) { [void] $created.Add($match.Groups[1].Value) }

        $searched = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($partition in $partitions)
        {
            foreach ($match in $columnsToSearchPattern.Matches($partition))
            {
                foreach ($name in $quotedNamePattern.Matches($match.Groups[1].Value)) { [void] $searched.Add($name.Groups[1].Value) }
            }
        }

        $unknown = @($searched | Where-Object { -not $knownColumns.Contains($_) -and -not $created.Contains($_) } | Sort-Object)

        $unknown -join ', ' | Should -BeNullOrEmpty -Because 'Table.ReplaceValue fails with "The column ''<name>'' of the table wasn''t found" when columnsToSearch names a column that is not in the table. Every name must be an export column, a column the query adds itself, or a column on the model table (see issue #2332).'
    }

    It 'Should not reference columns FOCUS 1.2 drops without a guard: <RelPath>' -ForEach $scanFiles {
        $content = Get-Content -Path $FullName -Raw

        # FOCUS versioning only applies to the focuscost dataset. The other datasets have their own
        # schemas that happen to share column names: Prices reads "pricesheet" and renames MeterName
        # to x_SkuMeterName, ReservationTransactions reads "reservationtransactions". Those uses are
        # correct and must not be flagged.
        $partitions = @(
            $partitionPattern.Matches($content) |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -match 'ftk_Storage\(\s*"focuscost"' }
        )
        $allowed = if ($baseline.ContainsKey($RelPath)) { $baseline[$RelPath] } else { 0 }

        $unguarded = @(
            foreach ($column in $droppedInFocus12)
            {
                $referenced = $false
                $guarded = $false
                foreach ($partition in $partitions)
                {
                    if ($partition -match ('\[{0}\]|"{0}"' -f [regex]::Escape($column))) { $referenced = $true }
                    if ($partition -match ('(Table\.HasColumns|_exists)\([^)]*"{0}"' -f [regex]::Escape($column))) { $guarded = $true }
                }
                if ($referenced -and -not $guarded) { $column }
            }
        )

        $unguarded.Count | Should -BeLessOrEqual $allowed -Because ("FOCUS 1.2 does not deliver these columns and ftk_Storage does not backfill them, so a container holding only 1.2 exports fails to refresh. Guard the reference with Table.HasColumns or the _exists helper. Unguarded here: $($unguarded -join ', ')")

        if ($unguarded.Count -le $allowed)
        {
            # Ratchet: if a reference was guarded, the baseline must be lowered so it cannot return.
            $unguarded.Count | Should -Be $allowed -Because ("the unguarded reference count in this file dropped below the baseline ($allowed); lower the baseline entry for '$RelPath' in PowerQueryColumnNames.Tests.ps1 to $($unguarded.Count) (or remove it if 0) so the fix is locked in.")
        }
    }
}
