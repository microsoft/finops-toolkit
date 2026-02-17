---
title: Troubleshoot Azure Optimization Engine issues
description: This article helps you troubleshoot common issues with Azure Optimization Engine deployment and runtime.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: troubleshooting
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to resolve common issues with Azure optimization engine.
---

# Troubleshoot Azure Optimization Engine issues

This article describes common issues you might experience with Azure Optimization Engine (AOE) deployment and runtime.

<br>

## Generic template deployment error when deploying AOE

In some situations, the AOE template deployment results in a `The template deployment failed with multiple errors` message or similar. To identify the cause of the deployment failure, you have to check in the Azure portal, in the `Deployments` menu option both in the resource group and subscription details you chose to deploy AOE in. The `resourcesDeployment` deployment is in the resource group and a deployment with the AOE name prefix is in the subscription, where you can identify the error details. Azure Policy deny policies are one of the typical causes for deployment errors.

## Recommendations workbook and Power BI report are empty after deploying AOE

AOE takes up to 3 hours after deployment to export and ingest the data required to generate recommendations into Log Analytics and SQL Database. If after this time you aren't still seeing any recommendations, check whether:

- You changed the Power BI data source to the SQL Database endpoint of your AOE deployment. For more information, see [Reports](reports.md).
- Azure Advisor has been reporting recommendations for the subscriptions in the AOE scope.
- You refreshed the report data, as most of the Power BI report pages are configured to filter out recommendations older than seven days.
- Azure Automation runbooks have been failing, especially critical ones such as `Ingest-RecommendationsToLogAnalytics`, `Ingest-RecommendationsToSQLServer` and all the runbooks with a `Recommend-` prefix, and verify the Exception message that is logged, which normally gives you a hint for the failure cause.
- A daily cap is set in the AOE Log Analytics Workspace that might be dropping the ingestion of AOE logs after the cap was reached.

## Workbook errors

The following sections address common errors you might encounter in the AOE workbooks.

### Workbook error - Failed to resolve table or column expression named AzureOptimizationPricesheetV1_CL

This error is typically a symptom of not granting the required permissions to the AOE Automation Account managed identity, which authenticates with Microsoft Cost Management to download your Azure price sheet. For more information, see [Enable Azure commitments workbooks](setup-options.md#enable-azure-commitments-workbooks).

AOE for Azure price sheet download is supported only for Enterprise Agreements (EA) and Microsoft Customer Agreements (MCA).

### Workbook errors - Failed to resolve table or column expression named AzureOptimizationReservationsUsageV1_CL or AzureOptimizationSavingsPlansUsageV1_CL

This problem might get caused by a lack of permissions in the AOE managed identity or because your organization didn't buy any reservations or savings plans. See the previous section.

## The Identity and Roles workbook is empty shows error messages

This problem is typically a symptom of not granting the required permissions at the Microsoft Entra ID tenant level to the AOE Automation Account managed identity. After your grant the `Global Reader` role to the AOE managed identity, the workbook should populate on the next day. If, after you grant the `Global Reader` role the workbook is still reporting errors, you need to investigate whether the `Export-AADObjectsToBlobStorage` runbook is failing and verify the Exception message that is logged, which will normally give you a hint for the failure cause. A typical cause is lack of sufficient memory in the Azure Automation sandbox worker. For a Hybrid Worker work-around, see instructions [Scale AOE runbooks with Hybrid Worker](customize.md#scale-aoe-runbooks-with-hybrid-worker). You can also filter the Microsoft Entra ID users and groups, by creating the `AzureOptimization_AADObjectsUserFilter` and `AzureOptimization_AADObjectsGroupFilter` automation variables with a [Microsoft Graph OData filter](/graph/filter-query-parameter).

## The Export-ConsumptionToBlobStorage runbook takes a long time to finish

The first symptom that the `Export-ConsumptionToBlobStorage` runbook takes a long time to finish. The second symptom is that `Ingest-OptimizationCSVExportsToLogAnalytics` runbook fails consistently for the `consumptionexports` container.

These issues might get caused by AOE having to deal with a large number of subscriptions in your environment, exporting a large number of small blobs.

In order to optimize Azure consumption ingestion, we recommend you to switch consumption exports from a subscription scope to a billing account or billing profile scope. Exports are possible only for EA or MCA customers.

To achieve this action, you must create, in the AOE Automation Account, an `AzureOptimization_ConsumptionScope` variable set to `BillingAccount` (EA) or `BillingProfile` (MCA). Ensure you granted the needed permissions to the AOE managed identity at the EA/MCA billing account/profile level and that the `AzureOptimization_BillingAccountID` (EA/MCA) and `AzureOptimization_BillingProfileID` (MCA only) are correctly set ([Enable Azure commitments workbooks](setup-options.md#enable-azure-commitments-workbooks)). After you verify the settings, the next run of the consumption exports should generate a single blob for the whole billing account/profile.

## The VM right-size recommendations overview page is empty

The AOE depends on Azure Advisor Cost recommendations for virtual machine (VM) right-sizing. If no VMs are showing up, try increasing the CPU threshold in the Azure Advisor configuration. For more information, see [Configure VM/Virtual Machine Scale Sets recommendations](/azure/advisor/advisor-cost-recommendations#configure-vmvmss-recommendations). Verify that your virtual machine infrastructure is truly oversized.

## VM right-size recommendations appear with Unknowns for the metrics thresholds

The AOE depends on your VMs getting monitored by Azure Monitor agents and configured to send a set of performance metrics that are then used to augment Advisor recommendations. See more details [Configure workspaces](configure-workspaces.md).

## Unexpected small for costs and savings

The Azure consumption exports runbook recently started its daily execution and only got one day of consumption data. After one month, or after manually kicking off the runbook for past dates, you should see the correct consumption data.

## Historical data in the AOE workbooks only for the last 30 days

The default AOE Log Analytics retention is 30 days. If you need to keep historical data for a longer period, [increase the Log Analytics retention](/troubleshoot/azure/azure-monitor/log-analytics/billing/configure-data-retention) accordingly.

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