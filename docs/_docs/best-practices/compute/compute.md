---
title: FinOps best practices for Compute
description: This article outlines a collection of proven FinOps practices for compute services.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with compute services. 
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for Compute

This article outlines a collection of proven FinOps practices for compute services.

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

## Virtual machines

### Query: List Virtual Machines stopped (and not deallocated)

This Azure Resource Graph (ARG) query identifies Virtual Machines (VMs) in your Azure environment that are not in the 'deallocated' or 'running' state. It retrieves details about their power state, location, resource group, and subscription ID.

<h4>Category</h4>

Waste reduction

<h4>Query</h4>

```kql
resources
| where type =~ 'microsoft.compute/virtualmachines' 
    and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM deallocated' 
    and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM running'
| extend PowerState = tostring(properties.extended.instanceView.powerState.displayStatus)
| extend VMLocation = location
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| order by id asc
| project id, PowerState, VMLocation, resourceGroup, subscriptionId
```

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

## Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. [Create a new issue](https://aka.ms/ftk/ideas) with the details that you'd like to see either included here.

<br>

## Related content

Related resources:

- [FinOps Framework](../../../docs-mslearn/framework/finops-framework.md)

Related products:

- [Azure Carbon Optimization](/azure/carbon-optimization/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../../../docs-mslearn/power-bi/reports.md)
- [FinOps hubs](../../../docs-mslearn/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../../../docs-mslearn/toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../../../docs-mslearn/optimization-engine/optimization-engine-overview.md)

<br>
