---
description: This template creates a new Azure Monitor workbook for FinOps hub cost, usage, and AI workload analysis.
page_type: sample
products:
- azure
- azure-app-service
- azure-data-explorer
- azure-kubernetes-service
- azure-monitor
- azure-openai
- azure-resource-manager
- azure-sql-database
- azure-storage-accounts
- azure-virtual-machines
urlFragment: hub-workbook
languages:
- bicep
- json
---

# FinOps hub workbook

This template creates a new Azure Monitor workbook for a **FinOps hub**.

The FinOps hub workbook is the Azure Monitor counterpart to the FinOps hub Grafana dashboards. It reads cost and usage data from the Azure Data Explorer cluster in your FinOps hub and combines it with Azure Monitor telemetry, so you can analyze rate optimization, usage optimization, and AI workloads without leaving the Azure portal.

The workbook includes the following tabs:

| Tab | What you can do |
| --- | --- |
| Home | Review overall cost and usage for the selected scope and time range. |
| App Service | Analyze App Service plans, utilization, and rate optimization. |
| Azure AI | Analyze Azure AI and Azure OpenAI usage, tokens, and cost. |
| Compute | Analyze virtual machine cost, utilization, and rightsizing. |
| Azure SQL | Analyze Azure SQL cost and utilization. |
| Storage | Analyze storage cost by account, tier, and redundancy. |
| Capacity reservations | Review capacity reservation coverage and use. |
| Premium SSD v2 | Analyze Premium SSD v2 disks and their configured performance. |

To learn more about FinOps hubs, the roadmap, or how to contribute, see [FinOps toolkit documentation](https://aka.ms/ftk/docs).

<br>

## 📋 Prerequisites

This workbook requires a deployed FinOps hub that includes Azure Data Explorer. The workbook queries the hub cluster through the Azure Monitor `adx()` cross-service operator, so you need at least **Reader** access to both the hub cluster and the Log Analytics workspaces you select.

<br>

## 📗 How to use this template

After you deploy the workbook, open it from **Azure Monitor** > **Workbooks**, or from the resource group where you deployed it. Set the **Telemetry resources** parameter to the Log Analytics workspaces that hold your telemetry, then select a tab.

<br>

## 🧰 Related tools

- [FinOps hubs](https://aka.ms/finops/hubs)
- [FinOps hub dashboards for Grafana](../README.md)
- [Cost optimization workbook](../optimization/README.md)
- [Governance workbook](../governance/README.md)

<br>
