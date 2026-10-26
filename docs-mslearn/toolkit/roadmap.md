---
title: FinOps toolkit roadmap
description: Explore the FinOps toolkit roadmap to learn about upcoming features, key themes, and initiatives planned for the future.
author: flanakin
ms.author: micflan
ms.date: 10/26/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to learn about the future plans for FinOps to better understand how those plans might affect my FinOps practice.
---

# FinOps toolkit roadmap

The Microsoft FinOps toolkit is an open-source collection of tools and resources that help you learn, adopt, and implement FinOps capabilities in the Microsoft Cloud. This document outlines the key themes and directional initiatives identified by the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board). They're based on direct feedback and inputs from the [Advisory council](https://github.com/microsoft/finops-toolkit/wiki/Advisory-council) on behalf of toolkit contributors and consumers. The FinOps toolkit publishes regular releases alongside updates to this roadmap and the [changelog](changelog.md).

Roadmap term: **January - December 2026**

<br>

This roadmap is a culmination of feedback from toolkit contributors, consumers, and the FinOps community as a whole. The roadmap provides a high-level view of where the toolkit is directionally headed. It summarizes key themes and initiatives but isn't a complete list of every change that can or will get made. We share the roadmap to garner early feedback. Ultimately, the FinOps toolkit community drives contributions.

While our community is growing, we don't have a dedicated staff and can't commit to explicit dates. As a result, not all items will be completed within the year. If you would like to see something added, [create an issue](https://aka.ms/ftk/ideas) or [start a discussion](https://aka.ms/ftk/discuss). And, we welcome any contribution with a pull request.

<br>

## Key themes for 2026

With the October 2026 release establishing the foundation for agentic FinOps, Azure capacity management, AI tokenomics queries, local development, private networking, and automated open data, the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board) identified the following high-level themes for the remainder of 2026:

- **AI-powered FinOps and FinOps for AI (tokenomics)**<br>
  Enable interactive and autonomous FinOps and capacity operations through AI agents, skills, and Model Context Protocol (MCP) tools while expanding AI billing, tokenomics (token-to-dollar attribution, provisioned throughput utilization, and unit economics), and telemetry visibility across Microsoft Foundry, Azure OpenAI, Azure API Management, OpenTelemetry, and GitHub Copilot.
- **End-to-end FinOps and cloud capacity management**<br>
  Expand the FinOps toolkit to connect cost reporting, rate and usage optimization, recommendations, and cloud capacity management—including quota headroom, SKU and zone restrictions, capacity reservation groups, and commitment discount coordination—across the Microsoft Cloud and cross-cloud environments.
- **Solidify the foundation and data quality**<br>
  Strengthen FinOps hubs security, private networking, multi-version FinOps Open Cost and Usage Specification (FOCUS) 1.3 and 1.4 conformance, and automated data-quality and release guardrails.
