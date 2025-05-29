---
title: FinOps best practices for compute
description: This article provides FinOps best practices for compute services, including cost optimization, efficiency improvements, and insights into Azure resources.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with compute services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for compute

This article outlines a collection of proven FinOps practices for compute services. It provides guidance on optimizing costs, improving efficiency, and gaining insights into your compute resources in Azure. The practices are categorized based on the type of compute service, such as virtual machines (VM), Azure Kubernetes Service (AKS), and Azure Functions.

<br>

## Azure Kubernetes Service

The following section provides an Azure Resource Graph (ARG) query for AKS clusters. The query helps you gain insights into your VMs.

### Query - AKS cluster

This ARG query retrieves detailed information about AKS clusters in your Azure environment.

**Category**

Resource management

**Query**

```kusto
resources
| where type == "microsoft.containerservice/managedclusters"
| extend AgentPoolProfiles = properties.agentPoolProfiles
| mvexpand AgentPoolProfiles
| project
    id,
    ProfileName = tostring(AgentPoolProfiles.name),
    Sku = tostring(sku.name),
    Tier = tostring(sku.tier),
    mode = AgentPoolProfiles.mode,
    AutoScaleEnabled = AgentPoolProfiles.enableAutoScaling,
    SpotVM = AgentPoolProfiles.scaleSetPriority,
    VMSize = tostring(AgentPoolProfiles.vmSize),
    nodeCount = tostring(AgentPoolProfiles.['count']),
    minCount = tostring(AgentPoolProfiles.minCount),
    maxCount = tostring(AgentPoolProfiles.maxCount),
    location,
    resourceGroup,
    subscriptionId,
    AKSname = name
```

<br>

## Virtual machines

Azure virtual machines (VMs) are one of several types of [on-demand, scalable computing resources that Azure offers](/azure/architecture/guide/technology-choices/compute-decision-tree). Typically, you choose a VM when you need more control over the computing environment than the other choices offer.

An Azure VM gives you the flexibility of virtualization without having to buy and maintain the physical hardware that runs it. However, you still need to maintain the VM by performing tasks, such as configuring, patching, and installing the software that runs on it.

Related resources:

