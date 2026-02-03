# FinOps hub developer documentation

## Data ingestion workflow

- All data is ingested into tables named "*_raw".
  - Raw tables are declared in [IngestionSetup_raw.kql](../modules/scripts/IngestionSetup_raw.kql).
  - These tables have a union schema to support multiple sources and versions.
- All data is transformed to the latest FOCUS schema using an update policy into a "*_final_vX_Y" table named after the version (for example, "1.0" = "_v1_0"). Final tables, Transform functions, and update policies are in the versioned setup files:
  - [IngestionSetup_v1_0.kql](../modules/scripts/IngestionSetup_v1_0.kql)
- Data ingestion from previous version of hubs will remain in the versioned tables.
- Data is read from versioned functions in the Hub database. See HubSetup_vX_Y.kql in the [modules/scripts folder](../modules/scripts) for details.

## Versioning strategy

- Each dataset includes a function that returns the latest version of the data (for example, "Costs()").
- Every supported version of FOCUS should have a corresponding function (for example, "Costs_v1_0").
- Each versioned function unions data from versioned tables in the Ingestion database and transforms it to that FOCUS version for back compat.
- Consumers should use the unversioned function for the latest and the versioned functions for back compat.

To add a new FOCUS versions:

1. Add schema mapping file
   1. Create new schema mapping file for the Cost Management export dataset version in the schemas folder
   2. Add file to file upload list in [storage.bicep](../modules/storage.bicep)
2. Update ingestion database scripts
   1. Add new columns to the *_raw tables per dataset in [IngestionSetup_RawTables.kql](../modules/scripts/IngestionSetup_RawTables.kql)
   2. Save a copy of the latest version of the IngestionSetup_vX_Y.kql using the latest FOCUS version
      - If updating the same version, increment the release number (e.g., `r2`)
   3. Rename all functions, tables, and policies in the new file to the new version (leave the old as-is)
   4. Update the *_final_vX_Y tables to account for any new columns
   5. Update the *_transform_vX_Y functions to account for any new columns
   6. Update the script to delete the old update policy for the *_raw tables
   7. Confirm the new file has the update policy set to use the latest version of the transform function and final table
3. Update hub database scripts
   1. Add new FOCUS version section after the latest version section and before existing version sections
   2. Create new *_vX_Y functions per dataset that transforms older data to the new FOCUS version
   3. Update the unversioned functions to use the new *_vX_Y functions
   4. Update older versioned functions to also pull from the new *_vX_Y functions and transform to the old schema
4. Update reports and dashboards
   1. Update the storage reports to use the new columns
   2. Update the KQL reports to use the new versioned functions
   3. Update the ADX dashboard to use the new versioned functions
   4. Update the FOCUS queries in the best practices library to use the new versioned functions

## Resource customization architecture

FinOps hubs support optional resource customization to accommodate enterprise naming conventions and centralized networking topologies. This section documents the technical implementation.

### Custom naming implementation

The custom naming feature allows users to override auto-generated resource names with their own values.

#### Architecture overview

```
main.bicep
  ├─ 13 optional parameters (default: empty string)
  │  ├─ 7 custom name parameters
  │  └─ 6 existing DNS Zone ID parameters
  │
  └─> hub.bicep
      └─> hub-types.bicep
          ├─ newHub() function
          │  └─ Creates HubProperties object with customNames/existingDnsZones
          │
          └─ Conditional logic pattern:
             name: !empty(customName) ? customName : generateDefaultName()
```

#### Key files and functions

1. **main.bicep** - Template entry point
   - Declares 13 optional parameters (all default to empty string `''`)
   - Passes parameters to `hub.bicep` module

2. **modules/hub.bicep** - Main orchestrator
   - Receives parameters from `main.bicep`
   - Calls `newHub()` function from `hub-types.bicep`
   - Passes hub configuration to child modules

