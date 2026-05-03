---
title: Python tools
description: Review the Python tools included with the FinOps toolkit SRE Agent for Azure quota, capacity, budgets, anomaly alerts, Resource Graph, FinOps hub health, and Advisor suppressions.
author: msbrett
ms.author: brettwil
ms.date: 05/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand which Python tools the FinOps toolkit SRE Agent includes so that I can use the right Azure API-backed tool for capacity, cost governance, and operations work.
---

# Python tools

The FinOps toolkit SRE Agent includes 12 Python tools that call Azure APIs directly through the agent managed identity. These tools complement the Kusto tools by checking Azure platform state, deploying Cost Management controls, and automating governance tasks that aren't stored in FinOps hub data.

Use Python tools when the agent needs live Azure Resource Manager, Resource Graph, Cost Management, Azure Data Explorer, or Advisor data instead of historical cost and usage data from the FinOps hub.

> [!NOTE]
> The agent managed identity must have enough permission at the target scope to read or update the resources each tool touches. Read tools typically need Reader permissions. Deployment and suppression tools need permissions to create or update the target Cost Management or Advisor resources.

## Source inventory

The following table maps the 12 Python tools documented on this page to their source YAML files. Use this inventory to audit this reference page against the template source. It doesn't assert that no other YAML files exist under `src/templates/sre-agent/tools/`.

| Tool | Source file |
|------|-------------|
| `vm-quota-usage` | `src/templates/sre-agent/tools/vm-quota-usage.yaml` |
| `capacity-reservation-groups` | `src/templates/sre-agent/tools/capacity-reservation-groups.yaml` |
| `sku-availability` | `src/templates/sre-agent/tools/sku-availability.yaml` |
| `non-compute-quotas` | `src/templates/sre-agent/tools/non-compute-quotas.yaml` |
| `deploy-budget` | `src/templates/sre-agent/tools/deploy-budget.yaml` |
| `deploy-bulk-budgets` | `src/templates/sre-agent/tools/deploy-bulk-budgets.yaml` |
| `deploy-anomaly-alert` | `src/templates/sre-agent/tools/deploy-anomaly-alert.yaml` |
| `deploy-bulk-anomaly-alerts` | `src/templates/sre-agent/tools/deploy-bulk-anomaly-alerts.yaml` |
| `resource-graph-query` | `src/templates/sre-agent/tools/resource-graph-query.yaml` |
| `benefit-recommendations` | `src/templates/sre-agent/tools/benefit-recommendations.yaml` |
| `data-freshness-check` | `src/templates/sre-agent/tools/data-freshness-check.yaml` |
| `suppress-advisor-recommendations` | `src/templates/sre-agent/tools/suppress-advisor-recommendations.yaml` |

<br>

## Capacity and quota

Use capacity and quota tools to check VM family quota, capacity reservation group utilization, SKU restrictions, and non-compute service limits before deployment or during recurring capacity reviews.

### `vm-quota-usage`

- **Azure API:** Azure Resource Manager Compute usages API: `Microsoft.Compute/locations/usages`.
- **When to use it:** Use this tool to query VM family quota usage across one or more regions in a subscription. It calculates utilization percentages and flags VM families above warning or critical thresholds.
- **Example prompt:** "Check VM quota usage for subscription `<subscription-id>` in eastus and westus2, and call out any families above 80% utilization."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "locations": ["eastus", "westus2"],
    "quotas": [
      {
        "location": "eastus",
        "name": "Standard DSv5 Family vCPUs",
        "current": 80,
        "limit": 100,
        "utilization_pct": 80,
        "at_risk_80": false,
        "at_risk_95": false
      }
    ],
    "warning_count": 0,
    "critical_count": 0,
    "suppressed_error_count": 0,
    "suppressed_errors": [],
    "errors": []
  }
  ```

### `capacity-reservation-groups`

- **Azure API:** Azure Resource Manager Compute capacity reservation group API: `Microsoft.Compute/capacityReservationGroups`, including capacity reservation instance view and associated virtual machines.
- **When to use it:** Use this tool to list capacity reservation groups in a subscription and compare reserved capacity with allocated virtual machines. It helps find unused capacity, overallocated groups, and zone-specific capacity reservation waste.
- **Example prompt:** "List capacity reservation groups in subscription `<subscription-id>` and identify groups with unused reserved capacity."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "capacity_reservation_groups": [
      {
        "name": "crg-prod-eastus",
        "id": "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Compute/capacityReservationGroups/crg-prod-eastus",
        "resource_group": "<resource-group>",
        "location": "eastus",
        "zones": ["1"],
        "zone": "1",
        "reserved_count": 10,
        "allocated_count": 8,
        "utilization_pct": 80,
        "waste": true,
        "waste_count": 2,
        "overallocated": false,
        "capacity_reservations": ["crg-prod-eastus/Standard_D8s_v5"],
        "virtual_machines_allocated": ["/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Compute/virtualMachines/vm01"],
        "virtual_machines_associated": []
      }
    ],
    "errors": []
  }
  ```

