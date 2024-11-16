---
title: FinOps best practices for Storage
description: This article outlines proven FinOps practices for storage services, focusing on cost optimization, efficiency improvements, and resource insights.
author: bandersmsft
ms.author: banders
ms.date: 10/29/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with storage services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for Storage

This article outlines a collection of proven FinOps practices for storage services. It provides strategies for optimizing costs, improving efficiency, and using Azure Resource Graph (ARG) queries to gain insights into your storage resources. By following these practices, you can ensure that your storage services are cost-effective and aligned with your organization's financial goals.

<br>

## Backup

The following sections provide ARG queries for backup services. These queries help you gain insights into your backup resources and ensure they're configured with the appropriate settings. By analyzing backup items and identifying idle backups, you can optimize your backup services for cost efficiency.

### Query: Idle backups

This ARG query analyzes backup items within Azure Recovery Services Vaults and identifies any that weren't backed up for over 90 days.

**Category**

Optimization

**Query**

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

### Query: List Recovery Services Vaults

This Azure Resource Graph (ARG) query retrieves details of Azure Recovery Services Vaults. The query also includes information on the SKU tier, redundancy settings, and other relevant metadata.

**Category**

Optimization

**Query**

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

<br>

## Disks

The following sections provide ARG queries for disk services. These queries help you gain insights into your disk resources and ensure they're configured with the appropriate settings. By analyzing disk snapshots and identifying idle disks, you can optimize your disk services for cost efficiency.

### Query: Idle disks

This ARG query identifies idle or unattached managed disks within your Azure environment.

**Category**

Optimization

**Query**

```kql
resources
| where type =~ 'microsoft.compute/disks' and managedBy == ""
| extend diskState = tostring(properties.diskState)
| where managedBy == ""
    and diskState != 'ActiveSAS'
    and tags !contains 'ASR-ReplicaDisk'
    and tags !contains 'asrseeddisk'
| extend DiskId=id, DiskIDfull=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated), SubId=subscriptionId
| order by DiskId asc 
| project DiskId, DiskIDfull, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId
```

### Query: Disk snapshot older than 30 days

This ARG query identifies disk snapshots that are older than 30 days.

**Category**

Optimization

**Query**

```kql
resources
| where type == 'microsoft.compute/snapshots'
| extend TimeCreated = properties.timeCreated
| extend resourceGroup = strcat("/subscriptions/",subscriptionId,"/resourceGroups/",resourceGroup)
| where TimeCreated < ago(30d)
| order by id asc 
| project id, resourceGroup, location, TimeCreated, subscriptionId
```

### Query: Snapshot using premium storage

This ARG query identifies disk snapshots that are utilizing premium storage.

**Category**

Optimization

**Query**

```kql
resources
| where type == 'microsoft.compute/snapshots'
| extend
    StorageSku = tostring(sku.tier),
    resourceGroup = strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup),
    diskSize = tostring(properties.diskSizeGB)
| where StorageSku == "Premium"
| project id, name, StorageSku, diskSize, location, resourceGroup, subscriptionId
```

<br>

## Storage accounts

The following section provides an ARG query for storage accounts. It helps you gain insights into your storage resources and ensure they're configured with the appropriate settings. By analyzing storage accounts and identifying legacy storage account types, you can optimize your storage services for cost efficiency.

### Query: Storage account v1

This ARG query identifies storage accounts that are still using the legacy v1 kind, which might not provide the same features and efficiencies as newer storage account types.

**Category**

Optimization

**Query**

```kql
resources
| where type =~ 'Microsoft.Storage/StorageAccounts'
    and kind !='StorageV2'
    and kind !='FileStorage'
| where resourceGroup in ({ResourceGroup})
| extend
    StorageAccountName = name,
    SAKind = kind,
    AccessTier = tostring(properties.accessTier),
    SKUName = sku.name,
    SKUTier = sku.tier,
    Location = location
| order by id asc
| project
    id,
    StorageAccountName,
    SKUName,
    SKUTier,
    SAKind,
    AccessTier,
    resourceGroup,
    Location,
    subscriptionId
```

<br>

## Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. [Create a new issue](https://aka.ms/ftk/ideas) with the details that you'd like to see either included here.

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
