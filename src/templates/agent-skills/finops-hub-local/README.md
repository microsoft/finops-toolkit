# FinOps hub (local) skill

A skill for running FinOps hub cost analytics **locally** — against a Kusto emulator
in Docker — without deploying anything to Azure.

## What it is

The FinOps Toolkit's KQL analytics (ingestion transforms, hub view functions, open
data, and the query catalog) loaded into a local [Kusto emulator] so an analyst can
query FOCUS cost exports on their own machine. It runs the **same** analytic IP a
deployed hub runs; only the cloud-orchestration glue (Data Factory, storage,
deployment) is replaced by local scripts in `src/templates/finops-hub-local/`.

## When to use this skill vs the cloud `finops-toolkit` skill

| Use **finops-hub-local** when… | Use **finops-toolkit** when… |
|--------------------------------|------------------------------|
| You have FOCUS Parquet exports and want to query them offline | You have (or want to deploy) a real hub on Azure Data Explorer / Fabric |
| You're developing/testing hub KQL without standing up Azure | You need scale, multi-user access, AAD auth, or Power BI |
| No Azure subscription / Azure MCP available | You're connecting to a live `*.kusto.windows.net` cluster |

## Prerequisites

- Docker
- PowerShell 7+ (`pwsh`)
- FOCUS cost exports as Parquet

## Getting started

See `SKILL.md` for the task-routing table and the quickstart. In short, from
`src/templates/finops-hub-local/`:

```bash
make up && make load-ftk-kql && make ingest
pwsh scripts/ftk.ps1 query "Costs() | summarize sum(EffectiveCost) by ServiceName | top 10 by sum_EffectiveCost"
```

[Kusto emulator]: https://learn.microsoft.com/azure/data-explorer/kusto-emulator-overview
