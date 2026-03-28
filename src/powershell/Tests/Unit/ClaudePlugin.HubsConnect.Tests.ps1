# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $commandPath = Join-Path $repoRoot 'src/templates/claude-plugin/commands/ftk/hubs-connect.md'
    $workflowPath = Join-Path $repoRoot 'src/templates/claude-plugin/skills/finops-toolkit/references/workflows/ftk-hubs-connect.md'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-FirstMatch
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Pattern,

            [Parameter(Mandatory)]
            [string]$Label
        )

        $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $match.Success | Should -BeTrue -Because "$Label should exist"
        return $match.Value.Trim()
    }
}

Describe 'Claude plugin hubs-connect markdown consistency' {
    # // T-1.6: RTM FR-5.1
    It 'FR5_1_AC1_HubsConnect_DataLastUpdatedHelperMatches' {
        $commandContent = Get-TestFileContent -Path $commandPath
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandHelper = Get-FirstMatch -Content $commandContent -Pattern '^\s*DataLastUpdated\s*=\s*.+$' -Label 'Command DataLastUpdated helper'
        $workflowHelper = Get-FirstMatch -Content $workflowContent -Pattern '^\s*DataLastUpdated\s*=\s*.+$' -Label 'Workflow DataLastUpdated helper'

        $commandHelper | Should -BeExactly $workflowHelper
    }

    # // T-1.6: RTM FR-5.1
    It 'FR5_1_AC2_HubsConnect_RetryGuidanceMatches' {
        $commandContent = Get-TestFileContent -Path $commandPath
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandRetryGuidance = Get-FirstMatch -Content $commandContent -Pattern '^If you don''t find any FinOps hub instances.*$' -Label 'Command retry guidance'
        $workflowRetryGuidance = Get-FirstMatch -Content $workflowContent -Pattern '^If you don''t find any FinOps hub instances.*$' -Label 'Workflow retry guidance'

        $commandRetryGuidance | Should -Not -Match 'subscriptioin'
        $workflowRetryGuidance | Should -Not -Match 'subscriptioin'
        $commandRetryGuidance | Should -Match '\bsubscription\b'
        $workflowRetryGuidance | Should -Match '\bsubscription\b'
        $commandRetryGuidance | Should -BeExactly $workflowRetryGuidance
        $commandRetryGuidance | Should -Match 'repeat step 2 with that subscription name or ID\.'
    }

    # // T-1.6: RTM FR-5.1
    It 'FR5_1_AC3_HubsConnect_HandoffRemainsPresent' {
        $commandContent = Get-TestFileContent -Path $commandPath
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandContent | Should -Match '/ftk-hubs-healthCheck'
        $workflowContent | Should -Match '/ftk-hubs-healthCheck'
    }

    # // T-1.6: RTM FR-1.1
    It 'FR5_1_AC5_HubsConnect_SelectionGuidanceMatches' {
        $commandContent = Get-TestFileContent -Path $commandPath
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandSelectionGuidance = Get-FirstMatch -Content $commandContent -Pattern '^If multiple FinOps hub instances were found and shared with the user, ask the user to select one of them by providing the `hubName`, `clusterShortUri`, or another cluster URI of the FinOps hub instance they want to use\.\r?$' -Label 'Command selection guidance'
        $workflowSelectionGuidance = Get-FirstMatch -Content $workflowContent -Pattern '^If multiple FinOps hub instances were found and shared with the user, ask the user to select one of them by providing the `hubName`, `clusterShortUri`, or another cluster URI of the FinOps hub instance they want to use\.\r?$' -Label 'Workflow selection guidance'

        $commandSelectionGuidance | Should -BeExactly $workflowSelectionGuidance
    }

    # // T-1.6: RTM FR-1.1
    It 'FR5_1_AC6_HubsConnect_SaveEnvironmentGuidanceMatches' {
        $commandContent = Get-TestFileContent -Path $commandPath
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandSaveSection = Get-FirstMatch -Content $commandContent -Pattern '(?s)^## Step 5: Save the environment.*?(?=^## Step 6: Run a health check)' -Label 'Command save environment section'
        $workflowSaveSection = Get-FirstMatch -Content $workflowContent -Pattern '(?s)^## Step 5: Save the environment.*?(?=^## Step 6: Run a health check)' -Label 'Workflow save environment section'

        $commandSaveSection | Should -BeExactly $workflowSaveSection
        $commandSaveSection | Should -Match 'preserve other environments'
        $commandSaveSection | Should -Match 'clusterShortUri'
        $commandSaveSection | Should -Match 'cluster-uri'
        $commandSaveSection | Should -Match 'tenant'
        $commandSaveSection | Should -Match 'subscription'
        $commandSaveSection | Should -Match 'resource-group'
        $commandSaveSection | Should -Match 'default'
    }

    # // T-1.6: RTM NFR-3
    It 'FR5_1_AC4_HubsConnect_TestRunsInRepoEnvironment' {
        $repoRoot | Should -Not -BeNullOrEmpty
        (Split-Path -Path $repoRoot -Leaf) | Should -Be 'finops-toolkit'
        (Join-Path $repoRoot 'package.json') | Should -Exist
        $commandPath | Should -Exist
        $workflowPath | Should -Exist
    }
}
