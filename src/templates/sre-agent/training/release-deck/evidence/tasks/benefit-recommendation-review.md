# Benefit Recommendation Review

## Identity
- **YAML:** sre-config/scheduled-tasks/benefit-recommendation-review.yaml
- **Cron:** 0 8 * * 5 — weekly on Friday at 08:00 UTC
- **Owning subagent:** chief-financial-officer
- **FinOps Framework capability:** Rate Optimization (RI/SP)
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, benefit-recommendations

## Latest run summary
The **Weekly Benefit Recommendation Review** scheduled task has completed successfully. Here's a summary: **What was done:** Retrieved 20 reservation recommendations from FinOps Hub and 1 compute savings plan recommendation from the CostManagement API Current ESR is **2.8%** with **96.5%** of core-hours running on-demand Identified **$12,739/month** in reservation savings (SQL DB + VMs across 6 regions) and **$41,454/month** in

## Final Teams card / Outlook output (verbatim)
~~~~text
Here is the exact Teams message posted during this run, followed by the knowledge base update.

---

## Teams Message (posted as message ID `1777748301375`)

<h2>Executive Summary</h2>
<p>The weekly benefit recommendation review identifies <b>$12,739/month in reservation savings</b> across 20
recommendations and a <b>$41,454/month compute savings plan opportunity</b> (3-year term). Current Effective
Savings Rate (ESR) is <b>2.8%</b> with 96.5% of core-hours running on-demand — signaling significant
under-commitment of compute workloads.</p>

<h3>Key Metrics</h3>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1a5276;color:white;"><th>Metric</th><th>Value</th></tr>
<tr><td>List Cost (Apr 2026)</td><td>$41,473</td></tr>
<tr><td>Effective Cost</td><td>$40,312</td></tr>
<tr><td>Total Savings</td><td>$1,161</td></tr>
<tr><td>Effective Savings Rate</td><td>2.8%</td></tr>
<tr><td>Negotiated Discount Savings</td><td>$34</td></tr>
<tr><td>Commitment Discount Savings</td><td>$1,127</td></tr>
<tr><td>On-Demand Core-Hours</td><td>96.5%</td></tr>
<tr><td>Reserved Core-Hours</td><td>3.5%</td></tr>
</table>

<hr/>

<h2>Reservation Recommendations (20 total)</h2>

<h3>SQL Database Reservations</h3>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1a5276;color:white;"><th>Resource Type</th><th>Region</th><th>Term</th><th>Qty</th><th>Cost
Before</th><th>Cost After</th><th>Savings</th><th>Discount %</th><th>Break-Even</th></tr>
<tr><td>SQL DB BC Gen5</td><td>West US
2</td><td>3yr</td><td>10</td><td>$4,365</td><td>$1,965</td><td>$2,400</td><td>55.0%</td><td>16 mo</td></tr>
<tr><td>SQL DB BC Gen5</td><td>West US
2</td><td>1yr</td><td>10</td><td>$4,365</td><td>$2,841</td><td>$1,525</td><td>34.9%</td><td>8 mo</td></tr>
<tr><td>SQL DB HS Gen5</td><td>West US
2</td><td>3yr</td><td>4</td><td>$1,049</td><td>$472</td><td>$578</td><td>55.0%</td><td>16 mo</td></tr>
<tr><td>SQL MI GP Gen5</td><td>West US
2</td><td>3yr</td><td>4</td><td>$873</td><td>$393</td><td>$480</td><td>55.0%</td><td>16 mo</td></tr>
<tr><td>SQL DB GP Gen5</td><td>East
US</td><td>3yr</td><td>4</td><td>$873</td><td>$393</td><td>$480</td><td>55.0%</td><td>16 mo</td></tr>
<tr><td>SQL DB HS Gen5</td><td>West US
2</td><td>1yr</td><td>4</td><td>$1,049</td><td>$682</td><td>$367</td><td>35.0%</td><td>8 mo</td></tr>
<tr><td>SQL MI GP Gen5</td><td>West US
2</td><td>1yr</td><td>4</td><td>$873</td><td>$569</td><td>$305</td><td>34.9%</td><td>8 mo</td></tr>
<tr><td>SQL DB GP Gen5</td><td>East
US</td><td>1yr</td><td>4</td><td>$873</td><td>$569</td><td>$305</td><td>34.9%</td><td>8 mo</td></tr>
<tr style="background:#eaf2f8;font-weight:bold;"><td colspan="6">SQL Total</td><td>$6,439</td><td
colspan="2"></td></tr>
</table>

