---
name: finops-toolkit
description: This skill should be used when the user asks about "FinOps hubs", "FinOps toolkit", "KQL queries", "Kusto", "cost data analysis", "Hub database", "Costs function", "Prices function", "Recommendations function", "FinOps hubs deployment", "Azure Data Explorer", "ADX cluster", or any FinOps hubs operations.
license: MIT
compatibility: Requires Azure MCP Server and Azure CLI authentication. For queries, requires Database Viewer access to FinOps hub ADX cluster.
metadata:
  author: microsoft
  version: "1.0"
---

# FinOps Toolkit

FinOps hubs are a scalable platform for cloud cost analytics, insights, and optimization built on Azure Data Explorer (Kusto) or Microsoft Fabric RTI. This skill covers KQL-based cost analysis and hub infrastructure deployment.

## Task routing

Load only the references relevant to the task at hand.

| Task | Load these references first |
|------|-----------------------------|
| Write or run a KQL query | `references/finops-hubs.md`, `references/queries/finops-hub-database-guide.md` |
| Use a pre-built query | `references/queries/INDEX.md`, then the specific `.kql` file |
| Deploy a new hub | `references/finops-hubs-deployment.md`, `toolkit/hubs/deploy.md`, `toolkit/hubs/template.md` |
| Upgrade a hub | `references/finops-hubs-deployment.md`, `toolkit/hubs/upgrade.md`, `toolkit/hubs/compatibility.md` |
| Savings / ESR analysis | `toolkit/hubs/savings-calculations.md`, `savings-summary-report.kql`, `commitment-discount-utilization.kql` |
| Reservation recommendations | `reservation-recommendation-breakdown.kql`, `toolkit/hubs/savings-calculations.md` |
| FOCUS columns / mapping | `focus/what-is-focus.md`, `focus/mapping.md` |
| Power BI setup | `toolkit/power-bi/setup.md`, `toolkit/power-bi/connector.md` |
| Troubleshooting / errors | `toolkit/help/troubleshooting.md`, `toolkit/help/errors.md` |
| PowerShell commands | `toolkit/powershell/powershell-commands.md` + the specific command file |
| Connect to hub for first time | `references/workflows/ftk-hubs-connect.md`, `references/settings-format.md` |
| Check hub health / version | `references/workflows/ftk-hubs-healthCheck.md`, `toolkit/hubs/compatibility.md` |

## Database functions

The Hub database exposes four analytic functions. Always use the `Hub` database — never `Ingestion`.

| Function | Purpose | Key columns |
|----------|---------|-------------|
| `Costs()` | Cost and usage analytics (FOCUS-aligned) | `BilledCost`, `EffectiveCost`, `ContractedCost`, `ListCost`, `ServiceName`, `ResourceName`, `Tags` |
| `Prices()` | Price sheets with list, contracted, and effective pricing | `ListUnitPrice`, `ContractedUnitPrice`, `x_EffectiveUnitPrice`, `PricingUnit` |
| `Recommendations()` | Reservation and savings plan recommendations | `x_EffectiveCostBefore`, `x_EffectiveCostAfter`, `x_EffectiveCostSavings` |
| `Transactions()` | Commitment purchases, refunds, and exchanges | `BilledCost`, `ChargeCategory`, `x_SkuTerm`, `x_TransactionType` |

Columns prefixed with `x_` are toolkit enrichments added during ingestion (e.g., `x_ResourceGroupName`, `x_CommitmentDiscountSavings`, `x_TotalSavings`). Full column definitions: `references/queries/finops-hub-database-guide.md`.

## Query execution

- Uses **KQL (Kusto)**, not SQL
- Default analysis window: 30 days
- Always include `tenant` — cross-tenant (B2B) scenarios fail without it

Environment settings are read from `.ftk/environments.local.md` at the project root. Use the `default` environment unless the user specifies one. See `references/settings-format.md` for the file format.

```json
{
  "cluster-uri": "<cluster-uri from .ftk/environments.local.md>",
  "database": "Hub",
  "tenant": "<tenant from .ftk/environments.local.md>",
  "query": "<KQL query>"
}
```

## Query catalog

