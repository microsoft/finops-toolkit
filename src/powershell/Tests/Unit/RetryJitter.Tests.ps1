# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Retry backoff jitter' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Computed backoff' {
        It 'Stays within the equal-jitter band for <Base>s' -ForEach @(
            @{ Base = 2 }
            @{ Base = 10 }
            @{ Base = 30 }
            @{ Base = 60 }
        ) {
            foreach ($i in 1..200) {
                $d = Get-JitteredDelay -BaseSeconds $Base
                $d | Should -BeGreaterOrEqual ($Base / 2)
                $d | Should -BeLessOrEqual $Base
            }
        }

        It 'Never returns a negative delay' {
            Get-JitteredDelay -BaseSeconds 0 | Should -Be 0
            Get-JitteredDelay -BaseSeconds -5 | Should -Be 0
        }

        It 'Actually decorrelates - repeated calls are not all identical' {
            $seen = 1..50 | ForEach-Object { Get-JitteredDelay -BaseSeconds 10 }
            (@($seen | Select-Object -Unique)).Count | Should -BeGreaterThan 1
        }
    }

    Context 'Server-supplied Retry-After' {
        It 'Treats Retry-After as a floor and never sleeps less' {
            foreach ($i in 1..200) {
                $d = Get-JitteredDelay -RetryAfterSeconds 5
                $d | Should -BeGreaterOrEqual 5
                $d | Should -BeLessOrEqual 6
            }
        }

        It 'Clamps a nonsensical negative Retry-After to zero' {
            $d = Get-JitteredDelay -RetryAfterSeconds -10
            $d | Should -BeGreaterOrEqual 0
            $d | Should -BeLessOrEqual 1
        }
    }
}
