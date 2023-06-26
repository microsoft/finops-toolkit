# 📊 Cost summary report

The **Cost summary report** provides an overview of amortized costs with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Build a chargeback report.
- Summarize cost savings from negotiated and commitment-based discounts.

> 🚩 **Important**<br>FinOps hubs use [amortized costs](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-amortization). Amortization breaks reservation and savings plan purchases down and allocates costs to the resources that received the benefit. Due to this, amortized costs will not show purchase costs and will not match your invoice. Please use [Cost Management](https://aka.ms/costmgmt) to review invoice charges.

On this page:

- [Common page layout](#common-page-layout)
- [Get started](#get-started)
- [Summary](#summary)
- [Services](#services)
- [Subscriptions](#subscriptions)
- [Resource groups](#resource-groups)
- [Resources](#resources)
- [Commitments](#commitments)
- [Hybrid Benefit](#hybrid-benefit)
- [FOCUS](#focus)
- [See also](#see-also)

---

## Common page layout

Most report pages follow a standard layout with filters, summary numbers (or KPIs), a chart, and table.

### Filters

- Date range
- Subscription
- Resource group
- Commitment (e.g., reservation, savings plan)
- Service/Tier (meter category/subcategory)
- Currency

Note the currency must be single-select to ensure costs in different currencies aren't mixed.

### Key performance indicators (KPIs)

- Amortized cost
- Discount savings

Both numbers represent the sum for the entire period.

### Chart

The chart shows daily cost for the period. Each page breaks the costs down by a different attribute.

### Table

The table shows a breakdown of the cost, usually with columns for the months. The table differs on each page.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

![Screenshot of the Get started page](https://user-images.githubusercontent.com/399533/216882617-5f5f5590-d2f8-4f55-923f-b77a39c4eb0b.png)

<br>

## Summary

The **Summary** page shows the running total (or accumulated cost) for the selected period. This is helpful in determining what your cost trends are.

The page uses the standard layout with cost, negotiated discount savings, and commitment-based discount savings in the chart and the subscription hierarchy with resource groups and resources in the table.

![Screenshot of the Summary page](https://user-images.githubusercontent.com/399533/216882658-45f026f1-c895-48ca-81e2-35765af8e29e.png)

<br>

## Services

The **Services** page offers a breakdown of cost by service. This is useful for determining how service usage changes over time at a high level, usually across multiple subscriptions or the entire billing account.

The page uses the standard layout with a breakdown of services (meter category) in the chart and table. The table has a further breakdown by tier (meter subcategory), meter, and product.

![Screenshot of the Services page](https://user-images.githubusercontent.com/399533/216882700-4e04b589-0580-4e49-9b40-9f5948792975.png)

<br>

## Subscriptions

The **Subscriptions** page includes a breakdown of cost by subscription. This is useful for building a chargeback report and determining which departments/teams/environments (depending on how you use subscriptions) are accruing the most cost.

The page uses the standard layout with a breakdown of subscriptions in the chart and table. The table has a further breakdown by resource group and resource.

![Screenshot of the Subscriptions page](https://user-images.githubusercontent.com/399533/217999411-6494c982-9e11-4cfa-b58b-1ddb566e5b5f.png)

<br>

## Resource groups

The **Resource groups** page includes a breakdown of cost by resource group. This is useful for building a chargeback report and determining which teams/projects (depending on how you use resource groups) are accruing the most cost.

The page uses the standard layout with a breakdown of resource groups in the chart and table. The table has a further breakdown by resource.

![Screenshot of the Resource groups page](https://user-images.githubusercontent.com/399533/217999483-f0e7c64b-a046-41b3-a8e0-8487bf4375b4.png)

<br>

## Resources

The **Resources** page includes a breakdown of cost by resource. This is useful for determining which resources are accruing the most cost.

The page uses the standard layout with a breakdown of resources in the chart and table. Instead of a hierarchy, The table includes columns about the resource location, resource group, subscription, and tags.

![Screenshot of the Resources page](https://user-images.githubusercontent.com/399533/216882840-ca908024-84f6-4930-b44c-9eeca6add758.png)

<br>

## Commitments

<!-- NOTE: This page is duplicated in the commitment-discounts.md. Please keep both updated at the same time. -->

The **Commitments** page serves 3 primary purposes:

1. Determine if there are any under-utilized commitments.
2. Facilitate chargeback at a subscription, resource group, or resource level.
3. Summarize cost savings obtained from commitment-based discounts.

This page uses the standard layout with a breakdown of commitment-based discounts in the chart and table.

In addition to cost and savings KPIs, there is also a utilization KPI for the amount of commitment-based discounts that have been utilized during the period. Low utilization will result in lost savings potential, so this number is one of the most important KPIs on the page.

The chart breaks down the cost of used (utilized) vs. unused charges. Unused charges are split out by commitment type (e.g., reservation, savings plan).

The table shows resource usage against commitment-based discounts with columns for resource name, resource group, subscription, and commitment. Use the table for chargeback and savings calculations.

This page filters usage down to only show charges related to commitment-based discounts, which means the total cost on the Commitments page won't match other pages, which aren't filtered by default.

![Screenshot of the Commitment-based discounts page](https://user-images.githubusercontent.com/399533/216882916-bb7ecfa3-d092-4ae2-88e1-7a0425c14dca.png)

<br>

## Hybrid Benefit

<!-- NOTE: This page is duplicated in the commitment-discounts.md. Please keep both updated at the same time. -->

The **Hybrid Benefit** page shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs). The page uses the standard filters, but differs with the other sections.

Instead of cost KPIs, the page shows how many VMs are currently enabled and how many vCPUs are used.

There are 3 charts on the page:

1. SKU names and number of VMs currently using less than 8 vCPUs. These are under-utilizing AHB.
2. SKU names and number of VMs with 8+ vCPUs that are not currently using AHB.
3. Daily breakdown of AHB and non-AHB usage (excluding those where AHB is not supported).

The table shows a list of VMs that are currently using or could be using AHB with their vCPU count, AHB vCPU count, resource group, subscription, cost and quantity.

![Screenshot of the Hybrid Benefit page](https://user-images.githubusercontent.com/399533/216882954-a83d0c8a-fe6d-4d55-8e8b-45b3df3914a9.png)

<br>

## FOCUS

The **FOCUS** page transforms the amortized cost data into the FinOps Open Cost and Usage Specification (FOCUS) schema. This is an early preview to demonstrate the FOCUS schema and elicit feedback. Not all aspects of FOCUS have been fully accounted for. Please see the details below.

The following changes were made to a new `FOCUS_0.5` table to align to the FOCUS schema:

| FOCUS column                                                                                                                                                | CostDetails column        | Notes                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| [`AmortizedCost`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/metrics/amortizedcost.md)              | `CostInBillingCurrency`   |
| [`AvailabilityZone`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/availabilityzone.md)     | `NULL` (empty)            | Not provided in Azure usage data.                                                                                                  |
| [`BilledCost`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/metrics/billedcost.md)                    | `CostInBillingCurrency`   | ⚠️ Only includes usage and Marketplace purchases. Reservation and savings plan purchases are not included.                         |
| [`BillingAccountId`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/billingaccountid.md)     | `BillingProfileId`        | Represents the invoice scope, which is the billing profile in Microsoft cost details.                                              |
| [`BillingAccountName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/billingaccountname.md) | `BillingProfileName`      | Represents the invoice scope, which is the billing profile in Microsoft cost details.                                              |
| [`BillingCurrency`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/billingcurrency.md)       | `BillingCurrencyCode`     |
| `BillingPeriod`                                                                                                                                             | (Derived)                 | Not an official FOCUS column. Derived from `BillingPeriodStart` for reporting purposes only.                                       |
| [`BillingPeriodEnd`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/billingperiodend.md)     | `BillingPeriodEndDate+1d` | FOCUS end dates are exclusive, meaning they are set to the start of the next period.                                               |
| [`BillingPeriodStart`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/billingperiodstart.md) | `BillingPeriodStartDate`  |
| `ChargePeriod`                                                                                                                                              | (Derived)                 | Not an official FOCUS column. Derived from `ChargePeriodStart` and `ChargePeriodEnd` for reporting purposes only.                  |
| [`ChargePeriodEnd`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/chargeperiodend.md)       | `Date+1d`                 | FOCUS end dates are exclusive, meaning they are set to the start of the next period.                                               |
| [`ChargePeriodStart`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/chargeperiodstart.md)   | `Date`                    |
| [`ChargeType`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/chargetype.md)                 | `ChargeType`              | `UnusedReservation` and `UnusedSavingsPlan` are returned as `Usage`. `Refund` is returned as `Adjustment`.                         |
| [`InvoiceIssuer`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/invoiceissuer.md)           | `"Microsoft"`             | Currently hard-coded.                                                                                                              |
| [`ProviderName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/provider.md)                 | `"Microsoft"`             | Currently hard-coded.                                                                                                              |
| [`PublisherName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/publisher.md)               | `PublisherName`           | If `PublisherName` is empty and `PublisherType` is `"Azure"`, `"Microsoft"` is used; otherwise, the `PublisherType` value is used. |
| [`Region`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/region.md)                         | `ResourceLocation`        | `"All regions"` and Microsoft Defender values are changed to `Global` for consistency.                                             |
| [`ResourceId`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/resourceid.md)                 | `ResourceId`              |
| [`ResourceName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/resourceid.md)               | `ResourceName`            |
| [`ServiceCategory`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/servicecategory.md)       | (Derived)                 | Value derived from a custom mapping from `ServiceName` and `ftk_ConsumedService`.                                                  |
| [`ServiceName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/servicename.md)               | (Derived)                 | Value derived from a custom mapping from `ftk_ProductName`, `ftk_ConsumedService`, and `ftk_MeterCategory`.                        |
| [`SubAccountId`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/subaccountid.md)             | `SubscriptionId`          |
| [`SubAccountName`](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/candidate_release/specification/dimensions/subaccountname.md)         | `SubscriptionName`        |
| `SubAccountNameUnique`                                                                                                                                      | (Derived)                 | Not an official FOCUS column. Derived from `SubAccountName` and `SubAccountId` for reporting purposes only.                        |
| `ftk_(ColumnName)`                                                                                                                                          | (Remaining columns)       | Not an official FOCUS column. Added a prefix to keep existing columns, but clearly denote them as separate.                        |

A few open issues we've identified:

1. `BilledCost` is missing reservation and savings plan purchases and cannot be used for invoice reconciliation.
   - FinOps hubs v0.0.1 only supports amortized cost data. Support for actual (billed) cost data will be added in a future release.
2. `BillingAccountId` and `BillingAccountName` may be confusing for Microsoft Customer Agreement accounts, where the billing profile is used.
   - We are looking for feedback about this to understand if it is a problem and determine the best way to address it.
3. `BillingPeriodEnd` and `ChargePeriodEnd` are exclusive, which is ideal for filtering, but may be confusing.
   - We are looking for feedback about this to understand if it is a problem and determine the best way to address it.
4. `ChargeType` is missing support for unused commitments. This will be accounted for by FOCUS 1.0.
5. `InvoiceIssuer` is not accounting for Cloud Solution Provider partners.
   - FinOps hubs v0.0.1 only supports Enterprise Agreement accounts. Support for Microsoft Customer Agreement and Microsoft Partner Agreement accounts will be added in a future release.
6. `Region` can include values that are not regions, such as `Unassigned`.
   - This is an underlying service issue and must be resolved by the service that is referencing invalid Azure locations in their usage data.
7. `Region` uses `Global` to indicate a global service.
   - FOCUS is considering whether to use `Global` or not. This will be finalized by FOCUS 1.0.
8. `ServiceName` and `ServiceCategory` are using a custom mapping that may not account for all services yet.
   - We will update this list to account for all services soon. This will require ongoing work to keep up with the pace at which Microsoft is enabling new services.
   - Please let us know if you find any missed services or if you have any feedback about the mapping.
9. `ServiceName` uses `Azure Savings Plan for Compute` for savings plan records due to missing service details.
   - This is an underlying data issue and must be resolved by the service that generates the data.
10. `ServiceName` attempts to map Azure Kubernetes Service (AKS) charges based on a simple resource group name check, which may catch false positives.
    - We will update the resource group check to be more targeted soon.
    - Please let us know if you find any false positives.
    - If we find we are unable to accurately identify AKS charges, we will fall back to the service name for the actual resource (e.g., Load Balancer).
11. `ftk_` prefix is not part of the specification.
    - FOCUS is considering whether to prefix custom columns or standard columns. This will be accounted for by FOCUS 1.0.
    - Please let us know if you have any feedback about this.

If you have feedback about our mappings or about our full FOCUS support plans, please leave a comment within the [FOCUS schema release discussion](https://github.com/microsoft/finops-toolkit/discussions/61). If you believe you've found a bug, please [create an issue](https://github.com/microsoft/finops-toolkit/issues/new/choose).

If you have feedback about FOCUS, please consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make this the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## See also

- [Power BI ideas and suggestions](https://github.com/microsoft/cloud-hubs/issues?q=is%3Aissue+is%3Aopen+label%3A%22Area%3A+Power+BI%22)
- [Common terms](./terms.md)