Check the catalog before writing custom KQL. Read the `.kql` file, substitute parameters, then execute. See `references/queries/INDEX.md` for the full scenario-to-query matrix.

| Query | Description |
|-------|-------------|
| [costs-enriched-base.kql](references/queries/catalog/costs-enriched-base.kql) | Base query with full enrichment and savings logic for all cost columns. **Start here for custom analytics.** |
| [monthly-cost-trend.kql](references/queries/catalog/monthly-cost-trend.kql) | Total billed and effective cost by month for trend analysis and executive reporting. |
| [monthly-cost-change-percentage.kql](references/queries/catalog/monthly-cost-change-percentage.kql) | Month-over-month cost change percentage for both billed and effective costs. |
| [top-services-by-cost.kql](references/queries/catalog/top-services-by-cost.kql) | Top N Azure services by cost. Key for cost visibility. |
| [top-resource-types-by-cost.kql](references/queries/catalog/top-resource-types-by-cost.kql) | Top N resource types by cost and usage (VMs, storage, etc.). |
| [top-resource-groups-by-cost.kql](references/queries/catalog/top-resource-groups-by-cost.kql) | Top N resource groups by effective cost. |
| [quarterly-cost-by-resource-group.kql](references/queries/catalog/quarterly-cost-by-resource-group.kql) | Effective cost by resource group for quarterly or multi-month reporting. |
| [cost-by-region-trend.kql](references/queries/catalog/cost-by-region-trend.kql) | Effective cost by Azure region for regional cost driver analysis. |
| [cost-by-financial-hierarchy.kql](references/queries/catalog/cost-by-financial-hierarchy.kql) | Cost allocation by billing profile, invoice section, team, product, and app for showback/chargeback. |
| [cost-anomaly-detection.kql](references/queries/catalog/cost-anomaly-detection.kql) | Detect unusual cost spikes or drops using statistical anomaly detection. |
| [cost-forecasting-model.kql](references/queries/catalog/cost-forecasting-model.kql) | Project future costs for budgeting and planning with configurable forecast horizon. |
| [service-price-benchmarking.kql](references/queries/catalog/service-price-benchmarking.kql) | Compare list, contracted, effective, negotiated, and commitment prices by service. |
| [commitment-discount-utilization.kql](references/queries/catalog/commitment-discount-utilization.kql) | Reservation and savings plan utilization analysis for rate optimization. |
| [savings-summary-report.kql](references/queries/catalog/savings-summary-report.kql) | Total realized savings and Effective Savings Rate (ESR) KPI. |
| [top-commitment-transactions.kql](references/queries/catalog/top-commitment-transactions.kql) | Top N reservation or savings plan purchases by cost impact. |
| [top-other-transactions.kql](references/queries/catalog/top-other-transactions.kql) | Top N non-commitment, non-usage transactions (support, marketplace, etc.). |
| [reservation-recommendation-breakdown.kql](references/queries/catalog/reservation-recommendation-breakdown.kql) | Microsoft reservation recommendations with projected savings and break-even analysis. |

## Infrastructure deployment

Deployment targets: Azure Data Explorer clusters, Microsoft Fabric workspaces, Cost Management exports, Power BI dashboards.

Key commands: `az deployment`, `az kusto`, `az storage`. PowerShell: `Deploy-FinOpsHub`.

Estimated cost: ~$120/mo + $10/mo per $1M in monitored spend.

For detailed documentation: `references/finops-hubs-deployment.md`

## Reference files

| File | Description |
|------|-------------|
| [references/finops-hubs.md](references/finops-hubs.md) | Analysis guide: KQL execution, query catalog protocol, tool matrix, performance rules. **Read before any cost query.** |
| [references/finops-hubs-deployment.md](references/finops-hubs-deployment.md) | Deployment and configuration: ADX clusters, Fabric, Data Factory, exports, Key Vault, Power BI dashboards. |
| [references/settings-format.md](references/settings-format.md) | Format specification for `.ftk/environments.local.md` — named environments with cluster-uri, tenant, subscription, and resource-group. |
| [references/queries/INDEX.md](references/queries/INDEX.md) | Query catalog with scenario-to-query matrix, parameter docs, and usage guidance for all 17 pre-built KQL queries. |
| [references/queries/finops-hub-database-guide.md](references/queries/finops-hub-database-guide.md) | Hub database schema: all four functions, column definitions, enrichment columns, and query best practices. **Read before writing custom KQL.** |
| [references/workflows/ftk-hubs-connect.md](references/workflows/ftk-hubs-connect.md) | Workflow to discover FinOps hub instances via Resource Graph, connect, and save environment config. |
| [references/workflows/ftk-hubs-healthCheck.md](references/workflows/ftk-hubs-healthCheck.md) | Health check workflow: version comparison against stable/dev releases, upgrade guidance, and diagnostic steps. |

