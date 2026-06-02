###########################################################################
# GET-MACCCOMMITMENT.PS1
# AZURE FINOPS MULTITOOL - MACC Consumption Commitment Tracking
###########################################################################
# Purpose: Read the customer's Microsoft Azure Consumption Commitment (MACC)
#          and return a minimal readout: commitment, consumed, remaining,
#          % burned, and status for the current agreement period.
#
# Description:
# Queries the Consumption Lots API at billing-account scope and filters for
# lots whose source is 'ConsumptionCommitment' (the MACC):
# 1. Discover reachable billing accounts and their agreement type
# 2. For EA / MCA accounts, list consumption lots
# 3. Keep MACC lots and compute commitment / consumed / remaining / % / status
#
# ── Parameters ──────────────────────────────────────────────────
# Subscriptions      Subscriptions in scope (used only to bound discovery)
# AgreementType      Detected agreement type from Get-ContractInfo
#
# Notes:
# - The lots API is supported for Microsoft Customer Agreement (MCA) and
#   Direct Enterprise Agreement (EA) only. PAYGO / CSP / MSDN return nothing.
# - Requires a billing role (Billing Account Reader / EA Reader) on the
#   billing account. Standard subscription RBAC does not grant access.
#
# Reference: https://learn.microsoft.com/en-us/rest/api/consumption/lots/list-by-billing-account
###########################################################################

function Get-MaccCommitment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$AgreementType
    )

    Write-Host "  Querying MACC consumption commitment..." -ForegroundColor Cyan

    # -- Result shape (single source of truth) --------------------------
    $result = [PSCustomObject]@{
        HasMacc     = $false
        Applicable  = $true
        Reason      = ''
        Commitments = @()
    }

    # -- Step 0: Gate on agreement type ---------------------------------
    # The lots API only returns data for MCA and Direct EA billing accounts.
    if ($AgreementType -and $AgreementType -notin @('EnterpriseAgreement', 'MicrosoftCustomerAgreement')) {
        $result.Applicable = $false
        $result.Reason = "MACC tracking applies to Enterprise Agreement (EA) and Microsoft Customer Agreement (MCA) only. Detected agreement type: $AgreementType."
        Write-Host "  MACC not applicable for agreement type '$AgreementType'." -ForegroundColor DarkGray
        return $result
    }

    # -- Step 1: Discover reachable billing accounts --------------------
    $billingAccounts = @()
    try {
        $resp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01" -Method GET
        if ($resp.StatusCode -eq 200) {
            $parsed = ($resp.Content | ConvertFrom-Json)
            foreach ($a in $parsed.value) {
                if ($a.properties.agreementType -in @('EnterpriseAgreement', 'MicrosoftCustomerAgreement')) {
                    $billingAccounts += [PSCustomObject]@{
                        Name        = $a.name
                        DisplayName = $a.properties.displayName
                        Agreement   = $a.properties.agreementType
                    }
                }
            }
        }
    } catch {
        $result.Reason = "Could not list billing accounts: $($_.Exception.Message)"
        Write-Warning "  MACC: $($result.Reason)"
        return $result
    }

    if ($billingAccounts.Count -eq 0) {
        $result.Reason = 'No EA/MCA billing account is reachable. Assign a billing role (Billing Account Reader or EA Reader) to view MACC data.'
        Write-Host "  MACC: no reachable EA/MCA billing account." -ForegroundColor DarkGray
        return $result
    }

    # -- Step 2: List MACC lots per billing account ---------------------
    $lots = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($ba in $billingAccounts) {
        $lotPath = "/providers/Microsoft.Billing/billingAccounts/$($ba.Name)/providers/Microsoft.Consumption/lots?api-version=2024-08-01"
        try {
            $lotResp = Invoke-AzRestMethodWithRetry -Path $lotPath -Method GET
            if ($lotResp.StatusCode -ne 200) {
                # 404 simply means no lots exist for this account — not an error.
                continue
            }
            $lotData = ($lotResp.Content | ConvertFrom-Json)
            foreach ($lot in $lotData.value) {
                $p = $lot.properties
                if ("$($p.source)" -ne 'ConsumptionCommitment') { continue }

                $currency  = if ($p.billingCurrency) { $p.billingCurrency } elseif ($p.originalAmount.currency) { $p.originalAmount.currency } else { 'USD' }
                $original  = if ($null -ne $p.originalAmount.value) { [double]$p.originalAmount.value } else { 0 }
                $used      = if ($null -ne $p.usedAmount.value) { [double]$p.usedAmount.value } else { 0 }

                # Remaining: prefer original - used; fall back to closedBalance.
                $remaining = if ($original -gt 0) { [math]::Round($original - $used, 2) }
                             elseif ($null -ne $p.closedBalance.value) { [double]$p.closedBalance.value }
                             else { 0 }

                $pctUsed = if ($original -gt 0) { [math]::Round(($used / $original) * 100, 1) } else { 0 }

                $lots.Add([PSCustomObject]@{
                    BillingAccount = $ba.DisplayName
                    Agreement      = $ba.Agreement
                    Currency       = $currency
                    Commitment     = [math]::Round($original, 2)
                    Consumed       = [math]::Round($used, 2)
                    Remaining      = $remaining
                    PctUsed        = $pctUsed
                    Status         = if ($p.status) { $p.status } else { 'Unknown' }
                    StartDate      = if ($p.startDate) { ([datetime]$p.startDate).ToString('yyyy-MM-dd') } else { '' }
                    ExpirationDate = if ($p.expirationDate) { ([datetime]$p.expirationDate).ToString('yyyy-MM-dd') } else { '' }
                    Estimated      = [bool]$p.isEstimatedBalance
                })
            }
        } catch {
            Write-Warning "  MACC lot query failed for account $($ba.DisplayName): $($_.Exception.Message)"
        }
    }

    if ($lots.Count -gt 0) {
        $result.HasMacc = $true
        $result.Commitments = @($lots)
        Write-Host "  Found $($lots.Count) MACC commitment lot(s)." -ForegroundColor Green
    } else {
        $result.Reason = 'No MACC commitment found on the reachable EA/MCA billing account(s). This agreement may not include a consumption commitment.'
        Write-Host "  MACC: no consumption-commitment lots found." -ForegroundColor DarkGray
    }

    return $result
}
