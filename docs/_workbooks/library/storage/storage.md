---
layout: default
parent: ARG Resource Library
permalink: /library/storage
nav_order: 2
title: Storage
author: arclares
ms.date: 06/27/2024
ms.service: finops
description: 'Learn more about the Azure Resource Graph (ARG) queries used in the cost optimization workbook.'
---

# 📇 Table of Contents
1. [📇 Table of Contents](#-table-of-contents)
- [Storage Account](#storage-account)
  - [Query: Storage account v1](#query-storage-account-v1)
2. [Disks](#disks)
  - [Query: Idle Disks](#query-idle-disks)
  - [Query: Disk Snapshot Older Than 30 Days](#query-disk-snapshot-older-than-30-days)
  - [Query: Snapshot Using Premium Storage](#query-snapshot-using-premium-storage)
  

# Storage Account

## Query: Storage account v1

This Azure Resource Graph (ARG) query identifies storage accounts that are still using the legacy v1 kind, which may not provide the same features and efficiencies as newer storage account types.

## Description

This query helps in identifying storage accounts that are using the older 'Storage' (v1) or 'BlobStorage' kinds instead of the newer 'StorageV2'. Upgrading to the latest storage account type can offer enhanced features, better performance, and potential cost savings.

### Category

Optimization

### Potential Benefits

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

# Disks

## Query: Idle Disks

This Azure Resource Graph (ARG) query identifies idle or unattached managed disks within your Azure environment.

## Description

The query helps in identifying managed disks that are not attached to any compute resource and are not in use, which can lead to unnecessary costs. By reviewing these disks, you can determine if they can be deleted or repurposed.

### Category

Optimization

### Potential Benefits

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


## Query: Disk Snapshot Older Than 30 Days

This Azure Resource Graph (ARG) query identifies disk snapshots that are older than 30 days.

## Description

The query helps in identifying outdated disk snapshots that may no longer be needed, leading to potential cost savings and resource optimization.

### Category

Optimization

### Potential Benefits

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


## Query: Snapshot Using Premium Storage

This Azure Resource Graph (ARG) query identifies disk snapshots that are utilizing premium storage.

## Description

The query helps in identifying disk snapshots that are using premium storage, which may not be necessary and could lead to higher costs. By reviewing these snapshots, you can determine if they can be moved to a lower-cost storage option.

### Category

Optimization

### Potential Benefits

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
