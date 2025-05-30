---
title: What is FOCUS?
description: Learn about FOCUS, a cloud-agnostic billing data specification that helps optimize cost and usage across cloud, SaaS, and on-premises providers.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: overview
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FOCUS is and how it can help me optimize cost and usage across various cloud, SaaS, and on-premises providers.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps Open Cost and Usage Specification

Learn about the new billing data specification that helps make it easier to understand and optimize cost and usage across any cloud, SaaS, or on-premises provider.

<br>

## What is FOCUS?

The FinOps Open Cost and Usage Specification (FOCUS) is a groundbreaking initiative to define a common format for billing data. It empowers organizations to better understand cost and usage patterns and optimize spending and performance across multiple cloud, SaaS, and even on-premises service offerings.

FOCUS provides organizations with a consistent, clear, and accessible view of their cost data explicitly designed for FinOps needs such as allocation, analytics, monitoring, and optimization. As the new "language" of FinOps, FOCUS enables practitioners to collaborate more efficiently and effectively with peers throughout the organization. It helps maximize transferability and onboarding for new team members, getting people up and running quicker. When paired with the FinOps Framework, practitioners have the tools needed to build a streamlined FinOps practice that maximizes the value of the cloud.

<br>

## Why FOCUS?

The variety and flexibility of Microsoft cloud services allows you to build amazing things while only paying for what you need, when you need it. And with this flexibility comes varying operational models where services are billed and can be tuned differently based on various factors. When services are billed differently, their cost and usage data tends to differ as well. It makes it challenging to allocate, analyze, monitor, and optimize consistently. It goes beyond just Microsoft’s cloud services. Organizations often rely on software as a service (SaaS) products, licensed software, on-premises infrastructure, or even other clouds. That reliance exacerbates the problem with each provider sharing data in proprietary formats.

FOCUS solves this problem by establishing a provider- and service-agnostic data specification that addresses some of the biggest challenges organizations face in managing the value of their cloud investments – understanding and quantifying the business value of their spending. FOCUS enables organizations to spend more time driving value and less struggling to understand data caused by inconsistencies between and unfamiliarity with different services and providers. But FOCUS isn't just for organizations using multiple cloud providers.

FOCUS can assist organizations that:

- Use a single cloud provider along with complementary service providers.
- Have multiple accounts within one cloud provider.
- Have just one account with a single cloud provider.

The benefits of using FOCUS are wide-reaching, from streamlined operations within an enterprise to making skills as a FinOps practitioner more portable.

<br>

## Benefits

FOCUS is the **best** version of cost and usage data you can get from Cost Management. Some of the benefits you see with FOCUS compared to actual and amortized cost data include:

<!-- markdownlint-disable MD036 -->

**Save 30% on storage and compute costs**

- FOCUS combines actual (billed) and amortized (effective) costs in a single row, which results in 49% fewer rows compared to actual and amortized datasets together. When you consider the new FOCUS columns, the total data size is ~30% smaller than actual and amortized datasets, which is a direct savings on storage costs. You also save on compute costs since fewer rows get processed. Exact compute savings vary, depending on your solution.

**Designed to handle multiple accounts and clouds**

- If you use multiple clouds or have different account types within a single cloud (like EA and MCA), FOCUS standardizes your cost data into a single schema with consistent terminology. It helps to understand and optimize your costs across all your accounts. For organizations still on EA, switching to FOCUS now puts you in control of timing so you're not "offline" after your account is transitioned to MCA.

**Easier to learn and aligned with the FinOps Framework**

- FOCUS is the new "language" of FinOps. All FinOps Framework guidance is updated to use FOCUS terminology and also include FOCUS queries and examples. FOCUS makes it easier to understand and implement FinOps best practices without requiring an extra layer of translation from cloud-agnostic guidance to cloud-specific implementation details. FOCUS enables cloud-agnostic patterns and guidance to go deeper and help you accomplish more with less effort.

**Clean, human-readable display names**

- FOCUS uses clean, human-readable display names for all names, types, and categories. Friendly display names are available for services, resource types, regions, pricing, commitment discounts, and more.

**Uniquely identify the exact price-point**

- FOCUS includes an identifier for the specific SKU price-point used for each charge (SkuPriceId). It's a unique identifier for the SKU inclusive of all pricing variations, like tiering and discounts, which isn't currently available in actual or amortized datasets. Each charge also includes the unit prices you need to understand how you get or how you might be charged. List (or retail) unit price is what you would pay per unit without any negotiated discounts. Your contracted (or on-demand) unit price is after negotiated discounts are applied. Your effective (or amortized) unit price shows the conceptual price after prepurchase commitment discounts were applied. Your billed (or actual) unit price represents what was or what gets invoiced.

**Easier to quantify cost savings**

- In addition to unit prices, FOCUS also includes columns to identify the specific pricing model used for each charge with list, contracted, effective, and billed cost which makes it easier to quantify cost savings from negotiated and commitment discounts.

