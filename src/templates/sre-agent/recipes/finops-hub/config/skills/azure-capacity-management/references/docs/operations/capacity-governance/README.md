---
title: Capacity governance program
parent: Capacity & quotas
nav_order: 6
---

# Capacity governance program

Azure guidance connects [capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [scale-unit architecture](https://learn.microsoft.com/en-us/azure/well-architected/mission-critical/application-design#scale-unit-architecture), quota management, [Azure Reservations and savings plans](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started), and [monitoring](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling#choose-appropriate-scale-units) into a cohesive capacity governance approach. This page aggregates those references so you can align the other guides in this site with the official documentation without guessing where guidance lives. You'll see how each link maps to the guides elsewhere in this repo.

> This page aggregates Azure's capacity governance surfaces so you can integrate them into your platform's supply chain. Each section cites Microsoft Learn and links to supporting guides.

## Azure capacity governance surfaces

Azure exposes these controls for capacity governance:

- **Forecasting:** [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) guidance describes demand modeling using telemetry and business context; [scale-unit architecture](https://learn.microsoft.com/en-us/azure/well-architected/mission-critical/application-design#scale-unit-architecture) and [deployment stamps](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern) show how to structure scalable capacity envelopes.
- **Access and quota:** [Region access](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) and [zone enablement](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) unblock restricted areas; [quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) pool vCPU limits across subscriptions for shared inventory management.
- **Capacity reservations:** [On-demand reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) guarantee VM availability for specific sizes, regions, and zones; [overallocation tracking](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) exposes utilization states beyond reserved quantities.
- **Monitoring:** [Quota alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) provide usage signals as consumption approaches limits; [rate optimization](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) surfaces include reservation and savings plan utilization views.
- **Supply chain integration:** [Operational excellence guidance](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) describes how to integrate capacity controls into CI/CD promotion paths.

### Quick links

- Forecast: [Capacity planning](../capacity-planning/README.md)
- Access and quota: [Quota operations](../quota/README.md), [Quota groups](../quota-groups/README.md)
- Reserve: [Capacity reservations](../capacity-reservations/README.md)
- Govern and ship: [Monitoring & alerting](../monitoring-alerting/README.md), [Capacity governance](../capacity-governance/README.md), [Supply chain guidance](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)

## Forecasts and scale units

- The Well-Architected [capacity planning article](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) describes capacity planning as an iterative process that uses historical telemetry, business context, and forecasting to keep workloads reliable without overprovisioning.
- The reliable scaling guidance recommends designing around [scale units](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling#choose-appropriate-scale-units)—logical groupings of components that scale together—and notes that you can scale individual resources, full components, or entire solutions as deployment stamps.
- In the mission-critical application design guidance, a [scale unit](https://learn.microsoft.com/en-us/azure/well-architected/mission-critical/application-design#scale-unit-architecture) is defined as a logical unit or function that can be scaled independently, potentially including code components, hosting platforms, deployment stamps, and even subscriptions when multitenant requirements are involved.
- The same guidance illustrates that [scale units](https://learn.microsoft.com/en-us/azure/well-architected/mission-critical/application-design#scale-unit-architecture) can range from microservice pods to cluster nodes and regional deployment stamps, and that using scale units helps standardize how capacity is added and validated before directing user traffic.

## Quota groups and shared quota

- The [Azure Quota Groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) article explains that quota groups are ARM objects created at the management group scope that allow you to share procured quota between subscriptions, distribute or reallocate unused quota, and submit group-level quota increase requests.
- [Supported scenarios](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) include deallocating unused quota from subscriptions into the group, allocating quota from the group back to subscriptions, and using group-level limit increases to make quota available for future transfers.
- Documentation notes that [quota groups are independent](https://learn.microsoft.com/en-us/azure/quotas/quota-groups#quota-group-is-an-arm-object) of subscription placement in the management group hierarchy and do not automatically synchronize subscription membership, which keeps quota management orthogonal to policy and role hierarchies.
- The [transfer](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#transfer-quota) and [quota allocation snapshot](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#quota-allocation-snapshot) APIs provide a view of per-subscription limits and shareable quota for VM families and regions within a group, using the same quota constructs that apply to standard subscription quota checks.

## Capacity reservations and compute supply

This section focuses on compute supply through capacity reservations and capacity reservation groups, which are distinct from Azure Reservations and savings plans used for pricing and discount optimization.

- The [on-demand capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) describes capacity reservations as a way to reserve compute capacity for a specific VM size in a region or availability zone, managed through capacity reservation groups.
- Reservations are created for a VM size, location, and quantity, and they can be [adjusted by changing the capacity property](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview#work-with-capacity-reservation); changes such as VM size or location require creating a new reservation and migrating workloads if needed.
- The documentation explains that [deployments that reference a capacity reservation group](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview#work-with-capacity-reservation) consume from the reserved quantity and skip quota checks up to that quantity, while deployments beyond the reserved quantity are considered [overallocations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) and are not covered by the capacity reservation SLA.
- [Overallocate capacity reservation guidance](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) clarifies the states for a reservation—capacity available, fully consumed, and overallocated—and shows how instance view data can be used to understand allocated versus reserved quantities.
- The capacity reservation overview also notes that [reserved capacity can be combined automatically with reserved instances](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview#benefits-of-capacity-reservation) to apply term-commitment discounts, while capacity reservations themselves do not require a one- or three-year commitment.

## Reservations, savings plans, and utilization

- [FinOps rate optimization guidance](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) highlights Azure Advisor recommendations, reservation purchase recommendations, and savings plan purchase recommendations as starting points for deciding when to buy reservations or savings plans based on historical usage and cost.
- After commitments are purchased, the same guidance points to [portal experiences for viewing utilization](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) for reservations and savings plans, with options to adjust scope or enable instance size flexibility to increase utilization.
- The documentation also describes [reservation utilization alerts](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) that can notify stakeholders when utilization drops below a desired threshold, and showback and chargeback reports for reservations and savings plans.
- These [utilization views and alerts](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/optimize/rates#getting-started) complement [capacity reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) and quota monitoring by providing cost-side signals about how effectively reserved capacity and savings plans are being used.

## Monitoring quotas and capacity signals

- The [quota monitoring and alerting article](https://learn.microsoft.com/en-us/azure/quotas/monitoring-alerting) describes how the Quotas experience in the Azure portal tracks resource usage against quota limits and supports configuring alerts when usage approaches those limits.
- The [Create alerts for quotas](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) documentation details how to create alert rules from the **My quotas** blade by selecting a quota name, choosing severity, and setting a usage-percentage threshold for triggering alerts.
- Together with [quota allocation snapshots](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups#quota-allocation-snapshot) for quota groups and [instance view data](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) for capacity reservations, these monitoring capabilities provide the platform-level signals referenced in Azure's guidance on [scaling and capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning).