### `sku-availability`

- **Azure API:** Azure Resource Manager SKU APIs for Azure Compute and Azure Data Explorer: `Microsoft.Compute/skus` and `Microsoft.Kusto/locations/skus`.
- **When to use it:** Use this tool to verify whether a VM or Azure Data Explorer SKU is available in a region and whether zone or subscription restrictions could block deployment.
- **Example prompt:** "Check whether Standard_D8s_v5 is available in eastus2, including zone support and any restriction reasons."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "location": "eastus2",
    "sku_filter": "Standard_D8s_v5",
    "resource_provider": "compute",
    "service": "Azure Compute",
    "source_endpoint": "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Compute/skus?api-version=2021-07-01&$filter=location eq 'eastus2'",
    "skus": [
      {
        "name": "Standard_D8s_v5",
        "family": "standardDSv5Family",
        "size": "D8s_v5",
        "zones_available": ["1", "2", "3"],
        "restrictions": []
      }
    ],
    "restriction_summary": {
      "total_skus": 1,
      "restricted_skus": 0,
      "restriction_count": 0,
      "reason_codes": {}
    }
  }
  ```

### `non-compute-quotas`

- **Azure API:** Azure Resource Manager provider usage APIs for supported services, with Azure Resource Graph fallbacks for services that don't expose a direct usage API.
- **When to use it:** Use this tool to review storage, networking, and PaaS quota usage that can block growth even when compute quota is healthy. It marks whether each limit came from an API-reported quota or an estimated fallback.
- **Example prompt:** "Audit non-compute quota usage for subscription `<subscription-id>` in eastus and summarize storage or network limits above 80% utilization."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "services": [
      {
        "service_name": "Storage",
        "resource_type": "Microsoft.Storage/locations/usages",
        "quota_name": "StorageAccounts",
        "current_count": 100,
        "limit": 250,
        "utilization_pct": 40,
        "at_risk": false,
        "count_source": "arm_provider_usages_api",
        "limit_source": "api_reported_limit",
        "limit_type": "api_reported",
        "source_endpoint": "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Storage/locations/eastus/usages?api-version=2023-05-01",
        "location": "eastus",
        "scope": "regional"
      }
    ],
    "quotas": [
      {
        "subscription_id": "<subscription-id>",
        "service_name": "Storage",
        "service": "Storage",
        "resource_type": "Microsoft.Storage/locations/usages",
        "quota_name": "StorageAccounts",
        "name": "StorageAccounts",
        "location": "eastus",
        "scope": "regional",
        "current_count": 100,
        "current": 100,
        "limit": 250,
        "utilization_pct": 40,
        "at_risk": false,
        "at_risk_80": false,
        "at_risk_95": false,
        "count_source": "arm_provider_usages_api",
        "limit_source": "api_reported_limit",
        "limit_type": "api_reported",
        "source_endpoint": "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Storage/locations/eastus/usages?api-version=2023-05-01"
      }
    ],
    "at_risk_count": 0,
    "api_reported_limit_count": 1,
    "estimated_limit_count": 0,
    "suppressed_count": 0,
    "errors": []
  }
  ```

<br>

## Budget and alert deployment

Use budget and alert deployment tools to create Cost Management controls for a single subscription or apply the same control across enabled subscriptions in a management group.

### `deploy-budget`

