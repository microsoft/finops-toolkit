# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for Azure Resource Graph pagination (#2320). ARG caps a response at 1,000 rows and returns
    a $skipToken when more rows exist. The ExecuteQuery pipeline must loop on the token and write one file per page.
#>

Describe 'HubsArgPagination' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $script:bicep = Get-Content -Raw (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceGraph/app.bicep')
    }

    It 'loops until Resource Graph stops returning a skip token' {
        $script:bicep | Should -Match "type: 'Until'"
        $script:bicep | Should -Match '\$skipToken'
    }

    It 'sorts results so paging is stable' {
        $script:bicep | Should -Match 'order by x_RecommendationId'
    }

    It 'writes each page to its own file' {
        $script:bicep | Should -Match "concat\(\\'_\\', variables\(\\'pageNumber\\'\)"
    }

    It 'uses Data Factory variable types' {
        # ADF rejects pipeline runs with "Invalid value for property 'type'" when a variable uses 'Bool' (parameters use 'Bool', variables use 'Boolean')
        $variables = [regex]::Match($script:bicep, "(?s)resource pipeline_ExecuteQuery.*?variables: \{(.*?)\n    \}").Groups[1].Value
        $variables | Should -Not -BeNullOrEmpty
        [regex]::Matches($variables, "type: '(\w+)'").ForEach({ $_.Groups[1].Value }) | Should -BeIn @('String', 'Boolean', 'Array', 'Integer')
    }

    It 'never sets a variable from itself' {
        # ADF fails the run with "Self reference is not supported when updating the value of variable"
        $selfRefs = [regex]::Matches($script:bicep, "(?s)variableName: '(\w+)'\s*value: \{\s*value: '([^\n]*)'") |
            Where-Object { $_.Groups[2].Value -match ("variables\(\\'{0}\\'\)" -f $_.Groups[1].Value) }
        $selfRefs | Should -BeNullOrEmpty
    }
}
