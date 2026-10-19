# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'ConvertTo-NormalizedVersion' {
        It 'Should append .0 to a single-component version' {
            ConvertTo-NormalizedVersion -Version '13' | Should -Be '13.0'
        }

        It 'Should leave "<Version>" unchanged' -ForEach @(
            @{ Version = '0.4' }
            @{ Version = '0.10' }
            @{ Version = '13.0' }
        ) {
            ConvertTo-NormalizedVersion -Version $Version | Should -Be $Version
        }

        It 'Should produce a value that casts to [version]' {
            { [version](ConvertTo-NormalizedVersion -Version '15') } | Should -Not -Throw
            [version](ConvertTo-NormalizedVersion -Version '0.10') | Should -BeGreaterThan ([version]'0.4')
        }
    }
}
