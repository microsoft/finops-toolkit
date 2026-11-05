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
}
