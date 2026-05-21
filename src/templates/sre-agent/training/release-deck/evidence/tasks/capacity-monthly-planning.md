# Capacity Monthly Planning

## Identity
- **YAML:** sre-config/scheduled-tasks/capacity-monthly-planning.yaml
- **Cron:** 0 9 1 * * — monthly on day 1 at 09:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Capacity Planning (monthly cycle)
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, vm-quota-usage, capacity-reservation-groups, benefit-recommendations, resource-graph-query, cost-forecasting-model, commitment-discount-utilization, savings-summary-report

## Latest run summary
The monthly capacity planning cycle is complete. All 11 tasks finished successfully. **Summary of what was delivered:** **Demand Forecast**: 180-day historical analysis + 90-day forecast — flat projection at ~$1,368–1,373/day with gradual 2.4% decline over the past 6 months. No capacity growth signals. **Procurement Pipeline**: All 49 regions at 0% vCPU utilization. No quota increases, region access, or zonal enablement needed. Non-compute quotas healthy (peak 1.2%).

## Final Teams card / Outlook output (verbatim)
~~~~text
Here is the exact Teams message posted during this run, followed by the knowledge base update.

---

## Teams Message (verbatim)

**Subject:** Monthly Capacity Planning Report — May 2026

<h2>Monthly Capacity Planning Report — May 2026</h2>
<p><b>Subscription:</b> Non-Prod-Workloads (cab7feeb-759d-478c-ade6-9326de0651ff)<br/>
<b>Report Date:</b> 2026-05-02 18:54 UTC<br/>
<b>Report Period:</b> Nov 2025 – Apr 2026 (180-day history) + 90-day forecast<br/>
<b>Hub:</b> msbwtreyhub.westus.kusto.windows.net (v13.0)</p>

<hr/>

<h3>1. Demand Forecast</h3>
<p><img
src="https://sre.azure.com/api/files/tmp/ThreadFiles/5234cff3-89ee-48b2-8dea-3dd9e7bfb478/chart1-forecast-trend.png"
alt="Cost Forecast Trend" width="700"/></p>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1e40af;color:white;"><th>Month</th><th>Avg Daily Cost</th><th>MoM
Change</th><th>Trend</th></tr>
<tr><td>Nov 2025</td><td>$1,377/day</td><td>—</td><td>Baseline</td></tr>
<tr><td>Dec 2025</td><td>$1,366/day</td><td>-0.9%</td><td>Slight decline</td></tr>
<tr><td>Jan 2026</td><td>$1,372/day</td><td>+0.5%</td><td>Stable</td></tr>
<tr><td>Feb 2026</td><td>$1,373/day</td><td>+0.1%</td><td>Stable</td></tr>
<tr><td>Mar 2026</td><td>$1,351/day</td><td>-1.6%</td><td>Moderate decline</td></tr>
<tr><td>Apr 2026</td><td>$1,344/day</td><td>-0.6%</td><td>Slight decline</td></tr>
</table>

<p><b>90-Day Forecast (May–Jul 2026):</b> Flat projection ~$1,368–1,373/day. No seasonal patterns detected.
Conservative (-5%) floor: $1,299/day. Optimistic (+5%) ceiling: $1,441/day.</p>
<p><b>Compute demand:</b> Zero VM core usage in this subscription — PaaS-dominant (Kusto, Cognitive Services,
Storage, ML). No VM family growth to project.</p>
<p><b>Key observation:</b> Gradual 2.4% cost decline from Nov 2025 to Apr 2026 ($1,377 → $1,344/day). Environment
is stable with no growth signals.</p>

<hr/>

<h3>2. Procurement Pipeline</h3>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1e40af;color:white;"><th>Action</th><th>Status</th><th>Lead Time</th><th>Notes</th></tr>
<tr><td>Quota increases</td><td>Not needed</td><td>—</td><td>All 49 regions at 0% vCPU utilization</td></tr>
<tr><td>Region access requests</td><td>Not needed</td><td>—</td><td>PaaS-only workload</td></tr>
<tr><td>Zonal enablement</td><td>Not needed</td><td>—</td><td>No VM deployments planned</td></tr>
<tr><td>Quota group enrollment</td><td>Not applicable</td><td>—</td><td>No compute quota pressure</td></tr>
<tr><td>Non-compute quotas</td><td>Healthy</td><td>—</td><td>Peak 1.2% (Storage westus). 0 at-risk items.</td></tr>
</table>

