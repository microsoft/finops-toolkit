# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $script:Plugin = Join-Path $script:RepoRoot 'src/templates/agent-plugin'
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

    It 'Uses consistent shared manifest metadata and intentional platform-specific fields' {
        $root = Get-Content (Join-Path $script:Plugin 'plugin.json') -Raw | ConvertFrom-Json
        $claude = Get-Content (Join-Path $script:Plugin '.claude-plugin/plugin.json') -Raw | ConvertFrom-Json

        $root.description | Should -Be $claude.description
        $root.version | Should -Be $claude.version
        $root.license | Should -Be $claude.license
        $root.repository | Should -Be $claude.repository
        $root.commands.TrimStart('./') | Should -Be $claude.commands.TrimStart('./')
        $root.skills[0].TrimStart('./') | Should -Be $claude.skills[0].TrimStart('./')
        $root.agents | Should -Be './agents/'
        $root.mcpServers | Should -Be '.mcp.json'
        $claude.agents | Should -BeNullOrEmpty
        $claude.mcpServers | Should -BeNullOrEmpty
        $claude.outputStyles | Should -Be './output-styles/'
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

    It 'Requires explicit invocation for commands that access hub data or write reports' {
        foreach ($command in @('hubs-connect.md', 'hubs-health-check.md', 'mom-report.md', 'ytd-report.md'))
        {
            $content = Get-Content (Join-Path $script:Plugin "commands/ftk/$command") -Raw
            $content | Should -Match '(?m)^disable-model-invocation:\s*true\s*$'
        }
    }

    It 'Resolves linked template content from its full source path' {
        $buildScript = Get-Content (Join-Path $script:RepoRoot 'src/scripts/Build-Toolkit.ps1') -Raw
        $buildScript | Should -Match '\$target = Join-Path \(Split-Path -Path \$source\.FullName -Parent\) \$target'
    }

    It 'Uses direct slash commands instead of duplicate workflow references' {
        Join-Path $script:Plugin 'commands/ftk/hubs-connect.md' | Should -Exist
        Join-Path $script:Plugin 'commands/ftk/hubs-health-check.md' | Should -Exist
        Join-Path $script:Plugin 'skills/finops-toolkit/references/workflows/ftk-hubs-connect.md' | Should -Not -Exist
        Join-Path $script:Plugin 'skills/finops-toolkit/references/workflows/ftk-hubs-health-check.md' | Should -Not -Exist

        $content = (Get-ChildItem $script:Plugin -Recurse -File | Get-Content -Raw) -join [Environment]::NewLine
        $content | Should -Not -Match 'hubs-healthCheck|ftk-hubs-healthCheck|references/workflows/ftk-hubs-(connect|health-check)'
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

    It 'Bundles only Markdown Learn documentation' {
        $bundle = Join-Path $TestDrive 'agent-plugin'
        New-Item (Join-Path $bundle 'skills/finops-toolkit') -ItemType Directory -Force | Out-Null

        & (Join-Path $script:RepoRoot 'src/scripts/Build-AgentPlugin.ps1') -DestDir $bundle

        $docs = Get-ChildItem (Join-Path $bundle 'skills/finops-toolkit/references/docs-mslearn') -File -Recurse
        $docs.Count | Should -BeGreaterThan 0
        $docs.Extension | Select-Object -Unique | Should -Be @('.md')
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
        $pluginRoot = Join-Path $script:RepoRoot '.plugin'
        if (-not (Test-Path $pluginRoot -PathType Container))
        {
            $pluginRoot = Join-Path $script:RepoRoot (Get-Content $pluginRoot -Raw).Trim()
        }

        Join-Path $pluginRoot 'plugin.json' | Should -Exist
    }

    It 'Uses repository-root-relative marketplace sources' {
        $marketplaces = @{
            '.github/plugin/marketplace.json' = './plugins/microsoft-finops-toolkit'
            '.claude-plugin/marketplace.json' = './plugins/microsoft-finops-toolkit'
        }

        foreach ($marketplace in $marketplaces.Keys)
        {
            $json = Get-Content (Join-Path $script:RepoRoot $marketplace) -Raw | ConvertFrom-Json
            $entry = $json.plugins | Where-Object { $_.name -eq 'microsoft-finops-toolkit' }
            $entry.source | Should -Be $marketplaces[$marketplace]
        }
    }
}