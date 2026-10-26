---
title: FinOps toolkit roadmap
description: Explore the FinOps toolkit roadmap to learn about upcoming features, key themes, and initiatives planned for the future.
author: flanakin
ms.author: micflan
ms.date: 10/19/2026
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

With release **v15** establishing the foundation for agentic FinOps, Azure capacity management, AI tokenomics queries, local development, private networking, and automated open data, the [Governing board](https://github.com/microsoft/finops-toolkit/wiki/Governing-board) identified the following high-level themes for **v16** and the remainder of 2026:

- **AI-powered FinOps and FinOps for AI (tokenomics)**<br>
  Enable interactive and autonomous FinOps and capacity operations through AI agents, skills, and Model Context Protocol (MCP) tools while expanding AI billing, tokenomics (token-to-dollar attribution, provisioned throughput utilization, and unit economics), and telemetry visibility across Microsoft Foundry, Azure OpenAI, Azure API Management, OpenTelemetry, and GitHub Copilot.<br>&nbsp;
- **End-to-end FinOps and cloud capacity management**<br>
  Expand the FinOps toolkit to connect cost reporting, rate and usage optimization, recommendations, and cloud capacity management—including quota headroom, SKU and zone restrictions, capacity reservation groups, and commitment discount coordination—across the Microsoft Cloud and cross-cloud environments.<br>&nbsp;
- **Solidify the foundation and data quality**<br>
  Strengthen FinOps hubs security, private networking, multi-version FinOps Open Cost and Usage Specification (FOCUS) 1.3 and 1.4 conformance, and automated data-quality and release guardrails.<br>&nbsp;
- **Enable the community and ecosystem**<br>
  Expand support resources, clarify tool ownership and support models, streamline contributor and triage workflows with agentic automation, and highlight partner and community solutions across the [FinOps toolkit ecosystem](finops-toolkit-ecosystem.md).

<br>

## General

- Completed - FOCUS 1.0 and 1.2 ([Issue #778](https://github.com/microsoft/finops-toolkit/issues/778)) – Support for FOCUS 1.0 and 1.2 across FinOps hubs, Power BI reports, and the data dictionary.<br>
- Completed - Office hours – Recurring community call to get real-time help and support for FinOps toolkit solutions.<br>
- Completed (v15) - FinOps toolkit ecosystem ([PR #2239](https://github.com/microsoft/finops-toolkit/pull/2239)) – Curated directory of partner and community FinOps solutions built for the Microsoft Cloud.<br>
- In development (v16) - FinOps hub upgrade guidance ([PR #2123](https://github.com/microsoft/finops-toolkit/pull/2123)) – Document schema upgrades and preview conventions for multi-version FOCUS adoption.<br>
- In development (v16) - FOCUS 1.3 and 1.4 ([Issue #2120](https://github.com/microsoft/finops-toolkit/issues/2120), [PR #2207](https://github.com/microsoft/finops-toolkit/pull/2207)) – Add support for FOCUS 1.3 and 1.4 across FinOps hubs, Power BI reports, agent plugins, and documentation.<br>
- In development (v16) - AI-assisted triage and repository automation ([Issue #2357](https://github.com/microsoft/finops-toolkit/issues/2357), [PR #2358](https://github.com/microsoft/finops-toolkit/pull/2358)) – Automate issue triage, link checking, moderation, and repository maintenance with GitHub Agentic Workflows.<br>
- In development (v16) - Release automation ([Issue #888](https://github.com/microsoft/finops-toolkit/issues/888), [PR #2322](https://github.com/microsoft/finops-toolkit/pull/2322)) – Automate the end-to-end CI/CD release and Power BI template packaging process.<br>
- In development (v16) - Official toolkit support and ownership model – Define ownership, lifecycle hygiene, and support boundaries across core, community-supported, and ecosystem tools.<br>
- Not started - Demo environment – Publicly available demo environment.<br>

<br>

## Learning resources

- Completed - Learning resources – Add learning resources to documentation.<br>
- Completed - FinOps documentation – Add documentation for how to implement FinOps.<br>
- Completed - Microsoft Learn training modules – Self-paced FinOps training on Microsoft Learn.<br>
- Completed - FinOps toolkit on Microsoft Learn – Publish toolkit documentation on Microsoft Learn.<br>
- Completed (v15) - FinOps Framework updates ([Milestone #21](https://github.com/microsoft/finops-toolkit/milestone/21), [PR #2170](https://github.com/microsoft/finops-toolkit/pull/2170)) – Align capability guides, reports, and workbooks with current FinOps Framework terminology.<br>
- Completed (v15) - FOCUS 1.2 data dictionary and hub schema reference ([PR #2112](https://github.com/microsoft/finops-toolkit/pull/2112), [Issue #2325](https://github.com/microsoft/finops-toolkit/issues/2325), [Issue #2329](https://github.com/microsoft/finops-toolkit/issues/2329)) – Align data dictionary definitions with FOCUS 1.2 and document nested FinOps hub `Costs()` columns.<br>
- In development (v16) - FOCUS 1.4 documentation and query library ([PR #2211](https://github.com/microsoft/finops-toolkit/pull/2211), [PR #2208](https://github.com/microsoft/finops-toolkit/pull/2208), [PR #1401](https://github.com/microsoft/finops-toolkit/pull/1401)) – Schema upgrade, compatibility, and conformance documentation plus a reusable FOCUS query library.<br>
- In development - Well-Architected Cost Optimization Assessment ([Milestone #45](https://github.com/microsoft/finops-toolkit/milestone/45)) – Guidance and assessment alignment for Well-Architected cost optimization.<br>
- Not started - FinOps toolkit overview deck ([Issue #663](https://github.com/microsoft/finops-toolkit/issues/663)) – Slide deck to summarize FinOps toolkit solutions.<br>

<br>

## FinOps hubs

- Completed - Remote hubs ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Ingest cost data from other tenants.<br>
- Completed - Managed exports ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Let FinOps hubs manage exports for you.<br>
- Completed - More export types – Add support for Cost Management price sheets, reservation details, reservation transactions, and recommendations exports.<br>
- Completed - Analytics engine ([Issue #57](https://github.com/microsoft/finops-toolkit/issues/57)) – Ingest cost data into Azure Data Explorer and Microsoft Fabric Real-Time Intelligence.<br>
- Completed - Sovereign cloud support ([Issue #2081](https://github.com/microsoft/finops-toolkit/issues/2081)) – Support deployments in Azure Government and Azure operated by 21Vianet.<br>
- Completed - Recommendations ingestion ([Issue #2011](https://github.com/microsoft/finops-toolkit/issues/2011), [Issue #2077](https://github.com/microsoft/finops-toolkit/issues/2077)) – Ingest Azure Advisor and custom Azure Resource Graph recommendations.<br>
- Completed - Extensibility – Modular Bicep app architecture to support optional hub components.<br>
- Completed - Troubleshooting guide ([Issue #734](https://github.com/microsoft/finops-toolkit/issues/734)) – Detailed walkthrough of how to resolve and get support for common issues.<br>
- Completed (v15) - Private endpoints and virtual network modes ([Milestone #22](https://github.com/microsoft/finops-toolkit/milestone/22), [PR #2163](https://github.com/microsoft/finops-toolkit/pull/2163), [Issue #2258](https://github.com/microsoft/finops-toolkit/issues/2258), [PR #2270](https://github.com/microsoft/finops-toolkit/pull/2270)) – Virtual network and private network modes with opt-in NAT Gateway, Azure Files private endpoint for deployment scripts, and customer-managed private endpoint guidance.<br>
- Completed (v15) - Retention configuration and preservation ([Issue #2348](https://github.com/microsoft/finops-toolkit/issues/2348), [PR #2288](https://github.com/microsoft/finops-toolkit/pull/2288)) – Configure storage and Data Explorer retention and preserve custom retention settings across redeployments and upgrades.<br>
- Completed (v15) - Run hubs locally ([PR #2187](https://github.com/microsoft/finops-toolkit/pull/2187)) – Run FinOps hubs KQL databases, transforms, and open data locally in a Kusto emulator container.<br>
- Completed (v15) - KQL query catalog and AI tokenomics queries ([PR #2167](https://github.com/microsoft/finops-toolkit/pull/2167)) – Shipped 37 scenario-specific KQL queries (`src/queries/`), including Azure OpenAI token usage breakdown, model cost comparison, daily AI spend trends, application cost allocation, and FinOps Foundation KPIs.<br>
- Completed (v15) - KQL performance and commitment savings accuracy ([Issue #2213](https://github.com/microsoft/finops-toolkit/issues/2213), [PR #2220](https://github.com/microsoft/finops-toolkit/pull/2220), [PR #2225](https://github.com/microsoft/finops-toolkit/pull/2225), [Issue #2279](https://github.com/microsoft/finops-toolkit/issues/2279), [Issue #2315](https://github.com/microsoft/finops-toolkit/issues/2315), [PR #2352](https://github.com/microsoft/finops-toolkit/pull/2352)) – Term-indexed KQL operators, broadcast `lookup` dimension enrichment, corrected commitment discount eligibility and reservation price backfills, and consistent dashboard savings calculations.<br>
- In development (v16) - FOCUS 1.4 ingestion and hub functions ([PR #2207](https://github.com/microsoft/finops-toolkit/pull/2207), [PR #2126](https://github.com/microsoft/finops-toolkit/pull/2126), [PR #2128](https://github.com/microsoft/finops-toolkit/pull/2128)) – Add the `v1_4` ingestion schema and hub functions, with `ContractCommitments` tables and functions remaining empty until Cost Management supports exporting the dataset.<br>
- In development (v16) - Quota, capacity, and savings plan recommendation ingestion ([Issue #1721](https://github.com/microsoft/finops-toolkit/issues/1721), [PR #2277](https://github.com/microsoft/finops-toolkit/pull/2277)) – Ingest compute, Azure AI, App Service, SQL, Storage, and capacity reservation quota usage and headroom into a normalized `Quota()` hub function alongside 1-year and 3-year Azure savings plan recommendations.<br>
- In development (v16) - FinOps for AI, tokenomics, and capacity dashboards ([PR #2282](https://github.com/microsoft/finops-toolkit/pull/2282)) – Add AI billing, tokenomics, and capacity Data Explorer and Azure Monitor with Grafana dashboard views joining operational token and quota telemetry across Microsoft Foundry, Azure API Management, GitHub Copilot, and OpenTelemetry with FinOps hub `Costs()` and `Prices()`.<br>
- In development (v16) - Key Vault RBAC and existing Key Vault support ([Issue #1067](https://github.com/microsoft/finops-toolkit/issues/1067), [PR #2249](https://github.com/microsoft/finops-toolkit/pull/2249), [PR #573](https://github.com/microsoft/finops-toolkit/pull/573)) – Add opt-in Key Vault role-based access control (RBAC) authorization for landing zone compliance and support referencing an existing Key Vault instance.<br>
- In development (v16) - Disable storage Shared Key access ([Issue #2312](https://github.com/microsoft/finops-toolkit/issues/2312), [PR #2316](https://github.com/microsoft/finops-toolkit/pull/2316)) – Add an opt-in parameter to disable storage account Shared Key authorization.<br>
- In development (v16) - MCA price sheet `2024-08-01` and invoice PDF ingestion ([Issue #2311](https://github.com/microsoft/finops-toolkit/issues/2311), [PR #2318](https://github.com/microsoft/finops-toolkit/pull/2318), [Issue #2273](https://github.com/microsoft/finops-toolkit/issues/2273)) – Support the `2024-08-01` Microsoft Customer Agreement price sheet schema and automatically download Microsoft invoice PDFs into the hub data lake.<br>
- In development (v16) - Data Factory Resource Graph pagination and custom naming ([Issue #2320](https://github.com/microsoft/finops-toolkit/issues/2320), [PR #2330](https://github.com/microsoft/finops-toolkit/pull/2330), [Issue #1105](https://github.com/microsoft/finops-toolkit/issues/1105), [Issue #2059](https://github.com/microsoft/finops-toolkit/issues/2059)) – Paginate Azure Resource Graph ingestion queries past 1,000 rows, support custom resource naming, and add cost center aggregation.<br>
- In development (v16) - Cross-cloud cost ingestion and Terraform module ([Milestone #39](https://github.com/microsoft/finops-toolkit/milestone/39), [Issue #910](https://github.com/microsoft/finops-toolkit/issues/910), [PR #2006](https://github.com/microsoft/finops-toolkit/pull/2006), [Issue #743](https://github.com/microsoft/finops-toolkit/issues/743)) – Support non-Azure (AWS and GCP) FOCUS cost ingestion, multi-cloud test data generation, and a Terraform module for FinOps hubs.<br>
- Not started - Autobackfill – Backfill historical data from Microsoft Cost Management.<br>
- Not started - Management UX ([Milestone #33](https://github.com/microsoft/finops-toolkit/milestone/33)) – Website to create and manage resources.<br>

<br>

## AI agents and plugins

- Completed - **New tool**: FinOps Hub Copilot Studio template – Copilot Studio agent template for conversational FinOps hubs analysis.<br>
- Completed (v15) - **New tool**: Claude Code and GitHub Copilot CLI plugin ([Issue #2013](https://github.com/microsoft/finops-toolkit/issues/2013), [PR #2167](https://github.com/microsoft/finops-toolkit/pull/2167), [PR #2272](https://github.com/microsoft/finops-toolkit/pull/2272)) – Shared AI plugin with 5 specialist agents (CFO, FinOps practitioner, database query, hubs agent, and Azure capacity manager for quota, capacity reservation groups, and SKU/zone readiness), 4 commands, a FinOps hubs KQL skill, and a read-only Azure MCP server.<br>
- Completed (v15) - Project coordination agents ([PR #2340](https://github.com/microsoft/finops-toolkit/pull/2340), [PR #2276](https://github.com/microsoft/finops-toolkit/pull/2276)) – Chief of staff (`ftk-cos`), release manager (`ftk-release-manager`), and support (`ftk-support`) agents plus the Microsoft Writing Style Guide skill.<br>
- In development (v16) - **New tool**: FinOps and capacity SRE Agent template ([Issue #1555](https://github.com/microsoft/finops-toolkit/issues/1555), [Issue #1567](https://github.com/microsoft/finops-toolkit/issues/1567), [PR #2168](https://github.com/microsoft/finops-toolkit/pull/2168), [PR #2169](https://github.com/microsoft/finops-toolkit/pull/2169)) – Installable Azure SRE Agent template for autonomous scheduled FinOps reporting, AI workload and tokenomics analysis, commitment reviews, and end-to-end capacity management (`Forecast → Procure → Allocate → Monitor`), plus Cost Management skills integration.<br>
- In development (v16) - FOCUS 1.3 and 1.4 agent and Copilot Studio updates ([Issue #2119](https://github.com/microsoft/finops-toolkit/issues/2119), [PR #2135](https://github.com/microsoft/finops-toolkit/pull/2135), [PR #2210](https://github.com/microsoft/finops-toolkit/pull/2210), [Issue #2274](https://github.com/microsoft/finops-toolkit/issues/2274)) – Refresh agent skills, Copilot Studio knowledge, and query catalog for FOCUS 1.3 and 1.4, and add a code-review skill.<br>

<br>

## Power BI reports

- Completed - Data ingestion report – Report to monitor FinOps hubs data ingestion and data quality warnings.<br>
- Completed - Raw exports – Support for raw exports without FinOps hubs.<br>
- Completed - Tags demo – Example of how to use tags.<br>
- Completed - KQL and Microsoft Fabric reports – DirectQuery reports for Azure Data Explorer and Microsoft Fabric Real-Time Intelligence.<br>
- Completed - Expanded report suite – Governance, Workload optimization, Rate optimization, and Invoicing and chargeback reports.<br>
- Completed (v15) - Azure Resource Graph pagination and FOCUS 1.2 storage compatibility ([Issue #1768](https://github.com/microsoft/finops-toolkit/issues/1768), [Issue #2174](https://github.com/microsoft/finops-toolkit/issues/2174), [Issue #2332](https://github.com/microsoft/finops-toolkit/issues/2332), [Issue #2347](https://github.com/microsoft/finops-toolkit/issues/2347)) – Subscription-batched Resource Graph pagination in Governance and Workload optimization reports, FOCUS 1.2 `SkuMeter` and ISO 8601 `x_SkuTerm` compatibility, and instance size flexibility open data integration.<br>
- In development (v16) - FOCUS 1.4 schema update ([PR #2209](https://github.com/microsoft/finops-toolkit/pull/2209)) – Update Power BI reports to the FOCUS 1.4 (`v1_4`) schema.<br>
- In development (v16) - Incremental refresh and query performance ([PR #2353](https://github.com/microsoft/finops-toolkit/pull/2353), [Issue #2336](https://github.com/microsoft/finops-toolkit/issues/2336), [PR #2337](https://github.com/microsoft/finops-toolkit/pull/2337)) – Support partitioned incremental refresh on the storage `Costs` table, optimize tag promotion CPU performance, and expand unattached disks reporting.<br>
- In development (v16) - Community reports and data-only template ([PR #1843](https://github.com/microsoft/finops-toolkit/pull/1843), [PR #1708](https://github.com/microsoft/finops-toolkit/pull/1708)) – Community Power BI reports repository and a data-only Power BI report template.<br>
- Not started - Update notification – Show an update notification when new releases are available.<br>

<br>

## Cost optimization workbook

- Completed (v15) - General updates and KQL join accuracy ([PR #2170](https://github.com/microsoft/finops-toolkit/pull/2170), [PR #2225](https://github.com/microsoft/finops-toolkit/pull/2225)) – FinOps Framework terminology alignment and explicit KQL join fixes across savings plan and Azure Hybrid Benefit queries.<br>
- Not started - FinOps hubs support – Merge cost from FinOps hubs with recommendations.<br>

<br>

## Optimization engine

- Completed - **New tool**: Azure Optimization Engine – Custom recommendation engine.<br>
- Completed - SQL database Microsoft Entra ID authentication – Replace SQL Server authentication with Microsoft Entra ID-only authentication.<br>
- Completed - FinOps hubs recommendations export – Export recommendations to FinOps hubs storage.<br>
- Completed (v15) - Reference documentation, DCR ingestion, and ISF open data ([Issue #1271](https://github.com/microsoft/finops-toolkit/issues/1271), [PR #2193](https://github.com/microsoft/finops-toolkit/pull/2193), [Issue #2090](https://github.com/microsoft/finops-toolkit/issues/2090), [Issue #2300](https://github.com/microsoft/finops-toolkit/issues/2300)) – Comprehensive architecture reference, Log Analytics Data Collection Rule (DCR) ingestion migration, and instance size flexibility open data integration with retired-SKU reservation visibility.<br>
- In development (v16) - Reservation workbook ratio scale and KQL join refinements ([Issue #2309](https://github.com/microsoft/finops-toolkit/issues/2309), [Issue #2226](https://github.com/microsoft/finops-toolkit/issues/2226)) – Align reservation workbook quantity scales and KQL join patterns.<br>

<br>

## PowerShell

- Completed (v15) - FinOps Multitool ([PR #2155](https://github.com/microsoft/finops-toolkit/pull/2155)) – Interactive `Start-FinOpsMultitool` cross-platform terminal UI for FinOps scanning and exploration.<br>
- Completed (v15) - Open data commands ([PR #2298](https://github.com/microsoft/finops-toolkit/pull/2298)) – `Get-FinOpsCommitmentDiscountEligibility` and `Get-FinOpsInstanceSizeFlexibility` commands.<br>
- Completed (v15) - Local FinOps hub initialization and export fixes ([PR #2187](https://github.com/microsoft/finops-toolkit/pull/2187), [Issue #2255](https://github.com/microsoft/finops-toolkit/issues/2255), [Issue #2063](https://github.com/microsoft/finops-toolkit/issues/2063), [PR #2304](https://github.com/microsoft/finops-toolkit/pull/2304)) – `Initialize-FinOpsHubLocal` for local Kusto emulator testing, UTC calendar date handling in `Start-FinOpsCostExport`, complete `-RunHistory`, and hub version parsing fixes.<br>
- In development (v16) - FinOps Multitool diagnostics and generated docs ([Issue #2335](https://github.com/microsoft/finops-toolkit/issues/2335), [PR #935](https://github.com/microsoft/finops-toolkit/pull/935)) – Expand `Start-FinOpsMultitool` diagnostic accuracy, read-only test guards, and entry-point help, and generate PowerShell documentation from code.<br>
- Not started - Deploy-FinOpsWorkbook – Deploy toolkit workbooks.<br>

<br>

## Open data

- Completed - Service model – Add ServiceModel to the services open data file.<br>
- Completed (v15) - Instance size flexibility dataset ([Issue #2090](https://github.com/microsoft/finops-toolkit/issues/2090), [PR #2308](https://github.com/microsoft/finops-toolkit/pull/2308)) – Automated weekly dataset from the Azure Reservations Catalogs API replacing deprecated `ccmstorageprod` CSV files across all Azure regions.<br>
- Completed (v15) - Commitment discount eligibility validation and FOCUS alignment ([PR #2164](https://github.com/microsoft/finops-toolkit/pull/2164), [PR #2251](https://github.com/microsoft/finops-toolkit/pull/2251), [Issue #2279](https://github.com/microsoft/finops-toolkit/issues/2279)) – Dual-traversal verified refresh, FOCUS spend and usage category alignment, and CI family-count regression protection.<br>
- In development (v16) - Advisor recommendation types and unified service metadata ([Issue #1255](https://github.com/microsoft/finops-toolkit/issues/1255), [PR #1267](https://github.com/microsoft/finops-toolkit/pull/1267), [PR #1292](https://github.com/microsoft/finops-toolkit/pull/1292)) – Add an Azure Advisor `RecommendationTypes` dataset and merge resource types and services open data.<br>

<br>

## New tools

- Completed - **New tool**: FinOps alerts ([Milestone #24](https://github.com/microsoft/finops-toolkit/milestone/24)) – Automated idle-resource detection and cost optimization notifications.<br>

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
