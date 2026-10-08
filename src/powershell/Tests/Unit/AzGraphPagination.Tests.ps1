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

    It 'Rejects an incomplete first page when all rows were requested' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool { $null }

        { Search-AzGraphSafe -Query 'resources' -All } | Should -Throw '*incomplete*'
    }

    It 'Rejects a full page without a continuation token' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [pscustomobject]@{ Data = @('a', 'b'); SkipToken = $null; Count = 2 }
        }

        $returned = [Collections.Generic.List[object]]::new()
        { Search-AzGraphSafe -Query 'resources' -First 2 -All | ForEach-Object { $returned.Add($_) } } | Should -Throw '*full page*incomplete*'

        $returned.Count | Should -Be 0
    }

    It 'Retains a resource ID for <Scan> pagination' -ForEach @(
        @{ Scan = 'Get-IdleVMs' }
        @{ Scan = 'Get-StorageTierAdvice' }
    ) {
        Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
            $Query | Should -Match '\|\s*project\s+id\s*,'
            throw 'Projection checked before scanning.'
        }

        { & $Scan -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) } | Should -Throw '*Projection checked*'
        Should -Invoke Search-AzGraphSafe -ModuleName FinOpsMultitool -Times 1 -Exactly
    }

    It 'Retains a resource ID in every <Scan> inventory query' -ForEach @(
        @{ Scan = 'Get-AHBOpportunities'; ExpectedQueries = 3 }
        @{ Scan = 'Get-LegacyResources'; ExpectedQueries = 5 }
    ) {
        Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
            $Query | Should -Match '\|\s*project\s+id\s*,'
            [pscustomobject]@{ Data = @(); SkipToken = $null; Count = 0 }
        }

        & $Scan -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) | Out-Null
        Should -Invoke Search-AzGraphSafe -ModuleName FinOpsMultitool -Times $ExpectedQueries -Exactly
    }

    It 'Accepts a measured empty page with the smallest page size' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [pscustomobject]@{ Data = @(); SkipToken = $null; Count = 0 }
        }

        $result = Search-AzGraphSafe -Query 'resources' -First 1 -All

        $result.Count | Should -Be 0
    }

    It 'Rejects a failed continuation without emitting partial rows' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            if (-not $SkipToken) { [PSCustomObject]@{ Data = @('a'); SkipToken = 'page2'; Count = 1 } }
            else { $null }
        }

        $returned = [Collections.Generic.List[object]]::new()
        { Search-AzGraphSafe -Query 'resources' -All | ForEach-Object { $returned.Add($_) } } | Should -Throw '*incomplete*'

        $returned.Count | Should -Be 0
    }

    It 'Stops at MaxPages rather than following an endless token chain' {
        # Each page hands back a token that differs from the one just used, so
        # the cap - not the same-token guard - is what ends the loop.
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            $next = if ($SkipToken) { "$SkipToken+" } else { 'page+' }
            [PSCustomObject]@{ Data = @('row'); SkipToken = $next; Count = 1 }
        }

        $returned = [Collections.Generic.List[object]]::new()
        { Search-AzGraphSafe -Query 'resources' -All -MaxPages 3 | ForEach-Object { $returned.Add($_) } } | Should -Throw '*incomplete*'

        $returned.Count | Should -Be 0
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 3 -Exactly
    }

    It 'Stops when the continuation token does not advance' {
        # A token that repeats would re-request the page already collected and
        # silently duplicate its rows.
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ Data = @('row'); SkipToken = 'stuck'; Count = 1 }
        }

        $returned = [Collections.Generic.List[object]]::new()
        { Search-AzGraphSafe -Query 'resources' -All | ForEach-Object { $returned.Add($_) } } | Should -Throw '*continuation token*incomplete*'

        $returned.Count | Should -Be 0
        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 2 -Exactly
    }

    It 'Rejects a cyclic continuation chain without returning repeated pages' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            $next = if ($SkipToken -eq 'page2') { 'page3' } else { 'page2' }
            [PSCustomObject]@{ Data = @('row'); SkipToken = $next; Count = 1 }
        }

        { Search-AzGraphSafe -Query 'resources' -All } | Should -Throw '*continuation token*incomplete*'

        Should -Invoke Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool -Times 3 -Exactly
    }

    It 'Keeps incomplete inventory visible through <Scan>' -ForEach @(
        @{ Scan = 'Get-StorageTierAdvice' }
        @{ Scan = 'Get-IdleVMs' }
        @{ Scan = 'Get-OrphanedResources' }
        @{ Scan = 'Get-LegacyResources' }
        @{ Scan = 'Get-AHBOpportunities' }
        @{ Scan = 'Get-UnitEconomics' }
        @{ Scan = 'Get-AIWorkloadMetrics' }
    ) {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            if (-not $SkipToken) { [pscustomobject]@{ Data = @('partial'); SkipToken = 'next'; Count = 1 } }
            else { $null }
        }
        Mock Get-PlainAccessToken -ModuleName FinOpsMultitool { throw 'Credentials must not be requested after inventory fails.' }
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool { throw 'Network requests are prohibited in this test.' }
        $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

        $parameters = @{ Subscriptions = $subscriptions }
        if ((Get-Command $Scan).Parameters.ContainsKey('TenantId')) { $parameters.TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
        { & $Scan @parameters } | Should -Throw '*incomplete*'

        Should -Invoke Get-PlainAccessToken -ModuleName FinOpsMultitool -Times 0 -Exactly
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 0 -Exactly
    }

    It 'Starts from a caller-supplied skip token' {
        Mock Invoke-AzGraphQueryPage -ModuleName FinOpsMultitool {
            [PSCustomObject]@{ Data = @($SkipToken); SkipToken = $null; Count = 1 }
        }

        $result = Search-AzGraphSafe -Query 'resources' -All -SkipToken 'resume-here'

        @($result.Data)[0] | Should -Be 'resume-here'
    }
}