3. **modules/fx/hub-types.bicep** - Type system and logic
   - **HubProperties type**: Contains `customNames` and `existingDnsZones` objects
   - **newHub() function**: Main entry point that creates hub configuration
   - **newHubInternal() function**: Internal implementation with conditional logic
   - **newAppInternal() function**: Creates app-specific configurations
   - **getPrivateEndpointName() function**: Returns custom or default PE names

4. **Resource-specific modules**:
   - **modules/fx/hub-app.bicep**: Storage, Data Factory, Key Vault, Private Endpoints
   - **modules/Microsoft.FinOpsHubs/Analytics/app.bicep**: Data Explorer cluster
   - **modules/Microsoft.FinOpsHubs/Core/infrastructure.bicep**: VNet, DNS Zones

#### Naming pattern

All custom naming follows this consistent pattern:

```bicep
resource example 'Microsoft.ResourceType@version' = {
  name: !empty(hub.customNames.resourceName) 
    ? hub.customNames.resourceName 
    : '{hub.name}-default-suffix'
}
```

**Key characteristics:**
- Simple `!empty()` check (no boolean flags)
- Ternary operator for clean conditionals
- Fallback to Azure naming best practices
- No breaking changes for existing deployments

#### Supported custom names

| Parameter | Azure Resource | Naming Rules |
|-----------|---------------|--------------|
| `storageAccountName` | Storage Account | 3-24 chars, lowercase + numbers only |
| `dataFactoryName` | Data Factory | 3-63 chars, alphanumeric + hyphens |
| `keyVaultName` | Key Vault | 3-24 chars, starts with letter |
| `virtualNetworkName` | Virtual Network | 2-64 chars, alphanumeric + hyphens/underscores/periods |
| `managedIdentityName` | Managed Identity | 3-128 chars, alphanumeric + hyphens/underscores |
| `dataExplorerClusterName` | Data Explorer | 4-22 chars, lowercase + numbers + hyphens |
| `privateEndpointNamePrefix` | Private Endpoints | Prefix + service type (e.g., `{prefix}-blob`) |

### Centralized networking (Hub & Spoke)

The centralized networking feature enables FinOps hubs to integrate with existing Hub & Spoke topologies by reusing centralized Private DNS Zones.

#### Architecture overview

```
Centralized Hub (Network RG)
  └─ Private DNS Zones (6)
     ├─ privatelink.blob.core.windows.net
     ├─ privatelink.dfs.core.windows.net
     ├─ privatelink.queue.core.windows.net
     ├─ privatelink.table.core.windows.net
     ├─ privatelink.vaultcore.azure.net
     └─ privatelink.{region}.kusto.windows.net

FinOps Hub (App RG)
  └─ Private Endpoints (5+)
     ├─ Uses existing DNS Zones (no duplication)
     └─ DNS Zone Groups link to centralized zones
```

#### Implementation pattern

**Conditional DNS Zone creation:**

```bicep
// Only create DNS Zone if not provided
resource blobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (empty(hub.existingDnsZones.blob)) {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}
```

**Private Endpoint with conditional DNS Zone:**

```bicep
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: getPrivateEndpointName(hub, 'blob')
  location: hub.location
  properties: {
    privateLinkServiceConnections: [/* ... */]
  }
  
  // Conditional DNS Zone Group
  resource dnsZoneGroup 'privateDnsZoneGroups' = if (!empty(hub.existingDnsZones.blob) || createNewZone) {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'blob'
          properties: {
            // Use existing zone if provided, otherwise use newly created zone
            privateDnsZoneId: !empty(hub.existingDnsZones.blob) 
              ? hub.existingDnsZones.blob 
              : blobDnsZone.id
          }
        }
      ]
    }
  }
}
```

#### Supported DNS Zones