<h3>Virtual Machine Reservations</h3>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#2e86c1;color:white;"><th>VM Family</th><th>Region</th><th>Term</th><th>Qty</th><th>Cost
Before</th><th>Cost After</th><th>Savings</th><th>Discount %</th><th>Break-Even</th></tr>
<tr><td>DSv2</td><td>East
US</td><td>1yr</td><td>9</td><td>$1,887</td><td>$798</td><td>$1,089</td><td>57.7%</td><td>5 mo</td></tr>
<tr><td>DSv3</td><td>East
US</td><td>3yr</td><td>8</td><td>$1,101</td><td>$423</td><td>$678</td><td>61.6%</td><td>14 mo</td></tr>
<tr><td>DSv2</td><td>West US</td><td>1yr</td><td>2</td><td>$1,605</td><td>$982</td><td>$623</td><td>38.8%</td><td>7
mo</td></tr>
<tr><td>Ddv4</td><td>West Central
US</td><td>3yr</td><td>5</td><td>$976</td><td>$370</td><td>$607</td><td>62.1%</td><td>14 mo</td></tr>
<tr><td>DSv3</td><td>South Central
US</td><td>3yr</td><td>5</td><td>$788</td><td>$323</td><td>$465</td><td>59.0%</td><td>15 mo</td></tr>
<tr><td>DSv3</td><td>East US</td><td>1yr</td><td>8</td><td>$1,101</td><td>$657</td><td>$444</td><td>40.3%</td><td>7
mo</td></tr>
<tr><td>Dv2 High Memory</td><td>West Central
US</td><td>1yr</td><td>5</td><td>$1,192</td><td>$759</td><td>$433</td><td>36.3%</td><td>8 mo</td></tr>
<tr><td>Dv2 High Memory</td><td>West
US</td><td>1yr</td><td>4</td><td>$1,098</td><td>$691</td><td>$406</td><td>37.0%</td><td>8 mo</td></tr>
<tr><td>Ddv4</td><td>West Central
US</td><td>1yr</td><td>5</td><td>$976</td><td>$575</td><td>$402</td><td>41.2%</td><td>7 mo</td></tr>
<tr><td>Dav4</td><td>West US</td><td>3yr</td><td>4</td><td>$665</td><td>$263</td><td>$402</td><td>60.4%</td><td>14
mo</td></tr>
<tr><td>DSv3</td><td>Canada
Central</td><td>3yr</td><td>1</td><td>$638</td><td>$237</td><td>$400</td><td>62.8%</td><td>13 mo</td></tr>
<tr><td>DSv2 High Memory</td><td>West US
2</td><td>1yr</td><td>2</td><td>$859</td><td>$507</td><td>$352</td><td>41.0%</td><td>7 mo</td></tr>
<tr style="background:#d6eaf8;font-weight:bold;"><td colspan="6">VM Total</td><td>$6,300</td><td
colspan="2"></td></tr>
</table>

<hr/>

<h2>Savings Plan Recommendation</h2>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#117864;color:white;"><th>Attribute</th><th>Value</th></tr>
<tr><td>Type</td><td>Compute Savings Plan</td></tr>
<tr><td>Term</td><td>3-Year</td></tr>
<tr><td>Scope</td><td>Shared</td></tr>
<tr><td>Lookback Period</td><td>60 days</td></tr>
<tr><td>Hourly Commitment</td><td>$1,427.30/hr</td></tr>
<tr><td>Benefit Cost (3yr)</td><td>$2,025,334</td></tr>
<tr><td>Overage Cost</td><td>$239,652</td></tr>
<tr><td>Total Cost (3yr)</td><td>$2,264,987</td></tr>
<tr><td>Projected Savings (3yr)</td><td>$1,492,331</td></tr>
<tr><td>Savings Percentage</td><td>39.7%</td></tr>
<tr><td>Utilization</td><td>99.3%</td></tr>
<tr><td>Coverage</td><td>93.6%</td></tr>
<tr><td>Wastage Cost (3yr)</td><td>$13,294</td></tr>
</table>

