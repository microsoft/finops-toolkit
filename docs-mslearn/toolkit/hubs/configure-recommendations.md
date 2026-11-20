---
title: Configure FinOps hubs recommendations
description: Learn about the recommendations available in FinOps hubs and how to add custom recommendations.
author: flanakin
ms.author: micflan
ms.date: 11/20/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub user, I want to understand the recommendations available in FinOps hubs and how to add my own.
---

<!-- prettier-ignore-start -->
# Configure FinOps hubs recommendations
<!-- prettier-ignore-end -->

FinOps hubs collect recommendations from multiple sources and ingest them into the [Recommendations managed dataset](data-model.md#recommendations-managed-dataset) alongside reservation recommendations from Cost Management exports. Recommendations are sourced from Azure Resource Graph using a configurable set of queries that pull Azure Advisor recommendations and identify various optimization scenarios based on resource configuration. Queries are managed in simple JSON files in storage, making it easy to add your own custom recommendations by uploading query files to hub storage. Hubs can also ingest [savings plan purchase recommendations](#savings-plan-recommendations) from Cost Management.

<br>

## Prerequisites

Before you begin, you must have:

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub).
- Assigned the **Reader** role to the Data Factory managed identity on the management groups or subscriptions you want to query. This permission must be configured separately from the FinOps hub deployment.
- For savings plan recommendations, granted the Data Factory managed identity read access to each billing scope. For more information, see [Required permissions](#required-permissions).

<br>

## How recommendations are processed

The recommendations pipeline runs daily and processes query files stored in the **config/queries** folder in hub storage:

1. The **queries_DailySchedule** trigger runs once per day.
2. The **queries_ExecuteETL** pipeline iterates through all query files in the **config/queries** storage folder.
3. The **queries_ETL_ingestion** pipeline executes each query against Azure Resource Graph, deduplicates results, and saves data as parquet in the **ingestion/Recommendations** folder.
4. If using Azure Data Explorer, data is ingested into the `Recommendations_raw` table and transformed using the `Recommendations_transform_v1_2()` function.

Hubs recommendations are combined with reservation recommendations from Cost Management exports in the same [Recommendations managed dataset](data-model.md#recommendations-managed-dataset). You can distinguish between sources using the `x_SourceType` column.

<br>

## Built-in recommendations

FinOps hubs include the following recommendations. Most are enabled by default. Optional recommendations may generate noise for organizations where they don't apply and can be enabled during deployment via the specified template parameter.

### Compute

- **Virtual Machines**
  - [Deallocate stopped VMs](../../best-practices/compute.md#deallocate-virtual-machines).
  - [Migrate to managed disks](../../best-practices/compute.md#migrate-to-managed-disks).
  - Optional: [Use Azure Hybrid Benefit for Windows VMs](../../best-practices/compute.md#use-azure-hybrid-benefit-for-windows-vms). Enabled via the `enableAHBRecommendations` option.
- **SQL Virtual Machines**
  - Optional: [Use Azure Hybrid Benefit for SQL VMs](../../best-practices/compute.md#use-azure-hybrid-benefit-for-sql-vms). Enabled via the `enableAHBRecommendations` option.
- **Azure Kubernetes Service**
  - Optional: [Use Spot VMs for AKS clusters](../../best-practices/compute.md#use-spot-vms-for-aks-clusters). Enabled via the `enableSpotRecommendations` option.

### Databases

- **Azure SQL Database**
  - [Remove unused elastic pools](../../best-practices/databases.md#remove-unused-elastic-pools)

### Management and Governance

- **Azure Advisor**
  - [Review Azure Advisor cost recommendations](../../best-practices/general.md#review-azure-advisor-cost-recommendations)

### Networking

- **Application Gateway**
  - [Remove idle application gateways](../../best-practices/networking.md#remove-idle-application-gateways).
  - [Upgrade classic application gateways](../../best-practices/networking.md#upgrade-classic-application-gateways)
- **DDoS Protection**
  - [Remove unassociated DDoS plans](../../best-practices/networking.md#remove-unassociated-ddos-protection-plans)
- **ExpressRoute**
  - [Remove unprovisioned ExpressRoute circuits](../../best-practices/networking.md#remove-unprovisioned-expressroute-circuits)
- **Load Balancer**
  - [Remove idle load balancers](../../best-practices/networking.md#remove-idle-load-balancers).
  - [Upgrade Basic load balancers](../../best-practices/networking.md#upgrade-basic-load-balancers)
- **NAT Gateway**
  - [Remove orphaned NAT gateways](../../best-practices/networking.md#remove-orphaned-nat-gateways)
- **Network Interfaces**
  - [Remove unattached NICs](../../best-practices/networking.md#remove-unattached-network-interfaces)
- **Network Security Groups**
  - [Remove empty NSGs](../../best-practices/networking.md#remove-empty-network-security-groups)
- **Public IP Addresses**
  - [Remove unattached public IPs](../../best-practices/networking.md#remove-idle-public-ip-addresses).
  - [Upgrade Basic public IPs](../../best-practices/networking.md#upgrade-basic-public-ips)
- **VPN Gateway**
  - [Remove idle VNet gateways](../../best-practices/networking.md#remove-idle-vnet-gateways)

### Storage

- **Managed Disks**
  - [Downgrade premium snapshots](../../best-practices/storage.md#downgrade-premium-snapshots).
  - [Remove unattached disks](../../best-practices/storage.md#remove-unattached-disks)
- **Storage Accounts**
  - [Upgrade legacy storage accounts](../../best-practices/storage.md#upgrade-legacy-storage-accounts)

### Web

- **App Service**
  - [Remove empty App Service plans](../../best-practices/web.md#remove-empty-app-service-plans)

To disable a specific default recommendation, delete its query file from the **config/queries** folder in hub storage. The pipeline only processes query files that are present.

<br>

## Savings plan recommendations

FinOps hubs can ingest Azure savings plan purchase recommendations from the [Cost Management Benefit Recommendations API](/rest/api/cost-management/benefit-recommendations/list). Cost Management exports don't include savings plan recommendations. Savings plan recommendations are added to the [Recommendations managed dataset](data-model.md#recommendations-managed-dataset) next to reservation recommendations, with `x_SourceType` set to `SavingsPlanRecommendations`.

Savings plan recommendations are optional. To enable them, set the `enableSavingsPlanRecommendations` template parameter to `true` when you deploy or redeploy your hub. They don't require the `enableRecommendations` parameter. To report on savings plan recommendations, deploy your hub with Azure Data Explorer or Microsoft Fabric.

### Supported scopes

The pipeline gets recommendations for each scope in the **scopes** property of **config/settings.json** that the Benefit Recommendations API supports. The benefit scope, which is where the recommended savings plan would apply, follows from the scope.

| Scope               | Example                                                                         | Benefit scope |
| ------------------- | ------------------------------------------------------------------------------- | ------------- |
| EA billing account  | `/providers/Microsoft.Billing/billingAccounts/{enrollmentId}`                   | Shared        |
| MCA billing profile | `/providers/Microsoft.Billing/billingAccounts/{id}/billingProfiles/{profileId}` | Shared        |
| Subscription        | `/subscriptions/{subscriptionId}`                                               | Single        |
| Resource group      | `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}`            | Single        |

Other scopes, like EA departments, EA enrollment accounts, MCA billing accounts, MCA invoice sections, and management groups, aren't supported by the API. The pipeline skips them.

### Required permissions

The template doesn't grant access to billing scopes. Grant the Data Factory managed identity read access to each scope you want recommendations for:

- **EA billing accounts** – Assign the EnrollmentReader role. For more information, see [Assign Enterprise Agreement roles to service principals](/azure/cost-management-billing/manage/assign-roles-azure-service-principals).
- **MCA billing profiles** – Assign the billing profile reader role. For more information, see [Manage billing roles in the Azure portal](/azure/cost-management-billing/manage/understand-mca-roles#manage-billing-roles-in-the-azure-portal).
- **Subscriptions and resource groups** – Assign the **Cost Management Reader** role, which includes the `Microsoft.CostManagement/benefitRecommendations/read` permission. For more information, see [Azure permissions for Management and governance](/azure/role-based-access-control/permissions/management-and-governance#microsoftcostmanagement).

To find the managed identity, open the FinOps hub resource group, go to **Deployments** > **hub** > **Outputs**, and note the **managedIdentityId** and **managedIdentityTenantId** values. If you use [managed exports](configure-scopes.md#configure-managed-exports), the managed identity might already have the access it needs for EA billing accounts.

### Lookback periods and terms

By default, the pipeline gets recommendations for every lookback period (7, 30, and 60 days) and term (1 year and 3 years). Each scope, lookback period, and term needs one API request, so the default is six requests per scope.

To change the defaults, set the `savingsPlanRecommendationLookbackPeriods` and `savingsPlanRecommendationTerms` template parameters, or edit the **recommendations** property in **config/settings.json**:

```json
{
  "recommendations": {
    "savingsPlans": {
      "lookbackPeriods": ["Last30Days"],
      "terms": ["P1Y", "P3Y"]
    }
  }
}
```

Like retention settings, a redeploy only changes these values when you specify the template parameters. Otherwise, the values in **config/settings.json** are kept.

### How savings plan recommendations are processed

1. The **savingsPlanRecommendations_DailySchedule** trigger runs once per day.
2. The **savingsPlanRecommendations_ExecuteETL** pipeline reads **config/settings.json** and keeps the supported scopes and the configured lookback periods and terms.
3. The **savingsPlanRecommendations_ExecuteScope** pipeline runs the **queries_ETL_ingestion** pipeline once for each lookback period and term. The **queries_CostManagement_ExecuteQuery** pipeline calls the API, follows `nextLink` to get all pages, and saves the results as parquet.
4. Results are saved in the **ingestion/Recommendations/{scope}/Microsoft-SavingsPlans-{term}-{lookbackPeriod}** folder. The folder doesn't include a date, so each run replaces the previous recommendation for the same scope, term, and lookback period. Hubs don't keep a history of savings plan recommendations.
5. If you use Data Explorer or Microsoft Fabric, data is ingested into the `Recommendations_raw` table and transformed using the `Recommendations_transform_v1_2()` function.

An empty response is valid. For example, Cost Management doesn't recommend more commitment when your existing savings plans and reservations already cover your eligible usage. An empty response doesn't fail the pipeline. The previous parquet file for that scope, term, and lookback period is removed from storage, but Data Explorer keeps the last recommendation that was ingested. Use `x_RecommendationDate` (the end of the lookback period) and `x_IngestionTime` to check how current a recommendation is.

After you buy a savings plan, recommendations can take up to seven days to reflect the purchase. For more information, see [Savings plan recommendations](/azure/cost-management-billing/savings-plan/purchase-recommendations).

### Savings plan recommendation details

Savings plan recommendations use the following columns in the Recommendations managed dataset:

| Column                      | Value                                                                                               |
| --------------------------- | --------------------------------------------------------------------------------------------------- |
| ResourceId                  | Scope the recommendation was requested for, like the EA billing account or subscription.            |
| SubAccountId                | Subscription the recommendation applies to. Only set for single-scope recommendations.              |
| x_EffectiveCostBefore       | Eligible on-demand cost for the lookback period without the recommended savings plan.               |
| x_EffectiveCostAfter        | Total cost for the lookback period with the recommended savings plan.                               |
| x_EffectiveCostSavings      | Savings for the lookback period with the recommended savings plan.                                  |
| x_RecommendationDate        | Last usage date in the lookback period.                                                             |
| x_RecommendationDescription | Term and commitment amount, like "Buy a 3-year savings plan with an hourly commitment of 12.5 USD". |
| x_RecommendationDetails     | Recommended commitment, commitment scenarios, and usage history. See the following table.           |
| x_RecommendationId          | ID of the recommendation in Cost Management.                                                        |
| x_ResourceGroupName         | Resource group the recommendation applies to. Only set for resource group scopes.                   |

The **x_RecommendationDetails** column includes:

| Property                 | Description                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------ |
| AllRecommendationDetails | Array of commitment scenarios Cost Management evaluated, with the same properties as the recommended one.    |
| BenefitCost              | Cost of the savings plan commitment for the lookback period.                                                 |
| CommitmentAmount         | Recommended commitment amount per `CommitmentGranularity`, in `CurrencyCode`.                                |
| CommitmentDiscountScope  | Benefit scope: `Shared` or `Single`.                                                                         |
| CommitmentGranularity    | Granularity of the commitment amount, like `Hourly`.                                                         |
| CoveragePercentage       | Percentage of eligible usage the commitment would cover.                                                     |
| CurrencyCode             | Currency of all cost and commitment amounts.                                                                 |
| LookbackPeriodDuration   | Lookback period as an ISO 8601 duration, like `P30D`.                                                        |
| LookbackPeriodEnd        | Last usage date in the lookback period.                                                                      |
| LookbackPeriodStart      | First usage date in the lookback period.                                                                     |
| OverageCost              | On-demand cost for usage above the commitment during the lookback period.                                    |
| SavingsPercentage        | Savings compared to on-demand cost.                                                                          |
| SkuName                  | Savings plan SKU, like `Compute_Savings_Plan`.                                                               |
| SkuTerm                  | Term in months.                                                                                              |
| TotalHours               | Number of hours in the lookback period. All costs cover these hours.                                         |
| UsageCharges             | On-demand charges for each `UsageGrain` interval in the lookback period that the recommendation is based on. |
| UsageGrain               | Granularity of `UsageCharges`, like `Hourly`.                                                                |
| UtilizationPercentage    | Average percentage of the commitment that would be used.                                                     |
| WastageCost              | Cost of the unused part of the commitment during the lookback period.                                        |

Each lookback period and term is a separate recommendation for the same usage, and savings plan and reservation recommendations can cover the same usage. Don't add savings across them. Filter to one lookback period and term before you summarize savings, and group by `CurrencyCode`.

The following query returns the recommended commitment and all evaluated scenarios for 3-year savings plans based on the last 30 days of usage:

```kusto
Recommendations()
| where x_SourceType == 'SavingsPlanRecommendations'
| where toint(x_RecommendationDetails.SkuTerm) == 36 and tostring(x_RecommendationDetails.LookbackPeriodDuration) == 'P30D'
| mv-expand Scenario = x_RecommendationDetails.AllRecommendationDetails
| project
    ResourceId,
    CurrencyCode        = tostring(x_RecommendationDetails.CurrencyCode),
    RecommendedAmount   = toreal(x_RecommendationDetails.CommitmentAmount),
    ScenarioAmount      = toreal(Scenario.commitmentAmount),
    ScenarioSavings     = toreal(Scenario.savingsAmount),
    ScenarioCoverage    = toreal(Scenario.coveragePercentage),
    ScenarioUtilization = toreal(Scenario.averageUtilizationPercentage)
| order by ResourceId asc, ScenarioAmount asc
```

<br>

## Add custom recommendations

You can add custom recommendations by uploading query files to the **config/queries** folder in hub storage. The pipeline picks up new query files automatically on the next daily run.

### File naming convention

Name query files using the `{dataset}-{provider}-{type}.json` format:

- **Dataset** — The target dataset (for example, `Recommendations`).
- **Provider** — The provider of the service data is for (for example, `Microsoft`, `Contoso`).
- **Type** — The recommendation type identifier using PascalCase (for example, `StoppedVMs`, `IdleCosmosDB`).

For example: `Recommendations-Contoso-IdleCosmosDB.json`

### Query file format

Each query file is a JSON file with the following properties:

```json
{
  "dataset": "Recommendations",
  "provider": "Microsoft",
  "query": "<Azure Resource Graph query>",
  "queryEngine": "ResourceGraph",
  "scope": "Tenant",
  "source": "<descriptive source name>",
  "type": "<unique type identifier>",
  "version": "1.0"
}
```

| Property      | Description                                                                                                                                                                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dataset`     | Must be `"Recommendations"`.                                                                                                                                                                                                                       |
| `provider`    | Provider name (for example, `"Microsoft"`).                                                                                                                                                                                                        |
| `query`       | The Azure Resource Graph query to execute, on a single line.                                                                                                                                                                                       |
| `queryEngine` | Must be `"ResourceGraph"`.                                                                                                                                                                                                                         |
| `scope`       | Query scope. Use `"Tenant"` to query all subscriptions the Data Factory managed identity has access to within the tenant. Cross-tenant queries aren't supported but resources delegated via Azure Lighthouse are included in tenant-scope queries. |
| `source`      | Descriptive name for the recommendation source (for example, `"Azure Advisor"` or `"FinOps hubs"`).                                                                                                                                                |
| `type`        | Programmatic identifier for this recommendation type. Use a `{provider}-{name}` format with alphanumeric characters and hyphens only (for example, `"Contoso-IdleCosmosDB"`). This value is used as part of the output file name.                  |
| `version`     | Schema version. Use `"1.0"`.                                                                                                                                                                                                                       |

> [!TIP]
> Don't use `take`, `limit`, or `sample` in your query. Resource Graph stops returning a continuation token when you do, and hubs only ingest the first page of results.

### Required output columns

Your query must return the following columns:

| Column                        | Description                                                                                                                                                                                                             |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ResourceId`                  | Resource ID (lowercase).                                                                                                                                                                                                |
| `ResourceName`                | Resource name (lowercase).                                                                                                                                                                                              |
| `SubAccountId`                | Subscription ID.                                                                                                                                                                                                        |
| `SubAccountName`              | Subscription name. Join with `resourcecontainers` to populate this.                                                                                                                                                     |
| `x_RecommendationCategory`    | Recommendation category. Use `"Cost"`, `"HighAvailability"`, `"OperationalExcellence"`, `"Performance"`, or `"Security"`.                                                                                               |
| `x_RecommendationDate`        | Recommendation date (use `now()` for point-in-time queries).                                                                                                                                                            |
| `x_RecommendationDescription` | Short description of the issue.                                                                                                                                                                                         |
| `x_RecommendationDetails`     | JSON string with additional properties. Include `x_RecommendationProvider`, `x_RecommendationSolution`, `x_RecommendationTypeId`, and `x_ResourceType` along with any custom properties specific to the recommendation. |
| `x_RecommendationId`          | Unique identifier for the recommendation (for example, resource ID + suffix).                                                                                                                                           |
| `x_ResourceGroupName`         | Resource group name (lowercase).                                                                                                                                                                                        |

### Tips for writing queries

- To populate the subscription name, join with `resourcecontainers` at the end of your query:

  ```kusto
  | join kind=leftouter (
      resourcecontainers
      | where type == 'microsoft.resources/subscriptions'
      | project SubAccountName=name, SubAccountId=subscriptionId
  ) on SubAccountId
  | project-away SubAccountId1
  ```

- Generate `x_RecommendationId` by combining the resource ID with a descriptive suffix (for example, `strcat(tolower(id), '-idle')`).
- Build `x_RecommendationDetails` using `tostring(bag_pack(...))` to produce a JSON string. Wrapping with `tostring()` is required because the data pipeline can't serialize dynamic objects to parquet; the value must be a string. You can also use `strcat()` to build a JSON string manually, but `bag_pack()` is recommended because it handles escaping automatically.
- Include `x_RecommendationTypeId` as a stable GUID to uniquely identify the recommendation type across runs.

For examples, review the built-in query files in the [FinOps toolkit source code](https://github.com/microsoft/finops-toolkit/tree/dev/src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/Recommendations)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

- [Recommendations managed dataset](data-model.md#recommendations-managed-dataset)
- [How data is processed in FinOps hubs](data-processing.md)
- [Best practices library](../../best-practices/library.md)

<br>