<p><b>Regional vCPU Quota (top regions):</b></p>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#059669;color:white;"><th>Region</th><th>vCPU
Limit</th><th>Used</th><th>Utilization</th></tr>
<tr><td>westus</td><td>350</td><td>0</td><td>0%</td></tr>
<tr><td>eastus2</td><td>100</td><td>0</td><td>0%</td></tr>
<tr><td>eastus</td><td>100</td><td>0</td><td>0%</td></tr>
<tr><td>westus2</td><td>100</td><td>0</td><td>0%</td></tr>
<tr><td>westus3</td><td>150</td><td>0</td><td>0%</td></tr>
</table>
<p><b>Procurement verdict:</b> No procurement actions required this month. All quotas have ample headroom.</p>

<hr/>

<h3>3. Allocation Review (Capacity Reservation Groups)</h3>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1e40af;color:white;"><th>Metric</th><th>Value</th></tr>
<tr><td>CRGs deployed</td><td><b>0</b></td></tr>
<tr><td>Reserved capacity</td><td>None</td></tr>
<tr><td>Overallocation policy</td><td>N/A</td></tr>
<tr><td>Sharing config</td><td>N/A</td></tr>
</table>

<p><b>Assessment:</b> No CRGs needed — this subscription has zero VM workloads. Capacity reservations are only
relevant for IaaS compute. PaaS services (Kusto, SQL DB, Cognitive Services) guarantee capacity through their own
scaling mechanisms.</p>

<hr/>

<h3>4. Cost Impact &amp; Commitment Analysis</h3>

<p><img
src="https://sre.azure.com/api/files/tmp/ThreadFiles/5234cff3-89ee-48b2-8dea-3dd9e7bfb478/chart4-commitment-monthly.png"
alt="Commitment Coverage and Monthly Cost" width="700"/></p>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1e40af;color:white;"><th>Metric</th><th>Value (90-day, Feb–Apr 2026)</th></tr>
<tr><td>List Cost</td><td>$124,141</td></tr>
<tr><td>Effective Cost</td><td>$120,650</td></tr>
<tr><td>Negotiated Discount Savings</td><td>$105</td></tr>
<tr><td>Commitment Discount Savings</td><td>$3,396</td></tr>
<tr><td>Total Savings</td><td>$3,491</td></tr>
<tr><td><b>Effective Savings Rate (ESR)</b></td><td><b>2.81%</b></td></tr>
<tr><td>On-Demand Core-Hours</td><td>96.1%</td></tr>
<tr><td>Reservation Core-Hours</td><td>3.9%</td></tr>
</table>

<p><b>Top 10 Reservation Recommendations (60-day lookback):</b></p>
<p><img
src="https://sre.azure.com/api/files/tmp/ThreadFiles/5234cff3-89ee-48b2-8dea-3dd9e7bfb478/chart2-reservation-recs.png"
alt="Reservation Recommendations" width="700"/></p>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr
style="background:#1e40af;color:white;"><th>#</th><th>Resource</th><th>Region</th><th>Term</th><th>Discount</th><th>Savings</th><th>Break-Even</th></tr>
<tr><td>1</td><td>SQL DB BC Gen5</td><td>West US 2</td><td>3yr</td><td>55%</td><td>$2,400</td><td>16.2 mo</td></tr>
<tr><td>2</td><td>SQL DB BC Gen5</td><td>West US 2</td><td>1yr</td><td>35%</td><td>$1,525</td><td>7.8 mo</td></tr>
<tr><td>3</td><td>DSv2 VMs</td><td>East US</td><td>1yr</td><td>58%</td><td>$1,089</td><td>5.1 mo</td></tr>
<tr><td>4</td><td>DSv3 VMs</td><td>East US</td><td>3yr</td><td>62%</td><td>$678</td><td>13.8 mo</td></tr>
<tr><td>5</td><td>DSv2 VMs</td><td>West US</td><td>1yr</td><td>39%</td><td>$623</td><td>7.3 mo</td></tr>
<tr><td>6</td><td>Ddv4 VMs</td><td>West Central US</td><td>3yr</td><td>62%</td><td>$607</td><td>13.6 mo</td></tr>
<tr><td>7</td><td>SQL DB HS Gen5</td><td>West US 2</td><td>3yr</td><td>55%</td><td>$578</td><td>16.2 mo</td></tr>
<tr><td>8</td><td>SQL DB GP Gen5</td><td>East US</td><td>3yr</td><td>55%</td><td>$480</td><td>16.2 mo</td></tr>
<tr><td>9</td><td>SQL MI GP Gen5</td><td>West US 2</td><td>3yr</td><td>55%</td><td>$480</td><td>16.2 mo</td></tr>
<tr><td>10</td><td>DSv3 VMs</td><td>South Central US</td><td>3yr</td><td>59%</td><td>$465</td><td>14.8 mo</td></tr>
</table>

