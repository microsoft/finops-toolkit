---
title: FinOps toolkit Invoicing and chargeback report
description: Learn about the Invoicing and chargeback report in Power BI to review and reconcile billed charges compared to your Microsoft Cloud invoice.
author: flanakin
ms.author: micflan
ms.date: 06/04/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Invoicing and chargeback report so that I can understand my costs.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Invoicing and chargeback report

The **Invoicing and chargeback report** provides a general overview of billed costs and facilitates comparing cost and usage details with the charges on your invoice.

> [!div class="nextstepaction"]
> [Download for KQL](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
> [!div class="nextstepaction"]
> [Download for storage](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20and%20optimize%20cost%20and%20usage%20with%20the%20FinOps%20toolkit%20Incoicing%20and%20chargeback%20report%3F/cvaQuestion/How%20valuable%20is%20the%20Incoicing%20and%20chargeback%20report%3F/surveyId/FTK0.12/bladeName/PowerBI.Invoicing/featureName/Documentation)

Power BI reports are provided as template (.PBIT) files. Template files are not preconfigured and do not include sample data. When you first open a Power BI template, you will be prompted to specify report parameters, then authenticate with each data source to view your data. To access visuals and queries without loading data, select Edit in the Load menu button.

This article contains images showing example data. Any price data is for test purposes only.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (for example, reservation and savings plan)
- Service (for example, Virtual machines and SQL database)
- Currency

A few common KPIs you fill find in this report are:

- **Billed cost** shows the billed cost for the period based on what you should see on your Microsoft Cloud invoice.

The currency must be single-select to ensure costs in different currencies aren't mixed.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with more links to learn more.

For instructions on how to connect this report to your data, including details about supported parameters, select the **Connect your data** button. Hold <kbd>Ctrl</kbd> when clicking the button in Power BI Desktop. If you need assistance, select the **Get help** button.

:::image type="content" source="./media/invoicing/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows a basic introduction to the report." lightbox="./media/invoicing/get-started.png" :::

<br>

## Summary

The **Summary** page shows the monthly billed cost for the selected period. This page is helpful in determining what your monthly invoice trends are.

:::image type="content" source="./media/invoicing/summary.png" border="true" alt-text="Screenshot of the Summary page that shows a running total." lightbox="./media/invoicing/summary.png" :::

<br>

## Services

The **Services** page offers a breakdown of cost by service. This page is useful for determining how service usage changes over time at a high level - usually across multiple subscriptions or the entire billing account.

The page uses the standard layout with a breakdown of services organized by category in the chart and table.

:::image type="content" source="./media/invoicing/services.png" border="true" alt-text="Screenshot of the Services page that shows a breakdown of cost by service." lightbox="./media/invoicing/services.png" :::

<br>

## Chargeback

The **Chargeback** page helps facilitate chargeback at a subscription or resource group level. The chart shows effective (amortized) cost over time for each subscription while the table shows a hierarchical breakdown of costs by subscription and resource group.

This page uses effective (amortized) cost rather than billed cost, which is used on other pages in this report. You may see different monthly numbers on this page compared to others because of the different ways effective and billed costs are calculated.

:::image type="content" source="./media/invoicing/chargeback.png" border="true" alt-text="Screenshot of the Chargeback page that shows information used for chargeback." lightbox="./media/invoicing/chargeback.png" :::

### Chargeback customization tips

- Change the columns in the chart and table based on your chargeback needs.
- Create custom columns in the Costs table that extract tags for cost allocation, then add them as columns into the visual for reporting.
- Integrate external data for more allocation options.

<br>

## Invoice recon (MCA)

The **Invoice recon (MCA)** page includes a breakdown of your billed cost by invoice section, service family, and meter to align to Microsoft Customer Agreement (MCA) invoices. This page is useful for comparing billed charges on the invoice with cost and usage details in Cost Management for MCA billing profiles. Enterprise Agreement (EA) enrollments can also use this page; however, it will not align to EA invoices and EA invoice IDs are not included in the cost data.

:::image type="content" source="./media/invoicing/invoice-recon-mca.png" border="true" alt-text="Screenshot of the Invoice recon (MCA) page that shows a breakdown of cost by invoice section, service family, and meter." lightbox="./media/invoicing/invoice-recon-mca.png" :::

<br>

## Invoice recon (EA)

The **Invoice recon (EA)** page includes a breakdown of your billed cost by charge description (product) to align to Enterprise Agreement (EA) invoices. This page is useful for comparing billed charges on the invoice with cost and usage details in Cost Management for EA enrollments. Microsoft Customer Agreement (MCA) billing profiles can also use this page; however, it will not align to MCA invoices.

Note that reservation refunds and credits may not be accounted for in the cost data. Please use the Azure portal or export reservation transactions to review refunds.

:::image type="content" source="./media/invoicing/invoice-recon-ea.png" border="true" alt-text="Screenshot of the Invoice recon (EA) page that shows a breakdown of cost by charge description." lightbox="./media/invoicing/invoice-recon-ea.png" :::

<br>

## Purchases

The **Purchases** page shows a list of products that were purchased during the period.

<!-- NOTE: There are similar pages in the cost-summary.md, rate-optimization.md, and invoicing.md files. They are not identical. Please keep both updated at the same time. -->

:::image type="content" source="./media/invoicing/purchases.png" border="true" alt-text="Screenshot of the Purchases page that shows a list of purchased products." lightbox="./media/invoicing/purchases.png" :::

<br>

## Prices

The **Prices** page shows the prices for all products used during the period.

<!-- NOTE: There are similar pages in the cost-summary.md, rate-optimization.md, and invoicing.md files. They are not identical. Please keep both updated at the same time. -->

The chart shows a summary of the meters that were most used.

:::image type="content" source="./media/invoicing/prices.png" border="true" alt-text="Screenshot of the Prices page that shows prices for all products." lightbox="./media/invoicing/prices.png" :::

<br>

## Tags example

The **Tags example** page provides a conceptual breakdown of charges based on promoted tags. Promoted tags are configured directly in the **Costs** query in Power BI. If you change the promoted tags, you will also need to change this page to align to the tags you use within your account.

:::image type="content" source="./media/invoicing/tags-example.png" border="true" alt-text="Screenshot of the Tags example page that shows a breakdown of costs by tag a sample tag hierarchy." lightbox="./media/invoicing/tags-example.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [Common terms](../help/terms.md)
- [Data dictionary](../help/data-dictionary.md)

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Invoicing and chargeback](../../framework/manage/invoicing-chargeback.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
