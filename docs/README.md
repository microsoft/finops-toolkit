# FinOps toolkit documentation

![Version: 0.0.1](https://img.shields.io/badge/version-0.0.1-blue) &nbsp; ![Status: In progress](https://img.shields.io/badge/status-in_progress-blue)

The **FinOps toolkit** seeks to provide a collection of customizable ARM templates that can be used to build homegrown cost management and optimization solutions. The project is in an early prerelease stage which establishes the foundation for what we call a **FinOps hub** – a reliable, trustworthy platform for cost analytics, insights, and optimization.

<!--
FinOps hubs aspire to be **virtual command centers** for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs.

FinOps hubs are:

- Based on open standards.
- Built to scale for the largest organizations.
- Designed to support full extensibility.
-->

<br>

On this page:

- [Summary](#summary)
- [Creating a new FinOps hub](#creating-a-new-finops-hub)
- [Customizing further](#customizing-further)
- [Roadmap](#roadmap)
- [Get involved](#get-involved)
- [Changelog](#changelog)

---

## Summary

The FinOps toolkit deploys a hub instance ([template](templates/finops-hub.md)), which includes the following resources:

- Storage account (Data Lake Storage Gen2) to hold all cost data.
- Data factory to manage data ingestion and cleanup.

Once deployed, you can create new exports in Cost Management and use out of the box Power BI reports to customize and share reports with your stakeholders.

<img alt="Screenshot of the cost summary report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882658-45f026f1-c895-48ca-81e2-35765af8e29e.png">
<img alt="Screenshot of the services cost report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882700-4e04b589-0580-4e49-9b40-9f5948792975.png">
<img alt="Screenshot of the commitment-based discounts coverage report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882916-bb7ecfa3-d092-4ae2-88e1-7a0425c14dca.png">

<br>

## Creating a new FinOps hub

1. [Deploy the **finops-hub** template](./deploy).
2. [Create a new cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:
   - **Metric** = `Amortized cost`
   - **Export type** = `Daily export of month-to-date costs`
     > 💡 _**Tip:** Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range._
   - **Storage account** = (Use subscription/resource from step 1)
   - **Container** = `ms-cm-exports`
   - **Directory** = (Use the resource ID of the scope you're exporting, but remove the first "/")
     > ℹ️ _You are welcome to use any directory name you want. Using the scope ID is how we plan to do it in order to avoid collisions. You will see this added in a future release._
3. Run your export.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.
4. Download one or more of the available Power BI starter templates:
   - [Cost summary](./reports/cost-summary.md) for standard cost roll-ups.
   - [Commitment discounts](./reports/commitment-discounts.md) for commitment-based savings utilization and coverage.
5. [Connect Power BI to your hub](./reports/README.md#setup-a-finops-toolkit-report)

> ![Version 0.0.2](https://img.shields.io/badge/version-0.0.2-lightgrey) &nbsp; ![Status: Proposed](https://img.shields.io/badge/status-proposed-lightgrey) &nbsp;<sup>→</sup>&nbsp; [![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/60)](https://github.com/microsoft/cloud-hubs/issues/60)
>
> 🆕 _Remove steps 2 and 3 when we have self-managed exports._

<br>

## Customizing further

FinOps toolkit is intended to be customized. Here are a few pointers to get you started:

| Area            | Notes                                                                                                                                                                                                                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Power BI        | Power BI reports are starter templates and intended to be customized. We encourage you to customize as needed. [Learn more](./reports).                                                                                                                                                                               |
| Data Factory    | Data Factory is used to ingest and clean up data. Do not edit the built-in pipelines. For details about the built-in pipelines, see [hub resources](./templates/modules/hub.md#resources).                                                                                                                            |
| Storage account | Data is ingested into the `ms-cm-exports` container. Do not store anything other than Cost Management exports in this container. In v0.0.2 and earlier, you can modify files, but this will need to happen after the built-in pipelines are run. Don't remove or rename columns, as that will break Power BI reports. |
| Templates       | We recommend not changing the template directly. Instead, create a new bicep module and reference `finops-hub/main.bicep` or `hub.bicep` directly. If you need to change `hub.bicep`, be sure to track those changes and re-apply them when upgrading to the latest release. [Learn more](./templates).               |

> ![Version 0.0.2](https://img.shields.io/badge/version-0.0.2-lightgrey) &nbsp; ![Status: Proposed](https://img.shields.io/badge/status-proposed-lightgrey) &nbsp;<sup>→</sup>&nbsp; [![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/60)](https://github.com/microsoft/cloud-hubs/issues/60)
>
> 🆕 _Change the notes for storage to: Data is ingested into the `ms-cm-exports` container and transformed when moved into the `ingestion` container. Do not store use the `ms-cm-exports` container for anything other than Cost Management exports. If manipulating data, please do that in the `ingestion` container after the transform pipeline completes. Don't remove or rename columns, as that can break Power BI reports._

If you access data in storage or are creating or customizing Power BI reports, please refer to the [data dictionary](data.md) for details about the available columns.

<br>

## Roadmap

We track the short-term roadmap for FinOps toolkit as [releases](https://github.com/microsoft/cloud-hubs/labels/Type%3A%20Release%20%F0%9F%9A%80). Each release includes overarching goals, tasks broken down into sub-releases, links to discussions for each sub-release, and tentative stretch tasks.

Please use discussions if you have questions, comments, or requests for any specific release. This will ensure everything gets triaged and not lost.

<br>

## Get involved

FinOps toolkit is an open source project. We have many ideas on the long-term vision, but are more interested in learning from you and seeing how the community drives the product. There are many ways you can contribute to the project from participating in discussions and requesting features to reviewing and submitting pull requests. To get started, refer to our [Contribution guide](../CONTRIBUTING.md).

<br>

## Changelog

All the main changes are tracked within the [Changelog](./changelog.md). For additional details, refer to the [commit history](https://github.com/microsoft/cloud-hubs/commits/main).