- **Enable the community and ecosystem**<br>
  Expand support resources, clarify tool ownership and support models, streamline contributor and triage workflows with agentic automation, and highlight partner and community solutions across the [FinOps toolkit ecosystem](https://microsoft.github.io/finops-toolkit/ecosystem).

<br>

## General

- Completed - FinOps toolkit ecosystem – Curated directory of partner and community FinOps solutions built for the Microsoft Cloud.
- Completed - Office hours – Recurring community call to get real-time help and support for FinOps toolkit solutions.
- Completed - FinOps hub upgrade guidance – Document schema upgrades and preview conventions for multi-version FOCUS adoption.
- In development - FOCUS 1.3 and 1.4 ([Issue #2120](https://github.com/microsoft/finops-toolkit/issues/2120)) – Add support for FOCUS 1.3 and 1.4 across FinOps hubs, Power BI reports, agent plugins, and documentation.
- In development - AI-assisted triage and repository automation ([Issue #2357](https://github.com/microsoft/finops-toolkit/issues/2357)) – Automate issue triage, link checking, moderation, and repository maintenance with GitHub Agentic Workflows.
- In development - Release automation ([Issue #888](https://github.com/microsoft/finops-toolkit/issues/888)) – Automate the end-to-end CI/CD release and Power BI template packaging process.
- In development - Official toolkit support and ownership model – Define ownership, lifecycle hygiene, and support boundaries across core, community-supported, and ecosystem tools.
- Not started - Demo environment – Publicly available demo environment.

<br>

## Learning resources

- Completed - FinOps Framework updates – Align capability guides, reports, and workbooks with current FinOps Framework terminology.
- Completed - FOCUS 1.2 data dictionary and hub schema reference ([Issue #2329](https://github.com/microsoft/finops-toolkit/issues/2329)) – Align data dictionary definitions with FOCUS 1.2 and document nested FinOps hub `Costs()` columns.
- In development - FOCUS 1.4 documentation and query library – Schema upgrade, compatibility, and conformance documentation plus a reusable FOCUS query library.
- In development - Well-Architected Cost Optimization Assessment – Guidance and assessment alignment for Well-Architected cost optimization.
- Not started - FinOps toolkit overview deck ([Issue #663](https://github.com/microsoft/finops-toolkit/issues/663)) – Slide deck to summarize FinOps toolkit solutions.

<br>

## FinOps hubs

- Completed - Sovereign cloud support ([Issue #2081](https://github.com/microsoft/finops-toolkit/issues/2081)) – Support deployments in Azure Government and Azure operated by 21Vianet.
- Completed - Recommendations ingestion ([Issue #2011](https://github.com/microsoft/finops-toolkit/issues/2011)) – Ingest Azure Advisor and custom Azure Resource Graph recommendations.
- Completed - Extensibility – Modular Bicep app architecture to support optional hub components.
- Completed - Private endpoints and virtual network modes ([Issue #2258](https://github.com/microsoft/finops-toolkit/issues/2258)) – Virtual network and private network modes with opt-in NAT Gateway, an Azure Files private endpoint for deployment scripts, and customer-managed private endpoint guidance.
- Completed - Retention configuration and preservation ([Issue #2348](https://github.com/microsoft/finops-toolkit/issues/2348)) – Configure storage and Data Explorer retention and preserve custom retention settings across redeployments and upgrades.
- Completed - Run hubs locally – Run FinOps hubs KQL databases, transforms, and open data locally in a Kusto emulator container.
- Completed - KQL query catalog and AI tokenomics queries – Scenario-specific KQL queries for Azure OpenAI token usage, model cost comparison, AI spend trends, application cost allocation, and FinOps Foundation KPIs.
- Completed - KQL performance and savings accuracy ([Issue #2213](https://github.com/microsoft/finops-toolkit/issues/2213)) – Faster KQL operators, corrected commitment discount eligibility and reservation price backfills, and consistent dashboard savings.
- In development - FOCUS 1.4 ingestion and hub functions – Add the `v1_4` ingestion schema and hub functions, with `ContractCommitments` tables and functions remaining empty until Cost Management supports exporting the dataset.
- In development - Quota, capacity, and savings plan recommendation ingestion ([Issue #1721](https://github.com/microsoft/finops-toolkit/issues/1721)) – Ingest quota usage and headroom into a normalized `Quota()` hub function alongside 1-year and 3-year Azure savings plan recommendations.
- In development - FinOps for AI, tokenomics, and capacity dashboards – Add AI billing, tokenomics, and capacity dashboards that join operational token and quota telemetry with FinOps hub `Costs()` and `Prices()`.
- In development - Key Vault RBAC and existing Key Vault support ([Issue #1067](https://github.com/microsoft/finops-toolkit/issues/1067)) – Add opt-in Key Vault role-based access control (RBAC) authorization and support for an existing Key Vault instance.
- In development - Disable storage Shared Key access ([Issue #2312](https://github.com/microsoft/finops-toolkit/issues/2312)) – Add an opt-in parameter to disable storage account Shared Key authorization.
- In development - MCA price sheet `2024-08-01` and invoice PDF ingestion ([Issue #2311](https://github.com/microsoft/finops-toolkit/issues/2311)) – Support the `2024-08-01` Microsoft Customer Agreement price sheet schema and download Microsoft invoice PDFs into the hub data lake.
- In development - Data Factory Resource Graph pagination and custom naming ([Issue #2320](https://github.com/microsoft/finops-toolkit/issues/2320)) – Paginate Azure Resource Graph ingestion queries past 1,000 rows, support custom resource naming, and add cost center aggregation.
- In development - Cross-cloud cost ingestion and Terraform module ([Issue #910](https://github.com/microsoft/finops-toolkit/issues/910)) – Support non-Azure (AWS and GCP) FOCUS cost ingestion, multi-cloud test data generation, and a Terraform module for FinOps hubs.
- Not started - Autobackfill – Backfill historical data from Microsoft Cost Management.
- Not started - Management UX – Website to create and manage resources.

<br>

## AI agents and plugins

- Completed - **New tool**: FinOps Hub Copilot Studio template – Copilot Studio agent template for conversational FinOps hubs analysis.
- Completed - **New tool**: Claude Code and GitHub Copilot CLI plugin ([Issue #2013](https://github.com/microsoft/finops-toolkit/issues/2013)) – Shared AI plugin with 5 specialist agents (CFO, FinOps practitioner, database query, hubs agent, and Azure capacity manager), 4 commands, a FinOps hubs KQL skill, and a read-only Azure MCP server.
- Completed - Project coordination agents – Chief of staff, release manager, and support agents plus the Microsoft Writing Style Guide skill to help run the project.
- In development - **New tool**: FinOps and capacity SRE Agent template ([Issue #1555](https://github.com/microsoft/finops-toolkit/issues/1555)) – Installable Azure SRE Agent template for scheduled FinOps reporting, AI workload and tokenomics analysis, commitment reviews, and end-to-end capacity management.
- In development - FOCUS 1.3 and 1.4 agent and Copilot Studio updates ([Issue #2119](https://github.com/microsoft/finops-toolkit/issues/2119)) – Refresh agent skills, Copilot Studio knowledge, and the query catalog for FOCUS 1.3 and 1.4, and add a code-review skill.

<br>

## Power BI reports

- Completed - Azure Resource Graph pagination and FOCUS 1.2 storage compatibility ([Issue #1768](https://github.com/microsoft/finops-toolkit/issues/1768)) – Subscription-batched Resource Graph pagination, FOCUS 1.2 and ISO 8601 `x_SkuTerm` compatibility in storage reports, and instance size flexibility open data integration.
- In development - FOCUS 1.4 schema update – Update Power BI reports to the FOCUS 1.4 (`v1_4`) schema.
- In development - Incremental refresh and query performance ([Issue #2336](https://github.com/microsoft/finops-toolkit/issues/2336)) – Support partitioned incremental refresh on the storage `Costs` table, optimize tag promotion CPU performance, and expand unattached disks reporting.
- In development - Community reports and data-only template – Community Power BI reports repository and a data-only Power BI report template.
- Not started - Update notification – Show an update notification when new releases are available.

<br>

## Cost optimization workbook

- Completed - General updates and KQL join accuracy – FinOps Framework terminology alignment and explicit KQL join fixes across savings plan and Azure Hybrid Benefit queries.
- Not started - FinOps hubs support – Merge cost from FinOps hubs with recommendations.

<br>

## Optimization engine

- Completed - Reference documentation, DCR ingestion, and ISF open data ([Issue #1271](https://github.com/microsoft/finops-toolkit/issues/1271)) – Comprehensive architecture reference, Log Analytics Data Collection Rule (DCR) ingestion migration, and instance size flexibility open data integration with retired-SKU reservation visibility.
- In development - Reservation workbook ratio scale and KQL join refinements ([Issue #2309](https://github.com/microsoft/finops-toolkit/issues/2309)) – Align reservation workbook quantity scales and KQL join patterns.

<br>

## PowerShell

- Completed - Open data commands – `Get-FinOpsCommitmentDiscountEligibility` and `Get-FinOpsInstanceSizeFlexibility` commands.
- Completed - Local FinOps hub initialization and export fixes ([Issue #2255](https://github.com/microsoft/finops-toolkit/issues/2255)) – `Initialize-FinOpsHubLocal` for local Kusto emulator testing, UTC calendar date handling in `Start-FinOpsCostExport`, complete `-RunHistory`, and hub version parsing fixes.
- In development - FinOps Explorer – Interactive cross-platform terminal UI for FinOps scanning and exploration.
- Not started - Deploy-FinOpsWorkbook – Deploy toolkit workbooks.

<br>

## Open data

- Completed - Instance size flexibility dataset ([Issue #2090](https://github.com/microsoft/finops-toolkit/issues/2090)) – Automated weekly dataset from the Azure Reservations Catalogs API replacing deprecated `ccmstorageprod` CSV files across all Azure regions.
- Completed - Commitment discount eligibility validation and FOCUS alignment ([Issue #2279](https://github.com/microsoft/finops-toolkit/issues/2279)) – Dual-traversal verified refresh, FOCUS spend and usage category alignment, and CI family-count regression protection.
- In development - Advisor recommendation types and unified service metadata ([Issue #1255](https://github.com/microsoft/finops-toolkit/issues/1255)) – Add an Azure Advisor `RecommendationTypes` dataset and merge resource types and services open data.

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
