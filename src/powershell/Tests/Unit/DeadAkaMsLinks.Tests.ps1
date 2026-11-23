# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
}

Describe 'Dead aka.ms shortcuts' {
    It 'Does not use aka.ms/ftk/pbi/invoicing in Power BI reports' {
        $hits = Get-ChildItem (Join-Path $script:RepoRoot 'src/power-bi') -Recurse -Filter report.json |
            Select-String -Pattern 'aka\.ms/ftk/pbi/invoicing'
        $hits | Should -BeNullOrEmpty
    }

    It 'Does not use aka.ms/ftk/tsg in the workbooks README' {
        Join-Path $script:RepoRoot 'src/templates/finops-workbooks/README.md' | Should -Not -FileContentMatch 'aka\.ms/ftk/tsg'
    }
}
