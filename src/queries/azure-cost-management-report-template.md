# Azure Cost Management & Optimization Report

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

--- ✦ ✦ ✦ ---

## 3. Cost Trends 🌠

![Cost Trend Chart](https://placehold.co/800x200/1a2233/fff?text=Monthly+Cost+Trend+%28Last+12+Months%29+%F0%9F%9A%80)

> 🌟 **Insight:** Watch for sharp increases or seasonal spikes. Investigate any sudden jumps in cost.

--- ✦ ✦ ✦ ---

## 4. Top Cost Drivers 🌑

| 🪐 Rank | Service Name      | Cost         | % of Total |
|---------|-------------------|--------------|------------|
| 1       | [Service1]        | $[Cost1]     | [Pct1]%    |
| 2       | [Service2]        | $[Cost2]     | [Pct2]%    |
| 3       | [Service3]        | $[Cost3]     | [Pct3]%    |
| ...     | ...               | ...          | ...        |

> 🛰️ **Action:** Focus on the top 3-5 services—they often account for 80%+ of spend.


| Region   | Cost          |
|----------|---------------|
| [Region1]| $[RegionCost1]|
| [Region2]| $[RegionCost2]|
| ...      | ...           |

--- ✦ ✦ ✦ ---

## 5. Usage Analysis

| Resource Type | Count | Utilization | Cost Impact |
|--------------|--------|-------------|-------------|
| VM           | [#]    | [Low/High]  | $[Cost]     |
| Storage      | [#]    | [Low/High]  | $[Cost]     |
| Database     | [#]    | [Low/High]  | $[Cost]     |
| ...          | ...    | ...         | ...         |

> **Warning:** Underutilized resources detected. Review and right-size or decommission.


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

## 12. Commitment Discount Utilization

> **Insight:** Track how much of your usage is covered by Reserved Instances or Savings Plans versus On-Demand. Use this to identify savings opportunities and underutilized commitments.

| Commitment Type | Consumed Core Hours | % of Total |
|-----------------|--------------------|-------------|
| [RI]            | [#]                | [Pct]%      |
| [SP]            | [#]                | [Pct]%      |
| On Demand       | [#]                | [Pct]%      |

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

---


## 20. Financial Hierarchy Reporting

> **Insight:** Report and allocate costs using your organization's financial hierarchy: **Billing Profile → Invoice Section → Team → Product → Application**. The last three levels are typically derived from resource tags (`team`, `product`, `application`).

| Billing Profile     | Invoice Section    | Team (tag)     | Product (tag)   | Application (tag) | Total Cost   | % of Total | Top Services         |
|---------------------|--------------------|----------------|-----------------|-------------------|--------------|------------|----------------------|
| [Profile1]          | [Section1]         | [Team1]        | [Product1]      | [App1]            | $[Cost1]     | [Pct1]%    | [Service1, Service2] |
| [Profile1]          | [Section2]         | [Team2]        | [Product2]      | [App2]            | $[Cost2]     | [Pct2]%    | [Service3, Service4] |
| ...                 | ...                | ...            | ...             | ...               | ...          | ...        | ...                  |

> **Tip:** Use the following fields from the FinOps Hub database for this hierarchy:
> - **Billing Profile:** `x_BillingProfileName` or `x_BillingProfileId`
> - **Invoice Section:** `x_InvoiceSectionName` or `x_InvoiceSectionId`
> - **Team:** `Tags['team']`
> - **Product:** `Tags['product']`
> - **Application:** `Tags['application']`

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
