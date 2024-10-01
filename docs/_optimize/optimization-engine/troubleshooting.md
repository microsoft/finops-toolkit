---
layout: default
parent: Optimization engine
title: Troubleshooting
nav_order: 70
description: 'Solutions to the most frequent issues with deployment and runtime.'
permalink: /optimization-engine/troubleshooting
---

<span class="fs-9 d-block mb-4">Troubleshooting</span>
Solutions to the most frequent issues with deployment and runtime.
{: .fs-6 .fw-300 }

---

* **When deploying AOE, I am getting a generic template deployment error** In some situations, the AOE template deployment results in a "_The template deployment failed with multiple errors_" message or similar. To identify the cause of the deployment failure, you have to check, in the Azure portal, the "_Deployments_" menu option both in the resource group and subscription details you chose to deploy AOE in. You will find a `resourcesDeployment` deployment in the resource group and a deployment with the AOE name prefix in the subscription, where you can identify the error details. Azure Policy deny policies are one of the typical causes for deployment errors.

* **Why are my Recommendations workbook and Power BI report still empty after deploying AOE?** AOE takes up to 3 hours after deployment to export and ingest the data required to generate recommendations into Log Analytics / SQL Database. If after this time you aren't still seeing any recommendations, check whether:
    * You have changed the Power BI data source to the SQL Database endpoint of your AOE deployment ([see instructions](https://aka.ms/AzureOptimizationEngine/reports)).
    * Azure Advisor has been reporting recommendations for the subscriptions in the AOE scope.
    * You refreshed the report data, as most of the Power BI report pages are configured to filter out recommendations older than 7 days.
    * Azure Automation runbooks have been failing, especially critical ones such as `Ingest-RecommendationsToLogAnalytics`, `Ingest-RecommendationsToSQLServer` and all the runbooks with a `Recommend-` prefix, and verify the Exception message that is logged, which will normally give you a hint for the failure cause.
    * A daily cap has been set in the AOE Log Analytics Workspace that might be dropping the ingestion of AOE logs after the cap was reached.

* **Why some workbooks present this message: `Failed to resolve table or column expression named 'AzureOptimizationPricesheetV1_CL'`?** This is typically a symptom of not having granted the required permissions to the AOE Automation Account managed identity, which authenticates with Azure Cost Management to download your Azure pricesheet. See setup instructions [here](https://aka.ms/AzureOptimizationEngine/commitmentssetup). NOTE: only Enterprise Agreement (EA) and Microsoft Customer Agreement (MCA) customers are supported by AOE for Azure pricesheet download.

* **Why some workbooks present this message: `Failed to resolve table or column expression named 'AzureOptimizationReservationsUsageV1_CL' (or 'AzureOptimizationSavingsPlansUsageV1_CL')`?** This can be caused by lack of permissions in the AOE managed identity (see question above) or simply because your organization did not buy any Reservations or Savings Plans.

* **Why is the Identity and Roles workbook empty and presenting error messages?** This is typically a symptom of not having granted the required permissions, at the Entra ID tenant level, to the AOE Automation Account managed identity. After having granted the `Global Reader` role to the AOE managed identity, the workbook should populate on the next day. If, after having granted the `Global Reader` role the workbook is still reporting errors, you need to investigate whether the `Export-AADObjectsToBlobStorage` runbook is failing and verify the Exception message that is logged, which will normally give you a hint for the failure cause. A typical cause is lack of sufficient memory in the Azure Automation sandbox worker. For a Hybrid Worker work-around, see instructions [here](https://aka.ms/AzureOptimizationEngine/customize#-scale-aoe-runbooks-with-hybrid-worker). You can also filter the Entra ID users and groups, by creating the `AzureOptimization_AADObjectsUserFilter` and `AzureOptimization_AADObjectsGroupFilter` automation variables with an [Microsoft Graph OData filter](https://learn.microsoft.com/graph/filter-query-parameter?tabs=http).

* **The `Export-ConsumptionToBlobStorage` runbook takes a long time to finish or the `Ingest-OptimizationCSVExportsToLogAnalytics` runbook has been failing consistently for the `consumptionexports` container** This might be caused by AOE having to deal with a large number of subscriptions in your environment, exporting a large number of small blobs. In order to optimize Azure consumption ingestion, we recommend you to switch consumption exports from a subscription scope to a billing account or billing profile scope (NOTE: this is possible only for EA or MCA customers). To achieve this, you must create, in the AOE Automation Account, an `AzureOptimization_ConsumptionScope` variable set to `BillingAccount` (EA) or `BillingProfile` (MCA). Ensure you have granted the needed permissions to the AOE managed identity at the EA/MCA billing account/profile level and that the `AzureOptimization_BillingAccountID` (EA/MCA) and `AzureOptimization_BillingProfileID` (MCA only) are correctly set ([see instructions](https://aka.ms/AzureOptimizationEngine/commitmentssetup)). After all this settings, the next run of the consumption exports should generate a single blob for the whole billing account/profile.

* **Why is my VM right-size recommendations overview page empty?** The AOE depends on Azure Advisor Cost recommendations for VM right-sizing. If no VMs are showing up, try increasing the CPU threshold in the Azure Advisor configuration (see steps [here](https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations#configure-vmvmss-recommendations))... or maybe your virtual machine infrastructure is not oversized after all!

* **Why are my VM right-size recommendations showing up with so many Unknowns for the metrics thresholds?** The AOE depends on your VMs being monitored by Azure Monitor agents and configured to send a set of performance metrics that are then used to augment Advisor recommendations. See more details [here](https://aka.ms/AzureOptimizationEngine/workspaces).

* **Why am I getting values so small for costs and savings after setting up AOE?** The Azure consumption exports runbook has just begun its daily execution and only got one day of consumption data. After one month - or after manually kicking off the runbook for past dates -, you should see the correct consumption data.

* **Why am I seeing historical data in the AOE workbooks only for the last 30 days?** The default AOE Log Analytics retention is 30 days. If you need to keep historical data for a longer period, [increase the Log Analytics retention](https://learn.microsoft.com/troubleshoot/azure/azure-monitor/log-analytics/billing/configure-data-retention) accordingly.
