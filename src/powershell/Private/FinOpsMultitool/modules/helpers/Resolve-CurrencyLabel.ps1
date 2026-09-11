# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
