---
layout: default
parent: Best practices
permalink: /bestpractices/compute
nav_order: 2
title: Compute
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

# 📇 Table of Contents

1. [Virtual Machines](#virtual-machines)
2. [Azure App Service](#azure-app-service)
3. [Azure Kubernetes Service](#azure-kubernetes-service)

<br>

## Virtual machines

### Query: Virtual machines not deallocated or running

This Azure Resource Graph (ARG) query identifies virtual machines (VMs) in your Azure environment that are not in the 'deallocated' or 'running' state. It retrieves details about their power state, location, resource group, and subscription ID.

#### Category

Waste reduction

#### Benefits

- **Cost optimization:** Identifies VMs that are not properly deallocated, helping to prevent unnecessary costs from allocated resources.

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    ```kql
    resources 
    | where type =~ 'microsoft.compute/virtualmachines' 
        and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM deallocated' 
        and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM running'
    | extend PowerState=tostring(properties.extended.instanceView.powerState.displayStatus)
    | extend VMLocation=location
    | extend resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
    | order by id asc
    | project id, PowerState, VMLocation, resourceGroup, subscriptionId
```
  </div>
</details>

### Query: Virtual machine scale sets details

This query analyzes Virtual Machine Scale Sets (VMSS) in your Azure environment based on their SKU, spot VM priority, and priority mix policy. It provides insights for cost optimization and resource management strategies.

#### Category

Optimization

#### Potential Benefits

- **Cost Optimization:** Identifies VMSS configurations that do not utilize spot instances or properly balance regular and spot VMs, potentially reducing infrastructure costs based on workload requirements.
- **Resource Management:** Optimizes VMSS deployments by leveraging spot VMs effectively and ensuring compliance with priority mix policies.

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    ```kql
    resources
    | where type =~ 'microsoft.compute/virtualmachinescalesets'
    | extend SpotVMs=tostring(properties.virtualMachineProfile.priority)
    | extend SpotPriorityMix=tostring(properties.priorityMixPolicy)
    | extend SKU=tostring(sku.name)
    | extend resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
    | project id, SKU, SpotVMs, SpotPriorityMix, subscriptionId, resourceGroup, location
    ```
  </div>
</details>

### Query: Virtual machine processor type analysis

This query identifies the processor type (ARM, AMD, or Intel) used by Virtual Machines (VMs) in your Azure environment. It helps in understanding the distribution of VMs across different processor architectures, which is useful for optimizing workload performance and cost efficiency.

#### Category

Optimization

#### Potential Benefits

- **Workload Optimization:** Helps in determining the most suitable processor type for specific workloads, potentially improving performance and reducing costs.
- **Cost Efficiency:** Identifies opportunities to optimize VM costs by choosing the right processor type based on your workload requirements.
- **Resource Management:** Provides insights into the distribution of VM sizes and processor types across your resource groups, aiding in more efficient resource management.

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources
  | where type == 'microsoft.compute/virtualmachines'
  | extend vmSize = properties.hardwareProfile.vmSize
  | extend processorType = case(
    // ARM Processors
    vmSize has "Epsv5" or vmSize has "Epdsv5" or vmSize has "Dpsv5" or vmSize has "Dpdsv", "ARM",
    // AMD Processors
    vmSize has "Standard_D2a" or vmSize has "Standard_D4a" or vmSize has "Standard_D8a" or vmSize has "Standard_D16a" or vmSize has "Standard_D32a" or vmSize has "Standard_D48a" or vmSize has "Standard_D64a" or vmSize has "Standard_D96a" or vmSize has "Standard_D2as" or vmSize has "Standard_D4as" or vmSize has "Standard_D8as" or vmSize has "Standard_D16as" or vmSize has "Standard_D32as" or vmSize has "Standard_D48as" or vmSize has "Standard_D64as" or vmSize has "Standard_D96as", "AMD",
    "Intel"
  )
  | project vmName = name, processorType, vmSize, resourceGroup
  ```
</details>

<br>

## Azure App Service

### Query: Web Function Status

This Azure Resource Graph (ARG) query retrieves the status and basic information of web applications (Web Apps) within your Azure environment.

#### Category

Monitoring

#### Potential Benefits

- **Operational Insights:** Provides visibility into the status (running, stopped, etc.) of Azure Web Apps, facilitating proactive monitoring and management.
- **Resource Utilization:** Helps in understanding the utilization of Azure App Service resources such as App Service Plans and SKUs.
- **Cost Management:** Enables effective cost management by identifying and optimizing Azure App Service resources based on their utilization and status.

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code>resources
| where type =~ 'Microsoft.Web/sites'
| extend WebAppRG=resourceGroup, WebAppName=name, AppServicePlan=tostring(properties.serverFarmId), SKU=tostring(properties.sku), Type=kind, Status=tostring(properties.state), WebAppLocation=location, SubscriptionName=subscriptionId
| project id,WebAppName, Type, Status, WebAppLocation, AppServicePlan, WebAppRG,SubscriptionName
| order by id asc
</code></pre>
  </div>
</details>

### Query: App Service plan details

This Azure Resource Graph (ARG) query retrieves detailed information about Azure App Service Plans within your Azure environment.

#### Category

Resource management

#### Benefits

- **Resource optimization:** Provides insights into the configuration and utilization of Azure App Service Plans, including SKU details, worker counts, and maximum capacities.
- **Cost management:** Helps in optimizing costs by identifying underutilized or over-provisioned App Service Plans.
- **Autoscaling insights:** Integrates autoscaling settings information, including predictive autoscale policies and autoscale profiles, to optimize resource scaling based on workload demands.


#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources
  | where type == "microsoft.web/serverfarms"  and sku.tier !~ 'Free'
  | project
      planId = tolower(tostring(id)),
      name,
      skuname = tostring(sku.name),
      skutier = tostring(sku.tier),
      workers = tostring(properties.numberOfWorkers),
      maxworkers = tostring(properties.maximumNumberOfWorkers),
      webRG = resourceGroup,
      Sites = tostring(properties.numberOfSites),
      SubscriptionId = subscriptionId
  | join kind=leftouter (
      resources
      | where type =="microsoft.insights/autoscalesettings"
      | project
          planId = tolower(tostring(properties.targetResourceUri)),
          PredictiveAutoscale = properties.predictiveAutoscalePolicy.scaleMode,
          AutoScaleProfiles = properties.profiles,
          resourceGroup
  ) on planId
  ```
</details>

### Query: App Service plan details

This Azure Resource Graph (ARG) query retrieves detailed information about Azure App Service Plans within your Azure environment.

#### Category

Resource management

#### Benefits

- **Resource optimization:** Provides insights into the configuration and utilization of Azure App Service Plans, including SKU details, worker counts, and maximum capacities.
- **Cost management:** Helps in optimizing costs by identifying underutilized or over-provisioned App Service Plans.
- **Autoscaling insights:** Integrates autoscaling settings information, including predictive autoscale policies and autoscale profiles, to optimize resource scaling based on workload demands.

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code>resources
| where type == "microsoft.web/serverfarms"  and sku.tier !~ 'Free'
| extend  planId=tolower(tostring(id)),skuname = tostring(sku.name) , skutier = tostring(sku.tier), workers=tostring(properties.numberOfWorkers),webRG=resourceGroup,maxworkers=tostring(properties.maximumNumberOfWorkers), Sites=tostring(properties.numberOfSites), SubscriptionName=subscriptionId
| project planId, name, skuname, skutier, workers, maxworkers, webRG, Sites, SubscriptionName
| join kind=leftouter (resources | where type =="microsoft.insights/autoscalesettings" | project planId=tolower(tostring(properties.targetResourceUri)), PredictiveAutoscale=properties.predictiveAutoscalePolicy.scaleMode, AutoScaleProfiles=properties.profiles,resourceGroup) on planId
</code></pre>
  </div>
</details>

<br>

## Azure Kubernetes Service

### Query: AKS Cluster

This Azure Resource Graph (ARG) query retrieves detailed information about Azure Kubernetes Service (AKS) clusters within your Azure environment.

#### Category

Resource management

#### Benefits

- **Resource optimization:** Provides insights into AKS cluster configurations, including agent pool profiles, auto-scaling settings, and VM sizes, to optimize resource allocation.
- **Cost management:** Helps in optimizing costs by identifying underutilized or over-provisioned AKS clusters.
- **Operational insights:** Provides operational visibility into AKS clusters, including node counts, scaling modes, and spot instance usage.
- **Autoscaling:** Enable cluster autoscaler to automatically adjust the number of agent nodes in response to resource constraints.
- **Spot VM usage:** Consider using Azure Spot VMs for workloads that can handle interruptions, early terminations, or evictions. For example, workloads such as batch processing jobs, development and testing environments, and large compute workloads may be good candidates to be scheduled on a spot node pool.
- **Pod autoscaling:** Utilize the Horizontal Pod Autoscaler to adjust the number of pods in a deployment depending on CPU utilization or other select metrics.
- **Cost optimization:** Use the Start/Stop feature in Azure Kubernetes Services (AKS) to manage costs effectively by shutting down unused clusters during non-business hours.

#### Query

<details>
  <summary>Click to view the code</summary>
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
</details>
