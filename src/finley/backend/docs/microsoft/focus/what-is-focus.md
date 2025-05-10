# FinOps Open Cost and Usage Specification (FOCUS) Overview

The FinOps Open Cost and Usage Specification (FOCUS) is a groundbreaking initiative to define a common format for billing data. It empowers organizations to better understand cost and usage patterns and optimize spending and performance across multiple cloud, SaaS, and even on-premises service offerings.

## Benefits

FOCUS is the **best** version of cost and usage data you can get from Cost Management. Some of the benefits you see with FOCUS compared to actual and amortized cost data include:

### Save 30% on storage and compute costs

FOCUS combines actual (billed) and amortized (effective) costs in a single row, which results in 49% fewer rows compared to actual and amortized datasets together. When you consider the new FOCUS columns, the total data size is ~30% smaller than actual and amortized datasets, which is a direct savings on storage costs. You also save on compute costs since fewer rows get processed. Exact compute savings vary, depending on your solution.

### Designed to handle multiple accounts and clouds

If you use multiple clouds or have different account types within a single cloud (like EA and MCA), FOCUS standardizes your cost data into a single schema with consistent terminology. It helps to understand and optimize your costs across all your accounts. For organizations still on EA, switching to FOCUS now puts you in control of timing so you're not "offline" after your account is transitioned to MCA.

### Easier to learn and aligned with the FinOps Framework

FOCUS is the new "language" of FinOps. All FinOps Framework guidance is updated to use FOCUS terminology and also include FOCUS queries and examples. FOCUS makes it easier to understand and implement FinOps best practices without requiring an extra layer of translation from cloud-agnostic guidance to cloud-specific implementation details. FOCUS enables cloud-agnostic patterns and guidance to go deeper and help you accomplish more with less effort.

### Clean, human-readable display names

FOCUS uses clean, human-readable display names for all names, types, and categories. Friendly display names are available for services, resource types, regions, pricing, commitment discounts, and more.

## Important Notes About FOCUS Columns

Note the following points when working with FOCUS data:

1. FOCUS relies on the billing currency for all prices and costs while Cost Management uses the pricing currency. Prices in FOCUS might be in a different currency than native Cost Management schemas.

2. FOCUS combines "actual" and "amortized" cost into a single dataset. It produces a smaller dataset compared to managing both datasets separately. Data size is on par with the amortized cost data plus any commitment discount purchases and refunds.

3. `BillingAccountId` and `BillingAccountName` map to the billing profile ID and name for Microsoft Customer Agreement accounts.

4. `BillingPeriodEnd` and `ChargePeriodEnd` are exclusive, which is helpful for filtering.

5. `SubAccountId` and `SubAccountName` map to the subscription ID and name, respectively.

6. All FOCUS `*Id` columns (not the `x_` extension columns) use fully qualified resource IDs.

7. `ServiceName` and `ServiceCategory` are using a custom mapping that might not account for all services yet.

8. `ServiceName` uses "Azure Savings Plan for Compute" for savings plan records due to missing service details.

9. `ServiceName` attempts to map Azure Kubernetes Service (AKS) charges based on a simple resource group name check, which might catch false positives.

10. `SkuPriceId` for Microsoft Customer Agreement accounts uses "{ProductId}_{SkuId}_{MeterType}" from the price sheet.

## Dataset Metadata

Given each dataset uses different columns and data types, FOCUS defines the metadata schema to describe the dataset. Dataset metadata includes general information about the data like the data generator, schema version, and columns included in the dataset.

Sample data:

| ColumnName | DataType | Description |
| --- | --- | --- |
| `BilledCost` | Decimal | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring). |
| `BillingAccountId` | String | Unique identifier assigned to a billing account by the provider. |
| `BillingAccountName` | String | Display name assigned to a billing account. |
| `BillingCurrency` | String | Currency that a charge was billed in. |
| `BillingPeriodEnd` | DateTime | End date and time of the billing period. |
| `BillingPeriodStart` | DateTime | Beginning date and time of the billing period. |

## Using FOCUS in Azure

For a comprehensive reference of all available datasets, including the schema for current and historical versions, see [Cost Management dataset schema index](https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/schema-index).

When exporting data from Cost Management, select **Cost and usage details (FOCUS)** to export cost and usage details using the FOCUS format. This combines actual and amortized costs in a single dataset.

Note that:
- This format reduces data processing time and storage and compute charges for exports.
- The management group scope isn't supported for Cost and usage details (FOCUS) exports.
- You can use the FOCUS-formatted export as the input for a Microsoft Fabric workspace for FinOps.

FOCUS data is also fully supported in [FinOps hubs](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/finops-hubs-overview), providing many additional benefits for advanced analytics and reporting.

---

_Source: [Microsoft Learn - What is FOCUS?](https://learn.microsoft.com/en-us/cloud-computing/finops/focus/what-is-focus)_
