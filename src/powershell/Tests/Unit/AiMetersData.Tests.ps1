# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'AiMeters open data' {
    It 'is skipped by Build-OpenData -PowerShell' {
        $build = Get-Content "$PSScriptRoot/../../../scripts/Build-OpenData.ps1" -Raw
        $build | Should -Match "\`$skipPowerShell\s*=\s*@\('AiMeters'\)"
        $build | Should -Match '\$_\.BaseName -notin \$skipPowerShell'
        Test-Path "$PSScriptRoot/../../Private/Get-OpenDataAiMeter.ps1" | Should -BeFalse
    }
}
