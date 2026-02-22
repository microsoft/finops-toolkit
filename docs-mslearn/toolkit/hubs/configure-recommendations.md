---
title: Configure FinOps hubs recommendations
description: Learn about the recommendations available in FinOps hubs and how to add custom recommendations.
author: flanakin
ms.author: micflan
ms.date: 02/13/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub user, I want to understand the recommendations available in FinOps hubs and how to add my own.
---

<!-- prettier-ignore-start -->
# Configure FinOps hubs recommendations
<!-- prettier-ignore-end -->

FinOps hubs collect recommendations from multiple sources and ingest them into the [Recommendations managed dataset](data-model.md#recommendations-managed-dataset) alongside reservation recommendations from Cost Management exports. Recommendations are sourced from Azure Resource Graph using a configurable set of queries that pull Azure Advisor recommendations and identify various optimization scenarios based on resource configuration. Queries are managed in simple JSON files in storage, making it easy to add your own custom recommendations by uploading query files to hub storage.

<br>

## Prerequisites

Before you begin, you must have:

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub).
- Assigned the **Reader** role to the Data Factory managed identity on the management groups or subscriptions you want to query. This permission must be configured separately from the FinOps hub deployment.

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

- **Azure Database for MySQL**
  - [Migrate legacy MySQL servers](../../best-practices/databases.md#migrate-legacy-mysql-servers)
- **Azure Database for PostgreSQL**
  - [Migrate legacy PostgreSQL servers](../../best-practices/databases.md#migrate-legacy-postgresql-servers)
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
- Build `x_RecommendationDetails` using `bag_pack()` to construct a dynamic object. You can also use `strcat()` to build a JSON string manually, but `bag_pack()` is recommended because it handles escaping and produces a proper dynamic type.
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
