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
