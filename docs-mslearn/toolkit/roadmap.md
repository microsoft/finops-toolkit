---
title: FinOps toolkit roadmap
description: Explore the FinOps toolkit roadmap to learn about upcoming features, key themes, and initiatives planned for the future.
author: bandersmsft
ms.author: banders
ms.date: 02/20/2025
ms.topic: reference
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to learn about the future plans for FinOps to better understand how those plans might affect my FinOps practice..
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit roadmap

The Microsoft FinOps toolkit is an open-source collection of tools and resources that help you learn, adopt, and implement FinOps capabilities in the Microsoft Cloud. This document outlines the key themes and directional initiatives identified by the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board). They're based on direct feedback and inputs from the [Advisory council](https://github.com/microsoft/finops-toolkit/wiki/Advisory-council) on behalf of toolkit contributors and consumers. The FinOps toolkit typically publishes releases monthly, which includes updates to this roadmap and the [changelog](changelog.md).

Roadmap term: **January - December 2025**

<br>

This roadmap is a culmination of feedback from toolkit consumers, contributors, and the FinOps community as a whole. The roadmap provides a high-level view of where the toolkit is directionally headed. It summarizes key themes and initiatives but isn't a complete list of every change that can or will be made. We share the roadmap to garner early feedback. Ultimately, the FinOps toolkit community drives contributions.

While our community is growing, we don't have dedicated staff and can't commit to explicit dates. As a result, not all items will be completed within the year. If you would like to see something added, [create an issue](https://aka.ms/ftk/ideas) or [start a discussion](https://aka.ms/ftk/discuss). We welcome any contributions, from collaborative discussions and bug reports to submitting and reviewing pull requests.

<br>

## Objectives for 2025

The [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board) identified the following high-level objectives for 2025:

- **Build and maintain customer trust**<br>
  Ensure FinOps tools and resources are secure, reliable, and scalable. Tools should be error-free, present accurate and complete data, and perform consistently regardless of data size. Tools should be customizable to meet unique business needs. Customizations must be durable and should not break after an upgrade.<br>&nbsp;
- **Maximize reach and facilitate customer success**<br>
  Build tools and resources that facilitate successful and scalable FinOps practice operations. Provide solutions to augment every Microsoft Cloud customer's FinOps toolset by continuously improving based on customer feedback and enabling new scenarios to make customers and services professionals successful.<br>&nbsp;
- **Champion cutting-edge innovation**<br>
  Integrate breakthrough technologies that enable new scenarios and empower organizations to achieve more through FinOps. Harness the power of AI and self-serve analytics to drive significant advancements and improvements. Encourage a culture of continuous innovation, where novel ideas and approaches are welcomed and tested, enabling organizations to achieve unparalleled cloud value and efficiency.<br>&nbsp;
- **Foster an active and inclusive community**<br>
  Nurture and support a vibrant, diverse, and engaged network of stakeholders who collaborate and contribute to the growth and success of the FinOps toolkit. Encourage open communication, knowledge sharing, and mutual support to build strong relationships and drive collective progress.

<br>

## General

- Office hours ([Issue #1333](https://github.com/microsoft/finops-toolkit/issues/1333)) – Monthly call to get real-time help and support for FinOps toolkit solutions.
- Official toolkit support – Get help from Microsoft Support.
- FinOps toolkit overview deck ([Issue #663](https://github.com/microsoft/finops-toolkit/issues/663)) – Slide deck to summarize FinOps toolkit solutions.
- Demo environment – Publicly available demo environment.
- Release automation ([Issue #888](https://github.com/microsoft/finops-toolkit/issues/888)) – Automate the end-to-end CI/CD release process.
- FinOps for AI ([Issue #1329](https://github.com/microsoft/finops-toolkit/issues/1329)) – Understand, optimize, and quantify the value of AI services.

<br>

## Implementing FinOps guide

- FinOps Framework 2025 – Update the Implementing FinOps guide for the FinOps Framework 2025 refresh.

<br>

## FinOps hubs

- Bring your own KeyVault ([PR #573](https://github.com/microsoft/finops-toolkit/pull/573)) – Add support for referencing an existing KeyVault instance.
- FOCUS 1.1 ([Issue #1275](https://github.com/microsoft/finops-toolkit/issues/1275)) – Add support for FOCUS 1.1 across tools and services.
- FOCUS 1.2 – Add support for FOCUS 1.2 across tools and services.
- Extensibility – App model to support optional components.
- Recommendations – Integrate recommendations from the Azure Optimization Engine.
- Management UX – Website to create and manage resources.
- Data quality improvements ([Issue #1111](https://github.com/microsoft/finops-toolkit/issues/1111)) – Augment and extend the Cost Management data.
- Terraform ([Issue #743](https://github.com/microsoft/finops-toolkit/issues/743)) – Create a terraform module for FinOps hubs.
- Allocation engine ([Issue #666](https://github.com/microsoft/finops-toolkit/issues/666)) – Create an engine that supports tag-based allocation.

<!--
- Troubleshooting guide ([Issue #734](https://github.com/microsoft/finops-toolkit/issues/734)) – Detailed walkthrough of how to resolve and get support for common issues.
- Autobackfill – Backfill historical data from Microsoft Cost Management.
- Retention – Configure how long you want to keep data in storage.
-->

<br>

## Power BI reports

- FOCUS 1.1 ([Issue #1275](https://github.com/microsoft/finops-toolkit/issues/1275)) – Add support for FOCUS 1.1 across tools and services.
- FOCUS 1.2 – Add support for FOCUS 1.2 across tools and services.
- Commitment discount break-even point ([Issue #406](https://github.com/microsoft/finops-toolkit/issues/406)) – Visualize the break-even point for commitment discounts.
- Microsoft Fabric – Add support for data hosted in Microsoft Fabric.

<!--
- Warnings – Show warnings to raise awareness about known issues.
- Update notification – Show an update notification when new releases are available.
-->

<br>

## FinOps workbooks

- FOCUS 1.1 ([Issue #733](https://github.com/microsoft/finops-toolkit/issues/733)) – Add support for FOCUS 1.1 across tools and services.
- General updates – Ongoing updates based on the latest feedback.
- FinOps hubs support – Merge cost from FinOps hubs with recommendations.

<br>

<!--
## Optimization engine
<br>
-->

## PowerShell

- Deploy-FinOpsWorkbook – Deploy toolkit workbooks.

<br>

## Bicep Registry

- Cost Management exports – Deploy Cost Management exports with native bicep modules.

<br>

## Open data

- Recommendation types ([#1255](https://github.com/microsoft/finops-toolkit/issues/1255)) – Metadata about Azure Advisor recommendations.
- Resource type services – Add service metadata to the Resource types open data file.

<br>

## New tools

- FinOps alerts ([Milestone #24](https://github.com/microsoft/finops-toolkit/milestone/24)) – Email notifications when optimization opportunities are identified.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.8/bladeName/Toolkit/featureName/Roadmap)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)

<br>
