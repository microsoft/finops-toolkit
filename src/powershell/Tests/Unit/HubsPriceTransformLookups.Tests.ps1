# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #1736 (Prices_transform row fan-out) and #1625 (commitment discount eligibility
    computed from a per-invocation partial view of Prices_raw).
    Text-pattern checks, like HubsReservationPriceBackfill.Tests.ps1.
#>

Describe 'HubsPriceTransformLookups' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $ingestionFiles = @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql') | ForEach-Object {
            @{ Name = $_; FullName = (Join-Path $scriptsPath $_) }
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $analyticsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics'
    }

    Context 'Savings plan price lookup (#1736)' {

        It 'Should dedupe the Consumption side with take_any, not distinct: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match "lookup kind=leftouter \(prices \| where x_SkuPriceType == 'Consumption'[^\n]*summarize take_any\(ListUnitPrice\), take_any\(ContractedUnitPrice\), take_any\(x_BaseUnitPrice\) by tmp_SavingsPlanKey\)" -Because 'distinct over price columns leaves several rows per key and fans out SavingsPlan rows'
            $content | Should -Not -Match '\| distinct tmp_SavingsPlanKey' -Because 'distinct over price columns is the #1736 fan-out bug'
        }

        It 'Should keep the savings plan meter prefilter on the dimension side: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match "'Consumption' \| where x_SkuMeterId in \(spMeters\) \| summarize take_any" -Because 'limits the aggregation to savings plan meters on the ingestion hot path'
        }

        It 'Should include billing profile and currency in the savings plan key: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'tmp_SavingsPlanKey = strcat\([^\n]*x_BillingProfileId[^\n]*Currency' -Because 'one billing profile or currency must not pick up another one''s price'
        }
    }

    Context 'Commitment discount eligibility (#1625)' {

        It 'Should source eligibility from the CommitmentDiscountEligibility table: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'let commitmentEligibility = CommitmentDiscountEligibility' -Because 'deriving eligibility only from the invocation''s partial Prices_raw gives wrong results for multi-file exports'
            $content | Should -Match 'lookup kind=leftouter \(commitmentEligibility\) on tmp_MeterId'
        }

        It 'Should fall back to pricesheet-derived eligibility when the meter is missing: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match "iff\(x_SkuMeterId in \(spMeters\), 'Eligible', 'Not Eligible'\)" -Because 'Azure Government/China and new meters are not in the open data'
            $content | Should -Match "iff\(x_SkuMeterId in \(riMeters\) and x_SkuPriceType != 'ReservedInstance', 'Eligible', 'Not Eligible'\)"
        }

        It 'Should create and populate the table for ADF, Fabric, and local hubs' {
            Get-Content -Path (Join-Path $analyticsPath 'scripts/IngestionSetup_HubInfra.kql') -Raw | Should -Match '\.create-merge table CommitmentDiscountEligibility'
            Get-Content -Path (Join-Path $analyticsPath 'scripts/IngestionSetup_OpenDataExternal.kql') -Raw | Should -Match '\.set-or-replace CommitmentDiscountEligibility'
            Get-Content -Path (Join-Path $analyticsPath 'app.bicep') -Raw | Should -Match '\.set-or-replace CommitmentDiscountEligibility'
        }
    }
}
