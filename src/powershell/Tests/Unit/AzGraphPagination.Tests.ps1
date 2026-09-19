# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Resource Graph query pagination' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Combines rows from every page when -All is used' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            if (-not $SkipToken) { [PSCustomObject]@{ Data = @('a', 'b'); SkipToken = 'page2'; Count = 2 } }
            elseif ($SkipToken -eq 'page2') { [PSCustomObject]@{ Data = @('c'); SkipToken = $null; Count = 1 } }
        }

        $result = Search-AzGraphSafe -Query 'resources' -All

        $result.Count | Should -Be 3
        @($result.Data) | Should -Be @('a', 'b', 'c')
        $result.SkipToken | Should -BeNullOrEmpty
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 2 -Exactly
    }

    It 'Reads only the first page when -All is not used' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ Data = @('a', 'b'); SkipToken = 'page2'; Count = 2 }
        }

        $result = Search-AzGraphSafe -Query 'resources'

        @($result.Data).Count | Should -Be 2
        $result.SkipToken | Should -Be 'page2'
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 1 -Exactly
    }

    It 'Returns null when the very first page fails' {
        # Callers treat $null as "the query failed", so that contract must survive.
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool { $null }

        $result = Search-AzGraphSafe -Query 'resources' -All

        $result | Should -BeNullOrEmpty
    }

    It 'Warns and keeps partial rows when a later page fails' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            if (-not $SkipToken) { [PSCustomObject]@{ Data = @('a'); SkipToken = 'page2'; Count = 1 } }
            else { $null }
        }

        $warnings = @()
        $result = Search-AzGraphSafe -Query 'resources' -All -WarningVariable warnings -WarningAction SilentlyContinue

        @($result.Data).Count | Should -Be 1
        "$warnings" | Should -Match 'incomplete'
    }

    It 'Stops at MaxPages rather than following an endless token chain' {
        # Each page hands back a token that differs from the one just used, so
        # the cap - not the same-token guard - is what ends the loop.
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            $next = if ($SkipToken) { "$SkipToken+" } else { 'page+' }
            [PSCustomObject]@{ Data = @('row'); SkipToken = $next; Count = 1 }
        }

        $warnings = @()
        $result = Search-AzGraphSafe -Query 'resources' -All -MaxPages 3 -WarningVariable warnings -WarningAction SilentlyContinue

        @($result.Data).Count | Should -Be 3
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 3 -Exactly
        "$warnings" | Should -Match 'incomplete'
    }

    It 'Stops when the continuation token does not advance' {
        # A token that repeats would re-request the page already collected and
        # silently duplicate its rows.
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ Data = @('row'); SkipToken = 'stuck'; Count = 1 }
        }

        $warnings = @()
        $result = Search-AzGraphSafe -Query 'resources' -All -WarningVariable warnings -WarningAction SilentlyContinue

        @($result.Data).Count | Should -Be 2
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 2 -Exactly
        "$warnings" | Should -Match 'same continuation token'
    }

    It 'Starts from a caller-supplied skip token' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ Data = @($SkipToken); SkipToken = $null; Count = 1 }
        }

        $result = Search-AzGraphSafe -Query 'resources' -All -SkipToken 'resume-here'

        @($result.Data)[0] | Should -Be 'resume-here'
    }
}
