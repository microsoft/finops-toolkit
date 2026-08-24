# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# RESOLVE-BILLINGSCOPE.PS1
# CORRELATE BILLING ACCOUNTS TO THE SCANNED SUBSCRIPTIONS
###########################################################################
# Purpose: Return only the billing accounts that actually own one of the
#          scanned subscriptions, so account-scoped scans do not mix in
#          commitments and enrollments from unrelated accounts.
# Author: Zac Larsen
#
# Description:
# Enumerating /providers/Microsoft.Billing/billingAccounts returns every
# account the caller can read, which on a multi-enrollment tenant is wider
# than the scan scope. This correlates each candidate through its
# billingSubscriptions collection, the same approach Get-ContractInfo uses.
#
# The subscription-scoped billingProperty/default endpoint is tried first
# because it is a single call per subscription. Note that billingInfo/default
# is NOT a valid resource type and returns 404 on every api-version, so it is
# deliberately not used here.
#
# ── Parameters ──────────────────────────────────────────────────
# BillingAccounts    Account objects from the billingAccounts list call
# Subscriptions      Scanned subscriptions; each needs an Id property
#
# Returns: PSCustomObject with Accounts (the in-scope subset), Resolved
#          (whether correlation produced an answer), and Reason.
#
# Usage: $scope = Get-FinOpsBillingScope -BillingAccounts $accts -Subscriptions $subs
###########################################################################

function Get-FinOpsBillingScope {
    param(
        [object[]]$BillingAccounts,
        [object[]]$Subscriptions
    )

    $out = [PSCustomObject]@{
        Accounts = @()
        Resolved = $false
        Reason   = $null
    }

    $accounts = @($BillingAccounts | Where-Object { $_ })
    if ($accounts.Count -eq 0) {
        $out.Reason = 'No billing accounts were returned by the billing accounts list.'
        return $out
    }

    $scanIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in @($Subscriptions)) {
        if ($s -and $s.Id) { [void]$scanIds.Add([string]$s.Id) }
    }

    # Nothing to correlate against, so the caller's own scoping already applies.
    if ($scanIds.Count -eq 0) {
        $out.Accounts = $accounts
        $out.Resolved = $true
        $out.Reason = 'No subscription scope supplied; returning all reachable billing accounts.'
        return $out
    }

    $matched = [System.Collections.Generic.List[object]]::new()
    $anyReadable = $false

    # Pass 1: ask each subscription which billing account owns it.
    $ownerNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in @($Subscriptions)) {
        if (-not $s -or -not $s.Id) { continue }
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path "/subscriptions/$($s.Id)/providers/Microsoft.Billing/billingProperty/default?api-version=2024-04-01" -Method GET
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $anyReadable = $true
                $baId = ($resp.Content | ConvertFrom-Json).properties.billingAccountId
                if ($baId) {
                    $name = ($baId -replace '(?i).*/billingAccounts/', '').Trim('/')
                    if ($name) { [void]$ownerNames.Add($name) }
                }
            }
        }
        catch { }
    }

    foreach ($ba in $accounts) {
        $name = if ($ba.PSObject.Properties['Name'] -and $ba.Name) { [string]$ba.Name } else { [string]$ba.name }
        if ($name -and $ownerNames.Contains($name)) { $matched.Add($ba) }
    }

    # Pass 2: walk each account's subscriptions. Covers enrollments where the
    # subscription-scoped lookup is not readable but the account is.
    if ($matched.Count -eq 0) {
        foreach ($ba in $accounts) {
            $name = if ($ba.PSObject.Properties['Name'] -and $ba.Name) { [string]$ba.Name } else { [string]$ba.name }
            if (-not $name) { continue }
            try {
                $resp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.Billing/billingAccounts/$name/billingSubscriptions?api-version=2024-04-01" -Method GET
                if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                    $anyReadable = $true
                    foreach ($bs in @(($resp.Content | ConvertFrom-Json).value)) {
                        $id = if ($bs.properties.subscriptionId) { [string]$bs.properties.subscriptionId } else { [string]$bs.name }
                        if ($id -and $scanIds.Contains($id)) { $matched.Add($ba); break }
                    }
                }
            }
            catch { }
        }
    }

    if ($matched.Count -gt 0) {
        $out.Accounts = @($matched)
        $out.Resolved = $true
        return $out
    }

    # Correlation failed. Distinguish "read it, found no link" from "could not read
    # it", because the second is a permissions problem the user can act on.
    $out.Reason = if ($anyReadable) {
        'No reachable billing account owns any of the scanned subscriptions.'
    }
    else {
        'Could not read billing account membership. Billing Account Reader, or Enterprise Administrator (reader) on an EA, is required to correlate accounts to subscriptions.'
    }
    return $out
}
