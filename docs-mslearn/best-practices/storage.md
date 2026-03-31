---
title: FinOps best practices for Storage
description: This article outlines proven FinOps practices for storage services, focusing on cost optimization, efficiency improvements, and resource insights.
author: flanakin
ms.author: micflan
ms.date: 03/31/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with storage services.
---

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

```kusto
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

```kusto
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

Azure managed disks are block-level storage volumes that are managed by Azure and used with virtual machines. Managed disks provide high availability, scalability, and security for your VM workloads.

Related resources:

- [Managed disks product page](https://azure.microsoft.com/products/managed-disks)
- [Managed disks pricing](https://azure.microsoft.com/pricing/details/managed-disks)
- [Managed disks documentation](/azure/virtual-machines/managed-disks-overview)

### Remove unattached disks

Recommendation: Remove or downgrade unattached managed disks to avoid unnecessary storage costs.

#### About unattached disks

When a VM is deleted, its associated managed disks may not be deleted automatically. These unattached (orphaned) disks continue to incur storage costs based on their disk type and size. The query excludes disks that are in active SAS transfer mode or are Azure Site Recovery replica or seed disks, as these are expected to be temporarily unattached.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify unattached disks. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify unattached disks

Use the following ARG query to identify unattached managed disks.

```kusto
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

```kusto
resources
| where type == 'microsoft.compute/snapshots'
| extend TimeCreated = properties.timeCreated
| extend resourceGroup = strcat("/subscriptions/",subscriptionId,"/resourceGroups/",resourceGroup)
| where TimeCreated < ago(30d)
| order by id asc 
| project id, resourceGroup, location, TimeCreated, subscriptionId
```

### Downgrade premium snapshots

Recommendation: Use Standard storage for managed disk snapshots instead of Premium to reduce storage costs.

#### About premium snapshots

Managed disk snapshots stored on Premium storage incur higher costs than Standard storage. In most cases, snapshots don't require the performance of Premium storage since they're used for backup and recovery, not active I/O. Downgrading to Standard storage can significantly reduce snapshot costs without affecting their functionality.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify snapshots using Premium storage. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify premium snapshots

Use the following ARG query to identify managed disk snapshots using Premium storage.

```kusto
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

Azure Storage accounts provide a unique namespace in Azure for your data. Storage accounts have evolved through several generations, and using legacy account kinds may limit access to newer features and optimizations.

Related resources:

- [Storage account product page](https://azure.microsoft.com/products/storage)
- [Storage account pricing](https://azure.microsoft.com/pricing/details/storage)
- [Storage account documentation](/azure/storage/common/storage-account-overview)

### Upgrade legacy storage accounts

Recommendation: Upgrade storage accounts using GPv1 or BlobStorage kind to GPv2 for better pricing tiers, features, and continued support.

#### About legacy storage accounts

Storage accounts using the GPv1 or BlobStorage kind don't support the latest Azure Storage features, such as access tiers for block blobs, lifecycle management policies, and immutability policies. GPv2 storage accounts provide the same features plus additional capabilities at competitive or lower prices. Microsoft recommends upgrading all GPv1 and BlobStorage accounts to GPv2.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify legacy storage accounts. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify legacy storage accounts

Use the following ARG query to identify storage accounts still using GPv1 or BlobStorage kind.

```kusto
resources
| where type =~ 'Microsoft.Storage/StorageAccounts'
    and kind !='StorageV2'
    and kind !='FileStorage'
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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.BestPractices/featureName/Storage)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

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
