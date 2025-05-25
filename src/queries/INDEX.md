# FinOps Hub Query Catalog

## Table of Contents

- [Table of Contents](#table-of-contents)
- [FinOps Framework \& Principles](#finops-framework--principles)
- [FinOps Domains \& Query Catalog](#finops-domains--query-catalog)
- [References](#references)

---

> **Note:** Refer to the [FinOps Hub Database Documentation](./finops-hub-database-guide.md) for table and column definitions.

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
| [costs-enriched-base](./catalog/costs-enriched-base.kql) | All Available Cost Columns | numberOfMonths (default: 1) | Full enrichment and savings logic for all columns in Costs() | Use as a base for custom analytics and reporting | 2025-05-17 |
| [cost-by-region-trend](./catalog/cost-by-region-trend.kql) | Cost by Region (Last N Months) | numberOfMonths (default: 1) | Returns total effective cost by region for the last N months | Use for regional cost breakdowns and optimization | 2025-05-17 |
| [monthly-cost-trend](./catalog/monthly-cost-trend.kql) | Last N Month Cost Trend | numberOfMonths (default: 12) | Returns total billed and effective cost by month for the last N months | Use for cost trend analysis and reporting | 2025-05-17 |
| [top-resource-groups-by-cost](./catalog/top-resource-groups-by-cost.kql) | Top N Resource Groups by Effective Cost (Last Month) | N (default: 5), numberOfMonths (default: 1) | Returns the top N resource groups by total effective cost for the last month | Use for monthly cost concentration analysis | 2025-05-17 |
| [quarterly-cost-by-resource-group](./catalog/quarterly-cost-by-resource-group.kql) | Top N Quarterly Cost by Resource Group | N (default: 5), numberOfMonths (default: 3) | Summarize effective cost by resource group over the last quarter | Use for quarterly resource group cost reporting | 2025-05-17 |
| [top-resource-types-by-cost](./catalog/top-resource-types-by-cost.kql) | Top N Resource Types by Cost (Last Month) | N (default: 10), numberOfMonths (default: 1) | Returns the top N resource types by count and total effective cost for the last N months | Use for usage analysis and cost impact by resource type | 2025-05-17 |
| [top-services-by-cost](./catalog/top-services-by-cost.kql) | Top N Services by Cost | N (default: 10), numberOfMonths (default: 1) | Returns the top N services by total effective cost for the last month | Use for identifying major cost drivers by service | 2025-05-17 |
| [month-to-date-running-cost](./catalog/month-to-date-running-cost.kql) | Running Cost This Month | (none) | Returns the running daily effective cost for the current month | Use for tracking cumulative spend throughout the current month | 2025-05-17 |
| [year-to-date-total-cost](./catalog/year-to-date-total-cost.kql) | YTD Total Cost | (none) | Returns the total effective and billed cost from the start of the current year to date | Use for annual cost reporting and executive summaries | 2025-05-17 |


### Quantify Business Value

Connect cloud spend to business outcomes and value delivered.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [cost-by-financial-hierarchy](./catalog/cost-by-financial-hierarchy.kql) | Top N Cost by Financial Hierarchy | N (default: 5), numberOfMonths (default: 1) | Reports cost by Billing Profile, Invoice Section, Team, Product, Application, Environment | Use for detailed cost allocation and reporting | 2025-05-17 |
| [service-price-benchmarking](./catalog/service-price-benchmarking.kql) | Last N Month Price Benchmarking by Service | numberOfMonths (default: 1) | Returns list price, contracted price, effective price, negotiated savings, commitment savings, and total savings by service for the last N months | Use for price benchmarking and savings analysis | 2025-05-17 |


### Optimize Cloud Usage & Cost

Identify and realize savings opportunities, optimize resource allocation, and forecast spend.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [cost-forecasting-model](./catalog/cost-forecasting-model.kql) | Cost Forecasting (Next 3 Months) | numberOfMonths (default: 12), forecastPeriods (default: 90), interval (default: 1d) | Forecasts future cost using time series decomposition and forecasting | Use for projected spend and budget planning | 2025-05-17 |
| [cost-anomaly-detection](./catalog/cost-anomaly-detection.kql) | Cost Anomaly Detection (Last 12 Months) | numberOfMonths (default: 12), interval (default: 1d) | Detects cost spikes and drops using time series decomposition and anomaly detection | Use for anomaly detection in cost trends | 2025-05-17 |
| [monthly-cost-change-percentage](./catalog/monthly-cost-change-percentage.kql) | Monthly Cost Change Percentage (Last N Months) | numberOfMonths (default: 13) | Returns the month-over-month percent change for billed and effective cost over the last N months | Use to monitor cost volatility and trend direction | 2025-05-17 |
| [commitment-discount-utilization](./catalog/commitment-discount-utilization.kql) | Commitment Discount Utilization (Last N Months) | numberOfMonths (default: 1) | Returns total consumed core hours by commitment discount type for the last N months | Use to analyze RI/SP/on-demand utilization for optimization | 2025-05-17 |
| [savings-summary-report](./catalog/savings-summary-report.kql) | Summary of negotiated discount, commitment discount, and total savings with Effective Savings Rate (ESR) | numberOfMonths (default: 1) | Reports cost, negotiated discount savings, commitment discount savings, total savings, and Effective Savings Rate | Use for savings calculations | 2025-05-20 |
| [top-commitment-transactions](./catalog/top-commitment-transactions.kql) | Top N Commitment Transactions | N (default: 10), numberOfMonths (default: 1) | Returns the top N commitment (RI/SP) transactions by billed cost for the last N months | Use for analyzing largest commitment transactions and their savings | 2025-05-17 |
| [top-other-transactions](./catalog/top-other-transactions.kql) | Top N Other Transactions | N (default: 10), numberOfMonths (default: 1) | Returns the top N non-commitment, non-usage purchase transactions for the last N months | Use for analyzing miscellaneous Azure purchases not covered by RI/SP | 2025-05-17 |


### Manage the FinOps Practice

Support FinOps operations, reporting, and continuous improvement.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|------|------------|-------------|-------|-------------|
| [reservation-recommendation-breakdown](./catalog/reservation-recommendation-breakdown.kql) | Reservation Recommendation Breakdown | (none) | Analyze reservation recommendations for cost savings and break-even | Use to identify and justify reservation purchases | 2025-05-17 |

---

## References

- [FinOps Framework (Microsoft Learn)](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/finops-framework)
- [Implementing FinOps Guide (Microsoft Learn)](https://learn.microsoft.com/en-us/cloud-computing/finops/implementing-finops-guide)
- [Adopt FinOps on Azure (Microsoft Learn)](https://learn.microsoft.com/en-us/training/modules/adopt-finops-on-azure/)
- [FinOps Hub Database Documentation](./finops-hub-database-guide.md)
- [FinOps Foundation](https://www.finops.org/framework/)
