---
title: Configure Data Explorer dashboard for FinOps hubs
description: Deploy a pre-built Azure Data Explorer dashboard for FinOps hubs to start analyzing cost and usage for your accounts.
author: bandersmsft
ms.author: banders
ms.date: 02/21/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want to deploy an Azure Data Explorer dashboard so that I can analyze my costs.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure Data Explorer dashboard

Azure Data Explorer is a fast and highly scalable data exploration service. You can explore data in the [Azure Data Explorer web application](https://dataexplorer.azure.com) by running queries or building dashboards. A dashboard is a collection of queries visualized as tiles and organized into pages. The FinOps toolkit provides a custom dashboard with pages design to facilitate FinOps capabilities. This article walks you through the process of deploying and configuring this dashboard.

<br>

## Prerequisites

Before you begin, you must have:

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- Have database viewer access to the Data Explorer **Hub** and **Ingestion** databases.

This walkthrough does not incur any cost; however, maintaining an active Data Explorer cluster does incur cost.

<br>

## Deploying the dashboard

1. Download the [latest dashboard template](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json).
2. Copy the Data Explorer cluster URI:
   1. Go to the [list of resource groups](https://portal.azure.com/#browse/resourcegroups) in the Azure portal.
   2. Select the resource group where your FinOps hub instance was deployed.
   3. Select **Settings** > **Deployments** > **hub** > **Outputs**.
   4. Copy the **clusterUri** output value.
3. Create a dashboard from the template:
   1. Go to [Azure Data Explorer dashboards](https://dataexplorer.azure.com/dashboards).
   2. Select the down arrow next to the **New dashboard** button.<br>
      :::image type="content" source="./media/configure-dashboard/new-dashboard-menu.png" alt-text="Screenshot of the new dashboard menu with an Import dashboard from file menu item." lightbox="./media/configure-dashboard/new-dashboard-menu.png" :::
   3. Select the **Import dashboard from file** option.
   4. Browse to and select the **finops-hub-dashboard.json** file from step one.
   5. Specify the desired name and select **Create**.
4. Connect the dashboard to your cluster:
   1. At the top of the page, select **Data sources**.
   2. In the pane on the right, select the pencil under **Hub**.
   3. Paste the **Cluster URI** from step 2.4.
   4. Select the **Connect** button and then select the **Hub** database.
   5. Select **Apply** and then **Close**.

You can now explore the FinOps hub dashboard. Data Explorer dashboards are only accessible to the person who creates them by default. And access to the data is controlled at the database level, so access to a dashboard does not grant access to the underlying data. Be sure to share access to the dashboard and the **Hub** and **Ingestion** databases in order for people to see the functional dashboard.

<br>

## Customizing the dashboard

The FinOps hub dashboard is a sample dashboard that is intended to be customized. We encourage you to customize the dashboard to meet specific stakeholder needs and copy queries to other dashboards. To learn more about creating and customizing dashboards, see [Visualize data with Azure Data Explorer dashboards](/azure/data-explorer/azure-data-explorer-dashboards).

Note that customized dashboards can't be merged from the Data Explorer dashboard editor. If you need to customize the dashboard, consider using Git or another source control solution.

<br>

## Alternatives to Data Explorer dashboards

While Data Explorer dashboards are free and simple to configure, you may have requirements that necessitate another reporting solution. Some examples might be bringing in data outside of Data Explorer or merging with existing reports used by stakeholders across the organization. We recommend everyone deploy the FinOps hub dashboard, but if you need other options, consider utilizing the [FinOps toolkit Power BI reports](../power-bi/reports.md).

The KQL reports are tuned to take advantage of the performance enhancements offered by Azure Data Explorer. This is the fastest, most scalable option for organizations analyzing over $2 million per month in spend or more than one year of data in Power BI.

You may also consider using [Azure workbooks](/azure/azure-monitor/visualize/workbooks-overview) in the Azure portal or utilizing other tools that support connecting to Azure Data Explorer, like Excel, Grafana, and Tableau. To learn more about these and other tools that support Azure Data Explorer, see [Visualization integrations overview](/azure/data-explorer/integrate-visualize-overview).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.8/bladeName/Hubs/featureName/ConfigureScopes)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure workbooks](/azure/azure-monitor/visualize/workbooks-overview)

Related solutions:

- [FinOps hubs](finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
