---
layout: default
parent: Optimization Engine
title: Reports
nav_order: 10
description: 'Visualize the Azure Optimization Engine rich recommendations and insights.'
permalink: /optimization-engine/reports
---

<span class="fs-9 d-block mb-4">Reports</span>
Visualize the Azure Optimization Engine rich recommendations and insights.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [📒 Power BI recommendations report](#-power-bi-recommendations-report)
- [📒 Workbooks](#-workbooks)

</details>

## 📒 Power BI recommendations report

AOE includes a [Power BI report](http://aka.ms/AzureOptimizationEngine/powerbi) for visualizing recommendations. To use it, you have first to change the data source connection to the SQL Database you deployed with the AOE. In the Power BI top menu, choose Transform Data > Data source settings.

![Open the Transform Data > Data source settings menu item](../assets/images/aoe/powerbi-transformdatamenu.jpg "Transform Data menu options")

Then click on "Change source" and change to your SQL database server URL (don't forget to ensure your SQL Firewall rules allow for the connection).

![Click on Change source and update SQL Server URL](../assets/images/aoe/powerbi-datasourcesettings.jpg "Update data source settings")

If the connection fails at the first try, this might be because the SQL Database was paused (it was deployed in the cheap Serverless plan). At the next try, the connection should open normally.

The report was built for a scenario where you have an "environment" tag applied to your resources. If you want to change this or add new tags, open the Transform Data menu again, but now choose the Transform data sub-option. A new window will open. If you click next in "Advanced editor" option, you can edit the data transformation logic and update the tag processing instructions.

![Open the Transform Data > Transform data menu item, click on Advanced editor and edit accordingly](../assets/images/aoe/powerbi-transformdata.jpg "Update data transformation logic")

### Recommendations overview

![An overview of all your optimization recommendations](../assets/images/aoe/powerbi-dashboard-overview.jpg "An overview of all your optimization recommendations")

### Cost opportunities overview

![An overview of your Cost optimization opportunities](../assets/images/aoe/powerbi-dashboard-costoverview.jpg "An overview of your Cost optimization opportunities")

### Augmented VM right-size overview

![An overview of your VM right-size recommendations](../assets/images/aoe/powerbi-dashboard-vmrightsizeoverview.jpg "An overview of your VM right-size recommendations")

### Fit score history for a specific recommendation

![Fit score history for a specific recommendation](../assets/images/aoe/powerbi-dashboard-fitscorehistory.jpg "Fit score history for a specific recommendation")

## 📒 Workbooks

With AOE's Log Analytics Workbooks, you can explore many perspectives over the data that is collected every day. For example, costs growing anomalies, Microsoft Entra ID and Azure RM principals and roles assigned, how your resources are distributed, how your Block Blob Storage usage is distributed, how your Azure Benefits usage is distributed (supports only Enterprise Agreement customers) or exploring Azure Policy compliance results over time.

![An overview of all your optimization recommendations](../assets/images/aoe/workbooks-recommendations-overview.jpg "An overview of all your optimization recommendations")

![An overview of your Cost optimization opportunities](../assets/images/aoe/workbooks-recommendations-costoverview.jpg "An overview of your Cost optimization opportunities")

![Costs growing anomalies](../assets/images/aoe/workbooks-costsgrowing-anomalies.jpg "Costs growing anomalies")

![Virtual Machines perspectives over time](../assets/images/aoe/workbooks-resourcesinventory-vms.jpg "Virtual Machines perspectives over time")

![Microsoft Entra ID/Azure Resource Manager principals and roles summary, with service principal credentials expiration](../assets/images/aoe/workbooks-identitiesroles-summary.jpg "Microsoft Entra ID/Azure Resource Manager principals and roles summary, with service principal credentials expiration")

![Privileged Microsoft Entra ID roles and assignment history](../assets/images/aoe/workbooks-identitiesroles-rolehistory.jpg "Priviliged Microsoft Entra ID roles and assignment history")

![Block Blob Storage usage analysis with Lifecycle Management recommendations](../assets/images/aoe/workbooks-blockblobusage-standardv2.jpg "Block Blob Storage usage analysis with Lifecycle Management recommendations")

![Azure Benefits usage analysis with a comparison between Reservations and On-Demand/Savings Plan prices](../assets/images/aoe/workbooks-benefitsusage-reservations.jpg "Azure Benefits usage analysis with a comparison between Reservations and On-Demand/Savings Plan prices")

![Policy Compliance state, with evolution over time](../assets/images/aoe/workbooks-policycompliance.jpg "Policy Compliance state, with evolution over time")
