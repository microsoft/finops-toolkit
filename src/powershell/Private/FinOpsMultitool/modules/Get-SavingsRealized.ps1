# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Read-only: builds in-memory objects and changes no state.')]
param()

###########################################################################
# GET-SAVINGSREALIZED.PS1
# AZURE FINOPS MULTITOOL - Estimated Savings from Commitments
###########################################################################
# Purpose: Estimate how much existing RIs, Savings Plans, and AHB are saving
#          versus pay-as-you-go. RI and savings plan figures apply an assumed
#          effective discount rate, so they are an estimate rather than
#          measured savings - see EstimateBasis on the result.
###########################################################################

function Get-SavingsRealized {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object]$CommitmentData
    )

    Write-Host "  Estimating savings from commitments..." -ForegroundColor Cyan

    $riSavings = 0
    $spSavings = 0
    $ahbSavings = 0
    $periodEndUtc = (Get-Date).ToUniversalTime()
    $periodStartUtc = $periodEndUtc.Date.AddDays(1 - $periodEndUtc.Day)
    $periodStart = $periodStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $periodEnd = $periodEndUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $period = "$periodStart to $periodEnd"
    $currencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $monetaryCurrencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($culture in [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures)) {
        try {
            $region = [System.Globalization.RegionInfo]::new($culture.Name)
            if ($region.ISOCurrencySymbol -notin @('XXX', 'XTS')) { [void]$monetaryCurrencies.Add($region.ISOCurrencySymbol) }
        }
        catch [System.ArgumentException] { Write-Verbose "No currency metadata for culture $($culture.Name)." }
    }
    $ahbIssue = $null

    # Assumed effective discount versus pay-as-you-go. Real discounts vary by
    # SKU, term, region, and agreement, so the RI/SP numbers below are an
    # estimate rather than measured savings.
    $riDiscountRate = 0.40
    $spDiscountRate = 0.25

    # Savings is the gap up to the PAYG price, not a share of what was paid:
    #   payg    = paid / (1 - d)
    #   savings = payg - paid = paid * d / (1 - d)
    # At a 40% discount, $100 paid implies $66.67 saved, not $40.
    $script:FinOpsRiSavingsFactor = $riDiscountRate / (1 - $riDiscountRate)
    $script:FinOpsSpSavingsFactor = $spDiscountRate / (1 - $spDiscountRate)
    # Amortized cost split by pricing model, used for commitment COVERAGE
    # (how much of eligible spend rides on a commitment) - distinct from the
    # savings amounts above. Spot is excluded from the eligible base because it
    # cannot be covered by a reservation or savings plan.
    $committedAmort = 0.0
    $onDemandAmort = 0.0
    $spotAmort = 0.0
    $details = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -- Short-circuit: skip RI/SP queries if no commitments exist -------
    $hasCommitments = $true
    if ($CommitmentData -and $CommitmentData.PSObject.Properties['HasData']) {
        if (-not $CommitmentData.HasData) {
            $hasCommitments = $false
            Write-Host "  No reservations or savings plans detected — skipping commitment savings queries" -ForegroundColor DarkGray
        }
    }

    $gotMgData = $false
    $subCount = if ($Subscriptions) { $Subscriptions.Count } else { 0 }

    # Map subscription Id -> friendly name so MG-grouped rows keep per-sub attribution
    $subNameById = @{}
    foreach ($s in $Subscriptions) { $subNameById[$s.Id] = $s.Name }

    # Build a Cost Management query body with the requested grouping dimensions
    function New-SavingsQueryBody {
        param([string]$Type, [string[]]$Dimensions)
        $query = @{
            type      = $Type
            timeframe = 'Custom'
            timePeriod = @{ from = $periodStart; to = $periodEnd }
            dataset   = @{
                granularity = 'None'
                aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                grouping    = @($Dimensions | ForEach-Object { @{ type = 'Dimension'; name = $_ } })
            }
        }
        if ($Type -eq 'AmortizedCost') {
            $query.dataset.filter = @{ dimensions = @{ name = 'ChargeType'; operator = 'In'; values = @('Usage') } }
        }
        $query | ConvertTo-Json -Depth 10
    }

    # Resolve named column indices from a Cost Management query result
    function Get-SavingsColMap {
        param($Columns)
        $map = @{ Cost = 0; ChargeType = -1; PricingModel = -1; SubscriptionId = -1; Currency = -1 }
        for ($c = 0; $c -lt $Columns.Count; $c++) {
            switch ($Columns[$c].name) {
                'Cost' { $map.Cost = $c }
                'ChargeType' { $map.ChargeType = $c }
                'PricingModel' { $map.PricingModel = $c }
                'SubscriptionId' { $map.SubscriptionId = $c }
                'Currency' { $map.Currency = $c }
            }
        }
        $map
    }

    function Assert-SavingsCurrency {
        param($Row, $Columns)
        if ($Columns.Currency -lt 0) { throw 'Savings currency is missing; results are incomplete.' }
        $currency = [string]$Row[$Columns.Currency]
        if ($currency -notmatch '^[A-Za-z]{3}$' -or -not $monetaryCurrencies.Contains($currency)) {
            throw 'Savings currency is missing or is not a recognized monetary currency; results are incomplete.'
        }
        $currency = $currency.ToUpperInvariant()
        [void]$currencies.Add($currency)
        if ($currencies.Count -gt 1) { throw 'Savings include multiple billing currencies. Scan each currency separately; no currency conversion is applied.' }
        return $currency
    }

    # Parse an ActualCost result for UnusedReservation waste; returns detail rows
    function Read-SavingsActual {
        param($Result)
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        if (-not $Result -or -not $Result.properties.rows) { return $rows }
        $m = Get-SavingsColMap -Columns $Result.properties.columns
        foreach ($row in $Result.properties.rows) {
            $currency = Assert-SavingsCurrency -Row $row -Columns $m
            $charge = if ($m.ChargeType -ge 0) { [string]$row[$m.ChargeType] } else { '' }
            if ($charge -match 'UnusedReservation') {
                $sub = 'All (MG scope)'
                if ($m.SubscriptionId -ge 0) {
                    $sid = [string]$row[$m.SubscriptionId]
                    $sub = if ($subNameById.ContainsKey($sid)) { $subNameById[$sid] } else { $sid }
                }
                $rows.Add([PSCustomObject]@{
                        Subscription = $sub
                        Category     = 'Unused Reservation'
                        Amount       = [math]::Round([double]$row[$m.Cost], 2)
                        Type         = 'Waste'
                        Currency     = $currency
                        Period       = $period
                    })
            }
        }
        return $rows
    }

    # Parse an AmortizedCost result for RI/SP benefit; returns rows + savings totals
    function Read-SavingsAmort {
        param($Result)
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        $ri = 0.0; $sp = 0.0
        $committed = 0.0; $onDemand = 0.0; $spot = 0.0
        if ($Result -and $Result.properties.rows) {
            $m = Get-SavingsColMap -Columns $Result.properties.columns
            foreach ($row in $Result.properties.rows) {
                $currency = Assert-SavingsCurrency -Row $row -Columns $m
                $pm = if ($m.PricingModel -ge 0) { [string]$row[$m.PricingModel] } else { '' }
                if ([double]$row[$m.Cost] -lt 0) {
                    throw 'Savings usage costs include negative adjustments; a comparable estimate is unavailable.'
                }
                $cost = [math]::Round([double]$row[$m.Cost], 2)
                $sub = 'All (MG scope)'
                if ($m.SubscriptionId -ge 0) {
                    $sid = [string]$row[$m.SubscriptionId]
                    $sub = if ($subNameById.ContainsKey($sid)) { $subNameById[$sid] } else { $sid }
                }
                if ($pm -match 'Reservation') {
                    $ri += $cost * $script:FinOpsRiSavingsFactor
                    $committed += $cost
                    $rows.Add([PSCustomObject]@{ Subscription = $sub; Category = 'Reservation Benefit'; Amount = $cost; Type = 'Commitment'; Currency = $currency; Period = $period })
                }
                elseif ($pm -match 'SavingsPlan') {
                    $sp += $cost * $script:FinOpsSpSavingsFactor
                    $committed += $cost
                    $rows.Add([PSCustomObject]@{ Subscription = $sub; Category = 'Savings Plan Benefit'; Amount = $cost; Type = 'Commitment'; Currency = $currency; Period = $period })
                }
                elseif ($pm -match 'Spot') { $spot += $cost }
                elseif ($pm) { $onDemand += $cost }
            }
        }
        return [PSCustomObject]@{ Rows = $rows; RI = $ri; SP = $sp; Committed = $committed; OnDemand = $onDemand; Spot = $spot }
    }

    if ($hasCommitments -and $subCount -eq 1) {
        # -- Strategy 0: single-subscription fast path (skip MG resolution entirely) --
        $only = $Subscriptions[0]
        try {
            Write-Host "  Calculating savings (single subscription, direct scope)..." -ForegroundColor Cyan
            $subPath = "/subscriptions/$($only.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

            $actualBody = New-SavingsQueryBody -Type 'ActualCost' -Dimensions @('ChargeType')
            $actualResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $actualBody
            if (-not $actualResp -or $actualResp.StatusCode -ne 200) {
                throw "Savings charge query returned HTTP $($actualResp.StatusCode); results are incomplete."
            }
            if ($actualResp.StatusCode -eq 200) {
                $actualResult = Get-CostQueryResult -FirstResponse $actualResp -Payload $actualBody -Context "savings charges for $($only.Name)"
                foreach ($d in (Read-SavingsActual -Result $actualResult)) {
                    $d.Subscription = $only.Name; [void]$details.Add($d)
                }
            }

            $amortBody = New-SavingsQueryBody -Type 'AmortizedCost' -Dimensions @('PricingModel')
            $amortResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $amortBody
            if (-not $amortResp -or $amortResp.StatusCode -ne 200) {
                throw "Savings benefit query returned HTTP $($amortResp.StatusCode); results are incomplete."
            }
            if ($amortResp.StatusCode -eq 200) {
                $amortResult = Get-CostQueryResult -FirstResponse $amortResp -Payload $amortBody -Context "savings benefits for $($only.Name)"
                $parsed = Read-SavingsAmort -Result $amortResult
                foreach ($d in $parsed.Rows) { $d.Subscription = $only.Name; [void]$details.Add($d) }
                $riSavings += $parsed.RI
                $spSavings += $parsed.SP
                $committedAmort += $parsed.Committed
                $onDemandAmort += $parsed.OnDemand
                $spotAmort += $parsed.Spot
            }

            $gotMgData = $true
            Write-Host "  Single-subscription savings calculated" -ForegroundColor Green
        }
        catch {
            throw "Single-subscription savings query failed: $($_.Exception.Message)"
        }
    }
    elseif ($hasCommitments) {
        # -- Strategy 1: MG-scope grouped by SubscriptionId (2 calls, per-sub attribution) --
        $mgScopeId = if ($TenantId) { Resolve-CostMgId -TenantId $TenantId } else { $null }
        if ($mgScopeId) {
            try {
                Write-Host "  Calculating savings (MG scope, grouped by subscription)..." -ForegroundColor Cyan
                $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

                $actualBody = New-SavingsQueryBody -Type 'ActualCost' -Dimensions @('SubscriptionId', 'ChargeType')
                $actualResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $actualBody
                if ($actualResp.StatusCode -in @(401, 403)) {
                    Set-MgCostScopeFailed
                    throw "MG-scope savings query returned HTTP $($actualResp.StatusCode)"
                }
                if (-not $actualResp -or $actualResp.StatusCode -ne 200) {
                    throw "MG-scope savings charge query returned HTTP $($actualResp.StatusCode); results are incomplete."
                }
                if ($actualResp.StatusCode -eq 200) {
                    $actualResult = Get-CostQueryResult -FirstResponse $actualResp -Payload $actualBody -Context 'management-group savings charges'
                    foreach ($d in (Read-SavingsActual -Result $actualResult)) { [void]$details.Add($d) }
                }

                $amortBody = New-SavingsQueryBody -Type 'AmortizedCost' -Dimensions @('SubscriptionId', 'PricingModel')
                $amortResp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $amortBody
                if (-not $amortResp -or $amortResp.StatusCode -ne 200) {
                    throw "MG-scope savings benefit query returned HTTP $($amortResp.StatusCode); results are incomplete."
                }
                if ($amortResp.StatusCode -eq 200) {
                    $amortResult = Get-CostQueryResult -FirstResponse $amortResp -Payload $amortBody -Context 'management-group savings benefits'
                    $parsed = Read-SavingsAmort -Result $amortResult
                    foreach ($d in $parsed.Rows) { [void]$details.Add($d) }
                    $riSavings += $parsed.RI
                    $spSavings += $parsed.SP
                    $committedAmort += $parsed.Committed
                    $onDemandAmort += $parsed.OnDemand
                    $spotAmort += $parsed.Spot
                }

                $gotMgData = $true
                Write-Host "  MG scope savings calculated" -ForegroundColor Green
            }
            catch {
                Write-Warning "  MG-scope savings query failed: $($_.Exception.Message)"
            }
        }
    }

    # -- Strategy 2: Per-subscription fallback (only if MG/direct scope unavailable) --
    if ($hasCommitments -and -not $gotMgData) {
        $details.Clear()
        $currencies.Clear()
        $riSavings = 0.0
        $spSavings = 0.0
        $committedAmort = 0.0
        $onDemandAmort = 0.0
        $spotAmort = 0.0
        $subCount = $Subscriptions.Count
        $i = 0
        foreach ($sub in $Subscriptions) {
            $i++
            if ($subCount -gt 5 -and ($i -eq 1 -or $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Calculating savings ($i/$subCount subs)..."
                }
            }
            try {
                $actualBody = New-SavingsQueryBody -Type 'ActualCost' -Dimensions @('ChargeType')

                $subPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $actualResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $actualBody
                if (-not $actualResp -or $actualResp.StatusCode -ne 200) {
                    throw "Savings charge retry returned HTTP $($actualResp.StatusCode); results are incomplete."
                }

                if ($actualResp.StatusCode -eq 200) {
                    $actualResult = Get-CostQueryResult -FirstResponse $actualResp -Payload $actualBody -Context "savings charges for $($sub.Name)"
                    foreach ($detail in (Read-SavingsActual -Result $actualResult)) {
                        $detail.Subscription = $sub.Name
                        [void]$details.Add($detail)
                    }
                }

                $amortBody = New-SavingsQueryBody -Type 'AmortizedCost' -Dimensions @('PricingModel')

                $amortResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $amortBody
                if (-not $amortResp -or $amortResp.StatusCode -ne 200) {
                    throw "Savings benefit retry returned HTTP $($amortResp.StatusCode); results are incomplete."
                }
                if ($amortResp.StatusCode -eq 200) {
                    $amortResult = Get-CostQueryResult -FirstResponse $amortResp -Payload $amortBody -Context "savings benefits for $($sub.Name)"
                    $parsed = Read-SavingsAmort -Result $amortResult
                    foreach ($detail in $parsed.Rows) {
                        $detail.Subscription = $sub.Name
                        [void]$details.Add($detail)
                    }
                    $riSavings += $parsed.RI
                    $spSavings += $parsed.SP
                    $committedAmort += $parsed.Committed
                    $onDemandAmort += $parsed.OnDemand
                    $spotAmort += $parsed.Spot
                }
            }
            catch {
                throw "Savings query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    } # end per-sub fallback

    # -- Step 2: Separate 730-hour AHB estimate for the current VM inventory ---
    try {
        $ahbQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.licenseType == 'Windows_Server'
| project vmSize = tostring(properties.hardwareProfile.vmSize), location
"@
        $subIds = $Subscriptions | ForEach-Object { $_.Id }
        $ahbResult = Search-AzGraphSafe -Query $ahbQuery -Subscription $subIds -All
        $ahbVMs = if ($ahbResult.Data) { @($ahbResult.Data) } else { @() }
        if ($ahbVMs.Count -gt 0) {
            $ahbSavings = 0
            $haveRates = Get-Command Get-AhbVmRates -ErrorAction SilentlyContinue
            foreach ($vm in $ahbVMs) {
                $perVm = 50  # fallback monthly estimate per VM when live rates are unavailable
                if ($haveRates) {
                    $rates = Get-AhbVmRates -VmSize $vm.vmSize -Region $vm.location
                    if ($rates) { $perVm = [math]::Round($rates.HourlyPremium * 730, 2) }
                }
                $ahbSavings += $perVm
            }
            [void]$details.Add([PSCustomObject]@{
                    Subscription = 'All'
                    Category     = 'Azure Hybrid Benefit (VMs)'
                    Amount       = [math]::Round($ahbSavings, 2)
                    Type         = 'AHB'
                    Currency     = 'USD'
                    Period       = '730-hour estimate for current VM inventory'
                })
        }
    }
    catch {
        $ahbSavings = $null
        $ahbIssue = "AHB estimate is unavailable: $($_.Exception.Message)"
        Write-Warning "  AHB savings query failed: $($_.Exception.Message)"
    }

    $currency = if ($currencies.Count -eq 1) { @($currencies)[0] } else { $null }
    $commitmentSavings = if ($currency) { [math]::Round($riSavings + $spSavings, 2) } else { $null }

    # Commitment coverage = committed eligible spend / total eligible spend.
    # Eligible = everything except Spot (Spot cannot be covered by a commitment).
    $eligibleBase = $committedAmort + $onDemandAmort
    $commitmentCoverage = if ($eligibleBase -gt 0) {
        [math]::Round(100 * $committedAmort / $eligibleBase, 1)
    }
    else { $null }

    return [PSCustomObject]@{
        RISavingsMonthToDate  = if ($currency) { [math]::Round($riSavings, 2) } else { $null }
        SPSavingsMonthToDate  = if ($currency) { [math]::Round($spSavings, 2) } else { $null }
        CommitmentSavingsMonthToDate = $commitmentSavings
        Currency              = $currency
        Period                = $period
        CostPeriodStartUtc    = $periodStartUtc
        CostPeriodEndUtc      = $periodEndUtc
        RISavingsMonthly      = $null
        SPSavingsMonthly      = $null
        AHBSavingsMonthly     = if ($null -ne $ahbSavings) { [math]::Round($ahbSavings, 2) } else { $null }
        AHBCurrency           = 'USD'
        AHBPeriod             = '730-hour estimate for current VM inventory'
        AHBIssue              = $ahbIssue
        TotalMonthly          = $null
        TotalAnnual           = $null
        CommittedAmortized    = [math]::Round($committedAmort, 2)
        OnDemandAmortized     = [math]::Round($onDemandAmort, 2)
        SpotAmortized         = [math]::Round($spotAmort, 2)
        CommitmentCoveragePct = $commitmentCoverage
        Details               = @($details)
        IsEstimate            = $true
        EstimateBasis         = "Commitment estimates cover usage charges for $period in the reported billing currency, using assumed $([int]($riDiscountRate * 100))% reservation and $([int]($spDiscountRate * 100))% savings plan discounts. Purchases, refunds, and unused commitment charges are excluded from that estimate. AHB is a separate USD estimate for 730 hours on the current VM inventory, using retail license premiums or a USD 50 per-VM fallback. These amounts are not combined or annualized. Monthly commitment and combined total fields are unavailable; use the month-to-date fields. Validate against matching pay-as-you-go rates and benefit usage before reporting realized savings."
        HasData               = ($null -ne $commitmentSavings -or $ahbSavings -gt 0 -or $details.Count -gt 0)
    }
}
