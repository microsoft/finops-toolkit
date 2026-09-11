# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Cost Management query pagination' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        function Get-FakeResponse {
            param([int]$StatusCode = 200, [string]$NextLink, [int]$RowCount = 1)
            $rows = @(1..$RowCount | ForEach-Object { , @("/subscriptions/x/r$_", 1.0, 'USD') })
            $payload = @{
                properties = @{
                    columns = @(@{ name = 'ResourceId' }, @{ name = 'Cost' }, @{ name = 'Currency' })
                    rows    = $rows
                }
            }
            if ($NextLink) { $payload.properties.nextLink = $NextLink }
            [PSCustomObject]@{ StatusCode = $StatusCode; Content = ($payload | ConvertTo-Json -Depth 6) }
        }
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Returns the single page when there is no nextLink' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse))
        $pages.Count | Should -Be 1
    }

    It 'Returns nothing when the first response is not 200' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse -StatusCode 403))
        $pages.Count | Should -Be 0
    }

    It 'Returns nothing when the response has no content' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse ([PSCustomObject]@{ StatusCode = 200; Content = $null }))
        $pages.Count | Should -Be 0
    }

    It 'Returns nothing when the response is null' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse ([PSCustomObject]@{ StatusCode = 200; Content = '' }))
        $pages.Count | Should -Be 0
    }

    It 'Tolerates a payload that is not valid JSON rather than throwing' {
        $bad = [PSCustomObject]@{ StatusCode = 200; Content = 'not json at all' }
        $pages = @(Get-CostQueryResponsePage -FirstResponse $bad -WarningAction SilentlyContinue)
        $pages.Count | Should -Be 1
    }

    It 'Preserves the row payload so callers can parse it' {
        $pages = @(Get-CostQueryResponsePage -FirstResponse (Get-FakeResponse -RowCount 3))
        $parsed = $pages[0].Content | ConvertFrom-Json
        @($parsed.properties.rows).Count | Should -Be 3
    }

    Context 'nextLink validation' {
        # nextLink is service-supplied. A relative or malformed value yields an
        # empty PathAndQuery rather than throwing, and a foreign host would be
        # rewritten onto the ARM host, so both are rejected.
        It 'Accepts <Case>' -ForEach @(
            @{ Case = 'an absolute ARM url'; Link = 'https://management.azure.com/subscriptions/x/q?api-version=2023-11-01' }
            @{ Case = 'a rooted relative path'; Link = '/subscriptions/x/q?api-version=2023-11-01' }
        ) {
            Resolve-NextLinkPath -NextLink $Link | Should -Not -BeNullOrEmpty
        }

        It 'Rejects <Case>' -ForEach @(
            @{ Case = 'a foreign host'; Link = 'https://evil.example.com/steal?a=1' }
            @{ Case = 'a non-https scheme'; Link = 'http://management.azure.com/x' }
            @{ Case = 'a malformed value'; Link = 'not a url' }
            @{ Case = 'an empty value'; Link = '' }
            @{ Case = 'a null value'; Link = $null }
        ) {
            Resolve-NextLinkPath -NextLink $Link | Should -BeNullOrEmpty
        }

        It 'Strips the host so the request stays on the ARM endpoint' {
            Resolve-NextLinkPath -NextLink 'https://management.azure.com/subscriptions/x/q?a=1' |
                Should -Be '/subscriptions/x/q?a=1'
        }
    }
}
