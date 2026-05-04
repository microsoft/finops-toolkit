# Introducing non-breaking "breaking" changes in FinOps hubs 12

_Published: 2025-08-05 · [Original post](https://techcommunity.microsoft.com/blog/finopsblog/introducing-non-breaking-%E2%80%9Cbreaking%E2%80%9D-changes-in-finops-hubs-12/4438554)_

Before I explain this, I want to say that I'm extremely excited about this update. FinOps hubs was designed to solve a common versioning challenge many organizations face where they need data coming from new columns but can't update because of breaking changes in other columns. FinOps hubs solves this by introducing these breaking changes in a non-breaking way, giving you the control and flexibility to update when and where you need while leaving your foundational reports and integration points untouched and running just as smoothly as before.

FinOps hubs 12 is the first release to fully realize the value of this non-breaking, "breaking" changes approach since the architecture was established late last year. This approach ensures the FinOps hubs platform will not break reports, will not stagnate with historical baggage, and will also avoid getting bloated with duplicate columns and data, like you might see in certain Cost and Usage Reports out there. But let me take a step back and walk you through it…

## How schema versioning works in FinOps hubs

FinOps hubs 0.7 added a custom, FOCUS-aligned schema for all supported datasets. When data is ingested into FinOps hubs with Azure Data Explorer or Microsoft Fabric, the native schemas are transformed into a FOCUS-like dataset to provide forward-looking datasets aligned to the future direction of FinOps across the industry. The data is also augmented to with extra columns and missing data to facilitate common FinOps tasks and goals we hear from organizations big and small. We refer to this as the v1_0 schema because all our tables and functions are named *_v1_0 to be clear about what schema version they use.

Some of you may be using the non-versioned functions, like Costs and Prices. These are wrappers around the corresponding versioned functions, like Costs_v1_0 and Prices_v1_0. The non-versioned functions are for ad-hoc use when you need a quick answer and don't want to think about what version you need. These always return the latest version. And until FinOps hubs 12, this was always v1_0.

Now, FinOps hubs 12 includes a new v1_2 dataset that aligns to FOCUS 1.2 and includes even more augmented columns to support new scenarios. This gives you three options when querying the system. Let's use cost as an example:

- **Costs** is that ad-hoc function where you don't have to think about what version you need. This now uses the v1_2 schema.
- **Costs_v1_0** is the original FOCUS 1.0 schema that was implemented in FinOps hubs 0.7. This has not changed and will not change.
- **Costs_v1_2** is the new schema that aligns to FOCUS 1.2 and includes additional columns to support other scenarios like commitment discount utilization, Azure Hybrid Benefit analysis, and more.

If you followed our guidance, then your reports, dashboards, and integration points should all use the versioned functions, like Costs_v1_0. In that case, upgrading to FinOps hubs 12 shouldn't impact you at all. All your reports and dashboards will continue to function as they have before. If you find you used non-versioned functions, like Costs, simply change to the versioned functions and you should revert back to the same behavior you were seeing before.

## Working with older FOCUS exports

Microsoft Cost Management has four different dataset versions for their FOCUS exports:

- **1.0-preview(v1)** is aligned to FOCUS 1.0 preview from November 2023. This was the first public release.
- **1.0** is fundamentally the same as 1.0-preview(v1) except with changes in the official FOCUS columns to align to the FOCUS 1.0 GA.
- **1.0r2** is the same as 1.0 except the date columns, like ChargePeriodStart and ChargePeriodEnd, are formatted with seconds. That's it. Older versions use "2025-01-01T00:00" and 1.0r2 going forward use "2025-01-01T00:00:00". The only difference is the added ":00" to support some systems which weren't able to parse dates without seconds.
- **1.2-preview** is aligned to FOCUS 1.2, except there are a few gaps that have not been filled, so it's flagged as a preview. Once those gaps are filled, you'll see a new "1.2" release.

FinOps hubs can work with any of these versions. When you export an older version of the data, FinOps hubs simply transforms it to the latest schema version. This means, if you're working on top of a 1.0-preview(v1) export, that data will now be fully converted to FOCUS 1.2, even if Cost Management didn't provide the new columns. If you're still using the v1_0 schema, you won't even notice the difference. But as soon as you need to leverage one of the newer columns in the v1_2 schema, it's right there for you, ready when you are. And the best thing is, you don't need to reprocess any of the data. All your historical data is immediately accessible using either the v1_0 or v1_2 schema.

I'll leave it at this for now, but please do leave comments if you're curious about the inner workings of this and how we implemented it. I'm happy to write a more detailed blog post to share the inner workings. In the meantime, refer to [FinOps hub data model](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-model) to learn more.

## What's new in Costs_v1_2

Each of the datasets supported by FinOps hubs were updated. The Costs dataset had the most updates, so we'll cover those first. The first difference you'll notice in Costs_v1_2 is support for the latest version of FOCUS:

- Added CapacityReservationId
- Added CapacityReservationStatus
- Added CommitmentDiscountQuantity
- Added CommitmentDiscountUnit
- Added ServiceSubcategory
- Added SkuPriceDetails based on x_SkuDetails, changed to align to FOCUS 1.2 requirements
- Renamed x_InvoiceId to InvoiceId
- Renamed x_PricingCurrency to PricingCurrency
- Renamed x_SkuMeterName to SkuMeter

You'll also see new columns coming from Microsoft Cost Management:

- x_AmortizationClass to help filter out principal charges that can be duplicated when summing ListCost and ContractedCost.
- x_CommitmentDiscountNormalizedRatio for the instance size flexibility ratio needed to support CommitmentDiscountQuantity calculations.
- x_ServiceModel to indicate what service model the charge is (i.e., IaaS, PaaS, SaaS).
- x_SkuPlanName for the Marketplace plan name.

Note that some of the above columns are empty coming from Cost Management. FinOps hubs populates most of the missing columns, like the new capacity reservation and commitment discount columns. We added a new x_SourceValues column to track the column changes happening during FinOps hubs data ingestion. If you're curious about any of the customizations applied on top of Cost Management data, review the properties in x_SourceValues. Any value that is changed is first backed up in x_SourceValues with its original column name and value to help source data quality issues.

While not a new column, one other change you may notice is that x_SkuTier is now being populated across all Cost Management FOCUS versions. This is an important one because you cannot get this information from actual and amortized cost datasets. You will only see the tier in FOCUS datasets. That's just one more reason to switch to FOCUS.

Looking beyond the columns coming from Cost Management, you'll also see extended columns for Alibaba and Tencent Cloud. This completes our native cloud FOCUS dataset support alongside AWS, GCP, and OCI, which are already supported. (Note we don't ingest the cost automatically. We added support for the data once it's been dropped into Azure storage.) This includes the following new columns:

- Alibaba: x_BillingItemCode, x_BillingItemName, x_CommodityCode, x_CommodityName, x_InstanceID
- Tencent: x_ComponentName, x_ComponentType, x_ExportTime, x_OwnerAccountID, x_SubproductName

FinOps hubs also added new columns to support scenarios covered in Power BI reports and the Data Explorer dashboard. With these columns promoted to the database level, reports will render faster and more consistently. This includes:

- Discount percentage columns: x_NegotiatedDiscountPercent, x_CommitmentDiscountPercent, x_TotalDiscountPercent.
- Savings columns: x_NegotiatedDiscountSavings, x_CommitmentDiscountSavings, x_TotalSavings.
- Commitment discount utilization columns: x_CommitmentDiscountUtilizationAmount, x_CommitmentDiscountUtilizationPotential.
- Azure Hybrid Benefit columns: x_SkuLicenseQuantity, x_SkuLicenseStatus, x_SkuLicenseType, x_SkuLicenseUnit.
- SKU property columns: x_SkuCoreCount, x_SkuInstanceType, x_SkuOperatingSystem.
- x_ConsumedCoreHours to track total core hours for the charge by multiplying ConsumedQuantity by x_SkuCoreCount.

## FOCUS updates for other v1_2 datasets

While updating the Costs dataset, we also updated the other datasets to align to FOCUS 1.2 changes. Changes in other tables weren't as big, but pair well and will be important to note if you're using those functions:

- CommitmentDiscountUsage
  - Added CommitmentDiscountUnit
  - Renamed x_CommitmentDiscountQuantity to CommitmentDiscountQuantity
- Prices
  - Renamed x_PricingCurrency to PricingCurrency
  - Renamed x_SkuMeterName to SkuMeter
- Transactions
  - Renamed x_InvoiceId to InvoiceId

## Recommendations changes for the future

In addition to aligning to FOCUS 1.2, we updated the Recommendations dataset schema to account for future plans to ingest Azure Advisor recommendations and also generate custom recommendations. This includes the following new columns:

- ResourceId
- ResourceName
- ResourceType
- SubAccountName
- x_RecommendationCategory
- x_RecommendationDescription
- x_RecommendationId
- x_ResourceGroupName

These columns are empty today, but will be populated in a future release when the Azure Advisor integration is complete.

## Decimal columns switched to the Real datatype

In our initial Data Explorer release, we set all floating-point columns, like prices and costs, to use the decimal datatype. Later, we learned that real is preferred when remaining under a certain level of precision. While we couldn't make the change in a non-breaking way within the v1_0 schema version, adopting a new schema version offered the perfect chance to address this.

Starting in v1_2, all floating-point columns will use the real datatype. If you're extending the tables, functions, or building any custom extensions, be sure to switch from decimal to real when you switch to the v1_2 schema. If you opt to remain on v1_0, you can disregard this as v1_0 will continue to use the decimal datatype going forward and will not change based on our non-breaking promise. For those of you who do switch, you may notice a slight performance improvement when working with numbers at scale.

## Next steps

Some may look at this update and see it as a simple update to align to FOCUS 1.2, while others may see it as a major shift in how FinOps hubs work and how that impacts the data being ingested. The truth is it's somewhere in the middle. FinOps hubs were designed to scale beyond a single FOCUS dataset version. And while FinOps hubs have always supported multiple dataset versions with 1.0-preview(v1), 1.0, and 1.0r2, this is the first time when the schema version has seen such a big change, leveraging the inherent benefits of the architecture.

We hope you're as excited about this as we are. You've already taken the first step to adopt FOCUS and now you'll be able to decide when you're ready to take the next step to FOCUS 1.2 when and where you need it, while keeping all other reports and integrations steady on 1.0. Minimal impact, maximum potential.

To learn more about managed datasets in FinOps hubs, see [FinOps hub data model](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-model). And if you're looking for more, I'm working on a set of premium services designed to help organizations deploy, customize, and scale the FinOps hubs with confidence. Whether you need help getting started, tailoring the tools to your environment, or ensuring long-term success, these services are built to meet you where you are – strategic, secure, and ready to deliver value from day one. Connect with me directly on [LinkedIn](https://linkedin.com/in/flanakin) or Slack to learn more.
