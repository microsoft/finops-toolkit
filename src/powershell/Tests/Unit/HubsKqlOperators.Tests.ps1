# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the string operator conventions in hub KQL (#2213 / PR #2220):

    1. tolower() must never appear in comparison position — KQL comparison operators are case-insensitive
       (use =~, !~, has, in~; append _cs for case-sensitive matching).
    2. contains is reserved for genuine substring matching (needle may be fused inside a larger token).
       Every usage must be listed in the allowlist below with a justification.
    3. The sites converted from contains to has stay converted (operator pins).
    4. Every pinned needle has per-row fixtures in the executable equivalence harness
       (Tests/assets/StringOperatorEquivalence.kql), which verifies old-vs-new behavior row by row,
       including the whole-term vs. substring boundary cases, on any Kusto database.
#>

Describe 'HubsKqlOperators' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $kqlDirs = @(
            (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'),
            (Join-Path $repoRoot 'src/queries/catalog')
        )
        $kqlFiles = @($kqlDirs | ForEach-Object { Get-ChildItem -Path $_ -Filter '*.kql' -ErrorAction SilentlyContinue } | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName }
            })

        # Sites converted from contains/tolower() to case-insensitive term operators.
        # Each entry pins the literal expression so a future edit cannot silently regress the operator choice.
        $operatorPins = @(
            @{ File = 'IngestionSetup_HubInfra.kql'; Literal = "!has '/providers/'";                                                        Needle = '/providers/' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "has '/microsoft.capacity/reservationorders/'";                              Needle = '/microsoft.capacity/reservationorders/' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "has '/microsoft.billingbenefits/savingsplanorders/'";                       Needle = '/microsoft.billingbenefits/savingsplanorders/' }
            @{ File = 'IngestionSetup_v1_0.kql';     Literal = "has '/microsoft.capacity/reservationorders/'";                              Needle = '/microsoft.capacity/reservationorders/' }
            @{ File = 'IngestionSetup_v1_2.kql';     Literal = "has '/microsoft.capacity/reservationorders/'";                              Needle = '/microsoft.capacity/reservationorders/' }
            @{ File = 'IngestionSetup_v1_0.kql';     Literal = "!has '/'";                                                                  Needle = '/' }
            @{ File = 'IngestionSetup_v1_2.kql';     Literal = "!has '/'";                                                                  Needle = '/' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "has 'Windows Server BYOL'";                                                 Needle = 'Windows Server BYOL' }
            @{ File = 'costs-enriched-base.kql';     Literal = "has 'Windows Server BYOL'";                                                 Needle = 'Windows Server BYOL' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "has 'Azure Hybrid Benefit'";                                                Needle = 'Azure Hybrid Benefit' }
            @{ File = 'IngestionSetup_v1_2.kql';     Literal = "has 'Azure Hybrid Benefit'";                                                Needle = 'Azure Hybrid Benefit' }
            @{ File = 'costs-enriched-base.kql';     Literal = "has 'Azure Hybrid Benefit'";                                                Needle = 'Azure Hybrid Benefit' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "has 'Windows'";                                                             Needle = 'Windows' }
            @{ File = 'IngestionSetup_v1_2.kql';     Literal = "has 'Windows'";                                                             Needle = 'Windows' }
            @{ File = 'costs-enriched-base.kql';     Literal = "has 'Windows'";                                                             Needle = 'Windows' }
            @{ File = 'costs-enriched-base.kql';     Literal = "has 'Trial'";                                                               Needle = 'Trial' }
            @{ File = 'costs-enriched-base.kql';     Literal = "has 'Preview'";                                                             Needle = 'Preview' }
            @{ File = 'ai-token-usage-breakdown.kql'; Literal = 'has "Input"';                                                              Needle = 'Input' }
            @{ File = 'ai-token-usage-breakdown.kql'; Literal = 'has "Output"';                                                             Needle = 'Output' }
            @{ File = 'HubSetup_v1_2.kql';           Literal = "=~ 'microsoft.compute/capacityreservationgroups/capacityreservations'";     Needle = 'microsoft.compute/capacityreservationgroups/capacityreservations' }
            @{ File = 'IngestionSetup_v1_2.kql';     Literal = "=~ 'microsoft.compute/capacityreservationgroups/capacityreservations'";     Needle = 'microsoft.compute/capacityreservationgroups/capacityreservations' }
            @{ File = 'costs-enriched-base.kql';     Literal = "x_SkuDetails.AHB =~ 'true'";                                                Needle = 'AHB' }
        )
        # Resolve pin file names to full paths
        $pinsByPath = @{}
        foreach ($f in $kqlFiles) { $pinsByPath[$f.Name] = $f.FullName }
        $operatorPins = @($operatorPins | ForEach-Object { $_.FullName = $pinsByPath[$_.File]; $_ })

        $pinnedNeedles = @($operatorPins | ForEach-Object { $_.Needle } | Sort-Object -Unique | ForEach-Object { @{ Needle = $_ } })
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $harnessPath = Join-Path $repoRoot 'src/powershell/Tests/assets/StringOperatorEquivalence.kql'
        $kqlFileCount = @(
            (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'),
            (Join-Path $repoRoot 'src/queries/catalog')
        ) | ForEach-Object { Get-ChildItem -Path $_ -Filter '*.kql' -ErrorAction SilentlyContinue } | Measure-Object | Select-Object -ExpandProperty Count

        # contains is only allowed where the needle may be fused inside a larger token (substring semantics required).
        # To add an entry: prove the substring requirement, add per-row fixtures to StringOperatorEquivalence.kql,
        # run the harness against a Kusto database, and document the justification here.
        $containsAllowlist = @(
            # ConsumedUnit carries fused unit forms (e.g. 'Mbps'); has would not match them and the needles are
            # below the 3-character term index minimum anyway, so has offers no benefit here.
            @{ File = 'storage-tier-distribution.kql'; Needle = 'PB' }
            @{ File = 'storage-tier-distribution.kql'; Needle = 'TB' }
            @{ File = 'storage-tier-distribution.kql'; Needle = 'MB' }
        )
    }

    Context 'Case-insensitive comparisons' {

        It 'Should have at least one KQL file' {
            $kqlFileCount | Should -BeGreaterThan 0
        }

        It 'Should not use tolower() in comparison position: <Name>' -ForEach $kqlFiles {
            $content = Get-Content -Path $FullName -Raw
            $leftSide = [regex]::Matches($content, "tolower\([^)]*\)\s*(==|!=|=~|!~|!?contains(_cs)?|!?has(_cs)?|startswith|endswith)")
            $rightSide = [regex]::Matches($content, "(==|!=|=~|!~|!?contains(_cs)?|!?has(_cs)?|startswith|endswith)\s*tolower\(")
            @($leftSide).Count + @($rightSide).Count | Should -Be 0 -Because ("KQL comparison operators are already case-insensitive; use =~, !~, has, or in~ instead of tolower() (see #2213). Found: " + (@($leftSide + $rightSide | ForEach-Object { $_.Value }) -join '; '))
        }
    }

    Context 'contains allowlist' {

        It 'Should only use contains for substring semantics: <Name>' -ForEach $kqlFiles {
            $content = Get-Content -Path $FullName -Raw
            $usages = [regex]::Matches($content, "!?contains(?:_cs)?\s+['`"](?<needle>[^'`"]*)['`"]")
            $violations = @($usages | Where-Object {
                    $needle = $_.Groups['needle'].Value
                    -not ($containsAllowlist | Where-Object { $_.File -eq $Name -and $_.Needle -eq $needle })
                })
            @($violations).Count | Should -Be 0 -Because ("contains scans every row for an arbitrary substring; use has for whole terms and phrases. If substring matching is genuinely required (needle can be fused inside a larger token), add per-row fixtures to Tests/assets/StringOperatorEquivalence.kql and extend the allowlist in this test. Found: " + (@($violations | ForEach-Object { $_.Value }) -join '; '))
        }
    }

    Context 'Operator pins' {

        It 'Should keep <Literal> in <File>' -ForEach $operatorPins {
            $content = Get-Content -Path $FullName -Raw
            $content.Contains($Literal) | Should -BeTrue -Because "the expression `"$Literal`" was validated per-row for #2213/PR #2220; if this site changed intentionally, re-run Tests/assets/StringOperatorEquivalence.kql against a Kusto database and update the pin"
        }
    }

    Context 'Equivalence harness' {

        It 'Should have the equivalence harness asset' {
            Test-Path $harnessPath | Should -BeTrue
        }

        It 'Should assert expected divergence per row' {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness | Should -Match '\| where \(old_result != new_result\) != expectedDivergent' -Because 'the harness must return only rows that violate the recorded old-vs-new expectation'
        }

        It 'Should cover pinned needle: <Needle>' -ForEach $pinnedNeedles {
            $harness = Get-Content -Path $harnessPath -Raw
            $harness.Contains($Needle) | Should -BeTrue -Because "every operator pin needs per-row fixtures in StringOperatorEquivalence.kql so the swap stays verifiable on a live cluster"
        }
    }
}
