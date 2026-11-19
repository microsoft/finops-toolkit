# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Regression coverage for #2384: current FOCUS versions (1.2, 1.2-preview) must not be flagged LegacyFocusVersion.
Describe 'HubsLegacyFocusVersion' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $script:kql = Get-Content -Raw (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql')
    }

    It 'Skips the legacy flag for FOCUS 1.2 and 1.2-preview' {
        $script:kql | Should -Match "iff\(x_SourceVersion startswith '1\.2', x_SourceChanges,"
    }

    It 'Does not treat only 1.0 as exempt from the legacy flag' {
        $script:kql | Should -Not -Match "iff\(x_SourceVersion == '1\.0', x_SourceChanges,"
    }

    It 'Still reports UnknownFocusVersion and LegacyFocusVersion' {
        $script:kql | Should -Match "'UnknownFocusVersion', 'LegacyFocusVersion'"
    }
}
