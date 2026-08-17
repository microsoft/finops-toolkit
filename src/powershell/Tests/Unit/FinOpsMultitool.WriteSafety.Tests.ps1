# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# The write-safety gate is a private FinOpsMultitool helper that the toolkit
# module only lazy-loads behind the TUI, so dot-source it directly. It must go in
# BeforeAll: top-level code runs only during Pester discovery, so functions
# dot-sourced there are gone by the run phase.
BeforeAll {
    . "$PSScriptRoot/../../Private/FinOpsMultitool/modules/helpers/Confirm-WriteAction.ps1"
}

Describe 'FinOps Multitool write-safety gate' {

    BeforeEach {
        # Every case starts from a known policy and empty in-process state.
        $env:FINOPS_AUDIT_LOG = Join-Path ([System.IO.Path]::GetTempPath()) "ftk-writegate-$([guid]::NewGuid().ToString('N')).log"
        $env:FINOPS_WRITE_MAX_IMPACT = $null
        $env:FINOPS_WRITE_MAX_PER_WINDOW = $null
        $env:FINOPS_PROTECTED_TAGS = $null
        $env:FINOPS_PROTECTED_RGS = $null
        $env:FINOPS_PROTECTED_SUBS = $null
        # Note: the gate's token store and write history are per-process and
        # cannot be reset from here, so each case must stand on its own.
    }

    AfterEach {
        if ($env:FINOPS_AUDIT_LOG -and (Test-Path -LiteralPath $env:FINOPS_AUDIT_LOG)) {
            Remove-Item -LiteralPath $env:FINOPS_AUDIT_LOG -Force -ErrorAction SilentlyContinue
        }
        $env:FINOPS_WRITE_MODE = $null
        $env:FINOPS_AUDIT_LOG = $null
    }

    Context 'ReadOnly mode (the default)' {

        It 'Should default to ReadOnly when FINOPS_WRITE_MODE is unset' {
            $env:FINOPS_WRITE_MODE = $null
            (Initialize-FinOpsWritePolicy).Mode | Should -Be 'ReadOnly'
        }

        It 'Should fall back to ReadOnly when FINOPS_WRITE_MODE is not a known value' {
            $env:FINOPS_WRITE_MODE = 'YOLO'
            (Initialize-FinOpsWritePolicy).Mode | Should -Be 'ReadOnly'
        }

        It 'Should block a dry-run preview' {
            $env:FINOPS_WRITE_MODE = 'ReadOnly'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r'
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should block apply=true' {
            $env:FINOPS_WRITE_MODE = 'ReadOnly'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply
            $d.Decision | Should -Be 'Blocked'
            $d.Reason | Should -Match 'ReadOnly'
        }
    }

    Context 'Interactive mode' {

        BeforeEach {
            $env:FINOPS_WRITE_MODE = 'Interactive'
            Initialize-FinOpsWritePolicy | Out-Null
        }

        It 'Should preview and issue a token on a dry run' {
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r'
            $d.Decision | Should -Be 'Preview'
            $d.ConfirmationToken | Should -Not -BeNullOrEmpty
            $d.RequiresToken | Should -BeFalse
        }

        It 'Should proceed on apply=true without a token' {
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply
            $d.Decision | Should -Be 'Proceed'
        }
    }

    Context 'Enforced mode' {

        BeforeEach {
            $env:FINOPS_WRITE_MODE = 'Enforced'
            Initialize-FinOpsWritePolicy | Out-Null
        }

        It 'Should flag that a token is required on preview' {
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r'
            $d.Decision | Should -Be 'Preview'
            $d.RequiresToken | Should -BeTrue
            $d.ConfirmationToken | Should -Not -BeNullOrEmpty
        }

        It 'Should block apply=true with no token' {
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply
            $d.Decision | Should -Be 'Blocked'
            $d.Reason | Should -Match 'Enforced'
        }

        It 'Should block apply=true with a bogus token' {
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply -ConfirmationToken 'not-a-real-token'
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should proceed with the token from the matching dry run' {
            $preview = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r'
            $apply = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply -ConfirmationToken $preview.ConfirmationToken
            $apply.Decision | Should -Be 'Proceed'
        }

        It 'Should reject a token on second use' {
            $preview = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r'
            $first = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply -ConfirmationToken $preview.ConfirmationToken
            $second = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply -ConfirmationToken $preview.ConfirmationToken
            $first.Decision | Should -Be 'Proceed'
            $second.Decision | Should -Be 'Blocked'
        }

        It 'Should reject a token issued for a different resource' {
            $preview = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/resource-A'
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/resource-B' -Apply -ConfirmationToken $preview.ConfirmationToken
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should reject a token issued for a different operation' {
            $preview = Resolve-WriteDecision -ToolName 'test' -Operation 'Deallocate' -ResourceId '/subscriptions/s/rg/r'
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply -ConfirmationToken $preview.ConfirmationToken
            $d.Decision | Should -Be 'Blocked'
        }
    }

    Context 'Guardrails' {

        BeforeEach {
            $env:FINOPS_WRITE_MODE = 'Interactive'
        }

        It 'Should block a resource carrying a protected tag by default' {
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Tags @{ 'DoNotDelete' = 'true' } -Apply
            $d.Decision | Should -Be 'Blocked'
            $d.GuardrailViolations.Count | Should -BeGreaterThan 0
        }

        It 'Should block a protected subscription' {
            $env:FINOPS_PROTECTED_SUBS = '00000000-0000-0000-0000-000000000001'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -SubscriptionId '00000000-0000-0000-0000-000000000001' -Apply
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should block a resource group matching a protected pattern' {
            $env:FINOPS_PROTECTED_RGS = 'prod-*'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -ResourceGroup 'prod-payments' -Apply
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should block when estimated impact exceeds the cap' {
            $env:FINOPS_WRITE_MAX_IMPACT = '100'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -EstimatedMonthlyImpact 500 -Apply
            $d.Decision | Should -Be 'Blocked'
        }

        It 'Should allow an impact below the cap' {
            $env:FINOPS_WRITE_MAX_IMPACT = '100'
            Initialize-FinOpsWritePolicy | Out-Null
            $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -EstimatedMonthlyImpact 5 -Apply
            $d.Decision | Should -Be 'Proceed'
        }

        It 'Should block once the blast-radius cap is reached' {
            $env:FINOPS_WRITE_MAX_PER_WINDOW = '3'
            Initialize-FinOpsWritePolicy | Out-Null
            # Write history is per-process and shared across cases, so assert the
            # transition to Blocked rather than a fixed attempt number.
            $blocked = $null
            for ($n = 1; $n -le 6; $n++) {
                $d = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId "/subscriptions/s/rg/r$n" -Apply
                if ($d.Decision -eq 'Blocked') { $blocked = $d; break }
            }
            $blocked | Should -Not -BeNullOrEmpty
            ($blocked.GuardrailViolations -join ' ') | Should -Match 'Blast-radius'
        }

        It 'Should enforce guardrails even in Enforced mode with a valid token' {
            $env:FINOPS_WRITE_MODE = 'Enforced'
            $env:FINOPS_PROTECTED_RGS = 'prod-*'
            Initialize-FinOpsWritePolicy | Out-Null
            $preview = Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -ResourceGroup 'prod-payments'
            $preview.Decision | Should -Be 'Blocked'
        }
    }

    Context 'Audit trail' {

        It 'Should append an entry for a blocked write' {
            $env:FINOPS_WRITE_MODE = 'ReadOnly'
            Initialize-FinOpsWritePolicy | Out-Null
            Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply | Out-Null
            Test-Path -LiteralPath $env:FINOPS_AUDIT_LOG | Should -BeTrue
            (Get-Content -LiteralPath $env:FINOPS_AUDIT_LOG -Raw) | Should -Match 'blocked'
        }

        It 'Should record preview and apply events' {
            $env:FINOPS_WRITE_MODE = 'Interactive'
            Initialize-FinOpsWritePolicy | Out-Null
            Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' | Out-Null
            Resolve-WriteDecision -ToolName 'test' -Operation 'Delete' -ResourceId '/subscriptions/s/rg/r' -Apply | Out-Null
            $log = Get-Content -LiteralPath $env:FINOPS_AUDIT_LOG -Raw
            $log | Should -Match 'preview'
            $log | Should -Match 'apply'
        }
    }
}
