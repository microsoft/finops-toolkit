---
title: Get-AzVMQuotaUsage.ps1
parent: Tools & scripts
nav_order: 1
---

# Get-AzVMQuotaUsage.ps1

Multi-threaded Azure VM quota analysis script that provides comprehensive quota visibility across your subscription estate.

## Overview

This PowerShell script analyzes Azure VM quota usage and availability zone restrictions across multiple subscriptions and regions in parallel. It addresses the challenge of understanding quota consumption at scale when managing hundreds of subscriptions without Quota Groups.

### Key capabilities

- **Parallel processing**: Multi-threaded execution across subscriptions for faster analysis
- **Zone restriction detection**: Identifies which availability zones are restricted for specific VM SKUs
- **Physical zone mapping**: Maps logical zones to physical datacenters for cross-subscription alignment
- **Comprehensive reporting**: Outputs detailed CSV with quota usage, limits, and zone availability

### When to use this script

- Quarterly capacity planning reviews
- Pre-deployment quota validation
- Cross-subscription deployment planning
- Zone alignment verification for multi-subscription architectures
- Identifying restricted SKUs and zones before scaling

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# PowerShell 7+ recommended for multi-threading
$PSVersionTable.PSVersion  # Should be 7.0 or higher

# Authenticate to Azure
Connect-AzAccount

# Verify you have Reader access to target subscriptions
Get-AzSubscription | Select-Object Name, Id, State
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **SKUs** | String[] | Array of VM SKU names to analyze | Downloads all SKUs |
| **Locations** | String[] | Array of Azure regions to query | All regions |
| **SubscriptionIds** | String[] | Array of subscription IDs to analyze | All accessible subscriptions |
| **Threads** | Int | Number of concurrent threads | 2 (0 for auto-detect) |
| **UsePhysicalZones** | Switch | Normalize output to physical zones | False |
| **OutputFile** | String | CSV output filename | VMQuotaUsage.csv |
| **MeterDataUri** | String | URL for VM SKU metadata | Azure public data |

## Usage examples

### Basic usage - analyze specific SKUs

```powershell
.\Get-AzVMQuotaUsage.ps1 -SKUs @('Standard_D4s_v5', 'Standard_E4s_v5') -Locations @('eastus', 'westus2')
```

### Multi-threaded analysis across all subscriptions

```powershell
.\Get-AzVMQuotaUsage.ps1 -SKUs @('Standard_D4s_v5', 'Standard_E4s_v5') `
                         -Locations @('eastus', 'westus2', 'northeurope') `
                         -Threads 4 `
                         -OutputFile "QuotaAnalysis_$(Get-Date -Format 'yyyyMMdd').csv"
```

### Physical zone mapping for cross-subscription deployment

```powershell
.\Get-AzVMQuotaUsage.ps1 -SKUs @('Standard_D4s_v5') `
                         -Locations @('eastus') `
                         -SubscriptionIds @('sub1-guid', 'sub2-guid') `
                         -UsePhysicalZones `
                         -OutputFile "CrossSubZoneAlignment.csv"
```

### Full estate analysis with auto-threading

```powershell
.\Get-AzVMQuotaUsage.ps1 -Threads 0 -OutputFile "FullEstateQuota.csv"
```

## Sample output

Running the script in a production environment produces output like this:

```csv
TenantId,SubscriptionId,SubscriptionName,Location,Family,Size,RegionRestricted,ZonesPresent,ZonesRestricted,CoresUsed,CoresTotal
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Production-East,eastus,standardDSv5Family,Standard_D4s_v5,False,"1,2,3",,24,350
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Production-East,eastus,standardESv5Family,Standard_E4s_v5,False,"1,2,3",,16,350
12345678-1234-1234-1234-123456789012,efgh5678-90ab-cdef-1234-567890abcdef,Production-West,westus2,standardDSv5Family,Standard_D4s_v5,False,"1,2,3",,48,350
12345678-1234-1234-1234-123456789012,efgh5678-90ab-cdef-1234-567890abcdef,Production-West,westus2,standardESv5Family,Standard_E4s_v5,False,"1,2,3",,0,350
12345678-1234-1234-1234-123456789012,ijkl9012-3456-7890-abcd-ef1234567890,Development,northeurope,standardDSv5Family,Standard_D4s_v5,True,"1,2,3","2,3",0,100
```

### Understanding the output

- **TenantId**: Your Microsoft Entra tenant identifier
- **SubscriptionId**: Unique subscription identifier
- **SubscriptionName**: Friendly subscription name
- **Location**: Azure region
- **Family**: VM family for quota calculation
- **Size**: Specific VM SKU
- **RegionRestricted**: Whether the SKU has regional restrictions (True/False)
- **ZonesPresent**: Available availability zones (comma-separated)
- **ZonesRestricted**: Restricted zones requiring enablement request (comma-separated)
- **CoresUsed**: Current vCPU consumption
- **CoresTotal**: Total vCPU quota limit

## Troubleshooting

### Common issues

**PowerShell version error**
```powershell
# Check version
$PSVersionTable.PSVersion

# Install PowerShell 7 if needed
winget install Microsoft.PowerShell
```

**Authentication failures**
```powershell
# Clear cached credentials
Clear-AzContext -Force

# Re-authenticate
Connect-AzAccount -Tenant 'your-tenant-id'
```

**Throttling with high thread count**
```powershell
# Reduce threads if seeing 429 errors
.\Get-AzVMQuotaUsage.ps1 -Threads 2  # Lower thread count
```

**No data returned**
```powershell
# Verify subscription access
Get-AzSubscription | Where-Object State -eq 'Enabled'

# Check region availability
Get-AzLocation | Select-Object Location, DisplayName
```

## Performance considerations

- **Thread optimization**: Start with 2-4 threads, increase gradually
- **Regional filtering**: Specify `-Locations` to reduce API calls
- **SKU filtering**: Target specific SKUs rather than analyzing all
- **Output size**: Large estates may produce CSV files over 10MB

## Integration with other tools

This script output integrates with:
- Excel pivot tables for quota analysis
- Power BI for visualization
- Azure Monitor for alerting
- Capacity planning spreadsheets

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/quota/Get-AzVMQuotaUsage.ps1)

## Related scripts

- [Get-AzAvailabilityZoneMapping.ps1](get-azavailabilityzonemapping.md) - Map logical to physical zones
- [Show-AzVMQuotaReport.ps1](show-azvmquotareport.md) - Single-threaded alternative