---
layout: default
title: Agent plugin
browser: FinOps toolkit agent plugin - Automate your FinOps efforts
nav_order: 65
description: 'The FinOps toolkit agent plugin brings AI-powered cloud financial management to Claude Code and GitHub Copilot CLI.'
permalink: /agent-plugin
#customer intent: As a Finops practitioner, I need to learn about the FinOps toolkit agent plugin
---

<span class="fs-9 d-block mb-4">FinOps toolkit agent plugin</span>
Bring AI-powered cloud financial management to Claude Code and GitHub Copilot CLI.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#install">Install</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/agent-plugin/finops-toolkit-agent-plugin-overview">Documentation</a>

---

The FinOps toolkit agent plugin pairs role-specific agents, ready-to-run commands, and a FinOps hubs query skill with a read-only Azure MCP server, so you can analyze cost data, review recommendations, and manage FinOps hubs without leaving your terminal.

<div id="whats-new" class="ftk-new">
    <h3>What's new in August 2026<span class="ftk-version">v15</span></h3>
    <p>
        The FinOps toolkit agent plugin is new this release: a shared plugin for Claude Code and GitHub Copilot CLI with 5 agents (CFO, FinOps practitioner, database query, hubs agent, and Azure capacity manager), 4 commands, a FinOps hubs KQL skill, and a read-only Azure MCP server.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>

<a name="features"></a>

## What's included

- **Agents** – Chief Financial Officer, FinOps practitioner, FinOps hubs database query, FinOps hubs agent, and Azure capacity manager.
- **Commands** – `/ftk-hubs-connect`, `/ftk-hubs-healthCheck`, `/ftk-mom-report`, and `/ftk-ytd-report`.
- **Skill** – A FinOps hubs KQL skill with task routing, a pre-built query catalog, and schema guidance.
- **MCP server** – A read-only [Azure MCP server](https://github.com/Azure/azure-mcp) scoped to the Kusto namespace for querying FinOps hubs data.

<a name="install"></a>

## Install

```bash
# Claude Code
claude plugin add microsoft/finops-toolkit

# GitHub Copilot CLI
copilot plugin install microsoft/finops-toolkit
```

<br>

## Learn more

[Read the full documentation](https://learn.microsoft.com/cloud-computing/finops/toolkit/agent-plugin/finops-toolkit-agent-plugin-overview) for required permissions and setup details.
