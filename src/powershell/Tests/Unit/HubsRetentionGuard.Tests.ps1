# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the settings.json retention guard (#2206):
    Copy-FileToAzureBlob.ps1 unconditionally overwrote retention.ingestion.months / retention.final.months
    with whatever the deploymentScript's Bicep parameters passed in. Bicep always resolves a value for an
    optional parameter (defaulting to 13 if the caller didn't specify one), so the script cannot tell an
    explicit redeploy value from a silently-defaulted one. A redeploy that omitted a previously-customized
    retention value therefore silently reset it to the toolkit default, and the next purge pipeline run
    aged out historical data older than the new (lower) cutoff -- oldest data first.

    The fix: never lower stored retention on redeploy. Growing retention is always safe; shrinking it has a
    destructive, hard-to-reverse consequence (data purge), so the script now takes the max of the stored
    value and the incoming one instead of overwriting unconditionally.
#>

Describe 'HubsRetentionGuard' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/Copy-FileToAzureBlob.ps1'
        $content = Get-Content -Path $scriptPath -Raw
    }

    Context 'Never-shrink guard' {

        It 'Should take the max of stored and incoming ingestion retention' {
            $content | Should -Match '\$json\.retention\.ingestion\.months\s*=\s*\[Math\]::Max\(\$json\.retention\.ingestion\.months,\s*\[Int32\]::Parse\(\$env:ingestionRetentionInMonths\)\)' `
                -Because 'a redeploy that omits an explicit retention value must not silently shrink stored retention and purge historical data (#2206)'
        }

        It 'Should take the max of stored and incoming final retention' {
            $content | Should -Match '\$json\.retention\.final\.months\s*=\s*\[Math\]::Max\(\$json\.retention\.final\.months,\s*\[Int32\]::Parse\(\$env:finalRetentionInMonths\)\)' `
                -Because 'a redeploy that omits an explicit retention value must not silently shrink stored retention and purge historical data (#2206)'
        }

        It 'Should not unconditionally overwrite ingestion retention' {
            $content | Should -Not -Match '\$json\.retention\.ingestion\.months\s*=\s*\[Int32\]::Parse\(\$env:ingestionRetentionInMonths\)\s*$' `
                -Because 'a direct assignment (rather than a max guard) was the source of the #2206 regression'
        }

        It 'Should not unconditionally overwrite final retention' {
            $content | Should -Not -Match '\$json\.retention\.final\.months\s*=\s*\[Int32\]::Parse\(\$env:finalRetentionInMonths\)\s*$' `
                -Because 'a direct assignment (rather than a max guard) was the source of the #2206 regression'
        }
    }

    Context 'First-run behavior unchanged' {

        It 'Should still seed ingestion retention from the parameter when no retention object exists yet' {
            $content | Should -Match 'Add-Member -Name ingestion -Value \(ConvertFrom-Json "\{""months"":\$\(\$env:ingestionRetentionInMonths\)\}"\)' `
                -Because 'a brand-new settings.json has no stored value to protect, so the first deploy must still honor the requested retention'
        }

        It 'Should still seed final retention from the parameter when no retention object exists yet' {
            $content | Should -Match 'Add-Member -Name final -Value \(ConvertFrom-Json "\{""months"":\$\(\$env:finalRetentionInMonths\)\}"\)' `
                -Because 'a brand-new settings.json has no stored value to protect, so the first deploy must still honor the requested retention'
        }
    }
}
