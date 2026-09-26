# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Builds Quota rows for one subscription and location.

.DESCRIPTION
    Writes one ComputeResourceSku row for the smallest VM SKU of each family, with its family and physical zone restrictions.
    Writes one more ComputeResourceSku row for each other SKU of the family that has different zones or restrictions.
    The smallest SKU has the lowest vCPU count in its size, then the lowest name.
    Writes one usage row per usage entry of a resource provider with its quota. SKU rows do not hold quota values.
    The SKU family matches the ResourceName of the family's ComputeUsage row.
    API fields that have no column are kept in x_QuotaDetails.

.PARAMETER Subscription
    Subscription object from the ARM subscription list.

.PARAMETER Location
    Azure region of the SKU and usage data.

.PARAMETER ComputeSkus
    Compute resource SKUs returned for this subscription and location.

.PARAMETER Usage
    Usage entries of one resource provider returned for this subscription and location.

.PARAMETER UsageResourceType
    ResourceType of the usage rows, such as Microsoft.Compute/locations/usages.

.PARAMETER UsageSourceType
    x_SourceType of the usage rows, such as ComputeUsage.

.PARAMETER UsagePath
    Path of the usage list under the location, such as usages. Used to build the ResourceId of usage rows.

.PARAMETER AvailabilityZoneMappings
    Logical-to-physical availability zone mappings for this subscription and location.

.PARAMETER SKUs
    Array of VM SKU names to write SKU rows for. If empty, uses all VM SKUs returned for the location.
    The smallest SKU of each family is found from these SKUs only. Does not limit usage rows.

.OUTPUTS
    One CSV row string per written VM SKU and one per usage entry.
