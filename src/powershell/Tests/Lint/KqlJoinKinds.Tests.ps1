# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Lint rule: every KQL join must state an explicit kind (PR #2225).

    A bare `| join (...)` defaults to kind=innerunique, which deduplicates the left side
    on the join key and silently drops rows. This has caused real data loss (savings plan
    recommendations collapsing to one row per subscription, SQL VMs with duplicate names
    disappearing). In Azure Resource Graph the same default applies and `lookup` is not
    available, so an explicit kind is the only way to state intent.

    The rule scans every surface that carries KQL: hub database scripts, the query catalog,
    ARG recommendation queries, the ADX dashboard, the finops-alerts logic app, workbooks,
    optimization engine runbooks and views, and the published docs examples.

    Known pre-existing bare joins are baselined per file below. The baseline is a ratchet:
    - Fixing a bare join REQUIRES lowering the count here (the test fails on stale entries).
    - Adding a new bare join is never allowed; write `join kind=...` explicitly.
#>

Describe 'KqlJoinKinds' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

        $scanTargets = @(
            @{ Path = 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'; Filter = '*.kql'; Recurse = $false }
            @{ Path = 'src/queries/catalog'; Filter = '*.kql'; Recurse = $false }
            @{ Path = 'src/powershell/Tests/assets'; Filter = '*.kql'; Recurse = $false }
            @{ Path = 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries'; Filter = '*.json'; Recurse = $false }
            @{ Path = 'src/templates/finops-hub'; Filter = 'dashboard.json'; Recurse = $false }
            @{ Path = 'src/templates/finops-alerts/modules'; Filter = 'logicApp.bicep'; Recurse = $false }
            @{ Path = 'src/workbooks'; Filter = '*.workbook'; Recurse = $true }
            @{ Path = 'src/workbooks'; Filter = 'workbook.json'; Recurse = $true }
            @{ Path = 'src/optimization-engine/runbooks'; Filter = '*.ps1'; Recurse = $true }
            @{ Path = 'src/optimization-engine/views'; Filter = '*.json'; Recurse = $true }
            @{ Path = 'docs-mslearn'; Filter = '*.md'; Recurse = $true }
        )

        $scanFiles = @($scanTargets | ForEach-Object {
                $full = Join-Path $repoRoot $_.Path
                Get-ChildItem -Path $full -Filter $_.Filter -Recurse:$_.Recurse -File -ErrorAction SilentlyContinue
            } | Sort-Object FullName -Unique | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName; RelPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') }
            })
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scanFileCount = @(
            (Join-Path $repoRoot 'src/workbooks'),
            (Join-Path $repoRoot 'src/optimization-engine'),
            (Join-Path $repoRoot 'src/queries/catalog'),
            (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts')
        ) | ForEach-Object { Get-ChildItem -Path $_ -Recurse -Include '*.kql', '*.workbook', 'workbook.json', '*.ps1', '*.json' -File -ErrorAction SilentlyContinue } | Measure-Object | Select-Object -ExpandProperty Count

        # Matches `| join` not followed by `kind=` before the right-table parenthesis.
        # Catches `| join (`, `| join(`, and `| join hint.x=y (`; ignores `| join kind=...` and `lookup`.
        $bareJoinPattern = [regex]'\|\s*join\b(?![^(\r\n]*\bkind\s*=)'

        # Pre-existing bare joins, counted per repo-relative path. Ratchet only: lower on fix, never raise.
        # All remaining entries are benign today (left side unique on the join key) but rely on the
        # innerunique default implicitly. Convert to an explicit kind when touching these queries.
        $baseline = @{
            'src/workbooks/optimization/AHB/AHB.workbook'         = 24
            'src/workbooks/optimization/Compute/AHB.workbook'     = 20
            'src/workbooks/optimization/Networking/Networking.workbook' = 3
            'src/workbooks/governance/workbook.json'              = 1
        }
    }

    It 'Should scan at least one file per surface' {
        $scanFileCount | Should -BeGreaterThan 100
    }

    It 'Should not add bare joins (no explicit kind): <RelPath>' -ForEach $scanFiles {
        $content = Get-Content -Path $FullName -Raw
        $bareJoins = @($bareJoinPattern.Matches($content))
        $allowed = if ($baseline.ContainsKey($RelPath)) { $baseline[$RelPath] } else { 0 }

        $bareJoins.Count | Should -BeLessOrEqual $allowed -Because ('a bare "| join" defaults to kind=innerunique, which deduplicates the left side on the join key and silently drops rows (see PR #2225). State the kind explicitly: kind=inner for lookups/filters, kind=leftouter for enrichment, kind=leftanti for exclusion. In ADX/Log Analytics, prefer the lookup operator for small dimension tables.')

        if ($bareJoins.Count -le $allowed)
        {
            # Ratchet: if bare joins were removed, the baseline must be lowered so they cannot return.
            $bareJoins.Count | Should -Be $allowed -Because ("the bare-join count in this file dropped below the baseline ($allowed); lower the baseline entry for '$RelPath' in KqlJoinKinds.Tests.ps1 to $($bareJoins.Count) (or remove it if 0) so the fix is locked in.")
        }
    }
}
