# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Backward-compatible entry point for the FinOps Explorer TUI.

    .DESCRIPTION
    Start-FinOpsMultitool is retained for existing scripts and sessions. It accepts
    the same parameters and forwards them to Start-FinOpsExplorer.

    .PARAMETER SubscriptionId
    Optional subscription ID in the current tenant.

    .PARAMETER OutputPath
    Optional local parent directory for reports.

    .PARAMETER Scans
    Optional list of scans to run.

    .PARAMETER DataSource
    Optional data source: Hub, Export, API, or GraphOnly.

    .PARAMETER NonInteractive
    Runs without prompting.

    .PARAMETER Accessible
    Uses numbered prompts instead of interactive arrow-key menus.

    .EXAMPLE
    Start-FinOpsMultitool -NonInteractive -Scans Get-OrphanedResources

    Runs the same FinOps Explorer scan as Start-FinOpsExplorer with these options.

    .LINK
    https://aka.ms/ftk/Start-FinOpsMultitool
#>
function Start-FinOpsMultitool {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Compatibility wrapper for a read-only interactive scanner.')]
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

    if (-not (Get-Command -Name 'Start-FinOpsExplorer' -CommandType Function -ErrorAction SilentlyContinue)) {
        $explorerScript = Join-Path -Path $PSScriptRoot -ChildPath 'Start-FinOpsExplorer.ps1'
        if (-not (Test-Path -LiteralPath $explorerScript -PathType Leaf)) {
            throw "FinOps Explorer entry point not found at '$explorerScript'. The module installation may be incomplete."
        }
        . $explorerScript
    }

    Start-FinOpsExplorer @PSBoundParameters
}