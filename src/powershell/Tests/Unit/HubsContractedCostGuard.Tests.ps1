# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the ContractedCost recompute guard (#2216 / PR #2221):
    the guard must compare with a 0.0001 tolerance, not exact float equality, so floating-point
    noise does not trigger no-op rewrites that pollute the x_SourceValues audit trail.

    Per-row behavioral coverage lives in the executable harness
    Tests/assets/ContractedCostTolerance.kql (PASS = 0 returned rows on any Kusto database).
#>

Describe 'HubsContractedCostGuard' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $guardFiles = @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql') | ForEach-Object {
            @{ Name = $_; FullName = (Join-Path $scriptsPath $_) }
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $harnessPath = Join-Path $repoRoot 'src/powershell/Tests/assets/ContractedCostTolerance.kql'
        $toleranceGuard = 'abs(ContractedCost - ContractedUnitPrice * PricingQuantity) >= 0.0001'
    }

    Context 'Tolerance guard' {

        It 'Should compare ContractedCost with a tolerance: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains($toleranceGuard) | Should -BeTrue -Because 'the ContractedCost recompute must use the 0.0001 tolerance (#2216); exact float equality fires on last-bit noise and floods x_SourceValues with no-op rewrites'
        }

        It 'Should not compare ContractedCost with exact inequality: <Name>' -ForEach $guardFiles {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains('ContractedCost != ContractedUnitPrice * PricingQuantity') | Should -BeFalse -Because 'exact float inequality was replaced by the tolerance comparison in #2216'
        }
    }

    Context 'Equivalence harness' {

        It 'Should have the tolerance harness asset' {
            Test-Path $harnessPath | Should -BeTrue
        }

        It 'Should assert expected divergence per row' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match '\| where \(old_fires != new_fires\) != expectedDivergent' -Because 'the harness must return only rows that violate the recorded old-vs-new expectation'
        }

        It 'Should cover both column typings' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'qty:real' -Because 'Costs_final_v1_2 columns are real'
            $harness | Should -Match 'qty:decimal' -Because 'Costs_final_v1_0 columns are decimal'
        }
    }
}
