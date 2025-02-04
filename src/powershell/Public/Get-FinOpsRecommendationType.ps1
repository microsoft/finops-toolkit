# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets details about an Azure Advisor recommendation type.

    .PARAMETER Id
    Optional. Azure Advisor recommendation type ID value. Accepts wildcards. Default = * (all).

    .PARAMETER Cost
    Optional. Indicates that only cost recommendations should be returned. Can be combined with other category flags.

    .PARAMETER HighAvailability
    Optional. Indicates that only high availability recommendations should be returned. Can be combined with other category flags.

    .PARAMETER OperationalExcellence
    Optional. Indicates that only operational excellence recommendations should be returned. Can be combined with other category flags.

    .PARAMETER Performance
    Optional. Indicates that only performance recommendations should be returned. Can be combined with other category flags.

    .PARAMETER High
    Optional. Indicates that only high impact recommendations should be returned. Can be combined with other impact flags.

    .PARAMETER Medium
    Optional. Indicates that only medium impact recommendations should be returned. Can be combined with other impact flags.

    .PARAMETER Low
    Optional. Indicates that only low impact recommendations should be returned. Can be combined with other impact flags.

    .PARAMETER Service
    Optional. Service name the recommendation pertains to. Accepts wildcards. Default = * (all).

    .PARAMETER Key
    Optional. Azure recommendation type key value. Accepts wildcards. Default = * (all).

    .PARAMETER Message
    Optional. Azure recommendation type message. Accepts wildcards. Default = * (all).

    .DESCRIPTION
    The Get-FinOpsRecommendationType command returns details about an Azure Advisor recommendation type with name, description, and a documentation link.

    .EXAMPLE
    Get-FinOpsRecommendationType -Id "abb1f687-2d58-4197-8f5b-8882f05c04b8"

    Returns the recommendation type details for virtual machine reservation renewal recommendation.

    .EXAMPLE
    Get-FinOpsRecommendationType -Cost

    Returns details for all cost recommendation types.

    .EXAMPLE
    Get-FinOpsRecommendationType -High

    Returns details for all high impact recommendation types.

    .EXAMPLE
    Get-FinOpsRecommendationType -Service "Virtual Machines"

    Returns details for all virtual machine recommendation types.

    .LINK
    https://aka.ms/ftk/Get-FinOpsRecommendationType
#>
function Get-FinOpsRecommendationType()
{
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [SupportsWildcards()]
        [string]
        $Id = "*",

        [Parameter()]
        [switch]
        $Cost = $false,

        [Parameter()]
        [switch]
        $HighAvailability = $false,

        [Parameter()]
        [switch]
        $OperationalExcellence = $false,

        [Parameter()]
        [switch]
        $Performance = $false,

        [Parameter()]
        [switch]
        $High = $false,

        [Parameter()]
        [switch]
        $Medium = $false,

        [Parameter()]
        [switch]
        $Low = $false,

        [Parameter()]
        [SupportsWildcards()]
        [string]
        $Service = "*",
    
        [Parameter()]
        [SupportsWildcards()]
        [string]
        $Key = "*",
    
        [Parameter()]
        [SupportsWildcards()]
        [string]
        $Message = "*"
    )
    $allImpacts = $false -eq ($High -or $Medium -or $Low)
    $allCategories = $false -eq ($Cost -or $HighAvailability -or $OperationalExcellence -or $Performance)
    return Get-OpenDataRecommendationType `
    | Where-Object {
        $_.RecommendationTypeId -like $Id `
            -and $_.ServiceName -like $Service `
            -and $_.Key -like $Key `
            -and $_.Message -like $Message `
            -and ($allImpacts `
                -or ($High -and $_.Impact -eq 'High') `
                -or ($Medium -and $_.Impact -eq 'Medium') `
                -or ($Low -and $_.Impact -eq 'Low')
        ) `
            -and ($allCategories `
                -or ($Cost -and $_.Category -eq 'Cost') `
                -or ($HighAvailability -and $_.Category -eq 'High Availability') `
                -or ($OperationalExcellence -and $_.Category -eq 'Operation Excellence') `
                -or ($Performance -and $_.Category -eq 'Performance')
        )
    }
}
