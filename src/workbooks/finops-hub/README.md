# FinOps hub workbook

The FinOps hub workbook provides native Azure Monitor views for FinOps hub data. It preserves the cost, usage, rate optimization, data quality, and AI workload reports from the FinOps hub dashboard. It also adds Foundry infrastructure, Foundry agents, and Supply views.

## Configure the workbook

Select these resources in the workbook toolbar:

- A FinOps hub Azure Data Explorer cluster.
- The FinOps hub database.
- One or more Log Analytics workspaces that contain Foundry agent telemetry.
- One or more Foundry accounts for platform metrics.

The workbook discovers resources with Azure Resource Graph. It does not store workspace resource IDs in KQL.

## Data sources

The workbook uses Azure Data Explorer for FinOps hub data, Azure Monitor Logs for Foundry agent telemetry, Azure Monitor Metrics for Foundry platform metrics, and Azure Resource Graph for resource discovery.

Azure Monitor supports queries across up to 100 Log Analytics workspaces in one request. Reduce the workspace selection if the tenant has more than 100 eligible workspaces.
