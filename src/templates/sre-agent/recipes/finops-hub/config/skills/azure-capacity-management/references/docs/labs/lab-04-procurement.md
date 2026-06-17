# Lab 4: Procurement

## Overview

This lab covers how to procure compute capacity on Azure for production workloads. You'll work with [capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) to guarantee supply, assess zone alignment across subscriptions, configure sharing for multi-subscription architectures, and layer pricing commitments (Azure Reservations and savings plans) on top of supply guarantees.

The core concept: capacity reservations are supply instruments, not pricing instruments. They guarantee compute availability at pay-as-you-go rates. Pricing commitments (reservations and savings plans) are separate knobs that stack on top.

By the end of this lab, you'll understand:

- How to validate SKU availability before committing to capacity
- How to create and manage capacity reservation groups (CRGs)
- How to associate workloads with reserved capacity
- How to share reservations across subscriptions and handle zone alignment
- How to monitor utilization and overallocation
- How to evaluate savings plans and spot VMs as complementary procurement levers

**Prerequisites:** Access to an Azure subscription with contributor permissions, Azure CLI or PowerShell Az module installed, and familiarity with resource groups and virtual machines.

---

## Exercise 1: Validate SKU availability and zone alignment

Before creating capacity reservations, confirm that the VM SKUs you need are available in your target regions and zones. Zone alignment matters when sharing CRGs across subscriptions—logical zone 1 in subscription A may map to a different physical zone than zone 1 in subscription B.

### Step 1: Check SKU availability in a region

Use `Get-AzComputeResourceSku` to list available VM SKUs:

```powershell
Get-AzComputeResourceSku `
  -Location "eastus" |
  Where-Object {
    $_.ResourceType -eq "virtualMachines" -and
    $_.Name -eq "Standard_D4s_v5"
  } |
  Select-Object Name, Locations, Restrictions
```

This returns the SKU name, regions where it's available, and any restrictions (regional, zonal, or license-related).

### Step 2: Map logical zones to physical zones

Capacity reservations are created in specific logical zones (1, 2, 3). When you share a CRG across subscriptions, you need to confirm that logical zone 1 in the producer subscription aligns with the same physical infrastructure in the consumer subscription.

Run the provided script to fetch zone mappings:

```powershell
.\scripts/quota/Get-AzAvailabilityZoneMapping.ps1 `
  -SubscriptionId "your-subscription-id" `
  -Location "eastus"
```

Output shows:

```
TenantId              : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
SubscriptionId        : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Location              : eastus
LogicalZone           : 1
PhysicalZone          : 3
PhysicalZoneName      : US-VA-AZ-3
```

Run this for both the producer (CRG owner) and consumer subscriptions. If physical zones don't align, shared workloads may see latency or cross-zone traffic charges.

### Step 3: Check zone restrictions

Some SKUs are restricted to specific zones. Query the Compute Resource SKU API:

```powershell
Get-AzComputeResourceSku `
  -Location "eastus" |
  Where-Object { $_.Restrictions -ne $null } |
  Select-Object Name, @{ Label="RestrictionType"; Expression={$_.Restrictions.Type} }
```

If a SKU shows `ZonesRestricted`, it's available only in certain zones. If `RegionRestricted`, file a [region access request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process).

---

## Exercise 2: Create a capacity reservation group

A [capacity reservation group (CRG)](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) is a container for one or more capacity reservations in a specific region and logical zone. All VMs associated with a CRG must use the same zone.

### Step 1: Create a CRG via Azure portal

1. Go to **Home** > **Create a resource** > search for "capacity reservation group"
2. Select **Capacity Reservation Group** and choose **Create**
3. Fill in:
   - **Subscription:** Your target subscription
   - **Resource group:** Create or select one
   - **Name:** e.g., `crg-eastus-z1-prod`
   - **Region:** e.g., East US
   - **Availability zone:** e.g., 1
4. Select **Review + create**, then **Create**

