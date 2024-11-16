---
title: FinOps best practices for compute
description: This article provides FinOps best practices for compute services, including cost optimization, efficiency improvements, and insights into Azure resources.
author: bandersmsft
ms.author: banders
ms.date: 10/24/2024
ms.topic: concept-article
ms.service: finops
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

The following sections provide ARG queries for VMs. These queries help you optimize costs, improve efficiency, and gain insights into your VMs.

### Query - List virtual machines stopped (and not deallocated)

This ARG query identifies VMs that don't have the `deallocated` or `running` state. It retrieves details about their power state, location, resource group, and subscription ID.

**Category**

Waste reduction

**Query**

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

### Query - Virtual machine scale set details

This query analyzes Virtual Machine Scale Sets in your Azure environment based on their SKU, spot VM priority, and priority mix policy. It provides insights for cost optimization and resource management strategies.

**Category**

Resource management

**Query**

```kql
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
