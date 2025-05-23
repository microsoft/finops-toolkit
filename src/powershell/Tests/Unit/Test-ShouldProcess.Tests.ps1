# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Test-ShouldProcess' {
        BeforeAll {
            function testShouldProcessCheck
            {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
                [CmdletBinding(SupportsShouldProcess)]
                param ()

                return (Test-ShouldProcess $PSCmdlet 'Target' 'Action')
            }
        }

        It 'Should not call script block when WhatIf is specified' {
            # Arrange
            # Act
            $actual = testShouldProcessCheck -WhatIf

            # Assert
            $actual | Should -Be $false
        }

        It 'Should call script block when WhatIf is not specified' {
            # Arrange
            # Act
            $actual = testShouldProcessCheck

            # Assert
            $actual | Should -Be $true
        }
    }
}
