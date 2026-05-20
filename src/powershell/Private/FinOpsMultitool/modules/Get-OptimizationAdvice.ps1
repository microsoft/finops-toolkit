###########################################################################
# GET-OPTIMIZATIONADVICE.PS1
# AZURE FINOPS MULTITOOL - Azure Advisor Cost Optimization
###########################################################################
# Purpose: Pull all cost optimization recommendations from Azure Advisor
#          across every subscription. Categorize by type: rightsize,
#          shutdown, delete, modernize.
#
# Reference: https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations
###########################################################################

function Get-OptimizationAdvice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $allRecs = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Build subscription ID list and name lookup
    $subIds = @($Subscriptions | ForEach-Object { $_.Id })
    $subNameMap = @{}
    foreach ($sub in $Subscriptions) { $subNameMap[$sub.Id] = $sub.Name }

    # Query all Advisor cost recommendations via Resource Graph (single call)
    $query = @"
advisorresources
| where type == 'microsoft.advisor/recommendations'
| where properties.category == 'Cost'
| project subscriptionId,
    shortDescriptionProblem  = tostring(properties.shortDescription.problem),
    shortDescriptionSolution = tostring(properties.shortDescription.solution),
    impact          = tostring(properties.impact),
    impactedField   = tostring(properties.impactedField),
    impactedValue   = tostring(properties.impactedValue),
    annualSavings   = tostring(properties.extendedProperties.annualSavingsAmount),
    savingsAmount   = tostring(properties.extendedProperties.savingsAmount),
    savingsCurrency = tostring(properties.extendedProperties.savingsCurrency)
"@

    try {
        Write-Host "  Querying Advisor cost recommendations via Resource Graph..." -ForegroundColor Cyan
        $allRows = [System.Collections.Generic.List[object]]::new()
        $skipToken = $null

        do {
            $result = Search-AzGraphSafe -Query $query -Subscription $subIds -First 1000 -SkipToken $skipToken
            if ($result -and $result.Data) { foreach ($r in $result.Data) { [void]$allRows.Add($r) } }
            $skipToken = if ($result) { $result.SkipToken } else { $null }
        } while ($skipToken)

        Write-Host "  Retrieved $($allRows.Count) Advisor cost recommendations." -ForegroundColor Cyan

        foreach ($row in $allRows) {
            $problem  = $row.shortDescriptionProblem
            $solution = $row.shortDescriptionSolution

            # Skip reservation/savings plan recs (handled by Get-ReservationAdvice)
            if ($problem -match 'reserv|savings plan') { continue }

            # Categorize the recommendation
            $catText = "$problem $solution"
            $category = switch -Regex ($catText) {
                'right.?siz|resize|downsize|scale down'    { 'Rightsize' }
                'shut.?down|deallocate|idle|stopped'       { 'Shutdown / Deallocate' }
                'delet|unused|orphan|unattached'            { 'Delete Unused' }
                'modern|upgrade|migrate|move to'           { 'Modernize' }
                'burstable|B-series'                        { 'Rightsize' }
                default                                     { 'Other' }
            }

            $savings = $null
            if ($row.annualSavings) {
                $savings = [math]::Round([double]$row.annualSavings, 2)
            }
            elseif ($row.savingsAmount) {
                $savings = [math]::Round([double]$row.savingsAmount, 2)
            }

            $subId = $row.subscriptionId
            [void]$allRecs.Add([PSCustomObject]@{
                Subscription     = if ($subNameMap.ContainsKey($subId)) { $subNameMap[$subId] } else { $subId }
                SubscriptionId   = $subId
                Category         = $category
                Impact           = $row.impact
                Problem          = $problem
                Solution         = $solution
                ResourceType     = $row.impactedField
                ResourceName     = $row.impactedValue
                AnnualSavings    = $savings
                Currency         = $row.savingsCurrency
            })
        }
    } catch {
        Write-Warning "  Advisor Resource Graph query failed: $($_.Exception.Message)"
        Write-Warning "  Falling back to per-subscription REST calls..."

        # Fallback: per-subscription REST API (slow but reliable)
        foreach ($sub in $Subscriptions) {
            try {
                $advPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$filter=Category eq 'Cost'"
                $advResp = Invoke-AzRestMethodWithRetry -Path $advPath -Method GET
                if ($advResp.StatusCode -ne 200) { continue }
                $advResult = ($advResp.Content | ConvertFrom-Json)

                foreach ($item in $advResult.value) {
                    $rec = $item.properties
                    if ($rec.shortDescription.problem -match 'reserv|savings plan') { continue }

                    $catText = "$($rec.shortDescription.problem) $($rec.shortDescription.solution)"
                    $category = switch -Regex ($catText) {
                        'right.?siz|resize|downsize|scale down'    { 'Rightsize' }
                        'shut.?down|deallocate|idle|stopped'       { 'Shutdown / Deallocate' }
                        'delet|unused|orphan|unattached'            { 'Delete Unused' }
                        'modern|upgrade|migrate|move to'           { 'Modernize' }
                        'burstable|B-series'                        { 'Rightsize' }
                        default                                     { 'Other' }
                    }

                    $savings = $null
                    if ($rec.extendedProperties.annualSavingsAmount) {
                        $savings = [math]::Round([double]$rec.extendedProperties.annualSavingsAmount, 2)
                    } elseif ($rec.extendedProperties.savingsAmount) {
                        $savings = [math]::Round([double]$rec.extendedProperties.savingsAmount, 2)
                    }

                    [void]$allRecs.Add([PSCustomObject]@{
                        Subscription     = $sub.Name
                        SubscriptionId   = $sub.Id
                        Category         = $category
                        Impact           = $rec.impact
                        Problem          = $rec.shortDescription.problem
                        Solution         = $rec.shortDescription.solution
                        ResourceType     = $rec.impactedField
                        ResourceName     = $rec.impactedValue
                        AnnualSavings    = $savings
                        Currency         = $rec.extendedProperties.savingsCurrency
                    })
                }
            } catch {
                Write-Warning "  Advisor query failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Summarize by category ------------------------------------------
    $byCat = $allRecs | Group-Object Category | ForEach-Object {
        [PSCustomObject]@{
            Category      = $_.Name
            Count         = $_.Count
            TotalSavings  = [math]::Round(($_.Group | Where-Object { $_.AnnualSavings } |
                Measure-Object -Property AnnualSavings -Sum).Sum, 2)
        }
    }

    $totalSavings = ($allRecs | Where-Object { $_.AnnualSavings } |
        Measure-Object -Property AnnualSavings -Sum).Sum

    # -- Summarize by impact --------------------------------------------
    $byImpact = $allRecs | Group-Object Impact | ForEach-Object {
        [PSCustomObject]@{ Impact = $_.Name; Count = $_.Count }
    }

    return [PSCustomObject]@{
        Recommendations     = $allRecs
        ByCategory          = $byCat
        ByImpact            = $byImpact
        TotalCount          = $allRecs.Count
        EstimatedAnnualSavings = [math]::Round($totalSavings, 2)
        Summary             = "$($allRecs.Count) optimization recommendations (est. `$$([math]::Round($totalSavings, 2))/yr savings)"
    }
}
