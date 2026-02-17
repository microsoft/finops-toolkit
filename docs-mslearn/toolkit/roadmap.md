---
title: FinOps toolkit roadmap
description: Explore the FinOps toolkit roadmap to learn about upcoming features, key themes, and initiatives planned for the future.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to learn about the future plans for FinOps to better understand how those plans might affect my FinOps practice..
---

# FinOps toolkit roadmap

The Microsoft FinOps toolkit is an open-source collection of tools and resources that help you learn, adopt, and implement FinOps capabilities in the Microsoft Cloud. This document outlines the key themes and directional initiatives identified by the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board). They're based on direct feedback and inputs from the [Advisory council](https://github.com/microsoft/finops-toolkit/wiki/Advisory-council) on behalf of toolkit contributors and consumers. As of May 2024, the FinOps toolkit targets publishing new releases at the end of every month, which includes updates to this roadmap and the [changelog](changelog.md).

Roadmap term: **January - December 2024**

<br>

This roadmap is a culmination of feedback from toolkit contributors, consumers, and the FinOps community as a whole. The roadmap provides a high-level view of where the toolkit is directionally headed. It summarizes key themes and initiatives but isn't a complete list of every change that can or will get made. We share the roadmap to garner early feedback. Ultimately, the FinOps toolkit community drives contributions.

While our community is growing, we don't have a dedicated staff and can't commit to explicit dates. As a result, not all items will be completed within the year. If you would like to see something added, [create an issue](https://aka.ms/ftk/ideas) or [start a discussion](https://aka.ms/ftk/discuss). And, we welcome any contribution with a pull request.

<br>

## Key themes for 2024

2023 was focused on establishing a baseline for a few of the core tools included in the toolkit. As we look forward to 2024, the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board) identified the following high-level themes:

- **End-to-end FinOps**<br>
  Expand the FinOps toolkit to encapsulate everything organizations need to learn and implement FinOps through Microsoft products, solutions, and services.<br>&nbsp;
- **Solidify the foundation**<br>
  Flesh out the infrastructure needed to scale open-source contributions and unblock key design principles of tools and resources within the toolkit. They include DevOps automation and extensibility to streamline the contributor and release workflows and native support for optional or custom functionality.<br>&nbsp;
- **Enable the community**<br>
  Expand and evolve the help and support resources and options available for the broader community of contributors and consumers.<br>&nbsp;
- **Community-driven evolution**<br>
  Continuously integrate community insights and feedback to refine and enhance tools and resources to evolve in alignment with user needs and industry trends.

<br>

## General

- Completed - FOCUS 1.0 (June, [Issue #778](https://github.com/microsoft/finops-toolkit/issues/778)) – Add support for FOCUS 1.0 GA across tools and services.<br>
- Not started - Office hours – Monthly call to get real-time help and support for FinOps toolkit solutions.<br>
- In development - Official toolkit support – Get help from Microsoft Support.<br>
- Not started - Demo environment – Publicly available demo environment.<br>
- Not started - Release automation – Automate the end-to-end CI/CD release process.<br>
- Not started - FOCUS 1.1 (November) – Add support for FOCUS 1.1 across tools and services.<br>

<br>

## Learning resources

- Completed - Learning resources – Add learning resources to documentation.<br>
- Completed - FinOps documentation – Add documentation for how to implement FinOps.<br>
- Completed - Microsoft Learn training modules – Self-paced FinOps training on Microsoft Learn.<br>
- Completed - FinOps Framework updates ([Milestone #21](https://github.com/microsoft/finops-toolkit/milestone/21)) – Update FinOps capability guides for 2024 FinOps Framework updates.<br>
- In development - FinOps toolkit on Microsoft Learn – Publish toolkit docs into Microsoft Learn.<br>
- Not started - FinOps toolkit overview deck – Slide deck to summarize FinOps toolkit solutions.<br>

<br>

## FinOps hubs

- Completed - Remote hubs ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Ingest cost data from other tenants.<br>
- Completed - Managed exports ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Let FinOps hubs manage exports for you.<br>
- Completed - More export types – Add support for all Cost Management export types.<br>
- In development - Analytics engine ([Issue #57](https://github.com/microsoft/finops-toolkit/issues/57)) – Ingest cost data into an Azure Data Explorer cluster.<br>
- In development - Private endpoints ([Milestone #22](https://github.com/microsoft/finops-toolkit/milestone/22)) – Add support for private endpoints.<br>
- In development - Bring your own KeyVault ([PR #573](https://github.com/microsoft/finops-toolkit/pull/573)) – Add support for referencing an existing KeyVault instance.<br>
- Not started - Troubleshooting guide ([Issue #734](https://github.com/microsoft/finops-toolkit/issues/734)) – Detailed walkthrough of how to resolve and get support for common issues.<br>
- Not started - Autobackfill – Backfill historical data from Microsoft Cost Management.<br>
- Not started - Retention – Configure how long you want to keep data in storage.<br>
- Not started - Extensibility – App model to support optional components.<br>
- Not started - Management UX – Website to create and manage resources.<br>

<br>

## Power BI reports

- Completed - Data ingestion report – New report to monitor FinOps hubs data ingestion.<br>
- Completed - Raw exports – Add support for raw exports without FinOps hubs.<br>
- Completed - Tags demo – Include example of how to use tags.<br>
- Not started - Warnings – Show warnings to raise awareness about known issues.<br>
- Not started - Microsoft Fabric – Add support for data hosted in Microsoft Fabric.<br>
- Not started - Update notification – Show an update notification when new releases are available.<br>

<br>

## Cost optimization workbook

- In development - General updates – Ongoing updates based on the latest feedback.<br>
- Not started - FinOps hubs support – Merge cost from FinOps hubs with recommendations.<br>

<br>

## Optimization engine

- Completed - **New tool**: Azure Optimization Engine – Custom recommendation engine.<br>
- Completed - SQL database Microsoft Entra ID authentication – Replace SQL Server authentication with Microsoft Entra ID-only authentication.<br>

<br>

## PowerShell

- Not started - Deploy-FinOpsWorkbook – Deploy toolkit workbooks.<br>

<br>

## Open data

- Completed - Service model – Add ServiceModel to the services open data file.<br>
- In development - Update all data – Ongoing updates all open data file with each release.<br>

<br>

## New tools

- In development - **New tool**: Cost optimization notifications ([Milestone #24](https://github.com/microsoft/finops-toolkit/milestone/24)) – Email notifications when optimization opportunities are identified.<br>

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Toolkit/featureName/Roadmap)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

<br>
