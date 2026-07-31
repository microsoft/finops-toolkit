# FinOps Toolkit agent plugin

This plugin is the canonical source for the FinOps Toolkit agent plugins.

## Distribution and runtime conventions

- `plugins/microsoft-finops-toolkit` is the marketplace source used by both marketplace manifests.
- `.plugin` is the repository-level discovery pointer for the plugin manifest.
- GitHub Copilot CLI declares agents and `.mcp.json` in `plugin.json`; Claude Code discovers those assets from the plugin root and declares its Claude-specific output style in `.claude-plugin/plugin.json`.
- The Azure MCP server uses `@azure/mcp@latest` so the plugin receives compatible Azure MCP updates without a separate plugin release. It is limited to the Kusto namespace and read-only operations.

For setup and usage:

- Skill overview and task routing: `./skills/finops-toolkit/SKILL.md`
- Querying and workflows: `./skills/finops-toolkit/README.md`
- MCP server configuration: `./.mcp.json`
