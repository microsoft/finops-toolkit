# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Commitment utilization de-duplication' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        $script:TwoSubs = @(
            [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000001'; Name = 'Sub one' }
            [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000002'; Name = 'Sub two' }
        )

        # One reservation, two usage periods. Both subscriptions consumed it, so
        # both report the identical pair of records.
        $script:ReservationPayload = @{
            value = @(
                @{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; skuName = 'Standard_D2s_v5'; kind = 'Compute'
                        avgUtilizationPercentage = 50; minUtilizationPercentage = 40; maxUtilizationPercentage = 60
                        reservedHours = 100; usedHours = 50; usageDate = '2026-08-01T00:00:00Z'
                    }
                }
                @{ properties = @{ reservationOrderId = 'order-1'; reservationId = 'res-1'; skuName = 'Standard_D2s_v5'; kind = 'Compute'
                        avgUtilizationPercentage = 90; minUtilizationPercentage = 80; maxUtilizationPercentage = 95
                        reservedHours = 100; usedHours = 90; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
            )
        } | ConvertTo-Json -Depth 8

        # Two DIFFERENT savings plans that share one benefit order.
        $script:SavingsPlanPayload = @{
            value = @(
                @{ properties = @{ benefitType = 'SavingsPlan'; benefitId = 'plan-a'; benefitOrderId = 'order-1'
                        avgUtilizationPercentage = 70; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
                @{ properties = @{ benefitType = 'SavingsPlan'; benefitId = 'plan-b'; benefitOrderId = 'order-1'
                        avgUtilizationPercentage = 30; usageDate = '2026-09-01T00:00:00Z'
                    }
                }
            )
        } | ConvertTo-Json -Depth 8
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    It 'Counts one reservation when every subscription reports it for several months' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match 'reservationSummaries') {
                [PSCustomObject]@{ StatusCode = 200; Content = $script:ReservationPayload }
            }
            else {
                [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' }
            }
        }

        $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # 2 subscriptions x 2 months = 4 API records for a single commitment.
        $result.RICount | Should -Be 1
        # The newest period wins, so the average is not dragged down by August.
        $result.RIAvgUtilization | Should -Be 90
    }

    It 'Keeps distinct savings plans that share one benefit order' {
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -match 'benefitUtilizationSummaries') {
                [PSCustomObject]@{ StatusCode = 200; Content = $script:SavingsPlanPayload }
            }
            else {
                [PSCustomObject]@{ StatusCode = 200; Content = '{"value":[]}' }
            }
        }

        $result = Get-CommitmentUtilization -Subscriptions $script:TwoSubs -WarningAction SilentlyContinue

        # De-duplicating on benefitOrderId alone would collapse these to 1.
        $result.SPCount | Should -Be 2
        $result.SPAvgUtilization | Should -Be 50
    }

    Context 'Usage date comparison' {

        It 'Treats a newer ISO date as newer' {
            Test-UsageDateIsNewer -Candidate '2026-09-01T00:00:00Z' -Existing '2026-08-01T00:00:00Z' | Should -BeTrue
        }

        It 'Treats an older ISO date as not newer' {
            Test-UsageDateIsNewer -Candidate '2026-07-01T00:00:00Z' -Existing '2026-08-01T00:00:00Z' | Should -BeFalse
        }

        It 'Accepts any candidate when nothing was recorded yet' {
            Test-UsageDateIsNewer -Candidate '2026-07-01T00:00:00Z' -Existing $null | Should -BeTrue
        }

        It 'Keeps the recorded row when the candidate has no date' {
            Test-UsageDateIsNewer -Candidate $null -Existing '2026-08-01T00:00:00Z' | Should -BeFalse
        }
    }
}
