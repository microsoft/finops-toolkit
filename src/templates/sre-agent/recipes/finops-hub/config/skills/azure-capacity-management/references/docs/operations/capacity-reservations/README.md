---
title: Capacity reservations
parent: Capacity & quotas
nav_order: 2
---

# Capacity reservation operations

> Where this fits: step 3 of the capacity supply chain. Use capacity reservations after access and quota are staged, so critical SKUs, regions, and zones are covered before you onboard or surge. [Source](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview)

On-demand capacity reservations guarantee that compute capacity is available when critical workloads scale out. This guide explains how to create, share, monitor, and automate capacity reservation groups (CRGs) so platform teams can coordinate with quota and deployment workflows, and it reminds you where the platform enforces prerequisites.

## Cost implications of capacity allocation

- Capacity reservations are billed at pay-as-you-go rates for the reserved VM size whether or not VMs are deployed against them—unused reservations still incur cost.
- Regional pricing varies: the same VM SKU costs different amounts in different regions. Check [Azure pricing by region](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/) before committing capacity to a specific location.
- Use [FinOps Hubs](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/finops-hubs-overview) to analyze historical pricing across regions before allocating; see the [FinOps Toolkit query index](https://github.com/microsoft/finops-toolkit/blob/main/src/queries/INDEX.md) for available queries.
- Capacity reservations are eligible for [Reserved Instance discounts](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations)—layer rate commitments on top of capacity commitments to maximize savings.
- Factor both capacity cost and rate optimization into unit economics before allocating; unused capacity reservations without RI coverage pay full PAYG rates.
- Run [reservation-recommendation-breakdown](https://github.com/microsoft/finops-toolkit/blob/main/src/queries/INDEX.md) to evaluate whether reserved instances reduce costs for capacity you've already reserved.
- Use [commitment-discount-utilization](https://github.com/microsoft/finops-toolkit/blob/main/src/queries/INDEX.md) to track whether capacity reservation costs are offset by reservation discounts.
- Use [savings-summary-report](https://github.com/microsoft/finops-toolkit/blob/main/src/queries/INDEX.md) to calculate your effective savings rate across both capacity and rate commitments.

## Prerequisites and access

- **Quota:** Creating [reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) consumes the same regional quota used by standard VM deployments. If the requested VM size, region, or zone lacks quota or inventory, the reservation request fails and must be retried after adjusting the request or increasing quota.
- **Permission scope:** The subscription that owns the CRG manages reservation creation, resizing, deletion, and [sharing](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share) (preview). Sharing requires two sets of rights: the ODCR owner in the consumer subscription needs `Microsoft.Compute/capacityReservationGroups/share/action`; the VM owner in the consumer subscription needs `Microsoft.Compute/capacityReservationGroups/read`, `Microsoft.Compute/capacityReservationGroups/deploy`, `Microsoft.Compute/capacityReservationGroups/capacityReservations/read`, and `Microsoft.Compute/capacityReservationGroups/capacityReservations/deploy`.
- **Supported SKUs:** Only specific [VM series](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) are eligible for capacity reservations; confirm support through the `ResourceSkus` API before planning rollouts.

## Create and manage reservations

1. **Create a CRG:** In the Azure portal, select **Virtual machines > Capacity reservations > Add**. Provide the subscription, resource group, region, and optional [availability zone](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview).
2. **Add member reservations:** Within the CRG, specify VM size (for example, `Standard_D2s_v3`) and quantity. Azure immediately attempts to [reserve capacity](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview); if it's unavailable the deployment fails and must be retried after adjusting parameters.
3. **Associate workloads:** When deploying a VM or scale set, set the `capacityReservationGroup.id` property so the workload [consumes the reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) and receives the capacity SLA.
4. **Adjust quantities:** Update the reservation to increase or reduce the quantity. [Reducing to zero](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) releases the capacity but retains metadata, which is useful when pausing workloads temporarily.
5. **Delete reservations:** Remove all associated VMs and reduce the quantity to zero before [deleting a member reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) or its CRG to avoid orphaned associations.

## Sharing across subscriptions (preview)

> This feature is in public preview. Portal support isn't available; use CLI, PowerShell, or REST API. See [preview terms](https://azure.microsoft.com/support/legal/preview-supplemental-terms/). **Source**: [Share a capacity reservation group](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share)

Sharing lets a central subscription guarantee capacity for dependent workloads:

1. **Designate roles:** Assign an [On-demand Capacity Reservation (ODCR) owner](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share?tabs=api-1%2Capi-2%2Capi-3%2Capi-4%2Capi-5%2Capi-6%2Cportal-7) in the consumer subscription with share permissions and VM owners with deploy permissions as required.
2. **Grant access:** From the producer subscription, add consumer subscription IDs to the [CRG share list](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share?tabs=api-1%2Capi-2%2Capi-3%2Capi-4%2Capi-5%2Capi-6%2Cportal-7). You can share individual CRGs or all CRGs in the provider subscription, and up to 100 consumer subscriptions can be granted access per group. If you're sharing zonal capacity reservations, [validate zone alignment between producer and consumer subscriptions](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share) because Azure assigns different logical-to-physical zone mappings per subscription and mismatched zones won't fail at deployment time but will result in workloads landing in the wrong physical zones.
3. **Deploy from consumers:** Consumer subscriptions enumerate shared CRGs and specify the `capacityReservationGroup` field during VM deployment. [Capacity usage is billed](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share?tabs=api-1%2Capi-2%2Capi-3%2Capi-4%2Capi-5%2Capi-6%2Cportal-7) to the provider subscription, while VM runtime usage is billed to the consuming subscription.
4. **Revoke:** Remove the consumer subscription or associated identities from the share list to stop new deployments. [Existing VMs must be disassociated](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share?tabs=api-1%2Capi-2%2Capi-3%2Capi-4%2Capi-5%2Capi-6%2Cportal-7) or deallocated before revocation completes.

## Overallocating and utilization states

CRGs support temporary overallocations to absorb burst traffic:

- **Reserved capacity available:** Allocated VM count is lower than reserved quantity. Consider [reducing quantity](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) if the buffer is no longer required.
- **Reservation consumed:** Allocated VM count equals reserved quantity. [Additional workloads deploy without SLA](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) until capacity increases.
- **Reservation overallocated:** Allocated VM count exceeds reserved quantity. [Excess VMs run without the capacity SLA](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) and won't regain it after deallocation unless capacity is increased.

![Diagram that shows capacity reservation with the third VM allocated.](https://learn.microsoft.com/en-us/azure/virtual-machines/media/capacity-reservation-overview/capacity-reservation-3.jpg)

Use the [CRG Instance View](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) (`$expand=instanceview`) to track utilization and determine whether to right-size or overprovision reservations.

## Monitoring and reporting

- Export [Instance View data](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) regularly to track allocated versus reserved quantities per member reservation.
- Correlate reservation usage with [quota audits](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) (for example, `az quota usage list --resource-provider Microsoft.Compute`) to ensure reservation growth aligns with available regional quota.

## Automation patterns

- **Create/update reservations:** Use the [`Microsoft.Compute/capacityReservationGroups` REST API](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) or `az resource` commands within CI/CD pipelines to create CRGs and member reservations with declarative templates.
- **Associate workloads:** Embed the [`capacityReservationGroup` property](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) in ARM/Bicep templates or Terraform modules so deployments automatically consume the reservation when promoted to production.
- **Sharing automation:** Script [share assignments](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share?tabs=api-1%2Capi-2%2Capi-3%2Capi-4%2Capi-5%2Capi-6%2Cportal-7) by calling the `share` action with the desired consumer subscription list, ensuring idempotent operations during pipeline runs.

## Operational checklist

1. Validate required [quota and inventory](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) before reserving capacity for new regions or VM sizes.
2. Review [reservation utilization](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) regularly; adjust quantities when buffers consistently remain unused or when overallocations persist.
