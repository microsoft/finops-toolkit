# Azure Cost Management & Optimization Report

<!--
Theme: FinOpsToolkitLight
- Background: #ffffff
- Primary text: #1a2233
- Accent: #0078d4
- Table header: #f3f6fa
- Table border: #e1e4e8
- Section divider: #e1e4e8
- Highlight: #f9fafb
- Icon color: #0078d4
- Link color: #0078d4
- Warning: #ffb900
- Success: #92c353
- Error: #e74856
- Info: #31aaff
-->

<style>
body {
  background: #ffffff;
  color: #1a2233;
}
h1, h2, h3, h4, h5, h6 {
  color: #0078d4;
}
table {
  border: 1px solid #e1e4e8;
  background: #f9fafb;
}
thead {
  background: #f3f6fa;
  color: #1a2233;
}
th, td {
  border: 1px solid #e1e4e8;
  padding: 8px 12px;
}
tr:nth-child(even) {
  background: #f9fafb;
}
a {
  color: #0078d4;
}
blockquote, .note, .warning {
  background: #f3f6fa;
  border-left: 4px solid #0078d4;
  padding: 8px 16px;
  margin: 12px 0;
}
.warning {
  border-left-color: #ffb900;
  color: #b8860b;
}
.success {
  border-left-color: #92c353;
  color: #276749;
}
.error {
  border-left-color: #e74856;
  color: #a4262c;
}
.info {
  border-left-color: #31aaff;
  color: #004e8c;
}
hr {
  border: none;
  border-top: 2px solid #e1e4e8;
  margin: 32px 0;
}
</style>

> **Note:** This template is designed for annual (YTD) Azure cost management reporting. Customize sections as needed for your organization. 
> Use the [guide](./azure-cost-management-report-guide.md) to help you fill in the template.
> Replace all [placeholders] with actual data from Azure Cost Management or FinOps Hub queries.  
> Save as a new files called `azure-cost-management-report-YYYY-MM-DD.md` in the same directory as this template.

--- ✦ ✦ ✦ ---

## 1. Executive Summary 🪐

> 🛸 **Warning:** Azure costs are rising. Immediate action is required to avoid budget overruns and waste.

**Current State:**

- Azure spend is trending upward with several high-risk cost drivers.
- Underutilized resources and missed optimization opportunities detected.

**Key Recommendations:**

- Review top cost drivers and right-size or decommission idle resources.
- Enforce proactive budget controls and alerts.
- Prioritize reserved instance and savings plan utilization.

--- ✦ ✦ ✦ ---

## 2. Total Cost Overview 🌌

| Period         | **Total Effective Cost** | **Total Billed Cost** |
|:--------------:|--------------------------|-----------------------|
|  Year to Date  | **$[YTD_COST]**          | **$[YTD_BILLED]**     |

> 🪐 **Note:** Year-to-date costs are highlighted. Review for anomalies or spikes.
> **Source:** [YTD Total Cost](./catalog/ytd-total-cost.kql)

--- ✦ ✦ ✦ ---

## 3. Cost Trends 🌠

