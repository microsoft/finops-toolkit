---
layout: default
parent: FinOps best practices library
permalink: /bestpractices/storage
nav_order: 2
title: Storage
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'
---

# 📇 Table of Contents
1. [Storage Account](#storage-account)
2. [Disks](#disks)
3. [Backup](#backup)
 

## Storage Account

### Query: Storage account v1

This Azure Resource Graph (ARG) query identifies storage accounts that are still using the legacy v1 kind, which may not provide the same features and efficiencies as newer storage account types.

### Description

This query helps in identifying storage accounts that are using the older 'Storage' (v1) or 'BlobStorage' kinds instead of the newer 'StorageV2'. Upgrading to the latest storage account type can offer enhanced features, better performance, and potential cost savings.

#### Category

Optimization

#### Potential Benefits

- **Performance Improvement:** The newer storage account types often offer better performance characteristics.
- **Cost Efficiency:** Potentially lower costs with the newer storage types due to data tiering options.


<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
| where type =~ 'Microsoft.Storage/StorageAccounts' and kind !='StorageV2' and kind !='FileStorage'
| where resourceGroup in ({ResourceGroup})
| extend StorageAccountName=name, SAKind=kind,AccessTier=tostring(properties.accessTier),SKUName=sku.name, SKUTier=sku.tier, Location=location
| order by id asc
| project id,StorageAccountName, SKUName, SKUTier, SAKind,AccessTier, resourceGroup, Location, subscriptionId</code></pre>
  </div>
</details>

## Disks

### Query: Idle Disks

This Azure Resource Graph (ARG) query identifies idle or unattached managed disks within your Azure environment.

### Description

The query helps in identifying managed disks that are not attached to any compute resource and are not in use, which can lead to unnecessary costs. By reviewing these disks, you can determine if they can be deleted or repurposed.

#### Category

Optimization

#### Potential Benefits

- **Cost Savings:** Eliminating unattached disks can reduce your storage costs as you are not paying for unused resources.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
| where type =~ 'microsoft.compute/disks' and managedBy == ""
| where resourceGroup in ({ResourceGroup})
| extend diskState = tostring(properties.diskState)
| where managedBy == "" and diskState != 'ActiveSAS'
or diskState == 'Unattached' and diskState != 'ActiveSAS'  
and tags !contains 'ASR-ReplicaDisk' and tags !contains 'asrseeddisk'
| extend DiskId=id, DiskIDfull=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated), QuickFix=id, SubId=subscriptionId
| order by DiskId asc 
| project DiskId, DiskIDfull, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, QuickFix, Location, TimeCreated, subscriptionId,SubId
</code></pre>
  </div>
</details>


### Query: Disk Snapshot Older Than 30 Days

This Azure Resource Graph (ARG) query identifies disk snapshots that are older than 30 days.

### Description

The query helps in identifying outdated disk snapshots that may no longer be needed, leading to potential cost savings and resource optimization.

#### Category

Optimization

#### Potential Benefits

- **Cost Savings:** Deleting outdated snapshots can significantly reduce storage costs, as snapshots can accumulate over time and incur charges.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == 'microsoft.compute/snapshots'
| extend TimeCreated = properties.timeCreated
| extend resourceGroup=strcat("/subscriptions/",subscriptionId,"/resourceGroups/",resourceGroup)
| where TimeCreated < ago(30d)
| order by id asc 
| project id, resourceGroup, location, TimeCreated ,subscriptionId
</code></pre>
  </div>
</details>


### Query: Snapshot Using Premium Storage

This Azure Resource Graph (ARG) query identifies disk snapshots that are utilizing premium storage.

### Description

The query helps in identifying disk snapshots that are using premium storage, which may not be necessary and could lead to higher costs. By reviewing these snapshots, you can determine if they can be moved to a lower-cost storage option.

#### Category

Optimization

#### Potential Benefits

- **Cost Savings:** Moving snapshots from premium to standard storage can reduce storage costs without compromising the availability or performance for backup and archival purposes.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == 'microsoft.compute/snapshots'
| extend StorageSku = tostring(sku.tier), resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup),diskSize=tostring(properties.diskSizeGB)
| where StorageSku == "Premium"
| project id,name,StorageSku,diskSize,location,resourceGroup,subscriptionId
</code></pre>
  </div>
</details>


## Backup

### Query: Idle Backups

This Azure Resource Graph (ARG) query analyzes backup items within Azure Recovery Services Vaults and identifies those that have not had a backup for over 90 days and are associated with specific tags. 

### Description

This query identifies backup items in Azure Recovery Services Vaults that have not been backed up for more than 90 days (considered idle) and are associated with specific tags. By focusing on these idle resources, the query provides insights into which resources may need attention or can be decommissioned.

#### Category

Optimization

#### Potential Benefits

- **Cost Optimization:**  Identifies backup items that have not been backed up for over 90 days, indicating potentially idle or unnecessary backups that could be reviewed and possibly decommissioned to save costs.


<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> recoveryservicesresources
| where type =~ 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
| extend vaultId = tostring(properties.vaultId),resourceId = tostring(properties.sourceResourceId),idleBackup= datetime_diff('day', now(), todatetime(properties.lastBackupTime)) > 90, resourceType=tostring(properties.workloadType), protectionState=tostring(properties.protectionState),lastBackupTime=tostring(properties.lastBackupTime), resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup),lastBackupDate=todatetime(properties.lastBackupTime)
| where idleBackup != 0
| project resourceId,vaultId,idleBackup,lastBackupDate,resourceType,protectionState,lastBackupTime,location,resourceGroup,subscriptionId
</code></pre>
  </div>
</details>


### Query: List Recovery Services Vaults

This Azure Resource Graph (ARG) query retrieves details of Azure Recovery Services Vaults. The query also includes information on the SKU tier, redundancy settings, and other relevant metadata.

### Description

This query identifies Azure Recovery Services Vaults. It provides insights into the SKU tier, redundancy settings, and other properties of the vaults, helping with targeted resource management and configuration verification.

#### Category

Optimization

#### Potential Benefits

- **Configuration Insights:** Provides detailed insights into the vaults' SKU tier and redundancy settings, assisting in verifying that resources are configured according to organizational standards and policies.


<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> Resources
| where type == 'microsoft.recoveryservices/vaults'
| where resourceGroup in ({ResourceGroup})
| extend skuTier = tostring(sku['tier']), skuName = tostring(sku['name']), resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup), redundancySettings = tostring(properties.redundancySettings['standardTierStorageRedundancy'])
| order by id asc
| project id, redundancySettings, resourceGroup, location, subscriptionId, skuTier, skuName
</code></pre>
  </div>
</details>