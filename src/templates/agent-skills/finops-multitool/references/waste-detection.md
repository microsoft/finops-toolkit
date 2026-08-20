# Waste detection

Finding resources that cost money without delivering value: orphaned infrastructure, idle compute, mis-tiered storage, and unclaimed licensing benefits.

All queries here are read-only. Run them with `az graph query -q "<query>"`, an Azure MCP Resource Graph tool, or `Search-AzGraph`.

## Orphaned resources

Six distinct categories. Run them together and group the results — a single "orphans" number is more actionable than six separate ones.

### Unattached managed disks

```kusto
resources
| where type =~ 'microsoft.compute/disks'
| where managedBy == '' or isnull(managedBy)
| where properties.diskState == 'Unattached'
| project name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          sku = sku.name, diskState = properties.diskState
```

Premium SSD disks are the expensive case. Report size and SKU, not just the count.

### Unattached public IPs

```kusto
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where properties.ipConfiguration == '' or isnull(properties.ipConfiguration)
| where properties.natGateway == '' or isnull(properties.natGateway)
| project name, resourceGroup, subscriptionId, location,
          sku = sku.name, ipAddress = properties.ipAddress,
          allocationMethod = properties.publicIPAllocationMethod
```

The `natGateway` check matters. An IP attached to a NAT gateway has no `ipConfiguration` but is very much in use — omitting that filter produces false positives.

Standard static IPs bill even when idle; Basic dynamic ones largely don't. Lead with the Standard ones.

### Unattached network interfaces

```kusto
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine) or properties.virtualMachine == ''
| where isnull(properties.privateEndpoint) or properties.privateEndpoint == ''
| project name, resourceGroup, subscriptionId, location,
          enableAcceleratedNetworking = properties.enableAcceleratedNetworking
```

NICs are free. They matter as a signal of abandoned deployments, not as a cost line — say so rather than implying savings.

### Deallocated VMs

```kusto
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.extended.instanceView.powerState.displayStatus == 'VM deallocated'
    or properties.extended.instanceView.powerState.code == 'PowerState/deallocated'
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          powerState = properties.extended.instanceView.powerState.displayStatus
```

**The one people get wrong.** A deallocated VM stops billing for compute, so it looks resolved. Its managed disks and any static public IP keep billing indefinitely. Treat a long-deallocated VM as an open finding and quantify the disk cost.

### Empty App Service plans

```kusto
resources
| where type =~ 'microsoft.web/serverfarms'
| where properties.numberOfSites == 0
| where sku.tier != 'Free' and sku.tier != 'Shared'
| project name, resourceGroup, subscriptionId, location,
          sku = strcat(sku.tier, ' / ', sku.name),
          workers = properties.numberOfWorkers
```

A plan with no sites bills the full tier. Multiply by `numberOfWorkers` — scaled-out empty plans are expensive.

### Old snapshots

```kusto
resources
| where type =~ 'microsoft.compute/snapshots'
| where properties.timeCreated < datetime('<cutoff>')
| project name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          timeCreated = properties.timeCreated
```

Substitute a cutoff date — 90 days back is a reasonable default. Confirm retention policy before recommending deletion; snapshots are sometimes the backup.

## Idle virtual machines

Two steps. Resource Graph gives the inventory:

```kusto
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend powerState = tostring(properties.extended.instanceView.powerState.code)
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          osType = properties.storageProfile.osDisk.osType,
          powerState
```

Then query Monitor metrics per running VM over a 14-day window:

```bash
az monitor metrics list --resource <vmResourceId> \
  --metric "Percentage CPU" "Network In Total" "Network Out Total" \
  --start-time <14d-ago> --end-time <now> \
  --aggregation Average Total --interval P14D
```

Classification used by the terminal UI:

| Verdict | Criteria |
| ------- | -------- |
| Idle | average CPU < 5% **and** total network < 14 MB over 14 days |
| Underutilized | average CPU < 10% **and** total network < 140 MB over 14 days |

**Use both signals.** CPU alone misclassifies a busy file server or a network appliance as idle. A VM moving traffic is doing work regardless of processor load.

Recommend deallocation for idle VMs and rightsizing for underutilized ones — they're different actions.

## Storage tier optimization

Find Hot-tier accounts:

```kusto
resources
| where type =~ 'microsoft.storage/storageaccounts'
| where properties.accessTier =~ 'Hot' or isnull(properties.accessTier)
| project name, resourceGroup, subscriptionId, location,
          kind, sku = sku.name,
          accessTier = tostring(properties.accessTier),
          creationTime = properties.creationTime
```

Then check 30-day transaction volume and blob capacity per account:

```bash
az monitor metrics list --resource <storageId>/blobServices/default \
  --metric Transactions --start-time <30d-ago> --end-time <now> \
  --aggregation Total --interval P30D
```

Low transactions plus meaningful capacity means the tier is wrong. Recommend Cool for infrequent access, Archive for effectively dormant data.

**Model the retrieval cost before recommending Archive.** Archive is cheap to store and expensive to read, with rehydration latency measured in hours. If the data is read even occasionally, Cool usually wins on total cost.

## Azure Hybrid Benefit

**Three resource types, three different license markers.** Checking only Windows VMs is the common mistake and understates the estate badly.

### Windows VMs

```kusto
resources
| where type == 'microsoft.compute/virtualmachines'
| where properties.storageProfile.osDisk.osType =~ 'Windows'
| where isempty(properties.licenseType) or (properties.licenseType !~ 'Windows_Server' and properties.licenseType !~ 'Windows_Client')
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          currentLicense = coalesce(tostring(properties.licenseType), 'None')
```

### SQL Server on VMs

```kusto
resources
| where type == 'microsoft.sqlvirtualmachine/sqlvirtualmachines'
| where isempty(properties.sqlServerLicenseType) or properties.sqlServerLicenseType !~ 'AHUB'
| project name, resourceGroup, subscriptionId, location,
          currentLicense = coalesce(tostring(properties.sqlServerLicenseType), 'None'),
          sqlEdition = tostring(properties.sqlImageSku)
```

### SQL Database and Managed Instance

```kusto
resources
| where type == 'microsoft.sql/servers/databases'
| where sku.tier != 'Free' and name != 'master'
| where isempty(properties.licenseType) or properties.licenseType !~ 'BasePrice'
| project name, resourceGroup, subscriptionId, location,
          currentLicense = coalesce(tostring(properties.licenseType), 'LicenseIncluded'),
          sku = strcat(tostring(sku.tier), ' / ', tostring(sku.name))
```

Marker summary:

| Resource type | Property | Value meaning AHB is on |
| ------------- | -------- | ----------------------- |
| Windows VM | `licenseType` | `Windows_Server` (or `Windows_Client`) |
| SQL Server VM | `sqlServerLicenseType` | `AHUB` |
| SQL Database / MI | `licenseType` | `BasePrice` |

**Eligibility is a licensing question, not a technical one.** These queries find resources that *could* use the benefit. Whether the customer owns qualifying licenses with Software Assurance is something only they can confirm. Present the findings as an opportunity to verify, never as guaranteed savings.

## Related

- `azure-cost-management` → `references/azure-orphaned-resources.md` for additional orphan query patterns
- `azure-cost-management` → `references/azure-vm-rightsizing.md` for SKU downsizing analysis
- `sustainability-carbon` for the emissions co-benefit of removing waste
