# Cost analysis

Spend, forecast, trend, and cost broken down by resource or tag — plus the data-source decision that determines whether any of it scales.

`azure-cost-management` documents the Cost Management APIs themselves. This page covers choosing the data path and reading the results correctly.

## Choose the data path first

Three ways to get cost data, in descending order of scale:

| Path                | When                                   | How                                             |
| ------------------- | -------------------------------------- | ----------------------------------------------- |
| FinOps hub Kusto    | A hub is deployed and covers the scope | Query the hub's ADX or Fabric database directly |
| Cost Management API | No hub, or a small scope               | `az rest` against the query API                 |
| Hub storage exports | Fallback for small datasets only       | Read Parquet/CSV from the hub storage account   |

**Push aggregation into Kusto when a hub exists.** A production hub can hold tens of GB and hundreds of millions of rows. Summarizing in the engine and returning only the result set is the difference between a working answer and a query that never completes.

Discover a hub cluster:

```kusto
resources
| where type =~ 'microsoft.kusto/clusters'
| where tags['ftk-tool'] == 'FinOps hubs'
| project name, resourceGroup, subscriptionId, uri = properties.uri
```

For local or offline analysis, the `ftklocal` Kusto emulator hosts the same hub database schema. See the `finops-toolkit` skill for the hub query catalog and table shapes.

## Cost summary and forecast

```bash
az rest --method post \
  --url "https://management.azure.com/subscriptions/<subId>/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{
    "type": "ActualCost",
    "timeframe": "MonthToDate",
    "dataset": { "granularity": "None", "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } } }
  }'
```

Forecast uses the same shape against `.../forecast`.

## Cost by tag

Add a grouping to the dataset:

```json
"dataset": {
  "granularity": "None",
  "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } },
  "grouping": [ { "type": "TagKey", "name": "<tagName>" } ]
}
```

**When this returns nothing but resources are clearly tagged**, there are two causes and they need different advice:

1. **The tag isn't enabled as a cost-allocation dimension.** Cost Management only dimensions cost by tags that have been explicitly enabled in settings. This is the usual cause and it's a settings change, not a tagging problem.
2. **Month-to-date lag.** Tag-dimensioned data populates behind raw cost. Early in a month it can be empty even when configured correctly.

Confirm the tag is applied to resources first (see `tags-and-policy.md`), then check the setting. Reporting "no cost by that tag" without distinguishing these sends people to re-tag an estate that's already tagged.

## Reading cost results

- **Billed versus effective cost.** When `BilledCost` is zero — common for commitment-covered usage — fall back to `EffectiveCost`. Treating zero as zero spend undercounts anything covered by a reservation or savings plan. Hub queries and API queries must apply the same rule or the two paths disagree.
- **Amortized versus actual.** Actual cost shows a reservation purchase as a lump on the purchase date. Amortized spreads it across the term. Use amortized for unit economics and trend; use actual for invoice reconciliation. Say which one you used.
- **Currency.** Multi-billing-account estates can mix currencies. Never sum across them without converting, and state the currency in the headline number.
- **Month-to-date is not a month.** Comparing an in-progress month against complete months in a trend produces a fake decline. Either exclude the current month or annotate it.
- **Empty results early in the month.** Cost Management data lags by a day or more. Say so rather than reporting "$0".

## Resource cost ranking

Group by `ResourceId` and order descending. Two things to watch:

- **Resource IDs are not resource names.** Present a readable name and resource group; keep the ID for drill-down.
- **The long tail matters.** Top 10 by cost usually finds the obvious. Concentration — what share the top 10 represent — is often the more useful number. A flat distribution and a top-heavy one call for different strategies.

## Trend

Monthly granularity over 6-12 months, grouped as needed. When reporting a change, separate the causes:

- Rate change — same usage, different price (commitment expired, region moved, SKU changed)
- Usage change — genuinely more or less consumption
- Scope change — subscriptions added or removed from the comparison

Reporting "cost rose 40%" without identifying which of these is the driver isn't an answer. A subscription added to the scope isn't a cost increase at all.

## Related

- `cost-data-source` for the full hub-versus-API decision and chunking large tenants
- `forecasting-budgeting` for forecast method and budget design
- `anomaly-investigation` for root-causing a spike
- `finops-toolkit` for the hub Kusto query catalog
- `azure-cost-management` → `references/azure-cost-exports.md` for scheduled FOCUS exports