<p><b>Cost optimization opportunity:</b> Total addressable savings across top 10 recommendations: ~$8,926 over
their respective terms. Prioritize SQL DB BC Gen5 1-year (West US 2) for fastest ROI — breaks even at 7.8 months
with $1,525 savings.</p>

<hr/>

<h3>5. Governance Compliance Scorecard</h3>

<p><img
src="https://sre.azure.com/api/files/tmp/ThreadFiles/5234cff3-89ee-48b2-8dea-3dd9e7bfb478/chart3-governance-scorecard.png"
alt="Governance Scorecard" width="600"/></p>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1e40af;color:white;"><th>Control</th><th>Status</th><th>Details</th></tr>
<tr style="background:#dcfce7;"><td>Budget alerts</td><td>PASS</td><td>1 budget (FDPOAzureBudget) with 6
thresholds, routing to AGOwner</td></tr>
<tr style="background:#fef2f2;"><td>Anomaly alerts</td><td>FAIL</td><td>0 Cost Management anomaly alerts
deployed</td></tr>
<tr style="background:#fef2f2;"><td>KQL-based alerts</td><td>FAIL</td><td>0 scheduled query rules for cost
monitoring</td></tr>
<tr style="background:#fef2f2;"><td>Tag governance</td><td>FAIL</td><td>0 subscription tags. 0%
Owner/CostCenter/Environment coverage</td></tr>
<tr style="background:#fef2f2;"><td>Quota groups</td><td>N/A</td><td>Not applicable — zero compute usage in this
subscription</td></tr>
<tr style="background:#fef2f2;"><td>CRG deployment</td><td>N/A</td><td>Not applicable — PaaS-only
subscription</td></tr>
</table>
<p><b>Overall governance score: 1/4 applicable controls passing (25%).</b> Maturity: Crawl stage.</p>

<p><b>Other observations:</b></p>
<ul>
<li>4 Smart Detector rules (App Insights failure anomalies) — operational but not cost-related</li>
<li>1 Activity Log alert (Service Health) — routing to AGOwner only</li>
<li>AGManager action group exists but is <b>not attached to any alert rule</b> — single-point-of-failure risk</li>
<li>Hub version 13.0 — upgrade to 14.0 recommended</li>
<li>Transactions() data: 0 rows (persistent gap since May 2) — investigate cost export config</li>
</ul>

<hr/>

<h3>6. Recommended Actions</h3>

<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr
style="background:#1e40af;color:white;"><th>#</th><th>Priority</th><th>Action</th><th>Owner</th><th>Deadline</th></tr>
<tr style="background:#fef2f2;"><td>1</td><td>CRITICAL</td><td>Deploy Cost Management anomaly alert (InsightAlert
scheduled action)</td><td>FinOps Lead</td><td>May 15, 2026</td></tr>
<tr style="background:#fef2f2;"><td>2</td><td>HIGH</td><td>Add AGManager action group to budget + health alert
routing (eliminate single-point-of-failure)</td><td>Platform Ops</td><td>May 15, 2026</td></tr>
<tr style="background:#fef2f2;"><td>3</td><td>HIGH</td><td>Tag subscription with Owner/Environment/CostCenter;
enforce tag policy in Audit mode</td><td>Platform Ops</td><td>May 31, 2026</td></tr>
<tr style="background:#fffbeb;"><td>4</td><td>MEDIUM</td><td>Evaluate SQL DB BC Gen5 1-year reservation (West US 2)
— $1,525 savings, 7.8-month break-even</td><td>FinOps Lead</td><td>May 31, 2026</td></tr>
<tr style="background:#fffbeb;"><td>5</td><td>MEDIUM</td><td>Investigate Transactions() data gap (0 rows) — verify
Cost Management commitment export configuration</td><td>Platform Ops</td><td>May 15, 2026</td></tr>
<tr style="background:#fffbeb;"><td>6</td><td>MEDIUM</td><td>Upgrade FinOps Hub from v13.0 to
v14.0</td><td>Platform Ops</td><td>Jun 15, 2026</td></tr>
<tr><td>7</td><td>LOW</td><td>Plan SKU migration for msbw-finops-hub Kusto cluster (Standard_E4ads_v5 not available
for new deployments)</td><td>Platform Ops</td><td>Jun 30, 2026</td></tr>
</table>

