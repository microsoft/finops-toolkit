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
    $inferredFriendly  = $null

    # -- Step 1: Detect agreement type from subscription quotaId ---------
    # QuotaId is always scoped to the correct tenant when using passed subs
    $subsToCheck = if ($Subscriptions) { @($Subscriptions | Select-Object -First 3) } else { @() }
    if ($subsToCheck.Count -eq 0) {
        try { $subsToCheck = @(Get-AzSubscription -ErrorAction SilentlyContinue | Select-Object -First 3) } catch { }
    }

    foreach ($sub in $subsToCheck) {
        try {
            $subPath = "/subscriptions/$($sub.Id)?api-version=2022-12-01"
            $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method GET
            if ($subResp.StatusCode -eq 200) {
                $subDetail = ($subResp.Content | ConvertFrom-Json)
                $quotaId = $subDetail.properties.subscriptionPolicies.quotaId

                $mapped = switch -Regex ($quotaId) {
                    'EnterpriseAgreement'       { @{ Agreement = 'EnterpriseAgreement'; Friendly = 'Enterprise Agreement (EA)' } }
                    'MCSFree|MSDN|Visual'       { @{ Agreement = 'MSDN'; Friendly = 'Visual Studio / MSDN' } }
                    'PayAsYouGo|PAYG'           { @{ Agreement = 'MicrosoftOnlineServicesProgram'; Friendly = 'Pay-As-You-Go (PAYGO)' } }
                    'Sponsored'                 { @{ Agreement = 'Sponsored'; Friendly = 'Azure Sponsored' } }
                    'CSP'                       { @{ Agreement = 'MicrosoftPartnerAgreement'; Friendly = 'CSP / Partner Agreement' } }
                    'Internal'                  { @{ Agreement = 'Internal'; Friendly = 'Microsoft Internal' } }
                    'MCA'                       { @{ Agreement = 'MicrosoftCustomerAgreement'; Friendly = 'Microsoft Customer Agreement (MCA)' } }
                    'FreeTrial'                 { @{ Agreement = 'FreeTrial'; Friendly = 'Free Trial' } }
                    'AAD'                       { @{ Agreement = 'AAD'; Friendly = 'Azure AD Subscription' } }
                    'MSAZR'                     { @{ Agreement = 'MicrosoftOnlineServicesProgram'; Friendly = 'Pay-As-You-Go (PAYGO)' } }
                    default                     { @{ Agreement = $quotaId; Friendly = $quotaId } }
                }

                if ($mapped) {
                    $inferredAgreement = $mapped.Agreement
                    $inferredFriendly  = $mapped.Friendly
                    Write-Host "  QuotaId detected: $quotaId -> $inferredFriendly" -ForegroundColor Green
                    break
                }
            }
        } catch { }
    }

    # -- Step 2: Try billing accounts API, filtered by inferred type -----
    try {
        $response = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01" -Method GET
        if (-not $response -or -not $response.Content) { throw "Billing accounts API returned no content (HTTP $($response.StatusCode))" }
        $result = ($response.Content | ConvertFrom-Json)

        if ($result.value -and $result.value.Count -gt 0) {
            $matchedAccount = $null

            # If multiple billing accounts and we know the agreement type, filter
            if ($inferredAgreement -and $result.value.Count -gt 1) {
                $matchedAccount = $result.value | Where-Object {
                    $_.properties.agreementType -eq $inferredAgreement
                } | Select-Object -First 1
            }
            if (-not $matchedAccount) {
                # If only one account or no match, use first
                $matchedAccount = $result.value | Select-Object -First 1
            }

            $props = $matchedAccount.properties
            $friendlyType = switch ($props.agreementType) {
                'EnterpriseAgreement'            { 'Enterprise Agreement (EA)' }
                'MicrosoftCustomerAgreement'     { 'Microsoft Customer Agreement (MCA)' }
                'MicrosoftOnlineServicesProgram'  { 'Pay-As-You-Go (PAYGO)' }
                'MicrosoftPartnerAgreement'       { 'CSP / Partner Agreement (MPA)' }
                default                           { $props.agreementType }
            }

            return @([PSCustomObject]@{
                AccountName   = $props.displayName
                AccountId     = $matchedAccount.name
                AgreementType = $props.agreementType
                FriendlyType  = $friendlyType
                AccountStatus = $props.accountStatus
                Currency      = if ($props.soldTo) { $props.soldTo.country } else { 'Unknown' }
            })
        }
    } catch {
        Write-Warning "Billing account query failed: $($_.Exception.Message)"
    }

    # -- Step 3: Return quotaId-based inference if billing API failed ----
    if ($inferredAgreement) {
        $subName = if ($subsToCheck.Count -gt 0) { $subsToCheck[0].Name } else { 'Unknown' }
        return @([PSCustomObject]@{
            AccountName   = "Inferred from subscription: $subName"
            AccountId     = if ($subsToCheck.Count -gt 0) { $subsToCheck[0].Id } else { '' }
            AgreementType = $inferredAgreement
            FriendlyType  = $inferredFriendly
            AccountStatus = 'Active'
            Currency      = 'Unknown'
        })
    }

    return @([PSCustomObject]@{
        AccountName   = 'Unknown'
        AgreementType = 'Unknown'
        FriendlyType  = 'Could not detect (assign Billing Reader for accurate detection)'
    })
}
