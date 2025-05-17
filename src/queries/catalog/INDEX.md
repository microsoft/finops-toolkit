# FinOps Hub Query Catalog

## Table of Contents

- [FinOps Hub Query Catalog](#finops-hub-query-catalog)
  - [Table of Contents](#table-of-contents)
  - [Catalog of Queries](#catalog-of-queries)

---

> **Note:** Refer to the [FinOps Hub Database Schema](../finops-hub-database-guide.md) documentation for table and column definitions.

---

## Catalog of Queries

| Query Name/ID | Name | Parameters | Description | Usage | Last Tested |
|---------------|--------------|------------|-------------|-------|-------------|
| [all-available-columns](/src/queries/catalog/all-available-columns.kql) | All Available Columns | numberOfMonths | Full enrichment and savings logic for all columns in Costs_v1_0 | Use as a base for custom analytics and reporting | 2025-05-16 |
| [commitment-discount-utilization](/src/queries/catalog/commitment-discount-utilization.kql) | Commitment Discount Utilization | numberOfMonths | Visualize core hour consumption by discount type | Use for commitment discount utilization analysis | 2025-05-16 |
| [reservation-recommendation-breakdown](/src/queries/catalog/reservation-recommendation-breakdown.kql) | Reservation Savings Opportunity | (none) | Analyze reservation recommendations for cost savings and break-even | Use to identify and justify reservation purchases | 2025-05-16 |
| [top-n-cost-by-billing-profile-invoice-section-team-product-application](/src/queries/catalog/top-ncost-by-billing-profile-invoice-section-team-product-application-environment.kql) | Charge by financial hierarchy with tags | numberOfMonths, N | Reports cost by Billing Profile, Invoice Section, Team, Product, Application, Environment | Use for detailed cost allocation and reporting | 2025-05-16 |
| [top-n-quarterly-cost-by-resource-group](/src/queries/catalog/top-n-quarterly-cost-by-resource-group.kql) | Top N Quarterly Cost by Resource Group | numberOfMonths, N | Summarize effective cost by resource group over the last quarter | Use for quarterly resource group cost reporting | 2025-05-16 |
| [top-N-resource-groups-by-effective-cost-last-month](/src/queries/catalog/top-N-resource-groups-by-effective-cost-last-month.kql) | Top N Resource Groups by Cost | numberOfMonths, N | Identify top 5 resource groups by effective cost for last month | Use for monthly cost concentration analysis | 2025-05-16 |