### Step 2: Create a CRG via Azure CLI

```bash
az capacity reservation group create \
  --resource-group "rg-prod" \
  --name "crg-eastus-z1-prod" \
  --location "eastus" \
  --zones 1
```

### Step 3: Create a CRG via ARM template

```json
{
  "type": "Microsoft.Compute/capacityReservationGroups",
  "apiVersion": "2023-09-01",
  "name": "crg-eastus-z1-prod",
  "location": "eastus",
  "zones": ["1"],
  "properties": {}
}
```

Deploy with:

```bash
az deployment group create \
  --resource-group "rg-prod" \
  --template-file "crg-template.json"
```

### Step 4: Verify creation

```bash
az capacity reservation group show \
  --resource-group "rg-prod" \
  --name "crg-eastus-z1-prod"
```

You now have an empty CRG. Next, you'll add capacity reservations to it.

---

## Exercise 2b: Verify two-sided quota constraints

Before creating a capacity reservation group, confirm you have sufficient quota headroom. Quota works in two dimensions: total regional vCPU and per-family vCPU. Deployments must satisfy both constraints simultaneously, and CRG creation itself consumes quota.

### Step 1: Understand the quota dimensions

- **Regional vCPU limit:** Total vCores allocated to a single family (e.g., Standard D family) in a region, regardless of zone
- **Per-VM-family vCPU limit:** Individual per-family caps on regional allocation

When you create a capacity reservation for 10 Standard_D4s_v5 instances (40 vCores), those vCores are reserved immediately and count against your regional quota. If you have only 35 vCores available in the Standard D quota, the CRG creation will fail.

### Step 2: Check quota headroom

Use the quota script to confirm you have room:

```powershell
.\scripts/quota/Get-AzVMQuotaUsage.ps1 `
  -SubscriptionId "<subscription-id>" `
  -Location "eastus" |
  Where-Object { $_.SKU -match "Standard_D" }
```

For each family, calculate available headroom:

```
AvailableQuota = QuotaLimit - UsedQuota
```

If you plan to create a CRG for 10 D4s_v5 instances (40 vCores), ensure `AvailableQuota >= 40` in the Standard D family quota.

### Step 3: Common mistake—forgetting the headroom check

A common error: teams request a CRG without checking available quota first. The request fails at creation time, delaying workload deployments and forcing emergency quota increases. Always verify both dimensions before submitting the CRG creation request.

### Step 4: Plan quota growth

