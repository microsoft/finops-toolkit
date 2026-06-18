# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:ClaudePlugin = Join-Path $script:RepoRoot 'src/templates/claude-plugin'
    $script:CopilotPlugin = Join-Path $script:RepoRoot 'src/templates/copilot-plugin'

    function Get-ClaudeAgentName {
        param([System.IO.FileInfo]$File)
        [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    }

    function Get-CopilotAgentName {
        param([System.IO.FileInfo]$File)
        $File.Name -replace '\.agent\.md$', ''
    }

    function Get-CommandName {
        param(
            [System.IO.FileInfo]$File,
            [string]$CommandsRoot
        )
        $relativePath = [System.IO.Path]::GetRelativePath($CommandsRoot, $File.FullName).Replace('\', '/')
        '/' + ($relativePath -replace '\.md$', '')
    }
}

Describe 'Agent plugin consistency' {
    It 'Ships the same agent set in Claude and Copilot plugins' {
        $claudeAgents = Get-ChildItem (Join-Path $script:ClaudePlugin 'agents') -Filter '*.md' |
            ForEach-Object { Get-ClaudeAgentName $_ } |
            Sort-Object

        $copilotAgents = Get-ChildItem (Join-Path $script:CopilotPlugin 'agents') -Filter '*.agent.md' |
            ForEach-Object { Get-CopilotAgentName $_ } |
            Sort-Object

        $copilotAgents | Should -Be $claudeAgents
    }

    It 'Ships the same command set in Claude and Copilot plugins' {
        $claudeCommands = Get-ChildItem (Join-Path $script:ClaudePlugin 'commands') -Filter '*.md' -Recurse |
            ForEach-Object { Get-CommandName $_ (Join-Path $script:ClaudePlugin 'commands') } |
            Sort-Object

        $copilotCommands = Get-ChildItem (Join-Path $script:CopilotPlugin 'commands') -Filter '*.md' -Recurse |
            ForEach-Object { Get-CommandName $_ (Join-Path $script:CopilotPlugin 'commands') } |
            Sort-Object

        $copilotCommands | Should -Be $claudeCommands
    }

    It 'Documents every shipped Copilot command with its nested slash namespace' {
        $readme = Get-Content (Join-Path $script:CopilotPlugin 'README.md') -Raw
        $commands = Get-ChildItem (Join-Path $script:CopilotPlugin 'commands') -Filter '*.md' -Recurse |
            ForEach-Object { Get-CommandName $_ (Join-Path $script:CopilotPlugin 'commands') }

        foreach ($command in $commands)
        {
            $readme | Should -Match ([regex]::Escape($command))
        }
    }
}
