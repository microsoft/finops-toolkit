# FinOps Open Cost and Usage Specification (FOCUS)

Learn about the new billing data specification that helps make it easier to understand and optimize cost and usage across any cloud, SaaS, or on-premises provider.

## What is FOCUS?

The FinOps Open Cost and Usage Specification (FOCUS) is a groundbreaking initiative to define a common format for billing data. It empowers organizations to better understand cost and usage patterns and optimize spending and performance across multiple cloud, SaaS, and even on-premises service offerings.

FOCUS provides organizations with a consistent, clear, and accessible view of their cost data explicitly designed for FinOps needs such as allocation, analytics, monitoring, and optimization. As the new "language" of FinOps, FOCUS enables practitioners to collaborate more efficiently and effectively with peers throughout the organization. It helps maximize transferability and onboarding for new team members, getting people up and running quicker. When paired with the FinOps Framework, practitioners have the tools needed to build a streamlined FinOps practice that maximizes the value of the cloud.

## Using FOCUS in Azure

For a comprehensive reference of all available datasets, including the schema for current and historical versions, see [Cost Management dataset schema index](/en-us/azure/cost-management-billing/dataset-schema/schema-index).

When working with Cost Management exports, you can select:

- **Cost and usage details (FOCUS)** - Export cost and usage details using the open-source FinOps Open Cost and Usage Specification (FOCUS) format. It combines actual and amortized costs.
  - This format reduces data processing time and storage and compute charges for exports.
  - The management group scope isn't supported for Cost and usage details (FOCUS) exports.
  - You can use the FOCUS-formatted export as the input for a Microsoft Fabric workspace for FinOps.

## FOCUS Dataset Metadata

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

## Benefits of Using FOCUS

1. **Standardization**: Common format across different cloud providers makes analysis easier
2. **Efficiency**: Reduced data processing time and storage requirements
3. **Integration**: Works seamlessly with FinOps tools like FinOps hubs
4. **Flexibility**: Can be used with various analytics platforms including Microsoft Fabric

---

_Source: [Microsoft Learn - What is FOCUS?](https://learn.microsoft.com/en-us/cloud-computing/finops/focus/what-is-focus)_
