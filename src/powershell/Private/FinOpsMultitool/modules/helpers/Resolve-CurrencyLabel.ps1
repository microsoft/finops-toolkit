# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by input and is not a declared contract.')]
param()

###########################################################################
# RESOLVE-CURRENCYLABEL.PS1
# MIXED-CURRENCY DETECTION FOR COST AGGREGATION
###########################################################################
# Purpose: Track the currencies seen while summing cost rows and label the
#          total honestly when more than one appears.
# Date: Created for FinOps Multitool
#
# Description:
# A tenant can bill different subscriptions in different currencies. Summing
# those rows produces a number that means nothing, and labelling it with
# whichever row happened to come last makes the result look authoritative.
# Callers add each row's currency, then ask for a label: a single currency
# is reported as-is, several are reported as 'Mixed'.
#
# ── Functions ───────────────────────────────────────────────────
# Add-CurrencySeen       Record one row's currency
# Resolve-CurrencyLabel  Currency code, or 'Mixed' when several were seen
# Test-CurrencyMixed     True when the total spans more than one currency
###########################################################################

function Add-CurrencySeen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Seen,

        [Parameter()]
        [string]$Currency
    )
    if (-not [string]::IsNullOrWhiteSpace($Currency)) {
        $Seen[$Currency.Trim().ToUpperInvariant()] = $true
    }
}

function Resolve-CurrencyLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Seen,

        [Parameter()]
        [string]$Fallback = 'USD'
    )
    $keys = @($Seen.Keys)
    if ($keys.Count -eq 0) { return $Fallback }
    if ($keys.Count -eq 1) { return [string]$keys[0] }
    return 'Mixed'
}

function Test-CurrencyMixed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Seen
    )
    return (@($Seen.Keys).Count -gt 1)
}

function Measure-FinOpsSavingsEstimate {
    param([AllowEmptyCollection()][object[]]$Recommendations)

    $currencies = @{}
    $total = 0.0
    $count = 0
    foreach ($recommendation in $Recommendations) {
        if ($null -eq $recommendation.AnnualSavings) { continue }
        $currency = ([string]$recommendation.Currency).Trim().ToUpperInvariant()
        if ($currency -notmatch '^[A-Z]{3}$' -or $currency -in @('XXX', 'XTS')) {
            return @{ Total = $null; Currency = 'Unknown'; CostIssue = 'Savings currency is missing or invalid; the combined estimate is unavailable.' }
        }
        Add-CurrencySeen -Seen $currencies -Currency $currency
        if (Test-CurrencyMixed -Seen $currencies) {
            return @{ Total = $null; Currency = 'Mixed'; CostIssue = 'Savings in different currencies cannot be combined.' }
        }
        try { $total += Get-HubCostValue -Row $recommendation -Column 'AnnualSavings' }
        catch { return @{ Total = $null; Currency = $currency; CostIssue = 'A savings amount is invalid; the combined estimate is unavailable.' } }
        $count++
    }
    return @{
        Total     = if ($count -gt 0) { [math]::Round($total, 2) } else { $null }
        Currency  = Resolve-CurrencyLabel -Seen $currencies -Fallback 'Unknown'
        CostIssue = $null
    }
}
