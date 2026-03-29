---
title: Configure a FinOps hub agent in Microsoft Copilot Studio
description: Learn how to create a FinOps hub AI agent in Microsoft Copilot Studio with the Kusto Query MCP Server.
author: rkrummenacher
ms.author: rkrummenacher
ms.date: 03/29/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want to create a Copilot Studio agent that can query my FinOps hub data so that my team can ask cost questions in natural language.
---

# Configure a FinOps hub agent in Microsoft Copilot Studio

[Microsoft Copilot Studio](https://copilotstudio.microsoft.com) enables you to create AI agents that integrate with Microsoft 365 Copilot. This article describes how to create a FinOps hub agent in Copilot Studio that connects to your FinOps hub database via the Kusto Query MCP Server and answers cost questions by executing KQL queries.

<br>

## Prerequisites

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- Database viewer or greater access to the Data Explorer **Hub** database. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).
- Access to [Microsoft Copilot Studio](https://copilotstudio.microsoft.com).

<br>

## Create the agent

1. Open [Microsoft Copilot Studio](https://copilotstudio.microsoft.com).
2. Select **Agents** > **New agent**.
3. Set the agent name to **FinOps Hub Agent** (or your preferred name).
4. Set the description:

   > FinOps Hub Agent provides governed, real time insights from your FinOps Toolkit Hub database. It translates natural language questions into validated KQL queries and delivers structured analysis on cloud spend, commitments, savings plans, anomalies, and optimization opportunities.

5. Download the [Copilot Studio instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot-studio.zip) and extract the contents.
6. Open the `instructions.md` file and update the **Environment** section with your cluster URI:

   ```text
   Cluster URI: <your-cluster>.kusto.windows.net
   Database: Hub
   ```

   > [!NOTE]
   > Do not include `https://` in the cluster URI. Copilot Studio strips HTTP links from the Instructions field.

7. Copy the full content of `instructions.md` and paste it into the **Instructions** field in Copilot Studio.
8. Select **Create**.

<br>

## Add tools

The agent needs two tools to function: the Kusto Query MCP Server for executing KQL queries and optionally the Microsoft Learn Docs MCP for looking up FinOps concepts and Azure documentation.

### Add the Kusto Query MCP Server

1. In your agent, select the **Tools** tab.
2. Select **+ Add a tool**.
3. Search for **Kusto Query MCP Server** (by Azure Data Explorer).
4. Select the tool and configure it for your FinOps hub cluster.
5. Ensure the tool is set to **By agent** trigger and **Enabled**.

### Add Microsoft Learn Docs MCP (optional)

1. Select **+ Add a tool**.
2. Search for **Microsoft Learn Docs MCP Server**.
3. Select the tool and enable it.

This tool allows the agent to look up FinOps concepts, FOCUS specification details, and Azure service documentation when answering questions.

<br>

## Add knowledge files

Knowledge files give the agent reference information for constructing accurate KQL queries. The agent instructions are designed to use these files as query-building references, not as data sources.

1. In your agent, select the **Knowledge** tab.
2. Select **+ Add knowledge** > **Files**.
3. Upload each file from the extracted `knowledge/` folder:

   | File | Description |
   |------|-------------|
   | `schema-reference.md` | Column reference for building KQL queries against Costs_v1_2(). Contains all 155 column names, data types, usage notes, and edge cases like blank meter categories and BilledCost vs EffectiveCost divergence. Use to look up correct column names before writing queries. |
   | `query-catalog.md` | Ready-to-use KQL query templates for FinOps analysis. Covers cost breakdowns by subscription/service/region, monthly trends, anomaly detection, forecasting, savings summary, commitment utilization, and reservation recommendations. Adapt these patterns to answer cost questions. |
   | `weekly-report-guide.md` | Step-by-step workflow for producing structured weekly cost anomaly reports. Contains 7 KQL queries (totals, category summary, resource increases/decreases, commitment coverage drops, marketplace), post-processing rules for grouping and severity classification, and the final report structure. |

4. For each file, use the description from the table above in the **Description** field in Copilot Studio. These descriptions help the agent decide when to retrieve each file.

<br>

## Select a model

1. In your agent, select the **Overview** tab.
2. Under **Select your agent's model**, choose the model you want to use for reasoning and responding.

<br>

## Test your agent

After configuration, test your agent in the **Test** panel:

1. Start a new test session.
2. The agent should automatically detect your billing currency and ask you to select an analysis scope.
3. Try these sample prompts:

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

4. Verify that the agent:
   - Executes KQL queries (not just quoting from knowledge files).
   - Presents results as formatted tables.
   - Shows the KQL query in a separate code block.
   - Includes confidence level, time range, and scope.

<br>

## Publish your agent

Once testing is complete, publish your agent to make it available to your team:

1. Select **Publish** in the top right corner.
2. Choose your preferred channel (Microsoft Teams, Microsoft 365 Copilot, or other supported channels).

For details about publishing and channel configuration, see [Publish your agent](/microsoft-copilot-studio/publication-fundamentals-publish-channels).

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

Related products:

- [Microsoft Copilot Studio](/microsoft-copilot-studio/fundamentals-what-is-copilot-studio)
- [Azure Data Explorer](/azure/data-explorer/)

<br>
