###########################################################################
# GET-RESERVATIONADVICE.PS1
# AZURE FINOPS MULTITOOL - Reservation & Savings Plan Recommendations
###########################################################################
# Purpose: Pull RI (Reserved Instance) and Savings Plan recommendations
#          from Azure Advisor and the Reservation Recommendation API.
#
# Rate optimization (RI/SP) is the #1 FinOps quick win - typical
# savings are 30-72% versus pay-as-you-go pricing.
#
# Reference: https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations
###########################################################################

function Get-ReservationAdvice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $allRecommendations = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Build subscription ID list and name lookup
    $subIds = @($Subscriptions | ForEach-Object { $_.Id })
    $subNameMap = @{}
    foreach ($sub in $Subscriptions) { $subNameMap[$sub.Id] = $sub.Name }

    # Query Advisor cost recommendations via Resource Graph (single call)
    $query = @"
advisorresources
| where type == 'microsoft.advisor/recommendations'
| where properties.category == 'Cost'
| where properties.shortDescription.problem matches regex '(?i)reserv|savings plan|reserved instance'
     or properties.shortDescription.solution matches regex '(?i)reserv|savings plan|reserved instance'
| project subscriptionId,
    shortDescriptionProblem  = tostring(properties.shortDescription.problem),
    shortDescriptionSolution = tostring(properties.shortDescription.solution),
    impact          = tostring(properties.impact),
    impactedField   = tostring(properties.impactedField),
    impactedValue   = tostring(properties.impactedValue),
    annualSavings   = tostring(properties.extendedProperties.annualSavingsAmount),
    savingsCurrency = tostring(properties.extendedProperties.savingsCurrency),
    term            = tostring(properties.extendedProperties.term),
    recName         = name
"@

    try {
        Write-Host "  Querying RI/SP recommendations via Resource Graph..." -ForegroundColor Cyan
        $allRows = [System.Collections.Generic.List[object]]::new()
        $skipToken = $null

        do {
            $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000 -SkipToken $skipToken
            if ($result -and $result.Data) { foreach ($r in $result.Data) { [void]$allRows.Add($r) } }
            $skipToken = if ($result) { $result.SkipToken } else { $null }
        } while ($skipToken)

        Write-Host "  Retrieved $($allRows.Count) RI/SP recommendations." -ForegroundColor Cyan

        foreach ($row in $allRows) {
            $subId = $row.subscriptionId
            $savings = if ($row.annualSavings) { [math]::Round([double]$row.annualSavings, 2) } else { $null }

            [void]$allRecommendations.Add([PSCustomObject]@{
                Subscription     = if ($subNameMap.ContainsKey($subId)) { $subNameMap[$subId] } else { $subId }
                SubscriptionId   = $subId
                Problem          = $row.shortDescriptionProblem
                Solution         = $row.shortDescriptionSolution
                Impact           = $row.impact
                Category         = 'Reservation / Savings Plan'
                ResourceType     = $row.impactedField
                ResourceName     = $row.impactedValue
                AnnualSavings    = $savings
                Currency         = $row.savingsCurrency
                Term             = $row.term
                RecommendationId = $row.recName
            })
        }
    } catch {
        Write-Warning "  Advisor Resource Graph query failed: $($_.Exception.Message)"
        Write-Warning "  Falling back to per-subscription REST calls..."

        foreach ($sub in $Subscriptions) {
            try {
                $advPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$filter=Category eq 'Cost'"
                $advResp = Invoke-AzRestMethodWithRetry -Path $advPath -Method GET
                if ($advResp.StatusCode -ne 200) { continue }
                $advResult = ($advResp.Content | ConvertFrom-Json)

                $riRecs = $advResult.value | Where-Object {
                    $_.properties.shortDescription.problem -match 'reserv|savings plan|reserved instance' -or
                    $_.properties.shortDescription.solution -match 'reserv|savings plan|reserved instance'
                }

                foreach ($item in $riRecs) {
                    $rec = $item.properties
                    [void]$allRecommendations.Add([PSCustomObject]@{
                        Subscription     = $sub.Name
                        SubscriptionId   = $sub.Id
                        Problem          = $rec.shortDescription.problem
                        Solution         = $rec.shortDescription.solution
                        Impact           = $rec.impact
                        Category         = 'Reservation / Savings Plan'
                        ResourceType     = $rec.impactedField
                        ResourceName     = $rec.impactedValue
                        AnnualSavings    = if ($rec.extendedProperties.annualSavingsAmount) {
                                             [math]::Round([double]$rec.extendedProperties.annualSavingsAmount, 2)
                                           } else { $null }
                        Currency         = $rec.extendedProperties.savingsCurrency
                        Term             = $rec.extendedProperties.term
                        RecommendationId = $item.name
                    })
                }
            } catch {
                Write-Warning "  Advisor query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Also try the Reservation Recommendation API --------------------
    $reservationRecs = [System.Collections.Generic.List[PSCustomObject]]::new()
    try {
        $rrPath = "/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01&`$filter=properties/scope eq 'Shared' and properties/lookBackPeriod eq 'Last30Days'"
        $rrResp = Invoke-AzRestMethodWithRetry -Path $rrPath -Method GET
        if (-not $rrResp -or -not $rrResp.Content) { throw "Reservation recommendation API returned no content (HTTP $($rrResp.StatusCode))" }
        $rrResult = ($rrResp.Content | ConvertFrom-Json)

        if ($rrResult.value) {
            foreach ($item in $rrResult.value) {
                $props = $item.properties
                [void]$reservationRecs.Add([PSCustomObject]@{
                    ResourceType      = $props.resourceType
                    SKU               = $props.skuProperties.name
                    RecommendedQty    = $props.recommendedQuantity
                    Term              = $props.term
                    CostWithoutRI     = if ($props.costWithNoReservedInstances) { [math]::Round($props.costWithNoReservedInstances, 2) } else { $null }
                    CostWithRI        = if ($props.totalCostWithReservedInstances) { [math]::Round($props.totalCostWithReservedInstances, 2) } else { $null }
                    NetSavings        = if ($props.netSavings) { [math]::Round($props.netSavings, 2) } else { $null }
                    Currency          = $props.currencyCode
                    Scope             = $props.scope
                    LookBackPeriod    = $props.lookBackPeriod
                })
            }
        }
    } catch {
        Write-Warning "Reservation recommendation API query failed (non-critical): $($_.Exception.Message)"
    }

    # -- Aggregate savings ----------------------------------------------
    $totalAnnualSavings = ($allRecommendations | Where-Object { $_.AnnualSavings } |
        Measure-Object -Property AnnualSavings -Sum).Sum

    return [PSCustomObject]@{
        AdvisorRecommendations    = $allRecommendations
        ReservationRecommendations = $reservationRecs
        TotalAdvisorCount         = $allRecommendations.Count
        TotalReservationCount     = $reservationRecs.Count
        EstimatedAnnualSavings    = [math]::Round($totalAnnualSavings, 2)
        Summary                   = "$($allRecommendations.Count) Advisor + $($reservationRecs.Count) reservation recommendations"
    }
}
