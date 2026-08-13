# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Unit tests for the pure helpers in
# src/scripts/Update-CommitmentDiscountEligibility.ps1. That script runs top to bottom
# (and calls the live Azure Retail Prices API) when dot-sourced, so rather than execute
# it we extract just the function definitions via the AST and evaluate those in isolation.

Describe 'Update-CommitmentDiscountEligibility helpers' {
    BeforeAll {
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/Update-CommitmentDiscountEligibility.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        foreach ($name in 'Get-FamilyShortfall', 'Get-RetryDelay', 'Get-EligibleMeter', 'ConvertTo-SortedMap')
        {
            $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Function $name not found in $scriptPath" }
            . ([scriptblock]::Create($fn.Extent.Text))
        }
    }

    Context 'ConvertTo-SortedMap' {
        It 'orders entries by key' {
            $m = ConvertTo-SortedMap -Map @{ Storage = 3; Compute = 1; Analytics = 2 }
            @($m.Keys) | Should -Be @('Analytics', 'Compute', 'Storage')
        }

        It 'preserves every value' {
            $m = ConvertTo-SortedMap -Map @{ Storage = 3; Compute = 1 }
            $m['Compute'] | Should -Be 1
            $m['Storage'] | Should -Be 3
        }

        It 'serializes identically regardless of insertion order' {
            # The actual regression: the workflow treats any diff in the baseline sidecar
            # as "data changed", so an unstable key order would push a branch and ask for
            # a PR even when no count moved.
            $a = [ordered]@{}
            'Storage', 'Compute', 'Analytics' | ForEach-Object { $a[$_] = 1 }
            $b = [ordered]@{}
            'Analytics', 'Storage', 'Compute' | ForEach-Object { $b[$_] = 1 }

            $jsonA = ConvertTo-SortedMap -Map ([hashtable]$a) | ConvertTo-Json -Depth 4
            $jsonB = ConvertTo-SortedMap -Map ([hashtable]$b) | ConvertTo-Json -Depth 4

            $jsonA | Should -BeExactly $jsonB
        }

        It 'handles an empty map' {
            $m = ConvertTo-SortedMap -Map @{}
            $m.Count | Should -Be 0
        }

        It 'sorts family names containing spaces and symbols' {
            # Real family names include 'AI + Machine Learning' and 'Management and Governance'.
            $m = ConvertTo-SortedMap -Map @{ 'Management and Governance' = 1; 'AI + Machine Learning' = 82 }
            @($m.Keys)[0] | Should -Be 'AI + Machine Learning'
        }
    }

    Context 'Get-FamilyShortfall' {
        It 'flags a previously-nonempty family that vanishes (drops to zero)' {
            $v = Get-FamilyShortfall -Section 'Reservation' -Current @{ Compute = 100 } -Baseline @{ Compute = 100; Tiny = 1 } -MaxShrinkFraction 0.15
            @($v) | Should -HaveCount 1
            $v | Should -Match 'Tiny'
        }

        It 'flags a family that shrinks beyond the tolerance' {
            $v = Get-FamilyShortfall -Section 'Reservation' -Current @{ Compute = 80 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            @($v) | Should -HaveCount 1
        }

        It 'passes a family within tolerance' {
            $v = Get-FamilyShortfall -Section 'Reservation' -Current @{ Compute = 90 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }

        It 'does not flag a brand-new family absent from the baseline' {
            $v = Get-FamilyShortfall -Section 'Reservation' -Current @{ Compute = 100; New = 5 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }

        It 'returns nothing when there is no baseline' {
            $v = Get-FamilyShortfall -Section 'Reservation' -Current @{ Compute = 1 } -Baseline $null -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }
    }

    Context 'Get-RetryDelay' {
        # Builds a real HttpResponseMessage -- the same type Invoke-RestMethod surfaces on
        # $_.Exception.Response -- so these tests exercise the actual header plumbing
        # rather than a hand-rolled stand-in.
        BeforeAll {
            function Get-TestResponse
            {
                param([string]$RetryAfter)
                $r = [System.Net.Http.HttpResponseMessage]::new(429)
                if ($RetryAfter) { $null = $r.Headers.TryAddWithoutValidation('Retry-After', $RetryAfter) }
                return $r
            }
        }

        It 'honors a delta-seconds Retry-After' {
            # Regression guard for the original bug: the header was read via
            # $Response.Headers['Retry-After'], but HttpResponseHeaders has no string
            # indexer, so that silently yielded $null and every 429 fell through to the
            # exponential backoff. A returned 30 (not the attempt-1 fallback of 20)
            # proves the header is genuinely being read.
            Get-RetryDelay -Response (Get-TestResponse -RetryAfter '30') -Attempt 1 | Should -Be 30
        }

        It 'honors the HTTP-date form of Retry-After' {
            $when = [DateTimeOffset]::UtcNow.AddSeconds(120).ToString('r')
            $delay = Get-RetryDelay -Response (Get-TestResponse -RetryAfter $when) -Attempt 1
            # Second-resolution formatting plus test execution time make this approximate.
            $delay | Should -BeGreaterThan 110
            $delay | Should -BeLessOrEqual 121
        }

        It 'clamps an outsized Retry-After to MaxSeconds' {
            Get-RetryDelay -Response (Get-TestResponse -RetryAfter '99999') -Attempt 1 -MaxSeconds 300 | Should -Be 300
        }

        It 'falls back to exponential backoff when the header is absent' {
            Get-RetryDelay -Response (Get-TestResponse) -Attempt 1 | Should -Be 20
            Get-RetryDelay -Response (Get-TestResponse) -Attempt 3 | Should -Be 80
        }

        It 'falls back to exponential backoff when there is no response at all' {
            # Network/DNS/timeout errors surface with a null .Response.
            Get-RetryDelay -Response $null -Attempt 2 | Should -Be 40
        }

        It 'falls back to exponential backoff for an HTTP-date already in the past' {
            # A stale date must not produce a zero/negative wait and busy-loop the retry.
            $past = [DateTimeOffset]::UtcNow.AddSeconds(-60).ToString('r')
            Get-RetryDelay -Response (Get-TestResponse -RetryAfter $past) -Attempt 1 | Should -Be 20
        }
    }

    Context 'Get-EligibleMeter' {
        # Get-EligibleMeter calls Get-RetailPriceSegment, which hits the live API. Stub it
        # in the test scope so the "traversal" replays a scripted list of items instead.
        BeforeEach {
            function Get-RetailPriceSegment
            {
                # Filter/MeterRegion are part of the real signature but irrelevant to the
                # stub, which replays scripted items. Target must be empty to suppress on
                # PSScriptAnalyzer 1.x (naming the parameter does not work).
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
                    Justification = 'Stub mirrors the real Get-RetailPriceSegment signature; only OnItem is exercised')]
                param($Filter, $MeterRegion, $OnItem)
                foreach ($i in $script:items) { & $OnItem $i }
                return @{ Items = @($script:items).Count; Pages = 1 }
            }

            $script:allMeters = { param($item) $item.meterId }
        }

        It 'collects meter ids and counts them per service family' {
            $script:items = @(
                @{ meterId = 'm1'; serviceFamily = 'Compute' },
                @{ meterId = 'm2'; serviceFamily = 'Compute' },
                @{ meterId = 'm3'; serviceFamily = 'Storage' }
            )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey $script:allMeters

            $r.Keys.Count | Should -Be 3
            $r.FamilyCounts['Compute'] | Should -Be 2
            $r.FamilyCounts['Storage'] | Should -Be 1
            $r.Items | Should -Be 3
        }

        It 'lower-cases collected meter ids so the CSV and guard compare consistently' {
            $script:items = @( @{ meterId = 'AbC-123'; serviceFamily = 'Compute' } )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey $script:allMeters

            $r.Keys.ContainsKey('abc-123') | Should -BeTrue
        }

        It 'counts a meter id seen twice in one family only once' {
            $script:items = @(
                @{ meterId = 'm1'; serviceFamily = 'Compute' },
                @{ meterId = 'm1'; serviceFamily = 'Compute' }
            )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey $script:allMeters

            $r.Keys.Count | Should -Be 1
            $r.FamilyCounts['Compute'] | Should -Be 1
        }

        It 'records a family that collects nothing as 0 rather than dropping it' {
            # The sharded implementation persisted an explicit 0 for such a family; the
            # baseline must keep doing so, otherwise a family whose meters all disappear
            # looks like a brand-new family to the guard instead of a 100% shortfall.
            $script:items = @(
                @{ meterId = 'm1'; serviceFamily = 'Compute'; savingsPlan = @(1) },
                @{ meterId = 'm2'; serviceFamily = 'Analytics'; savingsPlan = @() }
            )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey {
                param($item)
                if ($item.savingsPlan -and $item.savingsPlan.Count -gt 0) { $item.meterId } else { $null }
            }

            $r.Keys.Count | Should -Be 1
            $r.FamilyCounts['Compute'] | Should -Be 1
            $r.FamilyCounts.ContainsKey('Analytics') | Should -BeTrue
            $r.FamilyCounts['Analytics'] | Should -Be 0
        }

        It 'buckets items with no service family under (none)' {
            $script:items = @( @{ meterId = 'm1'; serviceFamily = $null } )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey $script:allMeters

            $r.FamilyCounts['(none)'] | Should -Be 1
        }

        It 'returns the page count from the underlying traversal' {
            $script:items = @( @{ meterId = 'm1'; serviceFamily = 'Compute' } )

            $r = Get-EligibleMeter -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -CollectKey $script:allMeters

            $r.Pages | Should -Be 1
        }
    }
}
