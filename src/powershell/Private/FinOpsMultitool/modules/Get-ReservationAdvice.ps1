# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
param()

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

function Get-ReservationRecommendationMoney {
    param([AllowNull()]$Amount)

    if ($null -eq $Amount) { return [pscustomobject]@{ Value = $null; Currency = 'Unknown' } }
    $isMoney = $Amount -is [System.Collections.IDictionary] -or $Amount -is [pscustomobject]
    $value = if ($isMoney) { $Amount.value } else { $Amount }
    $currency = if ($isMoney) { ([string]$Amount.currency).Trim().ToUpperInvariant() } else { 'Unknown' }
    $number = Get-HubCostValue -Row ([pscustomobject]@{ Amount = $value }) -Column 'Amount'
    if ($isMoney -and ($currency -notmatch '^[A-Z]{3}$' -or $currency -in @('XXX', 'XTS'))) {
        throw 'A modern recommendation amount has no valid currency.'
    }
    return [pscustomobject]@{ Value = [math]::Round($number, 2); Currency = $currency }
}

function Get-ReservationAdvice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $allRecommendations = [System.Collections.Generic.List[PSCustomObject]]::new()
    $readErrors = [System.Collections.Generic.List[string]]::new()
    $accessDenied = $false

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
| project id, subscriptionId,
    shortDescriptionProblem  = tostring(properties.shortDescription.problem),
    shortDescriptionSolution = tostring(properties.shortDescription.solution),
    impact          = tostring(properties.impact),
    impactedField   = tostring(properties.impactedField),
    impactedValue   = tostring(properties.impactedValue),
    annualSavings   = tostring(properties.extendedProperties.annualSavingsAmount),
    savingsCurrency = tostring(properties.extendedProperties.savingsCurrency),
    term            = tostring(properties.extendedProperties.term),
    displaySKU      = tostring(properties.extendedProperties.displaySKU),
    region          = tostring(properties.extendedProperties.region),
    displayQty      = tostring(properties.extendedProperties.displayQty),
    assessedResourceId = tostring(properties.resourceMetadata.resourceId),
    recommendationTypeId = tostring(properties.recommendationTypeId),
    options         = properties.extendedProperties,
    recName         = name
