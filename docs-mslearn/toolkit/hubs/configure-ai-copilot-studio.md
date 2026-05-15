---
title: Configure a FinOps hub agent in Microsoft Copilot Studio
description: Learn how to create a FinOps hub AI agent in Microsoft Copilot Studio with the Kusto Query MCP Server.
author: RolandKrummenacher
ms.author: brettwil
ms.date: 05/11/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
# customer intent: As a FinOps hub admin, I want to create a Copilot Studio agent that can query my FinOps hub data so that my team can ask cost questions in natural language.
---

# Configure a FinOps hub agent in Microsoft Copilot Studio

This article describes how to configure a [Microsoft Copilot Studio](https://copilotstudio.microsoft.com) agent that connects to your FinOps hub Data Explorer database and answers cost questions by executing KQL queries. The agent uses the Kusto Query MCP Server to run queries and knowledge files from the FinOps toolkit to construct accurate KQL.

<br>

## Prerequisites

Before you start, make sure you have the following:

- A [FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer running **FinOps hubs v12 or later**. The agent instructions use the `Costs_v1_2()` function, which isn't available in earlier versions. [Learn how to upgrade](upgrade.md).
- [Configured scopes](configure-scopes.md) with data ingested successfully.
- Database viewer or greater access to the Data Explorer **Hub** database. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).
- A Copilot Studio license or Microsoft 365 Copilot user license. For licensing details, see [Copilot Studio licensing](/microsoft-copilot-studio/billing-licensing).

If you're new to Copilot Studio, see [Quickstart: Create and deploy an agent](/microsoft-copilot-studio/fundamentals-get-started) to learn the basics of agent creation before continuing.

<br>

## Create and configure the agent

[Create a blank agent](/microsoft-copilot-studio/fundamentals-get-started) in Copilot Studio, then configure it with the following FinOps hub settings.

### Agent details

Set the agent name to **FinOps Hub Agent** (or your preferred name) and use the following description:

> FinOps Hub Agent provides governed, real-time insights from your FinOps Toolkit Hub database. It translates natural language questions into validated KQL queries and delivers structured analysis on cloud spend, commitments, savings plans, anomalies, and optimization opportunities.

### Model selection

The agent instructions require a model with deep reasoning capabilities for multistep KQL generation and structured report formatting. General-category models might produce lower-quality results for complex queries.

For available models, regional availability, and data residency considerations, see [Select a primary AI model for your agent](/microsoft-copilot-studio/authoring-select-agent-model). If you want to use an external model, your tenant administrator must enable it first; see [Choose an external model](/microsoft-copilot-studio/authoring-select-external-response-model).

### Agent instructions

1. Download the [Copilot Studio instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot-studio.zip) and extract the contents.
2. Open `agent-instructions.md` and update the **Environment** section with your cluster URI:

   ```text
   Cluster URI: <your-cluster>.kusto.windows.net
   Database: Hub
   ```

   > [!NOTE]
   > Don't include `https://` in the cluster URI. Copilot Studio removes HTTP links from the Instructions field.

3. Paste the full content of `agent-instructions.md` into the agent's **Instructions** field and save.

<br>

## Add tools

The agent needs the following MCP tools to function. For general steps on adding MCP tools to an agent, see [Add tools from an MCP server](/microsoft-copilot-studio/copilot-ai-plugins).

### Kusto Query MCP Server (required)

Add **Kusto Query MCP Server** (by Azure Data Explorer) with these settings:

- **Ask the end user before running**: No
- **Credentials to use**: End user credentials

This tool lets the agent execute KQL queries against your hub's Data Explorer database. The agent uses end-user credentials so query results respect each user's database permissions.

### Microsoft Learn Docs MCP Server (optional)

Add **Microsoft Learn Docs MCP Server** (by Microsoft Learn Docs MCP) to let the agent look up FinOps concepts, FOCUS specification details, and Azure service documentation when answering questions.

After adding tools, verify that each shows a **Connected** status in your agent's connection settings. If a connection shows as **Not Connected**, select **Manage** to authenticate.

<br>

## Add knowledge files

The agent instructions reference knowledge files for constructing accurate KQL queries. These files are query-building references, not data sources. For general steps on adding knowledge to an agent, see [Add knowledge sources](/microsoft-copilot-studio/knowledge-add-existing-copilot).

Upload each file from the extracted `knowledge/` folder and set the **Description** field for each file as shown:

| File | Description |
|------|-------------|
| `schema-reference.md` | Column reference for `Costs_v1_2()` including names, data types, usage notes, and edge cases. Use to look up correct column names before writing queries. |
| `query-catalog.md` | Ready-to-use KQL query templates for cost breakdowns, monthly trends, anomaly detection, forecasting, savings summary, and commitment utilization. |
| `weekly-report-guide.md` | Step-by-step workflow for producing structured weekly cost anomaly reports with seven KQL queries, post-processing rules, and the final report structure. |

The descriptions help the agent decide when to retrieve each file. Wait for all files to show a **Ready** status before testing.

<br>

## Test your agent

Test the agent in the **Test** panel to verify it connects to your hub data correctly. The agent should detect your billing currency and ask you to select an analysis scope. Try these sample prompts:

```text
What are my top 5 subscriptions by cost?
```

```text
Create a week over week summary
```

```text
Are there any unusual spikes in cost over the last 3 months?
```

```text
What was my savings rate last month?
```

Verify that the agent:

- Executes KQL queries against your hub database, not just quoting from knowledge files.
- Presents results as formatted tables.
- Shows the KQL query in a separate code block. Review the query to verify correct filters, time ranges, and aggregation logic.
- Includes confidence level, time range, and scope in the response.

<br>

## Publish your agent

After testing, publish your agent and configure channels to make it available to your team. For details, see [Publish your agent](/microsoft-copilot-studio/publication-fundamentals-publish-channels).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/ConfigureAICopilotStudio)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps hubs articles:

- [Configure AI agents](configure-ai.md)
- [FinOps hubs overview](finops-hubs-overview.md)
- [Data model](data-model.md)

Related Copilot Studio articles:

- [Quickstart: Create and deploy an agent](/microsoft-copilot-studio/fundamentals-get-started)
- [Select a primary AI model for your agent](/microsoft-copilot-studio/authoring-select-agent-model)
- [Add tools from an MCP server](/microsoft-copilot-studio/copilot-ai-plugins)
- [Add knowledge sources](/microsoft-copilot-studio/knowledge-add-existing-copilot)
- [Publish your agent](/microsoft-copilot-studio/publication-fundamentals-publish-channels)

<br>
