---
title: FinOps best practices for virtual machines
description: Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.
author: arclares
ms.date: 10/17/2024
ms.service: finops
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for virtual machines

Azure virtual machines (VMs) are one of several types of [on-demand, scalable computing resources that Azure offers](/azure/architecture/guide/technology-choices/compute-decision-tree). Typically, you choose a VM when you need more control over the computing environment than the other choices offer.

An Azure VM gives you the flexibility of virtualization without having to buy and maintain the physical hardware that runs it. However, you still need to maintain the VM by performing tasks, such as configuring, patching, and installing the software that runs on it.

<br>

<!--
## Understand cloud usage and cost
### Data ingestion
### Allocation
### Reporting and analytics
### Anomaly management
-->

### Query: Virtual machine scale set details

This query analyzes Virtual Machine Scale Sets (VMSS) in your Azure environment based on their SKU, spot VM priority, and priority mix policy. It provides insights for cost optimization and resource management strategies.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
resources
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend SpotVMs = tostring(properties.virtualMachineProfile.priority)
| extend SpotPriorityMix = tostring(properties.priorityMixPolicy)
| extend SKU = tostring(sku.name)
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| project id, SKU, SpotVMs, SpotPriorityMix, subscriptionId, resourceGroup, location
```

### Query: Virtual Machine processor type analysis

This query identifies the processor type (ARM, AMD, or Intel) used by Virtual Machines (VMs) in your Azure environment. It helps in understanding the distribution of VMs across different processor architectures, which is useful for optimizing workload performance and cost efficiency.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
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


<br>

<!--
## Quantify business value
### Planning and estimating
### Forecasting
### Budgeting
### Benchmarking
### Unit economics
<br>
-->

## Optimize cloud usage and cost

<!--
### Architecting for cloud
### Workload optimization
### Rate optimization
### Licensing and SaaS
### Cloud sustainability
-->

### Deallocate virtual machines

Recommendation: Deallocate VMs to avoid unused compute charges. Avoid stopping VMs without deallocating them.

#### About non-running VMs

VMs have 2 non-running states: Stopped and Deallocated.

Stopped VMs have been shut down from within the operating system (e.g., using the shut down command). Stopped VMs are powered off, but Azure still reserves compute resources, like CPU and memory. Since compute resources are reserved and cannot be used by other VMs, these VMs continue to incur compute charges.

Deallocated VMs are stopped via cloud management APIs in the Azure portal, CLI, PowerShell, or other client tool. When a VM is deallocated, Azure releases the corresponding compute resources. Since compute resources are released, these VMs will not incur compute charges; however, it is important to note that both stopped and deallocated VMs will incur non-compute charges, like storage charges from disks.

#### Identify stopped VMs

Use the following Azure Resource Graph (ARG) query to identify stopped VMs that have not been deallocated. It retrieves details about their power state, location, resource group, and subscription ID.

```kql
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

<br>

<!--
## Manage the FinOps practice
### FinOps practice operations
### FinOps education and enablement
### FinOps assessment
### Cloud policy and governance
### FinOps tools and services
### Chargeback and invoicing
### Onboarding workloads
### Intersecting disciplines
<br>
-->

## Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. [Create a new issue](https://aka.ms/ftk/ideas) with the details that you'd like to see either included here.

<br>

## Related content

Related resources:

- [About virtual machines](https://azure.microsoft.com/products/virtual-machines)
- [Virtual machine pricing](https://azure.microsoft.com/pricing/details/virtual-machines)
- [Virtual machine documentation](/azure/virtual-machines)
- [FinOps Framework](../../framework/finops-framework-overview.md)

Related solutions:

- [FinOps toolkit Power BI reports](../_docs/best-practices/power-bi/reports.md)
- [FinOps hubs](../_docs/best-practices/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../_docs/best-practices/optimization-engine/optimization-engine-overview.md)

<br>







## Azure Kubernetes Service

### Query: AKS Cluster

This Azure Resource Graph (ARG) query retrieves detailed information about Azure Kubernetes Service (AKS) clusters within your Azure environment.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
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