<hr/>

<h2>Total Potential Savings Summary</h2>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1a5276;color:white;"><th>Category</th><th>Monthly Savings</th><th>Notes</th></tr>
<tr><td>SQL DB Reservations</td><td>$6,439</td><td>8 recommendations across BC, HS, GP tiers</td></tr>
<tr><td>VM Reservations</td><td>$6,300</td><td>12 recommendations across 6 regions</td></tr>
<tr><td>Compute Savings Plan</td><td>$41,454</td><td>3yr plan, $1,427/hr commitment, 39.7% discount</td></tr>
<tr style="background:#eaf2f8;font-weight:bold;"><td>Combined RI + SP Potential</td><td>$54,193</td><td>Overlapping
coverage — actual will be lower</td></tr>
</table>
<p><b>Important:</b> RI and SP recommendations overlap on VM compute. Purchasing both at full quantity would result
in over-commitment. Choose RI for predictable, persistent workloads and SP for flexible/variable compute.</p>

<hr/>

<h2>Visualization</h2>
<img
src="https://sre.azure.com/api/files/tmp/ThreadFiles/fa3210e7-8c23-4a26-a336-633ac2a61692/benefit-recommendation-charts.png"
alt="Benefit Recommendation Charts" style="max-width:100%;"/>

<hr/>

<h2>Key Risks</h2>
<ol>
<li><b>Over-commitment risk:</b> SP coverage at 93.6% plus full RI purchase could exceed actual demand. Start with
RI for stable SQL workloads, then layer SP for remaining compute.</li>
<li><b>3-year term lock-in:</b> 11 of 20 RI recommendations are 3-year terms (55-62% discount but 13-16 month
break-even). Requires workload persistence confirmation.</li>
<li><b>Transactions() data gap:</b> Hub Transactions() returns 0 rows — cannot validate existing commitments
against new recommendations. Risk of duplicate purchases.</li>
<li><b>No owner accountability:</b> 0% Owner tag coverage. Recommendations cannot be routed to workload owners for
validation.</li>
<li><b>SQL migration risk:</b> SQL DB recommendations assume current tier persistence. Elastic Pool, Serverless, or
PaaS migration plans could invalidate reservations.</li>
<li><b>Low ESR baseline:</b> Current ESR at 2.8% confirms massive under-commitment but also means any purchase will
be a significant first-time commitment.</li>
</ol>

<h2>Recommended Executive Decisions</h2>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#1a5276;color:white;"><th>Priority</th><th>Action</th><th>Expected
Impact</th><th>Prerequisites</th></tr>
<tr><td>P1 — Approve</td><td>SQL DB BC Gen5 (West US 2) 1-year RI</td><td>$1,525/mo savings, 8-month
break-even</td><td>Confirm SQL DB BC workload persists &gt;12 months</td></tr>
<tr><td>P1 — Approve</td><td>DSv2 VMs (East US) 1-year RI</td><td>$1,089/mo savings, 5-month
break-even</td><td>Confirm VM fleet stability in East US</td></tr>
<tr><td>P2 — Validate</td><td>All remaining 1-year RI recommendations (7 recs)</td><td>$3,234/mo
combined</td><td>Workload owner sign-off, migration plan review</td></tr>
<tr><td>P3 — Defer</td><td>3-year RI recommendations (11 recs)</td><td>$6,891/mo combined</td><td>Establish tag
governance, validate 36-month persistence</td></tr>
<tr><td>P4 — Investigate</td><td>Compute Savings Plan ($1,427/hr, 3yr)</td><td>$41,454/mo (39.7%
discount)</td><td>Resolve Transactions() data gap, analyze SP vs RI overlap, pilot with smaller
commitment</td></tr>
</table>

<p><b>Next review:</b> May 9, 2026 (weekly automated cycle)</p>
<p><i>Report generated by Azure SRE Agent — CFO Scheduled Task (BenefitRecommendationReview)</i></p>

---

## Insights Saved to Synthesized Knowledge