If your procurement roadmap spans multiple quarters, request quota increases early. Azure quota requests typically complete within 1–2 business days, so build review time into your release schedule. See the [VM quotas](https://learn.microsoft.com/en-us/azure/virtual-machines/quotas) reference for details on requesting increases.

---

## Exercise 3: Add member reservations and associate workloads

A capacity reservation is a reservation for a specific VM SKU and quantity within a CRG. Once created, you can [deploy VMs and associate them with the reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-associate-vm).

### Step 1: Create a capacity reservation within the CRG

Via Azure CLI:

```bash
az capacity reservation create \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5" \
  --sku "Standard_D4s_v5" \
  --quantity 10
```

This reserves 10 instances of Standard_D4s_v5 in zone 1 of East US. The reservation runs at pay-as-you-go rates—you're charged for all 10 slots whether or not you deploy VMs into them.

### Step 2: Deploy a VM and associate it with the reservation

Via Azure CLI:

```bash
az vm create \
  --resource-group "rg-prod" \
  --name "vm-prod-01" \
  --image "UbuntuLTS" \
  --size "Standard_D4s_v5" \
  --zone 1 \
  --capacity-reservation-group "/subscriptions/<subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod"
```

Replace `<subscription-id>` with your subscription ID. The `--zone` must match the CRG's zone.

### Step 3: Deploy via ARM template

```json
{
  "type": "Microsoft.Compute/virtualMachines",
  "apiVersion": "2023-09-01",
  "name": "vm-prod-01",
  "location": "eastus",
  "zones": ["1"],
  "properties": {
    "capacityReservationGroup": {
      "id": "/subscriptions/<subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod"
    },
    "hardwareProfile": {
      "vmSize": "Standard_D4s_v5"
    },
    "osProfile": {
      "computerName": "vm-prod-01",
      "adminUsername": "azureuser"
    },
    "storageProfile": {
      "imageReference": {
        "publisher": "Canonical",
        "offer": "0001-com-ubuntu-server-focal",
        "sku": "20_04-lts-gen2",
        "version": "latest"
      }
    },
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "/subscriptions/<subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Network/networkInterfaces/nic-prod-01"
        }
      ]
    }
  }
}
```

### Step 4: Check utilization

Query the reservation's instanceView to see allocated vs. reserved capacity:

```bash
az capacity reservation show \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5" \
  --expand "instanceview"
```

Look for:
- `availableCapacity`: slots not yet allocated to VMs
- `virtualMachinesAllocated`: count of running VMs using this reservation
- `remainingCapacity`: available slots

If `virtualMachinesAllocated` exceeds the reservation quantity, those excess VMs are in overallocation mode—they run without the supply SLA.

---

## Exercise 4: Share a CRG across subscriptions

Capacity reservations are created in a producer subscription and can be [shared with up to 100 consumer subscriptions](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share). This pattern is common in multi-tenant ISV platforms where a central team manages procurement and consumer teams deploy workloads.

### Step 1: Configure sharing on the CRG

Before enabling sharing, use this pre-share checklist to ensure readiness:

**Pre-share checklist:**

- **Zone mapping validated:** Run the zone mapping script in both producer and consumer subscriptions (from Exercise 1). Confirm that logical zones align (e.g., logical zone 1 maps to the same physical zone in both subscriptions)
- **Consumer subscriptions identified:** List all subscriptions that will use the shared CRG and confirm access permissions
- **RBAC roles assigned:** The consumer subscription (or specific service principals) must have Reader access at minimum. Confirm the identities that will associate VMs with the CRG
- **Billing scope aligned:** Decide whether the CRG's cost should roll up to the producer subscription's cost center or be shared. Align CRG ownership to cost boundaries so the team that owns the capacity also sees the cost in their billing scope

In the producer subscription, grant the consumer subscription access to the CRG:

```bash
az role assignment create \
  --role "Reader" \
  --assignee-object-id "<consumer-service-principal-id>" \
  --scope "/subscriptions/<producer-subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod"
```

For UI-based assignment, go to the CRG in the producer subscription:
1. Select **Access control (IAM)**
2. Select **Add** > **Add role assignment**
3. Role: **Reader**
4. Assign to: Service principal or user from the consumer subscription
5. Select **Save**

See [capacity reservation group sharing](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share) for detailed steps.

### Step 2: Deploy from a consumer subscription

In the consumer subscription, create a VM and reference the CRG by its full resource ID:

```bash
az vm create \
  --resource-group "rg-consumer" \
  --name "vm-consumer-01" \
  --image "UbuntuLTS" \
  --size "Standard_D4s_v5" \
  --zone 1 \
  --capacity-reservation-group "/subscriptions/<producer-subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod"
```

### Step 3: Verify zone alignment

Before deploying from the consumer subscription, confirm that logical zone 1 in the producer subscription aligns with logical zone 1 in the consumer subscription. Run the zone mapping script in both subscriptions and compare physical zone names. If they differ, file a [zonal enablement request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) to address the misalignment.

### Step 4: Monitor shared utilization

The producer subscription owner can see all allocated VMs across all consumer subscriptions. In the producer subscription:

```bash
az capacity reservation show \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5" \
  --expand "instanceview"
```

The `virtualMachinesAllocated` count includes VMs from consumer subscriptions.

---

## Exercise 5: Monitor overallocation and utilization

[Overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) happens when you deploy more VMs than the reserved quantity. Overallocated VMs run without the supply SLA and can be interrupted if capacity is needed.

### Step 1: Deploy beyond reserved capacity

You have a reservation for 10 Standard_D4s_v5 instances. Deploy 12 VMs:

```bash
for i in {1..12}; do
  az vm create \
    --resource-group "rg-prod" \
    --name "vm-prod-$i" \
    --image "UbuntuLTS" \
    --size "Standard_D4s_v5" \
    --zone 1 \
    --capacity-reservation-group "/subscriptions/<subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod" \
    --no-wait
done
```

### Step 2: Check utilization states

```bash
az capacity reservation show \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5" \
  --expand "instanceview"
```

The output shows three capacity states:

1. **Available**: Reserved slots not yet allocated (reserved - allocated)
2. **Consumed**: VMs running within the reserved quantity
3. **Overallocated**: VMs beyond the reserved quantity (virtualMachinesAllocated - reserved quantity)

For example, if reserved = 10 and allocated = 12, you have 0 available, 10 consumed, and 2 overallocated.

### Step 3: Understand overallocation implications

Overallocated VMs don't have the availability SLA from the capacity reservation. They're useful for non-critical or batch workloads, but shouldn't be used for production services.

If you want to raise the reservation, run:

```bash
az capacity reservation update \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5" \
  --quantity 15
```

---

## Exercise 5b: Apply the create-migrate-delete pattern

You can't edit a capacity reservation's VM size or location in place. If you need to change a reservation's parameters, you must create a new reservation with the target specs, migrate running workloads, and delete the old reservation. This pattern has a cost implication: you'll pay for both reservations during the migration window.

### Step 1: Understand the immutability constraint

Once a capacity reservation is created, you cannot modify:

- SKU (e.g., changing from Standard_D4s_v5 to Standard_D8s_v5)
- Availability zone (e.g., moving from zone 1 to zone 2)
- Region (e.g., moving from East US to West US)

If your requirements change, the create-migrate-delete pattern is the only path forward.

### Step 2: Create a new CRG and capacity reservation

Create a new capacity reservation group in the target zone (if needed) and a new capacity reservation with the new SKU:

```bash
az capacity reservation group create \
  --resource-group "rg-prod" \
  --name "crg-eastus-z1-prod-new" \
  --location "eastus" \
  --zones 1

az capacity reservation create \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod-new" \
  --name "capres-standard-d8s-v5" \
  --sku "Standard_D8s_v5" \
  --quantity 10
```

### Step 3: Migrate workloads step by step

Follow this sequence to minimize downtime:

1. **Disassociate VMs from the old CRG** (they move to pay-as-you-go mode):

```bash
az vm update \
  --resource-group "rg-prod" \
  --name "vm-prod-01" \
  --capacity-reservation-group ""
```

2. **Associate the VM with the new CRG** (it now uses the new reservation):

```bash
az vm update \
  --resource-group "rg-prod" \
  --name "vm-prod-01" \
  --capacity-reservation-group "/subscriptions/<subscription-id>/resourceGroups/rg-prod/providers/Microsoft.Compute/capacityReservationGroups/crg-eastus-z1-prod-new"
```

3. **Verify the migration** by checking the instanceView:

```bash
az vm show \
  --resource-group "rg-prod" \
  --name "vm-prod-01" \
  --expand "instanceview" |
  jq '.capacityReservationGroup'
```

4. **Repeat for all workloads** until the old CRG is empty.

### Step 4: Understand the billing impact

During the migration window, you're paying for both the old and new capacity reservations. For example, if you're migrating 10 instances and each pays 10 vCores, you'll pay for 20 vCores across both reservations during the migration.

**Minimize double-billing:**

- Schedule migrations during off-peak hours to reduce the number of simultaneous VMs
- Batch VM migrations to complete within 1–2 hours rather than spreading over days
- Request a cost allocation tag or cost center split to track the migration costs separately

### Step 5: Delete the old CRG

Once all workloads have migrated, delete the old capacity reservation and CRG:

```bash
az capacity reservation delete \
  --resource-group "rg-prod" \
  --capacity-reservation-group-name "crg-eastus-z1-prod" \
  --name "capres-standard-d4s-v5"

az capacity reservation group delete \
  --resource-group "rg-prod" \
  --name "crg-eastus-z1-prod"
```

See [Capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) for more details on managing reservations across their lifecycle.

---

## Exercise 6: Pull savings plan recommendations and compare rate instruments

Capacity reservations guarantee supply at standard pay-as-you-go rates. To reduce costs further, layer pricing commitments—Azure Reservations (1-year or 3-year) or Savings Plans (1-year or 3-year)—on top of reserved capacity.

### Step 1: Get savings plan recommendations

Use the provided script to fetch recommendations from the Cost Management API:

```powershell
.\scripts/rate/Get-BenefitRecommendations.ps1 `
  -BillingScope "/subscriptions/<subscription-id>" `
  -LookBackPeriod 30 `
  -Term "P1Y"
```

This queries your actual usage over the past 30 days and recommends purchase quantities for a 1-year savings plan. Output includes:

```
SKU              : Standard_D4s_v5
RecommendedQty   : 8
RecommendedSpend : $18,000
AnnualSavings    : $4,500
```

The 80% heuristic: savings plans and reservations should cover ~80% of your expected usage. The remaining 20% runs at pay-as-you-go rates, giving you flexibility without over-committing.

### Step 2: Create a savings plan in the Azure portal

1. Go to **Cost Management + Billing** > **Savings plans**
2. Select **Buy savings plan**
3. Choose **Compute** and configure:
   - **Term:** 1-year or 3-year
   - **Billing frequency:** Monthly or upfront
   - **Scope:** Subscription or shared (if multi-subscription)
4. Review the recommendation and confirm purchase

See [savings plans for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview) for full details.

### Step 3: Compare rate instruments

You now have three layers:

1. **Capacity reservation (supply instrument):** Guarantees supply at PAYG rates. Unused slots cost money.
2. **Savings plan (pricing commitment):** Applies a discounted rate across your compute usage. Doesn't guarantee supply.
3. **Azure Reservation (pricing commitment):** Instance-based discount for 1-year or 3-year terms. Doesn't guarantee supply.

Strategy: Use capacity reservations for SKUs and regions where you need guaranteed supply. Layer savings plans or reservations on top to reduce the effective rate. For example:

- Reserve 80% of expected D4s_v5 demand in East US Zone 1 via a capacity reservation group
- Purchase a 1-year savings plan for 80% of the same volume to reduce the effective rate to ~25% below PAYG
- Let the remaining 20% run at PAYG rates to absorb spikes without over-committing

### Step 4: Monitor blended cost

Query your actual costs with and without commitments:

```bash
az costmanagement query --type "Usage" \
  --timeframe "MonthToDate" \
  --granularity "Daily" \
  --aggregation '{"totalCost":{"name":"PreTaxCost","function":"Sum"}}' \
  --grouping '[{"type":"Dimension","name":"ChargeType"}]'
```

This breaks down costs by charge type, helping you see the impact of capacity reservations and savings plans. See [FinOps rate optimization](https://www.finops.org/framework/capabilities/rate-optimization/) for rate optimization strategy.

---

## Exercise 7: Evaluate Spot VM placement scores

Spot VMs run on excess Azure capacity at steep discounts (up to 90% off PAYG) but can be evicted with 30 seconds' notice. They're ideal for non-critical workloads (batch jobs, dev/test, fault-tolerant services).

### Step 1: Check Spot placement scores

Before deploying Spot VMs, use the Spot Placement Score API to assess deployment success likelihood:

Via Azure CLI:

```bash
az compute-recommender spot-placement-score \
  --location "eastus" \
  --desired-locations "eastus" "westus2" \
  --desired-sizes "[{sku:Standard_D4s_v5}]" \
  --desired-count 10
```

Via REST API:

```bash
az rest \
  --method post \
  --url "/subscriptions/<subscription-id>/providers/Microsoft.Compute/locations/eastus/placementScores/spot/generate?api-version=2025-06-05" \
  --body '{
    "desiredLocations": ["eastus", "westus2"],
    "desiredSizes": [{"sku": "Standard_D4s_v5"}],
    "desiredCount": 10,
    "availabilityZones": false
  }'
