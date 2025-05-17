# FinOps Hub Query Catalog

## Table of Contents

- [FinOps Hub Query Catalog](#finops-hub-query-catalog)
  - [Table of Contents](#table-of-contents)
  - [Adding Queries to the Catalog](#adding-queries-to-the-catalog)
  - [Catalog of Queries](#catalog-of-queries)

---

> **Note:** Refer to the [FinOps Hub Database Documentation](../finops-hub-database-guide.md) for table and column definitions.

---

## Adding Queries to the Catalog

When adding queries to the catalog, always follow these steps:

1. **Check Query Catalog first:** Always check this catalog to see if an equivalent query already exists before writing a new one.
2. **Repurpose if possible:** Only add a new query if an existing one cannot be repurposed or parameterized to meet your needs.
3. **Read the Database Documentation:** Review the [FinOps Hub Database Documentation](../finops-hub-database-guide.md) for the latest schema, best practices, and enrichment columns.
4. **Prefer parameterized, top-N queries:** Use `top N`, `last N`, or similar parameters to keep queries flexible and efficient.
5. **Parameterize all inputs:** Avoid hardcoding values—use parameters for dates, counts, etc.
6. **Test your query before submission:** Run your query in the FinOps Hub environment and verify the results. Only submit queries that have been tested and validated.
7. **Document and save:** Save the query as a `.kql` file in this folder. Include a header with the query name, description, author, parameters, and last tested date.
8. **Use schema-compliant output names:** All output variable names must comply with the [FinOps Hub database schema](../../src/queries/finops-hub-database-guide.md) for downstream compatibility. Avoid introducing new variable names unless absolutely necessary.
9. **Catalog the query:** If the query works and is documented, add a new entry to the table below. Hyperlink the query name to the `.kql` file and provide a clear description, parameters, and usage notes.

## Catalog of Queries

> **Note:** The table below is sorted alphabetically by query name for ease of use. Please keep this table in alphabetical order when adding new queries.

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|--------------|------------|-------------|-------|-------------|
| [all-available-cost-columns](/src/queries/catalog/all-available-cost-columns.kql) | All Available Columns | numberOfMonths | Full enrichment and savings logic for all columns in Costs_v1_0 | Use as a base for custom analytics and reporting | 2025-05-16 |
| [commitment-discount-utilization](/src/queries/catalog/commitment-discount-utilization.kql) | Commitment Discount Utilization | numberOfMonths | Visualize core hour consumption by discount type | Use for commitment discount utilization analysis | 2025-05-16 |
| [cost-anomaly-detection](/src/queries/catalog/cost-anomaly-detection.kql) | Cost Anomaly Detection | numberOfMonths (default: 12), interval (default: 1d) | Detects cost spikes and drops using time series decomposition and anomaly detection | Use for anomaly detection in cost trends | 2025-05-17 |
| [cost-by-region](/src/queries/catalog/cost-by-region.kql) | Cost by Region | numberOfMonths (default: 1) | Returns total effective cost by region for the last N months (default: 1) | Use for regional cost breakdowns and optimization | 2025-05-17 |
| [cost-forecasting](/src/queries/catalog/cost-forecasting.kql) | Cost Forecasting | numberOfMonths (default: 12), forecastPeriods (default: 90), interval (default: 1d) | Forecasts future cost using time series decomposition and forecasting | Use for projected spend and budget planning | 2025-05-17 |
| [monthly-cost-trend](/src/queries/catalog/monthly-cost-trend.kql) | Monthly Cost Trend | numberOfMonths (default: 12) | Returns total effective cost by month for the last N months (default 12) | Use for cost trend analysis and reporting | 2025-05-17 |
| [price-benchmarking](/src/queries/catalog/price-benchmarking.kql) | Price Benchmarking by Service | numberOfMonths (default: 1) | Returns list price, contracted price, effective price, negotiated savings (%), commitment savings (%), and total savings (%) by service | Use for price benchmarking and savings analysis | 2025-05-17 |
| [all-available-recommendation-columns](/src/queries/catalog/all-available-recommendation-columns.kql) | Reservation Savings Opportunity | (none) | Analyze reservation recommendations for cost savings and break-even | Use to identify and justify reservation purchases | 2025-05-16 |
| [top-n-cost-by-billing-profile-invoice-section-team-product-application](/src/queries/catalog/top-ncost-by-billing-profile-invoice-section-team-product-application-environment.kql) | Charge by financial hierarchy with tags | numberOfMonths, N | Reports cost by Billing Profile, Invoice Section, Team, Product, Application, Environment | Use for detailed cost allocation and reporting | 2025-05-16 |
| [top-n-quarterly-cost-by-resource-group](/src/queries/catalog/top-n-quarterly-cost-by-resource-group.kql) | Top N Quarterly Cost by Resource Group | numberOfMonths, N | Summarize effective cost by resource group over the last quarter | Use for quarterly resource group cost reporting | 2025-05-16 |
| [top-n-resource-types-by-cost](/src/queries/catalog/top-n-resource-types-by-cost.kql) | Top N Resource Types by Cost | N (default: 10), numberOfMonths (default: 1) | Returns the top N resource types by count and total effective cost for the last N months (default: 1) | Use for usage analysis and cost impact by resource type | 2025-05-17 |
| [top-n-services-by-cost](/src/queries/catalog/top-n-services-by-cost.kql) | Top N Services by Cost | N (default: 10), numberOfMonths (default: 1) | Returns the top N services by total effective cost for the last month | Use for identifying major cost drivers by service | 2025-05-17 |
| [top-N-resource-groups-by-effective-cost-last-month](/src/queries/catalog/top-N-resource-groups-by-effective-cost-last-month.kql) | Top N Resource Groups by Cost | numberOfMonths, N | Identify top 5 resource groups by effective cost for last month | Use for monthly cost concentration analysis | 2025-05-16 |
| [ytd-total-cost](/src/queries/catalog/ytd-total-cost.kql) | YTD Total Cost | (none) | Returns the total effective and billed cost from the start of the current year to date | Use for annual cost reporting and executive summaries | 2025-05-16 |
