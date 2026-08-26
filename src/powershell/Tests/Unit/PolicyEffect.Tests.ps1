# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Policy effect resolution' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        function New-TestDefinition {
            param([string]$RuleEffect, [string]$ParameterDefault)
            $def = [PSCustomObject]@{
                policyRule = [PSCustomObject]@{ then = [PSCustomObject]@{ effect = $RuleEffect } }
                parameters = [PSCustomObject]@{ effect = [PSCustomObject]@{ defaultValue = $ParameterDefault } }
            }
            return $def
        }
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Format-PolicyEffectName' {
        # Named Raw, not Input: $Input is an automatic variable and silently
        # resolves to the pipeline enumerator instead of the test data.
        It 'Normalizes <Raw> to <Expected>' -ForEach @(
            @{ Raw = 'modify'; Expected = 'Modify' }
            @{ Raw = 'deployIfNotExists'; Expected = 'DeployIfNotExists' }
            @{ Raw = 'AuditIfNotExists'; Expected = 'AuditIfNotExists' }
            @{ Raw = 'deny'; Expected = 'Deny' }
        ) {
            Format-PolicyEffectName -Effect $Raw | Should -Be $Expected
        }

        It 'Leaves an empty value alone' {
            Format-PolicyEffectName -Effect '' | Should -BeNullOrEmpty
        }
    }

    Context 'Precedence' {
        It 'Prefers the assignment override over the definition' {
            $def = New-TestDefinition -RuleEffect 'Deny' -ParameterDefault 'Disabled'
            Resolve-PolicyEffect -AssignmentEffect 'Audit' -Definition $def | Should -Be 'Audit'
        }

        It 'Falls back to the definition literal when the assignment is silent' {
            $def = New-TestDefinition -RuleEffect 'modify' -ParameterDefault 'Disabled'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be 'Modify'
        }

        It 'Falls back to the parameter default when the rule defers to a parameter' {
            $def = New-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault 'AuditIfNotExists'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be 'AuditIfNotExists'
        }

        It 'Treats a dash from the caller as no override' {
            $def = New-TestDefinition -RuleEffect 'Deny' -ParameterDefault ''
            Resolve-PolicyEffect -AssignmentEffect '-' -Definition $def | Should -Be 'Deny'
        }
    }

    Context 'Initiatives' {
        It 'Reports varies rather than an unknown effect' {
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $null -IsInitiative | Should -Be 'varies'
        }

        It 'Still honors an explicit override on an initiative assignment' {
            Resolve-PolicyEffect -AssignmentEffect 'Deny' -Definition $null -IsInitiative | Should -Be 'Deny'
        }
    }

    Context 'Unresolvable' {
        It 'Returns a dash when no definition is available' {
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $null | Should -Be '-'
        }

        It 'Returns a dash when the rule defers and no default exists' {
            $def = New-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault ''
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be '-'
        }

        It 'Does not mistake a parameter expression for a literal effect' {
            $def = New-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault 'Deny'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Not -Match '^\['
        }
    }
}
