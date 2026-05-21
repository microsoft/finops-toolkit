---
title: Get-AzAvailabilityZoneMapping.ps1
parent: Tools & scripts
nav_order: 2
---

# Get-AzAvailabilityZoneMapping.ps1

Maps logical availability zones to physical datacenters across Azure subscriptions to ensure proper fault domain alignment.

## Overview

Azure randomizes the mapping between logical zones (1, 2, 3) and physical datacenters for each subscription. This means logical zone 1 in subscription A might map to a completely different physical datacenter than zone 1 in subscription B. This script reveals these mappings, which is critical for multi-subscription architectures requiring true zone alignment.

### Key capabilities

- **Physical zone discovery**: Reveals actual physical datacenter identifiers
- **Cross-subscription mapping**: Shows how zones align across multiple subscriptions
- **Compliance validation**: Ensures deployments meet data residency requirements
- **Architecture planning**: Essential data for multi-subscription deployment patterns

### When to use this script

- Planning multi-subscription deployments with zone redundancy
- Verifying zone alignment before deployment stamp creation
- Troubleshooting zone-related deployment failures
- Compliance audits requiring physical datacenter documentation
- Capacity reservation planning across subscriptions

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Authenticate to Azure
Connect-AzAccount

# Verify subscription access
Get-AzSubscription | Select-Object Name, Id, State

# Ensure you have Reader access to target subscriptions
Get-AzRoleAssignment | Where-Object {$_.RoleDefinitionName -like "*Reader*"}
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **SubscriptionIds** | String[] | Array of subscription IDs to analyze | All accessible subscriptions |
| **OutputFile** | String | CSV output filename | ZonePeers.csv |

## Usage examples

### Basic usage - all subscriptions

```powershell
.\Get-AzAvailabilityZoneMapping.ps1
```

### Specific subscriptions for deployment planning

```powershell
.\Get-AzAvailabilityZoneMapping.ps1 `
    -SubscriptionIds @('prod-sub-guid', 'dr-sub-guid') `
    -OutputFile "ProdDRZoneAlignment.csv"
```

### Multi-subscription stamp validation

```powershell
# Get all production subscription IDs
$prodSubs = Get-AzSubscription | Where-Object Name -like "Prod-*" | Select-Object -ExpandProperty Id

# Analyze zone mappings
.\Get-AzAvailabilityZoneMapping.ps1 `
    -SubscriptionIds $prodSubs `
    -OutputFile "ProductionZoneMappings_$(Get-Date -Format 'yyyyMMdd').csv"
```

## Sample output

Running the script across multiple subscriptions produces output like this:

```csv
TenantId,SubscriptionId,SubscriptionName,Location,LogicalZone,PhysicalZone,PhysicalZoneName
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Production-Primary,eastus,1,2,eastus-az2
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Production-Primary,eastus,2,3,eastus-az3
12345678-1234-1234-1234-123456789012,abcd1234-5678-90ab-cdef-123456789012,Production-Primary,eastus,3,1,eastus-az1
12345678-1234-1234-1234-123456789012,efgh5678-90ab-cdef-1234-567890abcdef,Production-Secondary,eastus,1,3,eastus-az3
12345678-1234-1234-1234-123456789012,efgh5678-90ab-cdef-1234-567890abcdef,Production-Secondary,eastus,2,1,eastus-az1
12345678-1234-1234-1234-123456789012,efgh5678-90ab-cdef-1234-567890abcdef,Production-Secondary,eastus,3,2,eastus-az2
12345678-1234-1234-1234-123456789012,ijkl9012-3456-7890-abcd-ef1234567890,Development,eastus,1,1,eastus-az1
12345678-1234-1234-1234-123456789012,ijkl9012-3456-7890-abcd-ef1234567890,Development,eastus,2,2,eastus-az2
12345678-1234-1234-1234-123456789012,ijkl9012-3456-7890-abcd-ef1234567890,Development,eastus,3,3,eastus-az3
```

### Understanding the output

- **TenantId**: Microsoft Entra tenant identifier
- **SubscriptionId**: Unique subscription identifier
- **SubscriptionName**: Friendly subscription name
- **Location**: Azure region
- **LogicalZone**: The zone number applications see (1, 2, 3)
- **PhysicalZone**: Actual physical datacenter identifier
- **PhysicalZoneName**: Full physical datacenter name

### Critical findings from sample

In this example:
- **Production-Primary**: Logical zone 1 → Physical zone 2
- **Production-Secondary**: Logical zone 1 → Physical zone 3
- **Development**: Logical zone 1 → Physical zone 1

This means deploying to "zone 1" across these subscriptions would actually spread resources across three different physical datacenters, defeating zone alignment goals.

## Real-world implications

### Incorrect assumption
```plaintext
Deploy to Zone 1 in all subscriptions = Same physical datacenter ❌
```

### Reality revealed by script
```plaintext
Subscription A Zone 1 = Physical Datacenter 2
Subscription B Zone 1 = Physical Datacenter 3
Subscription C Zone 1 = Physical Datacenter 1
Result: No actual zone alignment! ⚠️
```

### Correct approach
```plaintext
Use script output to map deployments:
- Subscription A: Deploy to Zone 3 (Physical DC 1)
- Subscription B: Deploy to Zone 2 (Physical DC 1)
- Subscription C: Deploy to Zone 1 (Physical DC 1)
Result: True zone alignment ✅
```

## Troubleshooting

### No zone data returned

```powershell
# Verify the region supports availability zones
Get-AzLocation | Where-Object Location -eq 'eastus' | Select-Object -ExpandProperty Zones

# Check if subscription has zone access
Get-AzComputeResourceSku -Location 'eastus' |
    Where-Object {$_.LocationInfo.Zones.Count -gt 0} |
    Select-Object -First 5
```

### Access denied errors

```powershell
# Verify role assignments
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# Switch to correct subscription context
Set-AzContext -SubscriptionId 'target-subscription-id'
```

### Performance optimization

For large numbers of subscriptions:
```powershell
# Process in batches
$allSubs = Get-AzSubscription | Select-Object -ExpandProperty Id
$batchSize = 10

for ($i = 0; $i -lt $allSubs.Count; $i += $batchSize) {
    $batch = $allSubs[$i..([Math]::Min($i + $batchSize - 1, $allSubs.Count - 1))]
    .\Get-AzAvailabilityZoneMapping.ps1 `
        -SubscriptionIds $batch `
        -OutputFile "ZoneMapping_Batch_$($i / $batchSize + 1).csv"
}
```

## Integration patterns

### Excel analysis
1. Import CSV into Excel
2. Create pivot table by Physical Zone
3. Filter by Location
4. Identify subscription groups with matching physical zones

### Automated deployment alignment
```powershell
# Load zone mappings
$zoneMappings = Import-Csv "ZonePeers.csv"

# Find subscriptions where logical zone 1 maps to physical zone 1
$alignedSubs = $zoneMappings |
    Where-Object {$_.LogicalZone -eq 1 -and $_.PhysicalZone -eq 1} |
    Select-Object -Unique SubscriptionId, SubscriptionName

# Deploy to these subscriptions in zone 1 for alignment
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/quota/Get-AzAvailabilityZoneMapping.ps1)

## Related scripts

- [Get-AzVMQuotaUsage.ps1](get-azvmquotausage.md) - Comprehensive quota analysis with zone restrictions
- [Show-AzVMQuotaReport.ps1](show-azvmquotareport.md) - Single-threaded quota reporting