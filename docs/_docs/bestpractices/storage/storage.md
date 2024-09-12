---
layout: default
parent: Best practices
permalink: /best-practices/storage
nav_order: 2
title: Storage
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">Storage</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure storage resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [💽 Backup](#backup)
- [💽 Disks](#disks)
- [🗄️ Storage Account](#storage-account)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

## Backup

### Query: Idle backups

This Azure Resource Graph (ARG) query analyzes backup items within Azure Recovery Services Vaults and identifies those that have not had a backup for over 90 days.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  recoveryservicesresources
  | where type =~ 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
  | extend vaultId = tostring(properties.vaultId)
  | extend resourceId = tostring(properties.sourceResourceId)
  | extend idleBackup= datetime_diff('day', now(), todatetime(properties.lastBackupTime)) > 90
  | extend  resourceType=tostring(properties.workloadType)
  | extend protectionState=tostring(properties.protectionState)
  | extend lastBackupTime=tostring(properties.lastBackupTime)
  | extend resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
  | extend lastBackupDate=todatetime(properties.lastBackupTime)
  | where idleBackup != 0
  | project resourceId,vaultId,idleBackup,lastBackupDate,resourceType,protectionState,lastBackupTime,location,resourceGroup,subscriptionId
  ```
</details>

### Query: List Recovery Services Vaults

This Azure Resource Graph (ARG) query retrieves details of Azure Recovery Services Vaults. The query also includes information on the SKU tier, redundancy settings, and other relevant metadata.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources
  | where type == 'microsoft.recoveryservices/vaults'
  | where resourceGroup in ({ResourceGroup})
  | extend skuTier = tostring(sku['tier'])
  | extend skuName = tostring(sku['name'])
  | extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
  | extend redundancySettings = tostring(properties.redundancySettings['standardTierStorageRedundancy'])
  | order by id asc
  | project id, redundancySettings, resourceGroup, location, subscriptionId, skuTier, skuName
  ```
</details>

<br>

## Disks

### Query: Idle disks

This Azure Resource Graph (ARG) query identifies idle or unattached managed disks within your Azure environment.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources 
  | where type =~ 'microsoft.compute/disks' and managedBy == ""
  | extend diskState = tostring(properties.diskState)
  | where managedBy == "" and diskState != 'ActiveSAS'
  or diskState == 'Unattached' and diskState != 'ActiveSAS'  
  and tags !contains 'ASR-ReplicaDisk' and tags !contains 'asrseeddisk'
  | extend DiskId=id, DiskIDfull=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated), SubId=subscriptionId
  | order by DiskId asc 
  | project DiskId, DiskIDfull, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId
  ```
</details>

### Query: Disk snapshot older than 30 days

This Azure Resource Graph (ARG) query identifies disk snapshots that are older than 30 days.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources
  | where type == 'microsoft.compute/snapshots'
  | extend TimeCreated = properties.timeCreated
  | extend resourceGroup = strcat("/subscriptions/",subscriptionId,"/resourceGroups/",resourceGroup)
  | where TimeCreated < ago(30d)
  | order by id asc 
  | project id, resourceGroup, location, TimeCreated, subscriptionId
  ```
</details>

### Query: Snapshot using premium storage

This Azure Resource Graph (ARG) query identifies disk snapshots that are utilizing premium storage.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources
  | where type == 'microsoft.compute/snapshots'
  | extend StorageSku = tostring(sku.tier), resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup),diskSize=tostring(properties.diskSizeGB)
  | where StorageSku == "Premium"
  | project id, name, StorageSku, diskSize, location, resourceGroup, subscriptionId
  ```
</details>

<br>

## Storage accounts

### Query: Storage account v1

This Azure Resource Graph (ARG) query identifies storage accounts that are still using the legacy v1 kind, which may not provide the same features and efficiencies as newer storage account types.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  resources 
  | where type =~ 'Microsoft.Storage/StorageAccounts' and kind !='StorageV2' and kind !='FileStorage'
  | where resourceGroup in ({ResourceGroup})
  | extend StorageAccountName=name, SAKind=kind,AccessTier=tostring(properties.accessTier),SKUName=sku.name, SKUTier=sku.tier, Location=location
  | order by id asc
  | project id, StorageAccountName, SKUName, SKUTier, SAKind,AccessTier, resourceGroup, Location, subscriptionId
  ```
</details>

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
