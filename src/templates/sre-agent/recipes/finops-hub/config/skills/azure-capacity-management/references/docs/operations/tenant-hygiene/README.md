---
title: Tenant & subscription hygiene
parent: Support & reference
nav_order: 2
---

# Tenant & subscription hygiene

ISVs commonly manage subscriptions across multiple tenants while centralizing billing and governance. This guide documents best practices for maintaining clean tenant relationships, recycling subscriptions, and preserving zone mappings so you aren't surprised by access gaps.

## Align tenant and billing structures

- Each [Microsoft Customer Agreement (MCA) billing account](https://learn.microsoft.com/en-us/azure/cost-management-billing/microsoft-customer-agreement/manage-tenants) links to a primary Microsoft Entra tenant but can associate additional tenants for billing operations.
- [Billing owners](https://learn.microsoft.com/en-us/azure/cost-management-billing/microsoft-customer-agreement/manage-tenants) can create, transfer, or link subscriptions across associated tenants without changing the resource tenant. Track which tenants are authorized for each billing profile and invoice section to avoid orphaned access.
- Invite guest users or [associate tenant relationships](https://learn.microsoft.com/en-us/azure/cost-management-billing/microsoft-customer-agreement/manage-tenants) before assigning billing roles to external teams, and ensure invitations are accepted to activate access.

## Subscription lifecycle hygiene

- **Onboarding:** Use the [subscription request workflow](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription-request) to provision subscriptions for other tenants while maintaining billing control. Capture required roles (Owner, Contributor, Azure subscription creator) and management group placement as part of the intake checklist.
- **Recycling vs. deletion:** When workloads retire, reclaim quota and billing ownership but keep the subscription if zone enablement or [region access](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) was previously granted. Deleting the subscription can force new access requests, delaying future projects.

## Preserve zone consistency

- [Logical-to-physical zone mappings](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) differ per subscription and are assigned at creation. Export mappings through the `List Locations` API or the `checkZonePeers` API to document how subscriptions align across tenants.
- When planning cross-tenant high availability, compare zone mappings early to avoid placing redundant components in the same physical zone.

## Automation opportunities

- Script [subscription request creation and acceptance](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription-request) for cross-tenant provisioning to reduce manual errors.
- Automate [zone mapping exports](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) and store results in source control for auditability.

