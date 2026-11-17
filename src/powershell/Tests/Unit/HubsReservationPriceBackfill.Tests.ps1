# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the MCA reservation list-price backfill fix (#1769 / #2176):
    the price backfill gate must not require x_SkuOfferId. x_SkuOfferId is EA-only -- for MCA it is blank on
    both the cost and price side (confirmed against reporter data in #2176), so gating on it excluded every
    MCA row from the price backfill before the join was even attempted. x_SkuOfferId stays in the lookup key
    unchanged: for MCA it is blank on both sides (a no-op suffix), and for EA it keeps differentiating rows
    (e.g. Production vs Dev/Test offers) exactly as before.

    BillingProfileId format (#2356): the Actual and Amortized transforms now reduce an MCA ARM billing-profile path once, up front,
    to its short ID, matching the FOCUS and Prices transforms, so the lookup key agrees on both sides. Covered by a
    content assertion below.

    Per-row behavioral coverage lives in the executable harness
    Tests/assets/ReservationPriceBackfillKey.kql (PASS = 0 returned rows on any Kusto database).
#>

Describe 'HubsReservationPriceBackfill' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $ingestionFiles = @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql') | ForEach-Object {
            @{ Name = $_; FullName = (Join-Path $scriptsPath $_) }
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $harnessPath = Join-Path $repoRoot 'src/powershell/Tests/assets/ReservationPriceBackfillKey.kql'
    }

    Context 'Missing-price gate' {

        It 'Should not require x_SkuOfferId to attempt the backfill: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains('isnotempty(x_SkuMeterId) and isnotempty(x_SkuOfferId)') | Should -BeFalse -Because 'x_SkuOfferId is EA-only and blank for every MCA row (cost and price side alike, confirmed in #2176); gating on it excludes every MCA row from the price backfill before the join is even attempted (#1769, #2176)'
        }

        It 'Should still require x_SkuMeterId to attempt the backfill: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content | Should -Match 'isnotempty\(x_SkuMeterId\)(?!\s+and\s+isnotempty\(x_SkuOfferId\))' -Because 'the meter ID is still required to identify the on-demand price to recover, without also requiring the EA-only offer ID (the negative lookahead rules out matching the pre-fix combined condition)'
        }

        It 'Should scope the offer-ID-less backfill to reservation usage rows: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains("and (isnotempty(x_SkuOfferId) or CommitmentDiscountCategory == 'Usage')") | Should -BeTrue -Because 'rows without an offer ID must only enter the backfill when they are reservation usage; otherwise every non-EA row would be imputed contracted and list values from effective when the price lookup misses'
        }

        It 'Should leave x_SkuOfferId in the reservation price lookup key: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains('x_SkuMeterId, x_SkuOfferId))') | Should -BeTrue -Because 'the key is unchanged by this fix: for MCA x_SkuOfferId is blank on both sides (a no-op suffix), and for EA it keeps differentiating rows (e.g. Production vs Dev/Test offers) as before'
        }
    }

    Context 'Billing profile ID normalization (#2356)' {

        It 'Should normalize BillingProfileId once, before any column uses it, on the Actual and Amortized paths: <Name>' -ForEach $ingestionFiles {
            $content = Get-Content -Path $FullName -Raw
            $normalize = [regex]::Escape("| extend BillingProfileId = iff(BillingProfileId startswith '/', tostring(split(BillingProfileId, '/')[-1]), BillingProfileId)") + '\r?\n\s*\| extend x_AmortizationClass'
            ([regex]::Matches($content, $normalize)).Count | Should -Be 2 -Because 'both the Actual and Amortized transforms must reduce an MCA ARM path to its short ID before BillingAccountId, BillingAccountType, PricingCurrency, and x_BillingProfileId read it, so the reservation price lookup key matches the Prices side (#2356)'
            ([regex]::Matches($content, 'x_BillingProfileId = BillingProfileId,')).Count | Should -Be 2 -Because 'x_BillingProfileId reads the already-normalized value'
            $content.Contains("x_BillingProfileId = iff(BillingProfileId startswith '/', tostring(") | Should -BeFalse -Because 'a second, column-local normalization would let other columns drift from x_BillingProfileId'
        }
    }

    Context 'Equivalence harness' {

        It 'Should have the reservation price backfill key harness asset' {
            Test-Path $harnessPath | Should -BeTrue
        }

        It 'Should assert expected divergence per row' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match '\| where \(old_matches != new_matches\) != expectedDivergent' -Because 'the harness must return only rows that violate the recorded old-vs-new expectation'
        }

        It 'Should cover an MCA blank offer ID case' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'mca-profile-1' -Because 'the fixture set must exercise the blank-offer-ID case that silently broke MCA reservation pricing (anchored on a fixture literal, not the header comment)'
        }

        It 'Should cover an EA offer ID differentiation case for regression safety' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match 'OFFER-EA-DEVTEST' -Because 'EA already matched before the fix; the fixture set must prove the fix does not regress it, including the case where offer ID legitimately differentiates two rows (anchored on a fixture literal, not the header comment)'
        }
    }
}