"@

    try {
        Write-Host "  Querying RI/SP recommendations via Resource Graph..." -ForegroundColor Cyan
        $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000 -All
        if ($null -eq $result -or $null -eq $result.Data) { throw 'Advisor Resource Graph response is unreadable; results are incomplete.' }
        $allRows = @($result.Data)

        Write-Host "  Retrieved $($allRows.Count) RI/SP recommendations." -ForegroundColor Cyan

        foreach ($row in $allRows) {
            $subId = $row.subscriptionId
            $savings = if (-not [string]::IsNullOrWhiteSpace([string]$row.annualSavings)) {
                [math]::Round((Get-HubCostValue -Row $row -Column 'annualSavings'), 2)
            } else { $null }
            $subName = if ($subNameMap.ContainsKey($subId)) { $subNameMap[$subId] } else { $subId }

            # Savings Plans are subscription-scoped, flexible commitments: Advisor
            # returns the subscription GUID as impactedValue and carries no
            # SKU/region/qty. Resolve the GUID to the subscription name and label
            # the flexible dimensions 'Any' so the row reads as a real scope-wide
            # commitment rather than a bare ID with missing data. RIs keep their
            # real SKU/region/qty. The savings come straight from Advisor.
            $isSavingsPlan = ($row.shortDescriptionSolution -match '(?i)savings plan') -or ($row.shortDescriptionProblem -match '(?i)savings plan')
            $isSubScope = $row.impactedField -match '(?i)subscriptions/subscriptions'
            $resName = if ($isSubScope) { "$subName (subscription-wide)" } else { $row.impactedValue }
            $sku = if ($row.displaySKU) { $row.displaySKU } elseif ($isSavingsPlan) { 'Any (flexible)' } else { '-' }
            $region = if ($row.region) { $row.region }    elseif ($isSavingsPlan) { 'Any' }            else { '-' }
            $qty = if ($row.displayQty) { $row.displayQty } elseif ($isSavingsPlan) { 'Commitment' }     else { '-' }
            # Search-AzGraph injects ResourceId from id; use a distinct alias for the assessed target.
            $resourceId = $row.assessedResourceId
            if (-not $resourceId -and $row.id -match '^(.+)/providers/Microsoft.Advisor/recommendations/[^/]+$') { $resourceId = $Matches[1] }

            [void]$allRecommendations.Add([PSCustomObject]@{
                    Subscription     = $subName
                    SubscriptionId   = $subId
                    Problem          = $row.shortDescriptionProblem
                    Solution         = $row.shortDescriptionSolution
                    Impact           = $row.impact
                    Category         = 'Reservation / Savings Plan'
                    ResourceType     = $row.impactedField
                    ResourceName     = $resName
                    SKU              = $sku
                    Region           = $region
                    Qty              = $qty
                    AnnualSavings    = $savings
                    Currency         = $row.savingsCurrency
                    Term             = $row.term
                    RecommendationId = $row.recName
                    ResourceId       = $resourceId
                    RecommendationTypeId = $row.recommendationTypeId
                    Options          = $row.options
                })
        }
    }
    catch {
        # The fallback rereads every subscription, so rows read before the failure would count twice.
        $allRecommendations.Clear()
        Write-Warning "  Advisor Resource Graph query failed: $($_.Exception.Message)"
        Write-Warning "  Falling back to per-subscription REST calls..."

        foreach ($sub in $Subscriptions) {
            try {
                $advPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$filter=Category eq 'Cost'"
                $advResp = Invoke-AzRestMethodWithRetry -Path $advPath -Method GET
                $advResult = Get-FinOpsListResult -FirstResponse $advResp -Context "Advisor recommendations for $($sub.Name)"

                $riRecs = $advResult.value | Where-Object {
                    $_.properties.shortDescription.problem -match 'reserv|savings plan|reserved instance' -or
                    $_.properties.shortDescription.solution -match 'reserv|savings plan|reserved instance'
                }

                foreach ($item in $riRecs) {
                    try {
                        $rec = $item.properties
                        $isSavingsPlan = ($rec.shortDescription.solution -match '(?i)savings plan') -or ($rec.shortDescription.problem -match '(?i)savings plan')
                        $isSubScope = $rec.impactedField -match '(?i)subscriptions/subscriptions'
                        $resName = if ($isSubScope) { "$($sub.Name) (subscription-wide)" } else { $rec.impactedValue }
                        $sku = if ($rec.extendedProperties.displaySKU) { $rec.extendedProperties.displaySKU } elseif ($isSavingsPlan) { 'Any (flexible)' } else { '-' }
                        $region = if ($rec.extendedProperties.region) { $rec.extendedProperties.region }     elseif ($isSavingsPlan) { 'Any' }            else { '-' }
                        $qty = if ($rec.extendedProperties.displayQty) { $rec.extendedProperties.displayQty } elseif ($isSavingsPlan) { 'Commitment' }     else { '-' }
                        $resourceId = $rec.resourceMetadata.resourceId
                        if (-not $resourceId -and $item.id -match '^(.+)/providers/Microsoft.Advisor/recommendations/[^/]+$') { $resourceId = $Matches[1] }
                        [void]$allRecommendations.Add([PSCustomObject]@{
                                Subscription     = $sub.Name
                                SubscriptionId   = $sub.Id
                                Problem          = $rec.shortDescription.problem
                                Solution         = $rec.shortDescription.solution
                                Impact           = $rec.impact
                                Category         = 'Reservation / Savings Plan'
                                ResourceType     = $rec.impactedField
                                ResourceName     = $resName
                                SKU              = $sku
                                Region           = $region
                                Qty              = $qty
                                AnnualSavings    = if (-not [string]::IsNullOrWhiteSpace([string]$rec.extendedProperties.annualSavingsAmount)) {
                                    [math]::Round((Get-HubCostValue -Row $rec.extendedProperties -Column 'annualSavingsAmount'), 2)
                                }
                                else { $null }
                                Currency         = $rec.extendedProperties.savingsCurrency
                                Term             = $rec.extendedProperties.term
                                RecommendationId = $item.name
                                ResourceId       = $resourceId
                                RecommendationTypeId = $rec.recommendationTypeId
                                Options          = $rec.extendedProperties
                            })
                    }
                    catch {
                        $message = "Advisor / $($sub.Name) / $($item.name): $($_.Exception.Message)"
                        [void]$readErrors.Add($message)
                        Write-Warning $message
                    }
                }
            }
            catch {
                if ((Get-CostRequestFailureStatus -ErrorRecord $_) -in @('401', '403') -or
                    "$($_.Exception.Message)" -match '\b40[13]\b|Forbidden|AuthorizationFailed|Unauthorized') { $accessDenied = $true }
                [void]$readErrors.Add("Advisor / $($sub.Name): $($_.Exception.Message)")
                Write-Warning "  Advisor query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Also try the Reservation Recommendation API --------------------
    # Must be subscription scoped: the bare provider path returns 404
    # InvalidResourceType. 'Shared' scope is only valid at billing-account scope
    # and returns 422 here. resourceType defaults to VirtualMachines, so every
    # other type has to be requested by name or it is silently absent.
    $rrResourceTypes = @(
        'VirtualMachines', 'SQLDatabases', 'PostgreSQL', 'ManagedDisk', 'MySQL',
        'RedHat', 'MariaDB', 'RedisCache', 'CosmosDB', 'SqlDataWarehouse',
        'SUSELinux', 'AppService', 'BlockBlob', 'AzureDataExplorer', 'VMwareCloudSimple'
    )
    $reservationRecs = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($sub in $Subscriptions) {
        foreach ($rrType in $rrResourceTypes) {
            try {
                $rrFilter = "properties/scope eq 'Single' and properties/resourceType eq '$rrType' and properties/lookBackPeriod eq 'Last30Days'"
                $rrPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01&`$filter=$([uri]::EscapeDataString($rrFilter))"
                $rrResp = Invoke-AzRestMethodWithRetry -Path $rrPath -Method GET
                # Consumption explicitly returns 204 when there are no recommendations.
                if ($rrResp -and $rrResp.StatusCode -eq 204) { continue }
                $rrResult = Get-FinOpsListResult -FirstResponse $rrResp -Context "Reservation recommendations for $($sub.Name) / $rrType"

                foreach ($item in $rrResult.value) {
                    try {
                        $props = $item.properties
                        if ($null -eq $props) { throw 'Recommendation properties are missing.' }
                        $without = Get-ReservationRecommendationMoney -Amount $props.costWithNoReservedInstances
                        $with = Get-ReservationRecommendationMoney -Amount $props.totalCostWithReservedInstances
                        $saving = Get-ReservationRecommendationMoney -Amount $props.netSavings
                        # Legacy records carry normalizedSize and no resourceType; modern carry skuName.
                        $rrSku = if ($props.skuName) { $props.skuName } elseif ($props.normalizedSize) { $props.normalizedSize } elseif ($item.sku) { $item.sku } else { '-' }
                        [void]$reservationRecs.Add([PSCustomObject]@{
                                Subscription   = $sub.Name
                                SubscriptionId = $sub.Id
                                RecommendationId = $item.id
                                ResourceType   = if ($props.resourceType) { $props.resourceType } else { $rrType }
                                SKU            = $rrSku
                                Region         = if ($props.location) { $props.location } else { $item.location }
                                RecommendedQty = $props.recommendedQuantity
                                Term           = $props.term
                                CostWithoutRI  = $without.Value
                                CostWithoutRICurrency = $without.Currency
                                CostWithRI     = $with.Value
                                CostWithRICurrency = $with.Currency
                                NetSavings     = $saving.Value
                                Currency       = $saving.Currency
                                Scope          = $props.scope
                                LookBackPeriod = $props.lookBackPeriod
                                FlexGroup      = $props.instanceFlexibilityGroup
                                CostPeriod     = 'API-modeled lookback period; not an annual estimate'
                            })
                    }
                    catch {
                        $message = "Reservation / $($sub.Name) / $rrType / $($item.name): $($_.Exception.Message)"
                        [void]$readErrors.Add($message)
                        Write-Warning $message
                    }
                }
            }
            catch {
                $denied = (Get-CostRequestFailureStatus -ErrorRecord $_) -in @('401', '403') -or
                    "$($_.Exception.Message)" -match '\b40[13]\b|Forbidden|AuthorizationFailed|Unauthorized'
                if ($denied) { $accessDenied = $true }
                $message = "Reservation / $($sub.Name) / $rrType : $($_.Exception.Message)"
                [void]$readErrors.Add($message)
                Write-Warning $message
                if ($denied) { break }
            }
        }
    }
    if ($reservationRecs.Count -gt 0) {
        Write-Host "  Retrieved $($reservationRecs.Count) reservation purchase recommendations." -ForegroundColor Cyan
    }

    # -- De-duplicate Advisor records -----------------------------------
    # Generation GUIDs can differ for the same advice. Preserve the assessed
    # resource, recommendation type, and purchase options before collapsing copies.
    $deduped = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenKeys = @{}
    foreach ($rec in $allRecommendations) {
        $options = [ordered]@{}
        if ($rec.Options -is [System.Collections.IDictionary]) {
            foreach ($name in @($rec.Options.Keys | Sort-Object)) { $options[$name] = $rec.Options[$name] }
        }
        elseif ($rec.Options) {
            foreach ($property in @($rec.Options.PSObject.Properties | Sort-Object Name)) { $options[$property.Name] = $property.Value }
        }
        $target = if ($rec.ResourceId) { $rec.ResourceId } else { $rec.ResourceName }
        $key = ConvertTo-Json -InputObject @($rec.SubscriptionId, $target, $rec.ResourceName, $rec.ResourceType, $rec.RecommendationTypeId,
            $rec.Problem, $rec.Solution, $rec.Term, $rec.SKU, $rec.Region, $rec.Qty, $rec.AnnualSavings, $rec.Currency, $options) -Depth 20 -Compress
        # Display names alone do not establish identity across resource groups.
        if (-not $rec.ResourceId) { $key += "|$($rec.RecommendationId)|$($deduped.Count)" }
        if ($seenKeys.ContainsKey($key)) {
            $seenKeys[$key].DuplicateCount++
        }
        else {
            $rec | Add-Member -NotePropertyName DuplicateCount -NotePropertyValue 1 -Force
            $seenKeys[$key] = $rec
            [void]$deduped.Add($rec)
        }
    }
    if ($allRecommendations.Count -ne $deduped.Count) {
        Write-Host "  Collapsed $($allRecommendations.Count) Advisor records into $($deduped.Count) distinct recommendations." -ForegroundColor Cyan
    }
    $allRecommendations = $deduped

    # -- Aggregate savings ----------------------------------------------
    $savingsSummary = Measure-FinOpsSavingsEstimate -Recommendations @($allRecommendations)
    $estimateIssues = [System.Collections.Generic.List[string]]::new()
    if ($savingsSummary.CostIssue) { $estimateIssues.Add($savingsSummary.CostIssue) }
    if ($readErrors.Count -gt 0) { $estimateIssues.Add('Recommendation coverage is incomplete; a selected-scope annual estimate is unavailable.') }
    if (@($allRecommendations | Where-Object { $null -eq $_.AnnualSavings }).Count -gt 0) {
        $estimateIssues.Add('Some Advisor recommendations have no annual savings amount; the combined estimate is unavailable.')
    }
    foreach ($group in @($allRecommendations | Group-Object SubscriptionId)) {
        $recs = @($group.Group)
        $targets = @($recs | Group-Object ResourceId)
        if (($recs.Count -gt 1 -and @($recs | Where-Object { -not $_.ResourceId }).Count -gt 0) -or
            @($targets | Where-Object Count -GT 1).Count -gt 0 -or
            ($recs.Count -gt 1 -and @($recs | Where-Object { "$($_.Problem) $($_.Solution)" -match 'savings plan' }).Count -gt 0)) {
            $estimateIssues.Add('Commitment recommendations can be alternative terms or cover overlapping usage. Compare individual options; their savings are not additive.')
            break
        }
    }
    $costIssue = if ($estimateIssues.Count -gt 0) { $estimateIssues -join ' ' } else { $null }

    return [PSCustomObject]@{
        AdvisorRecommendations     = $allRecommendations
        ReservationRecommendations = $reservationRecs
        TotalAdvisorCount          = $allRecommendations.Count
        TotalReservationCount      = $reservationRecs.Count
        EstimatedAnnualSavings     = if (-not $costIssue) { $savingsSummary.Total } else { $null }
        Currency                   = $savingsSummary.Currency
        CostIssue                  = $costIssue
        AccessDenied               = $accessDenied
        CoverageIncomplete         = ($readErrors.Count -gt 0)
        ReadErrors                 = @($readErrors)
        Note                       = if ($readErrors.Count -gt 0) { "Recommendation coverage is incomplete. $($readErrors -join ' ')" } else { $null }
        Summary                    = "$($allRecommendations.Count) Advisor + $($reservationRecs.Count) reservation recommendations"
    }
}
