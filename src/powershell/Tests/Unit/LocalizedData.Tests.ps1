# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Localized Data' {
        It 'Should import FinOpsToolKit.strings.psd1' {
            $script:LocalizedData | Should -Not -BeNullOrEmpty
        }
    }
}
