---
title: Configure a FinOps hub agent in Microsoft Copilot Studio
description: Learn how to create a FinOps hub AI agent in Microsoft Copilot Studio with the Kusto Query MCP Server.
author: rkrummenacher
ms.author: rkrummenacher
ms.date: 04/02/2026
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

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer running **FinOps hubs v12 or later**. The agent instructions use the `Costs_v1_2()` function, which is not available in earlier versions. [Learn how to upgrade](upgrade.md).
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- Database viewer or greater access to the Data Explorer **Hub** database. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).
- Access to [Microsoft Copilot Studio](https://copilotstudio.microsoft.com).
- A [Microsoft Copilot Studio license](/microsoft-copilot-studio/billing-licensing) or Microsoft 365 Copilot user license.

<br>

## Create the agent

1. Open [Microsoft Copilot Studio](https://copilotstudio.microsoft.com).
2. Select **Agents** in the left navigation, then select **+ Create blank agent**. Wait for the agent to be provisioned.
3. On the **Overview** page, in the **Details** section, select **Edit**. Set the name to **FinOps Hub Agent** (or your preferred name) and set the description:

   > FinOps Hub Agent provides governed, real time insights from your FinOps Toolkit Hub database. It translates natural language questions into validated KQL queries and delivers structured analysis on cloud spend, commitments, savings plans, anomalies, and optimization opportunities.

4. Under **Select your agent's model**, select **Claude Opus 4.6** or later.

   > [!NOTE]
   > The agent instructions have been tested and validated with **Claude Opus 4.6**. Other models may produce lower-quality results, especially for complex KQL generation and structured report formatting.

5. Download the [Copilot Studio instructions for FinOps hubs](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-copilot-studio.zip) and extract the contents.
6. Open the `agent-instructions.md` file and update the **Environment** section with your cluster URI:

   ```text
   Cluster URI: <your-cluster>.kusto.windows.net
   Database: Hub
   ```

   > [!NOTE]
   > Do not include `https://` in the cluster URI. Copilot Studio strips HTTP links from the Instructions field.

7. In the **Instructions** section, select **Edit**, paste the full content of `agent-instructions.md`, and select **Save**.

<br>

## Add tools

The agent requires the Kusto Query MCP Server to execute KQL queries against your FinOps hub database. You can optionally add the Microsoft Learn Docs MCP to look up FinOps concepts and Azure documentation.

### Add the Kusto Query MCP Server

1. In your agent, select the **Tools** tab.
2. Select **+ Add a tool**.
3. In the **Add tool** dialog, search for **Kusto Query MCP Server**.
4. Select the **Model Context Protocol** filter to narrow the results.
5. Select **Kusto Query MCP Server** (by Azure Data Explorer).
6. Expand **Additional details** and configure the following settings:
   - **Ask the end user before running**: No
   - **Credentials to use**: End user credentials
7. Ensure the **Enabled** toggle in the top right is on, then select **Save**.

### Add Microsoft Learn Docs MCP (optional)

1. Select **+ Add a tool**.
2. Search for **Microsoft Learn Docs MCP Server** and select the **Model Context Protocol** filter.
3. Select **Microsoft Learn Docs MCP Server** (by Microsoft Learn Docs MCP) and enable it.

This tool allows the agent to look up FinOps concepts, FOCUS specification details, and Azure service documentation when answering questions.

### Verify connections

1. Select **Settings** in the top right corner of the agent.
2. Select **Connection Settings** in the left navigation.
3. Verify that both **Azure Data Explorer** and **Microsoft Learn Docs MCP** (if added) show a **Connected** status. If a connection shows as **Not Connected**, select **Manage** to authenticate.

<br>

## Add knowledge files

Knowledge files give the agent reference information for constructing accurate KQL queries. The agent instructions are designed to use these files as query-building references, not as data sources.

1. In your agent, select the **Knowledge** tab.
2. Select **+ Add knowledge**.
3. In the **Add knowledge** dialog, drag and drop or browse to upload each file from the extracted `knowledge/` folder:

   | File | Description |
   |------|-------------|
   | `schema-reference.md` | Column reference for building KQL queries against Costs_v1_2(). Contains all column names, data types, usage notes, and edge cases like blank meter categories and BilledCost vs EffectiveCost divergence. Use to look up correct column names before writing queries. |
   | `query-catalog.md` | Ready-to-use KQL query templates for FinOps analysis. Covers cost breakdowns by subscription/service/region, monthly trends, anomaly detection, forecasting, savings summary, commitment utilization, and reservation recommendations. Adapt these patterns to answer cost questions. |
   | `weekly-report-guide.md` | Step-by-step workflow for producing structured weekly cost anomaly reports. Contains 7 KQL queries (totals, category summary, resource increases/decreases, commitment coverage drops, marketplace), post-processing rules for grouping and severity classification, and the final report structure. |

4. For each file, select it to open the details and enter the description from the table above in the **Description** field. These descriptions help the agent decide when to retrieve each file.
5. Wait for all files to show a **Ready** status on the Knowledge tab. Processing may take a few minutes.

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
   - Shows the KQL query in a separate code block. Review the query to verify correct filters, time ranges, and aggregation logic.
   - Includes confidence level, time range, and scope.

<br>

## Publish your agent

Once testing is complete, publish your agent to make it available to your team:

1. Select **Publish** in the top right corner.
2. Choose your preferred channel (Microsoft Teams, Microsoft 365 Copilot, or other supported channels).

For details about publishing and channel configuration, see [Publish your agent](/microsoft-copilot-studio/publication-fundamentals-publish-channels).

<br>

## Pricing and licensing

There are two licensing paths for using Copilot Studio agents:

- **Microsoft 365 Copilot users** — Interactive, employee-facing usage of Copilot Studio agents is included at no extra charge, subject to fair usage limits. If your team already has Microsoft 365 Copilot licenses, you can get started without additional purchases. Note that scheduled actions and agent flows are not included and consume Copilot Credits separately.
- **Standalone Copilot Studio license** — Uses a consumption-based billing model measured in Copilot Credits. For details on credit rates and capacity options, see [Copilot Studio billing rates and management](/microsoft-copilot-studio/requirements-messages-management#copilot-credits-billing-rates).

For full licensing details, see [Copilot Studio licensing](/microsoft-copilot-studio/billing-licensing).

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
