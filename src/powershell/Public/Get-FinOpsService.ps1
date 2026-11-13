# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets the name and category for a service, publisher, and cloud provider.

    .PARAMETER ConsumedService
    Optional. ConsumedService value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = * (all).

    .PARAMETER ResourceId
    Optional. The Azure resource ID for resource you want to look up. Accepts wildcards. Default = * (all).

    .PARAMETER ResourceType
    Optional. The Azure resource type for the resource you want to find the service for. Default = null (all).

    .PARAMETER ServiceName
    Optional. The service name to find. Default = null (all).

    .PARAMETER ServiceCategory
    Optional. The service category to find services for. Default = null (all).

    .PARAMETER ServiceCategory
    Optional. The service subcategory to find services for. Default = null (all).

    .PARAMETER Servicemodel
    Optional. The service model the service aligns to. Expected values: IaaS, PaaS, SaaS. Default = null (all).

    .PARAMETER Environment
    Optional. The environment the service runs in. Expected values: Cloud, Hybrid, On-Premises. Default = null (all).

    .PARAMETER PublisherName
    Optional. The publisher name to find services for. Default = null (all).

    .PARAMETER PublisherCategory
    Optional. The publisher category to find services for. Default = null (all).

    .DESCRIPTION
    The Get-FinOpsService command returns service details based on the specified filters. This command is designed to help map Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema but can also be useful for general data cleansing.

    Please note that both ConsumedService and ResourceType are required to find a unique service in many cases.

    .EXAMPLE
    Get-FinOpsService -ConsumedService "Microsoft.C*" -ResourceType "Microsoft.Compute/virtualMachines"

    Returns all services with a resource provider that starts with "Microsoft.C".

    .LINK
    https://aka.ms/ftk/Get-FinOpsService
#>
function Get-FinOpsService()
{
    param(
        [Parameter(Position = 0)]
        [Alias("ResourceProvider", "RP")]
        [string]
        $ConsumedService = "*",

        # TODO: Add this to a parameter set separate from ResourceType
        [Parameter(Position = 1)]
        [string]
        $ResourceId,

        # TODO: Add this to a parameter set separate from ResourceId
        [Parameter(Position = 2)]
        [string]
        $ResourceType = "*",

        [string]
        $ServiceName = "*",

        [string]
        $ServiceCategory = "*",

        [string]
        $ServiceSubcategory = "*",

        [string]
        $ServiceModel = "*",

        [string]
        $Environment = "*",

        [string]
        $PublisherName = "*",

        [Alias("PublisherType")]
        [string]
        $PublisherCategory = "*"
    )

    # Convert the resource ID to a resource type
    if ($ResourceId)
    {
        $resourceInfo = Split-AzureResourceId -Id $ResourceId
        $type = $resourceInfo.Type
    }
    else
    {
        $type = $ResourceType
    }

    return Get-OpenDataService `
    | Where-Object {
        $_.ConsumedService -like $ConsumedService `
            -and $_.ResourceType -like $type `
            -and $_.ServiceName -like $ServiceName `
            -and $_.ServiceCategory -like $ServiceCategory `
            -and $_.ServiceSubcategory -like $ServiceSubcategory `
            -and $_.ServiceModel -like $ServiceModel `
            -and $_.Environment -like $Environment `
            -and $_.PublisherName -like $PublisherName `
            -and $_.PublisherType -like $PublisherCategory
    } `
    | ForEach-Object {
        [PSCustomObject]@{
            Environment        = $_.Environment
            ServiceModel       = $_.ServiceModel
            ServiceCategory    = $_.ServiceCategory
            ServiceSubcategory = $_.ServiceSubcategory
            ServiceName        = $_.ServiceName
            PublisherName      = $_.PublisherName
            PublisherCategory  = $_.PublisherType
            ProviderName       = 'Microsoft'
            ProviderCategory   = 'Cloud Provider'
        }
    } `
    | Select-Object -Property * -Unique
}
