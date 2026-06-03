# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# FINOPSMULTITOOL.PSM1
# MODULE LOADER FOR STANDALONE (NON-GUI) USE
###########################################################################
# Purpose: Dot-sources all helpers and analysis modules so they can be
#          imported via Import-Module without launching the WPF GUI.
#
# Usage:
#   Import-Module .\FinOpsMultitool.psm1
#   $results = Get-OrphanedResources -Subscriptions $subs -TenantId $tid
#
# The GUI entry point remains Start-FinOpsMultitool.ps1 (unchanged).
###########################################################################

# -- Ensure required Az modules are loaded ---------------------------------
# Some terminals have incomplete PSModulePath — add the edition-appropriate user
# module path. In PowerShell 7 (Core) we must NOT prepend the Windows PowerShell
# 5.1 module path: it can shadow Core's modules with older, incompatible versions
# (for example an old Az.Accounts that then blocks a newer Az.Storage from loading).
$userModDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
if ($userModDir -and (Test-Path $userModDir) -and $env:PSModulePath -notlike "*$userModDir*") {
    $env:PSModulePath = "$userModDir;$env:PSModulePath"
}
if ($PSEdition -eq 'Desktop') {
    $userModDir5 = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
    if ($userModDir5 -and (Test-Path $userModDir5) -and $env:PSModulePath -notlike "*$userModDir5*") {
        $env:PSModulePath = "$userModDir5;$env:PSModulePath"
    }
}

foreach ($azMod in @('Az.Accounts', 'Az.Storage', 'Az.ResourceGraph')) {
    if (-not (Get-Module $azMod)) {
        Import-Module $azMod -ErrorAction SilentlyContinue
    }
}
# -- Helpers (runspace pool, REST retry, ARG wrapper, MG-scope state) ----
$helpersPath = Join-Path $PSScriptRoot 'modules\helpers'
. (Join-Path $helpersPath 'Get-PlainAccessToken.ps1')
. (Join-Path $helpersPath 'Invoke-AzRestMethodWithRetry.ps1')
. (Join-Path $helpersPath 'Search-AzGraphSafe.ps1')
. (Join-Path $helpersPath 'MgCostScope.ps1')
. (Join-Path $helpersPath 'Read-FinOpsHubData.ps1')
. (Join-Path $helpersPath 'Resolve-CostDataSource.ps1')

# -- Set script-scope root (some modules reference $script:ScriptRootDir) -
$script:ScriptRootDir = $PSScriptRoot

# -- Analysis Modules ----------------------------------------------------
$modulePath = Join-Path $PSScriptRoot 'modules'
. (Join-Path $modulePath 'Initialize-Scanner.ps1')
. (Join-Path $modulePath 'Get-TenantHierarchy.ps1')
. (Join-Path $modulePath 'Get-ContractInfo.ps1')
. (Join-Path $modulePath 'Get-CostData.ps1')
. (Join-Path $modulePath 'Get-ResourceCosts.ps1')
. (Join-Path $modulePath 'Get-TagInventory.ps1')
. (Join-Path $modulePath 'Get-CostByTag.ps1')
. (Join-Path $modulePath 'Get-AHBOpportunities.ps1')
. (Join-Path $modulePath 'Get-ReservationAdvice.ps1')
. (Join-Path $modulePath 'Get-OptimizationAdvice.ps1')
. (Join-Path $modulePath 'Get-TagRecommendations.ps1')
. (Join-Path $modulePath 'Get-CostTrend.ps1')
. (Join-Path $modulePath 'Deploy-ResourceTag.ps1')
. (Join-Path $modulePath 'Get-BillingStructure.ps1')
. (Join-Path $modulePath 'Get-CommitmentUtilization.ps1')
. (Join-Path $modulePath 'Get-OrphanedResources.ps1')
. (Join-Path $modulePath 'Get-BudgetStatus.ps1')
. (Join-Path $modulePath 'Get-MaccCommitment.ps1')
. (Join-Path $modulePath 'Get-AnomalyAlerts.ps1')
. (Join-Path $modulePath 'Get-SavingsRealized.ps1')
. (Join-Path $modulePath 'Get-PolicyInventory.ps1')
. (Join-Path $modulePath 'Get-PolicyRecommendations.ps1')
. (Join-Path $modulePath 'Deploy-PolicyAssignment.ps1')
. (Join-Path $modulePath 'Get-StorageTierAdvice.ps1')
. (Join-Path $modulePath 'Get-IdleVMs.ps1')
. (Join-Path $modulePath 'Get-LegacyResources.ps1')
. (Join-Path $modulePath 'Get-UnitEconomics.ps1')
. (Join-Path $modulePath 'Get-AIWorkloadMetrics.ps1')
. (Join-Path $modulePath 'Get-CarbonMetrics.ps1')
. (Join-Path $modulePath 'New-PowerBITemplate.ps1')
