---
layout: default
title: FinOps hubs - Open, extensible, scalable cost governance
nav_order: 2
description: 'FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization for the enterprise.'
permalink: /hubs
#customer intent: As a Finops practitioner, I need to learn about FinOps hubs
---

<span class="fs-9 d-block mb-4">FinOps hubs</span>
Open, extensible, and scalable cost governance for the enterprise.
{: .fs-6 .fw-300 }

[Deploy](#deploy){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Documentation](#docs){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

---

<a name="overview"></a>

## Open, extensible, and scalable cost governance for the enterprise

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs.

<br>

<a name="whats-new"></a>

## What's new in February 2025 (v0.8)

February introduced a simpler public networking architecture, a new Data Explorer dashboard, major Power BI optimizations and design improvements, and many small fixes and improvements.

[See all changes](https://aka.ms/ftk/changes#finops-hubs-v08){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

<a name="features"></a>

## Understand and optimize cost and usage

<table border="0">
<tr>
    <td>
        <strong>📥 Ingest FinOps data</strong><br>
        Automate data ingestion into Azure Data Explorer to facilitate big data analytics at scale.
    </td>
    <td>
        <strong>📊 Standardized reporting</strong><br>
        Flexible Power BI reports and Data Explorer dashboards using the FinOps Open Cost and Usage Specification (FOCUS).
    </td>
    <td>
        <strong>🏗️ Extensible platform</strong><br>
        Bring your own data or customize data pipelines to build a custom allocation model, specialized alerts, and more.
    </td>
</tr>
<tr>
    <td>
        <strong>☁️ Consolidate accounts and clouds</strong><br>
        Centralize FinOps data across multiple subscriptions, accounts, and clouds.
    </td>
    <td>
        <strong>🛡️ Secure processing</strong><br>
        Secure financial and organizational data on a private, isolated network you control and govern.
    </td>
    <td>
        <strong>🪛 Data cleansing and augmentation</strong><br>
        FinOps hubs tunes data to fill gaps and improve overall data quality and completeness.
    </td>
</tr>
</table>

<br>

<a name="deploy"></a>

## Deploy FinOps hub

Create a new or update an existing FinOps hub instance.

<table border="0">
<tr>
    <td>
        <strong>1️⃣ Register EventGrid</strong><br>
        Open the desired subscription in the Azure portal, select <b>Settings</b> > <b>Resource providers</b>, select the <b>Microsoft.EventGrid</b> row, then select the <b>Register</b> command at the top of the page. Registration might take a few minutes.
    </td>
    <td>
        <strong>2️⃣ Plan your network architecture</strong><br>
        If interested in private networking, work with your network admin to configure network peering and routing. FinOps hubs run on an isolated network, so this is critical to accessing. [Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/private-networking)
    </td>
    <td>
        <strong>3️⃣ Deploy the template</strong><br>
        [Deploy to Azure](https://aka.ms/finops/hubs/deploy){: .btn .btn-primary .mb-4 .mb-md-0 .mr-4 }
    </td>
</tr>
<tr>
    <td>
        <strong>4️⃣ Configure scopes to monitor</strong><br>
        FinOps hubs use Cost Management exports to load the data you want to monitor. You can configure exports manually or grant access to your hub to manage exports for you. [Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-scopes)
    </td>
    <td>
        <strong>5️⃣ Set up reports and dashboards</strong><br>
        [Set up Power BI](https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/setup#set-up-your-first-report){: .btn .mb-4 .mb-md-0 .mr-4 }
        [Set up ADX dashboard](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/setup-dashboard){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
</tr>
</table>

[💜 Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.8/bladeName/Hubs/featureName/Marketing.Deploy){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

<a name="pricing"></a>

## Estimated cost for FinOps hubs

FinOps hubs starts at $120/mo + $10 per $1 million in monitored spend.

Costs may be lower depending on your negotiated and commitment discounts.

<br>

<a name="docs"></a>

## Learn more from documentation

<table border="0">
<tr>
    <td>
        <strong>🗃️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-model">Data model</a></strong><br>
        Tables and functions available in FinOps hubs to support custom queries and reports.
    </td>
    <td>
        <strong>📗 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/help/data-dictionary">Data dictionary</a></strong><br>
        Explore the columns available in FinOps hubs with Data Explorer and Power BI reports.
    </td>
    <td>
        <strong>⚙️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-processing">Data processing</a></strong><br>
        How data is processed in Data Factory pipelines and Data Explorer ingestion.
    </td>
</tr>
<tr>
    <td>
        <strong>📦 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/template">Deployment template</a></strong><br>
        What's included in the FinOps hub deployment template &ndash; inputs, deployed resources, and output values.
    </td>
    <td>
        <strong>🧮 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/compatibility">Compatibility guide</a></strong><br>
        Identify breaking changes in each release that may require additional work when upgrading.
    </td>
    <td>
        <strong>🛠️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/upgrade">Upgrade guide</a></strong><br>
        Things to keep in mind when upgrading an existing FinOps hub instance.
    </td>
</tr>
</table>

[Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[💜 Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.8/bladeName/Hubs/featureName/Marketing.Docs){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>
