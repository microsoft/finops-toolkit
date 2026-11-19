---
name: azure-capacity-management
description: |
  This skill should be used when the user asks about Azure capacity management, quota
  operations, or capacity planning for SaaS ISVs running workloads in their own Azure
  subscriptions under EA or MCA. Relevant queries include: how to increase VM quota across
  subscriptions, how quota groups work, how to create or share capacity reservation groups,
  what the difference is between capacity reservations and Azure Reservations or savings plans,
  how to request region access or zonal enablement, how logical and physical availability zones
  map across subscriptions, how to configure quota or budget or anomaly alerts, how AKS node
  pools interact with capacity reservations, how to manage non-compute quotas, how deployment
  stamps map to FinOps Planning & Estimating, Forecasting, Architecting & Workload Placement,
  Usage Optimization, and Governance, Policy & Risk, and how Azure capacity controls support
  estate-level governance. Also covers quota transfers, overallocation, SKU restrictions, CRG
  sharing, billing hierarchy, and subscription vending.
---

# Azure capacity management

Estate-level capacity and quota management for SaaS ISVs operating workloads in subscriptions they own or control under an [Enterprise Agreement (EA)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-enterprise-agreement) or [Microsoft Customer Agreement (MCA)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement). This skill aligns with the [ISV landing zone guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/isv-landing-zone) and covers pure SaaS and [stamp-based isolation](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern) patterns where customers are isolated through dedicated or shared deployment stamps inside the ISV's Azure estate.

Read the full Azure implementation reference at `references/docs/operations/capacity-and-quotas/README.md`.

## FinOps capability mapping

