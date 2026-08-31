# FinOps hub dashboard canvas

The FinOps hub dashboard is a repository-scoped GitHub Copilot canvas. It connects to a local Kusto emulator or a remote Azure Data Explorer cluster.

The dashboard includes these views:

- Cost overview
- Allocation
- Rate optimization
- Usage and unit economics
- Anomalies and forecast
- AI tokenomics
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

## Run the canvas

Reload GitHub Copilot extensions after you change the source. The repository-scoped extension must report `sourceScope: "project"` from the `get_build_info` action.

The installed user extension uses `http://127.0.0.1:47821/`. The repository-scoped extension uses `http://127.0.0.1:47822/` so both sources can run during development. Connection preferences remain in the user's Copilot extension artifacts directory and aren't stored in the repository.

Remote connections require a Microsoft Entra tenant ID. The dashboard passes this tenant to Azure CLI when it requests the Kusto access token, so authentication doesn't inherit the active Azure CLI tenant. The dashboard doesn't save access tokens or other credentials.

## Test the canvas

Run the dependency-free test suite:

```console
npm run test-dashboard
```
