# FinOps Hub KQL Query Catalog

This catalog contains KQL (Kusto Query Language) queries for various FinOps Hub analytics scenarios. Use these queries as templates for your own analysis or incorporate them into your custom dashboards and reports.

## How to Use This Catalog

1. Browse the catalog by category below
2. Open the query file of interest
3. Copy the query and adapt it to your specific needs
4. Execute the query against your FinOps Hub using the Azure Data Explorer web UI or a compatible client

> **Note**: All queries are designed to work with the standard FinOps Hub data model. If you've customized your FinOps Hub deployment, you may need to adjust the queries accordingly.

## Categories

### Cost Analysis

| Query Name | Description | Path |
|------------|-------------|------|
| [Cost by Resource Group](./catalog/cost-by-resource-group.kql) | Analyze costs aggregated by resource group | [cost-by-resource-group.kql](./catalog/cost-by-resource-group.kql) |
| [Cost by Region](./catalog/cost-by-region.kql) | Analyze costs aggregated by Azure region | [cost-by-region.kql](./catalog/cost-by-region.kql) |
| [Cost by Service](./catalog/cost-by-service.kql) | Analyze costs aggregated by Azure service | [cost-by-service.kql](./catalog/cost-by-service.kql) |
| [Cost Trend Analysis](./catalog/cost-trend-analysis.kql) | Analyze cost trends over time | [cost-trend-analysis.kql](./catalog/cost-trend-analysis.kql) |
| [Tag-based Cost Analysis](./catalog/tag-based-cost-analysis.kql) | Analyze costs based on resource tags | [tag-based-cost-analysis.kql](./catalog/tag-based-cost-analysis.kql) |

### Commitment Discounts

| Query Name | Description | Path |
|------------|-------------|------|
| [Reserved Instance Utilization](./catalog/reserved-instance-utilization.kql) | Analyze Reserved Instance utilization | [reserved-instance-utilization.kql](./catalog/reserved-instance-utilization.kql) |
| [Savings Plan Utilization](./catalog/savings-plan-utilization.kql) | Analyze Savings Plan utilization | [savings-plan-utilization.kql](./catalog/savings-plan-utilization.kql) |
| [Commitment Discount Coverage](./catalog/commitment-discount-coverage.kql) | Analyze overall commitment discount coverage | [commitment-discount-coverage.kql](./catalog/commitment-discount-coverage.kql) |
| [Commitment Optimization Opportunities](./catalog/commitment-optimization-opportunities.kql) | Identify opportunities for optimizing commitments | [commitment-optimization-opportunities.kql](./catalog/commitment-optimization-opportunities.kql) |

### Anomaly Detection

| Query Name | Description | Path |
|------------|-------------|------|
| [Daily Cost Anomalies](./catalog/daily-cost-anomalies.kql) | Detect anomalies in daily costs | [daily-cost-anomalies.kql](./catalog/daily-cost-anomalies.kql) |
| [Resource Usage Anomalies](./catalog/resource-usage-anomalies.kql) | Detect anomalies in resource usage patterns | [resource-usage-anomalies.kql](./catalog/resource-usage-anomalies.kql) |
| [Service Cost Spikes](./catalog/service-cost-spikes.kql) | Identify sudden increases in service costs | [service-cost-spikes.kql](./catalog/service-cost-spikes.kql) |

### Forecasting and Benchmarking

| Query Name | Description | Path |
|------------|-------------|------|
| [Monthly Cost Forecast](./catalog/monthly-cost-forecast.kql) | Forecast monthly costs based on historical data | [monthly-cost-forecast.kql](./catalog/monthly-cost-forecast.kql) |
| [Budget Tracking](./catalog/budget-tracking.kql) | Track actual spending against budgets | [budget-tracking.kql](./catalog/budget-tracking.kql) |
| [Cost Benchmark Comparison](./catalog/cost-benchmark-comparison.kql) | Compare costs against benchmarks | [cost-benchmark-comparison.kql](./catalog/cost-benchmark-comparison.kql) |

## Contributing

To add new queries to the catalog:

1. Create a new `.kql` file in the appropriate subdirectory of `./catalog/`
2. Include detailed comments at the beginning of the file explaining the query's purpose, required parameters, and expected output
3. Add a reference to your query in this index file
4. Submit a pull request with your changes

## Resources

For more information on KQL and FinOps Hub:

- [Kusto Query Language (KQL) Documentation](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [FinOps Hub Documentation](https://aka.ms/finops/hubs/docs)
- [FinOps Hub Data Model](https://aka.ms/finops/hubs/data-model)
- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)