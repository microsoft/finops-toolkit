# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Launches the Azure FinOps Multitool interactive GUI.

    .DESCRIPTION
    The Start-FinOpsMultitool command launches a WPF-based GUI application that scans
    an Azure tenant for cost optimization, governance, and FinOps insights. The tool
    authenticates to Azure, discovers all subscriptions, and runs a comprehensive scan
    covering cost trends, orphaned resources, idle VMs, tag hygiene, reservation and
    savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly
    alerts, and policy compliance.

    Results are displayed in an interactive dashboard with export options for Excel,
    CSV, JSON, and Power BI.

    This command requires Windows with WPF support (PowerShell 5.1+ on Windows or
    PowerShell 7+ with Windows Compatibility). It is not supported on Linux or macOS.

    .EXAMPLE
    Start-FinOpsMultitool

    Launches the FinOps Multitool GUI. You will be prompted to authenticate and
    select a tenant to scan.

    .LINK
    https://aka.ms/ftk/Start-FinOpsMultitool
#>
function Start-FinOpsMultitool {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Start-FinOpsMultitool launches a read-only GUI scanner and does not modify system state.')]
    [OutputType([void])]
    param()

    # Validate Windows + WPF availability
    if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
        Write-Error "Start-FinOpsMultitool requires Windows with WPF support. It is not supported on Linux or macOS."
        return
    }

    # Locate the Multitool implementation
    $multitoolRoot = Join-Path -Path $PSScriptRoot -ChildPath '../Private/FinOpsMultitool'
    $mainScript = Join-Path -Path $multitoolRoot -ChildPath 'Start-FinOpsMultitool.ps1'

    if (-not (Test-Path -Path $mainScript)) {
        Write-Error "FinOps Multitool files not found at '$multitoolRoot'. The module installation may be incomplete."
        return
    }

    # Launch the Multitool in its own scope so $PSScriptRoot resolves correctly
    # and $script: variables don't leak into the module scope
    & $mainScript
}
