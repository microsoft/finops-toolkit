---
title: Configure AI agents for FinOps hubs
description: Learn how to configure an AI agent to connect to your FinOps hub instance.
author: flanakin
ms.author: micflan
ms.date: 06/05/2025
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
   4. Download the [GitHub Copilot instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot.zip) and extract the contents to the `.github` folder.

5. Install GitHub Copilot and Azure MCP:

   <!-- ### [VS Code](#tab/vscode) -->

   - [Install GitHub Copilot](vscode:extension/GitHub.copilot)
   - [Install GitHub Copilot Chat](vscode:extension/GitHub.copilot-chat)
   - [Install Azure MCP server for VS Code](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20MCP%20Server&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40azure%2Fmcp%40latest%22%2C%22server%22%2C%22start%22%5D%7D)

   <!--
   ### [VS Code Insiders](#tab/vscode-insiders)

   - [Install GitHub Copilot](vscode-insiders:extension/GitHub.copilot)
   - [Install GitHub Copilot Chat](vscode-insiders:extension/GitHub.copilot-chat)
   - [Install Azure MCP server for VS Code](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20MCP%20Server&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22%40azure%2Fmcp%40latest%22%2C%22server%22%2C%22start%22%5D%7D&quality=insiders)
   -->

For details about the Azure MCP server, see [Azure MCP on GitHub](https://github.com/Azure/azure-mcp?tab=readme-ov-file#-azure-mcp-server).

<br>

## Connect from other AI platforms

FinOps hubs use [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) to connect to and query your data in Azure Data Explorer using the Azure MCP server. Besides GitHub Copilot, there are many popular [clients that support MCP servers](https://modelcontextprotocol.io/clients), like Claude, Continue, and more. While we have not tested instructions with other clients, you may be able to reuse some or all of the [AI instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot.zip) with other clients. Try the instructions with clients you use and [create a change request](https://aka.ms/ftk/ideas) or [submit a pull request](https://github.com/microsoft/finops-toolkit/pulls) if you discover any gaps or improvements.

To learn more about the Azure MCP server, see [Azure MCP on GitHub](https://github.com/Azure/azure-mcp?tab=readme-ov-file#-azure-mcp-server).

<br>

## Query FinOps hubs with AI

After you install the Azure MCP server and configure your AI client, use the following sample steps to connect and query your FinOps hub instance. These steps are based on GitHub Copilot Agent mode with the [AI instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot.zip). They may work differently in other clients.

### Connect to your hub

If you're using GitHub Copilot, start by opening Chat in Agent mode:

- [Open Agent mode in VS Code](vscode://GitHub.Copilot-Chat/chat?mode=agent&referrer=ftk-finops-hubs-docs-configureai)
<!-- - [Open Agent mode in VS Code Insiders](vscode-insiders://GitHub.Copilot-Chat/chat?mode=agent&referrer=ftk-finops-hubs-docs-configureai) -->

The AI instructions for FinOps hubs are preconfigured for FinOps tasks and already know how to find and connect to your FinOps hub instance. To start, ask to connect to your FinOps hub instance:

- [`Connect to my hub in VS Code`](vscode://GitHub.Copilot-Chat/chat?mode=agent&referrer=ftk-finops-hubs-docs-configureai&query=Connect+to+my+hub)
<!-- - [`Connect to my hub in VS Code Insiders`](vscode-insiders://GitHub.Copilot-Chat/chat?mode=agent&referrer=ftk-finops-hubs-docs-configureai&query=Connect+to+my+hub) -->

```plaintext
/ftk-hubs-connect
```

Copilot should automatically connect to your FinOps hub instance. If you have multiple, you should see a list of them. You can ask to connect to them by resource group, hub name, cluster name, cluster short URI (cluster name and location), or the full cluster URI.

When connecting to your hub, you may get prompted to use your credentials. Select **Continue**.

The rest of the steps will use the FinOps capabilities to demonstrate an example of the type of questions you can ask.

### Data ingestion: Get last refresh time

Your queries are only as complete as your data. Start by checking when the data was last loaded into your FinOps hub instance. This should be part of the first connection step. You can also ask directly:

```plaintext
When was my data last refreshed?
```

Cost Management exports typically run every 24 hours. If using [managed exports](configure-scopes.md#configure-managed-exports), you can configure the schedule to run more frequently. If data is not up-to-date, check Cost Management exports.

### Allocation: Cost by resource group

The most common way to allocate costs in Azure is by resource group. To identify the resource groups with the most cost, ask:

```plaintext
What are the top resource groups by cost?
```

You can also ask about subscriptions (SubAccountName in FOCUS), invoice sections, or even tag.

### Reporting + analytics: Biggest changes in cost trends

The last two examples were fairly straightforward. Let's try something a little more complex by asking it to analyze trends over time. Copilot will do some research first to devise a plan. And given the complexity, Copilot may also ask you to review and approve a KQL query that it will execute to perform the analysis.

```plaintext
Analyze cloud service spending trends over the past 3 months. Show the top 5 services with the highest increase and top 5 with the highest decrease in cost, including percentage changes.
```

If asked to approve the query, you can tell Copilot to tweak or execute the query based on your needs.

Given the complexity of this one, you may want to ask for the query so you can run it yourself. You can always run the same queries from the [Data Explorer portal](https://dataexplorer.azure.com). Or ask Copilot to give you a link to run the query:

```plaintext
Give me a link to run this query myself.
```

### Anomaly management: Identify anomalies

Now let's look for anomalies:

```plaintext
Are there any unusual spikes in cost over the last 3 months?
```

You should get a summary of what was found, whether there were anomalies or not. This is another place where you may want to ask for a link to the query to see the details for yourself. You can also ask for the query or even have it explain the query.

```plaintext
Show me the query with comments on each line to explain what the line does.
```

This should use the built-in Data Explorer anomaly detection functionality. Ask Copilot to explain anything you don't understand. This can be a great opportunity to learn KQL. Tell Copilot to change the query or tweak it yourself to suit your needs.

In my case, it added empty lines between each commented line. To run this, you will need to select all the text in the Data Explorer query editor and select **Run**.

### Forecasting: Project end of month costs

Anomaly detection is about predicting what the cost of a day would be based on a forecast. So if Copilot can help you analyze historical forecasts with built-in Data Explorer capabilities, then you can also project out future costs:

```plaintext
Show me the cost for last month, this month, and the forecasted cost by the end of the month for the subscriptions that have the highest cost this month.
```

### Rate optimization: Quantifying savings

Next, let's look at savings. Let's look for savings from both negotiated discounts and commitment discounts, and quantify Effective Savings Rate (ESR) to give us an idea of how we're doing with our rate optimization efforts:

```plaintext
What was my cost last month, how much did I save on commitment discounts, and how much did I save with my negotiated discounts? Show my total savings and effective savings rate.
```

### Explore your data

These are just a few examples of the types of requests you can get answers to today. Ask your own questions and test how AI can help you. Just remember that AI is limited to what it's taught and the data it has available. If you find a scenario that is not covered or could be improved, please share the prompt, what response you received, and how you would like to see it improved as a [FinOps toolkit change request](https://aka.ms/ftk/ideas).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.12/bladeName/Hubs/featureName/ConfigureAI)

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
