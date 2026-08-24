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

    Consoles that cannot drive the arrow-key menus, such as remoting sessions and some
    editor terminals, automatically fall back to numbered prompts. Use NonInteractive to
    run with no prompts at all.

    .PARAMETER SubscriptionId
    Optional subscription ID to scope the scan to a single subscription. When omitted,
    the tool discovers all accessible subscriptions.

    .PARAMETER OutputPath
    Optional directory for exported result files. Defaults to a FinOpsResults folder in your
    home directory.

    .PARAMETER Scans
    Optional list of scans to run, replacing the default selection. Accepts either the
    scan function name, such as Get-OrphanedResources, or its menu label, such as
    'Orphaned Resources'. Use 'All' to select every scan. An unrecognized name is an error.

    .PARAMETER DataSource
    Optional data source, which skips the data source prompt. Hub reads a deployed FinOps
    hub, API queries Cost Management directly, and GraphOnly skips the cost scans. Hub
    falls back to API when no hub is found in scope.

    .PARAMETER NonInteractive
    Runs without prompting, for automation and scheduled jobs. Every choice comes from the
    parameters or their defaults: all accessible subscriptions in the current tenant unless
    SubscriptionId is set, a detected hub or the Cost Management API unless DataSource is
    set, and results are exported only when OutputPath is supplied.

    .EXAMPLE
    Start-FinOpsMultitool

    Launches the FinOps Multitool TUI. You will be prompted to authenticate and
    select the subscriptions and modules to scan.

    .EXAMPLE
    Start-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'

    Launches the TUI scoped to a single subscription.

    .EXAMPLE
    Start-FinOpsMultitool -NonInteractive -Scans Get-OrphanedResources, Get-IdleVMs -OutputPath './results'

    Runs two scans without prompting and writes the CSV output to the results folder,
    which is the shape to use from a pipeline or scheduled job.

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
        [string]$OutputPath,

        [Parameter()]
        [string[]]$Scans,

        [Parameter()]
        [ValidateSet('Hub', 'API', 'GraphOnly')]
        [string]$DataSource,

        [Parameter()]
        [switch]$NonInteractive
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
