# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Builds Quota rows for ARM resources of one subscription.

.DESCRIPTION
    Writes one row per ARM resource, such as a subscription location with its availability zone mappings,
    a capacity reservation group, or a disk. The ResourceId, ResourceName, ResourceType, and location
    columns come from the resource. API fields that have no column are kept in x_QuotaDetails.

.PARAMETER Subscription
    Subscription object from the ARM subscription list.

.PARAMETER Resources
    ARM resources returned for this subscription.

.PARAMETER SourceType
    x_SourceType of the rows, such as AvailabilityZoneMapping, CapacityReservation, or PremiumSSDv2Disk.

.OUTPUTS
    One CSV row string per resource.
#>
function Get-ResourceDetails {
    param (
        [object]$Subscription,
        [object[]]$Resources,
        [string]$SourceType
    )

    foreach ($resource in $Resources) {
        $resourceDetails = [ordered]@{}

        # Keep every API field that has no column, such as sku, properties, and availabilityZoneMappings, as a PascalCase key
        foreach ($field in $resource.PSObject.Properties) {
            if ($field.Name -notin 'id', 'name', 'type', 'location', 'displayName') { $resourceDetails[$field.Name.Substring(0, 1).ToUpperInvariant() + $field.Name.Substring(1)] = $field.Value }
        }
        $row = @(
            'Microsoft'                                           # ProviderName
            $resource.id                                          # ResourceId
            $resource.name                                        # ResourceName
            $resource.type                                        # ResourceType (e.g., "Region" or "Microsoft.Compute/disks")
            $Subscription.id                                      # SubAccountId
            $resource.displayName ?? $resource.sku.name ?? $resource.name # displayName (region display name or disk SKU, e.g., "PremiumV2_LRS")
            $resource.location ?? $resource.name                  # location (subscription locations are named by region)
            $resource.properties.diskSizeGB                       # currentValue (disk size in GiB)
            ''                                                    # limit
            ''                                                    # unit
            (ConvertTo-Json -InputObject $resourceDetails -Compress -Depth 10) # x_QuotaDetails
            'Azure Resource Manager'                              # x_SourceName
            'Microsoft'                                           # x_SourceProvider
            $SourceType                                           # x_SourceType
            '1.0'                                                 # x_SourceVersion
        )
        ($row -replace '"', '""' -replace '(?s)^(.+)\z', '"$1"') -join ','
    }
}
