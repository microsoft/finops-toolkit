---
title: Data ingestion report
description: Learn about the Data Ingestion Report, which provides insights into the data ingested into your FinOps hub storage account.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Data ingestion report so that I can understand my incoming data.
---

<!-- markdownlint-disable-next-line MD025 -->
# Data ingestion report

The **Data ingestion report** provides details about the data that got ingested into your FinOps hub storage account. You can download the Data ingestion report from the [latest release](https://aka.ms/ftk/latest).

<br>

## Get started

The **Get started** page includes a basic introduction to the report with other links to learn more.

:::image type="content" source="./media/data-ingestion/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows basic information and links to learn more." lightbox="./media/data-ingestion/get-started.png" :::

<br>

## Hubs

The **Hubs** page shows the cost of any FinOps hubs instances. Expand each instance to see the cost broken down by service (for example, Storage or Key Vault). Most organizations only have one hub instance. This page can be helpful in confirming how much your hub instance is costing you. And it helps confirm if there are other hub instances deployed within the organization, which could possibly be centralized.

This page includes the same KPIs as most pages within the [Cost summary report](cost-summary.md):

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Total savings** shows how much you're saving compared to list prices.

:::image type="content" source="./media/data-ingestion/hubs.png" border="true" alt-text="Screenshot of the Hubs page that shows the cost of FinOps hubs instances." lightbox="./media/data-ingestion/hubs.png" :::

<br>

## Exports

The **Exports** page shows which months were exported for which scopes, when the exports were run, and if any ingestion flows failed. Failures are shown in CSV files in the `msexports` container since that means they weren't fully ingested. To investigate why ingestion failed, you need to review the logs in Azure Data Factory. In general, as long as another ingestion was completed for that month, you're covered. Mid-month ingestion failures don't result in missing data since Cost Management re-exports the previous days' data in each export run. Exports are typically run up to the fifth day of the following month. If you see a date after the fifth day of the month, then that usually means someone ran a one-time export for the month.

> [!TIP]
> If you only see one export run per month, you might have configured file overwriting. While this setting is important when using Power BI against raw data exports, it is not recommended for FinOps hubs because it removes the ability to monitor export runs over time (since files are deleted).

:::image type="content" source="./media/data-ingestion/exports.png" border="true" alt-text="Screenshot of the Exports page that shows detailed information about exports." lightbox="./media/data-ingestion/exports.png" :::

<br>

## Ingestion

The **Ingestion** page shows which months have been ingested and are available for querying in Power BI and other client apps. The FinOps hubs ingestion process doesn't create new files every day, so you might only see one to two files. The number of files gets determined by Cost Management when generating the initial partitioned CSV files.

Similar to exports that are run until the fifth day of the following month, you typically see ingested months being updated until the fifth day of the following month. If you see a date later than the fifth day of the month, it's often due to a one-time export run.

If you notice exports from before ingested months, it typically means older data was removed from the `ingestion` container but the export metadata wasn't removed from `msexports`. You can safely remove files in `msexports` at any time. They're only useful for monitoring export runs.

:::image type="content" source="./media/data-ingestion/ingestion.png" border="true" alt-text="Screenshot of the Ingestion page that shows the months of ingestion data." lightbox="./media/data-ingestion/ingestion.png" :::

<br>

## Ingestion errors

The **Ingestion errors** page summarizes potential issues that were identified after reviewing data in hub storage. For troubleshooting details about each error, see [Troubleshooting Power BI reports](../help/troubleshooting.md).

:::image type="content" source="./media/data-ingestion/ingestion-errors.png" border="true" alt-text="Screenshot of the Ingestion errors page that shows a summary of potential problems." lightbox="./media/data-ingestion/ingestion-errors.png" :::


<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>