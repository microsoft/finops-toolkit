# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Validates the Prices_v1_5 price factors mapping (x_PriceFactors, x_FlexPlanProductCode).

    .DESCRIPTION
    The Cost Management 2026-10-01 price sheet adds priceFactors. Each factor can be a JSON object or
    a JSON string. No ADX engine is available in unit tests, so the Flex Plan product code regex is
    pulled from the KQL and run with .NET (the pattern only uses syntax shared with RE2).
#>

Describe 'Prices_v1_5 price factors' {
    BeforeAll {
        $scripts = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $path = Join-Path $scripts 'IngestionSetup_v1_5.kql'
        $kql = if (Test-Path $path) { Get-Content $path -Raw } else { '' }
        $raw = Get-Content (Join-Path $scripts 'IngestionSetup_RawTables.kql') -Raw
    }

    It 'Should define x_PriceFactors as a dynamic column in Prices_final_v1_5' {
        $kql | Should -Match 'x_PriceFactors:\s+dynamic'
        $kql | Should -Match 'x_PriceFactors = parse_json\(PriceFactors\)'
    }

    It 'Should map PriceFactors in Prices_raw' {
        $raw | Should -Match 'PriceFactors:\s+string'
        $raw | Should -Match '"Column": "PriceFactors"'
    }

    It 'Should extract the Flex Plan product code from <_.name> factors' -ForEach @(
        @{ name = 'object'; json = '[{"Factors":[{"Type":"SavingsPlan","Extensions":{"ProductCode":"SP1"}},{"Type":"FlexPlan","Extensions":{"ProductCode":"FLEX123"}}]}]' }
        @{ name = 'string'; json = '[{"Factors":["{\"Type\":\"FlexPlan\",\"Extensions\":{\"ProductCode\":\"FLEX123\"}}"]}]' }
    ) {
        $kql | Should -Match 'x_FlexPlanProductCode = extract\('
        $pattern = [regex]::Match($kql, "extract\(@'([^\r\n]+?)', 1, tostring\(PriceFactors\)\)").Groups[1].Value
        $pattern | Should -Not -BeNullOrEmpty
        [regex]::Match($json, $pattern).Groups[1].Value | Should -Be 'FLEX123'
    }

    It 'Should not read the next factor when a Flex Plan factor has no product code' {
        $pattern = [regex]::Match($kql, "extract\(@'([^\r\n]+?)', 1, tostring\(PriceFactors\)\)").Groups[1].Value
        [regex]::Match('[{"Factors":[{"Type":"FlexPlan","Extensions":{}},{"Type":"SavingsPlan","Extensions":{"ProductCode":"SP1"}}]}]', $pattern).Success | Should -BeFalse
    }

    It 'Should keep Prices() on v1_2 until v1_5 is complete' {
        (Get-Content (Join-Path $scripts 'HubSetup_v1_2.kql') -Raw) | Should -Match '(?s)Prices\(\)\s*\{\s*Prices_v1_2\(\)'
    }

    It 'Should not extract a product code when there is no Flex Plan factor' {
        $pattern = [regex]::Match($kql, "extract\(@'([^\r\n]+?)', 1, tostring\(PriceFactors\)\)").Groups[1].Value
        [regex]::Match('[{"Factors":[{"Type":"SavingsPlan","Extensions":{"ProductCode":"SP1"}}]}]', $pattern).Success | Should -BeFalse
    }
}
