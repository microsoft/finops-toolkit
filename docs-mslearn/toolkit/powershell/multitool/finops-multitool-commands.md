---
title: FinOps multitool commands
description: Learn about PowerShell commands in the FinOpsToolkit module that scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 07/02/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps multitool commands are available in the FinOpsToolkit module.
---

# FinOps multitool commands

The FinOps multitool PowerShell commands help you scan an Azure environment for cost optimization, governance, and FinOps insights. Findings are grounded in your live resource state and cover cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

The Multitool delivers one scan engine through two interfaces:

- **Terminal UI (TUI)** – An interactive, cross-platform terminal experience launched with [Start-FinOpsMultitool](Start-FinOpsMultitool.md). It surfaces 26 of the 30 scans.
- **MCP server** – A Model Context Protocol server (`Start-McpServer.ps1`) that exposes all 30 scans as tools for AI agents like GitHub Copilot.

<br>

## Commands

- [Start-FinOpsMultitool](Start-FinOpsMultitool.md) – Launch the interactive FinOps multitool terminal UI.

<br>

## Scan coverage

The Multitool includes 30 scan modules across the following categories:

- **Optimization** – Orphaned resources, idle VMs, storage tier advice, Azure Hybrid Benefit opportunities, and legacy resources.
- **Governance** – Tag inventory and recommendations, and policy inventory and recommendations.
- **Cost analysis** – Cost data, resource costs, cost by tag, cost trend, unit economics, VM cost breakdown, shared cost allocation, billing account, and usage allocation.
- **Commitments** – Reservation advice, commitment utilization, and realized savings.
- **Monitoring** – Budget status, budget history, and anomaly alerts.
- **Advisor** – Azure Advisor cost recommendations.
- **Account** – Billing structure, contract info, and Microsoft Azure Consumption Commitment (MACC) balance.
- **AI and ML** – Azure AI workload spend.
- **Sustainability** – Carbon emissions.

Analysis scans are read-only. Most need Reader or Cost Management Reader access. Account scans also need Billing Reader, or Enterprise Administrator (reader) on an Enterprise Agreement. The carbon scan needs Reader or Carbon Optimization Reader.

<br>

## FinOps hub data paths

When a [FinOps hub](../../hubs/finops-hubs-overview.md) is present, cost scans read from the hub and choose the path automatically:

- **Kusto database (recommended for large environments)** – When the hub has an Azure Data Explorer or Microsoft Fabric cluster, the Multitool discovers it through Azure Resource Graph and pushes aggregation into the engine, returning only summarized results. This scales to large datasets without loading raw cost rows into PowerShell. To query a local hub on your own hardware, set the `FINOPS_HUB_KUSTO_URI` environment variable to a local Kusto endpoint (optionally set `FINOPS_HUB_KUSTO_DB`, which defaults to `Hub`).
- **Storage reader (small-dataset fallback)** – When no Kusto cluster is reachable, the Multitool reads the hub's storage export and aggregates in PowerShell. Use this for smaller datasets.

If no hub is available, cost scans use the live Cost Management API.

<br>

## MCP server for AI agents

`Start-McpServer.ps1` exposes the scan engine as 40 tools over the Model Context Protocol (`2024-11-05`) via stdio: 36 read-only analysis tools (including `run_full_scan` and `detect_cost_data_source`) and four write/remediation tools. The write tools are dry-run by default, gated by a configurable write-safety policy, and disabled unless the `FINOPS_WRITE_MODE` environment variable is set—the server defaults to `ReadOnly`, which blocks all writes.

A companion set of agent skills teaches AI agents to use the server and route findings into the wider FinOps practice. The `finops-multitool` skill acts as the hub and hands off to FinOps-adjacent skills for reporting, allocation, governance, unit economics, and more.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Multitool)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit PowerShell module](../powershell-commands.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
