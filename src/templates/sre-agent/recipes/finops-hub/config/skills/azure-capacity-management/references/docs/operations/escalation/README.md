---
title: Support escalation
parent: Support & reference
nav_order: 1
---

# Support escalation guide

Self-service quota tooling resolves most requests, but some capacity problems still require Microsoft intervention. Use this guide to recognize when escalation is necessary and how to submit a support ticket with the required context so you don't lose time gathering details after the ticket opens.

## When to escalate

- **Restricted regions or zones:** Subscriptions cannot deploy to a region or zone because of [access restrictions](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) that only Microsoft can lift.
- **Non-adjustable quotas:** The **My quotas** blade flags the target quota as [non-adjustable](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal) or the automated request is denied.
- **Service-specific limits:** Services such as Azure Cosmos DB require engineering review to raise [account/container limits or throughput ceilings](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).
- **Capacity SLA claims:** [Capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) fail to meet the SLA despite available quantity, requiring investigation and potential credits.

## Pre-submission checklist

- Confirm you have Owner, Contributor, or Support Request Contributor rights on the subscription; without appropriate RBAC the portal blocks [ticket creation](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request).

## Creating the request

1. Open the Azure portal, select the **?** icon, and choose [**Create a support request**](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request).
2. On the **Problem description** tab, select [**Service and subscription limits (quotas)**](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request), choose the subscription, and pick the relevant quota type (for example, `Compute-VM (cores-vCPUs)`, [`Azure Cosmos DB`](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase), or `Microsoft Fabric`).
3. Provide detailed [problem statements](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), including region, VM series, desired quota value, and [deployment blockers](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/create-support-request-quota-increase).
4. Attach [supporting files](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request) (screenshots, export logs) and specify severity and preferred contact method.
5. Submit and capture the support request ID for tracking.

## Region and zone access workflow

- When requesting [region or zone enablement](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), list all regions, VM series, and logical zones required for upcoming deployments within the ticket.
- Reference [prior approvals](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) if recycling subscriptions so Microsoft can reconnect previously granted access.
