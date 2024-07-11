---
layout: default
title: FOCUS
has_children: true
nav_order: zzz
description: 'Cloud agnostics format for cost and usage data.'
permalink: /focus
---

<span class="fs-9 d-block mb-4">FinOps Open Cost and Usage Specification</span>
Learn about the new billing data specification that will make it easier to understand and optimize cost and usage across any cloud, SaaS, or on-prem provider.
{: .fs-6 .fw-300 }

<!--
[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#-v01){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🤔 Why FOCUS?](#-why-focus)
- [🌟 Benefits](#-benefits)
- [▶️ Getting started](#️-getting-started)
- [ℹ️ Important notes about FOCUS columns](#ℹ️-important-notes-about-focus-columns)
- [🙋‍♀️ Feedback about FOCUS columns](#️-feedback-about-focus-columns)
- [🧐 See also](#-see-also)
- [🍎 Learn more at the FinOps Foundation](#-learn-more-at-the-finops-foundation)
- [🧰 Related tools](#-related-tools)

</details>

---

The FinOps Open Cost and Usage Specification (FOCUS) is a groundbreaking initiative to define a common format for billing data that empowers organizations to better understand cost and usage patterns and optimize spending and performance across multiple cloud, SaaS, and even on-premises service offerings.

FOCUS provides organizations with a consistent, clear, and accessible view of their cost data explicitly designed for FinOps needs such as allocation, analytics, monitoring, and optimization. As the new "language" of FinOps, FOCUS enables practitioners to collaborate more efficiently and effectively with peers throughout the organization and even maximize transferability and onboarding for new team members, getting people up and running quicker. Paired with the FinOps Framework, practitioners have the tools needed to build a streamlined FinOps practice that maximizes the value of the cloud.

<br>

## 🤔 Why FOCUS?

The variety and flexibility of Microsoft cloud services allows you to build amazing things while only paying for what you need, when you need it. And with this flexibility comes varying operational models where services are billed and can be tuned differently based on a variety of factors. When services are billed differently, their cost and usage data tends to differ as well, making it challenging to allocate, analyze, monitor, and optimize consistently. Of course, this goes beyond just Microsoft’s cloud services. Organizations often rely on software as a service (SaaS) products, licensed software, on-premises infrastructure, or even other clouds, exacerbating the problem with each provider sharing data in proprietary formats.

FOCUS solves this problem by establishing a provider- and service-agnostic data specification that addresses some of the biggest challenges organizations face in managing the value of their cloud investments – understanding and quantifying the business value of their spending. FOCUS enables organizations to spend more time driving value and less struggling to understand data caused by inconsistencies between and unfamiliarity with different services and providers. But FOCUS isn't just for organizations using multiple cloud providers. FOCUS can help organizations that use one cloud provider with complementary service providers, multiple accounts within a single cloud provider, and even organizations that have a single account with a single cloud provider. The benefits from using FOCUS are wide-reaching, from streamlined operations within an enterprise to making skills as a FinOps practitioner more portable.

<br>

## 🌟 Benefits

FOCUS is the **best** version of cost and usage data you can get from Cost Management. Some of the benefits you'll see with FOCUS compared to actual and amortized cost data include:

- 💰 **Save 30% on storage and compute costs**

  > FOCUS combines actual (billed) and amortized (effective) costs in a single row, which results in 49% fewer rows compared to actual and amortized datasets together. Factoring in new FOCUS columns, the total data size is ~30% smaller than actual and amortized datasets, which is a direct savings on storage costs. You'll also save on compute costs since you'll be processing fewer rows. Exact compute savings will vary depending on your solution.

- 🔀 **Designed to handle multiple accounts and clouds**

  > Whether you're using multiple clouds or you have multiple account types in a single cloud (e.g., EA and MCA), FOCUS aligns your cost data into a single schema with consistent terminology that makes it easy to understand and optimize your costs across all your accounts. For organizations still on EA, switching to FOCUS now puts you in control of timing so you're not "offline" after your account is transitioned to MCA.

- 🍎 **Easier to learn and aligned with the FinOps Framework**

  > FOCUS is the new "language" of FinOps. All FinOps Framework guidance will be updated to use FOCUS terminology and also include FOCUS queries and examples. This will make it easier to understand and implement FinOps best practices without requiring an extra layer of translation from cloud-agnostic guidance to cloud-specific implementation details. FOCUS enables cloud-agnostic patterns and guidance to go deeper and help you accomplish more with less effort.

- 🪪 **Clean, human-readable display names**

  > FOCUS uses clean, human-readable display names for all names, types, and categories. Friendly display names are available for services, resource types, regions, pricing, commitment discounts, and more.

- 💲 **Uniquely identify the exact price-point**

  > FOCUS includes an identifier for the specific SKU price-point used for each charge (SkuPriceId). This is a unique identifier for the SKU inclusive of all pricing variations, like tiering and discounts, which is not currently available in actual or amortized datasets. Each charge also includes the unit prices you need to understand how you are or could be charged. List (or retail) unit price is what you would pay per unit without any negotiated discounts, your contracted (or on-demand) unit price is after negotiated discounts are applied, your effective (or amortized) unit price shows the conceptual price after pre-purchase commitment discounts were applied, and your billed (or actual) unit price represents what was or will be invoiced.

- 💹 **Easier to quantify cost savings**

  > In addition to unit prices, FOCUS also includes columns to identify the specific pricing model used for each charge with list, contracted, effective, and billed cost which makes it easier to quantify cost savings from negotiated and commitment discounts.

- 💎 **All prices and costs in a consistent currency**

  > FOCUS uses the billing currency for all prices and costs, which makes it easier to verify costs within the cost and usage data. Note this will differ from the prices in the native Cost Management datasets, which use the pricing currency.

- 🔡 **Organize and differentiate costs by service, resource, and SKU**

  > FOCUS clearly delineates between services, resources, and SKUs, which makes it easier to organize and differentiate costs. Service categorization is consistent across providers and offers a new perspective as it groups all resources consumed for a specific service together, regardless of the underlying product or SKU (e.g., bandwidth and compute costs both fall under the Virtual Machines service).

- 🌏 **More consistent regions**

  > The FOCUS dataset in Cost Management provides an extra layer of data cleansing to ensure regions are consistent with Azure Resource Manager. This means you'll see the same region names in FOCUS as you do in the Azure portal and Azure Resource Manager APIs.

- 📅 **Simpler date logic**

  > FOCUS uses exclusive end dates and industry standard ISO 8601 date formats for billing and charge periods, which makes it easier to filter and compare dates. This is especially useful when comparing to other dates, like the current date, since you don't have to guess about time zones or time of day.

- 🏷️ **Tags and SKU details are provided in a consistent JSON format**

  > If you have an Enterprise Agreement account, you may know that tags are not formatted as JSON in actual and amortized datasets. FOCUS fixes this by providing tags and SKU details (AdditionalInfo) in a consistent JSON format.

- 🎛️ **Identify and break usage down to discrete units**

  > FOCUS provides discrete pricing and usage units for each charge to help you understand how you're being charged compared to real-world usage units. This accounts for different pricing strategies like block pricing and makes it easier to verify pricing and usage quantities by providing data in separate columns.

<br>

## ▶️ Getting started

FOCUS 1.0 covers the resources you deployed, the internal SKUs each resource used, the type of charge, how much you used or purchased, how it was priced, and the specific:

- Billing details related to invoicing, like the provider you used, who generated the invoice (invoice issuer), and the billing period for the invoice.
- Resource details about what you deployed with the provider, like the service, resource type, region, and tags.
- SKU details about the product you used or purchased, like the publisher and SKU identifiers.
- Charge details that describe and categorize the charge, like the type, description, frequency, and amount used or purchased.
- Discount details that summarize the pricing model, like the pricing category and commitment discount details.
- Pricing and costs that include the raw details about how each charge is priced, like the pricing quantity, unit price, and cost.

Resources are identified by a **ResourceId** and **ResourceName** and organized into their respective **ServiceName** and **ServiceCategory**. **ServiceCategory** enables you to organize your costs into a top-level set of categories consistent across cloud providers, which makes it especially interesting. You can also see additional details, like a friendly **ResourceType** label, the **RegionId** and **RegionName** a resource was deployed to, and any **Tags** that were applied to the resource.

Behind the scenes, resources use one or more products to enable their core capabilities. FOCUS refers to these as SKUs. Use of these SKUs is ultimately what you are charged for. Each SKU has a **PublisherName** of the company who developed the SKU, a **SkuId** that identifies the SKU that was used, and a **SkuPriceId** that identifies the specific price-point for the SKU, inclusive of all pricing variations like tiering and discounts.

All charges include a **ChargeCategory** to describe what kind of charge it is (such as usage or purchase), **ChargeClass** that identifies corrections to previous charges, the **ChargePeriodStart** and **ChargePeriodEnd** dates the charge applied to, the **ChargeFrequency** to know how often you can expect to see this charge, and a high-level **ChargeDescription** to explain what the row represents. They also include a specific **ConsumedQuantity** and **ConsumedUnit** in distinct units based on what was used or purchased.

Each charge has a **PricingCategory** that indicates how the charge was priced and, if a commitment discount was applied, they include **CommitmentDiscountCategory** and **CommitmentDiscountType** for friendly provider-agnostic and provider-specific labels for the type of commitment discount, **CommitmentDiscountId** to identify which commitment discount was applied to usage, the **CommitmentDiscountName** of that instance, and the **CommitmentDiscountStatus** that indicates whether the charge was for the utilized (used) or unutilized (unused) portion of the commitment discount.

Since prices are determined based on the billing relationship, you can also find the **BillingAccountId** and **BillingAccountName** that invoices are generated against, the **BillingPeriodStart** and **BillingPeriodEnd** dates the invoice applies to, the **InvoiceIssuerName** for the company responsible for invoicing, and the **ProviderName** of the cloud, SaaS, on-premises, or other provider you used. Please note the "billing account" term in FOCUS refers to the scope at which an invoice is generated and not the top-level, root account. For organizations with a Microsoft Customer Agreement (MCA) account, this maps to your billing profile and not your Microsoft billing account. Within each billing account, you also have a **SubAccountId** and **SubAccountName** for the subscription within the billing account.

Last but not least you also have the price and cost details. Each charge has a **BillingCurrency** that all prices and costs use, which may be different than how the provider prices charges. As an example, most MCA accounts are priced in USD and may be billed in another currency like Yen or Euros.

<blockquote class="warning" markdown="1">
   _Please note that since FOCUS relies on the billing currency, the prices shown in FOCUS datasets may not match native Cost Management schemas._
</blockquote>

Each charge includes the **PricingQuantity** and **PricingUnit** based on how the SKU was priced (which may be in chunks or "blocks" of units) and a set of unit prices for the cost of each individual pricing unit (based on the **SkuPriceId**) and the total cost based on the pricing quantity. FOCUS includes the **ListUnitPrice** and **ListCost** for the public retail or market prices without discounts, **ContractedUnitPrice** and **ContractedCost** for prices after negotiated contractual discounts but without commitment discounts, **EffectiveCost** after commitment discount purchases have been amortized, and **BilledCost** that was or will be invoiced.

<blockquote class="important" markdown="1">
   _Perhaps the biggest difference between FOCUS and native schemas is that FOCUS combines "actual" and "amortized" cost into a single dataset. This saves you time and money with a smaller dataset size compared to managing both datasets separately. Data size is on par with the amortized cost data except with less than 100 more rows for commitment discount purchases and refunds._
</blockquote>

Beyond these, each provider can include additional columns prefixed with **x\_** to denote them as extended columns that are not part of the FOCUS schema but provide useful details about your cost and usage. Microsoft Cost Management provides the same details within its FOCUS dataset as the native schemas by utilizing this prefix. FinOps toolkit reports add to these columns with additional details to facilitate reporting and optimization goals.

<br>

## ℹ️ Important notes about FOCUS columns

Please note the following when working with FOCUS data:

1. `BillingAccountId` and `BillingAccountName` map to the billing profile ID and name for Microsoft Customer Agreement accounts.
   - We are looking for feedback about this to understand if it is a problem and determine the best way to address it.
2. `BillingPeriodEnd` and `ChargePeriodEnd` are exclusive, which is helpful for filtering.
3. `SubAccountId` and `SubAccountName` map to the subscription ID and name, respectively.
4. All FOCUS `*Id` columns (not the `x_` extension columns) use fully-qualified resource IDs.
5. `ServiceName` and `ServiceCategory` are using a custom mapping that may not account for all services yet.
   - We will update this list to account for all services soon. This will require ongoing work to keep up with the pace at which Microsoft is enabling new services.
   - Please let us know if you find any missed services or if you have any feedback about the mapping.
6. `ServiceName` uses "Azure Savings Plan for Compute" for savings plan records due to missing service details.
   - This is an underlying data issue and must be resolved by the service that generates the data.
7. `ServiceName` attempts to map Azure Kubernetes Service (AKS) charges based on a simple resource group name check, which may catch false positives.
   - We will update the resource group check to be more targeted soon.
   - Please let us know if you find any false positives.
   - If we find we are unable to accurately identify AKS charges, we will fall back to the service name for the actual resource (e.g., Load Balancer).
8. `SkuPriceId` for Microsoft Customer Agreement accounts uses "{ProductId}\_{SkuId}_{MeterType}" from the price sheet.
   - If you need to join FOCUS cost data with the price sheet, you will need to either split `SkuPriceId` or manually construct a similar key in the price sheet.

<br>

## 🙋‍♀️ Feedback about FOCUS columns

<!-- markdownlint-disable-line --> {% include focus_feedback.md %}

<br>

## 🧐 See also

- [How to convert Cost Management data to FOCUS](./convert.md)
- [How to update existing reports to FOCUS](./mapping.md)
- [Data dictionary](../../_resources/data-dictionary.md)
- [Generating a unique ID](../../_resources/data-dictionary.md#-generating-a-unique-id)
- [Known issues](../../_resources/data-dictionary.md#-known-issues)
- [Common terms](../../_resources/terms.md)

<br>

## 🍎 Learn more at the FinOps Foundation

The FinOps Open Cost and Usage Specification (FOCUS) was built in collaboration with the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FOCUS, see the [FOCUS project site](https://focus.finops.org) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/{id}?list={list}]-->
{% include video.html title="FinOps Open Cost and Usage Specification videos" id="w-RiyFpUhTSXtixI" list="PLUSCToibAswmzF4s0HHYlyoN9J9wi4Aur" %}

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
