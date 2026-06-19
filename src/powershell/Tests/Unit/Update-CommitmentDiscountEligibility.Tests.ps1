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
        foreach ($name in 'Get-ShardShortfall', 'Add-BaselineShard')
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
}
