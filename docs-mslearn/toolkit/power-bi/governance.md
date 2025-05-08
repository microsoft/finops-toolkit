---
title: FinOps toolkit Governance report
description: Summarize cloud governance posture including areas like compliance, security, operations, and resource management in Power BI.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Governance report so that I can better understand compliance, security, operations, and resource management.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Governance report

The **Governance report** summarizes your Microsoft Cloud governance posture. It offers standard metrics aligned with the Cloud Adoption Framework (CAF) to help identify issues, apply recommendations, and resolve compliance gaps.

The CAF govern methodology provides a structured approach for establishing and optimizing cloud governance in Azure. The guidance is relevant for organizations across any industry. It covers essential categories of cloud governance, such as regulatory compliance, security, operations, cost, data, resource management, and artificial intelligence (AI).

Cloud governance is how you control cloud use across your organization. Cloud governance sets up guardrails that regulate cloud interactions. These guardrails are a framework of policies, procedures, and tools you use to establish control. Policies define acceptable and unacceptable cloud activity, and the procedures and tools you use ensure all cloud usage aligns with those policies. Successful cloud governance prevents all unauthorized or unmanaged cloud usage.

To assess your transformation journey, try the [governance benchmark tool](/assessments/b1891add-7646-4d60-a875-32a4ab26327e/?WT.mc_id=FinOpsToolkit).

This report pulls data from:

- Cost Management exports or FinOps hubs
- Azure Resource Graph

The Governance report is new and still being fleshed out. We will continue to expand capabilities in each release in alignment with the [Cost optimization workbook](../workbooks/optimization.md). To request additional capabilities, please [create a feature request](https://aka.ms/ftk/ideas) in GitHub.

> [!div class="nextstepaction"]
> [Download for KQL](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
> [!div class="nextstepaction"]
> [Download for storage](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20and%20optimize%20cost%20and%20usage%20with%20the%20FinOps%20toolkit%20Policy%20and%20governance%20report%3F/cvaQuestion/How%20valuable%20is%20the%20Policy%20and%20governance%20report%3F/surveyId/FTK0.10/bladeName/PowerBI.Governance/featureName/Documentation)

Power BI reports are provided as template (.PBIT) files. Template files are not preconfigured and do not include sample data. When you first open a Power BI template, you will be prompted to specify report parameters, then authenticate with each data source to view your data. To access visuals and queries without loading data, select Edit in the Load menu button.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with links to learn more.

For instructions on how to connect this report to your data, including details about supported parameters, select the **Connect your data** button. Hold <kbd>Ctrl</kbd> when clicking the button in Power BI Desktop. If you need assistance, select the **Get help** button.

:::image type="content" source="./media/governance/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows basic information." lightbox="./media/governance/get-started.png" :::

<br>

## Summary

The **Summary** page provides a summary of subscriptions, resource types, resources, and regions across your environment.

:::image type="content" source="./media/governance/summary.png" border="true" alt-text="Screenshot of the Summary page that shows a summary of subscriptions, resource types, and other information." lightbox="./media/governance/summary.png" :::

<br>

## Policy compliance

The **Policy compliance** page lists policies configured in Azure Policy for the selected subscriptions.

:::image type="content" source="./media/governance/policy-compliance.png" border="true" alt-text="Screenshot of the Policy compliance page that shows policies configured in Azure Policy." lightbox="./media/governance/policy-compliance.png" :::

<br>

## Virtual machines

The **Virtual machines** page lists the virtual machines, disks, and public IP addresses with related right-sizing recommendations.

:::image type="content" source="./media/governance/virtual-machines.png" border="true" alt-text="Screenshot of the Virtual machines page that shows virtual machine details." lightbox="./media/governance/virtual-machines.png" :::

<br>

## Managed disks

The **Managed disks** page lists the managed disks.

:::image type="content" source="./media/governance/managed-disks.png" border="true" alt-text="Screenshot of the Managed disks page that lists managed disks." lightbox="./media/governance/managed-disks.png" :::

<br>

## SQL databases

The **SQL databases** page lists the SQL databases.

The chart shows the cost of each disk over time.

The table shows the disks with related properties. It includes billed and effective cost and the dates the disk was available during the selected date range. The date range is shown in the Charge period filter at the top-left of the page.

:::image type="content" source="./media/governance/sql-databases.png" border="true" alt-text="Screenshot of the SQL databases page that shows your SQL databases." lightbox="./media/governance/sql-databases.png" :::

<br>

## Network security groups

The **Network security groups** page lists network security groups and network security group rules.

:::image type="content" source="./media/governance/network-security-groups.png" border="true" alt-text="Screenshot of the Network security groups page that lists network security groups and network security group rules." lightbox="./media/governance/network-security-groups.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [How to convert Cost Management data to FOCUS](../../focus/convert.md)
- [How to update existing reports to FOCUS](../../focus/mapping.md)
- [Common terms](../help/terms.md)
- [Data dictionary](../help/data-dictionary.md)

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
