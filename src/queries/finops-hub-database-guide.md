# FinOps Hub Database Guide

This guide provides information about the FinOps Hub database schema, tables, and usage patterns to help you build effective KQL queries for your financial operations and cost analysis tasks.

## 📊 Database Structure

FinOps Hub includes two primary Azure Data Explorer databases:

1. **Hub database**: The main database for querying and analysis. Contains:
   - Unversioned functions (e.g., `Costs()`)
   - Versioned functions (e.g., `Costs_v1_0()`)

2. **Ingestion database**: Used for raw data ingestion and processing. Contains:
   - Versioned "final" tables (e.g., `Costs_final_v1_0`)

> **Important**: Always query the **Hub** database using the provided functions rather than working directly with tables in the **Ingestion** database.

## 📋 Key Tables and Functions

### Core Data Functions

| Function Name | Description | Example Usage |
|---------------|-------------|--------------|
| `Costs()` | Returns cost data across all subscriptions | `Costs() \| where TimeGenerated >= ago(30d)` |
| `Resources()` | Returns resource inventory data | `Resources() \| where ResourceType == "microsoft.compute/virtualmachines"` |
| `Recommendations()` | Returns optimization recommendations | `Recommendations() \| where Category == "Cost"` |
| `Prices()` | Returns pricing information | `Prices() \| where MeterName contains "Virtual Machines"` |
| `Transactions()` | Returns detailed usage transactions | `Transactions() \| where ServiceName == "Storage"` |

### Support Tables

| Table Name | Description | Example Usage |
|------------|-------------|--------------|
| `Subscriptions` | Information about Azure subscriptions | `Subscriptions \| join Costs() on SubscriptionId` |
| `ResourceTypes` | Information about Azure resource types | `ResourceTypes \| where Provider == "Microsoft.Compute"` |
| `Regions` | Information about Azure regions | `Regions \| where RegionName contains "East US"` |
| `Services` | Information about Azure services | `Services \| where ServiceName contains "Virtual Machines"` |
| `PricingUnits` | Information about pricing units | `PricingUnits \| where UnitName == "1 Hour"` |

### Specialized Tables

| Table Name | Description | Example Usage |
|------------|-------------|--------------|
| `VirtualMachines` | Details about virtual machine resources | `VirtualMachines \| where Size contains "Standard_D"` |
| `Disks` | Details about managed disks | `Disks \| where SKU contains "Premium"` |
| `SqlDatabases` | Details about SQL databases | `SqlDatabases \| where Edition == "Business Critical"` |
| `StorageData` | Details about storage accounts | `StorageData \| where AccountType contains "Premium"` |
| `NetworkInterfaces` | Details about network interfaces | `NetworkInterfaces \| where isnotempty(PrivateIPAddress)` |

## 📝 Key KQL Functions

FinOps Hub provides several utility KQL functions to help with data analysis:

| Function Name | Description | Example |
|---------------|-------------|---------|
| `parse_resourceid()` | Parses Azure resource IDs into components | `\| extend parsed = parse_resourceid(ResourceId)` |
| `percent()` | Calculates percentages based on a count column | `\| extend PercData = percent(Count)` |
| `percentOfTotal()` | Calculates percentage of a total value | `\| extend PctOfTotal = percentOfTotal(Cost, TotalCost)` |
| `deltastring()` | Formats change values with an arrow indicator | `\| extend DeltaStr = deltastring(CurrentValue, PreviousValue)` |
| `updown()` | Adds an up/down indicator based on a comparison | `\| extend Trend = updown(CurrentMonth, PreviousMonth)` |
| `resource_type()` | Extracts resource type information | `\| extend ResourceDetails = resource_type(ResourceType)` |

## 🔍 Common Schema Patterns

### Costs Function Schema

Key fields in the `Costs()` function:

```
Costs
 ├─ TimeGenerated: datetime
 ├─ SubscriptionId: string
 ├─ ResourceGroup: string
 ├─ ResourceId: string
 ├─ ResourceName: string
 ├─ ResourceType: string
 ├─ ServiceName: string
 ├─ ServiceTier: string
 ├─ Meter: string
 ├─ MeterCategory: string
 ├─ MeterSubCategory: string
 ├─ Cost: real
 ├─ Quantity: real
 ├─ UnitOfMeasure: string
 ├─ Currency: string
 ├─ Tags: dynamic
 └─ AdditionalInfo: dynamic
```

### Resources Function Schema

Key fields in the `Resources()` function:

```
Resources
 ├─ TimeGenerated: datetime
 ├─ SubscriptionId: string
 ├─ ResourceGroup: string
 ├─ ResourceId: string
 ├─ ResourceName: string
 ├─ ResourceType: string
 ├─ Location: string
 ├─ ProvisioningState: string
 ├─ Sku: dynamic
 ├─ Plan: dynamic
 ├─ Properties: dynamic
 ├─ Identity: dynamic
 ├─ Zones: dynamic
 ├─ Tags: dynamic
 └─ Changes: dynamic
```

## 🔧 Query Generation Guidelines

When generating KQL queries for FinOps Hub, follow these guidelines:

1. **Start with the appropriate function**:
   ```kql
   Costs()
   ```

2. **Apply time filtering early**:
   ```kql
   | where TimeGenerated >= startofmonth(ago(30d))
   | where TimeGenerated < startofmonth(now())
   ```

3. **Add data filtering**:
   ```kql
   | where SubscriptionId in ("subscription-id-1", "subscription-id-2")
   | where ResourceType startswith "Microsoft.Compute"
   ```

4. **Group and aggregate data**:
   ```kql
   | summarize TotalCost = sum(Cost) by ResourceGroup, bin(TimeGenerated, 1d)
   ```

5. **Format and enrich results**:
   ```kql
   | extend FormattedCost = strcat('$', format_number(TotalCost, 2))
   | project ResourceGroup, Date = format_datetime(TimeGenerated, 'yyyy-MM-dd'), FormattedCost
   ```

## 🔄 Schema Evolution

FinOps Hub uses versioned functions (e.g., `Costs_v1_0()`) to manage schema evolution. If backward compatibility is important for your reporting, use versioned functions to avoid disruption when the schema changes.

## 📚 Additional Resources

- [FinOps Hub Data Model Documentation](https://aka.ms/finops/hubs/data-model)
- [Kusto Query Language (KQL) Documentation](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [Azure Resource Graph Documentation](https://docs.microsoft.com/azure/governance/resource-graph/)