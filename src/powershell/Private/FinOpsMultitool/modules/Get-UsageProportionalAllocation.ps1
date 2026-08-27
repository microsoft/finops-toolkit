# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-USAGEPROPORTIONALALLOCATION.PS1
# TELEMETRY-KEYED SHOWBACK FOR SHARED PLATFORMS (AKS / APIM / AOAI)
###########################################################################
# Purpose: Split the billed cost of a shared platform across SUB-RESOURCE
#          consumers (k8s namespace, APIM product, OpenAI deployment) by a
#          usage signal pulled from telemetry - for showback/chargeback.
# Date: Created for FinOps Multitool shared-cost allocation
#
# Description:
# Native Azure cost allocation rules can only key on SubscriptionId,
# ResourceGroupName or Tag. When the consumer you want to charge is a
# Kubernetes namespace, an APIM product/subscription, or an Azure OpenAI
# model deployment, there is NO billing dimension for it - so the only fair
# split is telemetry-driven. This tool reads a usage key from a Log Analytics
# workspace (Container Insights for AKS, workspace-based Application Insights
# for APIM token metrics, Azure Monitor metrics for OpenAI tokens) and
# apportions the shared pool cost accordingly.
#
# SHOWBACK GUARD: these consumers are NOT Azure billing dimensions, so the
# result is Mode=Showback, RuleTargets is always empty, and it can NEVER be
# written via set_cost_allocation_rule. It is for reporting / internal
# chargeback only.
#
# ── Parameters ──────────────────────────────────────────────────
# Preset             aksNamespace | apimTokens | openAiTokens | custom
# WorkspaceId        Log Analytics workspace GUID holding the telemetry
# SharedResourceIds  Resource IDs whose billed cost forms the pool
# SharedResourceGroup Resource group holding the shared platform
# PoolAmount         Explicit pool cost (use instead of resolving resources)
# LookbackDays       Telemetry window (default 30)
# DimensionName      Override the consumer dimension (e.g. APIM 'API ID')
# WeightingQuery     Full KQL override - must return columns Consumer, Weight
#
# Prerequisites:
# - Az.OperationalInsights + read on the workspace
# - The platform must emit the telemetry (Container Insights / App Insights
#   token metrics / AOAI diagnostic metrics)
#
# Usage: Get-UsageProportionalAllocation -Preset aksNamespace `
#          -SharedResourceGroup rg-aks -WorkspaceId <guid>
###########################################################################

# -- Preset registry: each preset maps a shared platform to a usage key ----
# Query templates use {lb} (lookback days) and {dim} (dimension name). Each
# query MUST return two columns: Consumer (string) and Weight (number).
function Get-TelemetryPreset {
    param([string]$Name)

    $presets = @{
        aksNamespace = @{
            ConsumerDimension = 'KubernetesNamespace'
            Source            = 'Container Insights (Log Analytics)'
            DefaultDimension  = 'container.azm.ms/namespace'
            Query             = @'
InsightsMetrics
| where TimeGenerated >= ago({lb}d)
| where Name in ('cpuUsageNanoCores', 'memoryWorkingSetBytes')
| extend ns = tostring(parse_json(Tags)['container.azm.ms/namespace'])
| where isnotempty(ns)
| summarize cpuCores = avgif(Val, Name == 'cpuUsageNanoCores') / 1000000000.0, memGB = avgif(Val, Name == 'memoryWorkingSetBytes') / 1073741824.0 by ns
| extend Weight = cpuCores + (memGB / 4.0)
| project Consumer = ns, Weight
'@
        }
        apimTokens   = @{
            ConsumerDimension = 'ApimConsumer'
            Source            = 'Application Insights (workspace-based)'
            DefaultDimension  = 'Subscription Id'
            Query             = @'
AppMetrics
| where TimeGenerated >= ago({lb}d)
| where Name in ('Total Tokens', 'Tokens', 'TotalTokens', 'total_tokens')
| extend consumer = tostring(Properties['{dim}'])
| where isnotempty(consumer)
| summarize Weight = sum(Sum) by Consumer = consumer
'@
        }
        openAiTokens = @{
            ConsumerDimension = 'OpenAIResource'
            Source            = 'Azure Monitor metrics (Cognitive Services)'
            DefaultDimension  = 'Resource'
            Query             = @'
AzureMetrics
| where TimeGenerated >= ago({lb}d)
| where ResourceProvider == 'MICROSOFT.COGNITIVESERVICES'
| where MetricName in ('ProcessedPromptTokens', 'GeneratedTokens', 'TokenTransaction', 'ProcessedInferenceTokens')
| summarize Weight = sum(Total) by Consumer = Resource
'@
        }
    }

    if ($presets.ContainsKey($Name)) { return $presets[$Name] }
    return $null
}

