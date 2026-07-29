# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:Plugin = Join-Path $script:RepoRoot 'src/templates/agent-plugin'
    $script:PluginSource = './plugins/microsoft-finops-toolkit'
}

Describe 'Agent plugin manifest' {
    It 'Ships a root plugin.json for GitHub Copilot CLI' {
        Join-Path $script:Plugin 'plugin.json' | Should -Exist
    }

    It 'Ships a .claude-plugin/plugin.json for Claude' {
        Join-Path $script:Plugin '.claude-plugin/plugin.json' | Should -Exist
    }

    It 'Uses a consistent plugin name across both manifests' {
        $root = Get-Content (Join-Path $script:Plugin 'plugin.json') -Raw | ConvertFrom-Json
        $claude = Get-Content (Join-Path $script:Plugin '.claude-plugin/plugin.json') -Raw | ConvertFrom-Json
        $root.name | Should -Be $claude.name
    }

    It 'Points the agents field at a directory that exists' {
        $root = Get-Content (Join-Path $script:Plugin 'plugin.json') -Raw | ConvertFrom-Json
        Join-Path $script:Plugin ($root.agents -replace '^\./', '') | Should -Exist
    }

    It 'Loads MCP servers from .mcp.json in the plugin root' {
        $root = Get-Content (Join-Path $script:Plugin 'plugin.json') -Raw | ConvertFrom-Json
        $claude = Get-Content (Join-Path $script:Plugin '.claude-plugin/plugin.json') -Raw | ConvertFrom-Json

        $root.mcpServers | Should -Be '.mcp.json'
        $claude.mcpServers | Should -BeNullOrEmpty
        $claude.agents | Should -BeNullOrEmpty
        Join-Path $script:Plugin '.mcp.json' | Should -Exist
    }

    It 'Uses unpinned Azure MCP latest package in .mcp.json' {
        $mcp = Get-Content (Join-Path $script:Plugin '.mcp.json') -Raw | ConvertFrom-Json
        $args = $mcp.mcpServers.'azure-mcp-server'.args
        $packageArg = $args | Where-Object { $_ -like '@azure/mcp@*' } | Select-Object -First 1

        $packageArg | Should -Not -BeNullOrEmpty
        $packageArg | Should -Be '@azure/mcp@latest'
    }
}

Describe 'Agent plugin components' {
    It 'Ships agent definitions as NAME.agent.md files' {
        $agents = Get-ChildItem (Join-Path $script:Plugin 'agents') -Filter '*.agent.md'
        $agents.Count | Should -BeGreaterThan 0
    }

    It 'Gives every agent a name and description in front matter' {
        Get-ChildItem (Join-Path $script:Plugin 'agents') -Filter '*.agent.md' | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '(?ms)^---\s.*^name:\s*\S.*^description:\s*\S.*^---'
        }
    }

    It 'Ships slash commands under the ftk namespace' {
        $commands = Get-ChildItem (Join-Path $script:Plugin 'commands/ftk') -Filter '*.md'
        $commands.Count | Should -BeGreaterThan 0
    }

    It 'Uses the kebab-case health-check command name throughout the plugin' {
        Join-Path $script:Plugin 'commands/ftk/hubs-health-check.md' | Should -Exist
        Join-Path $script:Plugin 'skills/finops-toolkit/references/workflows/ftk-hubs-health-check.md' | Should -Exist

        $content = (Get-ChildItem $script:Plugin -Recurse -File | Get-Content -Raw) -join [Environment]::NewLine
        $content | Should -Not -Match 'hubs-healthCheck|ftk-hubs-healthCheck'
    }

    It 'Does not reference the deprecated Azure MCP command name' {
        $content = (Get-ChildItem $script:Plugin -Recurse -File | Get-Content -Raw) -join [Environment]::NewLine
        $content | Should -Not -Match '#?azmcp-kusto-query'
    }

    It 'Ships the finops-toolkit skill' {
        Join-Path $script:Plugin 'skills/finops-toolkit/SKILL.md' | Should -Exist
    }

    It 'Documents required kusto_query parameters in skill docs' {
        foreach ($doc in @('skills/finops-toolkit/SKILL.md', 'skills/finops-toolkit/README.md'))
        {
            $content = Get-Content (Join-Path $script:Plugin $doc) -Raw
            $content | Should -Match 'azure-mcp-server'
            $content | Should -Match 'kusto_query'
            $content | Should -Match '"subscription"\s*:'
        }
    }

    It 'Ships plugin root README for marketplace onboarding' {
        Join-Path $script:Plugin 'README.md' | Should -Exist
    }
}

Describe 'Deprecated azure-cost-management skill' {
    It 'No longer ships the azure-cost-management skill' {
        Join-Path $script:Plugin 'skills/azure-cost-management' | Should -Not -Exist
    }

    It 'Is not referenced by any plugin manifest' {
        foreach ($manifest in @('plugin.json', '.claude-plugin/plugin.json'))
        {
            $content = Get-Content (Join-Path $script:Plugin $manifest) -Raw
            $content | Should -Not -Match 'azure-cost-management'
        }
    }
}

Describe 'Plugin discovery and marketplaces' {
    It 'Resolves the .plugin discovery pointer to a plugin manifest' {
        Join-Path $script:RepoRoot '.plugin/plugin.json' | Should -Exist
    }

    It 'Points every marketplace source at the plugin directory' {
        foreach ($marketplace in @('.github/plugin/marketplace.json', '.claude-plugin/marketplace.json'))
        {
            $json = Get-Content (Join-Path $script:RepoRoot $marketplace) -Raw | ConvertFrom-Json
            $entry = $json.plugins | Where-Object { $_.name -eq 'microsoft-finops-toolkit' }
            $entry.source | Should -Be $script:PluginSource
        }
    }
}