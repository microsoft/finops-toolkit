---
layout: default
parent: Best practices
title: Compute
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'
permalink: /best-practices/compute
author: arclares
ms.date: 08/16/2024
ms.service: finops
---

<span class="fs-9 d-block mb-4">Compute best practices</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure compute resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Azure Kubernetes Service](#azure-kubernetes-service)
- [Virtual machines](#virtual-machines)
- [Virtual machine scale sets](#virtual-machine-scale-sets)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

## Azure Kubernetes Service

### Query: AKS Cluster

This Azure Resource Graph (ARG) query retrieves detailed information about Azure Kubernetes Service (AKS) clusters within your Azure environment.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
resources
| where type == 'microsoft.containerservice/managedclusters'
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

<br>

### Query: List deallocated virtual machines

This Azure Resource Graph (ARG) query identifies Virtual Machines (VMs) in your Azure environment that are in the 'deallocated' state. It retrieves details about their power state, location, resource group, and subscription ID.

<h4>Category</h4>

Waste reduction

<h4>Query</h4>

```kql
resources
| where type =~ 'microsoft.compute/virtualmachines'
    and tostring(properties.extended.instanceView.powerState.displayStatus) == 'VM deallocated'
| extend PowerState = tostring(properties.extended.instanceView.powerState.displayStatus)
| extend VMLocation = location
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| order by id asc
| project id, PowerState, VMLocation, resourceGroup, subscriptionId
```

<br>

### Query: List of virtual machines with their associated disks

This Resource Graph query retrieves a comprehensive list of all Virtual Machines (VMs) in your Azure environment, along with details of their associated disks. It provides insights into the storage configuration of each VM, helping you manage and optimize your storage resources effectively.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
Resources
| where type == 'microsoft.compute/virtualmachines'
| extend osDiskId = tostring(properties.storageProfile.osDisk.managedDisk.id)
| join kind=leftouter(
    Resources
    | where type =~ 'microsoft.compute/disks'
    | where properties !has 'Unattached'
    | where properties has 'osType'
    | project
        OS = tostring(properties.osType),
        osSku = tostring(sku.name),
        osDiskSizeGB = toint(properties.diskSizeGB),
         osDiskId=tostring(id)
) on osDiskId
| join kind=leftouter(
    Resources
    | where type =~ 'microsoft.compute/disks'
    | where properties !has "osType"
    | where properties !has 'Unattached'
    | project
        sku = tostring(sku.name),
        diskSizeGB = toint(properties.diskSizeGB),
        id = managedBy
    | summarize sum(diskSizeGB), count(sku) by id, sku
) on id
| project
    vmId = id,
    subscriptionId,
    resourceGroup,
    OS,
    location,
    osDiskId,
    osSku,
    osDiskSizeGB,
    DataDisksGB = sum_diskSizeGB,
    diskSkuCount = count_sku
| order by diskSkuCount desc
```

<br>

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

## Virtual machine scale sets

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

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
