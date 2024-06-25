---
layout: default
parent: Cost optimization workbook
title: Cost optimization workbook resource library - Compute
has_children: true
nav_order: 1
description: 'Learn more about the Azure Resource Graph (ARG) queries used in the cost optimization workbook.'
permalink: /optimization-workbook/library
---

# Virtual Machines

## Query: Virtual Machines Not Deallocated or Running

This Azure Resource Graph (ARG) query identifies virtual machines (VMs) in your Azure environment that are not in the 'deallocated' or 'running' state. It retrieves details about their power state, location, resource group, and subscription ID.

### Category

Waste Reduction

### Potential Benefits

- **Cost Optimization:** Identifies VMs that are not properly deallocated, helping to prevent unnecessary costs from allocated resources.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code>resources 
| where type =~ 'microsoft.compute/virtualmachines' and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM deallocated' and tostring(properties.extended.instanceView.powerState.displayStatus) != 'VM running'
| extend  PowerState=tostring(properties.extended.instanceView.powerState.displayStatus), VMLocation=location, resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| order by id asc
| project id, PowerState, VMLocation, resourceGroup, subscriptionId</code></pre>
  </div>
</details>

## Query: Virtual Machine Scale Sets Analysis

This query analyzes Virtual Machine Scale Sets (VMSS) in your Azure environment based on their SKU, spot VM priority, and priority mix policy. It provides insights for cost optimization and resource management strategies.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies VMSS configurations that do not utilize spot instances or properly balance regular and spot VMs, potentially reducing infrastructure costs based on workload requirements.
- **Resource Management:** Optimizes VMSS deployments by leveraging spot VMs effectively and ensuring compliance with priority mix policies.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code>resources 
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend  SpotVMs=tostring(properties.virtualMachineProfile.priority), SpotPriorityMix=tostring(properties.priorityMixPolicy), SKU=tostring(sku.name), resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project id, SKU, SpotVMs, SpotPriorityMix, subscriptionId, resourceGroup, location</code></pre>
  </div>
</details>

# Azure App Service

## Query: Web Function Status

This Azure Resource Graph (ARG) query retrieves the status and basic information of web applications (Web Apps) within your Azure environment.

### Category

Monitoring

### Potential Benefits

- **Operational Insights:** Provides visibility into the status (running, stopped, etc.) of Azure Web Apps, facilitating proactive monitoring and management.
- **Resource Utilization:** Helps in understanding the utilization of Azure App Service resources such as App Service Plans and SKUs.
- **Cost Management:** Enables effective cost management by identifying and optimizing Azure App Service resources based on their utilization and status.

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

## Query: App Service Plan Details

This Azure Resource Graph (ARG) query retrieves detailed information about Azure App Service Plans within your Azure environment.

### Category

Resource Management

### Potential Benefits

- **Resource Optimization:** Provides insights into the configuration and utilization of Azure App Service Plans, including SKU details, worker counts, and maximum capacities.
- **Cost Management:** Helps in optimizing costs by identifying underutilized or over-provisioned App Service Plans.
- **Autoscaling Insights:** Integrates autoscaling settings information, including predictive autoscale policies and autoscale profiles, to optimize resource scaling based on workload demands.


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


## Query: App Service Plan Details

This Azure Resource Graph (ARG) query retrieves detailed information about Azure App Service Plans within your Azure environment.

### Category

Resource Management

### Potential Benefits

- **Resource Optimization:** Provides insights into the configuration and utilization of Azure App Service Plans, including SKU details, worker counts, and maximum capacities.
- **Cost Management:** Helps in optimizing costs by identifying underutilized or over-provisioned App Service Plans.
- **Autoscaling Insights:** Integrates autoscaling settings information, including predictive autoscale policies and autoscale profiles, to optimize resource scaling based on workload demands.


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


## Query: AKS Cluster

This Azure Resource Graph (ARG) query retrieves detailed information about Azure Kubernetes Service (AKS) clusters within your Azure environment.

### Category

Resource Management

### Potential Benefits

- **Resource Optimization:** Provides insights into AKS cluster configurations, including agent pool profiles, auto-scaling settings, and VM sizes, to optimize resource allocation.
- **Cost Management:** Helps in optimizing costs by identifying underutilized or over-provisioned AKS clusters.
- **Operational Insights:** Provides operational visibility into AKS clusters, including node counts, scaling modes, and spot instance usage.
- **Autoscaling:** Enable cluster autoscaler to automatically adjust the number of agent nodes in response to resource constraints.
- **Spot VM Usage:** Consider using Azure Spot VMs for workloads that can handle interruptions, early terminations, or evictions. For example, workloads such as batch processing jobs, development and testing environments, and large compute workloads may be good candidates to be scheduled on a spot node pool.
- **Pod Autoscaling:** Utilize the Horizontal Pod Autoscaler to adjust the number of pods in a deployment depending on CPU utilization or other select metrics.
- **Cost Optimization:** Use the Start/Stop feature in Azure Kubernetes Services (AKS) to manage costs effectively by shutting down unused clusters during non-business hours.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code>	resources
	| where type == "microsoft.containerservice/managedclusters"
	| extend  AKSname=name,location=location,Sku=tostring(sku.name),Tier=tostring(sku.tier),AgentPoolProfiles=properties.agentPoolProfiles
    | project id,AKSname,resourceGroup,subscriptionId,Sku,Tier,AgentPoolProfiles,location
	| mvexpand AgentPoolProfiles
	| extend ProfileName = tostring(AgentPoolProfiles.name) ,mode=AgentPoolProfiles.mode,AutoScaleEnabled = AgentPoolProfiles.enableAutoScaling ,SpotVM=AgentPoolProfiles.scaleSetPriority,  VMSize=tostring(AgentPoolProfiles.vmSize),minCount=tostring(AgentPoolProfiles.minCount),maxCount=tostring(AgentPoolProfiles.maxCount) , nodeCount=tostring(AgentPoolProfiles.['count'])
    | project id,ProfileName,Sku,Tier,mode,AutoScaleEnabled,SpotVM, VMSize,nodeCount,minCount,maxCount,location,resourceGroup,subscriptionId,AKSname
    </code></pre>
  </div>
</details>
