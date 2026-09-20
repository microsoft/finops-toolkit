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

The FinOps hub workbook is the Azure Monitor counterpart to the FinOps hub dashboards. It reads cost and usage data from the Azure Data Explorer cluster in your FinOps hub and combines it with Azure Monitor telemetry, so you can analyze rate optimization, usage optimization, and AI workloads without leaving the Azure portal.

The workbook includes the following tabs:

| Tab | What you can do |
| --- | --- |
| About | Review the workbook version, how it aligns to the FinOps Framework, and where to find the FinOps toolkit. |
| Summary | Review cost and usage across services, regions, subscriptions, and resource groups. |
| AI & emerging workloads | Analyze the AI and machine learning estate, including foundation models, cognitive services, and ML platform compute. |
| Anomaly management | Detect and investigate abnormal cost and usage patterns. |
| Data ingestion | Review the state of your FinOps hub and the data it ingested. |
| Rate optimization | Analyze savings, commitment discounts, and purchases. |
| Licensing + SaaS | Review Azure Hybrid Benefit use and licensing cost. |
| Budgeting | Monitor budgets and track spending against your financial plans. |
| Invoicing + chargeback | Reconcile provider invoices and bill internal teams for their cloud costs. |
| Foundry infrastructure | Review Azure AI Foundry inventory, platform metrics, and cost. |
| Foundry agents | Analyze Foundry agent runs, tokens, latency, errors, and estimated cost. |
| Supply | Review quota and capacity inventory as separate evidence. |

To learn more about FinOps hubs, the roadmap, or how to contribute, see [FinOps toolkit documentation](https://aka.ms/ftk/docs).

<br>

## 📋 Prerequisites

- A [deployed FinOps hub instance](https://aka.ms/finops/hubs) with Azure Data Explorer.
- Configured scopes that ingested data successfully.
- Database **Viewer** or greater access to the Data Explorer **Hub** and **Ingestion** databases. Alternatively, **AllDatabasesViewer** access to the cluster. [Learn more](https://learn.microsoft.com/kusto/management/manage-database-security-roles#database-level-security-roles).
- [Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#reader) access to the subscriptions and Log Analytics workspaces you want to analyze.

The workbook reads the hub cluster with the Azure Monitor `adx()` cross-service operator. Azure RBAC on the cluster resource doesn't grant query access to the data, so you need the database roles listed previously.

<br>

## 📗 How to use this template

Once your workbook is deployed, you can use it by navigating to one of the following destinations:

1. From Azure Monitor:
   1. Select [**Workbooks**](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/workbooks) in the menu.
   2. Verify your subscription is selected in the **Subscription** filter.
   3. Select the **FinOps hub** workbook.
2. From the resource group:
   1. Select the workbook resource.
   2. Select **Workbook** in the menu.
3. From [Azure workbooks](https://portal.azure.com/#browse/microsoft.insights%2Fworkbooks):
   1. Select the **FinOps hub** workbook.
   2. Select **Workbook** in the menu.

> ℹ️ _**Pro tip:** If you navigate to the workbook resource (2 or 3 above), consider adding the workbook as a favorite using the star icon to the right of the resource name to make it easier to find in the future. Favorite resources can be opened directly from the Resources > Favorite section of the Azure portal default home page._

After you open the workbook, set the following parameters, then select a tab:

| Parameter | What to select |
| --- | --- |
| FinOps hub cluster | The Data Explorer cluster in your FinOps hub. |
| FinOps hub database | The hub database. Default: `Hub`. |
| Agent telemetry workspaces | The Log Analytics workspaces that store your agent telemetry. |
| Foundry accounts | The Azure AI Foundry accounts you want to analyze. |
| Time range | The period you want to report on. |

<br>

## 🧰 About the FinOps toolkit

The FinOps hub workbook is part of the [FinOps toolkit](https://aka.ms/finops/toolkit), an open source collection of FinOps solutions that help you manage and optimize your cost, usage, and carbon.

To contribute to the FinOps toolkit, [join us on GitHub](https://aka.ms/ftk).

Related solutions:

- [FinOps hubs](https://aka.ms/finops/hubs)
- [Workbook modules](../README.md)
- [Cost optimization workbook](../optimization/README.md)
- [Governance workbook](../governance/README.md)

<br>

`Tags: finops, hubs, cost, usage, ai, Microsoft.Insights/workbooks`

<br>
