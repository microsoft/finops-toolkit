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

    ARG-only surfaces (workbooks, recommendation queries, the alerts logic app) are additionally
    checked for operators Azure Resource Graph rejects: the lookup operator and the semi/anti
    join flavors. Verified live against ARG (2026-08): supported kinds are inner, innerunique,
    leftouter, rightouter, fullouter; lookup, leftsemi, leftanti, rightsemi, rightanti, and
    `in`/`!in` with a subquery are all rejected with InvalidQuery. Exclusion joins in ARG must
    therefore use the leftouter + `where isempty(<right key>)` emulation (with a key-unique
    right side) — the one place that pattern is acceptable.
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

        # Surfaces whose KQL runs on Azure Resource Graph. Workbook files may also contain the
        # occasional Log Analytics query (queryType 0); if one legitimately needs lookup or a
        # semi/anti join, add a per-file allowlist analogous to the bare-join baseline.
        $argFiles = @($scanFiles | Where-Object {
                $_.RelPath -like 'src/workbooks/*' -or
                $_.RelPath -like 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries/*' -or
                $_.RelPath -eq 'src/templates/finops-alerts/modules/logicApp.bicep'
            })

        # Published docs mix engines within a single file: docs-mslearn/best-practices/compute.md
        # carries both ARG inventory queries and hub (ADX) cost queries, and the latter legitimately
        # use lookup. So docs are classified per code block rather than per file - see the
        # 'ARG examples' test below.
        $docsFiles = @($scanFiles | Where-Object { $_.RelPath -like 'docs-mslearn/*' })
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

        # Operators Azure Resource Graph rejects with InvalidQuery (verified live, 2026-08).
        $argRejectedPattern = [regex]'\|\s*lookup\b|join\s+kind\s*=\s*(leftanti|leftsemi|rightanti|rightsemi|anti|semi|leftantisemi|rightantisemi)\b'

        # ARG tables that can open a query. A KQL query names its source table first, so the first
        # non-comment line of a docs code block identifies the engine it targets.
        $argTablePattern = [regex]'^\s*(resources|resourcecontainers|advisorresources|resourcechanges|resourcecontainerchanges|healthresources|securityresources|policyresources|guestconfigurationresources|patchassessmentresources|patchinstallationresources|maintenanceresources|servicehealthresources|desktopvirtualizationresources|kubernetesconfigurationresources|extendedlocationresources|networkresources|chaosresources|iotsecurityresources|insightsresources)\b'

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

    It 'Should not use operators ARG rejects (lookup, semi/anti joins): <RelPath>' -ForEach $argFiles {
        $content = Get-Content -Path $FullName -Raw
        $rejected = @($argRejectedPattern.Matches($content))

        @($rejected | ForEach-Object { $_.Value }) -join '; ' | Should -BeNullOrEmpty -Because ('Azure Resource Graph rejects the lookup operator and all semi/anti join flavors with InvalidQuery (verified live; supported kinds are inner, innerunique, leftouter, rightouter, fullouter). For exclusions in ARG, use join kind=leftouter + where isempty(<right key>) with a key-unique right side. If this file contains a Log Analytics query that legitimately needs the operator, add a per-file allowlist to this test.')
    }

    It 'Should not use operators ARG rejects in docs ARG examples: <RelPath>' -ForEach $docsFiles {
        $content = Get-Content -Path $FullName -Raw

        # Fenced code blocks, so a hub (ADX) example in the same file cannot mask or trip this rule.
        $offenders = @(
            foreach ($block in [regex]::Matches($content, '(?ms)^```[a-zA-Z]*\r?\n(.*?)^```'))
            {
                $code = $block.Groups[1].Value
                $firstLine = @($code -split '\r?\n' | Where-Object { $_.Trim() -and $_.Trim() -notmatch '^//' })[0]
                if ($null -eq $firstLine -or -not $argTablePattern.IsMatch($firstLine)) { continue }

                $argRejectedPattern.Matches($code) | ForEach-Object { $_.Value.Trim() }
            }
        )

        $offenders -join '; ' | Should -BeNullOrEmpty -Because ('this code block opens with an Azure Resource Graph table, and ARG rejects the lookup operator and all semi/anti join flavors with InvalidQuery (verified live). Published examples are copied verbatim by readers, so they must run as written: use join kind=leftouter + where isempty(<right key>) for exclusions. Hub (ADX) examples in the same file are unaffected - they open with Costs, Prices, or another hub table.')
    }
}
