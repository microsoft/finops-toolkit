# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #2177: .alter replaces the whole update policy, so the last
    `.alter table Costs_raw policy update` in IngestionSetup_v1_2.kql must list every source table.
#>

Describe 'Costs_raw update policy (#2177)' {
    BeforeAll {
        $path = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql'
        $text = Get-Content $path -Raw
        $start = $text.LastIndexOf('.alter table Costs_raw policy update')
        $end = $text.IndexOf('}]', $start)
        $script:lastPolicy = $text.Substring($start, $end - $start)
    }

    It 'keeps the <Source> policy in the final Costs_raw update policy' -ForEach @(
        @{ Source = 'ActualCosts_raw'; Query = 'ActualCosts_transform_v1_2()' }
        @{ Source = 'AmortizedCosts_raw'; Query = 'AmortizedCosts_transform_v1_2()' }
    ) {
        $script:lastPolicy | Should -Match ('"Source": "{0}"' -f [regex]::Escape($Source))
        $script:lastPolicy | Should -Match ('"Query": "{0}"' -f [regex]::Escape($Query))
    }
}