**All prices and costs in a consistent currency**

- FOCUS uses the billing currency for all prices and costs, which makes it easier to verify costs within the cost and usage data. It differs from the prices in the native Cost Management datasets, which use the pricing currency.

**Organize and differentiate costs by service, resource, and SKU**

- FOCUS clearly delineates between services, resources, and SKUs, which makes it easier to organize and differentiate costs. Service categorization is consistent across providers and offers a new perspective as it groups all resources consumed for a specific service together, regardless of the underlying product or SKU (for example, bandwidth and compute costs both fall under the Virtual Machines service).

**More consistent regions**

- The FOCUS dataset in Cost Management provides an extra layer of data cleansing to ensure regions are consistent with Azure Resource Manager. This means you see the same region names in FOCUS as you do in the Azure portal and Azure Resource Manager APIs.

**Simpler date logic**

- FOCUS uses exclusive end dates and industry standard ISO 8601 date formats for billing and charge periods. It helps make it easier to filter and compare dates. It's especially useful when comparing to other dates, like the current date, since you don't have to guess about time zones or time of day.

**Tags and SKU details are provided in a consistent JSON format**

- If you have an Enterprise Agreement account, you might know that tags aren't formatted as JSON in actual and amortized datasets. FOCUS fixes this issue by providing tags and SKU details (`AdditionalInfo`) in a consistent JSON format.

**Identify and break usage down to discrete units**

- FOCUS provides discrete pricing and usage units for each charge to help you understand how you're being charged compared to real-world usage units. It accounts for different pricing strategies like block pricing and makes it easier to verify pricing and usage quantities by providing data in separate columns.

<br>

## Get started

FOCUS 1.0 covers:

- **Billing details** related to invoicing, like the provider you used, who generated the invoice (invoice issuer), and the billing period for the invoice.
- **Resource details** about what you deployed with the provider, like the service, resource type, region, and tags.
- **SKU details** about the product you used or purchased, like the publisher and SKU identifiers.
- **Charge details** that describe and categorize the charge, like the type, description, frequency, and amount used or purchased.
- **Discount details** that summarize the pricing model, like the pricing category and commitment discount details.
- **Pricing and costs** that include the raw details about how each charge is priced, like the pricing quantity, unit price, and cost.

Resources are identified by a **ResourceId** and **ResourceName** and organized into their respective **ServiceName** and **ServiceCategory**. **ServiceCategory** enables you to organize your costs into a top-level set of categories consistent across cloud providers, which makes it especially interesting. You can also see other details, like a friendly **ResourceType** label, the **RegionId** and **RegionName** a resource was deployed to, and any **Tags** that were applied to the resource.

Behind the scenes, resources use one or more products to enable their core capabilities. FOCUS refers to them as SKUs. Use of these SKUs is ultimately what you are charged for. Each SKU has a **PublisherName** of the company who developed the SKU, a **SkuId** that identifies the SKU that got used, and a **SkuPriceId** that identifies the specific price-point for the SKU, inclusive of all pricing variations like tiering and discounts.

All charges include a **ChargeCategory** to describe what kind of charge it is (such as usage or purchase), **ChargeClass** that identifies corrections to previous charges, the **ChargePeriodStart**, and **ChargePeriodEnd** dates the charge applied to, the **ChargeFrequency** to know how often you can expect to see this charge, and a high-level **ChargeDescription** to explain what the row represents. They also include a specific **ConsumedQuantity** and **ConsumedUnit** in distinct units based on what got used or purchased.

Each charge has a **PricingCategory** that indicates how the charge was priced and, if a commitment discount was applied, they include **CommitmentDiscountCategory** and **CommitmentDiscountType** for friendly provider-agnostic and provider-specific labels for the type of commitment discount, **CommitmentDiscountId** to identify which commitment discount was applied to usage, the **CommitmentDiscountName** of that instance, and the **CommitmentDiscountStatus** that indicates whether the charge was for the utilized (used) or unutilized (unused) portion of the commitment discount.

Since prices are determined based on the billing relationship, you can also find the **BillingAccountId** and **BillingAccountName** that invoices are generated against, the **BillingPeriodStart** and **BillingPeriodEnd** dates the invoice applies to, the **InvoiceIssuerName** for the company responsible for invoicing, and the **ProviderName** of the cloud, SaaS, on-premises, or other provider you used. Note the "billing account" term in FOCUS refers to the scope at which an invoice is generated and not the top-level, root account. For organizations with a Microsoft Customer Agreement (MCA) account, it maps to your billing profile and not your Microsoft billing account. Within each billing account, you also have a **SubAccountId** and **SubAccountName** for the subscription within the billing account.

Last but not least you also have the price and cost details. Each charge has a **BillingCurrency** that all prices and costs use, which might differ from how the provider prices charges. As an example, most MCA accounts are priced in USD and might get billed in another currency like Yen or Euros.

