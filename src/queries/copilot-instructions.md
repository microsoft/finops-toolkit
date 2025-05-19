# GitHub Copilot Instructions for FinOps Hub

This document provides instructions for using GitHub Copilot Agent Mode in VS Code to query and analyze data in FinOps Hub using the Azure MCP server.

## 🔍 Overview

GitHub Copilot in Agent Mode can help you:
- Generate KQL (Kusto Query Language) queries for FinOps Hub data analysis
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
- [GitHub Copilot Agent Mode Documentation](https://docs.github.com/en/copilot/github-copilot-chat/using-github-copilot-chat-in-your-ide)

## 🤖 Using Copilot Agent Mode

To use GitHub Copilot Agent Mode with FinOps Hub:

1. **Open GitHub Copilot Chat** in VS Code (Ctrl+Shift+I / Cmd+Shift+I)
2. **Activate Agent Mode** by typing "@AzureMCP" to direct your query to the Azure MCP server
3. **Specify FinOps Hub analysis** in your prompt, such as:
   - "@AzureMCP Generate a KQL query to analyze my last month's costs by service"
   - "@AzureMCP Find resource groups with the highest costs this quarter"
   - "@AzureMCP Help me detect cost anomalies in the last 30 days"

## 📌 Required Context for Queries

When asking Copilot to generate KQL queries, always include:

1. **Target Data Source**: Specify which FinOps Hub database (`Hub` or `Ingestion`) and table/function to query.
2. **Time Range**: Define the time period for the analysis (last 30 days, current month, etc.).
3. **Aggregation Level**: Determine the level of detail (subscription, resource group, resource).
4. **Filtering Criteria**: Include any necessary filters (services, regions, tags).

Example query request:
```
@AzureMCP Generate a KQL query to analyze Virtual Machine costs by resource group for the last 30 days from the Hub database using the Costs() function.
```

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

Example prompt:
```
@AzureMCP Generate a KQL query that shows monthly cost by resource group for the current month
```

Example result:
```kql
// Get monthly cost by resource group for the current month
Costs()
| where TimeGenerated >= startofmonth(now())
| where TimeGenerated < endofmonth(now())
| summarize TotalCost = sum(Cost) by ResourceGroup
| order by TotalCost desc
| extend FormattedCost = strcat('$', format_number(TotalCost, 2))
| project ["Resource Group"] = ResourceGroup, ["Total Cost"] = FormattedCost
```

## 🔄 Iterative Query Development

When working with Copilot Agent Mode, you can refine queries iteratively:

1. Start with a basic query request
2. Review the generated query
3. Ask for modifications or improvements
4. Apply the query to your FinOps Hub data
5. Share results with Copilot for further analysis

Example iterative flow:
```
You: @AzureMCP Show me the top 5 most expensive resource groups

Copilot: Here's a query to find the top 5 most expensive resource groups...
[query displayed]

You: @AzureMCP Modify that query to show costs by month for the last quarter

Copilot: I've updated the query to show monthly costs for the last quarter...
[updated query displayed]
```