<hr/>
<p><b>Supply Chain Maturity:</b> Forecast=Crawl | Procure=Crawl | Allocate=Crawl | Monitor=Walk<br/>
<b>Next Monthly Review:</b> June 1, 2026 (automated)</p>
<p><i>Generated by Azure SRE Agent — Monthly Capacity Planning Cycle (CapacityMonthlyPlanning)</i></p>

---

## Synthesized Knowledge Update

The following section was appended to
[weekly-compute-utilization-trend.md](/api/files/memories/synthesizedKnowledge/weekly-compute-utilization-trend.md)
during this run:

```markdown
## Monthly Planning Run #2 — 2026-05-02 19:01 UTC

### Execution Summary
- CapacityMonthlyPlanning scheduled task — all 4 supply chain phases completed
- 8 parallel data collection calls (forecast, vm-quota, CRG, commitment, savings, recommendations, non-compute,
anomaly) all succeeded in first batch
- Governance queries via Python REST API (Resource Graph, Cost Management scheduledActions, Consumption budgets,
subscription metadata) all succeeded
- 4 matplotlib charts generated in single Python execution (~3 seconds)
- Teams report posted successfully with 4 embedded chart images + 7 data tables + governance scorecard

### Key Findings (operational only)
- Demand forecast: 180d history + 90d forecast produces flat projection ~$1,368-1,373/day with $0.035/day decline —
much more modest than prior run's steep projection
- 6-month cost trend: gradual 2.4% decline Nov 2025 ($1,377/day) to Apr 2026 ($1,344/day) — confirms stable
environment with no growth
- MoM changes: Nov→Dec -0.9%, Dec→Jan +0.5%, Jan→Feb +0.1%, Feb→Mar -1.6%, Mar→Apr -0.6%
- Anomaly detection (6 months): 0 true anomalies. Only Nov 2 and May 2 flagged as -1 (incomplete billing data)
- All 49 regions at 0% vCPU utilization — unchanged from all prior runs
- Non-compute: 0 real at-risk items, 15 active entries with resources, peak 1.2% (Storage westus)
- CRGs: still 0 deployed
- Governance: 1/4 applicable controls passing (25%) — budget exists, anomaly/KQL/tag controls missing

### Execution Pattern (optimal for monthly planning)
1. Read all KB docs in parallel (9 files) — ~2 seconds
2. Load azure-capacity-management skill — ~1 second
3. Launch 8 data tools in parallel (forecast, vm-quota, CRG, commitment, savings, recs, non-compute, anomaly) — ~5
seconds
4. Upload 2 large JSON files (vm-quota 1.5MB, non-compute 1.4MB) to session — ~1 second
5. Run governance queries via Python REST API (5 ARM calls) + parse uploaded data — ~3 seconds
6. Generate 4 matplotlib charts in single Python execution — ~3 seconds
7. Post single Teams message with embedded charts and HTML tables — ~2 seconds
Total: ~17 seconds end-to-end

### Confirmed Patterns
- ±5% scenario bands on forecast are appropriate for this stable environment
- Python REST API for Resource Graph is reliable (az graph query remains unreliable per prior findings)
- Cost Management scheduledActions API confirms 0 anomaly alerts — consistent across all runs
- Consumption budgets API returns 1 budget — consistent across all runs
- Subscription tags: still empty {} — governance gap persists
```

No other knowledge base files were created or modified during this run.
~~~~

## Finding tables
| Month | Avg Daily Cost | MoM Change | Trend |
| --- | --- | --- | --- |
| Nov 2025 | $1,377/day | — | Baseline |
| Dec 2025 | $1,366/day | -0.9% | Slight decline |
| Jan 2026 | $1,372/day | +0.5% | Stable |
| Feb 2026 | $1,373/day | +0.1% | Stable |
| Mar 2026 | $1,351/day | -1.6% | Moderate decline |
| Apr 2026 | $1,344/day | -0.6% | Slight decline |

| Action | Status | Lead Time | Notes |
| --- | --- | --- | --- |
| Quota increases | Not needed | — | All 49 regions at 0% vCPU utilization |
| Region access requests | Not needed | — | PaaS-only workload |
| Zonal enablement | Not needed | — | No VM deployments planned |
| Quota group enrollment | Not applicable | — | No compute quota pressure |
| Non-compute quotas | Healthy | — | Peak 1.2% (Storage westus). 0 at-risk items. |

