# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-BILLINGACCOUNT.PS1
# DISCOVER BILLING ACCOUNTS + COST ALLOCATION ELIGIBILITY
###########################################################################
# Purpose: Read-only lookup of billing accounts you can see, their agreement
#          type, whether they support cost allocation rules, and whether you
#          can reach the rules endpoint (Cost Management Contributor signal).
# Date: Created for FinOps Multitool shared-cost allocation
#
# Description:
# Lists Microsoft.Billing billing accounts visible to the signed-in identity
# and, for each, reports:
# 1. Billing account id (the path segment set_cost_allocation_rule needs)
# 2. Agreement type (EA / MCA / MPA / MOSA)
# 3. Eligibility - cost allocation rules require EA or MCA
# 4. Optional access probe - GETs the costAllocationRules endpoint so you
#    learn before an apply whether you have read access there (a 403 means
#    you lack Cost Management Contributor at that scope)
#
# This tool is READ-ONLY. It never writes or changes anything in Azure.
#
# ── Parameters ──────────────────────────────────────────────────
# BillingAccountId   Optional filter - return only this billing account
# ProbeAccess        When true (default), probe the rules endpoint per account
#
# Prerequisites:
# - Az.Accounts connected (Connect-AzAccount). Billing Reader is enough to list.
#
# Usage: Get-BillingAccount
###########################################################################

function Get-BillingAccount {
    param(
        [Parameter()]
        [string]$BillingAccountId,

        [Parameter()]
        [bool]$ProbeAccess = $true
    )

    $billingApi = '2020-05-01'
    $ruleApi = '2025-03-01'

    Write-Host '  Listing billing accounts...' -ForegroundColor Cyan
    $listPath = "/providers/Microsoft.Billing/billingAccounts?api-version=$billingApi"
    $resp = Invoke-AzRestMethodWithRetry -Path $listPath -Method 'GET'

    $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
    if ($status -ne 200) {
        $msg = "Could not list billing accounts (HTTP $status)."
        if ($resp -and $resp.Content) {
            try { $e = $resp.Content | ConvertFrom-Json -ErrorAction Stop; if ($e.error.message) { $msg += " $($e.error.message)" } } catch { }
        }
        return [PSCustomObject]@{
            HasData  = $false
            Accounts = @()
            Note     = "$msg Ensure you are signed in (Connect-AzAccount) and have at least Billing Reader."
        }
    }

    $payload = $null
    try { $payload = $resp.Content | ConvertFrom-Json -ErrorAction Stop } catch { }
    $raw = @()
    if ($payload -and $payload.value) { $raw = @($payload.value) }

    if ($BillingAccountId) {
        $raw = @($raw | Where-Object { $_.name -eq $BillingAccountId })
    }

    if ($raw.Count -eq 0) {
        return [PSCustomObject]@{
            HasData  = $false
            Accounts = @()
            Note     = if ($BillingAccountId) { "No billing account named '$BillingAccountId' is visible to this identity." } else { 'No billing accounts are visible to this identity.' }
        }
    }

    $eligibleTypes = @('EnterpriseAgreement', 'MicrosoftCustomerAgreement')
    $accounts = @()

    foreach ($ba in $raw) {
        $name = [string]$ba.name
        $agreement = [string]$ba.properties.agreementType
        $eligible = $eligibleTypes -contains $agreement

        $eligNote = switch ($agreement) {
            'EnterpriseAgreement' { 'Supported (EA enrollment).' }
            'MicrosoftCustomerAgreement' { 'Supported (MCA).' }
            'MicrosoftPartnerAgreement' { 'Not supported - CSP/partner agreements cannot use cost allocation rules.' }
            'MicrosoftOnlineServicesProgram' { 'Not supported - pay-as-you-go / MOSA cannot use cost allocation rules.' }
            default { "Unknown agreement type '$agreement' - verify cost allocation support." }
        }

        $access = $null
        if ($ProbeAccess -and $eligible) {
            $probePath = "/providers/Microsoft.Billing/billingAccounts/$name/providers/Microsoft.CostManagement/costAllocationRules?api-version=$ruleApi"
            $pr = Invoke-AzRestMethodWithRetry -Path $probePath -Method 'GET'
            $ps = if ($pr) { [int]$pr.StatusCode } else { 0 }
            $access = switch ($ps) {
                200 { 'Ok - you can read cost allocation rules here (write needs Cost Management Contributor).' }
                403 { 'Forbidden - you lack access at this scope. Cost Management Contributor is required to write rules.' }
                404 { 'Not found - the cost allocation provider is not enabled or the account does not expose it.' }
                default { "HTTP $ps when reading the rules endpoint." }
            }
        }

        $accounts += [PSCustomObject]@{
            Id              = $name
            DisplayName     = [string]$ba.properties.displayName
            AgreementType   = $agreement
            AccountStatus   = [string]$ba.properties.accountStatus
            Eligible        = $eligible
            EligibilityNote = $eligNote
            RulesAccess     = $access
        }
    }

    $hasNext = if ($payload.PSObject.Properties['nextLink'] -and $payload.nextLink) { $true } else { $false }
    $note = 'Use Id as billingAccountId in set_cost_allocation_rule. Only Eligible=true accounts (EA/MCA) support cost allocation rules.'
    if ($hasNext) { $note += ' More accounts exist beyond this page (nextLink present).' }

    return [PSCustomObject]@{
        HasData  = $true
        Accounts = @($accounts | Sort-Object -Property @{ Expression = 'Eligible'; Descending = $true }, 'DisplayName')
        Note     = $note
    }
}
