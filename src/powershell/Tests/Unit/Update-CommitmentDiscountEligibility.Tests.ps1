# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Unit tests for the pure guard/shard-list helpers in
# src/scripts/Update-CommitmentDiscountEligibility.ps1. That script runs top to bottom
# (and calls the live Azure Retail Prices API) when dot-sourced, so rather than execute
# it we extract just the function definitions via the AST and evaluate those in isolation.

Describe 'Update-CommitmentDiscountEligibility helpers' {
    BeforeAll {
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/Update-CommitmentDiscountEligibility.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        foreach ($name in 'Get-ShardShortfall', 'Add-BaselineShard', 'Get-ServiceFamily', 'Assert-DiscoveryConverged')
        {
            $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Function $name not found in $scriptPath" }
            . ([scriptblock]::Create($fn.Extent.Text))
        }
    }

    Context 'Get-ShardShortfall' {
        It 'flags a previously-nonempty family that vanishes (drops to zero)' {
            $v = Get-ShardShortfall -Section 'Reservation' -Current @{ Compute = 100 } -Baseline @{ Compute = 100; Tiny = 1 } -MaxShrinkFraction 0.15
            @($v) | Should -HaveCount 1
            $v | Should -Match 'Tiny'
        }

        It 'flags a shard that shrinks beyond the tolerance' {
            $v = Get-ShardShortfall -Section 'Reservation' -Current @{ Compute = 80 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            @($v) | Should -HaveCount 1
        }

        It 'passes a shard within tolerance' {
            $v = Get-ShardShortfall -Section 'Reservation' -Current @{ Compute = 90 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }

        It 'does not flag a brand-new family absent from the baseline' {
            $v = Get-ShardShortfall -Section 'Reservation' -Current @{ Compute = 100; New = 5 } -Baseline @{ Compute = 100 } -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }

        It 'returns nothing when there is no baseline' {
            $v = Get-ShardShortfall -Section 'Reservation' -Current @{ Compute = 1 } -Baseline $null -MaxShrinkFraction 0.15
            $v | Should -BeNullOrEmpty
        }
    }

    Context 'Add-BaselineShard' {
        It 'unions discovered families with the baseline families' {
            $u = Add-BaselineShard -Discovered ([string[]]@('Compute', 'Analytics')) -BaselineSection @{ Compute = 1; Tiny = 1 }
            $u | Should -Contain 'Tiny'
            $u | Should -Contain 'Analytics'
            $u | Should -Contain 'Compute'
        }

        It 'de-duplicates families present in both sets' {
            $u = Add-BaselineShard -Discovered ([string[]]@('Compute', 'Compute')) -BaselineSection @{ Compute = 1 }
            @($u | Where-Object { $_ -eq 'Compute' }).Count | Should -Be 1
        }

        It 'is null-safe when no baseline exists' {
            $u = Add-BaselineShard -Discovered ([string[]]@('A', 'B')) -BaselineSection $null
            $u | Should -HaveCount 2
        }
    }

    Context 'Get-ServiceFamily' {
        # Get-ServiceFamily calls Get-RetailPriceSegment, which hits the live API. Stub it
        # in the test scope so each "traversal" replays a scripted page of items instead.
        # $script:pages is the per-pass item list; $script:passLog records the passes made.
        BeforeEach {
            $script:passLog = 0
            function Get-RetailPriceSegment
            {
                # Filter/MeterRegion are part of the real signature but irrelevant to the
                # stub, which replays scripted pages. Target must be empty to suppress on
                # PSScriptAnalyzer 1.x (naming the parameter does not work).
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
                    Justification = 'Stub mirrors the real Get-RetailPriceSegment signature; only OnItem is exercised')]
                param($Filter, $MeterRegion, $OnItem)
                $script:passLog++
                $items = if ($script:pages.Count -ge $script:passLog) { $script:pages[$script:passLog - 1] } else { $script:pages[-1] }
                foreach ($i in $items) { & $OnItem $i }
                return @{ Items = @($items).Count; Pages = $script:pagesPerPass }
            }
        }

        It 'includes a new one-item family that only a later discovery pass sees' {
            # Pass 1 misses 'Tiny' entirely (the unstable page order dropped its only row);
            # passes 2+ see it. The unioned shard list must still contain it -- this is the
            # case Add-BaselineShard cannot cover, because a brand-new family is in no baseline.
            $script:pagesPerPass = 5
            $script:pages = @(
                @( @{ serviceFamily = 'Compute' }, @{ serviceFamily = 'Storage' } ),
                @( @{ serviceFamily = 'Compute' }, @{ serviceFamily = 'Storage' }, @{ serviceFamily = 'Tiny' } )
            )

            $r = Get-ServiceFamily -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -MaxPasses 4 -StablePasses 2

            $r.Families | Should -Contain 'Tiny'
            $r.Families | Should -HaveCount 3
            $r.Converged | Should -BeTrue
        }

        It 'reports non-convergence when every pass keeps adding families' {
            # A family set that never stabilizes means discovery cannot be trusted to be
            # complete, so the caller must refuse to publish rather than guess.
            $script:pagesPerPass = 5
            $script:pages = @(
                @( @{ serviceFamily = 'A' } ),
                @( @{ serviceFamily = 'B' } ),
                @( @{ serviceFamily = 'C' } ),
                @( @{ serviceFamily = 'D' } )
            )

            $r = Get-ServiceFamily -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -MaxPasses 4 -StablePasses 2

            $r.Converged | Should -BeFalse
            $r.Families | Should -HaveCount 4
            $script:passLog | Should -Be 4   # stopped at the cap, did not spin
        }

        It 'stops after one pass when the scan fit in a single response' {
            # No NextPageLink means the scan was complete and deterministic; repeating it
            # would only burn API calls.
            $script:pagesPerPass = 1
            $script:pages = @( , @( @{ serviceFamily = 'Compute' } ) )

            $r = Get-ServiceFamily -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -MaxPasses 4 -StablePasses 2

            $script:passLog | Should -Be 1
            $r.Converged | Should -BeTrue
            $r.Families | Should -Contain 'Compute'
        }

        It 'converges without exhausting the cap when the family set is stable' {
            $script:pagesPerPass = 5
            $script:pages = @( , @( @{ serviceFamily = 'Compute' }, @{ serviceFamily = 'Storage' } ) )

            $r = Get-ServiceFamily -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -MaxPasses 4 -StablePasses 2

            $r.Converged | Should -BeTrue
            $script:passLog | Should -Be 3   # pass 1 adds, passes 2-3 add nothing
            $r.Families | Should -HaveCount 2
        }

        It 'ignores items with no serviceFamily' {
            $script:pagesPerPass = 5
            $script:pages = @( , @( @{ serviceFamily = 'Compute' }, @{ serviceFamily = $null } ) )

            $r = Get-ServiceFamily -Filter 'x' -MeterRegion 'primary' -ActivityName 'test' -MaxPasses 4 -StablePasses 2

            $r.Families | Should -HaveCount 1
        }
    }

    Context 'Assert-DiscoveryConverged' {
        It 'throws when discovery did not converge' {
            { Assert-DiscoveryConverged -Discovery @{ Converged = $false } -PriceType 'Reservation' -MaxPasses 4 } |
                Should -Throw -ExpectedMessage '*Reservation serviceFamily discovery did not converge*'
        }

        It 'passes when discovery converged' {
            { Assert-DiscoveryConverged -Discovery @{ Converged = $true } -PriceType 'Consumption' -MaxPasses 4 } |
                Should -Not -Throw
        }
    }
}
