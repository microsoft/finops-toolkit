---
title: AKS capacity governance
parent: Operations
nav_order: 10
---

# AKS capacity governance

> For ISVs running stamp-based SaaS on AKS, capacity governance ensures node pools can scale without hitting quota limits or availability gaps. This page covers quota management and capacity reservation patterns specific to [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/intro-kubernetes) node pools.

AKS node pools consume the same regional VM quota and capacity as standalone VMs. You manage quota through [quota groups](../quota-groups/README.md) and guarantee capacity through [capacity reservation groups](../capacity-reservations/README.md), but AKS enforces constraints on how node pools associate with CRGs. This guide explains those constraints and their implications for stamp provisioning workflows.

## Quota considerations for AKS clusters

[AKS clusters](https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions) draw from the same VM family quota as standalone VMs. When you create or scale a node pool, AKS requests quota from the `Microsoft.Compute` provider in the subscription and region where the cluster runs.

- **Node pool scaling failures:** If regional quota is exhausted, [autoscaler operations fail](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler) and pods remain pending until quota increases or nodes are freed elsewhere in the region.
- **Quota group integration:** Add AKS subscriptions to a [quota group](https://learn.microsoft.com/en-us/azure/quotas/quota-groups) so node pools share quota with other workloads across your estate. This prevents isolated exhaustion in subscriptions dedicated to specific stamps.
- **VM family alignment:** Choose [VM sizes](https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions#vm-size-restrictions) that align with your quota allocation strategy. Mixing multiple VM families across node pools fragments quota and complicates capacity planning.
- **System node pool requirements:** Every AKS cluster requires a [system node pool](https://learn.microsoft.com/en-us/azure/aks/use-system-pools) to run critical control-plane components (CoreDNS, kube-proxy, metrics-server). Don't configure system node pools to scale to zero—they must maintain at least one node.

## Capacity reservations for node pools

AKS node pools support [capacity reservation groups (CRGs)](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups) to guarantee that VM capacity is available when the cluster scales out. CRGs for AKS work the same way as [VM capacity reservations](../capacity-reservations/README.md)—you reserve specific VM sizes in a region and zone, then associate node pools with those reservations—but AKS enforces additional constraints on association and identity.

### Node pool association constraints

You can't update an existing node pool to add a capacity reservation group. You must [create a new node pool](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups#create-a-new-node-pool-with-a-capacity-reservation-group) with the `--crg-id` parameter during creation.

```bash
# This operation isn't supported
az aks nodepool update --crg-id $CRG_ID --cluster-name myCluster --name existingPool --resource-group myRG

# Create a new node pool instead
az aks nodepool add \
  --resource-group myRG \
  --cluster-name myCluster \
  --name newPool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --crg-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/capacityReservationGroups/{crg-name}
```

**Implication for stamp automation:** If you create stamps through infrastructure-as-code pipelines, ensure CRG associations are embedded in the initial node pool definition. Don't expect to retrofit existing pools with CRG references after deployment.

### Identity and permission requirements

AKS requires a [user-assigned managed identity](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups#prerequisites) to associate node pools with CRGs. System-assigned managed identities don't work for this scenario.

1. **Create or identify a user-assigned identity:** The identity must exist in the same subscription as the AKS cluster.
2. **Assign Contributor role on the CRG's resource group:** The identity needs `Microsoft.Compute/capacityReservationGroups/*` permissions. [Grant the role](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal) at the resource group scope that contains the CRG.
3. **Wait for propagation:** Role assignments can take [up to 60 minutes](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups#prerequisites) to propagate. Don't create node pools immediately after assigning roles—your pipeline will fail if the identity isn't yet active.
4. **Attach the identity to the cluster:** When you [create the AKS cluster](https://learn.microsoft.com/en-us/azure/aks/use-managed-identity), specify the user-assigned identity with `--assign-identity`. Existing clusters can't switch from system-assigned to user-assigned identity—you'd need to recreate the cluster.

### Disassociation and lifecycle behavior

When you delete a node pool or cluster, AKS [automatically disassociates](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups#delete-a-node-pool-or-cluster-associated-with-a-capacity-reservation-group) it from any associated CRG before completing the delete operation. This differs from standalone VMs, where you must [manually disassociate VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-remove-vm) before deleting the capacity reservation.

- **Node pool deletion:** `az aks nodepool delete` removes the pool and its CRG association in a single operation. No manual cleanup is required.
- **Cluster deletion:** `az aks delete` disassociates all node pools from their CRGs before deleting the cluster resource.
- **Warning scenarios:** If the specified CRG doesn't exist or contains no member reservations, AKS [creates the node pool with a warning](https://learn.microsoft.com/en-us/azure/aks/use-capacity-reservation-groups#limitations-for-using-capacity-reservation-groups-with-aks-node-pools) but doesn't establish the CRG association. The node pool runs without capacity guarantees until you recreate it with a valid CRG reference.

### Zone alignment and cross-subscription sharing

If you're using [availability zones](https://learn.microsoft.com/en-us/azure/aks/availability-zones) with AKS, ensure the CRG's zonal capacity reservations align with the physical zones where your node pool deploys. Azure assigns different logical-to-physical zone mappings per subscription, so [validate zone mappings](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-group-share#zone-mapping-differences-across-subscriptions) if the CRG is shared from a different subscription.

Use the [Get-AzAvailabilityZoneMapping.ps1](../tools-scripts/get-azavailabilityzonemapping.md) script to compare zone mappings across subscriptions before configuring CRG sharing.

## Automation patterns

### Infrastructure-as-code templates

Embed CRG references in your Bicep or Terraform templates to ensure node pools are created with capacity guarantees from the start.

**Bicep example:**

```bicep
resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
  parent: aksCluster
  name: 'prodpool'
  properties: {
    count: 5
    vmSize: 'Standard_D4s_v3'
    capacityReservationGroupID: '/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/capacityReservationGroups/{crg-name}'
    mode: 'User'
    osType: 'Linux'
  }
}
```

**Terraform example:**

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "prod" {
  name                  = "prodpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = "Standard_D4s_v3"
  node_count           = 5
  capacity_reservation_group_id = azurerm_capacity_reservation_group.crg.id
}
```

### Pipeline sequencing for identity propagation

If your pipeline creates the user-assigned identity and assigns roles in the same run, add a delay before creating the AKS cluster or node pool.

```bash
# Create identity and assign role
az identity create --name aks-crg-identity --resource-group myRG
IDENTITY_ID=$(az identity show --name aks-crg-identity --resource-group myRG --query id -o tsv)
az role assignment create --assignee $IDENTITY_ID --role Contributor --scope /subscriptions/{sub-id}/resourceGroups/{crg-rg}

# Wait for propagation (adjust based on observed latency)
echo "Waiting 5 minutes for role propagation..."
sleep 300

# Create cluster with the identity
az aks create \
  --resource-group myRG \
  --name myCluster \
  --assign-identity $IDENTITY_ID \
  --enable-managed-identity
```

For production pipelines, poll the role assignment status instead of using fixed delays.

## Operational checklist

1. Verify [regional quota](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal) before creating AKS clusters in new regions. AKS doesn't provide distinct quota from `Microsoft.Compute`—both draw from the same pool.
2. Add AKS subscriptions to [quota groups](../quota-groups/README.md) if you manage multiple stamps or environments that share capacity.
3. Create [capacity reservation groups](../capacity-reservations/README.md) for critical node pools that must scale reliably during demand surges.
4. Use [user-assigned managed identities](https://learn.microsoft.com/en-us/azure/aks/use-managed-identity) for all AKS clusters that will associate with CRGs. Don't rely on system-assigned identities.
5. Embed CRG references in node pool definitions during initial creation. Don't expect to retrofit existing pools.
6. Monitor [CRG utilization](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overallocate) to ensure reserved capacity aligns with autoscaler policies. Underutilized reservations waste cost; overallocated pools lose capacity guarantees.
7. Validate [zone mappings](../tools-scripts/get-azavailabilityzonemapping.md) if sharing CRGs across subscriptions in zonal deployments.
