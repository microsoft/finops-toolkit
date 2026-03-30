# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $commandPath = Join-Path $repoRoot 'src/templates/claude-plugin/commands/ftk/hubs-healthCheck.md'
    $workflowPath = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references/workflows/ftk-hubs-healthCheck.md'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Remove-FrontMatter
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content
        )

        return [regex]::Replace(
            $Content,
            '\A---\r?\n.*?\r?\n---\r?\n',
            '',
            [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    function Get-NormalizedContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content
        )

        return ($Content -replace "`r`n", "`n").Trim()
    }

    function Get-MarkdownSection
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Heading,

            [string]$NextHeading
        )

        $lines = (Get-NormalizedContent -Content $Content) -split "`n"
        $startIndex = [array]::IndexOf($lines, $Heading)
        $startIndex | Should -BeGreaterThan -1 -Because "$Heading should exist"

        if ([string]::IsNullOrEmpty($NextHeading))
        {
            return ($lines[$startIndex..($lines.Length - 1)] -join "`n").Trim()
        }

        $endIndex = [array]::IndexOf($lines, $NextHeading)
        $endIndex | Should -BeGreaterThan $startIndex -Because "$NextHeading should exist after $Heading"

        return ($lines[$startIndex..($endIndex - 1)] -join "`n").Trim()
    }
}

Describe 'Claude plugin hubs-healthCheck markdown consistency' {
    # // T-1.7: RTM FR-5.2
    It 'FR5_2_AC1_HubsHealthCheck_VersionGuidanceMatches' {
        $commandContent = Remove-FrontMatter -Content (Get-TestFileContent -Path $commandPath)
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandVersionSection = Get-MarkdownSection -Content $commandContent -Heading '## Step 1: Check the latest released FinOps hub version' -NextHeading '## Step 2: Check the latest data refresh/update date'
        $workflowVersionSection = Get-MarkdownSection -Content $workflowContent -Heading '## Step 1: Check the latest released FinOps hub version' -NextHeading '## Step 2: Check the latest data refresh/update date'

        $commandVersionSection | Should -BeExactly $workflowVersionSection

        @(
            'https://aka.ms/finops/hubs/deploy',
            'https://aka.ms/finops/hubs/deploy/gov',
            'https://aka.ms/finops/hubs/deploy/china'
        ) | ForEach-Object {
            $commandVersionSection | Should -Match ([regex]::Escape($_))
            $workflowVersionSection | Should -Match ([regex]::Escape($_))
        }
    }

    # // T-1.7: RTM FR-5.2
    It 'FR5_2_AC2_HubsHealthCheck_StaleDataGuidanceMatches' {
        $commandContent = Remove-FrontMatter -Content (Get-TestFileContent -Path $commandPath)
        $workflowContent = Get-TestFileContent -Path $workflowPath

        $commandStaleDataSection = Get-MarkdownSection -Content $commandContent -Heading '## Step 2: Check the latest data refresh/update date'
        $workflowStaleDataSection = Get-MarkdownSection -Content $workflowContent -Heading '## Step 2: Check the latest data refresh/update date'

        $commandStaleDataSection | Should -BeExactly $workflowStaleDataSection
        $commandStaleDataSection | Should -Match 'data may be stale'
        $workflowStaleDataSection | Should -Match 'data may be stale'

        @(
            'https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/exports',
            'https://adf.azure.com/monitoring/pipelineruns',
            'https://learn.microsoft.com/cloud-computing/finops/toolkit/help/errors',
            'https://learn.microsoft.com/cloud-computing/finops/toolkit/help/troubleshooting'
        ) | ForEach-Object {
            $commandStaleDataSection | Should -Match ([regex]::Escape($_))
            $workflowStaleDataSection | Should -Match ([regex]::Escape($_))
        }
    }

    # // T-1.7: RTM NFR-3
    It 'FR5_2_AC3_HubsHealthCheck_TestRunsInRepoEnvironment' {
        $repoRoot | Should -Not -BeNullOrEmpty
        (Split-Path -Path $repoRoot -Leaf) | Should -Be 'finops-toolkit'
        (Join-Path $repoRoot 'package.json') | Should -Exist
        $commandPath | Should -Exist
        $workflowPath | Should -Exist
        $PSCommandPath | Should -Exist
    }
}
