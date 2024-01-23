# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Wrapper for $PSCmdlet.ShouldProcess() used to support mocking in tests.

    .PARAMETER Context
    Required. Always use $PSCmdlet.

    .PARAMETER Target
    Required. Name of the target object to perform the Action on. Used for logging purposes as part of ShouldProcess.

    .PARAMETER Action
    Required. Action to perform. Used for logging purposes as part of ShouldProcess.

    .EXAMPLE
    if (Test-ShouldProcess $PSCmdlet Foo Deploy) { ... }

    Checks if the "Deploy" action should be run based on the -WhatIf parameter for the calling command and executes the script block if it should.
#>
function Test-ShouldProcess
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Context,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $Target,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $Action
    )

    return $Context.ShouldProcess($Target, $Action)
}