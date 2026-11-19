# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Regression coverage for #2384: current FOCUS versions (1.2, 1.2-preview) must not be flagged LegacyFocusVersion.
Describe 'HubsLegacyFocusVersion' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $script:kql = Get-Content -Raw (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql')
    }

    It "Flags only FOCUS 1.0 variants, so 1.2 and newer are never legacy" {
        $script:kql | Should -Match "iff\(x_SourceVersion !startswith .1\.0. and x_SourceVersion != .., x_SourceChanges,"
    }

    It "Does not flag by exempting only 1.0 or only 1.2" {
        $script:kql | Should -Not -Match "iff\(x_SourceVersion (==|startswith) .1\.[02]., x_SourceChanges,"
    }

    It 'Still reports UnknownFocusVersion and LegacyFocusVersion' {
        $script:kql | Should -Match "'UnknownFocusVersion', 'LegacyFocusVersion'"
    }
}