```

Output includes a placement score—**High**, **Medium**, or **Low**—for each SKU-region combination, along with quota availability. A score of High indicates the deployment is highly likely to succeed; Low indicates low likelihood. Scores are point-in-time recommendations and don't guarantee allocation. If a SKU isn't available for your subscription, the API returns **Restricted SKU** instead of a placement score.

See the [Spot Placement Score documentation](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/spot-placement-score) for details.

### Step 2: Deploy a Spot VM

```bash
az vm create \
  --resource-group "rg-prod" \
  --name "vm-spot-01" \
  --image "UbuntuLTS" \
  --size "Standard_D4s_v5" \
  --priority "Spot" \
  --max-price "0.50" \
  --eviction-policy "Deallocate"
```

Set `--max-price` to your bid. If the spot price exceeds your bid, the VM is evicted. Use `--eviction-policy "Delete"` for stateless workloads or `--eviction-policy "Deallocate"` to pause the VM and avoid re-initialization costs.

### Step 3: Understand Spot capacity pool

Spot VMs use a separate capacity pool from reserved or standard PAYG VMs. You can have:

- 10 Standard_D4s_v5 instances in a capacity reservation group (supply SLA)
- 12 Standard_D4s_v5 PAYG instances (no SLA)
- 50 Standard_D4s_v5 Spot instances (no SLA, up to 90% discount)

All three types use the same SKU but different pricing and SLA models. See [Spot VMs overview](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms) for more detail.

---

## Exercise 8: Validate quota before large procurements

[Quota](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) limits how many vCores of each family you can allocate in a region. Before creating capacity reservations, confirm you have sufficient quota.

### Step 1: Check current quota usage

```powershell
.\scripts/quota/Get-AzVMQuotaUsage.ps1 `
  -SubscriptionId "<subscription-id>" `
  -Location "eastus"
