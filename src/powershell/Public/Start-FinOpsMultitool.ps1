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

    Results are rendered in the terminal and saved automatically on the machine running
    the command. Each run gets a private folder with one CSV file per selected scan,
    an HTML report, and a text summary. Failed or empty scans have a CSV status record.

    The scan modules are read-only. The TUI requires PowerShell 7 or later on Windows,
    macOS, and Linux, the Az modules (Az.Accounts,
    Az.ResourceGraph, Az.Storage) and Reader access on the target scope.

    Consoles that cannot drive the arrow-key menus, such as remoting sessions and some
    editor terminals, automatically fall back to numbered prompts. Use Accessible to
    select numbered prompts in any console, or NonInteractive to run with no prompts at all.

    .PARAMETER SubscriptionId
    Optional subscription ID in the current tenant. An unresolved or mismatched
    subscription stops the scan without searching other tenants or widening scope.
    When omitted, the tool discovers accessible subscriptions in the selected tenant.

    .PARAMETER OutputPath
    Optional local parent directory for reports. Each run creates a new timestamped
    subfolder and never overwrites earlier reports. The default is FinOpsToolkit/Multitool/Reports
    under the current user's LocalApplicationData directory, usually LOCALAPPDATA on Windows.
    Git repositories, UNC paths, mapped Windows network drives, symbolic links, and
    junctions are rejected. Unix network mounts aren't detected; choose a local filesystem.
    Reports contain sensitive cost and resource data; keep custom destinations outside synced folders.

    .PARAMETER Scans
    Optional list of scans to run, replacing the default selection. Accepts either the
    scan function name, such as Get-OrphanedResources, or its menu label, such as
    'Orphaned Resources'. Use 'All' on its own to select every scan. An unrecognized name is an error.
    Explicit null or empty lists, and empty entries, are rejected before the tool starts.

    .PARAMETER DataSource
    Optional data source, which skips the data source prompt. Hub reads a configured
    Kusto endpoint or a discovered FinOps hub. Export discovers existing CSV/CSV.gz Cost
    Management exports without requiring a hub, looking at definitions for the selected
    subscriptions, their management-group ancestors, and linked billing accounts, and at
    storage accounts in the selected subscriptions. A definition found at a wider scope can
    deliver to storage outside the selected subscriptions, and that destination is read. It
    reads one chosen export and filters rows to the selected subscriptions. ActualCost or FOCUS
    BilledCost is required; Parquet and local-file input aren't supported on this path.
    API queries Cost Management directly, and
    GraphOnly skips cost-dependent scans and orphan cost enrichment; remaining scans can
    still use Azure Monitor, Advisor, policy, and carbon APIs. API and GraphOnly ignore FINOPS_HUB_KUSTO_URI and
    don't preload hub data. An explicit Hub selection fails if no hub source is available.
    Select API separately to run a live scan. Export also ignores FINOPS_HUB_KUSTO_URI;
    a failed export read never switches to live costs. NonInteractive Export requires
    exactly one readable discovered candidate. Export mode supports cost totals, resource costs,
    cost by tag, and the months present in that export run; separate financial API scans are excluded.

    .PARAMETER NonInteractive
    Runs without prompting, for automation and scheduled jobs. Every choice comes from the
    parameters or their defaults: all accessible subscriptions in the current tenant unless
    SubscriptionId is set, a configured or detected hub or the Cost Management API unless DataSource is
    set. Failed automatic hub discovery warns and continues to API in the same scope,
    even when every probe fails. Explicit Hub selections never switch to API.
    Requires an existing Azure context; authenticate with the intended identity using
    Connect-AzAccount before running. Reports are saved automatically even when OutputPath is omitted.

    .PARAMETER Accessible
    Uses numbered prompts without clearing the screen or repainting menu rows, even in a
    console that supports them. Stays in the signed-in tenant; sign in separately to change tenants.
    NonInteractive takes precedence and disables all prompts when both switches are supplied.

    .EXAMPLE
    Start-FinOpsMultitool

    Launches the FinOps Multitool TUI. You will be prompted to authenticate and
    select the subscriptions and modules to scan.

    .EXAMPLE
    Start-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'

    Launches the TUI scoped to a single subscription.

    .EXAMPLE
    Start-FinOpsMultitool -NonInteractive -Scans Get-OrphanedResources, Get-IdleVMs

    Requires an existing authenticated Azure context. Runs two scans without prompting and saves CSV, HTML, and text reports in a new
    private run folder under the current user's local application data.

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
        [ValidateNotNullOrEmpty()]
        [string[]]$Scans,

        [Parameter()]
        [ValidateSet('Hub', 'Export', 'API', 'GraphOnly')]
        [string]$DataSource,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$Accessible
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "FinOps Multitool requires PowerShell 7 or later. This session is PowerShell $($PSVersionTable.PSVersion). Open PowerShell 7 with 'pwsh', import the module there, and run Start-FinOpsMultitool again. No scan was started."
    }

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