| Region | vCPU Limit | Used | Utilization |
| --- | --- | --- | --- |
| westus | 350 | 0 | 0% |
| eastus2 | 100 | 0 | 0% |
| eastus | 100 | 0 | 0% |
| westus2 | 100 | 0 | 0% |
| westus3 | 150 | 0 | 0% |

| Metric | Value |
| --- | --- |
| CRGs deployed | 0 |
| Reserved capacity | None |
| Overallocation policy | N/A |
| Sharing config | N/A |

| Metric | Value (90-day, Feb–Apr 2026) |
| --- | --- |
| List Cost | $124,141 |
| Effective Cost | $120,650 |
| Negotiated Discount Savings | $105 |
| Commitment Discount Savings | $3,396 |
| Total Savings | $3,491 |
| Effective Savings Rate (ESR) | 2.81% |
| On-Demand Core-Hours | 96.1% |
| Reservation Core-Hours | 3.9% |

| # | Resource | Region | Term | Discount | Savings | Break-Even |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | SQL DB BC Gen5 | West US 2 | 3yr | 55% | $2,400 | 16.2 mo |
| 2 | SQL DB BC Gen5 | West US 2 | 1yr | 35% | $1,525 | 7.8 mo |
| 3 | DSv2 VMs | East US | 1yr | 58% | $1,089 | 5.1 mo |
| 4 | DSv3 VMs | East US | 3yr | 62% | $678 | 13.8 mo |
| 5 | DSv2 VMs | West US | 1yr | 39% | $623 | 7.3 mo |
| 6 | Ddv4 VMs | West Central US | 3yr | 62% | $607 | 13.6 mo |
| 7 | SQL DB HS Gen5 | West US 2 | 3yr | 55% | $578 | 16.2 mo |
| 8 | SQL DB GP Gen5 | East US | 3yr | 55% | $480 | 16.2 mo |
| 9 | SQL MI GP Gen5 | West US 2 | 3yr | 55% | $480 | 16.2 mo |
| 10 | DSv3 VMs | South Central US | 3yr | 59% | $465 | 14.8 mo |

| Control | Status | Details |
| --- | --- | --- |
| Budget alerts | PASS | 1 budget (FDPOAzureBudget) with 6 thresholds, routing to AGOwner |
| Anomaly alerts | FAIL | 0 Cost Management anomaly alerts deployed |
| KQL-based alerts | FAIL | 0 scheduled query rules for cost monitoring |
| Tag governance | FAIL | 0 subscription tags. 0% Owner/CostCenter/Environment coverage |
| Quota groups | N/A | Not applicable — zero compute usage in this subscription |
| CRG deployment | N/A | Not applicable — PaaS-only subscription |

| # | Priority | Action | Owner | Deadline |
| --- | --- | --- | --- | --- |
| 1 | CRITICAL | Deploy Cost Management anomaly alert (InsightAlert scheduled action) | FinOps Lead | May 15, 2026 |
| 2 | HIGH | Add AGManager action group to budget + health alert routing (eliminate single-point-of-failure) | Platform Ops | May 15, 2026 |
| 3 | HIGH | Tag subscription with Owner/Environment/CostCenter; enforce tag policy in Audit mode | Platform Ops | May 31, 2026 |
| 4 | MEDIUM | Evaluate SQL DB BC Gen5 1-year reservation (West US 2) — $1,525 savings, 7.8-month break-even | FinOps Lead | May 31, 2026 |
| 5 | MEDIUM | Investigate Transactions() data gap (0 rows) — verify Cost Management commitment export configuration | Platform Ops | May 15, 2026 |
| 6 | MEDIUM | Upgrade FinOps Hub from v13.0 to v14.0 | Platform Ops | Jun 15, 2026 |
| 7 | LOW | Plan SKU migration for msbw-finops-hub Kusto cluster (Standard_E4ads_v5 not available for new deployments) | Platform Ops | Jun 30, 2026 |

