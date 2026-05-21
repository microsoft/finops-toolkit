---
title: Capacity and billing operations
parent: Operational topics
nav_order: 2
has_children: true
---

# Capacity and billing operations

This hub connects Azure billing models, subscription vending, quota operations, capacity reservations, monitoring, and automation so you can treat capacity management as a single supply chain across your estate. It aligns with [Well-Architected capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [reliable scaling](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling), and [workload supply chain guidance](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain), and maps into the [FinOps Framework](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/) and [FinOps rate optimization](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) practices.

Use this page as the estate-level reference for how billing scopes, subscription creation, quota groups, capacity reservations, and CI/CD gates work together. The public azcapman site speaks to ISV platform teams, while CSU training material uses the same vocabulary so Microsoft and the ISV can coordinate quota requests and automation based on [ISV landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/isv-landing-zone) expectations.

## Billing models and scopes (EA vs MCA)

Azure enterprise customers typically operate under either the historic Enterprise Agreement (EA) or the modern Microsoft Customer Agreement (MCA). Both contracts provide an enterprise footing for Azure subscriptions, but the MCA simplifies hierarchy, automation, and tenant alignment according to [MCA billing guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement).

- EA continues to use enrollments and departments to structure subscriptions, and many ISVs keep this model in place for existing estates. Subscription creation flows through enrollment accounts and automation patterns documented for Enterprise Agreements. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-enterprise-agreement?tabs=rest)
- MCA anchors the billing account to a Microsoft Entra tenant and introduces billing accounts, billing profiles, and invoice sections, which define how subscriptions inherit tenant context and how charges roll up. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement)
- MCA billing roles are designed for automation: subscription creator, Owner, or Contributor roles at the billing account, billing profile, or invoice section scope can create subscriptions through [programmatic subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) APIs.

From a FinOps perspective, these billing scopes define where [Azure Reservations and savings plans](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) attach as pricing constructs. Reservations and savings plans deliver rate optimization at the billing account, billing profile, or subscription scope, while [capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) guarantee supply at the region or availability zone scope. Treat these as complementary instruments: pricing commitments live at billing scopes, and capacity reservations live at compute scopes.

## Subscription vending and support workflows

Subscription vending connects billing scopes to workload landing zones. The goal is to standardize how you collect subscription requests, apply placement rules, and connect approvals to automation so developers receive subscriptions that match landing zone design and capacity governance. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending)

- Subscription vending design areas describe how platform teams capture intake data (owners, budget, network topology, data classifications) and route deployments into the correct management group and billing scope. This keeps subscriptions aligned with [Azure landing zone design areas](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending#determine-subscription-placement) while preserving internal governance.
- Programmatic subscription creation for EA, MCA, and partner agreements uses modern REST APIs so you can integrate vending into CI/CD or workflow engines. Align the entry points from [EA subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-enterprise-agreement?tabs=rest) and [MCA subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) with your subscription vending flows. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription)
- Cross-tenant subscription requests let an MCA billing owner create a subscription for a user or service principal in another tenant using the [subscription request workflow](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription-request). This pattern is important when the ISV operates multiple tenants or when CSU teams collaborate with customer tenants.

Support workflows are part of the same supply chain:

- Region access requests unblock subscriptions in restricted regions and should be planned ahead of major launches. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process)
- Zonal enablement requests grant access to restricted VM series in specific availability zones and protect high-availability designs that rely on those SKUs. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series)
- VM-family and regional quota increases use standard [per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) and [regional quota requests](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests) when capacity needs fall outside quota groups or existing limits.

CSU personas use these same patterns when they partner with ISVs: CSAMs coordinate support workflows and quotas, while CSAs and solution engineers focus on architecture and automation so subscriptions and regions stay ready for onboarding. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/isv-landing-zone)

## Follow the supply chain

- Forecast and shape demand: Size scale units or deployment stamps from telemetry, business targets, and Well-Architected capacity planning guidance before you request quota or reservations. This supports FinOps forecasting and budgeting by tying scale units to business demand. [Source](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) [Source](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern) [Source](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/)
- Secure access and quota: Get region and zonal access approved, then treat quota groups as shared inventory at the management group scope to avoid stranded VM-family headroom and speed quota limit increases. This step aligns with FinOps focus areas around allocation and governance because it centralizes vCPU limits. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) [Source](https://learn.microsoft.com/en-us/azure/quotas/quota-groups)
- Lock in compute supply: Design capacity reservations for the SKUs, regions, and zones your deployment stamps need, and keep over-allocations explicit with instance view. This is a capacity guarantee, not a price commitment, and it should respond to the same forecasts that drive Reservations and savings plans. [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate)
- Govern utilization and alerts: Wire quota and reservation utilization alerts so onboarding or seasonal spikes don't stall, and use FinOps rate guidance to monitor commitment utilization and effective discounts. This keeps cost and capacity signals aligned in dashboards and alerts. [Source](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) [Source](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started)
- Ship through one supply chain: Promote changes through the same gates—quota, region access, capacity reservations, billing approvals, and CI/CD—per operational excellence supply chain guidance to limit configuration drift and failed releases across subscriptions and regions. [Source](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)

### Links for each step

- Forecast: [Capacity planning](../capacity-planning/README.md)
- Access and quota: [Quota operations](../quota/README.md) and [Quota groups](../quota-groups/README.md)
- Reserve: [Capacity reservations](../capacity-reservations/README.md)
- Govern and ship: [Monitoring & alerting](../monitoring-alerting/README.md) and [Capacity governance](../capacity-governance/README.md)

## FinOps intersections

Capacity and billing operations intersect with multiple FinOps Framework domains and capabilities. [Source](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/) [Source](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started)

- Inform: Forecasting and demand shaping link Well-Architected capacity planning, scale unit sizing, and utilization telemetry to [FinOps data ingestion, allocation, and reporting](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/). ISV platform teams and CSU personas share dashboards, cost reports, and quota usage snapshots to keep everyone aligned on capacity and spend.
- Optimize: Azure Reservations and savings plans provide discount instruments that operate at billing scopes, while capacity reservations guarantee supply at compute scopes. Treat rate optimization and capacity reservations as separate but coordinated levers that respond to the same forecasts and supply chain. [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview)
- Operate and govern: Quota monitoring, budget alerts, and capacity governance guides form the operational backbone for capacity and billing operations. They connect [quota alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting), [budget alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending), and workload supply chain gates into a single governance story.

Across these domains, the distinction between pricing commitments and capacity guarantees is critical. Pricing constructs such as Azure Reservations and savings plans reduce unit cost but don't reserve capacity, while capacity reservations guarantee supply without changing price on their own. The unified view on this page keeps those roles clear so ISVs and Microsoft CSU teams can make coordinated decisions.


## Tools

For operational scripts and reporting, see:

- [Tools & scripts index](../tools-scripts/README.md) for quota, cost, and automation utilities
