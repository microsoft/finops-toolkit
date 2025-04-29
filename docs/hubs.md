---
layout: default
title: FinOps hubs
browser: FinOps hubs - Open, extensible, scalable cost governance
nav_order: 20
description: 'FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization for the enterprise.'
permalink: /hubs
#customer intent: As a Finops practitioner, I need to learn about FinOps hubs
---

<span class="fs-9 d-block mb-4">FinOps hubs</span>
Open, extensible, and scalable cost governance for the enterprise.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#deploy">Deploy</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview">Documentation</a>

---

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs.

<div id="whats-new" class="ftk-new">
    <h3>What's new in March 2025<span class="ftk-version">v0.9</span></h3>
    <p>
        In March, FinOps hubs saw a revamp of reservation recommendations, expansion of managed exports to cover all Cost Management datasets, and many small fixes and improvements.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
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

<div id="pricing" class="ftk-pricing">
    <h3>Estimated cost for FinOps hubs</h3>
    <p>FinOps hubs starts at $120/mo + $10 per $1 million in monitored spend.</p>
    <p>Costs may be lower depending on your negotiated and commitment discounts.</p>
</div>
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
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2">Go to subscriptions</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">2️⃣&nbsp; Plan your network architecture</button>
        <div>
            <p>
                Do you prefer public or private network routing?
            </p>
            <div class="ftk-gallery ftk-50">
                <div class="ftk-tile">
                    <div>🌐 Public routing</div>
                    <div>
                        <p>
                            Most common. Resources are reachable from the open internet. Access is controlled via RBAC.
                        </p>
                        <p>
                            Does not require additional configuration.<br><br>&nbsp;
                        </p>
                        <p>
                            <a class="btn mb-4 mb-md-0 mr-4" href="" style="visibility:hidden; width:100px">&nbsp;</a>
                        </p>
                    </div>
                </div>
                <div class="ftk-tile">
                    <div>🏢 Private routing</div>
                    <div>
                        <p>
                            Most secure. Resources are only reachable from peered networks. Access is controlled via RBAC.
                        </p>
                        <p>
                            Work with your network admin to configure peering and routing so the FinOps hubs isolated network is reachable from your network.
                        </p>
                        <p>
                            <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/private-networking">Plan for private networking</a>
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">3️⃣&nbsp; Deploy the template</button>
        <div>
            <p>
                FinOps hubs works best with the <strong>Owner</strong> role. See template details for least-privilege roles.
            </p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://aka.ms/finops/hubs/deploy">Deploy to Azure</a>
                <a class="btn mb-4 mb-md-0 mr-4 ftk-externallink ftk-btnlink" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/template">About the template</a>
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
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-scopes">Configure scopes</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">5️⃣&nbsp; Set up reports and dashboards</button>
        <div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-dashboards">Set up ADX dashboard</a>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/setup#set-up-your-first-report">Set up Power BI</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">🙋‍♀️&nbsp; Help + support</button>
        <div>
            <p>
                If you run into any issues, retrace your steps to ensure all steps were followed correctly and completely. Most issues are caused by missed or incomplete steps. If you are receiving an error, check for mitigation steps; otherwise, use the troubleshooting guide to identify and resolve common issues.
            </p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/help/errors">Review errors</a>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/help/troubleshooting">Start troubleshooting</a>
                <a class="btn mb-4 mb-md-0 mr-4 ftk-btnlink" target="_blank" href="https://aka.ms/ftk/discuss">Ask a question</a>
            </p>
        </div>
    </div>
</div>

<br><a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/Hubs/featureName/Marketing.Deploy">💜 Give feedback</a>
<a name="docs"></a>

## Learn more from documentation

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>🗃️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-model">Data model</a></div>
        <div>Tables and functions available in FinOps hubs to support custom queries and reports.</div>
    </div>
    <div class="ftk-tile">
        <div>📗 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/help/data-dictionary">Data dictionary</a></div>
        <div>Explore the columns available in FinOps hubs with Data Explorer and Power BI reports.</div>
    </div>
    <div class="ftk-tile">
        <div>⚙️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/data-processing">Data processing</a></div>
        <div>How data is processed in Data Factory pipelines and Data Explorer ingestion.</div>
    </div>
    <div class="ftk-tile">
        <div>📦 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/template">Deployment template</a></div>
        <div>Details about what's included in the FinOps hub deployment template.<br>&nbsp;</div>
    </div>
    <div class="ftk-tile">
        <div>🧮 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/compatibility">Compatibility guide</a></div>
        <div>Identify breaking changes in each release that may require additional work when upgrading.</div>
    </div>
    <div class="ftk-tile">
        <div>🛠️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/upgrade">Upgrade guide</a></div>
        <div>Things to keep in mind when upgrading an existing FinOps hub instance.</div>
    </div>
</div>

<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview">About FinOps hubs</a>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/Hubs/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
