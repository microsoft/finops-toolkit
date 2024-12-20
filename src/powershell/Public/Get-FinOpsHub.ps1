# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets details about a FinOps hub instance.

    .DESCRIPTION
    The Get-FinOpsHub command gets details about a FinOps hub instance using the cm-resource-parent tag to identify hub resources.

    .PARAMETER Name
    Optional. Name of the FinOps hub instance. Supports wildcards.

    .PARAMETER ResourceGroupName
    Optional. Name of the resource group the FinOps hub was deployed to. Supports wildcards.

    .EXAMPLE
    Get-FinOpsHub

    Returns all FinOps hubs for the selected subscription.

    .EXAMPLE
    Get-FinOpsHub -Name foo*

    Returns all FinOps hubs that start with 'foo'.

    .EXAMPLE
    Get-FinOpsHub -ResourceGroupName foo

    Returns all resources associated with a FinOps hub in the 'foo' resource group.

    .EXAMPLE
    Get-FinOpsHub -Name foo -ResourceGroupName bar

    Returns all FinOps hubs named 'foo' in the 'bar' resource group.

    .LINK
    https://aka.ms/ftk/Get-FinOpsHub
#>
function Get-FinOpsHub
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 1)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $ResourceGroupName
    )

    if ([System.String]::IsNullOrEmpty($Name))
    {
        $Name = '*'
    }

    if ([System.String]::IsNullOrEmpty($ResourceGroupName))
    {
        $ResourceGroupName = '*'
    }

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    $tagTemplate = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Cloud/hubs/{2}'
    $tagName = 'cm-resource-parent'
    $subscriptionId = $context.Subscription.Id
    $tagValue = $tagTemplate -f $subscriptionId, $ResourceGroupName, $Name
    $resourceMatches = @()
    $resources = Get-AzResource -TagName $tagName

    foreach ($resource in $resources)
    {
        $tagMatch = $resource.Tags.Values | Where-Object -FilterScript { $_ -like $tagValue }
        if ($tagMatch)
        {
            $properties = [ordered]@{
                Name     = $tagMatch.Split('/')[-1]
                HubId    = $tagMatch
                Resource = $resource
            }

            $resourceMatches += New-Object -TypeName 'PSObject' -Property $properties
        }
    }

    if ($resourceMatches.Count -gt 0)
    {
        $output = @()
        $groups = $resourceMatches | Group-Object -Property 'HubId'
        foreach ($group in $groups)
        {
            # Determine version and status
            $allResources = $group.Group.Resource
            $hasStorage = $allResources.ResourceType -like 'microsoft.storage/storageaccounts'
            $hasFactory = $allResources.ResourceType -like 'microsoft.datafactory/factories'
            $hasVault = $allResources.ResourceType -like 'microsoft.keyvault/vaults'
            $hasIdentities = $allResources.ResourceType -like 'microsoft.managedidentity/userassignedidentities'
            if (($allResources.Count -eq 1) -and $hasStorage)
            {
                $status = 'StorageOnly'
            }
            elseif ($allResources.Count -eq 3 -and $hasStorage -and $hasFactory -and $hasVault)
            {
                $status = 'Deployed'
                $version = '0.0.1'
            }
            elseif ($allResources.Count -eq 4 -and $hasStorage -and $hasFactory -and $hasVault)
            {
                $status = 'DeployedWithExtraResources'
                $version = '0.0.1'
            }
            elseif ($allResources.Count -eq 5)
            {
                $status = 'Deployed'
                $version = '0.1'
            }
            elseif ($allResources.Count -ge 6 -and $hasStorage -and $hasFactory -and $hasVault -and $hasIdentities)
            {
                $status = 'DeployedWithExtraResources'
                $version = '0.1'
            }
            else
            {
                # TODO: Read version from storage
                $status = 'Unknown'
            }

            $groupProperties = [ordered]@{
                Name      = $group.Group.Name | Select-Object -Unique
                HubId     = $group.Group.HubId | Select-Object -Unique
                Location  = $group.Group.Resource.Location | Select-Object -Unique
                Version   = $version
                Status    = $status
                Resources = $allResources
            }

            $output += New-Object -TypeName 'PSObject' -Property $groupProperties
        }

        return $output
    }
}
