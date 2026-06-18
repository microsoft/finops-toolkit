# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Launches the Azure FinOps Multitool interactive terminal UI.

    .DESCRIPTION
    The Start-FinOpsMultitool command launches an interactive terminal UI (TUI) that
    scans an Azure tenant for cost optimization, governance, and FinOps insights. The
    tool authenticates to Azure, discovers subscriptions, and runs the scan modules you
    select - covering cost trends, orphaned resources, idle VMs, tag hygiene, reservation
    and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly
    alerts, and policy compliance.

    Results are rendered in the terminal with export options for Excel, CSV, JSON, and
    Power BI.

    The scan modules are read-only. The TUI runs on PowerShell 5.1+ (Windows) or
    PowerShell 7+ (cross-platform) and requires the Az modules (Az.Accounts,
    Az.ResourceGraph, Az.Storage) and Reader access on the target scope.

    .PARAMETER SubscriptionId
    Optional subscription ID to scope the scan to a single subscription. When omitted,
    the tool discovers all accessible subscriptions.

    .PARAMETER OutputPath
    Optional directory for exported result files. Defaults to the tool's working folder.

    .EXAMPLE
    Start-FinOpsMultitool

    Launches the FinOps Multitool TUI. You will be prompted to authenticate and
    select the subscriptions and modules to scan.

    .EXAMPLE
    Start-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'

    Launches the TUI scoped to a single subscription.

    .LINK
    https://aka.ms/ftk/Start-FinOpsMultitool
#>
function Start-FinOpsMultitool {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Start-FinOpsMultitool launches a read-only interactive scanner and does not modify system state.')]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$SubscriptionId,

        [Parameter()]
        [string]$OutputPath
    )

    # Locate the Multitool TUI implementation
    $multitoolRoot = Join-Path -Path $PSScriptRoot -ChildPath '../Private/FinOpsMultitool'
    $tuiScript = Join-Path -Path $multitoolRoot -ChildPath 'Invoke-FinOpsMultitool.ps1'

    if (-not (Test-Path -Path $tuiScript)) {
        Write-Error "FinOps Multitool files not found at '$multitoolRoot'. The module installation may be incomplete."
        return
    }

    # Dot-source the TUI launcher so Invoke-FinOpsMultitool is defined here, then
    # invoke it. The TUI imports its own module set (FinOpsMultitool.psm1) on launch,
    # so it stays self-contained and does not leak $script: state into the module.
    . $tuiScript
    Invoke-FinOpsMultitool @PSBoundParameters
}
