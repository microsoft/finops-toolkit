---
title: Capacity and billing operations
parent: Operational topics
nav_order: 2
has_children: true
---

# Capacity and billing operations

This hub connects Azure billing models, subscription vending, quota operations, capacity reservations, monitoring, and automation so Azure capacity evidence fits inside the canonical FinOps Framework. It maps Azure controls to Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization, Governance, Policy & Risk, and Automation, Tools & Services, while using [Well-Architected capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [reliable scaling](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling), and [workload supply chain guidance](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) as Azure implementation references. [Source](https://www.finops.org/framework/) [Source](https://www.finops.org/framework/domains/)

Use this page as the estate-level reference for how billing scopes, subscription creation, quota groups, capacity reservations, and CI/CD gates work together for SaaS ISVs operating Azure estates under the [ISV landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/isv-landing-zone) expectations.

## Billing models and scopes (EA vs MCA)

Azure enterprise customers typically operate under either the historic Enterprise Agreement (EA) or the modern Microsoft Customer Agreement (MCA). Both contracts provide an enterprise footing for Azure subscriptions, but the MCA simplifies hierarchy, automation, and tenant alignment according to [MCA billing guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement).

- EA continues to use enrollments and departments to structure subscriptions, and many ISVs keep this model in place for existing estates. Subscription creation flows through enrollment accounts and automation patterns documented for Enterprise Agreements. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-enterprise-agreement?tabs=rest)
- MCA anchors the billing account to a Microsoft Entra tenant and introduces billing accounts, billing profiles, and invoice sections, which define how subscriptions inherit tenant context and how charges roll up. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement)
- MCA billing roles are designed for automation: subscription creator, Owner, or Contributor roles at the billing account, billing profile, or invoice section scope can create subscriptions through [programmatic subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) APIs.

From a FinOps perspective, these billing scopes define where [Azure Reservations and savings plans](https://www.finops.org/framework/capabilities/rate-optimization/) attach as pricing constructs. Reservations and savings plans deliver rate optimization at the billing account, billing profile, or subscription scope, while [capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) guarantee supply at the region or availability zone scope. Treat these as complementary instruments: pricing commitments live at billing scopes, and capacity reservations live at compute scopes.

## Subscription vending and support workflows

Subscription vending connects billing scopes to workload landing zones. The goal is to standardize how you collect subscription requests, apply placement rules, and connect approvals to automation so developers receive subscriptions that match landing zone design and capacity governance. [Source](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending)

- Subscription vending design areas describe how platform teams capture intake data (owners, budget, network topology, data classifications) and route deployments into the correct management group and billing scope. This keeps subscriptions aligned with [Azure landing zone design areas](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending#determine-subscription-placement) while preserving internal governance.
- Programmatic subscription creation for EA, MCA, and partner agreements uses modern REST APIs so you can integrate vending into CI/CD or workflow engines. Align the entry points from [EA subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-enterprise-agreement?tabs=rest) and [MCA subscription creation](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement?tabs=rest) with your subscription vending flows. [Source](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription)
- Cross-tenant subscription requests let an MCA billing owner create a subscription for a user or service principal in another tenant using the [subscription request workflow](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription-request). This pattern is important when the ISV operates multiple tenants.

Support workflows are part of the Azure implementation surface for Architecting & Workload Placement, Planning & Estimating, Forecasting, and Governance, Policy & Risk:

- Region access requests unblock subscriptions in restricted regions and should be planned ahead of major launches. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process)
- Zonal enablement requests grant access to restricted VM series in specific availability zones and protect high-availability designs that rely on those SKUs. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series)
- VM-family and regional quota increases use standard [per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) and [regional quota requests](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests) when capacity needs fall outside quota groups or existing limits.

## Map Azure controls to FinOps capabilities

- Planning & Estimating and Forecasting: Size scale units or deployment stamps from telemetry, business targets, and Well-Architected capacity planning guidance before you request quota or reservations. This connects capacity assumptions to FinOps planning, budget, and forecast evidence. [Source](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) [Source](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern) [Source](https://www.finops.org/framework/capabilities/)
- Architecting & Workload Placement: Get region and zonal access approved, verify SKU availability, and use quota groups at the management group scope to avoid stranded VM-family headroom. These Azure controls shape where workloads can run. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) [Source](https://learn.microsoft.com/en-us/azure/quotas/quota-groups)
- Usage Optimization: Track quota, reserved capacity, and deployment-stamp utilization so unused buffers, stranded headroom, and inefficient placement decisions are visible. Capacity reservations expose reserved versus allocated capacity through instance view. [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) [Source](https://www.finops.org/framework/capabilities/usage-optimization/)
- Rate Optimization: Coordinate Azure Reservations and savings plans with capacity reservations when workload demand is stable enough to support a pricing commitment. Capacity reservations guarantee compute supply; Reservations and savings plans reduce rate. [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) [Source](https://www.finops.org/framework/capabilities/rate-optimization/)
- Governance, Policy & Risk and Automation, Tools & Services: Wire quota and reservation utilization alerts so onboarding or seasonal spikes don't stall, and connect those signals to CI/CD gates, owner routing, budgets, anomaly alerts, and exception review. [Source](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) [Source](https://www.finops.org/framework/capabilities/governance-policy-risk/) [Source](https://www.finops.org/framework/capabilities/automation-tools-services/)

### Links by capability area

- Planning & Estimating and Forecasting: [Capacity planning](../capacity-planning/README.md)
- Architecting & Workload Placement: [Quota operations](../quota/README.md), [Quota groups](../quota-groups/README.md), and [Deployment patterns](../../deployment/README.md)
- Usage Optimization and Rate Optimization: [Capacity reservations](../capacity-reservations/README.md) and [Billing models](../../billing/README.md)
- Governance, Policy & Risk and Automation, Tools & Services: [Monitoring & alerting](../monitoring-alerting/README.md), [Capacity governance](../capacity-governance/README.md), and [Tools & scripts index](../tools-scripts/README.md)

## FinOps intersections

Capacity and billing operations intersect with multiple FinOps Framework domains and capabilities. Domains are outcomes, and capabilities describe the activities that achieve those outcomes. [Source](https://www.finops.org/framework/domains/) [Source](https://www.finops.org/framework/capabilities/)

- Understand Usage & Cost: Capacity evidence depends on Data Ingestion, Allocation, Reporting & Analytics, and Anomaly Management so teams can see utilization, headroom, and cost signals in one reporting context. [Source](https://www.finops.org/framework/domains/)
- Quantify Business Value: Planning & Estimating, Forecasting, Budgeting, KPIs & Benchmarking, and Unit Economics connect demand projections to business context, budget guardrails, and product economics. [Source](https://www.finops.org/framework/domains/)
- Optimize Usage & Cost: Architecting & Workload Placement, Usage Optimization, and Rate Optimization cover region, zone, SKU, utilization, and pricing-commitment choices. [Source](https://www.finops.org/framework/domains/)
- Manage the FinOps Practice: Governance, Policy & Risk and Automation, Tools & Services cover alerts, controls, owner routing, exception review, and tool-supported evidence collection. [Source](https://www.finops.org/framework/domains/)

Across these capabilities, the distinction between pricing commitments and capacity guarantees is critical. Pricing constructs such as Azure Reservations and savings plans reduce unit cost but don't reserve capacity, while capacity reservations guarantee supply without changing price on their own. The capability view on this page keeps those roles clear so ISV platform, finance, and product teams can make coordinated decisions.


## Tools

For operational scripts and reporting, see:

- [Tools & scripts index](../tools-scripts/README.md) for quota, cost, and automation utilities
