---
title: Quota groups reference
parent: Capacity & quotas
nav_order: 5
---

# Azure quota groups reference

> Where this fits: step 2 of the capacity supply chain. Use quota groups after you unblock regions and zones so you can stage VM-family headroom for multiple subscriptions. [Source](https://learn.microsoft.com/en-us/azure/quotas/quota-groups)

[Azure quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) are Azure Resource Manager (ARM) objects that let you share and self-manage compute quota across a set of subscriptions. This page aggregates key prerequisites, limitations, lifecycle behavior, and monitoring options from the official documentation so you can reason about quota groups alongside the other guides in this site, and you'll see where each Microsoft article fits.

## Feature overview

- [Quota groups elevate quota](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) from a per-subscription construct to a group-level ARM resource created under a management group, while quota enforcement at deployment time still occurs at the subscription level.
- The feature supports [quota sharing across subscriptions](https://learn.microsoft.com/en-us/azure/quotas/quota-groups), self-service reallocation of unused quota, and group-level quota increase requests that can later be allocated to individual subscriptions.
- [Supported scenarios](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) in the documentation include deallocating unused quota from subscriptions into the group, allocating quota from the group back to target subscriptions, and submitting quota group limit increase requests for specific regions and VM families.

## Prerequisites

- The [`Microsoft.Quota` and `Microsoft.Compute` resource providers must be registered](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#prerequisites) on all subscriptions you plan to add to a quota group.
- [A management group is required](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#prerequisites) to create a quota group. The group is created at the [management group scope](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#quota-group-is-an-arm-object) and inherits read and write permissions from that parent.
- [Subscriptions from different management groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#prerequisites) can be added to the same quota group; [subscription membership is independent](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#quota-group-is-an-arm-object) of the management group hierarchy as long as permissions allow it.
- The official guidance calls out the following [roles for operating quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#permissions):
  - Assign the GroupQuota Request Operator role on the management group where the quota group is created.
  - Assign the Quota Request Operator role on participating subscriptions for users or applications that perform quota operations.
  - Assign Reader on participating subscriptions for users or applications that need to view quota group resources in the portal.

## Limitations and scope

- [Quota groups are available](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#limitations) only for Enterprise Agreement, Microsoft Customer Agreement, and internal subscriptions.
- They currently [support IaaS compute resources only](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#limitations) and are available in public cloud regions.
- [A subscription can belong to only one quota group](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#limitations) at a time, as noted in both the [limitations](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group#add-subscriptions-to-a-quota-group) and subscription management documentation.
- Quota groups focus on quota management; they [don't grant regional or zonal access](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#limitations). [Region and zonal access still require separate support requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), and quota transfers or deployments can fail if the target subscription lacks region or zone access.
- [Management group deletion affects access](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#limitations) to the quota group limit. You must clear out group limits and delete the quota group object before deleting the management group, or recreate the management group with the same ID to regain access.

## ARM object and lifecycle behavior

- [Quota groups are global ARM resources](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#quota-group-is-an-arm-object) created at the management group scope and designed as an orthogonal grouping mechanism for quota management, separate from subscription placement in the management group hierarchy.
- [Subscription lists aren't automatically synchronized](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#quota-group-is-an-arm-object) from management groups; instead, you [explicitly add and remove subscriptions](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group#add-subscriptions-to-a-quota-group) to control which ones participate in group-level quota operations.

![Diagram of Management Group hierarchy with sample Quota Groups created under Management Group.](https://learn.microsoft.com/en-us/azure/quotas/media/quota-groups/sample-management-group-quota-group-hierarchy.png)

- [Creating or deleting a quota group](https://learn.microsoft.com/en-us/azure/quotas/create-quota-groups) requires the GroupQuota Request Operator role on the management group.
- When you [add subscriptions to a quota group](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group#add-subscriptions-to-a-quota-group), they carry their existing quota and usage; adding them doesn't change their subscription limits or usage values.
- When you [remove subscriptions from a quota group](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group#remove-subscriptions-from-a-quota-group), they retain their existing quota and usage. The group limit isn't automatically changed by removal operations.
- At creation time, the [quota group limit is set to zero](https://learn.microsoft.com/en-us/azure/quotas/quota-groups). You must either transfer quota from a subscription in the group or [submit a quota group limit increase request](https://learn.microsoft.com/en-us/azure/quotas/quota-group-limit-increase) and wait for approval before the group can allocate capacity.
- [Before deleting a quota group](https://learn.microsoft.com/en-us/azure/quotas/create-quota-groups), all subscriptions must be removed from it, as described in the create/delete guidance.

## Quota transfers and allocation snapshots

- The ["Transfer quota within an Azure Quota Group" article](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#transfer-quota) describes how to move unused quota from a subscription to the group (deallocation) or from the group to a subscription (allocation) using the quota group ARM object.
- [Quota allocation snapshots](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#quota-allocation-snapshot) expose, for each subscription in the group, a Limit value (current subscription limit) and a Shareable quota value that reflects how many cores have been deallocated or transferred between the subscription and the group.
- The [example in the snapshot section](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#quota-allocation-snapshot) shows a shareable quota of `-10` to indicate that 10 cores were given from the subscription to the group, alongside a new subscription limit of 50 cores for the corresponding VM family and region.
- These documented fields give you a [consistent view of how quota is distributed](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) between the group and its member subscriptions without changing how [deployments are evaluated](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#quota-allocation-snapshot) against per-subscription limits.

## Monitoring and alerting

- The [Quotas experience in the Azure portal](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting) includes a **My quotas** view that continuously tracks resource usage against quota limits for providers such as Microsoft.Compute, and supports alerting when usage approaches limits.
- The [quota monitoring and alerting documentation](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting) explains that quota alerts are notifications triggered when resource usage nears the predefined quota limit, and that you can create multiple alert rules across quotas in a subscription.
- The ["Create alerts for quotas" article](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) documents how to create alert rules from the Quotas page by selecting a quota name in **My quotas**, choosing an alert severity, and configuring a usage-percentage threshold for triggering alerts.
- While [quota group operations](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) are scoped to a management group, the [quota monitoring and alerting features](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting) give you a way to observe usage and quota consumption trends for the underlying subscriptions that participate in the group.