One file was updated during this run:
[benefit-recommendation-review-findings.md](/api/files/memories/synthesizedKnowledge/benefit-recommendation-review-findings.md).
The specific change was appending a **Run History** table to the existing `### Data Sources & Reliability` section.
Here is the exact block that was added:

```
### Run History
| Date | RI Recs | SP Recs | ESR | On-Demand % | Hub Recs Rows | Notes |
|------|---------|---------|-----|-------------|---------------|-------|
| 2026-05-02 18:55 | 20 | 1 | 2.8% | 96.5% | 45 | Stable — same rec profile as prior run. Streamlined execution. |
| 2026-05-02 18:29 | 20 | 1 | 2.8% | 96.5% | 45 | First run with full chart pipeline. |
```

The `## Last Execution` timestamp was also updated from `2026-05-02 18:29 UTC` to `2026-05-02 18:55 UTC`.

No financial figures, savings amounts, or cost data were persisted to the knowledge base — all financial detail was
posted exclusively to the Teams channel as required.
~~~~

## Finding tables
| Date | RI Recs | SP Recs | ESR | On-Demand % | Hub Recs Rows | Notes |
|------|---------|---------|-----|-------------|---------------|-------|
| 2026-05-02 18:55 | 20 | 1 | 2.8% | 96.5% | 45 | Stable — same rec profile as prior run. Streamlined execution. |
| 2026-05-02 18:29 | 20 | 1 | 2.8% | 96.5% | 45 | First run with full chart pipeline. |

| Metric | Value |
| --- | --- |
| List Cost (Apr 2026) | $41,473 |
| Effective Cost | $40,312 |
| Total Savings | $1,161 |
| Effective Savings Rate | 2.8% |
| Negotiated Discount Savings | $34 |
| Commitment Discount Savings | $1,127 |
| On-Demand Core-Hours | 96.5% |
| Reserved Core-Hours | 3.5% |

| Resource Type | Region | Term | Qty | Cost Before | Cost After | Savings | Discount % | Break-Even |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SQL DB BC Gen5 | West US 2 | 3yr | 10 | $4,365 | $1,965 | $2,400 | 55.0% | 16 mo |
| SQL DB BC Gen5 | West US 2 | 1yr | 10 | $4,365 | $2,841 | $1,525 | 34.9% | 8 mo |
| SQL DB HS Gen5 | West US 2 | 3yr | 4 | $1,049 | $472 | $578 | 55.0% | 16 mo |
| SQL MI GP Gen5 | West US 2 | 3yr | 4 | $873 | $393 | $480 | 55.0% | 16 mo |
| SQL DB GP Gen5 | East US | 3yr | 4 | $873 | $393 | $480 | 55.0% | 16 mo |
| SQL DB HS Gen5 | West US 2 | 1yr | 4 | $1,049 | $682 | $367 | 35.0% | 8 mo |
| SQL MI GP Gen5 | West US 2 | 1yr | 4 | $873 | $569 | $305 | 34.9% | 8 mo |
| SQL DB GP Gen5 | East US | 1yr | 4 | $873 | $569 | $305 | 34.9% | 8 mo |
| SQL Total | $6,439 |  |  |  |  |  |  |  |

| VM Family | Region | Term | Qty | Cost Before | Cost After | Savings | Discount % | Break-Even |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DSv2 | East US | 1yr | 9 | $1,887 | $798 | $1,089 | 57.7% | 5 mo |
| DSv3 | East US | 3yr | 8 | $1,101 | $423 | $678 | 61.6% | 14 mo |
| DSv2 | West US | 1yr | 2 | $1,605 | $982 | $623 | 38.8% | 7 mo |
| Ddv4 | West Central US | 3yr | 5 | $976 | $370 | $607 | 62.1% | 14 mo |
| DSv3 | South Central US | 3yr | 5 | $788 | $323 | $465 | 59.0% | 15 mo |
| DSv3 | East US | 1yr | 8 | $1,101 | $657 | $444 | 40.3% | 7 mo |
| Dv2 High Memory | West Central US | 1yr | 5 | $1,192 | $759 | $433 | 36.3% | 8 mo |
| Dv2 High Memory | West US | 1yr | 4 | $1,098 | $691 | $406 | 37.0% | 8 mo |
| Ddv4 | West Central US | 1yr | 5 | $976 | $575 | $402 | 41.2% | 7 mo |
| Dav4 | West US | 3yr | 4 | $665 | $263 | $402 | 60.4% | 14 mo |
| DSv3 | Canada Central | 3yr | 1 | $638 | $237 | $400 | 62.8% | 13 mo |
| DSv2 High Memory | West US 2 | 1yr | 2 | $859 | $507 | $352 | 41.0% | 7 mo |
| VM Total | $6,300 |  |  |  |  |  |  |  |

