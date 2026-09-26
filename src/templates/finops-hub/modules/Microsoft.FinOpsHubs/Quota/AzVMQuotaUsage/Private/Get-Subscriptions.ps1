# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Retrieves all accessible subscriptions within the token's tenant.

.DESCRIPTION
    Gets all Azure subscriptions that the ARM bearer token has access to
    within its tenant.

.PARAMETER AccessToken
    ARM bearer token.

.OUTPUTS
    Array of subscription objects with subscriptionId, id, displayName, and tenantId.
#>
function Get-Subscriptions {
    param (
        [securestring]$AccessToken
    )
    Write-Host "Listing Subscriptions"
    return Get-ArmCollection -Path '/subscriptions?api-version=2022-12-01' -AccessToken $AccessToken
}
