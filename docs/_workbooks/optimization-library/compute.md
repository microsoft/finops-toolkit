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
