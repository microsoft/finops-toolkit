---
layout: default
parent: Optimization engine
title: Suppressing recommendations
nav_order: 40
description: 'Adjust the recommendations results to your environment characteristics.'
permalink: /optimization-engine/suppressing-recommendations
---

<span class="fs-9 d-block mb-4">Suppressing recommendations</span>
Adjust the recommendations results to your environment characteristics.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [👉 Identifying the recommendation to suppress](#-identifying-the-recommendation-to-suppress)
- [🔕 Supressing the recommendation](#-supressing-the-recommendation)

</details>

---

When working on the recommendations provided by AOE, you may find some cases where the recommendation does not apply for some reason. For example, AOE is suggesting high availability recommendations that do not apply to Dev/Test Virtual Machines, or recommending enabling Azure Backup for non-critical VMs. You can suppress recommendations in two ways:

* If recommendations are originated from Azure Advisor, you can simply go to the Azure Portal and [dismiss/postpone the recommendation](https://learn.microsoft.com/azure/advisor/view-recommendations#dismissing-and-postponing-recommendations).
* If recommendations are custom to AOE or using the Azure Advisor interface is not viable, you can suppress them in AOE using the `Suppress-Recommendation.ps1` helper script (available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code) - see instructions below).

## 👉 Identifying the recommendation to suppress

In the Power BI report, if you drill through the details of a recommendation (Rec. Details page), you will find the Recommendation Id in the header. Copy this Id, by using the "Copy value" right-click menu option. You'll need this ID to call the Supress-Recommendation.ps1 script.

![Copying the Recommendation Id value from the Recommendation Details page in the Power BI report](../assets/images/aoe/powerbi-recdetails-recommendationid.jpg "Copy the Recommendation Id value")

## 🔕 Supressing the recommendation

From a PowerShell prompt, call the `Suppress-Recommendation.ps1` script as follows:

```powershell
./Suppress-Recommendation.ps1 -RecommendationId <recommendation Id>

# Example
./Suppress-Recommendation.ps1 -RecommendationId A2824017-602C-47DF-860D-B0B5A8CA7768
```

The script will ask you for the Azure SQL Server hostname, database and user credentials. After successfully finding the recommendation in the AOE database, it will ask you about the type of suppression:

* **Exclude** - this recommendation type will be completely excluded from the engine and will no longer be generated for any resource
* **Dismiss** - this recommendation will be dismissed for the scope to be chosen next (instance, resource group or subscription)
* **Snooze** - this recommendation will be postponed for the duration (in days) and scope to be chosen next (instance, resource group or subscription)

Depending on the type of suppression chosen, you can be asked to provide the suppression scope (subscription, resource group or resource instance) or the suppression duration (for Snooze suppressions). Finally, you should identify the author and the reason for the suppression.