# -- Generalized telemetry weighting provider ------------------------------
function Get-TelemetryWeighting {
    param(
        [string]$WorkspaceId,
        [string]$Preset = 'aksNamespace',
        [int]$LookbackDays = 30,
        [string]$Query,
        [string]$DimensionName
    )

    $weights = @{}
    $lb = if ($LookbackDays -gt 0) { $LookbackDays } else { 30 }

    $def = Get-TelemetryPreset -Name $Preset
    if (-not $def -and -not $Query) {
        return [PSCustomObject]@{
            Ok                = $false
            ConsumerDimension = 'Unknown'
            Source            = 'Unknown'
            BillingWritable   = $false
            Weights           = $weights
            QueryUsed         = $null
            Note              = "Unknown preset '$Preset'. Use aksNamespace, apimTokens, openAiTokens, or supply a weightingQuery returning Consumer, Weight."
        }
    }

    $dimName = if ($DimensionName) { $DimensionName } elseif ($def) { $def.DefaultDimension } else { '' }
    $kql = if ($Query) { $Query } else { $def.Query }
    $kql = $kql.Replace('{lb}', "$lb").Replace('{dim}', $dimName)

    $consumerDim = if ($def) { $def.ConsumerDimension } else { 'Custom' }
    $source = if ($def) { $def.Source } else { 'Custom query (Log Analytics)' }

    if (-not $WorkspaceId) {
        return [PSCustomObject]@{
            Ok                = $false
            ConsumerDimension = $consumerDim
            Source            = $source
            BillingWritable   = $false
            Weights           = $weights
            QueryUsed         = $kql
            Note              = 'workspaceId (the Log Analytics workspace GUID) is required to read telemetry.'
        }
    }

    $note = ''
    try {
        $qr = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $kql -ErrorAction Stop
        foreach ($row in @($qr.Results)) {
            $c = [string]$row.Consumer
            if (-not $c) { continue }
            $w = 0.0; [double]::TryParse([string]$row.Weight, [ref]$w) | Out-Null
            if ($w -gt 0) { $weights[$c] = $w }
        }
        if ($weights.Count -eq 0) {
            $note = 'Telemetry query returned no rows. Verify the workspace has the expected data and that the query returns Consumer + Weight columns.'
        }
    }
    catch {
        $note = "Telemetry query failed: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Ok                = ($weights.Count -gt 0)
        ConsumerDimension = $consumerDim
        Source            = $source
        BillingWritable   = $false
        Weights           = $weights
        QueryUsed         = $kql
        Note              = $note
    }
}