Treat Azure capacity management as implementation detail under the canonical FinOps Framework. Capacity evidence commonly supports Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization, Budgeting, Governance, Policy & Risk, and Automation, Tools & Services. Use [Well-Architected capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [reliable scaling](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling), and [workload supply chain guidance](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain) as Azure implementation guidance, not as a replacement framework. [Source](https://www.finops.org/framework/) [Source](https://www.finops.org/framework/domains/)

| FinOps capability | Capacity question | Azure surfaces |
|------|-------------|----------------|
| Planning & Estimating | What capacity does the planned workload, scenario, or stamp need? | Workload requirements, scale-unit assumptions, Azure Monitor, estimates, FinOps budgets |
| Forecasting | When will demand exceed quota, region, SKU, zone, or reserved-capacity headroom? | Historical usage, growth trends, forecast breach dates, capacity planning models |
| Architecting & Workload Placement | Which regions, zones, SKUs, quota pools, or deployment patterns should change? | SKU availability, region access, quota groups, capacity reservation groups, CRG sharing, overallocation |
| Usage Optimization | Which allocated capacity, quota, or deployment pattern is underused or inefficient? | Utilization, headroom, rightsizing evidence, unused reserved capacity, demand signals |
| Rate Optimization | Where should capacity guarantees be coordinated with reservations or savings plans? | Benefit recommendations, commitment utilization, CRG utilization, pricing evidence from FinOps Hub |
| Governance, Policy & Risk | Which capacity risks need ownership, exception review, or escalation? | Approved regions and SKUs, owner metadata, risk thresholds, exception status |
| Automation, Tools & Services | Which controls expose capacity risk before deployment or scale events? | Quota alerts, budget alerts, anomaly alerts, CI/CD gates, workflow status |

Read `references/docs/operations/capacity-planning/README.md` for forecasting details and `references/docs/operations/capacity-governance/README.md` for the governance program design.

## Quota operations

Azure assigns [default quota limits](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) per subscription. EA subscriptions typically start with 350 cores; pay-as-you-go subscriptions start with 20 cores. Some VM series have offer restrictions that block deployment until you request access.

Key workflows:
- **Region access:** Submit a [region access support request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) when a subscription can't deploy to a restricted region.
- **Zonal enablement:** Submit a [zonal enablement request](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series) for restricted VM series in specific availability zones.
- **Quota increases:** Use [per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests) for individual subscriptions or [quota group limit increases](https://learn.microsoft.com/en-us/azure/quotas/quota-group-limit-increase) for grouped subscriptions.

CLI reference:
```bash
# List quota usage for a subscription
az quota usage list --scope /subscriptions/{sub-id}/providers/Microsoft.Compute/locations/{location}

# Request a quota increase
az quota create --resource-name "StandardDSv3Family" --scope /subscriptions/{sub-id}/providers/Microsoft.Compute/locations/{location} --limit-object value=500
```

Read `references/docs/operations/quota/README.md` for the complete quota operations reference.

## Quota groups

[Quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) are ARM objects that aggregate compute quota across eligible subscriptions at the management group scope. They reduce stranded VM-family headroom and let you request group-level increases.

**Prerequisites:** Register the `Microsoft.Quota` resource provider on each member subscription. The management group must exist before creating the quota group.

**Limitations:**
- IaaS compute only — doesn't cover storage, networking, or PaaS services
- A subscription can belong to a single quota group at a time ([source](https://learn.microsoft.com/en-us/azure/quotas/quota-groups))
- Doesn't grant region or zone access — those require separate support requests
- [Quota transfers](https://learn.microsoft.com/en-us/azure/quotas/transfer-quota-groups) move allocation between member subscriptions but don't change the group total

**Lifecycle:** Create the quota group under a management group, [add subscriptions](https://learn.microsoft.com/en-us/azure/quotas/add-remove-subscriptions-quota-group), then request group-level limit increases. Monitor allocation snapshots and transfer as demand shifts between subscriptions.

Read `references/docs/operations/quota-groups/README.md` for the complete reference including ARM lifecycle, transfer mechanics, and monitoring integration.

## Capacity reservations

[Capacity reservation groups (CRGs)](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) guarantee compute capacity for specific VM sizes in a region or availability zone. CRGs are capacity guarantees, not pricing commitments — unused reserved capacity is billed at the pay-as-you-go rate for the VM size.

**Cost implications:** Reserved capacity is billed whether or not VMs run against it. Pair CRGs with Azure Reservations or savings plans to get both capacity guarantee and pricing discount.

**Sharing (preview):** CRGs can be [shared across subscriptions](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share) within the same tenant. The ODCR owner in the consumer subscription needs `Microsoft.Compute/capacityReservationGroups/share/action`. The VM owner in the consumer subscription needs `Microsoft.Compute/capacityReservationGroups/read`, `Microsoft.Compute/capacityReservationGroups/deploy`, `Microsoft.Compute/capacityReservationGroups/capacityReservations/read`, and `Microsoft.Compute/capacityReservationGroups/capacityReservations/deploy`. Portal support isn't available in preview; use CLI, PowerShell, or REST API.

**Overallocation:** [Overallocation](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) lets you deploy more VMs than the reserved quantity. Excess VMs don't have capacity guarantees but benefit from the reservation when capacity is available.

**Zone alignment:** CRGs are zone-specific. Before sharing across subscriptions, verify logical-to-physical zone mapping with the `Get-AzAvailabilityZoneMapping.ps1` script — [logical zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) can map to different physical zones across subscriptions.

Read `references/docs/operations/capacity-reservations/README.md` for the complete reference including automation patterns (REST API, Bicep, Terraform).

## AKS capacity governance

AKS node pools consume VM quota and can associate with capacity reservation groups, but with constraints specific to the AKS lifecycle:

- **Node pool CRG association** happens at creation time — you can't associate an existing node pool with a CRG after the fact
- **Identity requirement:** The AKS cluster must use a [user-assigned managed identity](https://learn.microsoft.com/en-us/azure/aks/use-managed-identity) with `Microsoft.Compute/capacityReservationGroups/read` permission on the CRG
- **Disassociation** removes the CRG association but doesn't delete the node pool
- **Zone alignment** matters for cross-subscription CRG sharing — verify physical zone mapping before configuring AKS node pools against shared CRGs

Read `references/docs/operations/aks-capacity/README.md` for the complete reference including Bicep and Terraform examples.

## Non-compute quotas

Storage accounts, App Service plans, Cosmos DB throughput, Service Bus namespaces, Key Vault transactions, and other services have their own quota limits outside the compute quota system. Quota groups don't cover these — manage them through standard [quota requests](https://learn.microsoft.com/en-us/azure/quotas/storage-account-quota-requests) and service-specific scaling controls.

Read `references/docs/operations/non-compute-quotas/README.md` for service-specific quota references.

## Monitoring and governance

Three alert types cover the capacity governance space:

1. **Quota alerts:** [Azure Monitor alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting) triggered when quota usage crosses a configured threshold. Requires Reader or higher on the subscription.
2. **Budget alerts:** [Cost Management alerts](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending) triggered when actual or forecasted spend exceeds budget thresholds. Uses Cost Management RBAC.
3. **Anomaly alerts:** Cost Management anomaly detection that flags unexpected spending patterns. Deploy with `references/scripts/anomaly-alerts/Deploy-AnomalyAlert.ps1` or bulk deploy with `references/scripts/anomaly-alerts/Deploy-BulkALZ.ps1`.

**Governance cadence:** Monthly quota reviews, quarterly capacity planning cycles, and post-incident reviews when scaling events fail. Read `references/docs/operations/monitoring-alerting/README.md` for alert configuration details and `references/docs/operations/capacity-governance/README.md` for the governance program design.

## Scripts quick reference

| Script | Path | Purpose |
|--------|------|---------|
| Get-AzVMQuotaUsage.ps1 | `references/scripts/quota/` | Multi-threaded quota analysis across subscriptions |
| Show-AzVMQuotaReport.ps1 | `references/scripts/quota/` | Single-threaded quota reporting |
| Get-AzAvailabilityZoneMapping.ps1 | `references/scripts/quota/` | Logical-to-physical zone mapping |
| Get-BenefitRecommendations.ps1 | `references/scripts/rate/` | Reservation and savings plan recommendations |
| Deploy-AnomalyAlert.ps1 | `references/scripts/anomaly-alerts/` | Deploy cost anomaly alerts |
| Deploy-BulkALZ.ps1 | `references/scripts/anomaly-alerts/` | Bulk deploy anomaly alerts |
| Deploy-Budget.ps1 | `references/scripts/budgets/` | Deploy individual budgets |
| Deploy-BulkBudgets.ps1 | `references/scripts/budgets/` | Bulk deploy budgets |
| Suppress-AdvisorRecommendations.ps1 | `references/scripts/advisor/` | Suppress Advisor recommendations |
| Serverless SQL workbook | `references/scripts/serverless-sql-storage/` | Azure Monitor workbook for serverless SQL allocated vs. used storage; identifies databases worth shrinking to reclaim billing waste |

Read the README in each script directory for parameter requirements and prerequisites.

## Key distinctions

These are commonly confused — keep them separated:

- **Capacity reservation vs Azure Reservation vs savings plan:** [Capacity reservations](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview) guarantee compute supply. [Azure Reservations](https://www.finops.org/framework/capabilities/rate-optimization/) and [savings plans](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/) provide pricing discounts. Capacity guarantees supply; pricing commitments reduce cost.
- **Quota group vs management group:** [Quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) aggregate compute quota. Management groups organize subscriptions for RBAC and policy. Quota groups are created under management groups but don't inherit their policy or access controls.
- **Logical vs physical zone:** [Logical zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview#configuring-resources-for-availability-zone-support) are subscription-specific labels. Physical zones are datacenter locations. Zone 1 in subscription A may map to a different physical zone than zone 1 in subscription B.
- **Region access vs quota increase:** Quota increases raise limits within an already-enabled region. [Region access requests](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process) unblock a restricted region for the subscription.

## Operational agent

The `azure-capacity-manager` agent is a capacity evidence specialist for FinOps workflows. It handles operational tasks like quota analysis and reservation evaluation, maps Azure capacity evidence back to FinOps capabilities, has access to the same references, and can run scripts and `az` commands for live operations.

## Documentation map

| Domain | Reference path |
|--------|---------------|
| Azure capacity reference | `references/docs/operations/capacity-and-quotas/README.md` |
| Glossary | `references/docs/operations/glossary.md` |
| Quota operations | `references/docs/operations/quota/README.md` |
| Quota groups | `references/docs/operations/quota-groups/README.md` |
| Capacity reservations | `references/docs/operations/capacity-reservations/README.md` |
| AKS capacity | `references/docs/operations/aks-capacity/README.md` |
| Non-compute quotas | `references/docs/operations/non-compute-quotas/README.md` |
| Monitoring and alerting | `references/docs/operations/monitoring-alerting/README.md` |
| Capacity governance | `references/docs/operations/capacity-governance/README.md` |
| Capacity planning | `references/docs/operations/capacity-planning/README.md` |
| Billing (EA) | `references/docs/billing/legacy/README.md` |
| Billing (MCA) | `references/docs/billing/modern/README.md` |
| Deployment patterns | `references/docs/deployment/README.md` |
| Tools and scripts | `references/docs/operations/tools-scripts/README.md` |
| Quota scripts | `references/scripts/quota/README.md` |
| Anomaly alerts | `references/scripts/anomaly-alerts/README.md` |
| Budgets | `references/scripts/budgets/README.md` |
| Rate optimization | `references/scripts/rate/README.md` |
| Serverless SQL storage | `references/scripts/serverless-sql-storage/README.md` |

## Notification procedures

<!-- // T-20: RTM FR-10.1, FR-10.2 -->
The capacity manager can send alerts and reports through [SRE Agent's notification connectors](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications). Use Teams for urgent capacity events and email for periodic reports.

### Teams channel alerts

Use Teams notifications for urgent capacity events that need immediate attention, following the [Azure SRE Agent notification guidance](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications). The SRE Agent sends messages through the Teams connector in HTML format, so keep the payload compact, scannable, and action-oriented, as described in [Send notifications from Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications).

**When to send Teams alerts:**
- Quota utilization exceeds 80 percent for any VM family in a production region.
- VM deployment fails with a quota or capacity error.
- Capacity reservation group utilization drops below 50 percent, which points to wasted spend.
- Quota group is depleted or nearly depleted.
- Region access or zonal enablement request is needed.

**Teams alert template:**

Use this HTML template when you compose a Teams message. Include alert severity, the affected resource, current state, the recommended action, and links to the relevant Azure portal blades, following [Send notifications from Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications).

```html
<h3>⚠️ Quota utilization alert</h3>
<p><b>Severity:</b> warning<br>
<b>VM family:</b> Standard_D_v5<br>
<b>Region:</b> eastus<br>
<b>Subscription:</b> prod-001<br>
<b>Usage:</b> 85/100 vCPUs (85%)</p>
<p><b>Recommended action:</b> Request a quota increase before the next deployment cycle.</p>
<p>
  <a href="https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade">Open quota blade</a><br>
  <a href="https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.Compute%2FcapacityReservationGroups">Open capacity reservation groups</a>
</p>
```

### Email capacity reports

Use Outlook email for periodic capacity reports and non-urgent recommendations, following the same [Azure SRE Agent notification guidance](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications). The SRE Agent sends email through the Outlook connector in HTML format, so structure the message for scanning first, and detailed follow-up second.

**When to send email reports:**
- Weekly capacity digest, including quota utilization trends across the estate.
- Reservation expiring within 30 days, including a renewal recommendation and cost analysis.
- Monthly savings plan optimization review.
- Quarterly capacity planning summary.
- Post-incident capacity analysis.

**Email report template:**

Use this HTML template for email reports. Include the report title, date range, a summary table of key metrics, highlighted findings, recommended actions with priority, and links to Azure portal resources or supporting documentation, as described in [Send notifications from Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications).

```html
<h2>Weekly capacity digest</h2>
<p><b>Period:</b> March 3–9, 2026<br>
<b>Subscriptions analyzed:</b> 47</p>
<h3>Key findings</h3>
<table border="1" cellpadding="8">
<tr><th>Region</th><th>VM family</th><th>Utilization</th><th>Action</th></tr>
<tr><td>eastus</td><td>Standard_D_v5</td><td>92%</td><td>Request increase</td></tr>
<tr><td>westus2</td><td>Standard_E_v5</td><td>78%</td><td>Monitor</td></tr>
</table>
<h3>Recommendations</h3>
<ol>
<li>Request quota increase for Standard_D_v5 in eastus (critical)</li>
<li>Review CRG utilization in westeurope—45% utilized, consider right-sizing</li>
<li>Savings plan expires April 15—evaluate renewal versus pay-as-you-go</li>
</ol>
<p>
  <a href="https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade">Open quota blade</a><br>
  <a href="https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting">Review quota monitoring guidance</a>
</p>
```

### Scheduled notification patterns

Configure recurring notifications with [Azure SRE Agent scheduled tasks](https://learn.microsoft.com/en-us/azure/sre-agent/scheduled-tasks), and pair the schedule with the connector flow from [Send notifications from Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications).

- Daily: quota utilization check, then send a Teams alert if any family is above 80 percent.
- Weekly: capacity digest, then send email to stakeholders.
- Monthly: savings plan and reservation review, then send email with recommendations.
