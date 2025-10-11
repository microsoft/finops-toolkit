# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets metadata for Azure Advisor recommendation types.

    .PARAMETER RecommendationTypeId
    Optional. The recommendation type ID (GUID) to filter by. Accepts wildcards. Default = * (all).

    .PARAMETER Category
    Optional. The recommendation category to filter by. Accepts wildcards. Default = * (all).
    Expected values: Cost, HighAvailability, OperationalExcellence, Performance, Security.

    .PARAMETER Impact
    Optional. The impact level to filter by. Accepts wildcards. Default = * (all).
    Expected values: High, Medium, Low.

    .PARAMETER ServiceName
    Optional. The service name to filter by. Accepts wildcards. Default = * (all).

    .PARAMETER ResourceType
    Optional. The resource type to filter by. Accepts wildcards. Default = * (all).

    .DESCRIPTION
    The Get-FinOpsRecommendationType command returns metadata about Azure Advisor recommendation types
    based on the specified filters. This data helps organize and provide additional context for 
    Azure Advisor recommendations in FinOps reports and dashboards.

    The recommendation type metadata includes:
    - RecommendationTypeId - Unique GUID identifier
    - Category - Cost, HighAvailability, OperationalExcellence, Performance, or Security
    - Impact - High, Medium, or Low
    - ServiceName - Name of the Azure service
    - ResourceType - Azure resource type (lowercase)
    - DisplayName - Human-readable description
    - LearnMoreLink - URL to documentation

    .EXAMPLE
    Get-FinOpsRecommendationType

    Returns all recommendation types.

    .EXAMPLE
    Get-FinOpsRecommendationType -Category Cost

    Returns all cost-related recommendation types.

    .EXAMPLE
    Get-FinOpsRecommendationType -Impact High -Category Cost

    Returns all high-impact cost recommendation types.

    .EXAMPLE
    Get-FinOpsRecommendationType -ResourceType "microsoft.compute/virtualmachines"

    Returns all recommendation types that apply to virtual machines.

    .LINK
    https://aka.ms/ftk/Get-FinOpsRecommendationType
#>
function Get-FinOpsRecommendationType()
{
    param(
        [Parameter(Position = 0)]
        [string]
        $RecommendationTypeId = "*",

        [Parameter(Position = 1)]
        [string]
        $Category = "*",

        [Parameter(Position = 2)]
        [string]
        $Impact = "*",

        [string]
        $ServiceName = "*",

        [string]
        $ResourceType = "*"
    )

    return Get-OpenDataRecommendationType `
    | Where-Object {
        $_.RecommendationTypeId -like $RecommendationTypeId `
            -and $_.Category -like $Category `
            -and $_.Impact -like $Impact `
            -and $_.ServiceName -like $ServiceName `
            -and $_.ResourceType -like $ResourceType
    } `
    | ForEach-Object {
        [PSCustomObject]@{
            RecommendationTypeId = $_.RecommendationTypeId
            Category             = $_.Category
            Impact               = $_.Impact
            ServiceName          = $_.ServiceName
            ResourceType         = $_.ResourceType
            DisplayName          = $_.DisplayName
            LearnMoreLink        = $_.LearnMoreLink
        }
    }
}
