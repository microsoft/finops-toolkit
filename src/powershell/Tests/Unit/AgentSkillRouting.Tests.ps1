# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Agent skill routing' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
        $script:SkillRoot = Join-Path $script:RepoRoot 'src/templates/agent-skills'
        $script:PluginSkillRoot = Join-Path $script:RepoRoot 'src/templates/agent-plugin/skills'

        # A skill only counts as shipped when it has content. An empty directory
        # survives on disk but is absent from git, so it reaches nobody.
        function Get-ShippedSkill {
            param([string]$Root)
            if (-not (Test-Path $Root)) { return @() }
            Get-ChildItem $Root -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
            Select-Object -ExpandProperty Name
        }

        $script:Shipped = @(Get-ShippedSkill $script:SkillRoot) + @(Get-ShippedSkill $script:PluginSkillRoot)

        $script:SkillDocs = @(
            Get-ChildItem $script:SkillRoot -Recurse -Include '*.md' -File -ErrorAction SilentlyContinue
        )
    }

    It 'Finds skill documentation to check' {
        $script:SkillDocs.Count | Should -BeGreaterThan 0
        $script:Shipped.Count | Should -BeGreaterThan 0
    }

    It 'Does not route to a skill directory that ships no SKILL.md' {
        # Backtick-quoted kebab-case names are how the docs reference sibling skills.
        $referenced = $script:SkillDocs |
        Select-String -Pattern '`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Value.Trim('`') } |
        Sort-Object -Unique

        # Only names that look like a skill folder are routing targets; the same
        # pattern also matches things like file names and CLI flags.
        $candidates = @($referenced | Where-Object { $_ -match '^(azure|finops|cost|unit|anomaly|forecasting|focus|sustainability|power|rate)-' })

        $dead = @($candidates | Where-Object { $script:Shipped -notcontains $_ })
        $dead | Should -BeNullOrEmpty -Because "every routed skill must ship a SKILL.md (dead: $($dead -join ', '))"
    }

    It 'Does not reference the deprecated azure-cost-management skill' {
        $hits = @($script:SkillDocs | Select-String -Pattern 'azure-cost-management' -SimpleMatch)
        $hits | Should -BeNullOrEmpty -Because 'AgentPlugins.Tests.ps1 asserts that skill no longer ships'
    }
}
