# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets the instance size flexibility group and ratio for an ARM SKU.

    .PARAMETER ArmSkuName
    Optional. The ARM SKU name to look up. Accepts wildcards. Default = * (all).

    .PARAMETER InstanceSizeFlexibilityGroup
    Optional. The instance size flexibility group to find SKUs for. Accepts wildcards. Default = * (all).

    .DESCRIPTION
    The Get-FinOpsInstanceSizeFlexibility command returns instance size flexibility (ISF) ratios, sourced from the Azure Reservations Catalogs API. ISF lets a reservation apply across multiple SKUs in the same flexibility group, weighted by a ratio.

    .EXAMPLE
    Get-FinOpsInstanceSizeFlexibility -ArmSkuName "Standard_D4s_v5"

    Returns the flexibility group and ratio for the Standard_D4s_v5 SKU.

    .EXAMPLE
    Get-FinOpsInstanceSizeFlexibility -InstanceSizeFlexibilityGroup "Dsv5 Series"

    Returns all SKUs in the Dsv5 Series flexibility group.

    .LINK
    https://aka.ms/ftk/Get-FinOpsInstanceSizeFlexibility
#>
function Get-FinOpsInstanceSizeFlexibility()
{
    param(
        [Parameter(Position = 0)]
        [string]
        $ArmSkuName = "*",

        [Parameter(Position = 1)]
        [string]
        $InstanceSizeFlexibilityGroup = "*"
    )

    return Get-OpenDataInstanceSizeFlexibility `
    | Where-Object {
        $_.ArmSkuName -like $ArmSkuName `
            -and $_.InstanceSizeFlexibilityGroup -like $InstanceSizeFlexibilityGroup
    } `
    | ForEach-Object {
        [PSCustomObject]@{
            InstanceSizeFlexibilityGroup = $_.InstanceSizeFlexibilityGroup
            ArmSkuName                   = $_.ArmSkuName
            Ratio                        = $_.Ratio
        }
    } `
    | Select-Object -Property * -Unique
}
