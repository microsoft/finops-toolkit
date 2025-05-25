# FinOps Hub Query Catalog

## Table of Contents

- [Table of Contents](#table-of-contents)
- [FinOps Framework \& Principles](#finops-framework--principles)
- [FinOps Domains \& Query Catalog](#finops-domains--query-catalog)
- [References](#references)

---

> **Note:** Refer to the [FinOps Hub Database Documentation](./finops-hub-database-guide.md) for table and column definitions.

> **Tip:** If you do not find a more specific or suitable query for your analysis, start with the [`costs-enriched-base`](./catalog/costs-enriched-base.kql) query. It provides the full enrichment and savings logic for all cost columns and is the recommended foundation for custom analytics and reporting.

---

## FinOps Framework & Principles

The [FinOps Framework](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/finops-framework) is a set of best practices and principles for cloud financial management, as defined by the FinOps Foundation and Microsoft. It organizes FinOps into four domains:

1. **Understand Cloud Usage & Cost** – Gain visibility into spend, usage patterns, and cost drivers.
2. **Quantify Business Value** – Connect cloud spend to business outcomes and value delivered.
3. **Optimize Cloud Usage & Cost** – Identify and realize savings opportunities, optimize allocation, and forecast spend.
4. **Manage the FinOps Practice** – Support FinOps operations, reporting, and continuous improvement.

> Learn more: [FinOps Framework (Microsoft Learn)](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/finops-framework)

---

## FinOps Domains & Query Catalog

### Understand Cloud Usage & Cost

Gain visibility into cloud spend, usage patterns, and cost drivers.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [costs-enriched-base](./catalog/costs-enriched-base.kql) | All Available Cost Columns | startDate, endDate | Full enrichment and savings logic for all columns in Costs() | Use as a base for custom analytics and reporting | 2024-06-08 |
| [cost-by-region-trend](./catalog/cost-by-region-trend.kql) | Cost by Region (Custom Date Range) | startDate, endDate | Returns total effective cost by region for the specified date range | Use for regional cost breakdowns and optimization | 2024-06-08 |
| [monthly-cost-trend](./catalog/monthly-cost-trend.kql) | Monthly Cost Trend (Custom Date Range) | startDate, endDate | Returns total billed and effective cost by month for the specified date range | Use for cost trend analysis and reporting | 2024-06-08 |
| [top-resource-groups-by-cost](./catalog/top-resource-groups-by-cost.kql) | Top N Resource Groups by Effective Cost (Custom Date Range) | N (default: 5), startDate, endDate | Returns the top N resource groups by total effective cost for the specified date range | Use for monthly cost concentration analysis | 2024-06-08 |
| [quarterly-cost-by-resource-group](./catalog/quarterly-cost-by-resource-group.kql) | Top N Quarterly Cost by Resource Group (Custom Date Range) | N (default: 5), startDate, endDate | Summarize effective cost by resource group for the specified date range | Use for quarterly resource group cost reporting | 2024-06-08 |
| [top-resource-types-by-cost](./catalog/top-resource-types-by-cost.kql) | Top N Resource Types by Cost (Custom Date Range) | N (default: 10), startDate, endDate | Returns the top N resource types by count and total effective cost for the specified date range | Use for usage analysis and cost impact by resource type | 2024-06-08 |
| [top-services-by-cost](./catalog/top-services-by-cost.kql) | Top N Services by Cost (Custom Date Range) | N (default: 10), startDate, endDate | Returns the top N services by total effective cost for the specified date range | Use for identifying major cost drivers by service | 2024-06-08 |

### Quantify Business Value

Connect cloud spend to business outcomes and value delivered.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [cost-by-financial-hierarchy](./catalog/cost-by-financial-hierarchy.kql) | Top N Cost by Financial Hierarchy (Custom Date Range) | N (default: 5), startDate, endDate | Reports cost by Billing Profile, Invoice Section, Team, Product, Application, Environment for the specified date range | Use for detailed cost allocation and reporting | 2024-06-08 |
| [service-price-benchmarking](./catalog/service-price-benchmarking.kql) | Price Benchmarking by Service (Custom Date Range) | startDate, endDate | Returns list price, contracted price, effective price, negotiated savings, commitment savings, and total savings by service for the specified date range | Use for price benchmarking and savings analysis | 2024-06-08 |


### Optimize Cloud Usage & Cost

Identify and realize savings opportunities, optimize resource allocation, and forecast spend.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [cost-forecasting-model](./catalog/cost-forecasting-model.kql) | Cost Forecasting (Next 3 Months) | startDate, endDate, forecastPeriods (default: 90), interval (default: 1d) | Forecasts future cost using time series decomposition and forecasting for the specified date range | Use for projected spend and budget planning | 2024-06-08 |
| [cost-anomaly-detection](./catalog/cost-anomaly-detection.kql) | Cost Anomaly Detection (Last 12 Months) | numberOfMonths (default: 12), interval (default: 1d) | Detects cost spikes and drops using time series decomposition and anomaly detection | Use for anomaly detection in cost trends | 2024-06-08 |
| [monthly-cost-change-percentage](./catalog/monthly-cost-change-percentage.kql) | Monthly Cost Change Percentage (Custom Date Range) | startDate, endDate | Returns the month-over-month percent change for billed and effective cost over the specified date range | Use to monitor cost volatility and trend direction | 2024-06-08 |
| [commitment-discount-utilization](./catalog/commitment-discount-utilization.kql) | Commitment Discount Utilization (Custom Date Range) | startDate, endDate | Returns total consumed core hours by commitment discount type for the specified date range | Use to analyze RI/SP/on-demand utilization for optimization | 2024-06-08 |
| [savings-summary-report](./catalog/savings-summary-report.kql) | Summary of negotiated discount, commitment discount, and total savings with Effective Savings Rate (ESR) | startDate, endDate | Reports cost, negotiated discount savings, commitment discount savings, total savings, and Effective Savings Rate for the specified date range | Use for savings calculations | 2024-06-08 |
| [top-commitment-transactions](./catalog/top-commitment-transactions.kql) | Top N Commitment Transactions | N (default: 10), startDate, endDate | Returns the top N commitment (RI/SP) transactions by billed cost for the specified date range | Use for analyzing largest commitment transactions and their savings | 2024-06-08 |
| [top-other-transactions](./catalog/top-other-transactions.kql) | Top N Other Transactions | N (default: 10), startDate, endDate | Returns the top N non-commitment, non-usage purchase transactions for the specified date range | Use for analyzing miscellaneous Azure purchases not covered by RI/SP | 2024-06-08 |


### Manage the FinOps Practice

Support FinOps operations, reporting, and continuous improvement.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [reservation-recommendation-breakdown](./catalog/reservation-recommendation-breakdown.kql) | Reservation Recommendation Breakdown | (none) | Analyze reservation recommendations for cost savings and break-even | Use to identify and justify reservation purchases | 2024-06-08 |

---

## References

- [FinOps Framework (Microsoft Learn)](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/finops-framework)
- [Implementing FinOps Guide (Microsoft Learn)](https://learn.microsoft.com/en-us/cloud-computing/finops/implementing-finops-guide)
- [Adopt FinOps on Azure (Microsoft Learn)](https://learn.microsoft.com/en-us/training/modules/adopt-finops-on-azure/)
- [FinOps Hub Database Documentation](./finops-hub-database-guide.md)
- [FinOps Foundation](https://www.finops.org/framework/)
