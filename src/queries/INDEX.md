# FinOps Hub KQL Query Catalog

This catalog contains KQL (Kusto Query Language) queries for various FinOps Hub analytics scenarios. Use these queries as templates for your own analysis or incorporate them into your custom dashboards and reports.

## How to Use This Catalog

1. Browse the catalog by category below
2. Open the query file of interest
3. Copy the query and adapt it to your specific needs
4. Execute the query against your FinOps Hub using the Azure Data Explorer web UI or a compatible client
5. For use with GitHub Copilot, see [Copilot Instructions](./copilot-instructions.md)

> **Note**: All queries are designed to work with the standard FinOps Hub data model. If you've customized your FinOps Hub deployment, you may need to adjust the queries accordingly.

## Categories

### Cost Analysis

| Query Name | Description | Path |
|------------|-------------|------|
| [Cost by Resource Group](./catalog/cost-by-resource-group.kql) | Analyze costs aggregated by resource group | [cost-by-resource-group.kql](./catalog/cost-by-resource-group.kql) |
| [Cost by Region](./catalog/cost-by-region.kql) | Analyze costs aggregated by Azure region | [cost-by-region.kql](./catalog/cost-by-region.kql) |
| [Top N Services by Cost](./catalog/top-n-services-by-cost.kql) | Returns top services by total effective cost | [top-n-services-by-cost.kql](./catalog/top-n-services-by-cost.kql) |
| [Top N Resource Types by Cost](./catalog/top-n-resource-types-by-cost.kql) | Returns top resource types by count and cost | [top-n-resource-types-by-cost.kql](./catalog/top-n-resource-types-by-cost.kql) |
| [Last N Month Cost Trend](./catalog/last-n-month-cost-trend.kql) | Returns total billed and effective cost by month | [last-n-month-cost-trend.kql](./catalog/last-n-month-cost-trend.kql) |

### Commitment Discounts

| Query Name | Description | Path |
|------------|-------------|------|
| [Reserved Instance Utilization](./catalog/reserved-instance-utilization.kql) | Analyze Reserved Instance utilization | [reserved-instance-utilization.kql](./catalog/reserved-instance-utilization.kql) |
| [Commitment Discount Coverage](./catalog/commitment-discount-coverage.kql) | Analyze overall commitment discount coverage | [commitment-discount-coverage.kql](./catalog/commitment-discount-coverage.kql) |
| [Last N Month Commitment Discount Utilization](./catalog/last-n-month-commitment-discount-utilization.kql) | Returns consumed core hours by commitment discount type | [last-n-month-commitment-discount-utilization.kql](./catalog/last-n-month-commitment-discount-utilization.kql) |
| [Top N Commitment Transactions](./catalog/top-n-transactions-commitments.kql) | Returns top commitment (RI/SP) transactions by cost | [top-n-transactions-commitments.kql](./catalog/top-n-transactions-commitments.kql) |

### Anomaly Detection

| Query Name | Description | Path |
|------------|-------------|------|
| [Daily Cost Anomalies](./catalog/daily-cost-anomalies.kql) | Detect anomalies in daily costs | [daily-cost-anomalies.kql](./catalog/daily-cost-anomalies.kql) |
| [Cost Anomaly Detection](./catalog/cost-anomaly-detection.kql) | Detects cost spikes and drops using time series decomposition | [cost-anomaly-detection.kql](./catalog/cost-anomaly-detection.kql) |

### Forecasting and Benchmarking

| Query Name | Description | Path |
|------------|-------------|------|
| [Monthly Cost Forecast](./catalog/monthly-cost-forecast.kql) | Forecast monthly costs based on historical data | [monthly-cost-forecast.kql](./catalog/monthly-cost-forecast.kql) |
| [Cost Forecasting](./catalog/cost-forecasting.kql) | Forecasts future cost using time series decomposition | [cost-forecasting.kql](./catalog/cost-forecasting.kql) |
| [Last N Month Price Benchmarking](./catalog/last-n-month-price-benchmarking.kql) | Returns price benchmarking and savings analysis by service | [last-n-month-price-benchmarking.kql](./catalog/last-n-month-price-benchmarking.kql) |
| [YTD Total Cost](./catalog/ytd-total-cost.kql) | Returns the total cost from the start of current year to date | [ytd-total-cost.kql](./catalog/ytd-total-cost.kql) |
| [MTD Running Cost](./catalog/mtd-running-cost.kql) | Returns running daily effective cost for current month | [mtd-running-cost.kql](./catalog/mtd-running-cost.kql) |

### Financial Analysis

| Query Name | Description | Path |
|------------|-------------|------|
| [Top N Cost by Financial Hierarchy](./catalog/top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql) | Reports cost by billing profile and other dimensions | [top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql](./catalog/top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql) |
| [Top N Quarterly Cost by Resource Group](./catalog/top-n-quarterly-cost-by-resource-group.kql) | Summarize effective cost by resource group over quarter | [top-n-quarterly-cost-by-resource-group.kql](./catalog/top-n-quarterly-cost-by-resource-group.kql) |
| [Top N Resource Groups by Effective Cost](./catalog/top-n-resource-groups-by-effective-cost.kql) | Returns top resource groups by total effective cost | [top-n-resource-groups-by-effective-cost.kql](./catalog/top-n-resource-groups-by-effective-cost.kql) |
| [Last N Month Costs Change Over Time](./catalog/last-n-month-costs-change-over-time.kql) | Returns month-over-month percent change for costs | [last-n-month-costs-change-over-time.kql](./catalog/last-n-month-costs-change-over-time.kql) |
| [Top N Other Transactions](./catalog/top-n-transactions-other.kql) | Returns top non-commitment, non-usage purchase transactions | [top-n-transactions-other.kql](./catalog/top-n-transactions-other.kql) |

