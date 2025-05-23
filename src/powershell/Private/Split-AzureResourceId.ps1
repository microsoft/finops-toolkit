# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

class AzureResourceIdInfo
{
    [string] $ResourceId
    [string] $SubscriptionId
    [string] $SubscriptionResourceId
    [string] $ResourceGroupId
    [string] $ResourceGroupName
    [string] $Provider
    [string] $Type
    [string] $Name
}

<#
    .SYNOPSIS
    Parses an Azure resource ID and returns an object that includes resource details.

    .PARAMETER Id
    Azure resource ID to parse.

    .DESCRIPTION
    The Split-AzureResourceId command parses an Azure resource ID and returns an object with properties based on what is parseable from the resource ID string.
    This command does not call any APIs and does not validate the resource exists.

    Split-AzureResourceId will fix invalid resource IDs in the following cases:
    - Adds a leading slash, if missing.
    - Removes a trailing slash, if present.
    - Removes the last segment if the resource ID has an odd number of segments.

    .EXAMPLE
    Split-AzureResourceId -Id '/subscriptions/##-#-#-#-###/resourceGroups/foo/providers/Microsoft.Bar/bazes/baz1'

    Parses the resource ID and returns an object with resource details.
#>
function Split-AzureResourceId
{
    [OutputType([AzureResourceIdInfo])]
    [CmdletBinding()]
    param
    (
        [AllowNull()]
        [AllowEmptyString()]
        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )

    if ($Id)
    {
        Write-Verbose "Parsing resource ID: '$Id'"

        if (-not $Id)
        {
            return @{ ResourceId = $null }
        }

        # Add leading slash
        if (-not $Id.StartsWith('/'))
        {
            $Id = "/$Id"
        }

        # Remove trailing slash
        $parts = $Id.TrimEnd('/').Split('/')

        # Check for odd number of segments
        if ($parts.Count % 2 -eq 0)
        {
            Write-Verbose "Resource ID has odd number of segments and is invalid: $Id"
            $Id = ($parts[0..($parts.Count - 2)] -join '/')
            Write-Verbose "  Parsing trimmed resource ID: $Id"
            return Split-AzureResourceId -Id $Id
        }

        # Check basic format
        $isRoot = $Id -eq '/'
        $isSubResource = -not $isRoot -and $parts[1].ToLower() -eq 'subscriptions'
        $isRGResource = $isSubResource -and $parts.Count -gt 3 -and $parts[3].ToLower() -eq 'resourcegroups'
        $isRG = $isRGResource -and $parts.Count -eq 5
        $isTenantResource = $parts[1].ToLower() -eq 'providers'
        $isProvider = $isTenantResource -and $parts.Count -eq 3
        $isTenant = $parts[1].ToLower() -eq 'tenants'

        Write-Verbose "Root? $isRoot"
        Write-Verbose "Subscription resource? $isSubResource"
        Write-Verbose "Resource group resource? $isRGResource"
        Write-Verbose "Resource group? $isRG"
        Write-Verbose "Tenant resource? $isTenantResource"
        Write-Verbose "Provider? $isProvider"
        Write-Verbose "Tenant? $isTenant"

        # Add implicit Microsoft.Resources RP before we check the resource details
        if ($isProvider)
        {
            # -or $isTenant
            # Prepend implicit RP name
            $leafParts = @('Microsoft.Resources') + $parts[1..($parts.Count - 1)]
        }
        else
        {
            # Prepend implicit RP name
            $leafParts = @($parts[0], 'providers', 'Microsoft.Resources') + $parts[1..($parts.Count - 1)]

            # Find last providers segment
            $leafParts = (($leafParts -replace '/PROVIDERS/', '/providers/') -join '/').Split('/providers/')[-1].Split('/')
        }

        Write-Verbose "Leaf resource: $($leafParts -Join '/')"

        return [AzureResourceIdInfo]@{
            ResourceId             = $Id
            SubscriptionId         = if ($isSubResource) { $parts[2] } else { $null }
            SubscriptionResourceId = if ($isSubResource) { $parts[0..2] -join '/' } else { $null }
            ResourceGroupId        = if ($isRGResource) { $parts[0..4] -join '/' } else { $null }
            ResourceGroupName      = if ($isRGResource) { $parts[4] } else { $null }
            Provider               = $leafParts[0]
            Type                   = @($leafParts[0]) + $leafParts[(1..($leafParts.Count - 1)).Where{ $_ % 2 -eq 1 }] -join '/'
            Name                   = if ($isRG) { $leafParts[-1] } else { @($leafParts[(2..($leafParts.Count - 1)).Where{ $_ % 2 -eq 0 }]) -join '/' }
        }
    }
}
