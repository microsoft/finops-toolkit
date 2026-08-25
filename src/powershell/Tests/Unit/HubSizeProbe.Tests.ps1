# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'FinOps Hub size probe' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        function New-TestItem {
            param([string]$Name, [long]$Length, [bool]$IsDirectory = $false)
            [PSCustomObject]@{ Name = $Name; Length = $Length; IsDirectory = $IsDirectory }
        }
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Format-FinOpsByteSize' {
        It 'Formats <Bytes> as <Expected>' -ForEach @(
            @{ Bytes = 512; Expected = '512 bytes' }
            @{ Bytes = 2048; Expected = '2.0 KB' }
            @{ Bytes = 3355443; Expected = '3.2 MB' }
            @{ Bytes = 268435456; Expected = '256.0 MB' }
            @{ Bytes = 44989782425; Expected = '41.9 GB' }
        ) {
            Format-FinOpsByteSize -Bytes $Bytes | Should -Be $Expected
        }
    }

    Context 'Test-FinOpsHubAccessDenied' {
        It 'Treats <Case> as denied' -ForEach @(
            @{ Case = 'AuthorizationFailure'; Message = 'This request is not authorized to perform this operation.' }
            @{ Case = 'explicit 403'; Message = 'Status: 403 (Forbidden)' }
            @{ Case = 'public access disabled'; Message = 'Public access is not permitted on this storage account.' }
        ) {
            Test-FinOpsHubAccessDenied -Message $Message | Should -BeTrue
        }

        It 'Does not treat an ordinary miss as denied' {
            Test-FinOpsHubAccessDenied -Message 'PathNotFound: the specified path does not exist' | Should -BeFalse
            Test-FinOpsHubAccessDenied -Message 'No such host is known.' | Should -BeFalse
        }
    }

    Context 'Get-FinOpsHubSizeClass' {
        It 'Classifies a small hub as not large' {
            $r = Get-FinOpsHubSizeClass -Items @(
                (New-TestItem -Name 'a.parquet' -Length 1MB)
                (New-TestItem -Name 'b.parquet' -Length 2MB)
            )
            $r.Known | Should -BeTrue
            $r.IsLarge | Should -BeFalse
            $r.FileCount | Should -Be 2
            $r.Bytes | Should -Be 3MB
            $r.Display | Should -Be '3.0 MB across 2 file(s)'
        }

        It 'Classifies a hub over the byte threshold as large' {
            $r = Get-FinOpsHubSizeClass -Items @(New-TestItem -Name 'big.parquet' -Length 512MB)
            $r.IsLarge | Should -BeTrue
        }

        It 'Classifies a hub at the file cap as large even when small in bytes' {
            $items = 1..50 | ForEach-Object { New-TestItem -Name "f$_.parquet" -Length 1KB }
            $r = Get-FinOpsHubSizeClass -Items $items -MaxFiles 50
            $r.IsLarge | Should -BeTrue
            $r.Display | Should -Match 'at least'
        }

        It 'Marks a truncated listing as large regardless of measured size' {
            $r = Get-FinOpsHubSizeClass -Items @(New-TestItem -Name 'a.parquet' -Length 1KB) -Truncated
            $r.IsLarge | Should -BeTrue
            $r.Display | Should -Match 'at least'
        }

        It 'Excludes directory entries from the size and count' {
            $r = Get-FinOpsHubSizeClass -Items @(
                (New-TestItem -Name 'folder' -Length 9999 -IsDirectory $true)
                (New-TestItem -Name 'a.parquet' -Length 1MB)
            )
            $r.FileCount | Should -Be 1
            $r.Bytes | Should -Be 1MB
        }

        It 'Handles an empty listing without reporting it large' {
            $r = Get-FinOpsHubSizeClass -Items @()
            $r.FileCount | Should -Be 0
            $r.IsLarge | Should -BeFalse
        }

        It 'Uses the exact threshold boundary' {
            (Get-FinOpsHubSizeClass -Items @(New-TestItem -Name 'a' -Length 256MB)).IsLarge | Should -BeTrue
            (Get-FinOpsHubSizeClass -Items @(New-TestItem -Name 'a' -Length ((256MB) - 1))).IsLarge | Should -BeFalse
        }
    }
}
