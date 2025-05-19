---
title: Configure AI agents for FinOps hubs
description: Learn how to configure an AI agent to connect to your FinOps hub instance.
author: flanakin
ms.author: micflan
ms.date: 05/16/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want to connect an AI agent to my FinOps hub instance so that I can analyze my costs.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure and use AI agents

Artificial Intelligence (AI) agents are revolutionizing the way people and applications engage with data by integrating large language models (LLMs) with external tools and databases. Agents streamline complex workflows, improve the accuracy of information retrieval, and provide an intuitive, natural language interface to your data. This article describes how to train an AI agent to understand [FinOps](../../overview.md), the [FinOps Open Cost and Usage Specification (FOCUS)](../../focus/what-is-focus.md), and connect to data in a FinOps hub instance.

<br>

## Prerequisites

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- Database viewer or greater access to the Data Explorer **Hub** and **Ingestion** databases. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).

<br>

## Configure GitHub Copilot in VS Code

The simplest way to get started with an AI-powered FinOps hub is with [GitHub Copilot Agent mode](https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode).

1. Sign up for [GitHub Copilot Free](https://github.com/settings/copilot?utm_source=ftk-finops-hubs-docs-configureai&utm_medium=first&utm_campaign=ftk-finops-hubs-docs-configureai) if you don't have GitHub Copilot.
2. Install [Node.js](https://nodejs.org/en/download) 20 or later.
3. Install [VS Code](https://code.visualstudio.com).
4. Open a workspace and save GitHub Copilot instructions for FinOps hubs:

   1. Open VS Code.
   2. Open a folder or workspace where you want to connect to your FinOps hub instance.
   3. Create a `.github` folder at the root of the workspace.
   4. Download the [GitHub Copilot instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hubs-copilot-instructions.md) and save it to the `.github` folder as `copilot-instructions.md`.

5. Install GitHub Copilot and Azure MCP:

   ### [VS Code](#tab/vscode)

   - [Install GitHub Copilot](vscode:extension/GitHub.copilot)
   - [Install GitHub Copilot Chat](vscode:extension/GitHub.copilot-chat)
   - [Install Azure MCP server for VS Code](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20MCP%20Server&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40azure%2Fmcp%40latest%22%2C%22server%22%2C%22start%22%5D%7D)

   ### [VS Code Insiders](#tab/vscode-insiders)

   - [Install GitHub Copilot](vscode-insiders:extension/GitHub.copilot)
   - [Install GitHub Copilot Chat](vscode-insiders:extension/GitHub.copilot-chat)
   - [Install Azure MCP server for VS Code](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20MCP%20Server&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40azure%2Fmcp%40latest%22%2C%22server%22%2C%22start%22%5D%7D&quality=insiders)

For details about the Azure MCP server, see [Azure MCP on GitHub](https://github.com/Azure/azure-mcp?tab=readme-ov-file#-azure-mcp-server).

<br>

## Connect from other AI platforms

FinOps hubs use [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) to connect to and query your data in Azure Data Explorer using the Azure MCP server. Besides GitHub Copilot, there are many popular [clients that support MCP servers](https://modelcontextprotocol.io/clients), like Claude, Continue, and more. While we have not tested instructions with other clients, you may be able to reuse some or all of the [AI instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hubs-copilot-instructions.md) with other clients. Try the instructions with clients you use and [create a change request](https://aka.ms/ftk/ideas) or [submit a pull request](https://github.com/microsoft/finops-toolkit/pulls) if you discover any gaps or improvements.

To learn more about the Azure MCP server, see [Azure MCP on GitHub](https://github.com/Azure/azure-mcp?tab=readme-ov-file#-azure-mcp-server).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.10/bladeName/Hubs/featureName/ConfigureAI)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure workbooks](/azure/azure-monitor/visualize/workbooks-overview)

Related solutions:

- [FinOps hubs](finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
