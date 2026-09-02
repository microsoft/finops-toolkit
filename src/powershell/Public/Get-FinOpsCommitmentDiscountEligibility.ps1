# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Gets commitment discount eligibility for a meter.

    .PARAMETER MeterId
    Optional. The meter ID to look up. Accepts wildcards. Default = * (all).

    .PARAMETER SpendEligibility
    Optional. Filters to meters with the specified savings plan (spend commitment) eligibility. FOCUS classifies a savings plan as a spend commitment because you commit to an amount of money. Expected values: Eligible, Not Eligible. Default = null (all).

    .PARAMETER UsageEligibility
    Optional. Filters to meters with the specified reservation (usage commitment) eligibility. FOCUS classifies a reservation as a usage commitment because you commit to a quantity of usage. Expected values: Eligible, Not Eligible. Default = null (all).

    .DESCRIPTION
    The Get-FinOpsCommitmentDiscountEligibility command returns a pre-computed lookup of which meters are eligible for commitment-based discounts (reservations and savings plans), sourced from the Azure Retail Prices API.

    .EXAMPLE
    Get-FinOpsCommitmentDiscountEligibility -MeterId "00003b45-e996-5b04-b673-a2db710f9237"

    Returns commitment discount eligibility for the specified meter.

    .EXAMPLE
    Get-FinOpsCommitmentDiscountEligibility -UsageEligibility "Eligible"

    Returns all meters eligible for reservations.

    .LINK
    https://aka.ms/ftk/Get-FinOpsCommitmentDiscountEligibility
#>
function Get-FinOpsCommitmentDiscountEligibility()
{
    param(
        [Parameter(Position = 0)]
        [string]
        $MeterId = "*",

        [string]
        $SpendEligibility = "*",

        [string]
        $UsageEligibility = "*"
    )

    # MeterId is already unique per row in the source data, so no de-duplication is needed here.
    return Get-OpenDataCommitmentDiscountEligibility `
    | Where-Object {
        $_.MeterId -like $MeterId `
            -and $_.x_CommitmentDiscountSpendEligibility -like $SpendEligibility `
            -and $_.x_CommitmentDiscountUsageEligibility -like $UsageEligibility
    } `
    | ForEach-Object {
        [PSCustomObject]@{
            MeterId          = $_.MeterId
            SpendEligibility = $_.x_CommitmentDiscountSpendEligibility
            UsageEligibility = $_.x_CommitmentDiscountUsageEligibility
        }
    }
}
