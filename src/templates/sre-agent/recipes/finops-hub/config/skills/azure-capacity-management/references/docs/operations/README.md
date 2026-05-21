---
title: Capacity management
nav_order: 4
has_children: true
---

# Capacity management overview

Use this section to access subscription lifecycle guides, capacity and quota guidance, and supporting operational references. The goal is to connect estate-level controls to Azure landing zone and Well-Architected guidance without prescribing your internal operating model. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/isv-landing-zone) [Source](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)

- [Forecast](capacity-planning/README.md)—capacity planning inputs, isolation decisions, and the demand signals you use before you source quota or commitments.
- [Procure](quota/README.md)—billing scopes, region and zonal access, quota requests, and capacity reservations.
- [Allocate](quota-groups/README.md)—pooled quota distribution through quota groups and management group controls.
- [Monitor](monitoring-alerting/README.md)—quota and reservation monitoring, alerting, governance gates, and support references.

## Subscription vending context

- [Subscription vending](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending#determine-subscription-placement) standardizes how platform teams capture requests, enforce approval logic, and automate placement of new landing zones so application teams can focus on workload delivery.
- The Cloud Center of Excellence defines intake requirements (budget, owner, network expectations, data classifications) and connects the approval flow to the subscription deployment pipeline to keep governance aligned with [Azure landing zone design areas](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending#determine-subscription-placement).

## Programmatic subscription creation

- Azure supports [programmatic subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription) for Enterprise Agreements, Microsoft Customer Agreements, and Microsoft Partner Agreements via modern REST APIs.
- Legacy EA processes use enrollment accounts to scope billing, while modern MCA workflows rely on billing profiles and invoice sections. See the dedicated legacy and modern pages in this folder for detailed guides.
- When planning subscription vending product lines, align the automation entry points from the EA and MCA procedures with the [placement guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending#determine-subscription-placement) so workload subscriptions land in the correct management group and billing scope.

## Support workflows

- [Regional access requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) unblock subscriptions in restricted regions; submit quota support tickets when deployment plans require new geographies and make sure you follow up on any offer flags set at subscription creation.
- [Zonal access requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) grant restricted VM series access to targeted availability zones, preserving high-availability plans across logical mappings.
- [VM-family](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) and [regional quota increases](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests) continue to flow through Azure's quota tooling for any needs outside pooled quota groups.
