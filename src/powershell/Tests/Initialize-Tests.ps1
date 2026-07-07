# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../FinOpsToolkit.psm1"
Import-Module Pester -Global -ErrorAction Stop

if (-not (Get-Command Assert-MockCalled -CommandType Function -ErrorAction SilentlyContinue)) {
    function Assert-MockCalled {
        [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [string]$CommandName,

            [Parameter(Position = 1)]
            [int]$Times = 1,

            [ScriptBlock]$ParameterFilter = { $true },

            [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
            [scriptblock]$ExclusiveFilter,

            [string]$ModuleName,

            [string]$Scope = 0,
            [switch]$Exactly
        )

        Should -Invoke @PSBoundParameters
    }
}

BeforeAll {
    # Bring the Monitor functions in to simplify debugging
    . "$PSScriptRoot/../../scripts/Monitor.ps1"
}

function Get-FinOpsHubRequiredResourceProvider
{
    return @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
}