| Parameter | DNS Zone FQDN | Used By |
|-----------|---------------|---------|
| `existingBlobDnsZoneId` | `privatelink.blob.core.windows.net` | Storage (Blob) |
| `existingDfsDnsZoneId` | `privatelink.dfs.core.windows.net` | Storage (Data Lake Gen2) |
| `existingQueueDnsZoneId` | `privatelink.queue.core.windows.net` | Storage (Queue), Data Explorer |
| `existingTableDnsZoneId` | `privatelink.table.core.windows.net` | Storage (Table), Data Explorer |
| `existingVaultDnsZoneId` | `privatelink.vaultcore.azure.net` | Key Vault |
| `existingDataExplorerDnsZoneId` | `privatelink.{region}.kusto.windows.net` | Data Explorer |

**Note:** Data Explorer requires 4 DNS Zones (its own + blob, queue, table for storage).

### Testing custom configurations

Test scenarios are provided in `test/main.test.bicep`:

1. **Test 1 (Default)**: Auto-generated names, new DNS Zones
2. **Test 2 (Custom Names)**: All 7 custom names specified
3. **Test 3 (Existing DNS)**: Centralized DNS Zones (Hub & Spoke)
4. **Test 4 (Hybrid)**: Custom names + existing DNS Zones

#### Running tests

```bash
# Test with default settings
az deployment group create \
  --resource-group ftk-test-rg \
  --template-file test/main.test.bicep \
  --parameters uniqueName=ftk-test-001

# Test with custom names
az deployment group create \
  --resource-group ftk-test-rg \
  --template-file test/main.test.bicep \
  --parameters uniqueName=ftk-test-002 \
               storageAccountName=ftkstgcustom001 \
               dataFactoryName=ftk-df-custom-001
```

### UI implementation (createUiDefinition.json)

The Azure Portal UI exposes customization options through a dedicated "Customization" tab.

#### UI structure

```
Tabs:
├─ Basics
├─ Pricing
├─ Retention
├─ Advanced
├─ Customization (NEW)
│  ├─ Section: Resource naming (optional)
│  │  ├─ InfoBox: "Leave empty for auto-generated names"
│  │  └─ 7 TextBox controls with validation
│  └─ Section: Centralized networking (Hub & Spoke)
│     ├─ InfoBox: "For Hub & Spoke topologies"
│     └─ 6 TextBox controls for DNS Zone Resource IDs
└─ Tags
```

#### Output mapping

The `outputs` section maps UI controls to template parameters:

```json
{
  "outputs": {
    "storageAccountName": "[steps('customization').resourceNaming.storageAccountName]",
    "existingBlobDnsZoneId": "[steps('customization').centralizedNetworking.existingBlobDnsZoneId]"
  }
}
```

### Best practices for developers

1. **Always use !empty() checks**: Never assume custom names are provided
2. **Maintain backward compatibility**: Empty parameters should work identical to previous versions
3. **Validate resource names**: Each parameter has regex validation in createUiDefinition.json
4. **Document defaults**: Clear comments on what default names will be generated
5. **Test all scenarios**: Default, custom names only, DNS zones only, and hybrid
6. **DNS Zone regions**: Data Explorer DNS Zone must match deployment region

### Migration guide

For existing deployments, no migration is needed. The feature is fully backward compatible:

- Empty parameters → Auto-generated names (existing behavior)
- Specified parameters → Custom names (new behavior)
- No changes to generated resource names when parameters are omitted

### Troubleshooting

**Issue**: Custom name rejected during deployment
- **Cause**: Name doesn't meet Azure naming rules
- **Fix**: Check validation regex in createUiDefinition.json or Azure docs

**Issue**: Private Endpoint can't resolve DNS
- **Cause**: DNS Zone ID is incorrect or zone not linked to VNet
- **Fix**: Verify DNS Zone exists and is properly linked in network hub

**Issue**: Duplicate DNS Zones created
- **Cause**: Empty DNS Zone parameter when one exists
- **Fix**: Provide correct DNS Zone resource IDs for centralized zones
