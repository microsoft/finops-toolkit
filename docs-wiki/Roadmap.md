<!-- markdownlint-disable MD041 -->

The Microsoft FinOps toolkit is an open-source collection of tools and resources that help you learn, adopt, and implement FinOps capabilities in the Microsoft Cloud. This document outlines the key themes and directional initiatives identified by the [[Governing board]] based on direct feedback and inputs from the [[Advisory council]] on behalf of toolkit contributors and consumers. As of May 2024, the FinOps toolkit will target publishing new releases at the end of every month, which includes updates to this roadmap and the [changelog](https://aka.ms/ftk/changes).

📅 Roadmap term: **January - December 2024**

<br>

On this page:

- [🎯 Key themes for 2024](#-key-themes-for-2024)
- [🛠️ General](#️-general)
- [🍎 Learning resources](#-learning-resources)
- [🏦 FinOps hubs](#-finops-hubs)
- [📊 Power BI reports](#-power-bi-reports)
- [📒 Cost optimization workbook](#-cost-optimization-workbook)
- [🖥️ PowerShell](#️-powershell)
- [🌐 Open data](#-open-data)
- [🆕 New tools](#-new-tools)

---

This roadmap is a culmination of feedback from toolkit contributors, consumers, and the FinOps community as a whole. The roadmap provides a high-level view of where the toolkit is directionally headed by summarizing key themes and initiatives but is not a complete list of every change that can or will be made. We share the roadmap to garner early feedback. Ultimately, contributions are driven by the FinOps toolkit community.

While our community is growing, we don't have dedicated staff and cannot commit to explicit dates. As a result, not all items will be completed within the year. If you would like to see something added, please [create an issue](https://aka.ms/ftk/idea) or [start a discussion](https://aka.ms/ftk/discuss). And of course, we welcome any contribution via pull request.

<br>

## 🎯 Key themes for 2024

2023 was focused on establishing a baseline for a few of the core tools included in the toolkit. As we look forward to 2024, the [[Governing board]] has identified the following high-level themes:

- **End-to-end FinOps**<br>
  Expand the FinOps toolkit to encapsulate everything organizations need to learn and implement FinOps through Microsoft products, solutions, and services.<br>&nbsp;
- **Solidify the foundation**<br>
  Flesh out the infrastructure needed to scale open-source contributions and unblock key design principles of tools and resources within the toolkit, like DevOps automation and extensibility to streamline the contributor and release workflows and native support for optional or custom functionality.<br>&nbsp;
- **Enable the community**<br>
  Expand and evolve the help and support resources and options available for the broader community of contributors and consumers.<br>&nbsp;
- **Community-driven evolution**<br>
  Continuously integrate community insights and feedback to refine and enhance tools and resources to evolve in alignment with user needs and industry trends.

<br>

## 🛠️ General

✅ FOCUS 1.0 (June, [Issue #778](https://github.com/microsoft/finops-toolkit/issues/778)) – Add support for FOCUS 1.0 GA across tools and services.<br>
🔜 Office hours – Monthly call to get real-time help and support for FinOps toolkit solutions.<br>
🔜 Official toolkit support – Get help from Microsoft Support.<br>
🔜 Demo environment – Publicly available demo environment.<br>
🔜 Release automation – Automate the end-to-end CI/CD release process.<br>
🔜 FOCUS 1.1 (November) – Add support for FOCUS 1.1 across tools and services.<br>

<br>

## 🍎 Learning resources

✅ Learning resources – Add learning resources to documentation.<br>
✅ FinOps documentation – Add documentation for how to implement FinOps.<br>
✅ Microsoft Learn training modules – Self-paced FinOps training on Microsoft Learn.<br>
✅ FinOps Framework updates ([Milestone #21](https://github.com/microsoft/finops-toolkit/milestone/21)) – Update FinOps capability guides for FinOps Framework 2024 updates.<br>
🔄️ FinOps toolkit on Microsoft Learn – Publish toolkit docs into Microsoft Learn.<br>
🔜 FinOps toolkit overview deck – Slide deck to summarize FinOps toolkit solutions.<br>

<br>

## 🏦 FinOps hubs

✅ Remote hubs ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Ingest cost data from other tenants.<br>
✅ Managed exports ([Milestone #19](https://github.com/microsoft/finops-toolkit/milestone/19)) – Let FinOps hubs manage exports for you.<br>
🔄️ Analytics engine ([Issue #57](https://github.com/microsoft/finops-toolkit/issues/57)) – Ingest cost data into an Azure Data Explorer cluster.<br>
🔄️ Private endpoints ([Milestone #22](https://github.com/microsoft/finops-toolkit/milestone/22)) – Add support for private endpoints.<br>
🔄️ Bring your own KeyVault ([PR #573](https://github.com/microsoft/finops-toolkit/pull/573)) – Add support for referencing an existing KeyVault instance.<br>
🔜 Troubleshooting guide ([Issue #734](https://github.com/microsoft/finops-toolkit/issues/734)) – Detailed walkthrough of how to resolve and get support for common issues.<br>
🔜 Auto-backfill – Backfill historical data from Microsoft Cost Management.<br>
🔜 Retention – Configure how long you want to keep data in storage.<br>
🔜 More export types – Add support for all Cost Management export types.<br>
🔜 Extensibility – App model to support optional components.<br>
🔜 Management UX – Website to create and manage resources.<br>

<br>

## 📊 Power BI reports

✅ Data ingestion report – New report to monitor FinOps hubs data ingestion.<br>
🔜 Warnings – Show warnings to raise awareness about known issues.<br>
🔜 Tags demo – Include example of how to use tags.<br>
🔜 Raw exports – Add support for raw exports without FinOps hubs.<br>
🔜 Microsoft Fabric – Add support for data hosted in Microsoft Fabric.<br>
🔜 Update notification – Show an update notification when new releases are available.<br>

<br>

## 📒 Cost optimization workbook

🔄️ General updates – Ongoing updates based on the latest feedback.<br>
🔜 FinOps hubs support – Merge cost from FinOps hubs with recommendations.<br>

<br>

## 🔍 Optimization engine

✅ **New tool**: Azure Optimization Engine – Custom recommendation engine.<br>
🔄️ SQL database Entra ID authentication – Replace SQL Server authentication with Entra ID-only authentication.<br>

<br>

## 🖥️ PowerShell

🔜 Deploy-FinOpsWorkbook – Deploy toolkit workbooks.<br>

<br>

## 🌐 Open data

✅ Service model – Add ServiceModel to the services open data file.<br>
🔄️ Update all data – Ongoing updates all open data file with each release.<br>

<br>

## 🆕 New tools

🔄️ **New tool**: Cost optimization notifications ([Milestone #24](https://github.com/microsoft/finops-toolkit/milestone/24)) – Email notifications when optimization opportunities are identified.<br>

<br>
