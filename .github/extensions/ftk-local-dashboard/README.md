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
- Capacity
- Read-only KQL query editor

## Capacity

The Capacity workspace shows seven quota areas: App Service, Azure AI, Compute, Azure SQL, Storage, capacity reservations, and Premium SSD v2.

The workspace doesn't combine unlike readings into one score. It keeps these concepts separate:

- Provider quota entitlement
- Billed demand
- Observed resource inventory
- Physical Azure capacity
- Pricing commitments

Only registered Compute metrics support quota utilization and headroom calculations. Unknown metrics stay visible as descriptive rows. Stale or invalid rows don't receive quota-health calculations.

## Run the canvas

Reload GitHub Copilot extensions after you change the source. The repository-scoped extension must report `sourceScope: "project"` from the `get_build_info` action.

The installed user extension uses `http://127.0.0.1:47821/`. The repository-scoped extension uses `http://127.0.0.1:47822/` so both sources can run during development. Connection preferences remain in the user's Copilot extension artifacts directory and aren't stored in the repository.

## Test the canvas

Run the dependency-free test suite:

```console
npm run test-dashboard
```
