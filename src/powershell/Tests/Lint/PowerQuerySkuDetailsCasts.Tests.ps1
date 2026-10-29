# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Lint rule: values extracted from the free-form x_SkuDetails JSON blob must not be cast with an unguarded
    Table.TransformColumnTypes.

    The blob's shape varies by charge type (VM usage, Marketplace, reservation purchase, etc.), so VCPUs / vCores
    are not always a clean number. An unguarded cast produces an Error cell, which Power BI surfaces on refresh as
    "OLE DB or ODBC error: Type mismatch (DISP_E_TYPEMISMATCH 0x80020005)" (issue #2297). Nothing in CI runs
    Power Query, so this static check keeps the guarded form (try ... otherwise null) from regressing.
#>

Describe 'PowerQuerySkuDetailsCasts' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $files = @(
            Get-ChildItem -Path (Join-Path $repoRoot 'src/power-bi') -Include '*.tmdl', '*.pq' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { (Get-Content -Path $_.FullName -Raw) -match 'tmp_VMvCPUs|tmp_SQLvCores' } |
                ForEach-Object { @{ FullName = $_.FullName; RelPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') } }
        )
    }

    It 'Finds at least one dataset that extracts VCPUs/vCores' {
        $files.Count | Should -BeGreaterThan 0
    }

    It 'Does not cast tmp_VMvCPUs / tmp_SQLvCores with an unguarded Table.TransformColumnTypes in <RelPath>' -ForEach $files {
        $text = Get-Content -Path $FullName -Raw
        $unguarded = [regex]::Matches($text, '\{\s*"tmp_(VMvCPUs|SQLvCores)"\s*,\s*Int64\.Type\s*\}')
        $unguarded.Count | Should -Be 0 -Because 'an unparseable VCPUs/vCores value must degrade to null (try ... otherwise null), not fail the refresh'
    }

    It 'Guards the tmp_VMvCPUs / tmp_SQLvCores cast with try ... otherwise null in <RelPath>' -ForEach $files {
        $text = Get-Content -Path $FullName -Raw
        $text | Should -Match '"tmp_VMvCPUs",\s*each try [^,]+ otherwise null'
        $text | Should -Match '"tmp_SQLvCores",\s*each try [^,]+ otherwise null'
    }
}
