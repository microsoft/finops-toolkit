---
title: Suppress recommendations
description: Learn how to adjust the Azure Optimization Engine recommendation results for your environment characteristics by suppressing irrelevant recommendations.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to understand how to suppress recommendations in Azure optimization engine.
---

# Suppress recommendations

When working on the recommendations provided by the Azure Optimization Engine (AOE), you might find some cases where the recommendation doesn't apply. For example, AOE might suggest high availability recommendations that don't apply to Dev/Test virtual machines (VM), or recommend enabling Azure Backup for noncritical VMs. You can suppress recommendations in two ways:

- If recommendations are originated from Azure Advisor, you can go to the Azure portal and [dismiss/postpone the recommendation](/azure/advisor/view-recommendations#dismiss-and-postpone-recommendations).
- If recommendations are custom to AOE or using the Azure Advisor interface isn't viable, you can suppress them in AOE using the `Suppress-Recommendation.ps1` helper scrsuppressipt. The script is available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code). See the following instructions.

<br>

## Identify recommendations to suppress

In the Power BI report, if you drill through the details of a recommendation (Recommendation Details page), you see the Recommendation ID in the header. Copy the ID, by using the **Copy value** right-select menu option. You need the ID to call the `Suppress-Recommendation.ps1` script.

:::image type="content" source="./media/suppress-recommendations/power-bi-recommendation-details-recommendation-id.png" border="true" alt-text="Screenshot showing copy the recommendation ID value on the Recommendation Details page." lightbox="./media/suppress-recommendations/power-bi-recommendation-details-recommendation-id.png":::

<br>

## Suppress the recommendation

From a PowerShell prompt, call the `Suppress-Recommendation.ps1` script as follows:

```powershell
./Suppress-Recommendation.ps1 -RecommendationId <recommendation Id>

# Example

./Suppress-Recommendation.ps1 -RecommendationId A2824017-602C-47DF-860D-B0B5A8CA7768
```

The script asks you for the Azure SQL Server hostname, database, and user credentials. After it successfully finds the recommendation in the AOE database, it asks you about the type of suppression:

- **Exclude** - this recommendation type is excluded from the engine and no longer gets generated for any resource
- **Dismiss** - this recommendation is dismissed for the scope that gets chosen next (instance, resource group, or subscription)
- **Snooze** - this recommendation is postponed for the duration (in days) and scope that gets chosen next (instance, resource group, or subscription)

Depending on the type of suppression chosen, you might get asked to provide the suppression scope (subscription, resource group, or resource instance) or the suppression duration (for Snooze suppressions). Finally, you should identify the author and the reason for the suppression.

<br>

## Related content

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