## Microsoft Learn documentation

Official Microsoft documentation for FinOps and the FinOps toolkit. Source: [learn.microsoft.com](https://learn.microsoft.com/cloud-computing/finops/).

### FinOps overview

| File | Description |
|------|-------------|
| [overview.md](references/docs-mslearn/overview.md) | Microsoft Cloud FinOps overview |
| [implementing-finops-guide.md](references/docs-mslearn/implementing-finops-guide.md) | Guide to implementing FinOps in Azure |
| [conduct-iteration.md](references/docs-mslearn/conduct-iteration.md) | Conducting a FinOps iteration |

### FinOps Framework

| File | Description |
|------|-------------|
| [finops-framework.md](references/docs-mslearn/framework/finops-framework.md) | FinOps Framework overview |
| [capabilities.md](references/docs-mslearn/framework/capabilities.md) | FinOps capabilities reference |

#### Understand cloud usage and cost

| File | Description |
|------|-------------|
| [understand-cloud-usage-cost.md](references/docs-mslearn/framework/understand/understand-cloud-usage-cost.md) | Understand pillar overview |
| [ingestion.md](references/docs-mslearn/framework/understand/ingestion.md) | Data ingestion |
| [allocation.md](references/docs-mslearn/framework/understand/allocation.md) | Cost allocation |
| [reporting.md](references/docs-mslearn/framework/understand/reporting.md) | Reporting and analytics |
| [anomalies.md](references/docs-mslearn/framework/understand/anomalies.md) | Anomaly management |

#### Quantify business value

| File | Description |
|------|-------------|
| [quantify-business-value.md](references/docs-mslearn/framework/quantify/quantify-business-value.md) | Quantify pillar overview |
| [planning.md](references/docs-mslearn/framework/quantify/planning.md) | Planning and estimating |
| [budgeting.md](references/docs-mslearn/framework/quantify/budgeting.md) | Budgeting |
| [forecasting.md](references/docs-mslearn/framework/quantify/forecasting.md) | Forecasting |
| [benchmarking.md](references/docs-mslearn/framework/quantify/benchmarking.md) | Benchmarking |
| [unit-economics.md](references/docs-mslearn/framework/quantify/unit-economics.md) | Unit economics |

#### Optimize cloud usage and cost

| File | Description |
|------|-------------|
| [optimize-cloud-usage-cost.md](references/docs-mslearn/framework/optimize/optimize-cloud-usage-cost.md) | Optimize pillar overview |
| [architecting.md](references/docs-mslearn/framework/optimize/architecting.md) | Architecting for cloud |
| [workloads.md](references/docs-mslearn/framework/optimize/workloads.md) | Workload optimization |
| [rates.md](references/docs-mslearn/framework/optimize/rates.md) | Rate optimization |
| [licensing.md](references/docs-mslearn/framework/optimize/licensing.md) | Licensing and SaaS |
| [sustainability.md](references/docs-mslearn/framework/optimize/sustainability.md) | Cloud sustainability |

#### Manage the FinOps practice

| File | Description |
|------|-------------|
| [manage-finops.md](references/docs-mslearn/framework/manage/manage-finops.md) | Manage pillar overview |
| [onboarding.md](references/docs-mslearn/framework/manage/onboarding.md) | FinOps onboarding |
| [education.md](references/docs-mslearn/framework/manage/education.md) | FinOps education and enablement |
| [operations.md](references/docs-mslearn/framework/manage/operations.md) | FinOps operations |
| [governance.md](references/docs-mslearn/framework/manage/governance.md) | FinOps and governance |
| [assessment.md](references/docs-mslearn/framework/manage/assessment.md) | FinOps assessment |
| [invoicing-chargeback.md](references/docs-mslearn/framework/manage/invoicing-chargeback.md) | Invoicing and chargeback |
| [tools-services.md](references/docs-mslearn/framework/manage/tools-services.md) | Tools and services |
| [intersecting-disciplines.md](references/docs-mslearn/framework/manage/intersecting-disciplines.md) | Intersecting disciplines |

### FOCUS

| File | Description |
|------|-------------|
| [what-is-focus.md](references/docs-mslearn/focus/what-is-focus.md) | What is FOCUS (FinOps Open Cost and Usage Specification) |
| [mapping.md](references/docs-mslearn/focus/mapping.md) | FOCUS column mapping |
| [metadata.md](references/docs-mslearn/focus/metadata.md) | FOCUS metadata |
| [convert.md](references/docs-mslearn/focus/convert.md) | Converting data to FOCUS |
| [validate.md](references/docs-mslearn/focus/validate.md) | Validating FOCUS data |
| [conformance-summary.md](references/docs-mslearn/focus/conformance-summary.md) | FOCUS conformance summary |
| [conformance-full-report.md](references/docs-mslearn/focus/conformance-full-report.md) | FOCUS conformance full report |

### Cost optimization best practices

| File | Description |
|------|-------------|
| [general.md](references/docs-mslearn/best-practices/general.md) | General cost optimization best practices |
| [compute.md](references/docs-mslearn/best-practices/compute.md) | Compute cost optimization |
| [databases.md](references/docs-mslearn/best-practices/databases.md) | Database cost optimization |
| [networking.md](references/docs-mslearn/best-practices/networking.md) | Networking cost optimization |
| [storage.md](references/docs-mslearn/best-practices/storage.md) | Storage cost optimization |
| [web.md](references/docs-mslearn/best-practices/web.md) | Web and app service cost optimization |
| [library.md](references/docs-mslearn/best-practices/library.md) | Best practices library |

### FinOps toolkit

| File | Description |
|------|-------------|
| [finops-toolkit-overview.md](references/docs-mslearn/toolkit/finops-toolkit-overview.md) | FinOps toolkit overview |
| [changelog.md](references/docs-mslearn/toolkit/changelog.md) | Toolkit changelog |
| [roadmap.md](references/docs-mslearn/toolkit/roadmap.md) | Toolkit roadmap |
| [open-data.md](references/docs-mslearn/toolkit/open-data.md) | Open data (pricing units, regions, services, resource types) |
| [data-lake-storage-connectivity.md](references/docs-mslearn/toolkit/data-lake-storage-connectivity.md) | Data lake storage connectivity |

### FinOps hubs

| File | Description |
|------|-------------|
| [finops-hubs-overview.md](references/docs-mslearn/toolkit/hubs/finops-hubs-overview.md) | FinOps hubs overview |
| [deploy.md](references/docs-mslearn/toolkit/hubs/deploy.md) | Deploy FinOps hubs |
| [upgrade.md](references/docs-mslearn/toolkit/hubs/upgrade.md) | Upgrade FinOps hubs |
| [template.md](references/docs-mslearn/toolkit/hubs/template.md) | Hub Bicep template reference |
| [data-model.md](references/docs-mslearn/toolkit/hubs/data-model.md) | Hub database data model. **Read for authoritative schema reference.** |
| [data-processing.md](references/docs-mslearn/toolkit/hubs/data-processing.md) | Data processing pipeline |
| [savings-calculations.md](references/docs-mslearn/toolkit/hubs/savings-calculations.md) | Savings calculations methodology |
| [compatibility.md](references/docs-mslearn/toolkit/hubs/compatibility.md) | Version compatibility matrix |
| [configure-scopes.md](references/docs-mslearn/toolkit/hubs/configure-scopes.md) | Configure cost export scopes |
| [configure-dashboards.md](references/docs-mslearn/toolkit/hubs/configure-dashboards.md) | Configure dashboards |
| [configure-remote-hubs.md](references/docs-mslearn/toolkit/hubs/configure-remote-hubs.md) | Configure remote hubs |
| [configure-ai.md](references/docs-mslearn/toolkit/hubs/configure-ai.md) | Configure AI copilot for FinOps hubs |
| [private-networking.md](references/docs-mslearn/toolkit/hubs/private-networking.md) | Private networking configuration |

### Alerts

| File | Description |
|------|-------------|
| [finops-alerts-overview.md](references/docs-mslearn/toolkit/alerts/finops-alerts-overview.md) | FinOps alerts overview |
| [configure-finops-alerts.md](references/docs-mslearn/toolkit/alerts/configure-finops-alerts.md) | Configure FinOps alerts |

### Bicep registry

| File | Description |
|------|-------------|
| [modules.md](references/docs-mslearn/toolkit/bicep-registry/modules.md) | Bicep registry modules |
| [scheduled-actions.md](references/docs-mslearn/toolkit/bicep-registry/scheduled-actions.md) | Scheduled actions module |

### Optimization engine

| File | Description |
|------|-------------|
| [overview.md](references/docs-mslearn/toolkit/optimization-engine/overview.md) | Optimization engine overview |
| [setup-options.md](references/docs-mslearn/toolkit/optimization-engine/setup-options.md) | Setup options |
| [configure-workspaces.md](references/docs-mslearn/toolkit/optimization-engine/configure-workspaces.md) | Configure workspaces |
| [customize.md](references/docs-mslearn/toolkit/optimization-engine/customize.md) | Customize the optimization engine |
| [reports.md](references/docs-mslearn/toolkit/optimization-engine/reports.md) | Optimization reports |
| [suppress-recommendations.md](references/docs-mslearn/toolkit/optimization-engine/suppress-recommendations.md) | Suppress recommendations |
| [troubleshooting.md](references/docs-mslearn/toolkit/optimization-engine/troubleshooting.md) | Troubleshooting |
| [faq.md](references/docs-mslearn/toolkit/optimization-engine/faq.md) | Frequently asked questions |

### Power BI

| File | Description |
|------|-------------|
| [reports.md](references/docs-mslearn/toolkit/power-bi/reports.md) | Power BI reports overview |
| [setup.md](references/docs-mslearn/toolkit/power-bi/setup.md) | Power BI setup |
| [connector.md](references/docs-mslearn/toolkit/power-bi/connector.md) | FinOps toolkit Power BI connector |
| [template-app.md](references/docs-mslearn/toolkit/power-bi/template-app.md) | Power BI template app |
| [help-me-choose.md](references/docs-mslearn/toolkit/power-bi/help-me-choose.md) | Help me choose a Power BI report |
| [cost-summary.md](references/docs-mslearn/toolkit/power-bi/cost-summary.md) | Cost summary report |
| [rate-optimization.md](references/docs-mslearn/toolkit/power-bi/rate-optimization.md) | Rate optimization report |
| [workload-optimization.md](references/docs-mslearn/toolkit/power-bi/workload-optimization.md) | Workload optimization report |
| [governance.md](references/docs-mslearn/toolkit/power-bi/governance.md) | Governance report |
| [data-ingestion.md](references/docs-mslearn/toolkit/power-bi/data-ingestion.md) | Data ingestion report |
| [invoicing.md](references/docs-mslearn/toolkit/power-bi/invoicing.md) | Invoicing report |

### Workbooks

| File | Description |
|------|-------------|
| [finops-workbooks-overview.md](references/docs-mslearn/toolkit/workbooks/finops-workbooks-overview.md) | FinOps workbooks overview |
| [customize-workbooks.md](references/docs-mslearn/toolkit/workbooks/customize-workbooks.md) | Customize workbooks |
| [optimization.md](references/docs-mslearn/toolkit/workbooks/optimization.md) | Optimization workbook |
| [governance.md](references/docs-mslearn/toolkit/workbooks/governance.md) | Governance workbook |

### Fabric

| File | Description |
|------|-------------|
| [create-fabric-workspace-finops.md](references/docs-mslearn/fabric/create-fabric-workspace-finops.md) | Create a Fabric workspace for FinOps |

### PowerShell commands

| File | Description |
|------|-------------|
| [powershell-commands.md](references/docs-mslearn/toolkit/powershell/powershell-commands.md) | PowerShell commands overview |

#### Cost Management commands

| File | Description |
|------|-------------|
| [cost-management-commands.md](references/docs-mslearn/toolkit/powershell/cost/cost-management-commands.md) | Cost Management commands overview |
| [get-finopscostexport.md](references/docs-mslearn/toolkit/powershell/cost/get-finopscostexport.md) | Get-FinOpsCostExport |
| [new-finopscostexport.md](references/docs-mslearn/toolkit/powershell/cost/new-finopscostexport.md) | New-FinOpsCostExport |
| [start-finopscostexport.md](references/docs-mslearn/toolkit/powershell/cost/start-finopscostexport.md) | Start-FinOpsCostExport |
| [remove-finopscostexport.md](references/docs-mslearn/toolkit/powershell/cost/remove-finopscostexport.md) | Remove-FinOpsCostExport |
| [add-finopsserviceprincipal.md](references/docs-mslearn/toolkit/powershell/cost/add-finopsserviceprincipal.md) | Add-FinOpsServicePrincipal |

#### Open data commands

| File | Description |
|------|-------------|
| [open-data-commands.md](references/docs-mslearn/toolkit/powershell/data/open-data-commands.md) | Open data commands overview |
| [get-finopspricingunit.md](references/docs-mslearn/toolkit/powershell/data/get-finopspricingunit.md) | Get-FinOpsPricingUnit |
| [get-finopsregion.md](references/docs-mslearn/toolkit/powershell/data/get-finopsregion.md) | Get-FinOpsRegion |
| [get-finopsresourcetype.md](references/docs-mslearn/toolkit/powershell/data/get-finopsresourcetype.md) | Get-FinOpsResourceType |
| [get-finopsservice.md](references/docs-mslearn/toolkit/powershell/data/get-finopsservice.md) | Get-FinOpsService |

#### FinOps hubs commands

| File | Description |
|------|-------------|
| [finops-hubs-commands.md](references/docs-mslearn/toolkit/powershell/hubs/finops-hubs-commands.md) | FinOps hubs commands overview |
| [deploy-finopshub.md](references/docs-mslearn/toolkit/powershell/hubs/deploy-finopshub.md) | Deploy-FinOpsHub |
| [get-finopshub.md](references/docs-mslearn/toolkit/powershell/hubs/get-finopshub.md) | Get-FinOpsHub |
| [initialize-finopshubdeployment.md](references/docs-mslearn/toolkit/powershell/hubs/initialize-finopshubdeployment.md) | Initialize-FinOpsHubDeployment |
| [register-finopshubproviders.md](references/docs-mslearn/toolkit/powershell/hubs/register-finopshubproviders.md) | Register-FinOpsHubProviders |
| [remove-finopshub.md](references/docs-mslearn/toolkit/powershell/hubs/remove-finopshub.md) | Remove-FinOpsHub |
| [remove-finopshubscope.md](references/docs-mslearn/toolkit/powershell/hubs/remove-finopshubscope.md) | Remove-FinOpsHubScope |

#### Toolkit commands

| File | Description |
|------|-------------|
| [finops-toolkit-commands.md](references/docs-mslearn/toolkit/powershell/toolkit/finops-toolkit-commands.md) | Toolkit commands overview |
| [get-finopstoolkitversion.md](references/docs-mslearn/toolkit/powershell/toolkit/get-finopstoolkitversion.md) | Get-FinOpsToolkitVersion |

### Help and support

| File | Description |
|------|-------------|
| [help-options.md](references/docs-mslearn/toolkit/help/help-options.md) | Help options |
| [support.md](references/docs-mslearn/toolkit/help/support.md) | Support |
| [troubleshooting.md](references/docs-mslearn/toolkit/help/troubleshooting.md) | Troubleshooting |
| [errors.md](references/docs-mslearn/toolkit/help/errors.md) | Error reference |
| [deploy.md](references/docs-mslearn/toolkit/help/deploy.md) | Deployment help |
| [data-dictionary.md](references/docs-mslearn/toolkit/help/data-dictionary.md) | Data dictionary |
| [terms.md](references/docs-mslearn/toolkit/help/terms.md) | Terms and definitions |
| [contributors.md](references/docs-mslearn/toolkit/help/contributors.md) | Contributors |