#>
function Get-QuotaDetails {
    param (
        [object]$Subscription,
        [string]$Location,
        [object[]]$ComputeSkus,
        [object[]]$Usage,
        [string]$UsageResourceType,
        [string]$UsageSourceType,
        [string]$UsagePath = 'usages',
        [object[]]$AvailabilityZoneMappings,
        [string[]]$SKUs
    )

    Write-Host "Processing: $($Subscription.subscriptionId) - $($Subscription.displayName) - $Location"

    # Index physical zone numbers by logical zone once per location
    $physicalZones = @{}
    foreach ($mapping in $AvailabilityZoneMappings) {
        $logicalZone = [string]$mapping.logicalZone
        if ($logicalZone -and -not $physicalZones.ContainsKey($logicalZone)) {
            # Physical zone number is the last character of the physical zone name (e.g., "eastus-az3")
            $physicalZones[$logicalZone] = if ($mapping.physicalZone) { [string]([string]$mapping.physicalZone)[-1] } else { '' }
        }
    }

    # Get the zones and restrictions of each VM SKU in this location, limited to the requested SKUs if any
    $auditedSkus = foreach ($filteredSku in $ComputeSkus) {
        if ($filteredSku.ResourceType -ne 'virtualMachines' -or -not ($filteredSku.LocationInfo.Location -like $Location)) {
            continue
        }
        if ($SKUs.Count -and $filteredSku.Name -notin $SKUs) {
            continue
        }

        # Convert logical zones to physical zones
        $zones = [string[]]@(foreach ($zone in $filteredSku.LocationInfo.Zones) { $physicalZones[[string]$zone] ?? '' })
        [Array]::Sort($zones)

        # Create the quota details object
        $auditedSku = [PSCustomObject]@{
            Family                     = $filteredSku.Family    # VM family key, the ResourceName of its usage row (e.g., "standardDv3Family")
            Tier                       = $filteredSku.Tier      # SKU tier (e.g., "Standard")
            Size                       = $filteredSku.Size      # SKU size (e.g., "D2s_v5")
            RegionRestricted           = 'False'                # Whether SKU is restricted in this entire region
            RegionRestrictedReasonCode = ''                     # Reason for the region restriction (e.g., "NotAvailableForSubscription")
            ZonesPresent               = $zones -join ","       # Available zones for this SKU
            ZonesRestricted            = ''                     # Zones where SKU is restricted
            ZonesRestrictedReasonCode  = ''                     # Reason for the zone restriction
        }

        # Process any restrictions on this SKU
        foreach ($restriction in $filteredSku.Restrictions) {
            if ($restriction.Type -like "Zone") {
                # Handle zone-specific restrictions, converting logical zones to physical zones
                $zoneRestrictions = [string[]]@(foreach ($zone in $restriction.RestrictionInfo.Zones) { $physicalZones[[string]$zone] ?? '' })
                [Array]::Sort($zoneRestrictions)
                $auditedSku.ZonesRestricted = $zoneRestrictions -join ","
                $auditedSku.ZonesRestrictedReasonCode = [string]$restriction.ReasonCode
            }
            elseif ($restriction.Type -like "Location") {
                # Handle region-wide restrictions
                $auditedSku.RegionRestricted = 'True'
                $auditedSku.RegionRestrictedReasonCode = [string]$restriction.ReasonCode
            }
        }

        [PSCustomObject]@{
            Name         = $filteredSku.Name
            Vcpus        = if ($filteredSku.Size -match '\d+') { [int]$Matches[0] } else { -1 } # First number in the size (e.g., 2 for "D2s_v5")
            Availability = "$($auditedSku.RegionRestricted)|$($auditedSku.RegionRestrictedReasonCode)|$($auditedSku.ZonesPresent)|$($auditedSku.ZonesRestricted)|$($auditedSku.ZonesRestrictedReasonCode)"
            Details      = $auditedSku
        }
    }

    # Find the smallest SKU of each family: the lowest vCPU count, then the lowest name
    $smallestSkus = @{}
    foreach ($sku in $auditedSkus) {
        $smallest = $smallestSkus[[string]$sku.Details.Family]
        if (-not $smallest -or $sku.Vcpus -lt $smallest.Vcpus -or ($sku.Vcpus -eq $smallest.Vcpus -and [string]::CompareOrdinal($sku.Name, $smallest.Name) -lt 0)) {
            $smallestSkus[[string]$sku.Details.Family] = $sku
        }
    }

    # Write the smallest SKU of each family, and each other SKU of the family with different zones or restrictions
    foreach ($sku in $auditedSkus) {
        $smallest = $smallestSkus[[string]$sku.Details.Family]
        if ($sku.Name -cne $smallest.Name -and $sku.Availability -ceq $smallest.Availability) {
            continue
        }

        # Output the result as a Quota CSV row with every non-empty field quoted, so empty values are read as null
        $row = @(
            'Microsoft'                                         # ProviderName
            "$($Subscription.id)/providers/Microsoft.Compute/locations/$Location/skus/$($sku.Name)" # ResourceId
            $sku.Name                                           # ResourceName
            'Microsoft.Compute/skus'                            # ResourceType
            $Subscription.id                                    # SubAccountId
            $sku.Name                                           # displayName
            $Location                                           # location
            ''                                                  # currentValue (quota is on the family's usage row)
            ''                                                  # limit
            ''                                                  # unit
            (ConvertTo-Json -InputObject $sku.Details -Compress -Depth 5) # x_QuotaDetails
            'Azure Resource Manager'                            # x_SourceName
            'Microsoft'                                         # x_SourceProvider
            'ComputeResourceSku'                                # x_SourceType
            '1.0'                                               # x_SourceVersion
        )
        ($row -replace '"', '""' -replace '(?s)^(.+)\z', '"$1"') -join ','
    }

    # Output every usage entry, such as VM family vCPUs, regional vCPUs, and disks
    $usageProvider = $UsageResourceType.Split('/')[0]
    foreach ($usageEntry in $Usage) {
        $usageDetails = [ordered]@{}
        # SQL returns the name as a string and the values under properties; other providers return them at the top level
        if ($usageEntry.name -is [string]) {
            $quota = $usageEntry.properties
            $resourceName = $usageEntry.name
            $displayName = $quota.displayName
            $columnFields = 'name', 'properties'
            $columnQuotaFields = 'displayName', 'currentValue', 'limit', 'unit'
        }
        else {
            $quota = $usageEntry
            $resourceName = $usageEntry.name.value
            $displayName = $usageEntry.name.localizedValue
            $columnFields = 'name', 'currentValue', 'limit', 'unit'
            $columnQuotaFields = $null
        }

        # Keep every API field that has no column, such as id, type, and isAdjustable, as a PascalCase key
        foreach ($field in $usageEntry.PSObject.Properties) {
            if ($field.Name -notin $columnFields) { $usageDetails[$field.Name.Substring(0, 1).ToUpperInvariant() + $field.Name.Substring(1)] = $field.Value }
        }
        if ($columnQuotaFields) {
            foreach ($field in $quota.PSObject.Properties) {
                if ($field.Name -notin $columnQuotaFields) { $usageDetails[$field.Name.Substring(0, 1).ToUpperInvariant() + $field.Name.Substring(1)] = $field.Value }
            }
        }

        # Machine Learning returns dedicated and low-priority quota of a VM family with the same name and id; its type path keeps their IDs unique
        $idPath = if ($usageEntry.type -and $usageEntry.type -ne $UsageResourceType) { $usageEntry.type.Substring($usageEntry.type.IndexOf('/') + 1) } else { $UsagePath }
        $row = @(
            'Microsoft'                                           # ProviderName
            "$($Subscription.id)/providers/$usageProvider/locations/$Location/$idPath/$resourceName" # ResourceId
            $resourceName                                         # ResourceName
            $UsageResourceType                                    # ResourceType
            $Subscription.id                                      # SubAccountId
            $displayName                                          # displayName
            $Location                                             # location
            $quota.currentValue                                   # currentValue
            $quota.limit                                          # limit
            $quota.unit                                           # unit
            (ConvertTo-Json -InputObject $usageDetails -Compress -Depth 5) # x_QuotaDetails
            'Azure Resource Manager'                              # x_SourceName
            'Microsoft'                                           # x_SourceProvider
            $UsageSourceType                                      # x_SourceType
            '1.0'                                                 # x_SourceVersion
        )
        ($row -replace '"', '""' -replace '(?s)^(.+)\z', '"$1"') -join ','
    }
}
