---
title: Monitoring & alerting
parent: Capacity & quotas
nav_order: 7
---

# Monitoring & alerting guide

> Where this fits: step 4 of the capacity supply chain. Alert on quota and reservation utilization before saturation so releases and onboarding don't stall. [Source](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) [Source](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started)

Proactive monitoring prevents quota exhaustion and cost overruns from surprising application teams. This guide outlines how to turn on quota monitoring, author alert rules, and align quota telemetry with cost guardrails so you don't miss leading indicators.

## Turn on quota monitoring

- From the Azure portal, open **Quotas** and select **My quotas**. When [monitoring is turned on](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting) for a provider, adjustable quotas become highlighted and clickable, exposing usage details and alert creation shortcuts.
- Ensure administrators hold the [required Azure RBAC permissions](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting)—typically Owner, Contributor, or a custom role with alert authoring rights—before configuring monitoring and alert rules.

## Create quota usage alerts

1. **Select quota:** In **My quotas**, choose the [resource provider](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) (for example, `Microsoft.Compute`, `Microsoft.Storage`, or `Microsoft.Web`) and select the quota to monitor.
2. **Launch alert wizard:** Select the quota name to open the [**Create usage alert rule**](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) experience. Quota-specific dimensions (subscription, region, quota name) are pre-populated.
3. **Configure thresholds:** Set the [usage percentage trigger](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) (for example, 70%, 85%, 95%) and choose the evaluation cadence (5–15 minutes) to balance responsiveness and noise.
4. **Notifications:** Define [action groups](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) (email, Teams, ITSM) to route alerts to responders. Confirm the managed identity or user configuring the alert has Reader access on the subscription.

## Quota dashboards

- Export quota usage via [`az quota usage list`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) for each provider and ingest into Log Analytics or Power BI for trend dashboards. Consistent exports allow teams to visualize approaching limits and correlate with deployment events.

## Cost management guardrails

- [Configure budget alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending) at the subscription, billing profile, or invoice section level to warn stakeholders when actual or forecasted spend approaches agreed thresholds. Budget alerts deliver notifications in tandem with quota alerts to reinforce accountability.
- Set [cost anomaly alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending) to detect unexpected spikes that may indirectly signal runaway deployments consuming quota faster than planned.
