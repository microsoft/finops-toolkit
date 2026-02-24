# Cost optimization report

Generate a comprehensive cost optimization report for the current Azure environment. Works with or without FinOps hubs.

## Phase 1: Discovery

1. Determine scope: Ask the user for subscription(s) or management group, or use the current `az account show` context.
2. Verify authentication: `az account show` — confirm logged in and correct tenant.
3. Check permissions: Reader role is sufficient for all detection queries. Note if elevated permissions are available.
4. Check for FinOps hubs: Read `.ftk/environments.local.md` to see if a FinOps hub is connected. If available, note it for Phase 2.

## Phase 2: Data collection

Run these data collection steps in parallel where possible. Save intermediate results as you go.

### 2a: Orphaned resources

Detect unused resources generating waste with zero workload value.

Use the queries from `references/azure-orphaned-resources.md` to scan for:
- Unattached managed disks
- Unused network interfaces
- Orphaned public IP addresses
- Idle NAT gateways
- Orphaned snapshots (source disk deleted, age > 30 days)
- Idle load balancers (empty backend pools)
- Empty availability sets
- Orphaned NSGs

For each category, capture: count, estimated monthly cost, resource list.

### 2b: Advisor cost recommendations

Query Azure Advisor for all cost recommendations.

Use `references/azure-advisor.md` for query patterns:

```bash
az advisor recommendation list --category Cost --output json
```

Categorize recommendations by type: right-size VMs, shutdown idle VMs, reserved instances, delete unused disks, and other.

Calculate total potential monthly savings from Advisor.

### 2c: Commitment discount status

Analyze current commitment discount coverage and opportunities.

Use `references/azure-savings-plans.md` and `references/azure-reservations.md` for:
- Current savings plan coverage and utilization
- Current reservation coverage and utilization
- New purchase recommendations from the Benefit Recommendations API
- Gap analysis: what percentage of eligible compute spend is covered

Use `references/azure-commitment-discount-decision.md` for the decision framework when recommending new purchases.

### 2d: FinOps hubs data (if available)

If a FinOps hub is connected (from Phase 1), query for additional context:

```kusto
// Cost trend - last 3 months
Costs
| where ChargePeriodStart >= ago(90d)
| summarize TotalCost = sum(EffectiveCost) by Month = startofmonth(ChargePeriodStart), ServiceName
| order by Month desc, TotalCost desc
```

```kusto
// Top cost growth services
Costs
| where ChargePeriodStart >= ago(60d)
| extend Month = startofmonth(ChargePeriodStart)
| summarize MonthlyCost = sum(EffectiveCost) by Month, ServiceName
| evaluate pivot(Month, sum(MonthlyCost), ServiceName)
```

Look for cost anomalies and trends that inform optimization priorities.

## Phase 3: Analysis

### 3a: Validate top rightsizing recommendations

For the top 5 Advisor right-size VM recommendations (by savings amount), validate with the Retail Prices API.

Use `references/azure-retail-prices.md` to look up current and target SKU prices. Compare Advisor's estimated savings against actual retail price deltas.

### 3b: VM utilization deep dive (if VM Insights available)

For the top rightsizing candidates, check actual utilization metrics if VM Insights is enabled.

Use `references/azure-vm-rightsizing.md` for:
- 14-day CPU P95 analysis
- Memory utilization (if VM Insights agent deployed)
- Burst pattern detection (P99 check)

Skip this step if VM Insights is not available — note it as a recommendation for future optimization maturity.

### 3c: Categorize by effort and risk

Organize all findings into four categories:

| Category | Effort | Risk | Examples |
|----------|--------|------|----------|
| **Quick wins** | Low | Zero | Delete orphaned resources, remove unused IPs |
| **Rightsizing** | Medium | Low | Resize underutilized VMs (requires restart) |
| **Commitment optimization** | Medium | Medium | Purchase savings plans or reservations |
| **Architecture changes** | High | Variable | Redesign for cost efficiency, migrate to PaaS |

## Phase 4: Report

Generate a markdown report with the following structure:

### Report template

```markdown
# Cost Optimization Report — {subscription/environment name}
**Generated:** {date}
**Scope:** {subscription(s) or management group}
**FinOps Hubs:** {connected / not connected}

## Executive summary

- **Total identified monthly savings:** ${amount}
- **Quick wins (zero risk):** ${amount} across {count} resources
- **Rightsizing opportunities:** ${amount} across {count} VMs
- **Commitment discount opportunities:** ${amount} estimated
- **Current commitment coverage:** {percentage}%

## Quick wins — orphaned resources

| Resource Type | Count | Est. Monthly Cost | Action |
|--------------|-------|-------------------|--------|
| Unattached disks | {n} | ${cost} | Delete |
| Orphaned public IPs | {n} | ${cost} | Delete |
| ... | ... | ... | ... |
| **Total** | **{n}** | **${cost}** | |

## Rightsizing recommendations

### Top VM recommendations (validated)

| VM | Current SKU | Target SKU | CPU P95 | Savings/mo | Risk |
|----|-------------|------------|---------|------------|------|
| {name} | {current} | {target} | {%} | ${savings} | Low |
| ... | ... | ... | ... | ... | ... |

{Include notes on burst patterns, memory utilization where available}

## Commitment discount opportunities

### Current coverage
- Savings plan utilization: {%}
- Reservation utilization: {%}
- Total eligible compute covered: {%}

### Recommendations
{Summarize Benefit Recommendations API findings}
{Reference azure-commitment-discount-decision.md framework for purchase guidance}

## Cost trends (FinOps hubs)
{Include if FinOps hubs connected, otherwise note: "Connect FinOps hubs for trend analysis — run /ftk-hubs-connect"}

## Next steps

1. **Immediate (this week):** Delete orphaned resources — ${amount}/mo savings
2. **Short-term (this month):** Resize top {n} VMs — ${amount}/mo savings
3. **Medium-term (this quarter):** Evaluate commitment discount purchases
4. **Ongoing:** Deploy VM Insights for memory-aware rightsizing, connect FinOps hubs for trend analysis

## Audit trail

| Data Source | Query Time | Records |
|-------------|-----------|---------|
| Resource Graph (orphaned) | {timestamp} | {count} |
| Advisor recommendations | {timestamp} | {count} |
| Benefit Recommendations API | {timestamp} | {count} |
| FinOps hubs (if connected) | {timestamp} | {count} |
```

### Report guidance

- Format all currency values with the appropriate billing currency
- Include resource IDs or names for actionable items
- Flag any data gaps (e.g., "Memory metrics unavailable — VM Insights not deployed")
- If FinOps hubs are not connected, recommend `/ftk-hubs-connect` for deeper analysis
- Save the report to `results/cost-optimization-{date}.md`
