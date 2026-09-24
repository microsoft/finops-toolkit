# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
param()

###########################################################################
# GET-ANOMALYALERTS.PS1
# AZURE FINOPS MULTITOOL - Cost Management Anomaly & Budget Alerts
###########################################################################
# Purpose: Query Azure Cost Management for triggered alerts (anomaly,
#          budget, forecast) and configured anomaly alert rules
#          (InsightAlert scheduled actions) across all subscriptions.
###########################################################################

function Get-AnomalyAlerts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $subCount = $Subscriptions.Count
    Write-Host "  Querying anomaly & budget alerts ($subCount subs)..." -ForegroundColor Cyan

    $triggeredAlerts = [System.Collections.Generic.List[PSCustomObject]]::new()
    $configuredRules = [System.Collections.Generic.List[PSCustomObject]]::new()
    $readErrors = [Collections.Generic.List[string]]::new()

    $i = 0
    foreach ($sub in $Subscriptions) {
        $i++
        if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
            if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                Update-ScanStatus "Querying anomaly alerts ($i/$subCount subs)..."
            }
        }

        # -- Triggered Cost Management alerts --
        try {
            $alertPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/alerts?api-version=2023-09-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $alertPath -Method GET
            $data = Get-FinOpsListResult -FirstResponse $resp -Context "alerts for $($sub.Name)"

            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                if ($data.value) {
                    foreach ($alert in $data.value) {
                        $p   = $alert.properties
                        $def = if ($p.definition) { $p.definition } else { @{} }
                        $det = if ($p.details) { $p.details } else { @{} }

                        $alertType = if ($def.type)     { $def.type }     else { 'Unknown' }
                        $category  = if ($def.category) { $def.category } else { '' }
                        $criteria  = if ($def.criteria) { $def.criteria } else { '' }
                        $status    = if ($p.status)     { $p.status }     else { 'Unknown' }

                        $amount = if ($null -ne $det.amount) { [math]::Round((Get-HubCostValue -Row $det -Column 'amount'), 2) } else { $null }
                        $currentSpend = if ($null -ne $det.currentSpend) { [math]::Round((Get-HubCostValue -Row $det -Column 'currentSpend'), 2) } else { $null }
                        $unit = if ($det.unit) { $det.unit } else { $null }

                        # Cost Management names alerts with a GUID. Derive a human
                        # label: prefer the alert description, then the related
                        # budget/scope leaf (costEntityId), then a Category/Type
                        # composite, and only fall back to the GUID as a last resort.
                        $description  = if ($p.description)  { [string]$p.description }  else { '' }
                        $costEntityId = if ($p.costEntityId) { [string]$p.costEntityId } else { '' }
                        $relatedTo    = if ($costEntityId) { ($costEntityId -split '/')[-1] } else { '' }
                        $alertLabel =
                            if ($description) { $description }
                            elseif ($relatedTo) { "$relatedTo ($alertType)" }
                            else {
                                $composite = (@($category, $alertType) | Where-Object { $_ -and $_ -ne 'Unknown' }) -join ' '
                                if ($composite) { $composite } else { $alert.name }
                            }

                        $contacts = @()
                        if ($det.contactEmails) { $contacts += @($det.contactEmails) }
                        if ($det.contactRoles)  { $contacts += @($det.contactRoles) }

                        $createdAt = ''
                        if ($p.creationTime) {
                            try { $createdAt = ([datetime]$p.creationTime).ToString('yyyy-MM-dd') } catch { $createdAt = $p.creationTime }
                        }

                        [void]$triggeredAlerts.Add([PSCustomObject]@{
                            Subscription   = $sub.Name
                            SubscriptionId = $sub.Id
                            AlertName      = $alert.name
                            AlertLabel     = $alertLabel
                            RelatedTo      = $relatedTo
                            Description    = $description
                            AlertType      = $alertType
                            Category       = $category
                            Criteria       = $criteria
                            Status         = $status
                            Amount         = $amount
                            CurrentSpend   = $currentSpend
                            Unit           = $unit
                            Contacts       = (($contacts | Select-Object -Unique) -join ', ')
                            CreatedAt      = $createdAt
                        })
                    }
                }
            }
        } catch {
            $readErrors.Add($_.Exception.Message)
            Write-Warning "  Alert query failed for $($sub.Name): $($_.Exception.Message)"
        }

        # -- Configured anomaly alert rules (InsightAlert scheduled actions) --
        try {
            $saPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/scheduledActions?api-version=2023-03-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $saPath -Method GET
            $data = Get-FinOpsListResult -FirstResponse $resp -Context "scheduled actions for $($sub.Name)"

            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                if ($data.value) {
                    $insightActions = @($data.value | Where-Object { $_.kind -eq 'InsightAlert' })
                    foreach ($sa in $insightActions) {
                        $p = if ($sa.properties) { $sa.properties } else { @{} }

                        $toEmails = ''
                        if ($p.notification -and $p.notification.to) {
                            $toEmails = ($p.notification.to -join ', ')
                        }

                        $nextRun = ''
                        if ($p.nextRunTime) {
                            try { $nextRun = ([datetime]$p.nextRunTime).ToString('yyyy-MM-dd') } catch { $nextRun = $p.nextRunTime }
                        }

                        [void]$configuredRules.Add([PSCustomObject]@{
                            Subscription   = $sub.Name
                            SubscriptionId = $sub.Id
                            RuleName       = $sa.name
                            DisplayName    = if ($p.displayName) { $p.displayName } else { $sa.name }
                            Status         = if ($p.status) { $p.status } else { 'Unknown' }
                            Scope          = if ($p.scope) { $p.scope } else { "/subscriptions/$($sub.Id)" }
                            ToEmails       = $toEmails
                            NextRunTime    = $nextRun
                        })
                    }
                }
            }
        } catch {
            $readErrors.Add($_.Exception.Message)
            Write-Warning "  Scheduled action query failed for $($sub.Name): $($_.Exception.Message)"
        }
    }

    $anomalyCount  = @($triggeredAlerts | Where-Object { $_.AlertType -match 'Anomaly' }).Count
    $activeCount   = @($triggeredAlerts | Where-Object { $_.Status -eq 'Active' }).Count
    $budgetCount   = @($triggeredAlerts | Where-Object { $_.AlertType -match 'Budget' }).Count

    return [PSCustomObject]@{
        TriggeredAlerts     = @($triggeredAlerts)
        CoverageIncomplete  = ($readErrors.Count -gt 0)
        ReadErrors          = @($readErrors)
        Note                = if ($readErrors.Count -gt 0) { 'Alert and rule coverage is incomplete. ' + ($readErrors -join ' ') } else { $null }
        ConfiguredRules     = @($configuredRules)
        TotalAlerts         = $triggeredAlerts.Count
        AnomalyAlertCount   = $anomalyCount
        ActiveAlertCount    = $activeCount
        BudgetAlertCount    = $budgetCount
        ConfiguredRuleCount = $configuredRules.Count
        HasData             = ($triggeredAlerts.Count -gt 0 -or $configuredRules.Count -gt 0)
    }
}