# -- Main: telemetry-keyed showback split of a shared pool -----------------
function Get-UsageProportionalAllocation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [string[]]$SharedResourceIds,

        [Parameter()]
        [string]$SharedResourceGroup,

        [Parameter()]
        [double]$PoolAmount = 0,

        [Parameter()]
        [string]$Preset = 'aksNamespace',

        [Parameter()]
        [string]$WorkspaceId,

        [Parameter()]
        [int]$LookbackDays = 30,

        [Parameter()]
        [string]$DimensionName,

        [Parameter()]
        [string]$WeightingQuery,

        [Parameter()]
        [object[]]$HubData
    )

    if (-not $WorkspaceId) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'Provide workspaceId - the Log Analytics workspace GUID that holds the platform telemetry (Container Insights / App Insights).'
        }
    }
    $haveResources = ($SharedResourceIds -and $SharedResourceIds.Count -gt 0) -or $SharedResourceGroup
    if (-not $haveResources -and $PoolAmount -le 0) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'Provide the shared pool: sharedResourceIds / sharedResourceGroup (cost is resolved), or poolAmount (an explicit cost to split).'
        }
    }

    $scanSubs = @($Subscriptions | ForEach-Object { $_.Id })

    # -- Size the shared pool ---------------------------------------------
    $poolTotal = 0.0
    $poolResources = @()
    $currency = 'USD'
    $source = 'Explicit'

    if ($haveResources) {
        Write-Host '  Resolving shared platform resources...' -ForegroundColor Cyan
        $pool = Resolve-SharedCostPool -SubscriptionIds $scanSubs -ResourceIds $SharedResourceIds -ResourceGroup $SharedResourceGroup
        if (@($pool).Count -gt 0) {
            $hubSubs = @($pool | ForEach-Object { $_.SubscriptionId } | Select-Object -Unique)
            $maps = Get-AllocationCostMaps -SubscriptionIds $hubSubs -HubData $HubData
            $currency = $maps.Currency
            $source = $maps.Source
            foreach ($p in $pool) {
                $c = if ($maps.ByResource.ContainsKey($p.Id)) { [double]$maps.ByResource[$p.Id] } else { 0.0 }
                $poolTotal += $c
                $poolResources += [PSCustomObject]@{ Name = $p.Name; Type = $p.Type; Cost = [math]::Round($c, 2) }
            }
        }
    }

    if ($poolTotal -le 0 -and $PoolAmount -gt 0) {
        $poolTotal = $PoolAmount
        $source = 'Explicit'
    }

    if ($poolTotal -le 0) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'The shared pool cost resolved to 0. Check the resource IDs / resource group, or pass poolAmount explicitly.'
        }
    }

    # -- Telemetry usage key ----------------------------------------------
    Write-Host "  Reading telemetry usage ($Preset)..." -ForegroundColor Cyan
    $tw = Get-TelemetryWeighting -WorkspaceId $WorkspaceId -Preset $Preset -LookbackDays $LookbackDays -Query $WeightingQuery -DimensionName $DimensionName

    $weights = $tw.Weights
    $totalWeight = 0.0
    foreach ($v in $weights.Values) { $totalWeight += [double]$v }

    $allocations = @()
    $notes = @()
    if ($totalWeight -gt 0) {
        foreach ($key in $weights.Keys) {
            $w = [double]$weights[$key]
            $pct = $w / $totalWeight
            $allocations += [PSCustomObject]@{
                Consumer      = $key
                WeightUnits   = [math]::Round($w, 4)
                WeightPct     = [math]::Round($pct * 100, 2)
                AllocatedCost = [math]::Round($poolTotal * $pct, 2)
            }
        }
        $allocations = @($allocations | Sort-Object AllocatedCost -Descending)
    }
    else {
        $notes += 'No usage telemetry resolved, so the pool was not split. ' + $tw.Note
    }

    $notes += "Showback only: $($tw.ConsumerDimension) is not an Azure billing dimension, so this allocation CANNOT be written as a native cost allocation rule (set_cost_allocation_rule). Use it for internal chargeback / reporting."
    if ($tw.Note -and $totalWeight -gt 0) { $notes += $tw.Note }

    return [PSCustomObject]@{
        HasData           = $true
        Mode              = 'Showback'
        BillingWritable   = $false
        Preset            = $Preset
        ConsumerDimension = $tw.ConsumerDimension
        Source            = $tw.Source
        CostSource        = $source
        Period            = 'MonthToDate'
        Currency          = $currency
        SharedPool        = [PSCustomObject]@{
            TotalCost = [math]::Round($poolTotal, 2)
            Resources = @($poolResources | Sort-Object Cost -Descending)
        }
        Allocations       = $allocations
        RuleTargets       = @()
        Note              = ($notes -join ' ')
    }
}
