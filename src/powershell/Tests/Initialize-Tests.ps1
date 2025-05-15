# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../FinOpsToolkit.psm1"

BeforeAll {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidGlobalVars", "", Justification = "Used for testing only")]
    param()

    # Bring the Monitor functions in to simplify debugging
    . "$PSScriptRoot/../../scripts/Monitor.ps1"

    $global:ftk_InitializeTests_Hubs_RequiredRPs = @( 'Microsoft.CostManagementExports', 'Microsoft.EventGrid' )
}
