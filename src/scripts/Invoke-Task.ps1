# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Executes a build task.

    .DESCRIPTION
    Run this from the /src/scripts folder.

    .PARAMETER Task
    Optional. Name of the task to execute.

    .PARAMETER Major
    Optional. Increments the major version number (x.0). Only applies to version tasks.

    .PARAMETER Minor
    Optional. Increments the minor version number (0.x). Only applies to version tasks.

    .PARAMETER Patch
    Optional. Increments the patch version number (0.0.x). Only applies to version tasks.

    .PARAMETER Prerelease
    Optional. Increments the prerelease version number (0.0.0-ooo.x). Only applies to version tasks.

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Allowed: dev, alpha, preview. Only applies to version tasks.

    .PARAMETER Version
    Optional. Sets the version number to an explicit value. Only applies to version tasks.

    .PARAMETER Reset
    Optional. Indicates whether the BuildHelper module should be re-compiled. Use this when changing build tasks and scripts. Default = false.

    .EXAMPLE
    ./Invoke-Task -Task Build.PsModule

    Executes the "Build.PsModule" task.

    .EXAMPLE
    ./Invoke-Task Version

    Executes the "Version" task.
#>
param (
    [Parameter(Position = 0)]
    [string]
    $Task,

    [switch]
    $Major,

    [switch]
    $Minor,

    [switch]
    $Patch,

    [switch]
    $Prerelease,

    [ValidateSet($null, '', 'dev', 'alpha', 'preview')]
    [string]
    $Label,

    [string]
    $Version,

    [switch]
    $Reset
)

# If -Reset is specified, remove the BuildHelper module so it can be re-compiled
if ($Reset) {
    Remove-Module BuildHelper -ErrorAction SilentlyContinue
    $PSBoundParameters.Remove('Reset') | Out-Null
}

# Don't run unless a task is specified
if ($Task) {
    $start = Join-Path $PSScriptRoot ../../.build/start.ps1
    $output = & $start @PSBoundParameters

    # Hide verbose output for tasks that are getters
    $trimOutput = $Task -in @(
        'Version'
    )

    if ($trimOutput) {
        ($output | Join-String) -replace "^.*Task /$Task([^/].*)Done /$Task .*$", '$1'
    } else {
        $output
    }
}
