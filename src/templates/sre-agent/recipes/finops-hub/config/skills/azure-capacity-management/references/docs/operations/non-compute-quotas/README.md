---
title: Non-compute quotas
parent: Capacity & quotas
nav_order: 3
---

# Non-compute quota guide

## When to use this guide

Azure capacity planning extends well beyond vCPU cores. Storage accounts, App Service plans, Azure Cosmos DB accounts, and emerging platform services all impose limits that can block customer onboarding if they are not tracked and increased ahead of demand. This guide captures the baseline limits, monitoring patterns, and escalation paths for the most common non-compute services so operations teams can manage quota holistically without juggling separate notes.

## Service quick reference

| Service | Default scope & notable limits | How to check usage | How to request more |
| --- | --- | --- | --- |
| **Azure Storage** | [250 standard storage accounts per subscription and region (increaseable to 500)](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests); [per-account throughput and egress limits vary by SKU](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#scalability-targets-for-standard-storage-accounts). | [`az storage account show-usage`, `Get-AzStorageUsage`](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests), or [`az quota usage list --resource-provider Microsoft.Storage`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest). | Use [**My quotas > Storage** to submit a numeric limit](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests); [fallback to support ticket if auto-approval fails](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal). |
| **Azure App Service** | [App Service plans capped per region (10 Free/Shared, 100 per resource group for higher tiers); storage quota enforced per plan and per region/resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits). | [`az quota usage list --resource-provider Microsoft.Web`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) to export plan counts; portal usage charts per plan. | [Submit App Service quota adjustments through **My quotas > Web**; escalate via support when non-adjustable](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal). |
| **Azure Cosmos DB** | [500 databases/containers per account, request throughput change limits per 5-minute window; higher limits require support review](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase). | Monitor provisioned throughput and request units in portal/metrics; track account limits manually. | [Create a support request (Quota type: Azure Cosmos DB) with workload details and desired limits](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase). |

If your workloads depend on other services (for example, Azure OpenAI, Dev Box, Azure Deployment Environments), extend this guide by adding their limits, monitoring commands, and support workflows so everyone's using the same reference.

## Azure Storage quota operations

### Key limits and dependencies

- [Each subscription can hold up to 250 standard storage accounts per region by default; increases up to 500 require approval](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
- [Per-account scalability targets (aggregate ingress/egress, request rate, replication constraints) depend on the account kind](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#scalability-targets-for-standard-storage-accounts). Include these constraints when forecasting storage demand.

### Usage and tooling

- Run [`az storage account show-usage --location <region>` to list the current count versus limit for storage accounts in a region](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
- [PowerShell administrators can retrieve the same data with `Get-AzStorageUsage` for automation pipelines](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
- Use [`az quota usage list --scope /subscriptions/<subId> --resource-provider Microsoft.Storage` to generate machine-readable quota snapshots](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) that align with other quota reporting scripts.

### Request workflow

1. [Open **Azure portal > Quotas > Storage** and select the subscription](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
2. [Choose the region and select the pencil icon under **Request adjustment** to enter a new limit (up to 500)](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
3. [Submit the request; most approvals complete within minutes](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests).
4. [If the request is denied or the limit is non-adjustable, use the **Create support request** link presented in **My quotas** to route the request to Microsoft support](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).


## Azure App Service quota operations

### Key limits and dependencies

- [Free and Shared plans are limited to 10 instances per region, while Basic, Standard, Premium, and Isolated tiers allow up to 100 plans per resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits).
- [Storage quotas are enforced per App Service plan (10 GB Basic, 50 GB Standard, 250 GB Premium, 1 TB Isolated) and aggregated across plans within the same region/resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits).
- [Scale-out ceilings range from 3 instances (Basic) to 30 instances (Premium v2/v3/v4) and 100 instances (Isolated)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits).

### Usage and tooling

- Use [`az quota usage list --resource-provider Microsoft.Web --scope /subscriptions/<subId>` to pull plan counts and limits for automation or dashboards](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest).
- [Review per-plan metrics (connections, storage consumption) in the App Service blade to anticipate when plan-level storage limits approach exhaustion](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-app-service-limits).

### Request workflow

1. [Navigate to **Azure portal > Quotas > Web** and locate the target region](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).
2. [Select the relevant quota row (for example, `AppServicePlanCount`) and choose **New quota request**](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).
3. [Enter the desired limit and submit. Azure applies the increase automatically when capacity is available](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).
4. [If the quota is non-adjustable or the request fails, generate a support ticket from the same blade with justification and deployment timelines](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).


## Azure Cosmos DB quota operations

### Key limits and dependencies

- [Each account supports up to 500 databases and containers combined, and provisioned throughput changes are limited to 25 updates per five-minute interval](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).
- [Azure Cosmos DB enforces additional request limits (for example, list/get keys operations) that can throttle automation if not accounted for](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).

### Request workflow

1. [From **Help + Support**, create a new support request with Issue type **Service and subscription limits (quotas)** and Quota type **Azure Cosmos DB**](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).
2. [Provide workload context, current limits, desired values, and any diagnostic artifacts requested on the Additional details tab](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).
3. [Specify severity and preferred contact, then submit. The Cosmos DB engineering team typically responds within 24 hours to confirm or gather more information](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).

[Because increases require manual approval, plan requests well ahead of large onboarding waves and track throughput usage via Azure Monitor to justify the ask](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).

## Monitoring and alerting

- [Turn on quota monitoring in the Azure portal; adjustable quotas become clickable, allowing you to open the alert rule wizard directly from **My quotas**](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting).
- [Create usage alert rules with thresholds (for example, 70/85/95 percent) and severity levels aligned to escalation procedures](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting).
- [Integrate alerts with cost monitoring by configuring budget alerts for the same subscriptions, ensuring cost anomalies and quota exhaustion trigger complementary notifications](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending).

## Extend this guide

Maintain a backlog of additional services the community relies on (Azure OpenAI, Azure SQL, Azure Deployment Environments). For each addition, document:

- Default limits and any preview restrictions.
- CLI/PowerShell/REST commands to retrieve usage.
- The portal or support path required for increases.
- Monitoring hooks and escalation timelines.
