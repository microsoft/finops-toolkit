---
layout: default
title: FinOps hubs
browser: FinOps hubs - Open, extensible, scalable cost governance
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

<div id="whats-new" class="m-0 p-4" style="background-color:#edf; border:solid 1px #609;">
    <h3 class="m-0 mb-4">What's new in February 2025<span class="ftk-version">v0.8</span></h3>
    <p class="mt-2 mb-0">
        February introduced a simpler public networking architecture, a new Data Explorer dashboard, major Power BI optimizations and design improvements, and many small fixes and improvements.
    </p>
    <p class="mt-2 mb-0"><a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>

<a name="features"></a>

## Understand and optimize cost and usage

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>📥 Ingest FinOps data</div>
        <div>Automate data ingestion into Azure Data Explorer to facilitate big data analytics at scale.</div>
    </div>
    <div class="ftk-tile">
        <div>📊 Standardized reporting</div>
        <div>Flexible reports in Power BI and Data Explorer using the FinOps Open Cost and Usage Specification.</div>
    </div>
    <div class="ftk-tile">
        <div>🏗️ Extensible platform</div>
        <div>Bring your own data, build a custom allocation model, trigger custom alerts, and more.</div>
    </div>
    <div class="ftk-tile">
        <div>☁️ Consolidate accounts</div>
        <div>Centralize FinOps data across multiple subscriptions, accounts, and clouds.</div>
    </div>
    <div class="ftk-tile">
        <div>🛡️ Secure processing</div>
        <div>Secure financial and organizational data on a private, isolated network you control and govern.</div>
    </div>
    <div class="ftk-tile">
        <div>🪛 Data preparation</div>
        <div>FinOps hubs tunes data to fill gaps and improve overall data quality and completeness.</div>
    </div>
</div>

<br>

<a name="deploy"></a>

## Deploy FinOps hub

Create a new or update an existing FinOps hub instance.

<div class="ftk-instructions">
    <div class="ftk-step">
        <button class="ftk-accordion">1️⃣&nbsp; Register EventGrid</button>
        <div>
            <p>
                Register the <b>Microsoft.EventGrid</b> resource provider for your subscription.
            </p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2">Go to subscriptions</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">2️⃣&nbsp; Plan your network architecture</button>
        <div>
            <p>
                Work with your network admin to configure peering and routing. FinOps hubs run on an isolated network, so this is critical to accessing.
            </p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/private-networking">Plan for private networking</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">3️⃣&nbsp; Deploy the template</button>
        <div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://aka.ms/finops/hubs/deploy">Deploy to Azure</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">4️⃣&nbsp; Configure scopes to monitor</button>
        <div>
            <p>
                Configure exports manually or grant access to your hub to manage exports for you.
            </p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-scopes">Configure scopes</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">5️⃣&nbsp; Set up reports and dashboards</button>
        <div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/setup-dashboard">Set up ADX dashboard</a>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/setup#set-up-your-first-report">Set up Power BI</a>
            </p>
        </div>
    </div>
</div>

<br><a class="btn mb-4 mb-md-0 mr-4" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.8/bladeName/Hubs/featureName/Marketing.Deploy">💜 Give feedback</a>

<br>

<div id="pricing" class="m-0 p-4" style="background-color:#efe; border:solid 1px #090;">
    <h3 class="m-0 mb-4">Estimated cost for FinOps hubs</h3>
    <p class="mt-2 mb-0">FinOps hubs starts at $120/mo + $10 per $1 million in monitored spend.</p>
    <p class="mt-2 mb-0">Costs may be lower depending on your negotiated and commitment discounts.</p>
</div>

<br>

<a name="docs"></a>

## Learn more from documentation

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>🗃️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-model">Data model</a></div>
        <div>Tables and functions available in FinOps hubs to support custom queries and reports.</div>
    </div>
    <div class="ftk-tile">
        <div>📗 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/help/data-dictionary">Data dictionary</a></div>
        <div>Explore the columns available in FinOps hubs with Data Explorer and Power BI reports.</div>
    </div>
    <div class="ftk-tile">
        <div>⚙️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-processing">Data processing</a></div>
        <div>How data is processed in Data Factory pipelines and Data Explorer ingestion.</div>
    </div>
    <div class="ftk-tile">
        <div>📦 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/template">Deployment template</a></div>
        <div>Details about what's included in the FinOps hub deployment template.</div>
    </div>
    <div class="ftk-tile">
        <div>🧮 <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/compatibility">Compatibility guide</a></div>
        <div>Identify breaking changes in each release that may require additional work when upgrading.</div>
    </div>
    <div class="ftk-tile">
        <div>🛠️ <a href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/upgrade">Upgrade guide</a></div>
        <div>Things to keep in mind when upgrading an existing FinOps hub instance.</div>
    </div>
</div>

<a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview">Learn more</a>
<a class="btn mb-4 mb-md-0 mr-4" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.8/bladeName/Hubs/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
