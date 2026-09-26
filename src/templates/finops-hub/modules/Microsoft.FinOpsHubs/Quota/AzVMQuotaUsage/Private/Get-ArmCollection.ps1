# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Gets all items from an Azure Resource Manager GET request.

.DESCRIPTION
    Calls Azure Resource Manager with a bearer token and follows nextLink pagination.
    Returns each item in the value collection, or the response itself when it has no value collection.

.PARAMETER Path
    Azure Resource Manager path and query string, starting with a forward slash.

.PARAMETER AccessToken
    ARM bearer token.

.OUTPUTS
    Response items.
#>
function Get-ArmCollection {
    param (
        [string]$Path,
        [securestring]$AccessToken
    )

    $uri = "https://management.azure.com$Path"
    do {
        if (([uri]$uri).Scheme -ne 'https' -or ([uri]$uri).Authority -ne 'management.azure.com') {
            throw "Unexpected ARM endpoint: $uri"
        }
        $response = Invoke-RestMethod -Uri $uri -Authentication Bearer -Token $AccessToken -TimeoutSec 120 -ErrorAction Stop
        if ($response.PSObject.Properties.Name -contains 'value') { $response.value } else { $response }
        $uri = $response.nextLink
    } while ($uri)
}
