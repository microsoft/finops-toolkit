---
title: Quota operations
parent: Capacity & quotas
nav_order: 4
---

# Quota operations guide

Use this guide when you're auditing or increasing Azure quotas so every request pulls from the same reference.

[Where this fits](../capacity-and-quotas/README.md): step 2 of the capacity journey. Use it to unblock regions and zones and confirm VM-family limits before moving quota into groups or reserving capacity. [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) [Source](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series)

## Understand default quotas and enforcement

- Azure enforces [quotas per subscription and region](https://learn.microsoft.com/en-us/azure/virtual-machines/quotas), tracking both total regional vCPUs and per VM-family vCPUs; deployments must stay within both limits or the [platform blocks the request](https://learn.microsoft.com/en-us/azure/quotas/regional-quota-requests).
- Default vCPU quotas vary by offer type. [Enterprise Agreement subscriptions default to 350 cores](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/ea-portal-agreements#resource-prepayment-and-requesting-quota-increases) for both the total regional quota and each VM family (D-series, E-series, etc.), while pay-as-you-go subscriptions default to 20 cores per region. Validate your actual limits in the [**Quotas**](https://learn.microsoft.com/en-us/azure/quotas/view-quotas) blade to confirm no offer restrictions are reducing your baseline.
- All quotas can be increased through support requests, regardless of the initial default assigned to your offer type.
- [Quota calculations](https://learn.microsoft.com/en-us/azure/virtual-machines/quotas) include allocated and deallocated virtual machines, so idle cores still count against the quota until resources are deleted or quota is increased.

## Understand offer restrictions

Azure applies [SKU restrictions based on your subscription's offer type](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-sku-not-available), blocking deployment of certain VM families in specific regions or zones even when quota is available. These restrictions exist independently of quota limits and you'll need to request access before deploying to affected areas.

### What offer restrictions are

- SKU restrictions tie to the subscription's offer type (pay-as-you-go, trial, student, MSDN, EA, or MCA Enterprise) and determine which VM families can deploy in each region and zone.
- Azure imposes two types of restrictions: [location restrictions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-sku-not-available) block the SKU from an entire region, while zone restrictions block specific availability zones within an otherwise accessible region.
- When [`Get-AzComputeResourceSku`](https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azcomputeresourcesku) shows `NotAvailableForSubscription` in the `Restriction` column, the SKU isn't available for this subscription's offer type, regardless of quota availability.

### Why restrictions exist

- Azure uses restrictions to [control capacity distribution](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-sku-not-available) across subscription tiers and manage datacenter resource allocation.
- Trial, student, and MSDN subscriptions face more restrictions because they're designed for development and learning scenarios rather than production workloads.
- Enterprise-tier subscriptions (EA and MCA Enterprise) have fewer restrictions, reflecting their use for production SaaS estates and mission-critical workloads.

### Error messages you'll see

When deployments fail because of offer restrictions, you'll encounter these error codes:

- [`SkuNotAvailable`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-sku-not-available)—the primary error when the requested SKU isn't available in the target region or zone. When triggered via ARM templates, this surfaces as `InvalidTemplateDeployment` during validation, and [no deployment history is created](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/find-error-code)—check the activity log instead.
- `ZonalAllocationFailed`—Azure can't allocate resources in the specific zone you requested, often because of zone restrictions or transient capacity constraints.
- `AllocationFailed`—a general allocation failure indicating capacity issues, restrictions, or other constraints preventing deployment.
- [`OverconstrainedAllocationRequest`](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/windows/allocation-failure)—too many constraints (VM size, availability zone, accelerated networking, proximity placement group, ephemeral disk, Ultra disk) prevent Azure from finding available capacity. Remove constraints incrementally to identify the blocker.

### Detect restrictions before deployment

- Run [`Get-AzVMQuotaUsage.ps1`](https://github.com/MSBrett/azcapman/tree/main/scripts/quota) to check restrictions before deploying. The script outputs `RegionRestricted` (True/False indicating whether the SKU is blocked for the entire region) and `ZonesRestricted` (comma-separated list of logical zones where the SKU is unavailable) columns for each subscription and location.
- Use [`Get-AzComputeResourceSku`](https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azcomputeresourcesku) directly to inspect the `Restrictions` property for specific SKUs, which exposes location and zone restrictions along with the reason code.
- Always check restrictions before filing quota increase requests, because increased quota won't help if the offer type blocks access to the SKU in your target region or zone.

### Remediate restrictions

- Submit a [zonal enablement request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) when you need access to specific zones for restricted VM families; the support workflow lets you select regions, logical zones, and VM series.
- File a [region access request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) when entire regions are blocked for your subscription, ensuring quotas and offer flags match your deployment plan before attempting scale-outs or quota transfers.
- Plan ahead for these requests—there's no guaranteed SLA for approval times, so factor enablement lead time into your capacity planning and deployment schedules.

### Special case: Spot VM capacity

- [Azure Spot VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms) use a [separate capacity pool](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms#frequently-asked-questions) from on-demand VMs, so a SKU can be available for regular deployments but have zero Spot capacity.
- The `Get-AzComputeResourceSku` cmdlet doesn't show Spot-specific availability. Use the [Spot Placement Score API](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/spot-placement-score) to evaluate deployment likelihood before committing to Spot-based architectures.
- Spot VMs have [no availability guarantees or SLA](https://learn.microsoft.com/en-us/azure/architecture/guide/spot/spot-eviction)—Azure can evict them whenever on-demand capacity is needed, providing [30 seconds total for detection and graceful shutdown](https://learn.microsoft.com/en-us/azure/architecture/guide/spot/spot-eviction), not 30 seconds after notification.
- Don't rely on Spot capacity for workloads where you've committed SLAs to your customers; use [on-demand capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) instead for guaranteed availability.

## Quota analysis scripts

> [!IMPORTANT]
> This repository includes PowerShell scripts for quota analysis developed through ISV engagements. These tools address quota management scenarios for organizations not yet using Quota Groups.

### Available scripts

| Script | Purpose | Use Case |
|--------|---------|----------|
| **Get-AzVMQuotaUsage.ps1** | Multi-threaded quota analysis with zone restrictions | Large-scale enterprise analysis across 100+ subscriptions |
| **Show-AzVMQuotaReport.ps1** | Single-threaded quota reporting | Smaller deployments or learning scenarios |
| **Get-AzAvailabilityZoneMapping.ps1** | Logical-to-physical zone mapping | Critical for multi-subscription architectures |

### Quick start

Download and run the multi-threaded quota analyzer:

```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MSBrett/azcapman/main/scripts/quota/Get-AzVMQuotaUsage.ps1" -OutFile "Get-AzVMQuotaUsage.ps1"

# Analyze specific SKUs and regions
.\Get-AzVMQuotaUsage.ps1 -SKUs @('Standard_D2s_v5', 'Standard_E2s_v5') -Locations @('eastus', 'westus2') -Threads 4
```

### Script capabilities

**Get-AzVMQuotaUsage.ps1** (Recommended for production):
- Analyzes quota usage across multiple subscriptions in parallel
- Reports zone restrictions for VM SKUs
- Maps logical zones to physical datacenters
- Outputs comprehensive CSV for further analysis
- Supports 4+ concurrent threads for faster processing

**Get-AzAvailabilityZoneMapping.ps1** (Essential for multi-subscription deployments):
- Shows how logical zones (1,2,3) map to physical zones per subscription
- Critical because Azure randomizes zone mappings per subscription
- Required for ensuring true zone alignment across subscriptions
- Outputs zone peering data for cross-subscription planning

[View complete script documentation →](https://github.com/MSBrett/azcapman/tree/main/scripts/quota)

## Audit regional quota and zone access

- Run `scripts/quota/Get-AzVMQuotaUsage.ps1` for comprehensive multi-threaded analysis or `scripts/quota/Show-AzVMQuotaReport.ps1` for simpler single-threaded reporting to enumerate VM family usage versus limits per subscription and region.
- Include `-UsePhysicalZones` when you need cross-subscription mapping, because [Azure maps physical datacenters to logical availability zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) differently per subscription and the `checkZonePeers` API exposes the authoritative mapping.
- Use `scripts/quota/Get-AzAvailabilityZoneMapping.ps1` to generate a complete zone mapping matrix before planning multi-subscription deployments that require zone alignment.
- Scope the scripts with `-SubscriptionIds` and `-Locations` to focus on business-critical subscriptions or surge regions, then export the CSV output and compare against [`az quota usage list`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) to validate the data against the Microsoft.Quota service.
- When you need to file a quota increase from automation, submit the request with [`az quota create`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) and record the request ID so you can track approvals and retry deployments deterministically.
- Flag regions where the report shows restricted or missing zones and initiate the [zonal enablement workflow](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) to request access for the required VM series and zones before attempting redeployments.
- If entire regions are unavailable for a subscription, raise a [region access request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) so that quota transfers or scale-outs do not fail when you move capacity between subscriptions.

## Regional and zonal access workflows

- [Region enablement requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) grant access to restricted geographies and ensure quotas and offer flags match planned deployments; submit through Azure support when the portal limits block deployments in new regions.
- [Zonal enablement requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) authorize deployments into specific availability zones for restricted VM families; use the support workflow to select regions, logical zones, and VM series before scaling out.
- Each subscription receives a [unique logical-to-physical zone mapping](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) at creation time, so use `checkZonePeers` when planning multi-subscription resilience to align physical fault domains.

## Create and govern quota groups

- Establish [quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) under the management group that owns your shared capacity so you can pool vCPU limits across EA and MCA subscriptions without filing support requests for every transfer. [Quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) have Azure-enforced constraints: they support only EA and MCA Enterprise subscriptions, apply exclusively to compute quota (VM cores), and require registration of the `Microsoft.Quota` resource provider.
- [Create the group](https://learn.microsoft.com/en-us/azure/quotas/create-quota-groups?tabs=rest-1%2Crest-2) via the Microsoft.Quota REST API or Azure portal once the GroupQuota Request Operator role is assigned at the management group scope.
- [Add newly provisioned or recycled subscriptions](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group?tabs=rest-1%2Crest-2) to the quota group so their existing limits are tracked centrally while retaining subscription-level enforcement at deployment time.

## Reallocate and increase capacity

- Increase compute capacity with [capacity reservation groups](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) when you need guaranteed VM availability, reserving specific VM sizes in targeted regions or zones with pay-as-you-go billing.
- [Share capacity reservation groups](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share) with up to 100 consumer subscriptions (preview) so platform teams own the reservation and consumer subscriptions consume capacity; unused reservations bill to the owner while VM usage accrues to consumers.
- Use [quota allocations to transfer unused cores](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups?tabs=rest-1) from retiring subscriptions back into the group and push them to surge subscriptions that need immediate capacity.
- Submit [group-level limit increase requests](https://learn.microsoft.com/en-us/azure/quotas/quota-group-limit-increase?tabs=rest-1) when aggregate demand outpaces the pooled limit; approved increases stamp capacity on the quota group so you can redistribute it without additional tickets.
- Continue to request [VM-family quota increases](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) for edge cases directly from **Quotas** when you need adjustments outside of the pooled families or regions.

## Reclaim and recycle subscriptions

- Recycle subscriptions with zonal or regional access rather than deleting them. There's no documented SLA for [zonal](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) or [regional enablement requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process)—the Azure engineering team manually reviews each request. If you offer SLAs to your customers, you can't guarantee infrastructure availability without pre-approved access flags in place.
- Before decommissioning a workload, [return its quota to the group](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups?tabs=rest-1) and keep the subscription for future use so that existing [zonal](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) and [regional access flags](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) remain in place and you avoid repeating the support-ticket workflow.
- When onboarding a new subscription, check the quota report and [`az quota list`](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) output to confirm the baseline allocations before moving workloads or transferring additional quota.

## Operational tips

- Schedule the [quota report](https://learn.microsoft.com/en-us/azure/virtual-machines/quotas) and [CLI usage checks](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest) to run after major deployments so the platform team has an auditable history of usage, available capacity, and zone coverage.
- If subscriptions span multiple tenants, pair the quota audits with the [`checkZonePeers` API](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) to ensure logical zone identifiers align before you redistribute workload placements.
