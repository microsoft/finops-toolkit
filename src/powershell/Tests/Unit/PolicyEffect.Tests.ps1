# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Policy effect resolution' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        function Get-TestDefinition {
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
            $def = Get-TestDefinition -RuleEffect 'Deny' -ParameterDefault 'Disabled'
            Resolve-PolicyEffect -AssignmentEffect 'Audit' -Definition $def | Should -Be 'Audit'
        }

        It 'Falls back to the definition literal when the assignment is silent' {
            $def = Get-TestDefinition -RuleEffect 'modify' -ParameterDefault 'Disabled'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be 'Modify'
        }

        It 'Falls back to the parameter default when the rule defers to a parameter' {
            $def = Get-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault 'AuditIfNotExists'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be 'AuditIfNotExists'
        }

        It 'Treats a dash from the caller as no override' {
            $def = Get-TestDefinition -RuleEffect 'Deny' -ParameterDefault ''
            Resolve-PolicyEffect -AssignmentEffect '-' -Definition $def | Should -Be 'Deny'
        }
    }

    Context 'Initiatives' {
        It 'Reports varies rather than an unknown effect' {
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $null -IsInitiative | Should -Be 'varies (Initiative)'
        }

        It 'Still honors an explicit override on an initiative assignment' {
            Resolve-PolicyEffect -AssignmentEffect 'Deny' -Definition $null -IsInitiative | Should -Be 'Deny'
        }
    }

    Context 'Unresolvable' {
        It 'Warns visibly when a policy definition cannot be read' -Tag 'PolicyDefinitionCoverage' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                Mock Write-Warning { }

                $result = Get-PolicyDefinitionMap -DefinitionIds @('/providers/Microsoft.Authorization/policyDefinitions/fixture')

                $result.Count | Should -Be 0
                Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'fixture.*503' }
            }
        }

        It 'Returns a dash when no definition is available' {
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $null | Should -Be '-'
        }

        It 'Returns a dash when the rule defers and no default exists' {
            $def = Get-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault ''
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Be '-'
        }

        It 'Does not mistake a parameter expression for a literal effect' {
            $def = Get-TestDefinition -RuleEffect "[parameters('effect')]" -ParameterDefault 'Deny'
            Resolve-PolicyEffect -AssignmentEffect '' -Definition $def | Should -Not -Match '^\['
        }
    }

    Context 'Definition ID guard' {
        It 'Records an invalid definition ID without sending a request' -Tag 'PolicyDefinitionCoverage' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry { throw 'An invalid definition ID must not be requested.' }
                Mock Write-Warning { }
                $readErrors = [System.Collections.Generic.List[string]]::new()

                $result = Get-PolicyDefinitionMap -DefinitionIds @('/providers/Microsoft.Authorization/policyDefinitions/unsafe?api-version=bad') -ReadErrors $readErrors

                $result.Count | Should -Be 0
                $readErrors.Count | Should -Be 1
                $readErrors[0] | Should -Match 'resource ID is invalid'
                Should -Invoke Write-Warning -Times 1 -Exactly
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
            }
        }

        # Get-PolicyDefinitionMap concatenates the ID ahead of a query string, so a
        # malformed ID could rewrite the request. These assert the accepted shapes.
        BeforeAll {
            $script:IdPattern = '^(/[A-Za-z0-9._\-()/]+)?/providers/Microsoft\.Authorization/policyDefinitions/[A-Za-z0-9._\-()]+$'
        }

        It 'Accepts <Case>' -ForEach @(
            @{ Case = 'a built-in definition'; Id = '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26' }
            @{ Case = 'a subscription-scoped definition'; Id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/my-policy' }
            @{ Case = 'a management-group definition'; Id = '/providers/Microsoft.Management/managementGroups/mg1/providers/Microsoft.Authorization/policyDefinitions/abc123' }
        ) {
            $Id -match $script:IdPattern | Should -BeTrue
        }

        It 'Rejects <Case>' -ForEach @(
            @{ Case = 'a query-string injection'; Id = '/providers/Microsoft.Authorization/policyDefinitions/x?api-version=2015-01-01&evil=1' }
            @{ Case = 'a fragment injection'; Id = '/providers/Microsoft.Authorization/policyDefinitions/x#frag' }
            @{ Case = 'a different resource type'; Id = '/subscriptions/abc/providers/Microsoft.Authorization/roleAssignments/x' }
            @{ Case = 'an initiative definition'; Id = '/providers/Microsoft.Authorization/policySetDefinitions/abc' }
            @{ Case = 'an empty id'; Id = '' }
        ) {
            $Id -match $script:IdPattern | Should -BeFalse
        }
    }

    Context 'Assignment inventory coverage' {
        It 'Preserves incomplete assignment evidence for <Scenario>' -ForEach @(
            @{ Scenario = 'denied'; Incomplete = $true; AssignmentCount = 0 }
            @{ Scenario = 'malformed'; Incomplete = $true; AssignmentCount = 0 }
            @{ Scenario = 'later page failure'; Incomplete = $true; AssignmentCount = 1 }
            @{ Scenario = 'complete empty inventory'; Incomplete = $false; AssignmentCount = 0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scenario = $Scenario; Incomplete = $Incomplete; AssignmentCount = $AssignmentCount } {
                param($Scenario, $Incomplete, $AssignmentCount)
                $fixtureScenario = $Scenario
                Mock Write-Host { }
                Mock Search-AzGraphSafe { [pscustomobject]@{ Data = @(); SkipToken = $null } }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*policyAssignments*') {
                        if ($fixtureScenario -eq 'denied') { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                        if ($fixtureScenario -eq 'malformed') { return [pscustomobject]@{ StatusCode = 200; Content = '{}' } }
                        if ($fixtureScenario -eq 'later page failure') {
                            if ($Path -like '*continuation*') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                            return [pscustomobject]@{ StatusCode = 200; Content = (@{
                                value = @(@{
                                    id = '/subscriptions/fixture/providers/Microsoft.Authorization/policyAssignments/locations'
                                    name = 'locations'
                                    properties = @{
                                        displayName = 'Locations'
                                        policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
                                        parameters = @{ effect = @{ value = 'Audit' } }
                                    }
                                })
                                nextLink = '/subscriptions/fixture/providers/Microsoft.Authorization/policyAssignments?continuation=second'
                            } | ConvertTo-Json -Depth 8) }
                        }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' }
                }

                $inventory = Get-PolicyInventory -Subscriptions @([pscustomobject]@{ Id = 'fixture'; Name = 'Fixture' })

                $inventory.CoverageIncomplete | Should -Be $Incomplete
                $inventory.AssignmentCount | Should -Be $AssignmentCount
                if ($Incomplete) {
                    @($inventory.AssignmentErrors).Count | Should -BeGreaterThan 0
                    $inventory.Note | Should -Match 'Missing assignments cannot be determined'
                }
                else {
                    @($inventory.AssignmentErrors).Count | Should -Be 0
                    Should -Invoke Search-AzGraphSafe -Times 0 -Exactly -ParameterFilter { $Query -like '*policyassignments*' }
                }
            }
        }
    }

    Context 'Definition read coverage' {
        It 'Separates <Scenario> definition reads from assignment and compliance coverage' -Tag 'PolicyDefinitionCoverage' -ForEach @(
            @{ Scenario = 'HTTP 503'; Incomplete = $true; ErrorPattern = '503' }
            @{ Scenario = 'exception'; Incomplete = $true; ErrorPattern = 'Synthetic definition timeout' }
            @{ Scenario = 'malformed JSON'; Incomplete = $true; ErrorPattern = 'definition' }
            @{ Scenario = 'missing properties'; Incomplete = $true; ErrorPattern = 'properties' }
            @{ Scenario = 'empty response'; Incomplete = $true; ErrorPattern = 'properties' }
            @{ Scenario = 'unresolved parameter'; Incomplete = $false; ErrorPattern = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Scenario = $Scenario; Incomplete = $Incomplete; ErrorPattern = $ErrorPattern } {
                param($Scenario, $Incomplete, $ErrorPattern)
                $fixtureScenario = $Scenario
                $subscriptionId = '11111111-1111-1111-1111-111111111111'
                $definitionId = '/providers/Microsoft.Authorization/policyDefinitions/unavailable'
                Mock Write-Host { }
                Mock Write-Warning { }
                Mock Get-AzContext { throw 'Definition coverage tests must not read an Azure context.' }
                Mock Invoke-RestMethod { throw 'Definition coverage tests must not make HTTP requests.' }
                Mock Search-AzGraphSafe {
                    [pscustomobject]@{ Data = @([pscustomobject]@{ subscriptionId = $subscriptionId; Total = 10; Compliant = 10; NonCompliant = 0 }) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -eq "/subscriptions/$subscriptionId/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01") {
                        $assignments = @(foreach ($name in @('known', 'unavailable-one', 'unavailable-two')) {
                            $policyId = if ($name -eq 'known') { '/providers/Microsoft.Authorization/policyDefinitions/known' } else { $definitionId }
                            @{
                                id = "/subscriptions/$subscriptionId/providers/Microsoft.Authorization/policyAssignments/$name"
                                name = $name
                                properties = @{ displayName = $name; policyDefinitionId = $policyId }
                            }
                        })
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $assignments } | ConvertTo-Json -Depth 8) }
                    }
                    if ($Path -eq '/providers/Microsoft.Authorization/policyDefinitions/known?api-version=2023-04-01') {
                        return [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"policyRule":{"then":{"effect":"Deny"}}}}' }
                    }
                    if ($Path -ne "$($definitionId)?api-version=2023-04-01") { throw 'Unexpected request scope.' }
                    switch ($fixtureScenario) {
                        'HTTP 503' { [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                        'exception' { throw 'Synthetic definition timeout.' }
                        'malformed JSON' { [pscustomobject]@{ StatusCode = 200; Content = '{invalid' } }
                        'missing properties' { [pscustomobject]@{ StatusCode = 200; Content = '{}' } }
                        'empty response' { [pscustomobject]@{ StatusCode = 200; Content = '' } }
                        'unresolved parameter' {
                            [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ policyRule = @{ then = @{ effect = "[parameters('effect')]" } } } } | ConvertTo-Json -Depth 6) }
                        }
                    }
                }

                $inventory = Get-PolicyInventory -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @(
                    [pscustomobject]@{ Id = $subscriptionId; Name = 'Selected subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                )

                $inventory.AssignmentCount | Should -Be 3
                $inventory.CoverageIncomplete | Should -BeFalse
                $inventory.ComplianceCoverageIncomplete | Should -BeFalse
                $inventory.HasComplianceData | Should -BeTrue
                $inventory.CompliancePct | Should -Be 100
                $inventory.DefinitionCoverageIncomplete | Should -Be $Incomplete
                ($inventory.Assignments | Where-Object AssignmentName -EQ 'known').Effect | Should -Be 'Deny'
                @($inventory.Assignments | Where-Object Effect -EQ '-').Count | Should -Be 2
                if ($Incomplete) {
                    @($inventory.DefinitionErrors).Count | Should -Be 1
                    $inventory.DefinitionErrors[0] | Should -Match ([regex]::Escape($definitionId))
                    $inventory.DefinitionErrors[0] | Should -Match $ErrorPattern
                    $inventory.Note | Should -Match 'Policy definition.*incomplete'
                    $inventory.Note | Should -Not -Match 'Missing assignments|compliance coverage is incomplete'
                    Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'Policy definition.*unavailable' }
                }
                else {
                    @($inventory.DefinitionErrors).Count | Should -Be 0
                    $inventory.Note | Should -BeNullOrEmpty
                    Should -Invoke Write-Warning -Times 0 -Exactly
                }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 3 -Exactly
                Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter {
                    @($Subscription).Count -eq 1 -and $Subscription[0] -eq $subscriptionId
                }
                Should -Invoke Get-AzContext -Times 0 -Exactly
                Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            }
        }
    }

    Context 'Compliance and assignment identity' {
        It 'Resolves policy scope names without losing IDs or crossing tenants (<LookupState>)' -Tag 'PolicyScopeMetadata' -ForEach @(
            @{ LookupState = 'readable'; StatusCode = 200; ReturnedTenant = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; ExpectedName = 'Example management group' }
            @{ LookupState = 'denied'; StatusCode = 403; ReturnedTenant = $null; ExpectedName = $null }
            @{ LookupState = 'different tenant'; StatusCode = 200; ReturnedTenant = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; ExpectedName = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ StatusCode = $StatusCode; ReturnedTenant = $ReturnedTenant; ExpectedName = $ExpectedName } {
                param($StatusCode, $ReturnedTenant, $ExpectedName)
                $fixtureStatus = $StatusCode
                $fixtureTenant = $ReturnedTenant
                $subId = '11111111-1111-1111-1111-111111111111'
                $mgScope = '/providers/Microsoft.Management/managementGroups/fixture-group'
                $policyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
                Mock Write-Host { }
                Mock Write-Warning { }
                Mock Get-AzContext { throw 'Scope fixtures must not read Azure context.' }
                Mock Invoke-RestMethod { throw 'Scope fixtures must not send HTTP requests.' }
                Mock Search-AzGraphSafe { @{ Data = @([pscustomobject]@{ subscriptionId = $subId; Total = 1; Compliant = 1; NonCompliant = 0 }) } }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -eq "/subscriptions/$subId/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01") {
                        $assignments = @(
                            @{ id = "/subscriptions/$subId/providers/Microsoft.Authorization/policyAssignments/sub-policy"; name = 'sub-policy'; properties = @{ displayName = 'Subscription policy'; policyDefinitionId = $policyId; parameters = @{ effect = @{ value = 'Audit' } } } }
                            @{ id = "$mgScope/providers/Microsoft.Authorization/policyAssignments/mg-policy-one"; name = 'mg-policy-one'; properties = @{ displayName = 'Inherited one'; policyDefinitionId = $policyId; parameters = @{ effect = @{ value = 'Audit' } } } }
                            @{ id = "$mgScope/providers/Microsoft.Authorization/policyAssignments/mg-policy-two"; name = 'mg-policy-two'; properties = @{ displayName = 'Inherited two'; policyDefinitionId = $policyId; parameters = @{ effect = @{ value = 'Audit' } } } }
                        )
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $assignments } | ConvertTo-Json -Depth 9) }
                    }
                    if ($Path -eq "$($mgScope)?api-version=2020-05-01" -and $Method -eq 'GET') {
                        return [pscustomobject]@{ StatusCode = $fixtureStatus; Content = (@{ id = $mgScope; name = 'fixture-group'; properties = @{ displayName = 'Example management group'; tenantId = $fixtureTenant } } | ConvertTo-Json -Depth 5) }
                    }
                    throw 'Unexpected policy scope request.'
                }

                $inventory = Get-PolicyInventory -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions @([pscustomobject]@{ Id = $subId; Name = 'Example subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })
                $recommendations = Get-PolicyRecommendations -ExistingAssignments $inventory.Assignments

                $inventory.AssignmentCount | Should -Be 3
                $inventory.CoverageIncomplete | Should -BeFalse
                $inventory.CompliancePct | Should -Be 100
                ($inventory.Assignments | Where-Object AssignmentName -EQ 'Subscription policy').ScopeDisplayName | Should -Be 'Example subscription'
                $inherited = @($inventory.Assignments | Where-Object Scope -EQ $mgScope)
                $inherited.Count | Should -Be 2
                foreach ($assignment in $inherited) {
                    $assignment.ScopeDisplayName | Should -Be $(if ($ExpectedName) { $ExpectedName } else { $mgScope })
                    $assignment.Scope | Should -Be $mgScope
                }
                $matched = @(($recommendations.Analysis | Where-Object PolicyDefId -EQ $policyId).MatchedAssignments)
                $matched.Count | Should -Be 3
                ($matched | Where-Object AssignmentName -EQ 'Subscription policy').ScopeDisplayName | Should -Be 'Example subscription'
                @($inventory.ScopeNameErrors).Count | Should -Be $(if ($ExpectedName) { 0 } else { 1 })
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter { $Path -eq "$($mgScope)?api-version=2020-05-01" -and $Method -eq 'GET' }
                Should -Invoke Get-AzContext -Times 0 -Exactly
                Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            }
        }

        It 'Keeps compliance coverage separate from assignment coverage (<ArgMode>, HTTP <SecondStatus>)' -ForEach @(
            @{ ArgMode = 'empty'; SecondStatus = 503; ExpectedIncomplete = $true }
            @{ ArgMode = 'partial'; SecondStatus = 403; ExpectedIncomplete = $true }
            @{ ArgMode = 'failed'; SecondStatus = 200; ExpectedIncomplete = $false }
            @{ ArgMode = 'partial'; SecondStatus = 200; ExpectedIncomplete = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ArgMode = $ArgMode; SecondStatus = $SecondStatus; ExpectedIncomplete = $ExpectedIncomplete } {
                param($ArgMode, $SecondStatus, $ExpectedIncomplete)
                $fixtureArgMode = $ArgMode
                $fixtureStatus = $SecondStatus
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )
                Mock Search-AzGraphSafe {
                    if ($fixtureArgMode -eq 'failed') { throw 'ARG incomplete.' }
                    if ($fixtureArgMode -eq 'partial') { return @{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; Total = 10; Compliant = 10; NonCompliant = 0 }) } }
                    @{ Data = @() }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*policyAssignments*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    if ($Path -like '*/22222222-2222-2222-2222-222222222222/*' -and $fixtureStatus -ne 200) { return [pscustomobject]@{ StatusCode = $fixtureStatus; Content = '{}' } }
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"results":{"resourceDetails":[{"complianceState":"compliant","count":10}],"policyDetails":[]}}]}' }
                }

                $result = Get-PolicyInventory -Subscriptions $subscriptions

                $result.CoverageIncomplete | Should -BeFalse
                $result.ComplianceCoverageIncomplete | Should -Be $ExpectedIncomplete
                if ($ExpectedIncomplete) {
                    $result.CompliancePct | Should -BeNullOrEmpty
                    $result.HasComplianceData | Should -BeFalse
                    $result.Note | Should -Match 'compliance.*incomplete'
                }
                else { $result.CompliancePct | Should -Be 100; $result.HasComplianceData | Should -BeTrue }
            }
        }

        It 'Replaces partial ARG state counts with resource summaries for every subscription' {
            InModuleScope FinOpsMultitool {
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )
                Mock Search-AzGraphSafe {
                    @{ Data = @([pscustomobject]@{ subscriptionId = '11111111-1111-1111-1111-111111111111'; Total = 100; Compliant = 100; NonCompliant = 0 }) }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*policyAssignments*') { return [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' } }
                    $state = if ($Path -like '*/11111111-1111-1111-1111-111111111111/*') { 'compliant' } else { 'noncompliant' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ results = @{ resourceDetails = @(@{ complianceState = $state; count = 1 }); policyDetails = @() } }) } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-PolicyInventory -Subscriptions $subscriptions

                $result.ComplianceCoverageIncomplete | Should -BeFalse
                $result.CompliancePct | Should -Be 50
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter { $Path -like '*policyStates/latest/summarize*' }
            }
        }

        It 'Retains distinct same-name initiative assignments and finds both sets of members' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*policyAssignments*') {
                        $assignments = @(foreach ($number in 1..2) {
                            @{ id = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments/fixture-$number"; name = "fixture-$number"; properties = @{ displayName = 'Same display name'; policyDefinitionId = "/providers/Microsoft.Authorization/policySetDefinitions/fixture-$number" } }
                        })
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = $assignments } | ConvertTo-Json -Depth 8) }
                    }
                    if ($Path -like '*policySetDefinitions*') {
                        $policyId = if ($Path -like '*fixture-1?*') { 'e56962a6-4747-49cd-b67b-bf8b01975c4c' } else { '726aca4c-86e9-4b04-b0c5-073027359532' }
                        return [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ policyDefinitions = @(@{ policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/$policyId" }) } } | ConvertTo-Json -Depth 8) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[]}' }
                }

                $inventory = Get-PolicyInventory -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })
                $recommendations = Get-PolicyRecommendations -ExistingAssignments $inventory.Assignments

                $inventory.AssignmentCount | Should -Be 2
                ($recommendations.Analysis | Where-Object DisplayName -EQ 'Allowed locations').Status | Should -Be 'Assigned (Initiative)'
                ($recommendations.Analysis | Where-Object DisplayName -EQ 'Require a tag on resources').Status | Should -Be 'Assigned (Initiative)'
            }
        }
    }

    Context 'Recommendation initiative membership' {
        It 'Finds policies in a <Scope> initiative and resolves each definition once' -ForEach @(
            @{ Scope = 'built-in'; DefinitionId = '/providers/Microsoft.Authorization/policySetDefinitions/fixture' }
            @{ Scope = 'subscription'; DefinitionId = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policySetDefinitions/fixture' }
            @{ Scope = 'management-group'; DefinitionId = '/providers/Microsoft.Management/managementGroups/fixture/providers/Microsoft.Authorization/policySetDefinitions/fixture' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ DefinitionId = $DefinitionId } {
                param($DefinitionId)
                $initiativeId = $DefinitionId
                $policyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{ policyDefinitions = @(
                        @{ policyDefinitionId = $policyId.ToUpperInvariant(); policyDefinitionReferenceId = 'locations-one' }
                        @{ policyDefinitionId = $policyId; policyDefinitionReferenceId = 'locations-two' }
                    ) } } | ConvertTo-Json -Depth 8) }
                }
                $assignments = @(
                    [pscustomobject]@{ AssignmentName = 'Governance initiative'; AssignmentId = '/assignments/one'; PolicyDefId = $initiativeId; Origin = 'Initiative'; Scope = '/subscriptions/one'; EnforcementMode = 'Default' }
                    [pscustomobject]@{ AssignmentName = 'Audit-only initiative'; AssignmentId = '/assignments/two'; PolicyDefId = $initiativeId; Origin = 'Initiative'; Scope = '/subscriptions/two'; EnforcementMode = 'DoNotEnforce' }
                )

                $result = Get-PolicyRecommendations -ExistingAssignments $assignments

                $locations = $result.Analysis | Where-Object PolicyDefId -EQ $policyId
                $locations.Status | Should -Be 'Assigned (Initiative)'
                @($locations.MatchedAssignments).Count | Should -Be 2
                $locations.MatchedAssignments.AssignmentName | Should -Contain 'Governance initiative'
                $locations.MatchedAssignments.EnforcementMode | Should -Contain 'DoNotEnforce'
                $result.Assigned.PolicyDefId | Should -Contain $policyId
                $result.Missing.PolicyDefId | Should -Not -Contain $policyId
                $result.CoverageIncomplete | Should -BeFalse
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $Path -eq "$($initiativeId)?api-version=2023-04-01" -and $Method -eq 'GET'
                }
            }
        }

        It 'Leaves unmatched policies unverified when an initiative read fails with <Failure>' -ForEach @(
            @{ Failure = '403' }
            @{ Failure = '429' }
            @{ Failure = 'malformed response' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Failure = $Failure } {
                param($Failure)
                $fixtureFailure = $Failure
                Mock Invoke-AzRestMethodWithRetry {
                    if ($fixtureFailure -eq 'malformed response') { return [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{}}' } }
                    [pscustomobject]@{ StatusCode = [int]$fixtureFailure; Content = '{}' }
                }
                $assignments = @(
                    [pscustomobject]@{ AssignmentName = 'Unknown initiative'; PolicyDefId = '/providers/Microsoft.Authorization/policySetDefinitions/fixture'; Origin = 'Initiative' }
                    [pscustomobject]@{ AssignmentName = 'Locations'; PolicyDefId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'; Origin = 'BuiltIn' }
                )

                $result = Get-PolicyRecommendations -ExistingAssignments $assignments

                ($result.Analysis | Where-Object DisplayName -EQ 'Allowed locations').Status | Should -Be 'Assigned'
                ($result.Analysis | Where-Object DisplayName -EQ 'Require a tag on resources').Status | Should -Be 'Unknown'
                @($result.Missing).Count | Should -Be 0
                $result.CompliancePct | Should -BeNullOrEmpty
                $result.CoverageIncomplete | Should -BeTrue
                @($result.InitiativeErrors).Count | Should -Be 1
            }
        }

        It 'Does not treat a matching assignment name as a matching policy definition' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry { throw 'Direct assignments should not trigger initiative reads.' }
                $assignments = @([pscustomobject]@{
                    AssignmentName = 'Allowed locations'
                    PolicyDefId = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyDefinitions/different-policy'
                })

                $result = Get-PolicyRecommendations -ExistingAssignments $assignments

                ($result.Analysis | Where-Object DisplayName -EQ 'Allowed locations').Status | Should -Be 'Missing'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
            }
        }

        It 'Rejects an unsafe initiative ID without sending it to ARM' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry { throw 'The unsafe resource ID must not be sent.' }

                $result = Get-PolicyRecommendations -ExistingAssignments @([pscustomobject]@{
                    PolicyDefId = '/providers/Microsoft.Authorization/policySetDefinitions/fixture?api-version=bad'
                    Origin = 'Initiative'
                })

                $result.CoverageIncomplete | Should -BeTrue
                @($result.Missing).Count | Should -Be 0
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
            }
        }

        It 'Renders initiative presence and unknown coverage honestly (read failure: <ReadFailure>)' -ForEach @(
            @{ ReadFailure = $false }
            @{ ReadFailure = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ReadFailure = $ReadFailure; ModuleRoot = (Split-Path $script:MultitoolModule -Parent) } {
                param($ReadFailure, $ModuleRoot)
                $failLookup = $ReadFailure
                Mock Invoke-AzRestMethodWithRetry {
                    if ($failLookup) { return [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                    [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"policyDefinitions":[{"policyDefinitionId":"/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"}]}}' }
                }
                $data = Get-PolicyRecommendations -ExistingAssignments @([pscustomobject]@{
                    AssignmentName = 'Governance initiative'; AssignmentId = '/assignments/fixture'; Scope = '/subscriptions/fixture'; EnforcementMode = 'DoNotEnforce'
                    PolicyDefId = '/providers/Microsoft.Authorization/policySetDefinitions/fixture'; Origin = 'Initiative'
                })
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-PolicyRecommendations' -and $_.Item2.Extent.Text.Contains('$data.Analysis') })
                $branches.Count | Should -Be 3
                $captured = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { [void]$captured.Add([string]$Object) }
                $guidanceItems = @()
                $htmlRows = $null
                $rows = $null

                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data)`n$body")) $data
                }

                ($captured -join ' ') | Should -Match 'Assignment coverage:'
                ($captured -join ' ') | Should -Not -Match 'Compliance:'
                if ($ReadFailure) {
                    ($captured -join ' ') | Should -Match 'unverified'
                    ($guidanceItems.Message -join ' ') | Should -Match 'Unknown, not confirmed missing'
                    $guidanceItems.Severity | Should -Not -Contain 'Green'
                }
                else {
                    ($rows | Where-Object Policy -EQ 'Allowed locations').Status | Should -Be 'Assigned (Initiative)'
                    ($htmlRows | Where-Object Policy -EQ 'Allowed locations').Assignments | Should -Be 'Governance initiative [Initiative; DoNotEnforce; /subscriptions/fixture]'
                }
                ($guidanceItems.Message -join ' ') | Should -Not -Match 'foundation is incomplete|Strong governance foundation'
                ($guidanceItems.Message -join ' ') | Should -Match 'does not prove enforcement'
            }
        }
    }
}
