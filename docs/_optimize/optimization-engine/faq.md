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

* **What is the currency used for costs and savings?** The currency used is the one that is reported by default by the Azure Consumption APIs. It should match the one you usually see in Azure Cost Management.

* **What is the default time span for collecting Azure consumption data?** By default, the Azure consumption exports daily runbook collects 1-day data from 3 days ago. This offset works well for many types of subscriptions. If you're running AOE in PAYG or EA subscriptions, you can decrease the offset by adjusting the `AzureOptimization_ConsumptionOffsetDays` variable. However, using a value less than 2 days is not recommended.

* **Why is AOE recommending to delete a long-deallocated VM that was deallocated just a few days before?** The _LongDeallocatedVms_ recommendation depends on accurate Azure consumption exports. If you just deployed AOE, it hasn't collected consumption long enough to provide accurate recommendations. Let AOE run at least for 30 days to get accurate recommendations.

* **Why is AOE recommending to delete a long-deallocated VM that was already deleted?** Due to the fact that Azure consumption exports are collected with a (default) offset of 7 days, the _LongDeallocatedVms_ recommendation might recommend for deletion a long-deallocated VM that was meanwhile deleted. That false positive should normally disappear in the next iteration.

* **How much does running AOE in my subscription cost?** The default AOE deployment requires cheap Azure resources: an Azure Automation account, a small Azure SQL Database and a Storage Account. It also requires a Log Analytics Workspace to which it sends all the logs used by Workbooks. The costs, mostly coming from Azure Automation, depend on the size of your environment, but even in customers with hundreds of VMs, AOE costs do not amount to more than 100 EUR/month. In small to medium-sized environments, it will cost less than 20 EUR/month. **These costs do not include agent-based VM performance metrics ingestion into Log Analytics**.