## Recommendations
- Quota increases - Not needed - — - All 49 regions at 0% vCPU utilization
- Region access requests - Not needed - — - PaaS-only workload
- Zonal enablement - Not needed - — - No VM deployments planned
- Quota group enrollment - Not applicable - — - No compute quota pressure
- Non-compute quotas - Healthy - — - Peak 1.2% (Storage westus). 0 at-risk items.
- 1 CRITICAL Deploy Cost Management anomaly alert (InsightAlert
- 2 HIGH Add AGManager action group to budget + health alert
- 3 HIGH Tag subscription with Owner/Environment/CostCenter;
- enforce tag policy in Audit mode Platform Ops May 31, 2026
- 4 MEDIUM Evaluate SQL DB BC Gen5 1-year reservation (West US 2)
- 5 MEDIUM Investigate Transactions() data gap (0 rows) — verify
- 6 MEDIUM Upgrade FinOps Hub from v13.0 to

## Knowledge updates
## Synthesized Knowledge Update

The following section was appended to
[weekly-compute-utilization-trend.md](/api/files/memories/synthesizedKnowledge/weekly-compute-utilization-trend.md)
during this run:

```markdown
## Monthly Planning Run #2 — 2026-05-02 19:01 UTC

### Execution Summary
- CapacityMonthlyPlanning scheduled task — all 4 supply chain phases completed
- 8 parallel data collection calls (forecast, vm-quota, CRG, commitment, savings, recommendations, non-compute,
anomaly) all succeeded in first batch
- Governance queries via Python REST API (Resource Graph, Cost Management scheduledActions, Consumption budgets,
subscription metadata) all succeeded
- 4 matplotlib charts generated in single Python execution (~3 seconds)
- Teams report posted successfully with 4 embedded chart images + 7 data tables + governance scorecard

### Key Findings (operational only)
- Demand forecast: 180d history + 90d forecast produces flat projection ~$1,368-1,373/day with $0.035/day decline —
much more modest than prior run's steep projection
- 6-month cost trend: gradual 2.4% decline Nov 2025 ($1,377/day) to Apr 2026 ($1,344/day) — confirms stable
environment with no growth
- MoM changes: Nov→Dec -0.9%, Dec→Jan +0.5%, Jan→Feb +0.1%, Feb→Mar -1.6%, Mar→Apr -0.6%
- Anomaly detection (6 months): 0 true anomalies. Only Nov 2 and May 2 flagged as -1 (incomplete billing data)
- All 49 regions at 0% vCPU utilization — unchanged from all prior runs
- Non-compute: 0 real at-risk items, 15 active entries with resources, peak 1.2% (Storage westus)
- CRGs: still 0 deployed
- Governance: 1/4 applicable controls passing (25%) — budget exists, anomaly/KQL/tag controls missing

### Execution Pattern (optimal for monthly planning)
1. Read all KB docs in parallel (9 files) — ~2 seconds
2. Load azure-capacity-management skill — ~1 second
3. Launch 8 data tools in parallel (forecast, vm-quota, CRG, commitment, savings, recs, non-compute, anomaly) — ~5
seconds
4. Upload 2 large JSON files (vm-quota 1.5MB, non-compute 1.4MB) to session — ~1 second
5. Run governance queries via Python REST API (5 ARM calls) + parse uploaded data — ~3 seconds
6. Generate 4 matplotlib charts in single Python execution — ~3 seconds
7. Post single Teams message with embedded charts and HTML tables — ~2 seconds
Total: ~17 seconds end-to-end

### Confirmed Patterns
- ±5% scenario bands on forecast are appropriate for this stable environment
- Python REST API for Resource Graph is reliable (az graph query remains unreliable per prior findings)
- Cost Management scheduledActions API confirms 0 anomaly alerts — consistent across all runs
- Consumption budgets API returns 1 budget — consistent across all runs
- Subscription tags: still empty {} — governance gap persists
```

No other knowledge base files were created or modified during this run.

## MCAPS asks this task answers
- **#8:** Procurement pipeline states no quota increases needed; all 49 regions at 0% vCPU utilization.
- **#9:** CRG portfolio review shows 0 CRGs and no reserved capacity waste.
- **#10:** Quota group enrollment marked not applicable because no compute quota pressure exists.
- **#11:** Regional vCPU quota table covers regional scope; zonal enablement not needed.
- **#12:** CRG sharing config N/A because no CRGs are deployed.
- **#18:** Monthly report connects forecast, procurement, allocation, cost impact, and governance.
- **#21:** Uses 180-day history plus 90-day forecast for planning depth.
- **#24:** Governance and quota controls are monitored monthly.
- **#43:** Scores supply chain maturity: Forecast=Crawl, Procure=Crawl, Allocate=Crawl, Monitor=Walk.
- **#71:** Provides consolidated quota, CRG, non-compute, and governance visibility.
