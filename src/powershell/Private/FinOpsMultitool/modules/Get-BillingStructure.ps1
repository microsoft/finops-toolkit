###########################################################################
# GET-BILLINGSTRUCTURE.PS1
# AZURE FINOPS MULTITOOL - Billing Profiles, Invoice Sections & Cost Allocation
###########################################################################
# Purpose: Retrieve billing account structure (profiles, invoice sections)
#          and any configured cost allocation rules. Requires Billing Reader
#          on the billing account for full data; falls back gracefully.
###########################################################################

function Get-BillingStructure {
    [CmdletBinding()]
    param(
        [object[]]$Subscriptions
    )

    Write-Host "  Querying billing structure..." -ForegroundColor Cyan

    $billingAccounts = @()
    $billingProfiles = @()
    $invoiceSections = @()
    $costAllocationRules = @()

    # -- Resolve billing account IDs linked to scanned subscriptions -----
    # Query ALL scanned subscriptions (not just 5) to build a complete set
    # of billing accounts that belong to this tenant/scan scope.
    $tenantBillingAccountNames = @{}
    if ($Subscriptions) {
        foreach ($sub in $Subscriptions) {
            try {
                $biPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Billing/billingInfo/default?api-version=2024-04-01"
                $biResp = Invoke-AzRestMethodWithRetry -Path $biPath -Method GET
                if ($biResp.StatusCode -eq 200) {
                    $biResult = ($biResp.Content | ConvertFrom-Json)
                    $baId = $biResult.properties.billingAccountId
                    if ($baId) {
                        # Normalize: extract the account name portion after /billingAccounts/
                        $baName = ($baId -replace '(?i).*/billingAccounts/', '').Trim('/')
                        if ($baName) { $tenantBillingAccountNames[$baName] = $true }
                    }
                }
            } catch { }
        }
        Write-Host "  Resolved $($tenantBillingAccountNames.Count) billing account(s) linked to scanned subscriptions." -ForegroundColor Cyan
    }

    # -- Step 1: Get Billing Accounts -----------------------------------
    try {
        $baPath = "/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01"
        $baResp = Invoke-AzRestMethodWithRetry -Path $baPath -Method GET
        if ($baResp.StatusCode -eq 200) {
            $baResult = ($baResp.Content | ConvertFrom-Json)
            if ($baResult.value) {
                foreach ($ba in $baResult.value) {
                    # Filter to billing accounts associated with scanned subscriptions
                    if ($tenantBillingAccountNames.Count -gt 0 -and -not $tenantBillingAccountNames.ContainsKey($ba.name)) {
                        continue
                    }
                    # If no billing account names resolved at all, skip rather than showing everything
                    if ($tenantBillingAccountNames.Count -eq 0) {
                        Write-Warning "  Could not resolve any billing account IDs from subscriptions — skipping billing account: $($ba.properties.displayName)"
                        continue
                    }
                    $props = $ba.properties
                    $billingAccounts += [PSCustomObject]@{
                        AccountId     = $ba.name
                        DisplayName   = $props.displayName
                        AgreementType = $props.agreementType
                        AccountType   = $props.accountType
                        AccountStatus = $props.accountStatus
                        FullId        = $ba.id
                    }
                }
            }
        } else {
            Write-Warning "  Billing accounts returned HTTP $($baResp.StatusCode)"
        }
    } catch {
        Write-Warning "  Billing accounts query failed: $($_.Exception.Message)"
    }

    # -- Step 2: Get Billing Profiles (MCA only) ------------------------
    foreach ($ba in $billingAccounts) {
        if ($ba.AgreementType -notin @('MicrosoftCustomerAgreement', 'MicrosoftPartnerAgreement')) {
            continue
        }
        try {
            $bpPath = "$($ba.FullId)/billingProfiles?api-version=2024-04-01"
            $bpResp = Invoke-AzRestMethodWithRetry -Path $bpPath -Method GET
            if ($bpResp.StatusCode -eq 200) {
                $bpResult = ($bpResp.Content | ConvertFrom-Json)
                if ($bpResult.value) {
                    foreach ($bp in $bpResult.value) {
                        $bpProps = $bp.properties
                        $billingProfiles += [PSCustomObject]@{
                            ProfileId       = $bp.name
                            DisplayName     = $bpProps.displayName
                            BillingAccount  = $ba.DisplayName
                            Currency        = $bpProps.currency
                            InvoiceDay      = $bpProps.invoiceDay
                            Status          = $bpProps.status
                            FullId          = $bp.id
                        }

                        # -- Step 3: Invoice Sections per Profile -------
                        try {
                            $isPath = "$($bp.id)/invoiceSections?api-version=2024-04-01"
                            $isResp = Invoke-AzRestMethodWithRetry -Path $isPath -Method GET
                            if ($isResp.StatusCode -eq 200) {
                                $isResult = ($isResp.Content | ConvertFrom-Json)
                                if ($isResult.value) {
                                    foreach ($section in $isResult.value) {
                                        $sProps = $section.properties
                                        $invoiceSections += [PSCustomObject]@{
                                            SectionId      = $section.name
                                            DisplayName    = $sProps.displayName
                                            BillingProfile = $bpProps.displayName
                                            BillingAccount = $ba.DisplayName
                                            State          = $sProps.state
                                            SystemId       = $sProps.systemId
                                            FullId         = $section.id
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-Warning "  Invoice sections query failed for profile $($bpProps.displayName): $($_.Exception.Message)"
                        }
                    }
                }
            }
        } catch {
            Write-Warning "  Billing profiles query failed: $($_.Exception.Message)"
        }
    }

    # -- Step 4: EA Departments & Enrollment Accounts (EA only) ---------
    $eaDepartments = @()
    foreach ($ba in $billingAccounts) {
        if ($ba.AgreementType -ne 'EnterpriseAgreement') { continue }
        try {
            $deptPath = "$($ba.FullId)/departments?api-version=2024-04-01"
            $deptResp = Invoke-AzRestMethodWithRetry -Path $deptPath -Method GET
            if ($deptResp.StatusCode -eq 200) {
                $deptResult = ($deptResp.Content | ConvertFrom-Json)
                if ($deptResult.value) {
                    foreach ($dept in $deptResult.value) {
                        $dProps = $dept.properties
                        $eaDepartments += [PSCustomObject]@{
                            DepartmentId   = $dept.name
                            DisplayName    = $dProps.displayName
                            BillingAccount = $ba.DisplayName
                            CostCenter     = $dProps.costCenter
                            Status         = $dProps.status
                        }
                    }
                }
            }
        } catch {
            Write-Warning "  EA departments query failed: $($_.Exception.Message)"
        }
    }

    # -- Step 5: Cost Allocation Rules ----------------------------------
    foreach ($ba in $billingAccounts) {
        try {
            $carPath = "$($ba.FullId)/providers/Microsoft.CostManagement/costAllocationRules?api-version=2023-11-01"
            $carResp = Invoke-AzRestMethodWithRetry -Path $carPath -Method GET
            if ($carResp.StatusCode -eq 200) {
                $carResult = ($carResp.Content | ConvertFrom-Json)
                if ($carResult.value) {
                    foreach ($rule in $carResult.value) {
                        $rProps = $rule.properties
                        $costAllocationRules += [PSCustomObject]@{
                            RuleName        = $rProps.name
                            Description     = $rProps.description
                            Status          = $rProps.status
                            BillingAccount  = $ba.DisplayName
                            SourceCount     = if ($rProps.details.sourceResources) { $rProps.details.sourceResources.Count } else { 0 }
                            TargetCount     = if ($rProps.details.targetResources) { $rProps.details.targetResources.Count } else { 0 }
                            CreatedDate     = $rProps.createdDate
                            UpdatedDate     = $rProps.updatedDate
                        }
                    }
                }
            } elseif ($carResp.StatusCode -ne 404) {
                Write-Warning "  Cost allocation rules returned HTTP $($carResp.StatusCode)"
            }
        } catch {
            Write-Warning "  Cost allocation rules query failed: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        BillingAccounts     = $billingAccounts
        BillingProfiles     = $billingProfiles
        InvoiceSections     = $invoiceSections
        EADepartments       = $eaDepartments
        CostAllocationRules = $costAllocationRules
        HasBillingAccess    = ($billingAccounts.Count -gt 0)
    }
}
