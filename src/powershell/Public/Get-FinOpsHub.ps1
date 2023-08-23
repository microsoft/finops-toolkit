<#
    .SYNOPSIS
    Gets a FinOps hub instance.

    .PARAMETER Name
    Name of the FinOps hub.

    .PARAMETER ResourceGroupName
    Name of the resource group the FinOps hub was deployed to.

    .EXAMPLE
    Get-FinOpsHub -Name foo*

    Returns all FinOps hubs that start with 'foo'.

    .EXAMPLE
    Get-FinOpsHub -ResourceGroupName foo

    Returns all resources associated with a FinOps hub in reource group 'foo'.

    .EXAMPLE
    Get-FinOpsHub -Name foo -ResourceGroupName bar

    Returns all FinOps hubs named 'foo' in the 'bar' resource group.
#>

function Get-FinOpsHub
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $ResourceGroupName
    )

    $wildcard = '*'
    if ([System.String]::IsNullOrEmpty($Name))
    {
        $Name = $wildcard
    }

    if ([System.String]::IsNullOrEmpty($ResourceGroupName))
    {
        $ResourceGroupName = $wildcard
    }
    
    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:localizedData.ContextNotFound
    }

    $tagTemplate = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Cloud/hubs/{2}'
    $tagName = 'cm-resource-parent' 
    $subscriptionId = $context.Subscription.Id
    $tagValue = $tagTemplate -f $subscriptionId, $ResourceGroupName, $Name
    $output = @()
    $resources = Get-AzResource -TagName $tagName
    foreach ($resource in $resources)
    {
        foreach ($tag in $resource.Tags)
        {
            if ($tag.Values -like $tagValue)
            {
                $output += $resource
                break
            }
        }
    }

    return $output
}
