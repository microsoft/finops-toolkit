# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the missing-cost gate split (#2214 / #2235 / #2286):
    the ListCost/ContractedCost repair fallback must not require a meter ID and offer ID -- only the
    price-sheet lookup does. Rows without either (most commonly third-party Marketplace/ISV purchases,
    which have no Microsoft retail list price by design) must still reach the repair fallback so ListCost
    isn't left at 0 despite a real EffectiveCost, which was corrupting x_TotalSavings and Effective Savings
    Rate reporting.

    Per-row behavioral coverage lives in the executable harness
    Tests/assets/MissingCostGateSplit.kql (PASS = 0 returned rows on any Kusto database).

    v1.0 also gets the MissingListCost flag-clearing fix (defect 4), but NOT the x_SourceValues audit trail
    (defect 3) -- v1.0's Costs_final_v1_0 schema is intentionally frozen so people can revert to legacy
    behavior; adding a column there is out of scope permanently, not just for this change.
#>

Describe 'HubsMissingCostGate' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $guardFiles = @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql') | ForEach-Object {
            @{ Name = $_; FullName = (Join-Path $scriptsPath $_) }
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $harnessPath = Join-Path $repoRoot 'src/powershell/Tests/assets/MissingCostGateSplit.kql'
    }

    Context 'Gate split' {

        It 'Should gate the cost-repair fallback on tmp_MissingCost, not tmp_MissingPrices: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'extend\s+tmp_MissingCost\s*=' `
                -Because 'the cost-repair fallback must be reachable without a meter/offer ID (#2214); tmp_MissingCost is the broader gate that no longer requires them'
        }

        It 'Should narrow tmp_MissingPrices from tmp_MissingCost plus the meter/offer ID requirement: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'extend\s+tmp_MissingPrices\s*=\s*tmp_MissingCost\s+and\s+isnotempty\(x_SkuMeterId\)\s+and\s+isnotempty\(x_SkuOfferId\)' `
                -Because 'only the price-sheet join needs a meter/offer ID; the cost-repair fallback below does not'
        }

        It 'Should filter into the repair block on tmp_MissingCost, not tmp_MissingPrices: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match '(?m)\|\s*where\s+tmp_MissingCost\s*$' -Because 'rows without a meter/offer ID must still enter the repair block, just skip the price-sheet join'
        }

        It 'Should restrict the price-sheet join to rows that pass tmp_MissingPrices: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'costsWithMissingPrices\s*\|\s*where\s+tmp_MissingPrices\s*\|\s*summarize\s+by\s+tmp_ReservationPriceLookupKey' `
                -Because 'a row without a meter/offer ID has no valid lookup key and must not join to the price sheet'
        }

        It 'Should merge unrepaired rows back by tmp_MissingCost, not tmp_MissingPrices: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'union\s*\(allCosts\s*\|\s*where\s+not\(tmp_MissingCost\)\)' `
                -Because 'rows that entered the repair block are gated by tmp_MissingCost now, so the merge-back of untouched rows must exclude the same set'
        }
    }

    Context 'MissingListCost flag clears after repair' {

        It 'Should clear MissingListCost from x_SourceChanges once ListCost is repaired: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match "iff\(\(isnotempty\(ListCost\) and ListCost != 0\),\s*\r?\n\s*trim_end\(',', replace_string\(replace_string\(x_SourceChanges, 'MissingListCost,', ''\), 'MissingListCost', ''\)\),\s*\r?\n\s*x_SourceChanges\)" `
                -Because 'MissingListCost is computed before the repair runs, so a repaired row must not still report itself as broken (#2214 defect 4)'
        }
    }

    Context 'Equivalence harness' {

        It 'Should have the gate-split harness asset' {
            Test-Path $harnessPath | Should -BeTrue
        }

        It 'Should assert both the repaired outcome and the changed-vs-old-gate outcome per row' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match '\| where new_entersRepair != expectedRepaired or \(old_entersRepair != new_entersRepair\) != expectedChanged' `
                -Because 'the harness must return only rows that violate either the final gate outcome or the expected delta from the old gate'
        }

        It 'Should cover rows missing only one of meter ID or offer ID' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'only meter ID set' -Because 'the old gate required both IDs; a row with just one must still change behavior'
            $harness | Should -Match 'only offer ID set' -Because 'the old gate required both IDs; a row with just one must still change behavior'
        }

        It 'Should cover the unused spend commitment exclusion' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'unused spend commitment' -Because 'unused spend commitments must stay excluded from the repair fallback under both gates'
        }

        It 'Should cover the non-Microsoft provider exclusion' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'non-Microsoft provider' -Because 'the gate is Microsoft-only under both old and new behavior'
        }
    }

    Context 'v1.0 schema is frozen' {

        It 'Should not add x_SourceValues to the v1.0 schema' {
            $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
            $v10Path = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_0.kql'
            $content = Get-Content -Path $v10Path -Raw
            $content | Should -Not -Match 'x_SourceValues' `
                -Because 'Costs_final_v1_0 is kept for people who want to revert to legacy behavior; its schema is intentionally frozen and must never gain new columns'
        }
    }
}
