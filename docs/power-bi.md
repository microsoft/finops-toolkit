---
layout: default
title: Power BI
browser: Power BI reports - Accelerate your analytics efforts with simple, targeted reports
nav_order: 25
description: 'Accelerate your analytics efforts with simple, targeted reports. Summarize and break costs down, or customize to meet your needs.'
permalink: /power-bi
#customer intent: As a Finops practitioner, I need to learn about FinOps toolkit Power BI reports
---

<span class="fs-9 d-block mb-4">Power BI reports</span>
Accelerate your analytics efforts with simple, targeted reports. Summarize and break costs down, or customize to meet your needs.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#deploy">Deploy</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/reports">Documentation</a>

---

FinOps toolkit Power BI reports provide a great starting point for FinOps reporting. Customize and augment reports with your own data to facilitate organizational requirements.

<div id="whats-new" class="ftk-new">
    <h3>What's new in January 2026<span class="ftk-version">v13</span></h3>
    <p>
        In January, Power BI reports added export requirements documentation to all report pages, added Azure Resource Graph as an explicit requirement for governance and workload optimization reports, and fixed tag expansion for tag names with special characters.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>
<a name="features"></a>

## Gain critical insights on a familiar platform

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>📥 Pre-built reports</div>
        <div>Jump start your FinOps reporting with over 30 pre-built pages across 5 reports.</div>
    </div>
    <div class="ftk-tile">
        <div>📊 Built on open standards</div>
        <div>Get started with the FinOps Open Cost and Usage Specification (FOCUS) with almost no effort.</div>
    </div>
    <div class="ftk-tile">
        <div>💰 Calculate savings</div>
        <div>Extend Cost Management data to add missing prices, calculate savings, and more.</div>
    </div>
    <div class="ftk-tile">
        <div>🏦 Do more with FinOps hubs</div>
        <div>Pair with FinOps hubs for increased performance, security, and data quality.</div>
    </div>
    <div class="ftk-tile">
        <div>☁️ Consolidate accounts</div>
        <div>Centralize FinOps data across multiple subscriptions, accounts, and clouds.</div>
    </div>
    <div class="ftk-tile">
        <div>🏗️ Extensible platform</div>
        <div>Build on an established platform with a rich ecosystem. Leverage familiar tools and integrations.</div>
    </div>
</div>

<a class="btn mb-4 mb-md-0 mr-4" href="https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip">Try the demo</a>

<div id="pricing" class="ftk-pricing">
    <h3>Estimated cost for FinOps toolkit Power BI reports</h3>
    <p>
        FinOps toolkit Power BI reports do not incur any cost beyond the required Power BI licenses and underlying data storage costs.
    </p>
</div>
<a name="deploy"></a>

## Deploy Power BI reports

Create a new or update an existing FinOps hub instance.

<div class="ftk-instructions">
    <div class="ftk-step">
        <button class="ftk-accordion">1️⃣&nbsp; Pick your data source</button>
        <div>
            <p>
                The data source you use can make or break the experience. Use the following criteria to select the right data source to meet your needs.
            </p>
            <div class="ftk-gallery ftk-50">
                <div class="ftk-tile">
                    <div>Total spend</div>
                    <div>
                        <p>
                            To monitor over $100,000 in spend, use <strong>FinOps hubs with Data Explorer</strong>. Storage reports may experience performance issues.
                        </p>
                    </div>
                </div>
                <div class="ftk-tile">
                    <div>Multiple scopes</div>
                    <div>
                        <p>
                            If you have multiple accounts, subscriptions, or tenants, use <strong>FinOps hubs</strong>. Centralize data across accounts and teannts for consolidated reporting.
                        </p>
                    </div>
                </div>
                <div class="ftk-tile">
                    <div>All other cases</div>
                    <div>
                        <p>
                            Use storage reports for other cases. Export FOCUS cost to a storage account you already have or use FinOps hubs to manage exports for you.
                        </p>
                    </div>
                </div>
            </div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/help-me-choose">Help me choose</a>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview">About FinOps hubs</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">2️⃣&nbsp; Set up your data source</button>
        <div>
            <p>Export FOCUS data to a storage account or deploy FinOps hubs for improved performance and added functionality.<br></p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/exports/openedBy/FinOpsToolkit.PowerBI.CreateExports">Create exports</a>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/help-me-choose">Deploy FinOps hubs</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">3️⃣&nbsp; Download the reports</button>
        <div>
            <p>Use KQL reports for FinOps hubs with Data Explorer or Microsoft Fabric; otherwise, use storage reports.<br></p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip">Download for KQL</a>
                <a class="btn mb-4 mb-md-0 mr-4" href="https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip">Download for storage</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">4️⃣&nbsp; Connect and publish reports</button>
        <div>
            <p>Connect reports to your storage account or Data Explorer cluster and publish to the Power BI service to share with your stakeholders.<br></p>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/setup">Connect to your data</a>
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

<br>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20Power%20BI%20reports%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20Power%20BI%20reports%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/PowerBI/featureName/Marketing.Deploy">💜 Give feedback</a>
<a name="docs"></a>

## Explore the reports

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>📊 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/cost-summary">Cost summary</a></div>
        <div>
            Track cost over time and get a general overview of cost and savings with common breakdowns to get you started.
        </div>
    </div>
    <div class="ftk-tile">
        <div>🪙 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/rate-optimization">Rate optimization</a></div>
        <div>
            Review cost savings from negotiated and commitment discounts and identify opportunities to increase savings.
        </div>
    </div>
    <div class="ftk-tile">
        <div>🧾 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/invoicing">Invoicing + chargeback</a></div>
        <div>
            Review billed costs, compare Cost Management with EA or MCA invoices, and break costs down for chargeback.
        </div>
    </div>
    <div class="ftk-tile">
        <div>⚖️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/governance">Policy + governance</a></div>
        <div>
            Summarize your governance posture with standard metrics aligned with the Cloud Adoption Framework.
        </div>
    </div>
    <div class="ftk-tile">
        <div>☁️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/workload-optimization">Workload optimization</a></div>
        <div>
            Gain insights into resource utilization and efficiency opportunities based on historical usage patterns.
        </div>
    </div>
    <div class="ftk-tile">
        <div>📥 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/data-ingestion">Data ingestion</a></div>
        <div>
            Review FinOps hubs cost and monitor Cost Management exports to identify and resolve common issues.
        </div>
    </div>
</div>

<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/reports">About the reports</a>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20Power%20BI%20reports%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20Power%20BI%20reports%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/PowerBI/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
