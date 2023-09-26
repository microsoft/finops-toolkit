# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Executes a build task.

    .DESCRIPTION
    Run this from the /src/scripts folder.

    .PARAMETER Task
    Required. Name of the task to execute.

    .PARAMETER Silent
    Optional. Indicates whether Invoke-Build should hide verbose build output. Default = false.

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