### Data Schema References

| Query Name | Description | Path |
|------------|-------------|------|
| [All Available Cost Columns](./catalog/all-available-cost-columns.kql) | Full enrichment and savings logic for all columns in Costs_v1_0 | [all-available-cost-columns.kql](./catalog/all-available-cost-columns.kql) |
| [All Available Recommendation Columns](./catalog/all-available-recommendation-columns.kql) | Analyze reservation recommendations for cost savings and break-even | [all-available-recommendation-columns.kql](./catalog/all-available-recommendation-columns.kql) |

## Contributing

To add new queries to the catalog:

1. Create a new `.kql` file in the appropriate subdirectory of `./catalog/`
2. Include detailed comments at the beginning of the file explaining the query's purpose, required parameters, and expected output
3. Add a reference to your query in this index file
4. Submit a pull request with your changes

### Reference Queries

| Query Name | Description | Path |
|------------|-------------|------|
| [All Available Cost Columns](./catalog/all-available-cost-columns.kql) | Full enrichment and savings logic for all columns in Costs_v1_0 | [all-available-cost-columns.kql](./catalog/all-available-cost-columns.kql) |
| [All Available Recommendation Columns](./catalog/all-available-recommendation-columns.kql) | Analyze reservation recommendations for cost savings and break-even | [all-available-recommendation-columns.kql](./catalog/all-available-recommendation-columns.kql) |
| [Cost Anomaly Detection](./catalog/cost-anomaly-detection.kql) | Detects cost spikes and drops using time series decomposition | [cost-anomaly-detection.kql](./catalog/cost-anomaly-detection.kql) |
| [Cost Forecasting](./catalog/cost-forecasting.kql) | Forecasts future cost using time series decomposition | [cost-forecasting.kql](./catalog/cost-forecasting.kql) |
| [Last N Month Commitment Discount Utilization](./catalog/last-n-month-commitment-discount-utilization.kql) | Returns consumed core hours by commitment discount type | [last-n-month-commitment-discount-utilization.kql](./catalog/last-n-month-commitment-discount-utilization.kql) |
| [Last N Month Cost by Region](./catalog/last-n-month-cost-by-region.kql) | Returns total effective cost by region | [last-n-month-cost-by-region.kql](./catalog/last-n-month-cost-by-region.kql) |
| [Last N Month Cost Trend](./catalog/last-n-month-cost-trend.kql) | Returns total billed and effective cost by month | [last-n-month-cost-trend.kql](./catalog/last-n-month-cost-trend.kql) |
| [Last N Month Costs Change Over Time](./catalog/last-n-month-costs-change-over-time.kql) | Returns month-over-month percent change for costs | [last-n-month-costs-change-over-time.kql](./catalog/last-n-month-costs-change-over-time.kql) |
| [Last N Month Price Benchmarking](./catalog/last-n-month-price-benchmarking.kql) | Returns price benchmarking and savings analysis by service | [last-n-month-price-benchmarking.kql](./catalog/last-n-month-price-benchmarking.kql) |
| [MTD Running Cost](./catalog/mtd-running-cost.kql) | Returns running daily effective cost for current month | [mtd-running-cost.kql](./catalog/mtd-running-cost.kql) |
| [Top N Cost by Financial Hierarchy](./catalog/top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql) | Reports cost by billing profile and other dimensions | [top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql](./catalog/top-n-cost-by-billing-profile-invoice-section-team-product-application-environment.kql) |
| [Top N Quarterly Cost by Resource Group](./catalog/top-n-quarterly-cost-by-resource-group.kql) | Summarize effective cost by resource group over quarter | [top-n-quarterly-cost-by-resource-group.kql](./catalog/top-n-quarterly-cost-by-resource-group.kql) |
| [Top N Resource Groups by Effective Cost](./catalog/top-n-resource-groups-by-effective-cost.kql) | Returns top resource groups by total effective cost | [top-n-resource-groups-by-effective-cost.kql](./catalog/top-n-resource-groups-by-effective-cost.kql) |
| [Top N Resource Types by Cost](./catalog/top-n-resource-types-by-cost.kql) | Returns top resource types by count and cost | [top-n-resource-types-by-cost.kql](./catalog/top-n-resource-types-by-cost.kql) |
| [Top N Services by Cost](./catalog/top-n-services-by-cost.kql) | Returns top services by total effective cost | [top-n-services-by-cost.kql](./catalog/top-n-services-by-cost.kql) |
| [Top N Commitment Transactions](./catalog/top-n-transactions-commitments.kql) | Returns top commitment (RI/SP) transactions by cost | [top-n-transactions-commitments.kql](./catalog/top-n-transactions-commitments.kql) |
| [Top N Other Transactions](./catalog/top-n-transactions-other.kql) | Returns top non-commitment, non-usage purchase transactions | [top-n-transactions-other.kql](./catalog/top-n-transactions-other.kql) |
| [YTD Total Cost](./catalog/ytd-total-cost.kql) | Returns the total cost from the start of current year to date | [ytd-total-cost.kql](./catalog/ytd-total-cost.kql) |

## Resources

For more information on KQL and FinOps Hub:

- [Kusto Query Language (KQL) Documentation](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [FinOps Hub Documentation](https://aka.ms/finops/hubs/docs)
- [FinOps Hub Data Model](https://aka.ms/finops/hubs/data-model)
- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)