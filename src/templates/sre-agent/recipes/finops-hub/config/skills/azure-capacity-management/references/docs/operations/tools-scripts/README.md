---
title: Tools & scripts
parent: Operational topics
nav_order: 15
---

# Tools & scripts

Scripts that extend Azure's native capabilities for ISV capacity management.

## Quota management

| Script | Description |
|--------|-------------|
| [Get-AzVMQuotaUsage.ps1](get-azvmquotausage.md) | Multi-threaded quota analysis across 100+ subscriptions |
| [Get-AzAvailabilityZoneMapping.ps1](get-azavailabilityzonemapping.md) | Logical-to-physical zone mapping for cross-subscription alignment |
| [Show-AzVMQuotaReport.ps1](show-azvmquotareport.md) | Single-threaded quota reporting for smaller deployments |

## Cost optimization

| Script | Description |
|--------|-------------|
| [Get-BenefitRecommendations.ps1](get-benefitrecommendations.md) | Extract savings plan recommendations from Cost Management API |
| [Deploy-AnomalyAlert.ps1](deploy-anomalyalert.md) | Deploy cost anomaly alerts to individual subscriptions |
| [Deploy-BulkALZ.ps1](deploy-bulkalz.md) | Bulk deploy anomaly alerts across management groups |

## Budget management

| Script | Description |
|--------|-------------|
| [Deploy-Budget.ps1](deploy-budget.md) | Deploy a cost budget to a single subscription with tag-based amount configuration |
| [Deploy-BulkBudgets.ps1](deploy-bulkbudgets.md) | Bulk deploy budgets to all subscriptions in a management group |

## Storage analysis

| Tool | Description |
|------|-------------|
| [Serverless SQL storage audit](https://github.com/MSBrett/azcapman/tree/main/scripts/serverless-sql-storage) | Azure Monitor workbook that surfaces allocated vs. used storage across Azure SQL serverless databases; identifies `DBCC SHRINKDATABASE` candidates to reclaim billing waste |

## Advisor recommendations

| Script | Description |
|--------|-------------|
| [Suppress-AdvisorRecommendations.ps1](suppress-advisorrecommendations.md) | Suppress specified Azure Advisor recommendation types across a management group for up to 90 days; useful when FinOps teams manage spend centrally |

## Utilities

| Tool | Description |
|------|-------------|
| [calculator.py](https://github.com/MSBrett/azcapman/tree/main/scripts/calculator) | Python calculator using SymPy for safe evaluation of mathematical expressions from string input; designed for LLM tool use in cost and quota calculations |

**Source**: [GitHub repository](https://github.com/MSBrett/azcapman/tree/main/scripts)
