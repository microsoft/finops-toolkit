# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
param()

###########################################################################
# GET-CONTRACTINFO.PS1
# AZURE FINOPS MULTITOOL - Billing Account & Contract Type Detection
###########################################################################
# Purpose: Detect the customer's Azure contract type (EA, MCA, PAYGO, CSP)
#          and return billing account details.
#
# Contract Types:
#   EnterpriseAgreement              Enterprise Agreement (EA)
#   MicrosoftCustomerAgreement       Microsoft Customer Agreement (MCA)
#   MicrosoftOnlineServicesProgram   Pay-As-You-Go (PAYGO / MOSP)
#   MicrosoftPartnerAgreement        CSP / Partner (MPA)
#
# Reference: https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/view-all-accounts
###########################################################################

function Get-ContractInfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Subscriptions
    )

    $inferredAgreement = $null
    $inferredFriendly = $null
    $probeErrors = [Collections.Generic.List[string]]::new()

    # -- Step 1: Detect agreement type from subscription quotaId ---------
    # QuotaId is always scoped to the correct tenant when using passed subs
    $subsToCheck = if ($Subscriptions) { @($Subscriptions | Select-Object -First 3) } else { @() }
    if ($subsToCheck.Count -eq 0) {
        try { $subsToCheck = @(Get-AzSubscription -ErrorAction Stop | Select-Object -First 3) } catch {
            $probeErrors.Add("Subscription discovery: $($_.Exception.Message)")
            Write-Warning "Contract subscription discovery failed: $($_.Exception.Message)"
        }
    }

    foreach ($sub in $subsToCheck) {
        try {
            $subPath = "/subscriptions/$($sub.Id)?api-version=2022-12-01"
            $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method GET
            if (-not $subResp -or $subResp.StatusCode -ne 200) { throw "Subscription contract probe returned HTTP $($subResp.StatusCode)." }
            if ($subResp.StatusCode -eq 200) {
                $subDetail = ($subResp.Content | ConvertFrom-Json)
                $quotaId = $subDetail.properties.subscriptionPolicies.quotaId

                $mapped = switch -Regex ($quotaId) {
                    'EnterpriseAgreement' { @{ Agreement = 'EnterpriseAgreement'; Friendly = 'Enterprise Agreement (EA)' } }
                    'MCSFree|MSDN|Visual' { @{ Agreement = 'MSDN'; Friendly = 'Visual Studio / MSDN' } }
                    'PayAsYouGo|PAYG' { @{ Agreement = 'MicrosoftOnlineServicesProgram'; Friendly = 'Pay-As-You-Go (PAYGO)' } }
                    'Sponsored' { @{ Agreement = 'Sponsored'; Friendly = 'Azure Sponsored' } }
                    'CSP' { @{ Agreement = 'MicrosoftPartnerAgreement'; Friendly = 'CSP / Partner Agreement' } }
                    'Internal' { @{ Agreement = 'Internal'; Friendly = 'Microsoft Internal' } }
                    'MCA' { @{ Agreement = 'MicrosoftCustomerAgreement'; Friendly = 'Microsoft Customer Agreement (MCA)' } }
                    'FreeTrial' { @{ Agreement = 'FreeTrial'; Friendly = 'Free Trial' } }
                    'AAD' { @{ Agreement = 'AAD'; Friendly = 'Azure AD Subscription' } }
                    'MSAZR' { @{ Agreement = 'MicrosoftOnlineServicesProgram'; Friendly = 'Pay-As-You-Go (PAYGO)' } }
                    default { @{ Agreement = $quotaId; Friendly = $quotaId } }
                }

                if ($mapped) {
                    $inferredAgreement = $mapped.Agreement
                    $inferredFriendly = $mapped.Friendly
                    Write-Host "  QuotaId detected: $quotaId -> $inferredFriendly" -ForegroundColor Green
                    break
                }
            }
        }
        catch {
            $probeErrors.Add("$($sub.Name): $($_.Exception.Message)")
            Write-Warning "Contract probe failed for $($sub.Name): $($_.Exception.Message)"
        }
    }

    # -- Step 2: Try billing accounts API, filtered by inferred type -----
    try {
        $response = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01" -Method GET
        $result = Get-FinOpsListResult -FirstResponse $response -Context 'contract billing accounts'

        if ($result.value -and $result.value.Count -gt 0) {
            $matchedAccount = $null

            if ($result.value.Count -eq 1) {
                # Single billing account in scope - unambiguous.
                $matchedAccount = $result.value[0]
            }
            else {
                # Multiple billing accounts are visible across every tenant the
                # signed-in identity can reach. Picking by agreement type alone
                # can surface an account from an unrelated tenant, so confirm the
                # account actually owns one of the scanned subscriptions before
                # trusting it. Prefer candidates matching the inferred agreement.
                $scanIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($sc in $subsToCheck) { if ($sc.Id) { [void]$scanIds.Add([string]$sc.Id) } }

                $candidates = if ($inferredAgreement) {
                    @($result.value | Where-Object { $_.properties.agreementType -eq $inferredAgreement })
                }
                else { @() }
                if (-not $candidates -or $candidates.Count -eq 0) { $candidates = @($result.value) }

                foreach ($cand in $candidates) {
                    if ($scanIds.Count -eq 0) { break }
                    try {
                        $bsPath = "/providers/Microsoft.Billing/billingAccounts/$($cand.name)/billingSubscriptions?api-version=2024-04-01"
                        $bsResp = Invoke-AzRestMethodWithRetry -Path $bsPath -Method GET
                        $bsData = Get-FinOpsListResult -FirstResponse $bsResp -Context "billing membership for $($cand.name)"
                        if ($bsResp -and $bsResp.StatusCode -eq 200 -and $bsResp.Content) {
                            $owns = $false
                            foreach ($bs in @($bsData.value)) {
                                $bsSubId = if ($bs.properties.subscriptionId) { [string]$bs.properties.subscriptionId } else { [string]$bs.name }
                                if ($scanIds.Contains($bsSubId)) { $owns = $true; break }
                            }
                            if ($owns) { $matchedAccount = $cand; break }
                        }
                    }
                    catch {
                        $probeErrors.Add("$($cand.name): $($_.Exception.Message)")
                        Write-Warning "Contract billing membership probe failed for $($cand.name): $($_.Exception.Message)"
                    }
                }
                # No account could be confirmed to own the scanned subscription -
                # fall through to the subscription-accurate quotaId inference.
            }

            if (-not $matchedAccount) { throw "No billing account confirmed for the scanned subscription" }

            $props = $matchedAccount.properties
            $friendlyType = switch ($props.agreementType) {
                'EnterpriseAgreement' { 'Enterprise Agreement (EA)' }
                'MicrosoftCustomerAgreement' { 'Microsoft Customer Agreement (MCA)' }
                'MicrosoftOnlineServicesProgram' { 'Pay-As-You-Go (PAYGO)' }
                'MicrosoftPartnerAgreement' { 'CSP / Partner Agreement (MPA)' }
                default { $props.agreementType }
            }

            return @([PSCustomObject]@{
                    AccountName        = $props.displayName
                    AccountId          = $matchedAccount.name
                    AgreementType      = $props.agreementType
                    FriendlyType       = $friendlyType
                    AccountStatus      = $props.accountStatus
                    CoverageIncomplete = ($probeErrors.Count -gt 0)
                    ReadErrors         = @($probeErrors)
                    Note               = if ($probeErrors.Count -gt 0) { 'Some contract probes failed. ' + ($probeErrors -join ' ') } else { $null }
                    # soldTo is a billing mailing address, so this is a country, not a currency.
                    SoldToCountry      = if ($props.soldTo) { $props.soldTo.country } else { 'Unknown' }
                })
        }
    }
    catch {
        $probeErrors.Add($_.Exception.Message)
        Write-Warning "Billing account query failed: $($_.Exception.Message)"
    }

    # -- Step 3: Return quotaId-based inference if billing API failed ----
    if ($inferredAgreement) {
        $subName = if ($subsToCheck.Count -gt 0) { $subsToCheck[0].Name } else { 'Unknown' }
        return @([PSCustomObject]@{
                AccountName        = "Inferred from subscription: $subName"
                AccountId          = if ($subsToCheck.Count -gt 0) { $subsToCheck[0].Id } else { '' }
                AgreementType      = $inferredAgreement
                FriendlyType       = $inferredFriendly
                AccountStatus      = 'Active'
                Currency           = 'Unknown'
                CoverageIncomplete = ($probeErrors.Count -gt 0)
                ReadErrors         = @($probeErrors)
                Note               = 'Agreement inferred from subscription metadata, not confirmed billing-account details. ' + ($probeErrors -join ' ')
            })
    }

    return @([PSCustomObject]@{
            AccountName        = 'Unknown'
            AgreementType      = 'Unknown'
            FriendlyType       = 'Could not confirm the agreement type'
            CoverageIncomplete = ($probeErrors.Count -gt 0)
            ReadErrors         = @($probeErrors)
            Note               = if ($probeErrors.Count -gt 0) { 'Contract discovery is incomplete. ' + ($probeErrors -join ' ') } else { 'No agreement was identified from the readable metadata.' }
        })
}