| Attribute | Value |
| --- | --- |
| Type | Compute Savings Plan |
| Term | 3-Year |
| Scope | Shared |
| Lookback Period | 60 days |
| Hourly Commitment | $1,427.30/hr |
| Benefit Cost (3yr) | $2,025,334 |
| Overage Cost | $239,652 |
| Total Cost (3yr) | $2,264,987 |
| Projected Savings (3yr) | $1,492,331 |
| Savings Percentage | 39.7% |
| Utilization | 99.3% |
| Coverage | 93.6% |
| Wastage Cost (3yr) | $13,294 |

| Category | Monthly Savings | Notes |
| --- | --- | --- |
| SQL DB Reservations | $6,439 | 8 recommendations across BC, HS, GP tiers |
| VM Reservations | $6,300 | 12 recommendations across 6 regions |
| Compute Savings Plan | $41,454 | 3yr plan, $1,427/hr commitment, 39.7% discount |
| Combined RI + SP Potential | $54,193 | Overlapping coverage — actual will be lower |

| Priority | Action | Expected Impact | Prerequisites |
| --- | --- | --- | --- |
| P1 — Approve | SQL DB BC Gen5 (West US 2) 1-year RI | $1,525/mo savings, 8-month break-even | Confirm SQL DB BC workload persists >12 months |
| P1 — Approve | DSv2 VMs (East US) 1-year RI | $1,089/mo savings, 5-month break-even | Confirm VM fleet stability in East US |
| P2 — Validate | All remaining 1-year RI recommendations (7 recs) | $3,234/mo combined | Workload owner sign-off, migration plan review |
| P3 — Defer | 3-year RI recommendations (11 recs) | $6,891/mo combined | Establish tag governance, validate 36-month persistence |
| P4 — Investigate | Compute Savings Plan ($1,427/hr, 3yr) | $41,454/mo (39.7% discount) | Resolve Transactions() data gap, analyze SP vs RI overlap, pilot with smaller commitment |

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
## Insights Saved to Synthesized Knowledge

One file was updated during this run:
[benefit-recommendation-review-findings.md](/api/files/memories/synthesizedKnowledge/benefit-recommendation-review-findings.md).
The specific change was appending a **Run History** table to the existing `### Data Sources & Reliability` section.
Here is the exact block that was added:

```
### Run History
| Date | RI Recs | SP Recs | ESR | On-Demand % | Hub Recs Rows | Notes |
|------|---------|---------|-----|-------------|---------------|-------|
| 2026-05-02 18:55 | 20 | 1 | 2.8% | 96.5% | 45 | Stable — same rec profile as prior run. Streamlined execution. |
| 2026-05-02 18:29 | 20 | 1 | 2.8% | 96.5% | 45 | First run with full chart pipeline. |
```

The `## Last Execution` timestamp was also updated from `2026-05-02 18:29 UTC` to `2026-05-02 18:55 UTC`.

No financial figures, savings amounts, or cost data were persisted to the knowledge base — all financial detail was
posted exclusively to the Teams channel as required.

## MCAPS asks this task answers
- **#17:** Compares reservation and compute savings plan opportunities and current ESR.
- **#18:** Sequences commitment actions through candidate recommendations and break-even data.
- **#19:** Shows current 96.5% on-demand exposure; CRG pairing risk is called out by adjacent capacity tasks.
- **#32:** Gives finance-ready list/effective cost, savings, and ESR metrics.
- **#62:** Quantifies RI/SP math: $12,739/month reservation and $41,454/month savings-plan opportunity.
- **#66:** Uses hub and commitment data to support finance trust in rate-optimization recommendations.
