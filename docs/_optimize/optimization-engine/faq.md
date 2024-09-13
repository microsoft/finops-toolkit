---
layout: default
parent: Optimization engine
title: FAQ
nav_order: 60
description: 'All the frequently asked questions about AOE in one place.'
permalink: /optimization-engine/faq
---

<span class="fs-9 d-block mb-4">Frequently Asked Questions</span>
All the frequently asked questions about AOE in one place.
{: .fs-6 .fw-300 }

---

* **Is AOE supported by Microsoft?** No, the Azure Optimization Engine is not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind. The entire risk arising out of the use or performance of the scripts and documentation remains with you.

* **What type of Azure subscriptions/clouds are supported?** AOE has been deployed and tested against EA, MCA and MSDN subscriptions in the Azure commercial cloud (AzureCloud). Although not tested yet, it should also work in MOSA subscriptions. It was designed to also operate in the US Government cloud, though it was never tested there. Sponsorship (MS-AZR-0036P and MS-AZR-0143P), CSP (MS-AZR-0145P, MS-AZR-0146P, and MS-AZR-159P) DreamSpark (MS-AZR-0144P) and Internal subscriptions should also work, but due to lack of availability or disparities in their consumption (billing) exports models, some of the Workbooks may not fully work.

* **Why are my Recommendations workbook and Power BI report still empty after deploying AOE?** AOE takes up to 3 hours after deployment to export and ingest the data required to generate recommendations into Log Analytics / SQL Database. If after this time you aren't still seeing any recommendations, check whether:
    * Azure Advisor has been reporting recommendations for the subscriptions in the AOE scope;
    * Azure Automation runbooks have been failing, especially critical ones such as `Ingest-` and `Recommend-`, and verify the Exception message that is logged, which will normally give you a hint for the failure cause;
    * a daily cap has been set in the AOE Log Analytics Workspace that might be dropping the ingestion of AOE logs after the cap was reached.

* **Why some workbooks present this message: `Failed to resolve table or column expression named 'AzureOptimizationPricesheetV1_CL'`?** This is typically a symptom of not having granted the required permissions to the AOE Automation Account managed identity. See instructions [here](https://aka.ms/AzureOptimizationEngine/commitmentssetup).

* **Why is the Identity and Roles workbook empty and presenting error messages?** This is typically a symptom of not having granted the required permissions, at the Entra ID tenant level, to the AOE Automation Account managed identity. After having granted the `Global Reader` role to the AOE managed identity, the workbook should populate on the next day.

* **Why is my Power BI report empty?** Most of the Power BI report pages are configured to filter out recommendations older than 7 days. If it shows empty, just try to refresh the report data.

* **Why is my VM right-size recommendations overview page empty?** The AOE depends on Azure Advisor Cost recommendations for VM right-sizing. If no VMs are showing up, try increasing the CPU threshold in the Azure Advisor configuration... or maybe your infrastructure is not oversized after all!

* **Why are my VM right-size recommendations showing up with so many Unknowns for the metrics thresholds?** The AOE depends on your VMs being monitored by Log Analytics agents and configured to send a set of performance metrics that are then used to augment Advisor recommendations. See more details [here](https://aka.ms/AzureOptimizationEngine/rightsizeblogpt2).

* **Why am I getting values so small for costs and savings after setting up AOE?** The Azure consumption exports runbook has just begun its daily execution and only got one day of consumption data. After one month - or after manually kicking off the runbook for past dates -, you should see the correct consumption data.

* **What is the currency used for costs and savings?** The currency used is the one that is reported by default by the Azure Consumption APIs. It should match the one you usually see in Azure Cost Management.

* **What is the default time span for collecting Azure consumption data?** By default, the Azure consumption exports daily runbook collects 1-day data from 3 days ago. This offset works well for many types of subscriptions. If you're running AOE in PAYG or EA subscriptions, you can decrease the offset by adjusting the `AzureOptimization_ConsumptionOffsetDays` variable. However, using a value less than 2 days is not recommended.

* **Why is AOE recommending to delete a long-deallocated VM that was deallocated just a few days before?** The _LongDeallocatedVms_ recommendation depends on accurate Azure consumption exports. If you just deployed AOE, it hasn't collected consumption long enough to provide accurate recommendations. Let AOE run at least for 30 days to get accurate recommendations.

* **Why is AOE recommending to delete a long-deallocated VM that was already deleted?** Due to the fact that Azure consumption exports are collected with a (default) offset of 7 days, the _LongDeallocatedVms_ recommendation might recommend for deletion a long-deallocated VM that was meanwhile deleted. That false positive should normally disappear in the next iteration.

* **How much does running AOE in my subscription cost?** The default AOE deployment requires cheap Azure resources: an Azure Automation account, a small Azure SQL Database and a Storage Account. It also requires a Log Analytics Workspace to which it sends all the logs used by Workbooks. The costs, mostly coming from Azure Automation, depend on the size of your environment, but even in customers with hundreds of VMs, AOE costs do not amount to more than 100 EUR/month. In small to medium-sized environments, it will cost less than 20 EUR/month. **These costs do not include agent-based VM performance metrics ingestion into Log Analytics**.