- **Azure API:** Azure Resource Manager Consumption budgets API: `Microsoft.Consumption/budgets`.
- **When to use it:** Use this tool to create or update a subscription-level Cost Management budget with notification thresholds and contact emails.
- **Example prompt:** "Create a monthly budget named SubscriptionBudget for subscription `<subscription-id>` with an amount of 50000 and notify finops@example.com."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "budget_name": "SubscriptionBudget",
    "amount": 50000,
    "time_grain": "Monthly",
    "contact_emails": ["finops@example.com"],
    "status_code": 201,
    "budget": {
      "id": "/subscriptions/<subscription-id>/providers/Microsoft.Consumption/budgets/SubscriptionBudget",
      "name": "SubscriptionBudget",
      "type": "Microsoft.Consumption/budgets"
    },
    "status": "created"
  }
  ```

### `deploy-bulk-budgets`

- **Azure API:** Azure Resource Graph to discover enabled subscriptions, then Azure Resource Manager Consumption budgets API: `Microsoft.Consumption/budgets`.
- **When to use it:** Use this tool to deploy the same Cost Management budget across all enabled subscriptions under a management group.
- **Example prompt:** "Deploy a monthly 50000 budget named SubscriptionBudget to every enabled subscription in management group `<management-group-id>` and notify finops@example.com."
- **Sample output shape:**

  ```json
  {
    "management_group": "<management-group-id>",
    "budget_name": "SubscriptionBudget",
    "amount": 50000,
    "contact_emails": ["finops@example.com"],
    "subscription_count": 2,
    "created_or_updated": 2,
    "failed": 0,
    "deployments": [
      {
        "subscription_id": "<subscription-id>",
        "subscription_name": "Production",
        "budget_name": "SubscriptionBudget",
        "status": "created",
        "status_code": 201,
        "error": null
      }
    ]
  }
  ```

### `deploy-anomaly-alert`

- **Azure API:** Azure Resource Manager Cost Management scheduled actions API: `Microsoft.CostManagement/scheduledActions`.
- **When to use it:** Use this tool to create or update a daily Cost Management anomaly alert scheduled action for one subscription.
- **Example prompt:** "Create a cost anomaly alert for subscription `<subscription-id>` that sends daily anomaly notifications to finops@example.com."
- **Sample output shape:**

  ```json
  {
    "subscription_id": "<subscription-id>",
    "scheduled_action_name": "cost-anomaly-alert",
    "email_recipients": ["finops@example.com"],
    "status_code": 201,
    "anomaly_alert": {
      "id": "/subscriptions/<subscription-id>/providers/Microsoft.CostManagement/scheduledActions/cost-anomaly-alert",
      "name": "cost-anomaly-alert",
      "kind": "InsightAlert"
    },
    "status": "created"
  }
  ```

### `deploy-bulk-anomaly-alerts`

- **Azure API:** Azure Resource Graph to discover enabled subscriptions, then Azure Resource Manager Cost Management scheduled actions API: `Microsoft.CostManagement/scheduledActions`.
- **When to use it:** Use this tool to deploy the same cost anomaly alert configuration across enabled subscriptions under a management group.
- **Example prompt:** "Deploy cost anomaly alerts to all enabled subscriptions in management group `<management-group-id>` and send notifications to finops@example.com."
- **Sample output shape:**

  ```json
  {
    "management_group": "<management-group-id>",
    "email_recipients": ["finops@example.com"],
    "subscription_count": 2,
    "created_or_updated": 2,
    "failed": 0,
    "deployments": [
      {
        "subscription_id": "<subscription-id>",
        "subscription_name": "Production",
        "scheduled_action_name": "cost-anomaly-alert",
        "status": "updated",
        "status_code": 200,
        "error": null
      }
    ]
  }
  ```

<br>

## Resource analysis

Use resource analysis tools when the agent needs live Azure inventory, configuration, or commitment discount recommendation data outside the FinOps hub.

### `resource-graph-query`

- **Azure API:** Azure Resource Graph resources API: `Microsoft.ResourceGraph/resources`.
- **When to use it:** Use this tool to run Azure Resource Graph KQL across one or more subscriptions for inventory, configuration drift, governance checks, and subscription-scale troubleshooting.
- **Example prompt:** "Run a Resource Graph query across my subscriptions to list unattached managed disks by subscription, resource group, size, and age."
- **Sample output shape:**

  ```json
  {
    "rows": [
      {
        "subscriptionId": "<subscription-id>",
        "resourceGroup": "<resource-group>",
        "name": "disk01",
        "type": "microsoft.compute/disks"
      }
    ],
    "count": 1,
    "errors": [],
    "total_records": 1,
    "result_truncated": false,
    "subscriptions": ["<subscription-id>"]
  }
  ```

### `benefit-recommendations`

- **Azure API:** Azure Resource Manager Cost Management benefit recommendations API: `Microsoft.CostManagement/benefitRecommendations`.
- **When to use it:** Use this tool to retrieve reservation and savings plan recommendations at a billing scope, including recommendation type, term, savings, cost, and break-even details.
- **Example prompt:** "Get three-year benefit recommendations for billing account scope `<billing-scope>` using a Last30Days lookback and summarize the largest savings opportunities."
- **Sample output shape:**

  ```json
  {
    "billing_scope": "<billing-scope>",
    "lookback_period": "Last30Days",
    "term": "P3Y",
    "recommendations": [
      {
        "type": "SP",
        "savings": 12000,
        "cost": 30000,
        "total_cost": 30000,
        "cost_without_benefit": 42000,
        "term": "P3Y",
        "break_even": "P8M",
        "id": "/providers/Microsoft.Billing/billingAccounts/<billing-account>/providers/Microsoft.CostManagement/benefitRecommendations/<recommendation-id>",
        "name": "<recommendation-id>"
      }
    ],
    "count": 1
  }
  ```

<br>

## Hub management

Use hub management tools to verify whether FinOps hub data is current enough for reliable scheduled reports and agent answers. Use `data-freshness-check` as the source of truth for hub freshness before relying on stale memory, raw KQL rollups, or ingestion timestamp checks.

### `data-freshness-check`

- **Azure API:** Azure Data Explorer REST query API (`/v1/rest/query` or `/v2/rest/query`) on the configured FinOps hub cluster.
- **When to use it:** Use this tool to check data freshness for FinOps hub functions such as `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()`. It reports latest data dates, stale functions, and functions without data. Treat `Costs()` as the authoritative freshness signal. If `Costs()` is 3 days old or newer, don't report the hub as stale even if older memory, raw KQL, or ingestion timestamp checks disagree.
- **Example prompt:** "Check data freshness for the FinOps hub at `<cluster-uri>` in the hub database and tell me which functions are stale."
- **Sample output shape:**

  ```json
  {
    "cluster_uri": "https://<cluster>.kusto.windows.net",
    "database": "hub",
    "functions": [
      {
        "function_name": "Costs()",
        "source_dataset": "Costs",
        "expected_export_dataset": "focuscost",
        "row_count": 100000,
        "latest_data_date": "2026-05-01T00:00:00Z",
        "latest_ingestion_time": null,
        "staleness_days": 1,
        "is_stale": false,
        "has_data": true,
        "schema_status": "ok",
        "schema_column_count": 120,
        "required_for_hub_health": true,
        "diagnostic_code": "OK",
        "diagnostic_message": null
      }
    ],
    "total_functions": 4,
    "stale_count": 0,
    "empty_count": 0,
    "error_count": 0,
    "hub_data_stale": false,
    "attention_required": false,
    "status": "healthy",
    "diagnostics": [],
    "freshest_function": {},
    "stalest_function": {},
    "authoritative_freshness_signal": {
      "function_name": "Costs()",
      "latest_data_date": "2026-05-01T00:00:00Z",
      "staleness_days": 1,
      "is_stale": false,
      "has_data": true,
      "row_count": 100000
    },
    "source_of_truth": {
      "tool": "data-freshness-check",
      "method": "direct_adx_rest_query",
      "endpoint": "/v2/rest/query",
      "authoritative_function": "Costs()",
      "freshness_threshold_days": 3,
      "supersedes": ["stale memory conclusions", "raw KQL freshness rollups", "Kusto ingestion timestamp checks"]
    }
  }
  ```

<br>

## Advisor

Use Advisor tools when the agent needs to apply governance decisions to Azure Advisor recommendations.

### `suppress-advisor-recommendations`

- **Azure API:** Azure Resource Graph to find Advisor recommendations, then Azure Resource Manager Advisor suppressions API: `Microsoft.Advisor/recommendations/suppressions`.
- **When to use it:** Use this tool to suppress selected Azure Advisor recommendation types across subscriptions under a management group for a limited time to live.
- **Example prompt:** "Suppress the default Advisor recommendation types for management group `<management-group-id>` for 30 days and report how many recommendations were suppressed."
- **Sample output shape:**

  ```json
  {
    "management_group_id": "<management-group-id>",
    "days": 30,
    "ttl": "P30D",
    "recommendation_type_ids": ["89515250-1243-43d1-b4e7-f9437cedffd8"],
    "found_count": 10,
    "suppressed_count": 10,
    "failed_count": 0,
    "suppressions": [
      {
        "subscription_id": "<subscription-id>",
        "recommendation_id": "/subscriptions/<subscription-id>/providers/Microsoft.Advisor/recommendations/<recommendation-id>",
        "recommendation_type_id": "89515250-1243-43d1-b4e7-f9437cedffd8",
        "suppression_id": "<suppression-guid>",
        "ttl": "P30D",
        "status": "suppressed",
        "status_code": 201,
        "error": null
      }
    ]
  }
  ```

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/PythonTools)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Anomaly management](../../framework/understand/anomalies.md)
- [Budgeting](../../framework/quantify/budgeting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)

Related solutions:

- [FinOps toolkit SRE Agent](overview.md)
- [FinOps toolkit SRE Agent tools](tools.md)
- [FinOps toolkit SRE Agent Kusto tools](kusto-tools.md)

<br>
