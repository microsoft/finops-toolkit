# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
}

Describe 'AHB workbook tile text' {
    It 'Mentions the 8-core minimum in <_>' -ForEach 'AHB/AHB.workbook', 'Compute/AHB.workbook' {
        $text = Get-Content (Join-Path $script:RepoRoot "src/workbooks/optimization/$_") -Raw
        $text | Should -Match 'at least 8 cores'
    }
}
