---
title: Show-AzVMQuotaReport.ps1
parent: Tools & scripts
nav_order: 3
---

# Show-AzVMQuotaReport.ps1

Single-threaded Azure VM quota reporting script that provides streamlined quota analysis for smaller deployments or learning scenarios.

## Overview

This PowerShell script offers a simplified approach to Azure VM quota analysis. Unlike its multi-threaded counterpart, it processes subscriptions sequentially and displays results in a formatted table, making it ideal for smaller estates or when you're learning how Azure quota management works.

### Key capabilities

- **Sequential processing**: Straightforward single-threaded execution for easier debugging
- **Formatted output**: Displays results in a clean table format at completion
- **Zone restriction detection**: Identifies which availability zones are restricted for specific VM SKUs
- **Physical zone mapping**: Optional mapping of logical to physical zones for cross-subscription planning
- **Educational design**: Simpler code structure for understanding quota analysis patterns

### When to use this script

- Learning Azure quota management concepts
- Analyzing smaller subscription counts (< 10 subscriptions)
- Debugging quota issues with verbose output
- Quick ad-hoc quota checks for specific SKUs/regions
- Teaching quota analysis patterns to new team members

### Comparison with Get-AzVMQuotaUsage.ps1

| Feature | Show-AzVMQuotaReport | Get-AzVMQuotaUsage |
|---------|----------------------|--------------------|
| Threading | Single-threaded | Multi-threaded (configurable) |
| Best for | < 10 subscriptions | 100+ subscriptions |
| Performance | Sequential | Parallel processing |
| Code complexity | Simpler | Production-optimized |
| Output format | Table + CSV | CSV only |
| Use case | Learning/debugging | Production analysis |

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Authenticate to Azure
Connect-AzAccount

# Verify subscription access
Get-AzSubscription | Select-Object Name, Id, State

# Check Reader permissions
Get-AzRoleAssignment | Where-Object {$_.RoleDefinitionName -like "*Reader*"}
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **SKUs** | String[] | Array of VM SKU names to analyze | Downloads all SKUs |
| **Locations** | String[] | Array of Azure regions to query | All regions |
| **SubscriptionIds** | String[] | Array of subscription IDs to analyze | All accessible subscriptions |
| **OutputFile** | String | CSV output filename | QuotaQuery.csv |
| **UsePhysicalZones** | Switch | Map logical zones to physical datacenters | False |
| **MeterDataUri** | String | URL for VM SKU metadata | Azure public data |

## Usage examples

### Basic quota check for specific SKUs

```powershell
.\Show-AzVMQuotaReport.ps1 -SKUs @('Standard_D2s_v5', 'Standard_E4s_v5') -Locations @('eastus', 'westus2')
```

### Analyze specific subscriptions with physical zone mapping

```powershell
.\Show-AzVMQuotaReport.ps1 `
    -SubscriptionIds @('sub1-guid', 'sub2-guid') `
    -UsePhysicalZones `
    -OutputFile "DevSubscriptionQuota.csv"
```

### Quick quota audit for a single region

```powershell
.\Show-AzVMQuotaReport.ps1 `
    -SKUs @('Standard_D4s_v5') `
    -Locations @('eastus') `
    -OutputFile "EastUSQuotaCheck_$(Get-Date -Format 'yyyyMMdd').csv"
```

### Full analysis with all defaults

```powershell
.\Show-AzVMQuotaReport.ps1 -OutputFile "CompleteQuotaAnalysis.csv"
```

## Sample output

Running the script produces both console output and a CSV file:

### Console output
```plaintext
Downloading VM SKU Details
Listing Subscriptions
Processing subscription: Development (12345678-abcd-1234-5678-123456789012)
  Analyzing location: eastus
    Checking SKU: Standard_D2s_v5
    Checking SKU: Standard_E4s_v5
  Analyzing location: westus2
    Checking SKU: Standard_D2s_v5
    Checking SKU: Standard_E4s_v5

Results saved to: QuotaQuery.csv

Summary Table:
Subscription    Location    SKU                 CoresUsed/Total    Zones Available
------------    --------    ---------------     ---------------    ---------------
Development     eastus      Standard_D2s_v5     8/100             1,2,3
Development     eastus      Standard_E4s_v5     0/100             1,2,3
Development     westus2     Standard_D2s_v5     4/100             1,2,3
Development     westus2     Standard_E4s_v5     16/100            1,2,3
```

### CSV output
```csv
TenantId,SubscriptionId,SubscriptionName,Location,Family,Size,RegionRestricted,ZonesPresent,ZonesRestricted,CoresUsed,CoresTotal
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Development,eastus,standardDSv5Family,Standard_D2s_v5,False,"1,2,3",,8,100
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Development,eastus,standardESv5Family,Standard_E4s_v5,False,"1,2,3",,0,100
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Development,westus2,standardDSv5Family,Standard_D2s_v5,False,"1,2,3",,4,100
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Development,westus2,standardESv5Family,Standard_E4s_v5,False,"1,2,3",,16,100
```

### Understanding the output

- **TenantId**: Microsoft Entra tenant identifier
- **SubscriptionId**: Unique subscription identifier
- **SubscriptionName**: Friendly subscription name
- **Location**: Azure region
- **Family**: VM family for quota calculation
- **Size**: Specific VM SKU
- **RegionRestricted**: Whether the SKU has regional restrictions
- **ZonesPresent**: Available availability zones
- **ZonesRestricted**: Zones requiring enablement request
- **CoresUsed**: Current vCPU consumption
- **CoresTotal**: Total vCPU quota limit

## Troubleshooting

### Script runs slowly

This is expected behavior for the single-threaded version. For faster processing:
```powershell
# Use the multi-threaded version instead
.\Get-AzVMQuotaUsage.ps1 -Threads 4
```

### No SKU data returned

```powershell
# Verify the region supports the SKU
Get-AzComputeResourceSku -Location 'eastus' |
    Where-Object {$_.Name -eq 'Standard_D2s_v5'}

# Check if meter data download succeeded
Test-Path "AutofitComboMeterData.csv"
```

### Authentication errors

```powershell
# Clear and re-authenticate
Clear-AzContext -Force
Connect-AzAccount -Tenant 'your-tenant-id'

# Verify current context
Get-AzContext | Select-Object Account, Subscription, Tenant
```

### Empty zones data

```powershell
# Some regions don't support availability zones
Get-AzLocation | Where-Object Location -eq 'westus' |
    Select-Object -ExpandProperty Zones

# If empty, the region doesn't support zones
```

## Educational value

This script serves as a learning tool for understanding:
- How Azure organizes quota by VM family
- The relationship between logical and physical zones
- Sequential API interaction patterns
- CSV export for further analysis

For production use with large subscription counts, use Get-AzVMQuotaUsage.ps1 which provides:
- Parallel processing for 10x faster execution
- Configurable thread counts
- Better error handling for large-scale analysis

## Performance comparison

| Subscriptions | Show-AzVMQuotaReport | Get-AzVMQuotaUsage (4 threads) |
|---------------|----------------------|----------------------------------|
| 5 | ~2 minutes | ~30 seconds |
| 25 | ~10 minutes | ~3 minutes |
| 100 | ~40 minutes | ~10 minutes |

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/quota/Show-AzVMQuotaReport.ps1)

## Related scripts

- [Get-AzVMQuotaUsage.ps1](get-azvmquotausage.md) - Multi-threaded version for production use
- [Get-AzAvailabilityZoneMapping.ps1](get-azavailabilityzonemapping.md) - Dedicated zone mapping analysis