```

Output shows:

```
SKU                 : Standard_D4s_v5
UsedQuota           : 6
QuotaLimit          : 20
AvailableQuota      : 14
RegionRestricted    : False
ZonesRestricted     : False
```

In this case, you've allocated 6 instances of D4s_v5 out of a 20-instance limit in East US.

### Step 2: Request a quota increase

If your procurement plan exceeds available quota, request an increase:

1. Go to **Help + support** > **New support request**
2. **Issue type:** Service and subscription limits (quotas)
3. **Quota type:** Compute-VM (cores) quotas
4. **Location:** Your target region
5. **SKU:** e.g., Standard D family
6. **New limit:** Enter desired quota
7. Submit the request

Azure reviews quota requests based on capacity availability. Requests typically complete within 1–2 business days.

### Step 3: Plan quota for multi-region and multi-zone

If you're procuring Standard_D4s_v5 across East US zone 1, East US zone 2, and West US zone 1, quota is counted per-region (not per-zone). A 30-instance capacity reservation in East US consumes 120 vCores from the East US Standard D quota, regardless of zone distribution.

---

## Wrap-up

Procurement is the foundation for capacity planning, cost management, and availability. The outputs of this lab feed into:

1. **Monitoring & Observability (Deck 5):** Track actual vs. reserved utilization, alert on overallocation, and audit cost allocation across teams
2. **Governance & automation:** Enforce procurement policies (e.g., "all prod VMs must use capacity reservations"), automate quota requests, and scale procurement based on demand signals

Key takeaways:

- Validate SKU availability and zone alignment before committing capacity
- Use capacity reservations for supply guarantees; layer savings plans or reservations for cost reduction
- Share CRGs across subscriptions for centralized procurement, but monitor zone alignment
- Spot VMs complement reserved capacity for non-critical, cost-sensitive workloads
- Monitor utilization regularly and adjust reservations quarterly based on actual demand
- Quota is a guardrail; request increases early to avoid allocation delays during scale-outs

### Billing scope alignment

Cost allocation varies by your agreement type. Align CRG boundaries to match your cost structure:

- **Enterprise Agreements (EA):** Capacity reservation purchases are visible at the billing account (enrollment) scope. If you have multiple cost centers or departments, create separate CRGs per cost center to track procurement costs separately
- **Microsoft Customer Agreement (MCA):** Capacity reservation purchases are visible at the billing profile scope. Align CRG ownership to billing profile boundaries so costs roll up correctly for chargeback or FinOps analysis

See [Understand Cost Management scopes](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-work-scopes) for guidance on mapping subscriptions, resource groups, and billing accounts to your organizational structure.

---

## Beyond VMs: PaaS capacity procurement

CRGs are VM-specific. For PaaS services, procurement uses reserved capacity pricing commitments rather than supply-side reservations. These commitments lock in discounted rates for 1-year or 3-year terms but don't guarantee physical capacity the way CRGs do.

- **Premium SSD v2:** Provisioned IOPS and throughput are billed independently from disk size. You configure capacity by adjusting IOPS and throughput values on the managed disk resource—there's no separate reservation mechanism. Purchase through the Azure portal or `az disk create`/`az disk update` with `--disk-iops-read-write` and `--disk-mbps-read-write` parameters. See [Premium SSD v2 overview](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types#premium-ssd-v2) for provisioning details.

- **Azure Database for PostgreSQL flexible server:** [Reserved capacity](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-reserved-capacity) provides vCore-based pricing discounts for 1-year or 3-year terms. Purchase through **Cost Management + Billing** > **Reservations** > **Add** > **Azure Database for PostgreSQL** in the portal, or use the [Reservations REST API](https://learn.microsoft.com/en-us/rest/api/reserved-vm-instances/).

- **Azure Database for MySQL flexible server:** [Reserved capacity](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concept-reserved-pricing) works the same way as PostgreSQL—vCore-based 1-year or 3-year commitments purchased through the portal reservations blade or REST API.

- **Azure SQL Managed Instance:** [Reserved capacity](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/reserved-capacity?view=azuresql) provides vCore-based pricing discounts by service tier (General Purpose, Business Critical). Purchase through the portal reservations blade, selecting the service tier, region, and term. Use `az reservations reservation-order purchase` for CLI-based procurement.

For all PaaS reserved capacity, the pricing discount applies automatically to matching resources in the reservation scope (subscription or shared). Unlike CRGs, these don't guarantee that capacity will be available at deployment time—they're cost optimization instruments only.

---

## References

- [Capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview)
- [Capacity reservation group sharing](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share)
- [Overallocation in capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate)
- [Associate VM to capacity reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-associate-vm)
- [Associate VMSS to capacity reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set-flex)
- [Remove VM from capacity reservation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-remove-vm)
- [Reserved Instance discounts](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations)
- [Savings plans for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)
- [Spot VMs overview](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms)
- [Spot Placement Score API](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/spot-placement-score)
- [Get-AzComputeResourceSku cmdlet](https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azcomputeresourcesku)
- [FinOps rate optimization](https://www.finops.org/framework/capabilities/rate-optimization/)
- [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations)
- [Zonal enablement requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series)
- [Region access requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process)
- [VM quotas](https://learn.microsoft.com/en-us/azure/virtual-machines/quotas)
- [Understand Cost Management scopes](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-work-scopes)