- [Virtual machines product page](https://azure.microsoft.com/products/virtual-machines)
- [Virtual machine pricing](https://azure.microsoft.com/pricing/details/virtual-machines)
- [Virtual machine documentation](/azure/virtual-machines)
- [Azure services for on-demand, scalable compute](/azure/architecture/guide/technology-choices/compute-decision-tree)

### Deallocate virtual machines

Recommendation: Deallocate VMs to avoid unused compute charges. Avoid stopping VMs without deallocating them.

#### About inactive VMs

VMs have two inactive states: Stopped and Deallocated.

Stopped VMs were shut down from within the operating system (for example, using the **Shut down** command). Stopped VMs are powered off, but Azure still reserves compute resources, like CPU and memory. Since compute resources are reserved and aren't available to for use with other VMs, these VMs continue to incur compute charges.

Deallocated VMs are stopped via cloud management APIs in the Azure portal, CLI, PowerShell, or other client tool. When a VM is deallocated, Azure releases the corresponding compute resources. Since compute resources are released, these VMs don't incur compute charges; however, it's important to note that both stopped and deallocated VMs continue to incur charges unrelated to compute, like storage charges from disks.

#### Identify stopped VMs

Use the following Azure Resource Graph (ARG) query to identify stopped VMs that aren't deallocated. It retrieves details about their power state, location, resource group, and subscription ID.

<!-- cSpell:ignore tostring, virtualmachines -->
```kusto
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend PowerState = tostring(properties.extended.instanceView.powerState.displayStatus)
| where PowerState !in =('VM deallocated', 'VM running')
| project
    ResourceId = id,
    PowerState,
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

### Use commitment discounts

Recommendation: Use commitment discounts to save up to 72% compared to list costs.

#### About commitment discounts

Commitment discounts are financial incentives offered to organizations who commit to using Azure services for a specified period or term, typically one or three years. By agreeing to a fixed amount of usage or spend (cost) for the term, organizations can benefit from significant discounts (up to 72%) compared to list prices. Discounts are applied to eligible resources, helping organizations save on their cloud costs while providing flexibility and predictability in their budgeting.

To learn more about commitment discounts, refer to the [Rate optimization capability](../framework/optimize/rates.md).

#### Measure virtual machine commitment discount coverage

Use the following FinOps hub query to measure overall VM commitment discount coverage.

<!-- cSpell:ignore countif, leftover, strcat -->
```kusto
Costs
| where ResourceType =~ 'Virtual machine'
| where x_SkuMeterCategory startswith 'Virtual Machines'
//
// Join with prices to filter out ineligible SKUs
| extend tmp_MeterKey = strcat(substring(ChargePeriodStart, 0, 7), x_SkuMeterId)
| project tmp_MeterKey, EffectiveCost, PricingCategory, CommitmentDiscountCategory, ResourceName, x_ResourceGroupName, SubAccountName, BillingCurrency
| join kind=leftouter (
    Prices
    | where x_SkuMeterCategory startswith 'Virtual Machines'
    | summarize sp = countif(x_SkuPriceType == 'SavingsPlan'), ri = countif(x_SkuPriceType == 'ReservedInstance')
        by tmp_MeterKey = strcat(substring(x_EffectivePeriodStart, 0, 7), x_SkuMeterId)
    | project tmp_MeterKey, x_CommitmentDiscountSpendEligibility = iff(sp == 0, 'Not Eligible', 'Eligible'), x_CommitmentDiscountUsageEligibility = iff(ri == 0, 'Not Eligible', 'Eligible')
) on tmp_MeterKey
| extend x_CommitmentDiscountUsageEligibility = iff(isempty(x_CommitmentDiscountUsageEligibility), '(missing prices)', x_CommitmentDiscountUsageEligibility)
| extend x_CommitmentDiscountSpendEligibility = iff(isempty(x_CommitmentDiscountSpendEligibility), '(missing prices)', x_CommitmentDiscountSpendEligibility)
//
// Sum costs
| summarize
    TotalCost = sum(EffectiveCost),
    OnDemandCost = sumif(EffectiveCost, PricingCategory == 'Standard'),
    SpotCost = sumif(EffectiveCost, PricingCategory == 'Dynamic'),
    CommittedCost = sumif(EffectiveCost, PricingCategory == 'Committed'),
    CommittedSpendCost = sumif(EffectiveCost, CommitmentDiscountCategory == 'Spend'),
    CommittedUsageCost = sumif(EffectiveCost, CommitmentDiscountCategory == 'Usage')
    by x_CommitmentDiscountUsageEligibility, x_CommitmentDiscountSpendEligibility, BillingCurrency
| extend OnDemandPercent = round(OnDemandCost / TotalCost * 100, 2)
| extend CoveragePercent = round(CommittedCost / TotalCost * 100, 2)
| extend CoverageUsagePercent = round(CommittedUsageCost / TotalCost * 100, 2)
| extend CoverageSpendPercent = round(CommittedSpendCost / TotalCost * 100, 2)
| order by CoveragePercent desc
```

Use the following query to measure the cost breakdown per VM, including coverage of commitment discounts.

```kusto
Costs
| where ResourceType =~ 'Virtual machine'
| where x_SkuMeterCategory startswith 'Virtual Machines'
//
// Join with prices to filter out ineligible SKUs
| extend tmp_MeterKey = strcat(substring(ChargePeriodStart, 0, 7), x_SkuMeterId)
| project tmp_MeterKey, EffectiveCost, PricingCategory, CommitmentDiscountCategory, ResourceName, x_ResourceGroupName, SubAccountName, BillingCurrency
| join kind=leftouter (
    Prices
    | where x_SkuMeterCategory startswith 'Virtual Machines'
    | summarize sp = countif(x_SkuPriceType == 'SavingsPlan'), ri = countif(x_SkuPriceType == 'ReservedInstance')
        by tmp_MeterKey = strcat(substring(x_EffectivePeriodStart, 0, 7), x_SkuMeterId)
    | project tmp_MeterKey, x_CommitmentDiscountSpendEligibility = iff(sp == 0, 'Not Eligible', 'Eligible'), x_CommitmentDiscountUsageEligibility = iff(ri == 0, 'Not Eligible', 'Eligible')
) on tmp_MeterKey
| extend x_CommitmentDiscountUsageEligibility = iff(isempty(x_CommitmentDiscountUsageEligibility), '(missing prices)', x_CommitmentDiscountUsageEligibility)
| extend x_CommitmentDiscountSpendEligibility = iff(isempty(x_CommitmentDiscountSpendEligibility), '(missing prices)', x_CommitmentDiscountSpendEligibility)
//
// Sum costs by resource
| summarize
    TotalCost = sum(EffectiveCost),
    OnDemandCost = sumif(EffectiveCost, PricingCategory == 'Standard'),
    SpotCost = sumif(EffectiveCost, PricingCategory == 'Dynamic'),
    CommittedCost = sumif(EffectiveCost, PricingCategory == 'Committed'),
    CommittedSpendCost = sumif(EffectiveCost, CommitmentDiscountCategory == 'Spend'),
    CommittedUsageCost = sumif(EffectiveCost, CommitmentDiscountCategory == 'Usage')
    by ResourceName, x_ResourceGroupName, SubAccountName, x_CommitmentDiscountUsageEligibility, x_CommitmentDiscountSpendEligibility, BillingCurrency
| extend OnDemandPercent = round(OnDemandCost / TotalCost * 100, 2)
| extend CoveragePercent = round(CommittedCost / TotalCost * 100, 2)
| extend CoverageUsagePercent = round(CommittedUsageCost / TotalCost * 100, 2)
| extend CoverageSpendPercent = round(CommittedSpendCost / TotalCost * 100, 2)
| order by CoveragePercent desc
```

To learn more about FinOps hubs, refer to [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md).

### Query - Virtual machine scale set details

This query analyzes Virtual Machine Scale Sets in your Azure environment based on their SKU, spot VM priority, and priority mix policy. It provides insights for cost optimization and resource management strategies.

**Category**

Resource management

**Query**

```kusto
resources
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend SpotVMs = tostring(properties.virtualMachineProfile.priority)
| extend SpotPriorityMix = tostring(properties.priorityMixPolicy)
| extend SKU = tostring(sku.name)
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| project id, SKU, SpotVMs, SpotPriorityMix, subscriptionId, resourceGroup, location
```

### Query - Virtual machine processor type analysis

This query identifies the processor type (ARM, AMD, or Intel) used by VMs in your Azure environment. It helps in understanding the distribution of VMs across different processor architectures, which is useful for optimizing workload performance and cost efficiency.

**Category**

Resource management

**Query**

```kusto
resources
| where type == 'microsoft.compute/virtualmachines'
| extend vmSize = properties.hardwareProfile.vmSize
| extend processorType = case(
    // ARM Processors
    vmSize has "Epsv5"
        or vmSize has "Epdsv5"
        or vmSize has "Dpsv5"
        or vmSize has "Dpdsv", "ARM",
    // AMD Processors
    vmSize has "Standard_D2a"
        or vmSize has "Standard_D4a"
        or vmSize has "Standard_D8a"
        or vmSize has "Standard_D16a"
        or vmSize has "Standard_D32a"
        or vmSize has "Standard_D48a"
        or vmSize has "Standard_D64a"
        or vmSize has "Standard_D96a"
        or vmSize has "Standard_D2as"
        or vmSize has "Standard_D4as"
        or vmSize has "Standard_D8as"
        or vmSize has "Standard_D16as"
        or vmSize has "Standard_D32as"
        or vmSize has "Standard_D48as"
        or vmSize has "Standard_D64as"
        or vmSize has "Standard_D96as", "AMD",
    "Intel"
)
| project vmName = name, processorType, vmSize, resourceGroup
```

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.BestPractices/featureName/Compute)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related products:

- [Azure Carbon Optimization](/azure/carbon-optimization/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
