# GitHub Copilot Instructions for FinOps Hub

This document provides instructions for using GitHub Copilot to query and analyze data in FinOps Hub using the Azure MCP Server.

## 🔍 Overview

When working with FinOps Hub, GitHub Copilot can help you:
- Generate KQL (Kusto Query Language) queries for cost analysis
- Identify cost optimization opportunities
- Assist with anomaly detection and forecasting
- Format and analyze query results

## 📚 Authoritative References

Always rely on these official sources when working with FinOps Hub data:

- [Azure Resource Graph Documentation](https://docs.microsoft.com/azure/governance/resource-graph/)
- [Kusto Query Language (KQL) Documentation](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [FinOps Hub Documentation](https://aka.ms/finops/hubs/docs)
- [Azure Data Explorer Documentation](https://docs.microsoft.com/azure/data-explorer/)

## 📌 Required Context for Queries

When generating KQL queries, always include:

1. **Target Data Source**: Specify which FinOps Hub database (`Hub` or `Ingestion`) and table/function to query.
2. **Time Range**: Define the time period for the analysis (last 30 days, current month, etc.).
3. **Aggregation Level**: Determine the level of detail (subscription, resource group, resource).
4. **Filtering Criteria**: Include any necessary filters (services, regions, tags).

## 🛠 Mandatory Procedures

### Query Execution

1. **Always use the Hub database** - Query the unversioned functions in the Hub database (e.g., `Costs()`) and avoid querying tables directly in the Ingestion database.

2. **Version compatibility** - For long-term reports or systems requiring backward compatibility, use versioned functions (e.g., `Costs_v1_0()`).

3. **Data validation** - Include data validation steps in your queries:
   ```kql
   | where isnotempty(ResourceId)
   | where Quantity > 0
   ```

4. **Performance optimization** - Always add filters early in the query:
   ```kql
   | where TimeGenerated >= ago(30d)
   | where ServiceName == "Virtual Machines"
   ```

### Error Handling

1. **Empty result detection**:
   ```kql
   | summarize Count = count()
   | extend HasResults = iff(Count > 0, "Yes", "No")
   ```

2. **Handle missing data**:
   ```kql
   | extend ServiceName = iif(isempty(ServiceName), "Unidentified", ServiceName)
   ```

3. **Validate numeric calculations**:
   ```kql
   | extend Cost = iif(Cost < 0 or isnan(Cost) or isinf(Cost), 0.0, Cost)
   ```

### Result Formatting

1. **Use standard formatting for currency**:
   ```kql
   | extend FormattedCost = strcat('$', format_number(Cost, 2))
   ```

2. **Format percentages consistently**:
   ```kql
   | extend SavingsPercent = format_number(Savings / TotalCost * 100, 2)
   ```

3. **Always include column headers that are meaningful**:
   ```kql
   | project ["Resource Name"] = ResourceName, ["Resource Group"] = ResourceGroup, ["Monthly Cost"] = MonthlyCost
   ```

## 🔧 Azure MCP Server Configuration

To use GitHub Copilot with the Azure MCP Server for FinOps Hub:

1. **Configure the MCP Server connection in VS Code**:
   - Open VS Code Settings
   - Navigate to Extensions > GitHub Copilot > Chat > MCP Servers
   - Add a new MCP Server with:
     - Name: "Azure MCP Server"
     - URL: Endpoint URL for your Azure MCP server

2. **Use the agent mode in VS Code**:
   - Access Copilot in VS Code (Ctrl+Shift+I / Cmd+Shift+I)
   - Type "@AzureMCP" to activate the Azure MCP Server agent
   - Specify that you want to work with FinOps Hub data

## 🚫 Common Pitfalls to Avoid

1. **Avoid cross-database queries** as they may not be supported or optimized.
2. **Don't access raw tables directly** - use the provided functions.
3. **Avoid querying excessive time ranges** which can impact performance.
4. **Don't include sensitive information** in queries or results.
5. **Avoid hardcoding subscription IDs or tenant IDs** directly in queries.

## 🔄 Query Testing and Validation

All queries should be tested for:

1. **Performance** - Check query execution time and resource utilization
2. **Accuracy** - Validate results against expected values
3. **Error handling** - Test with edge cases and missing data
4. **Security** - Ensure no sensitive data is exposed

## 💡 Example Query Flow

```kql
// Get monthly cost by resource group
Costs()
| where TimeGenerated >= startofmonth(now())
| where TimeGenerated < endofmonth(now())
| summarize TotalCost = sum(Cost) by ResourceGroup
| order by TotalCost desc
| extend FormattedCost = strcat('$', format_number(TotalCost, 2))
| project ["Resource Group"] = ResourceGroup, ["Total Cost"] = FormattedCost
```