![Cost Trend Chart](https://placehold.co/800x200/1a2233/fff?text=Monthly+Cost+Trend+%28Last+12+Months%29+%F0%9F%9A%80)

> 🌟 **Insight:** Watch for sharp increases or seasonal spikes. Investigate any sudden jumps in cost.
> **Source:** [Monthly Cost Trend](./catalog/monthly-cost-trend.kql)

--- ✦ ✦ ✦ ---

## 4. Top Cost Drivers 🌑

| 🪐 Rank | Service Name      | Cost         | % of Total |
|---------|-------------------|--------------|------------|
| 1       | [Service1]        | $[Cost1]     | [Pct1]%    |
| 2       | [Service2]        | $[Cost2]     | [Pct2]%    |
| 3       | [Service3]        | $[Cost3]     | [Pct3]%    |
| ...     | ...               | ...          | ...        |

> 🛰️ **Action:** Focus on the top 3-5 services—they often account for 80%+ of spend.
> **Source:** [Top N Services by Cost](./catalog/top-n-services-by-cost.kql)

| Region   | Cost          |
|----------|---------------|
| [Region1]| $[RegionCost1]|
| [Region2]| $[RegionCost2]|
| ...      | ...           |

> **Source:** [Cost by Region](./catalog/cost-by-region.kql)

--- ✦ ✦ ✦ ---

## 5. Usage Analysis

| Resource Type | Count | Utilization | Cost Impact |
|--------------|--------|-------------|-------------|
| VM           | [#]    | [Low/High]  | $[Cost]     |
| Storage      | [#]    | [Low/High]  | $[Cost]     |
| Database     | [#]    | [Low/High]  | $[Cost]     |
| ...          | ...    | ...         | ...         |

> **Warning:** Underutilized resources detected. Review and right-size or decommission.
> **Source:** [Top N Resource Types by Cost](./catalog/top-n-resource-types-by-cost.kql)

---

## 6. Anomalies (Cost Anomaly Detection)

> **Best Practice:** Proactively detect and respond to cost anomalies to prevent budget overruns and uncover hidden issues.

- Use Azure Cost Management’s built-in anomaly detection to monitor for unexpected spikes in spend.
- Set up budgets and alerts to notify stakeholders when costs exceed thresholds.
- Integrate with Log Analytics for unified visibility and advanced anomaly detection using KQL queries.
- Assign anomaly investigation and response ownership to specific teams or roles.
- Document and track anomalies, including root cause and remediation steps.
- Use Azure Policy to prevent misconfigurations that can lead to cost anomalies (e.g., unauthorized resource types, missing tags).

| Date       | Anomaly Type      | Impact      | Status     | Owner      | Notes                |
|------------|-------------------|-------------|------------|------------|----------------------|
| [Date]     | [Spike/Drop/etc.] | $[Amount]   | [Open/Closed]| [Name]   | [Root cause/Action]  |
| ...        | ...               | ...         | ...        | ...        | ...                  |

> **Source:** [Cost Anomaly Detection](./catalog/cost-anomaly-detection.kql)

## 7. Cost Optimization Opportunities

> **Critical:** The following actions can yield immediate savings and long-term efficiency:

- **Rightsize resources:** Match compute/storage/database capacity to actual workload. Use Azure Advisor and monitoring tools to detect overprovisioned or underutilized resources.
- **Disable idle resources:** Stop or delete VMs, disks, databases, and other resources that are not in use. Review regularly.
- **Use autoscaling:** Enable autoscale for services that support it to automatically adjust capacity to demand.
- **Adopt discounted pricing:** Use Reservations and Savings Plans for predictable workloads. Review Azure Advisor for recommendations.
- **Implement cost allocation:** Use tags and resource groups to track costs by department, project, or environment. Require tags with Azure Policy.
- **Investigate cost anomalies:** Set up alerts for unusual spend. Use Azure Cost Management and Advisor for anomaly detection.
- **Enforce governance:** Use Azure Policy to restrict resource types, enforce tagging, and prevent misconfiguration.

## 8. Recommendations & Next Steps

| Priority | Recommendation                                  | Owner      | Due Date |
|----------|-------------------------------------------------|------------|----------|
| High     | Review top cost drivers and right-size VMs      | [Name]     | [Date]   |
| High     | Set up budget alerts and cost anomaly detection | [Name]     | [Date]   |
| High     | Require tags on all resources (Azure Policy)    | [Name]     | [Date]   |
| High     | Review Azure Advisor recommendations monthly    | [Name]     | [Date]   |
| Medium   | Review reserved instance utilization            | [Name]     | [Date]   |
| Medium   | Implement regular cost reviews                  | [Name]     | [Date]   |
| Medium   | Enable autoscale for scalable services          | [Name]     | [Date]   |
| Medium   | Review and disable idle resources quarterly     | [Name]     | [Date]   |

## 9. Governance & Tagging

> **Best Practice:** Require tags on all resources for cost allocation and accountability. Use Azure Policy to enforce tagging and restrict resource types.

- Tag resources by department, project, environment, and owner.
- Use resource groups to organize and aggregate costs.
- Limit who can provision resources to reduce risk of sprawl.

## 10. Advisor Recommendations

> **Tip:** Use Azure Advisor for automated, actionable recommendations on cost, security, reliability, and performance.

- Review Advisor at least monthly.
- Track which recommendations are implemented and their impact.

## 11. Continuous Monitoring & Review

> **Best Practice:** Cost optimization is a continuous process. Set up regular reviews and monitoring.

- Schedule monthly/quarterly cost reviews with stakeholders.
- Set up alerts for budget overruns and cost anomalies.
- Empower teams with cost visibility and accountability.

---

## 12. Committed Usage and Spend

| Metric/Section                      | Description                                                                 | Source/Instructions                                                                                       |
|-------------------------------------|-----------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| Committed Usage                     | Reservations                                                               | -                                                                                                        |
| Committed Spend                     | Savings Plans                                                              | -                                                                                                        |
| Commitment Savings                  | Track how much you're saving through commitments (Reservations and Savings Plans) | Table: List Cost, Contracted Cost, Effective Cost, Underutilized (Waste), Effective Savings (by type)    |
| Commitment Coverage                 | Track how much of your usage is covered by RIs or Savings Plans vs On-Demand| [Commitment Discount Utilization](./catalog/commitment-discount-utilization.kql)                         |
| Underutilized Commitments           | Identify RIs that are underutilized or unused (wasted spend)                | Table: Region, Resource Type, Term, Utilization (%), Unused Cost ($), Qty, Scope                         |
| Commitment Savings Opportunities    | Review top RI purchase recommendations to maximize savings                  | [Reservation Recommendation Breakdown](./catalog/all-available-recommendation-columns.kql)               |

---

### 12a. Commitment Savings

> **Insight:** Track how much you're saving through commitments (Reservations and Savings Plans)

| Commitment Type | List Cost | Contracted Cost | Effective Cost | Underutilized (Waste) | Effective Savings |
|-----------------|-----------|-----------------|----------------|-----------------------|-------------------|
| Reservations    | [#]       | [#]             | [#]            | [#]                   | [#]               |
| Savigns Plans   | [#]       | [#]             | [#]            | [#]                   | [#]               |

---

### 12b. Commitment Coverage

> **Insight:** Track how much of your usage is covered by Reserved Instances or Savings Plans versus On-Demand. Use this to identify savings opportunities and underutilized commitments.

| Commitment Type | Consumed Core Hours | % of Total |
|-----------------|--------------------|-------------|
| [RI]            | [#]                | [Pct]%      |
| [SP]            | [#]                | [Pct]%      |
| On Demand       | [#]                | [Pct]%      |

> **Source:** [Commitment Coverage](./catalog/commitment-discount-utilization.kql)

---

### 12c. Underutilized Commitments

> **Risk:** Identify Reserved Instances (RIs) that are underutilized or unused. These represent wasted spend and should be reviewed for possible reallocation, exchange, or cancellation.

| Region      | Resource Type      | Term     | Utilization (%) | Unused Cost ($) | Qty | Scope   |
|-------------|-------------------|----------|-----------------|-----------------|-----|---------|
| [Region]    | [Type]            | [Term]   | [UtilPct]%      | $[UnusedCost]   | [Qty]| [Scope] |
| ...         | ...               | ...      | ...             | ...             | ... | ...     |

> **How to use:**
>
> - Fill in this table using the output from the underutilized RI query in the FinOps Hub Query Catalog (or create one if missing).
> - Focus on RIs with the lowest utilization and highest unused cost.
> - Review with resource owners to determine if RIs can be reallocated, exchanged, or cancelled.

---

### 12d. Commitment Savings Opportunities

> **Opportunity:** Review the top Reserved Instance (RI) purchase recommendations to maximize savings and reduce pay-as-you-go costs. Use this to justify new RI purchases and track break-even points.

| Region      | Resource Type      | Term     | Savings ($) | Savings % | Break-even (months) | Break-even Date | Recommended Qty | Scope   |
|-------------|-------------------|----------|-------------|-----------|---------------------|-----------------|-----------------|---------|
| [Region]    | [Type]            | [Term]   | $[Savings]  | [Pct]%    | [Months]            | [Date]          | [Qty]           | [Scope] |
| ...         | ...               | ...      | ...         | ...       | ...                 | ...             | ...             | ...     |

> **How to use:**
>
> - Fill in this table using the output from the [Reservation Recommendation Breakdown](./catalog/all-available-recommendation-columns.kql) query in the FinOps Hub Query Catalog.
> - Prioritize recommendations with the highest savings and shortest break-even periods.
> - Review regularly to ensure optimal RI coverage and utilization.
> **Source:** [Reservation Recommendation Breakdown](./catalog/all-available-recommendation-columns.kql)

---

## 13. Optimization Recommendations

> **Actionable:** Review the top cost-saving recommendations from the FinOps Hub database. Prioritize those with the highest estimated savings.

| Recommendation           | Estimated Savings | Details               |
|-------------------------|-------------------|------------------------|
| [Right-size VMs]        | $[Amount]         | [Details]              |
| [Purchase RIs]          | $[Amount]         | [Details]              |
| [Delete idle disks]     | $[Amount]         | [Details]              |
| ...                     | ...               | ...                    |

---

## 14. Price Benchmarking

> **Compare:** List price, contracted price, and effective price for your top services. Use this to validate negotiated discounts and spot anomalies.

| Service Name      | List Price | Contracted Price | Effective Price |
|-------------------|-----------|------------------|------------------|
| [Service1]        | $[List]   | $[Contracted]    | $[Effective]     |
| [Service2]        | $[List]   | $[Contracted]    | $[Effective]     |
| ...               | ...       | ...              | ...              |

> **Source:** [Price Benchmarking](./catalog/price-benchmarking.kql)

---

## 15. Transaction Summary

> **Audit:** Track major purchases, refunds, and adjustments for Reserved Instances and Savings Plans.

| Date       | Transaction Type | Amount   | Description         |
|------------|------------------|----------|---------------------|
| [Date]     | [Purchase/Refund]| $[Amt]   | [Details]           |
| ...        | ...              | ...      | ...                 |

---

## 16. Data Quality & Ingestion

> **Monitor:** Report on data ingestion errors and missing data. Ensure your analytics are based on complete, accurate data.

| Error Type         | Count | Last Occurrence | Details        |
|--------------------|-------|-----------------|----------------|
| [Missing file]     | [#]   | [Date]          | [Details]      |
| [Parse error]      | [#]   | [Date]          | [Details]      |
| ...                | ...   | ...             | ...            |

---

## 17. User & Team Accountability

> **Transparency:** Highlight top spenders or resource owners to drive accountability and cost awareness across teams.

| Owner/Team         | Total Cost   | % of Total | Top Services        |
|--------------------|-------------|------------|----------------------|
| [Team/Owner1]      | $[Cost1]    | [Pct1]%    | [Service1, Service2] |
| [Team/Owner2]      | $[Cost2]    | [Pct2]%    | [Service3, Service4] |
| ...                | ...         | ...        | ...                  |

---

## 18. Resource Inventory

> **Inventory:** List and count key resource types (VMs, DBs, IPs, etc.) by region or group for asset management and security.

| Resource Type      | Count | Region/Group   |
|--------------------|-------|----------------|
| [VM]               | [#]   | [Region/Group] |
| [SQL DB]           | [#]   | [Region/Group] |
| [Public IP]        | [#]   | [Region/Group] |
| ...                | ...   | ...            |

---

## 19. Forecast & Planning

> **Forecast:** Projected year-end spend and potential budget overruns. Use Azure Cost Management’s forecasting features or your own KQL/Power BI models.

| Scenario           | Projected Spend | Variance vs. Budget |
|--------------------|-----------------|---------------------|
| Current Trend      | $[Forecast]     | $[Variance]         |
| With Optimizations | $[Optimized]    | $[Variance]         |
| ...                | ...             | ...                 |

> **Source:** [Cost Forecasting](./catalog/cost-forecasting.kql)

---

## 20. Financial Hierarchy Reporting

> **Insight:** Report and allocate costs using your organization's financial hierarchy: **Billing Profile → Invoice Section → Team → Product → Application**. The last three levels are typically derived from resource tags (`team`, `product`, `application`).

| Billing Profile     | Invoice Section    | Team (tag)     | Product (tag)   | Application (tag) | Total Cost   | % of Total | Top Services         |
|---------------------|--------------------|----------------|-----------------|-------------------|--------------|------------|----------------------|
| [Profile1]          | [Section1]         | [Team1]        | [Product1]      | [App1]            | $[Cost1]     | [Pct1]%    | [Service1, Service2] |
| [Profile1]          | [Section2]         | [Team2]        | [Product2]      | [App2]            | $[Cost2]     | [Pct2]%    | [Service3, Service4] |
| ...                 | ...                | ...            | ...             | ...               | ...          | ...        | ...                  |

> **Tip:** Use the following fields from the FinOps Hub database for this hierarchy:
>
> - **Billing Profile:** `x_BillingProfileName` or `x_BillingProfileId`
> - **Invoice Section:** `x_InvoiceSectionName` or `x_InvoiceSectionId`
> - **Team:** `Tags['team']`
> - **Product:** `Tags['product']`
> - **Application:** `Tags['application']`

> **Source:** [Charge by Financial Hierarchy with Tags](./catalog/top-ncost-by-billing-profile-invoice-section-team-product-application-environment.kql)

> **Action:** Ensure all resources are consistently tagged for accurate reporting. Work with resource owners to remediate missing or inconsistent tags.

---

## 21. Visualizations

<details>
<summary>📊 Click to expand sample visuals</summary>

![Cost Breakdown Pie](https://placehold.co/400x200/0078d4/fff?text=Cost+Breakdown+by+Service)

![Top Regions Bar](https://placehold.co/400x200/00b4ff/fff?text=Top+Regions+by+Cost)

</details>

---

> **Data Quality Note:** Accurate reporting depends on complete, timely, and correct data ingestion. Review the Data Quality & Ingestion section for any issues before presenting results.

<sub>Report generated on [DATE]. Replace all [placeholders] with actual data from Azure Cost Management or FinOps Hub queries.</sub>
