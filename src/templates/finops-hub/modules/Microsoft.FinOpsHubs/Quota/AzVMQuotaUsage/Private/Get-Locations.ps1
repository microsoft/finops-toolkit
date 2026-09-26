# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Retrieves all physical Azure regions.

.DESCRIPTION
    Gets all Azure regions that are physical locations (not logical regions)
    and have a defined physical location. Filters out logical regions and
    regions without physical presence. Uses the location list of the given subscription.

.PARAMETER SubscriptionId
    The Azure subscription ID to list locations for.

.PARAMETER AccessToken
    ARM bearer token.

.OUTPUTS
    Array of Azure region names (e.g., 'eastus', 'westus2', 'centralus')
#>
function Get-Locations {
    param (
        [string]$SubscriptionId,
        [securestring]$AccessToken
    )
    Write-Host "Listing Locations"
    $locations = Get-ArmCollection -Path "/subscriptions/$SubscriptionId/locations?api-version=2022-12-01" -AccessToken $AccessToken
    return ($locations | Where-Object { $_.metadata.regionType -eq 'Physical' -and $_.metadata.physicalLocation -ne "" -and $_.name } | Select-Object -Property name -Unique).name
}
