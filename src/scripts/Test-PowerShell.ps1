# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Runs Pester tests.

    .PARAMETER Cost
    Optional. Indicates whether to run Cost Management tests.

    .PARAMETER Data
    Optional. Indicates whether to run open data tests.

    .PARAMETER Exports
    Optional. Indicates whether to run Cost Management export tests.

    .PARAMETER FOCUS
    Optional. Indicates whether to run FOCUS tests.

    .PARAMETER Hubs
    Optional. Indicates whether to run FinOps hubs tests.

    .PARAMETER Toolkit
    Optional. Indicates whether to run FinOps toolkit tests.
#>
[CmdletBinding()]
param (
    [switch]
    $Cost,

    [switch]
    $Data,

    [switch]
    $Exports,
    
    [switch]
    $FOCUS,
    
    [switch]
    $Hubs,

    [switch]
    $Toolkit
)

$testsToRun = @()
if ($Cost) { $testsToRun += '*-FinOpsCost*' }
if ($Data) { $testsToRun += '*-OpenData*', '*-FinOpsPricingUnit*', '*-FinOpsRegion*', '*-FinOpsService*' }
if ($Exports) { $testsToRun += '*-FinOpsCostExport*' }
if ($FOCUS) { $testsToRun += '*-FinOpsSchema*' }
if ($Hubs) { $testsToRun += '*-FinOpsHub*' }
if ($Toolkit) { $testsToRun += '*FinOpsToolkit.Tests.ps1' }

Push-Location
Set-Location "$PSScriptRoot/../powershell/Tests/Unit"

if ($testsToRun)
{
    $testsToRun | Select-Object -Unique | ForEach-Object { 
        Write-Host "Running $_"
        Invoke-Pester -Path $_ -Output Detailed
    }
}
else
{
    Invoke-Pester -Path * -Output Detailed
}

Pop-Location
