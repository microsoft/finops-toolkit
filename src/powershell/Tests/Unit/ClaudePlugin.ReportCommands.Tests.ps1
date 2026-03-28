# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $momReportPath = Join-Path $repoRoot 'src/templates/claude-plugin/commands/ftk/mom-report.md'
    $ytdReportPath = Join-Path $repoRoot 'src/templates/claude-plugin/commands/ftk/ytd-report.md'
    $testFilePath = Join-Path $repoRoot 'src/powershell/Tests/Unit/ClaudePlugin.ReportCommands.Tests.ps1'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-AllMatches
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Pattern
        )

        return @([regex]::Matches($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | ForEach-Object {
                $_.Value.Trim()
            })
    }

    function Get-UniqueKnowledgeRoots
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content
        )

        return @(Get-AllMatches -Content $Content -Pattern 'ftk/(?:knowledge|research)/' | ForEach-Object {
                $_.TrimEnd('/')
            } | Sort-Object -Unique)
    }

    function Get-QueryRoots
    {
        param(
            [Parameter(Mandatory)]
            [string[]]$Paths
        )

        return @($Paths | ForEach-Object {
                if ($_ -match '^(ftk/(?:knowledge/)?queries)/')
                {
                    $Matches[1]
                }
            } | Sort-Object -Unique)
    }

    function Assert-CanonicalKnowledgeReferences
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Name
        )

        @(
            'ftk/knowledge/queries/INDEX.md',
            'ftk/knowledge/analysis/finops-hubs.md',
            'ftk/knowledge/core/finops-framework.md',
            'ftk/knowledge/core/capabilities.md'
        ) | ForEach-Object {
            $Content | Should -Match ([regex]::Escape($_)) -Because "$Name should reference canonical knowledge asset $_"
        }
    }
}

Describe 'Claude plugin report command markdown consistency' {
    # // T-1.8: RTM FR-5.3
    It 'FR5_3_AC1_ReportCommands_UseCommonKnowledgeRoot' {
        $momContent = Get-TestFileContent -Path $momReportPath
        $ytdContent = Get-TestFileContent -Path $ytdReportPath

        $momKnowledgeRoots = @(Get-UniqueKnowledgeRoots -Content $momContent)
        $ytdKnowledgeRoots = @(Get-UniqueKnowledgeRoots -Content $ytdContent)

        $momKnowledgeRoots.Count | Should -Be 1 -Because 'mom-report should use a single reusable knowledge-root taxonomy'
        $ytdKnowledgeRoots.Count | Should -Be 1 -Because 'ytd-report should use a single reusable knowledge-root taxonomy'
        $momKnowledgeRoots[0] | Should -BeExactly $ytdKnowledgeRoots[0] -Because 'report commands should share the same reusable knowledge-root taxonomy'
    }

    # // T-1.8: RTM FR-5.3
    It 'FR5_3_AC2_ReportCommands_ExposeDeterministicCheckpoints' {
        $cases = @(
            @{ Name = 'mom-report'; Content = Get-TestFileContent -Path $momReportPath },
            @{ Name = 'ytd-report'; Content = Get-TestFileContent -Path $ytdReportPath }
        )

        foreach ($case in $cases)
        {
            $case.Content | Should -Match '(?im)^##\s+\d+\s*-\s*.*setup.*$' -Because "$($case.Name) should expose a setup checkpoint or phase heading"
            $case.Content | Should -Match '(?im)^##\s+\d+\s*-\s*.*plan.*$' -Because "$($case.Name) should expose a plan checkpoint or phase heading"
            $case.Content | Should -Match '(?im)^##\s+\d+\s*-\s*.*execute.*$' -Because "$($case.Name) should expose an execute checkpoint or phase heading"
            $case.Content | Should -Match '(?im)^##\s+\d+\s*-\s*.*reflect.*$' -Because "$($case.Name) should expose a reflect checkpoint or phase heading"
        }
    }

    # // T-1.8: RTM FR-5.3
    It 'FR5_3_AC3_ReportCommands_StoragePathsStayConsistent' {
        $cases = @(
            @{ Name = 'mom-report'; Content = Get-TestFileContent -Path $momReportPath },
            @{ Name = 'ytd-report'; Content = Get-TestFileContent -Path $ytdReportPath }
        )

        foreach ($case in $cases)
        {
            $planPaths = Get-AllMatches -Content $case.Content -Pattern 'ftk/planning/[^\s`]+\.md'
            $resultPaths = Get-AllMatches -Content $case.Content -Pattern 'ftk/results/[^\s`]+\.md'
            $notesPaths = Get-AllMatches -Content $case.Content -Pattern 'ftk/notes/[^\s`]+\.md'
            $queryPaths = Get-AllMatches -Content $case.Content -Pattern 'ftk/(?:knowledge/)?queries/[^\s`]+\.md'

            $planPaths.Count | Should -BeGreaterThan 1 -Because "$($case.Name) should define both planning and progress markdown paths"
            $resultPaths.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should define a results markdown path"
            $notesPaths.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should define a notes markdown path"
            $queryPaths.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should define reusable query markdown paths"

            foreach ($planPath in $planPaths)
            {
                $planPath | Should -Match '^ftk/planning/' -Because "$($case.Name) planning assets should stay under ftk/planning"
                $planPath | Should -Match '\[environment-name\]' -Because "$($case.Name) planning assets should preserve the environment placeholder"
                $planPath | Should -Match '\[date\]' -Because "$($case.Name) planning assets should preserve the date placeholder"
            }

            foreach ($resultPath in $resultPaths)
            {
                $resultPath | Should -Match '^ftk/results/' -Because "$($case.Name) report output should stay under ftk/results"
                $resultPath | Should -Match '\[environment-name\]' -Because "$($case.Name) results path should preserve the environment placeholder"
                $resultPath | Should -Match '\[date\]' -Because "$($case.Name) results path should preserve the date placeholder"
            }

            foreach ($notesPath in $notesPaths)
            {
                $notesPath | Should -Match '^ftk/notes/' -Because "$($case.Name) troubleshooting notes should stay under ftk/notes"
            }

            $queryRoots = @(Get-QueryRoots -Paths $queryPaths)
            $queryRoots.Count | Should -Be 1 -Because "$($case.Name) query references should stay under one reusable query root"
            foreach ($queryPath in $queryPaths)
            {
                $queryPath.StartsWith("$($queryRoots[0])/") | Should -BeTrue -Because "$($case.Name) query references should stay under $($queryRoots[0])"
            }
        }
    }

    # // T-1.8: RTM FR-5.3
    It 'FR5_3_AC4_ReportCommands_ReferenceCanonicalKnowledgeAssets' {
        $cases = @(
            @{ Name = 'mom-report'; Content = Get-TestFileContent -Path $momReportPath },
            @{ Name = 'ytd-report'; Content = Get-TestFileContent -Path $ytdReportPath }
        )

        foreach ($case in $cases)
        {
            Assert-CanonicalKnowledgeReferences -Content $case.Content -Name $case.Name
        }
    }

    # // T-1.8: RTM NFR-3
    It 'FR5_3_AC5_ReportCommands_TestRunsInRepoEnvironment' {
        $repoRoot | Should -Not -BeNullOrEmpty
        (Split-Path -Path $repoRoot -Leaf) | Should -Be 'finops-toolkit'
        (Join-Path $repoRoot 'package.json') | Should -Exist
        $momReportPath | Should -Exist
        $ytdReportPath | Should -Exist
        $testFilePath | Should -Exist
    }
}
