# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for Data Explorer dashboard savings formulas (#2093 / PR #2248):

    1. Savings are never computed by subtracting raw aggregates (sum(ListCost) - sum(EffectiveCost)); tiles use the
       row-level clamped x_*Savings columns so every displayed operand and result share one basis.
    2. Commitment purchases are excluded via x_AmortizationClass != 'Principal'; the older
       ChargeCategory == 'Usage' or isempty(CommitmentDiscountId) variant is gone.
    3. Every Effective Savings Rate guards against a zero List cost (blank instead of NaN).
#>

Describe 'HubsDashboardSavings' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $dashboard = Get-Content (Join-Path $repoRoot 'src/templates/finops-hub/dashboard.json') -Raw | ConvertFrom-Json
        $queries = @($dashboard.queries | ForEach-Object { @{ Id = $_.id.Substring(0, 8); Text = [string]$_.text } })
        # 3886b5cd pivots Effective cost only; its savings columns are never displayed.
        $savingsQueries = @($queries | Where-Object { $_.Id -ne '3886b5cd' -and $_.Text -match '(?i)sum(if)?\(\s*x_(Negotiated|Commitment|Total)\w*Savings' })
    }

    It 'Excludes commitment purchases from all Summary page savings queries' {
        $summaryQueries = @($queries | Where-Object { $_.Text -match "(?i)sumif\(\s*x_(Negotiated|Commitment)DiscountSavings\s*,\s*x_AmortizationClass\s*!=\s*'Principal'\s*\)" })
        $summaryQueries.Count | Should -BeGreaterOrEqual 9
    }

    Context 'Query <Id>' -ForEach $queries {
        It 'Does not subtract raw aggregates to compute savings' {
            $Text | Should -Not -Match '(?i)sum\(\s*(List|Contracted)Cost\s*\)\s*-\s*sum\('
        }

        It 'Does not use the legacy commitment purchase filter' {
            $Text | Should -Not -Match "(?i)ChargeCategory\s*==\s*'Usage'\s+or\s+isempty\(CommitmentDiscountId\)"
        }
    }

    Context 'Savings query <Id>' -ForEach $savingsQueries {
        It 'Excludes commitment purchases or is limited to usage rows' {
            $Text | Should -Match "(?i)x_AmortizationClass\s*!=\s*'Principal'|ChargeCategory\s*==\s*'Usage'"
        }

        It 'Guards the savings rate against zero list cost' {
            if ($Text -match '(?i)EffectiveSavingsRate\s*=') {
                $Text | Should -Match '(?i)ListCost\s*==\s*0'
            }
        }
    }
}