Each charge includes the **PricingQuantity** and **PricingUnit** based on how the SKU was priced (which could be in chunks or "blocks" of units) and a set of unit prices for the cost of each individual pricing unit (based on the **SkuPriceId**) and the total cost based on the pricing quantity. FOCUS includes the **ListUnitPrice** and **ListCost** for the public retail or market prices without discounts, **ContractedUnitPrice**, and **ContractedCost** for prices after negotiated contractual discounts but without commitment discounts, **EffectiveCost** after commitment discount purchases were amortized, and **BilledCost** that was or will be invoiced.

Beyond these points, each provider can include more columns prefixed with **x\_** to denote them as extended columns that aren't part of the FOCUS schema but provide useful details about your cost and usage. Microsoft Cost Management provides the same details within its FOCUS dataset as the native schemas by utilizing this prefix. FinOps toolkit reports add to the columns with more details to facilitate reporting and optimization goals.

<br>

## Learning FOCUS blog series

If you're interested in a more thorough walkthrough of all the FOCUS columns, check out the Learning FOCUS blog series on the FinOps blog:

- [Introduction](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-introducing-an-open-billing-data-format/4321609)
- [Cost columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-cost-columns/4352713)
- [Charge types and pricing models](https://techcommunity.microsoft.com/blog/FinOpsBlog/learning-focus-charge-types-and-pricing-models/4357997)
- [Date columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-date-columns/4366382)
- [Resource columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-resource-columns/4372954)
- [Service columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-service-columns/4388703)
- [SKU columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-skus/4398881)
- [Purchase columns](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-purchases/4404283)
- [Commitment discounts](https://techcommunity.microsoft.com/blog/finopsblog/learning-focus-commitment-discounts/4411405)

New blog posts are released periodically, so watch the [FinOps blog](https://aka.ms/finops/blog) for updates every couple of weeks.

<br>

## Important notes about FOCUS columns

Note the following points when working with FOCUS data:

- FOCUS relies on the billing currency for all prices and costs while Cost Management uses the pricing currency. Prices in FOCUS might be in a different currency than native Cost Management schemas.
- FOCUS combines "actual" and "amortized" cost into a single dataset. It produces a smaller dataset compared to managing both datasets separately. Data size is on par with the amortized cost data plus any commitment discount purchases and refunds.
- `BillingAccountId` and `BillingAccountName` map to the billing profile ID and name for Microsoft Customer Agreement accounts.
  - We're looking for feedback about it to understand if it's a problem and determine the best way to address it.
- `BillingPeriodEnd` and `ChargePeriodEnd` are exclusive, which is helpful for filtering.
- `SubAccountId` and `SubAccountName` map to the subscription ID and name, respectively.
- All FOCUS `*Id` columns (not the `x_` extension columns) use fully qualified resource IDs.
- `ServiceName` and `ServiceCategory` are using a custom mapping that might not account for all services yet.
  - We're working on updating this list to account for all services. It requires ongoing work to keep up with the pace at which Microsoft is enabling new services.
  - Let us know if you find any missed services or if you have any feedback about the mapping.
- `ServiceName` uses "Azure Savings Plan for Compute" for savings plan records due to missing service details.
  - It's an underlying data issue and must get resolved by the service that generates the data.
- `ServiceName` attempts to map Azure Kubernetes Service (AKS) charges based on a simple resource group name check, which might catch false positives.
  - We're working on updating the resource group check to be more targeted.
  - Let us know if you find any false positives.
  - If we find we're unable to accurately identify AKS charges, we expect to fall back to the service name for the actual resource (for example, Load Balancer).
- `SkuPriceId` for Microsoft Customer Agreement accounts uses "{ProductId}\_{SkuId}_{MeterType}" from the price sheet.
  - If you need to join FOCUS cost data with the price sheet, you can either split `SkuPriceId` or manually construct a similar key in the price sheet.

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Learn more at the FinOps Foundation

The FinOps Open Cost and Usage Specification (FOCUS) was built in collaboration with the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FOCUS, see the [FOCUS project site](https://focus.finops.org) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/w-RiyFpUhTSXtixI?list=PLUSCToibAswmzF4s0HHYlyoN9J9wi4Aur]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.FOCUS/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [How to convert Cost Management data to FOCUS](convert.md)
- [How to update existing reports to FOCUS](mapping.md)
- [Microsoft Cost Management FOCUS dataset](/azure/cost-management-billing/dataset-schema/cost-usage-details-focus)
- [FinOps toolkit data dictionary](../toolkit/help/data-dictionary.md)
- [Generating a unique ID](../toolkit/help/data-dictionary.md#generating-a-unique-id)
- [FinOps toolkit common terms](../toolkit/help/terms.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../toolkit/powershell/powershell-commands.md)

<br>
