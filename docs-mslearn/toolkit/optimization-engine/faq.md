---
title: Azure optimization engine FAQ
description: This article covers frequently asked questions about the Azure Optimization Engine (AOE), including support, subscriptions, and currency.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to answer frequently asked questions about Azure optimization engine.
---

# Azure optimization engine Frequently Asked Questions

This article summarizes frequently asked questions about Azure optimization engine (AOE). It covers support, subscriptions, currency, and other common questions.

## Is AOE supported by Microsoft?

No, the Azure Optimization Engine isn't supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind. The entire risk arising out of the use or performance of the scripts and documentation remains with you.

## What type of Azure subscriptions/clouds are supported?

AOE was deployed and tested against EA, Microsoft Customer Agreement (MCA), and Visual Studio subscriptions in the Azure commercial cloud (AzureCloud). Although not tested yet, it should also work in Microsoft Online Subscription Agreement (MOSA) subscriptions. It was designed to also operate in the US Government cloud, though it was never tested there. The following subscriptions should also work, but due to lack of availability or disparities in their consumption (billing) exports models, some of the Workbooks might not fully work.

- Sponsorship (MS-AZR-0036P and MS-AZR-0143P)
- Cloud Solution Provider (CSP) (MS-AZR-0145P, MS-AZR-0146P, and MS-AZR-159P)
- DreamSpark (MS-AZR-0144P)
- Internal subscriptions

## What is the currency used for costs and savings?

The currency used is the one that gets reported by default by the Azure Consumption APIs. It should match the one you usually see in Microsoft Cost Management.

## What is the default time span for collecting Azure consumption data?

By default, the Azure consumption exports daily runbook collects one-day data from three days ago. This offset works well for many types of subscriptions. If you're running AOE in pay-as-you-go or EA subscriptions, you can decrease the offset by adjusting the `AzureOptimization_ConsumptionOffsetDays` variable. However, using a value less than two days isn't recommended.

## Why does AOE recommend deleting a long-deallocated VM that was deallocated just a few days before?

The _LongDeallocatedVms_ recommendation depends on accurate Azure consumption exports. If you recently deployed AOE, it didn't collect consumption long enough to provide accurate recommendations. Let AOE run at least for 30 days to get accurate recommendations.

## Why does AOE recommend deleting a long-deallocated VM that was already deleted?

Because Azure consumption exports are collected with a (default) offset of seven days, the _LongDeallocatedVms_ recommendation might recommend for deletion a long-deallocated VM that was meanwhile deleted. That false positive should normally disappear in the next iteration.

## How much does running AOE in my subscription cost?

The default AOE deployment requires cheap Azure resources: an Azure Automation account, a small Azure SQL Database, and a Storage Account. It also requires a Log Analytics Workspace to which it sends all the logs used by Workbooks. The costs, mostly coming from Azure Automation, depend on the size of your environment, but even in customers with hundreds of VMs, AOE costs don't amount to more than 100 EUR/month. In small to medium-sized environments, it costs less than 20 EUR/month. **These costs do not include agent-based VM performance metrics ingestion into Log Analytics**.

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)