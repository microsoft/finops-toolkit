# FinOps hub dashboard canvas

The FinOps hub dashboard is a repository-scoped GitHub Copilot canvas. It connects to a local Kusto emulator or a remote Azure Data Explorer cluster.

The canvas supports desktop layouts only. Its minimum width is 1280 pixels. Narrow host surfaces scroll horizontally and do not reflow the dashboard.

The dashboard includes these views:

- Cost overview
- Allocation
- Rate optimization
- Usage and unit economics
- Anomalies and forecast
- AI tokenomics
- AI Foundry platform operations
- Foundry agents
- AI and emerging workloads
- Supply
- Read-only KQL query editor

## Supply

The Supply workspace shows seven quota areas: App Service, Azure AI, Compute, Azure SQL, Storage, capacity reservations, and Premium SSD v2.

The workspace doesn't combine unlike readings into one score. It keeps these concepts separate:

- Provider quota entitlement
- Billed demand
- Observed resource inventory
- Physical Azure capacity
- Pricing commitments

Compute queries load their base KQL from `src/queries/catalog`. The family heatmap reads quota at family level. It reads offer restrictions from the smallest-vCPU SKU in each family and region. Only registered Compute metrics support quota utilization and headroom calculations. Unknown metrics stay visible as descriptive rows. Stale or invalid rows don't receive quota-health calculations.

App Service uses the catalog-backed `AppServiceUsage` source. Its matrix shows exact plan SKU by region, including Total Regional VMs as a separate row. The left bar reports subscription quota status, while the percentage reports aggregate quota utilization. This view doesn't infer physical regional capacity or combine billed demand with quota.

Azure SQL uses the catalog-backed `SqlSubscriptionUsage` source. Its matrix includes the current regional quotas for Azure SQL Database and Synapse vCores, logical servers, and the three SQL Managed Instance hardware generations. Legacy subnet and single-vCore counters and subscription-wide free-offer counters don't receive utilization calculations. Zero and negative limits remain visible as no usable quota instead of being treated as zero utilization or unlimited capacity. Region access and zone-redundant access require separate validation because the usage rows don't report those permissions.

Compute, App Service, and Azure SQL share the dependency-free controls in `public/ui.js` and `public/ui.css`. These helpers render filters, matrix panes, detail tabs, and pagination without owning service data or quota semantics. Other Supply areas continue to use their existing controls.

## AI Foundry

The AI Foundry view uses the configured tenant ID. Azure Resource Graph finds accessible Azure OpenAI and AI Services accounts.

The view reproduces the 11 panels in the canonical Azure Managed Grafana dashboard. It queries these Azure Monitor platform metrics:

- `InputTokens`
- `OutputTokens`
- `TotalTokens`
- `ModelRequests`
- `TimeToLastByte`
- `AzureOpenAITTLTInMS`
- `AzureOpenAITokenPerSecond`
- `AzureOpenAIContextTokensCacheMatchRate`

The default time range is seven days. The dashboard applies the same deployment and status-code filters, aggregations, legends, chart styles, and 24-column panel layout as the Grafana dashboard.

The estate view groups accounts by subscription and region and sends each regional Metrics Batch request for no more than 50 resources. Select an account to drill down to its model deployments. The dashboard uses the configured tenant ID for resource discovery and Azure Monitor authentication.

The **Estimated Cost** panel replaces the Grafana dashboard's fixed prices with rates from `Prices()`. Input, output, and total token tiles and charts also show the corresponding estimated cost for each deployment and time bucket. A match requires the exact model, version, deployment SKU, region class, currency, billing scope, token direction, and pricing block. The view uses the current-period rate first. If that rate isn't available, it can use the immediately previous monthly price sheet and labels the estimate as provisional. It doesn't use older rates. Unmatched or ambiguous usage remains unpriced. Only `Costs()` is authoritative for billed and effective cost.

## Foundry agents

The Foundry agents view uses Azure Resource Graph to find accessible Microsoft Foundry projects. One Azure Resource Manager batch request gets each project's Application Insights connection. The view queries only the linked Log Analytics workspaces. Every panel and control uses the same 30-second cached tenant and time-range result.

The view identifies Microsoft Foundry `invoke_agent`, `chat`, and `execute_tool` spans. Each agent row must have a `microsoft.foundry.project.id` value. Chat spans without an agent identity are assigned by operation ID only when the trace has exactly one Microsoft Foundry agent. Selecting a Foundry account includes only agents whose project is under that account.

Estimated run cost uses uncached input, cached input, and output tokens from chat spans. Each token class uses an eligible `Prices()` rate with the same model, version, deployment SKU, region class, billing scope, currency, and effective-period checks as the Foundry view. Token charts and agent, model, and recent-run tables show each token class beside its estimated cost. Missing or conflicting rates remain explicit as partial or unmatched coverage. Provisioned deployments aren't presented as token-priced.

Trace estimates aren't billed cost. Exact `Costs()` resource ID matches appear in a separate authoritative billed-cost field. Foundry telemetry identities aren't treated as cost resource IDs.

## Run the canvas

Reload GitHub Copilot extensions after you change the source. The repository-scoped extension must report `sourceScope: "project"` from the `get_build_info` action.

The installed user extension uses `http://127.0.0.1:47821/`. The repository-scoped extension uses `http://127.0.0.1:47822/` so both sources can run during development. Connection preferences remain in the user's Copilot extension artifacts directory and aren't stored in the repository.

The tenant ID controls remote Hub authentication and Azure resource discovery. Local Hub queries do not authenticate. The AI Foundry view still requires the tenant ID in local mode. The dashboard passes the tenant to Azure CLI for each access token. Authentication does not inherit the active Azure CLI tenant. The dashboard does not save access tokens or other credentials.

## Test the canvas

Run the dependency-free test suite:

```console
npm run test-dashboard
```
