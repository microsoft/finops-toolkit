# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets a pricing unit with its corresponding distinct unit and block size.

    .DESCRIPTION
    The Get-FinOpsPricingUnit command returns a pricing unit (aka unit of measure) with the singular, distinct unit based on applicable block pricing rules, and the pricing block size.

    Block pricing is when a service is measured in groups of units (e.g., 100 hours).

    .PARAMETER UnitOfMeasure
    Optional. Unit of measure (aka pricing unit) value from a Cost Management cost/usage details or price sheet dataset. Accepts wildcards. Default = * (all).

    .PARAMETER DistinctUnits
    Optional. The distinct unit for the pricing unit without block pricing. Accepts wildcards. Default = * (all).

    .PARAMETER BlockSize
    Optional. The number of units for block pricing (e.g., 100 for "100 Hours"). Default = null (all).

    .EXAMPLE
    Get-FinOpsPricingUnit -UnitOfMeasure "*hours*"

    ### Get based on unit of measure
    Returns all pricing units with "hours" in the name.

    .EXAMPLE
    Get-FinOpsPricingUnit -DistinctUnits "GB"

    ### Get based on distinct units
    Returns all pricing units measured in gigabytes.

    .LINK
    https://aka.ms/ftk/Get-FinOpsPricingUnit
#>
function Get-FinOpsPricingUnit()
{
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [Alias("PricingUnit")]
        [string]
        $UnitOfMeasure = "*",

        [Parameter()]
        [string]
        $DistinctUnits = "*",

        [Parameter()]
        [Alias("PricingBlockSize")]
        [AllowNull()]
        [double]
        $BlockSize
    )
    return Get-OpenDataPricingUnit `
    | Where-Object {
        $_.UnitOfMeasure -like $UnitOfMeasure `
            -and $_.DistinctUnits -like $DistinctUnits `
            -and ($null -eq $BlockSize -or $BlockSize -le 0 -or $_.PricingBlockSize -eq $BlockSize)
    } `
    | ForEach-Object {
        [PSCustomObject]@{
            DistinctUnits    = $_.DistinctUnits
            PricingBlockSize = $_.PricingBlockSize
            PricingUnit      = $_.UnitOfMeasure
        }
    } `
    | Select-Object -Property * -Unique
}
