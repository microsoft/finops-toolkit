# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a Cost Management export and optionally data associated with the export.

    .PARAMETER Name
    Name of the Cost Management export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER RemoveData
    Optional. Indicates that all cost data associated with the Export scope should be deleted.

    .PARAMETER APIVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

    .EXAMPLE
    Remove-FinOpsCostExport -Name MyExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -RemoveData

    Deletes a Cost Management export named MyExport scoped to /subscriptions/00000000-0000-0000-0000-000000000000, and deletes all exported data from the related storage account.
#>

function Remove-FinOpsHub
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty ()]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Name')]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        [ValidateNotNullOrEmpty ()]
        [psobject]
        $InputObject,

        [Parameter(ParameterSetName = 'Name')]
        [Parameter(ParameterSetName = 'Object')]
        [switch]
        $KeepStorageAccount,

        [Parameter(ParameterSetName = 'Name')]
        [Parameter(ParameterSetName = 'Object')]
        [switch]
        $Force
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:localizedData.ContextNotFound
    }

    try
    {

        $fhO = $null

        if ($PSCmdlet.ParameterSetName -eq 'Name')
        {
            if (-not [string]::IsNullOrEmpty($ResourceGroupName))
            {
                $fhO = Get-FinOpsHub -Name $Name -ResourceGroupName $ResourceGroupName
            }
            else
            {
                $fhO = Get-FinOpsHub -Name $Name
            }
        }
        else
        {
            $fhO = $InputObject
        }

        # TODO: $Name is not available if InputObject provided
        if (-not $fhO)
        {
            throw $script:localizedData.FinOpsHubNotFound -f $Name
        }

        # Extract unique identifier from Key Vault name
        $kv = $fhO.Resources | Where-Object ResourceType -eq "Microsoft.KeyVault/vaults"
        $uniqueId = $kv[0].Substring($kv[0].LastIndexOf("-") + 1)

        $resources = $null
        if ($KeepStorageAccount)
        {
            $resources = Get-AzResource -ResourceGroupName $ResourceGroup | Where-Object Name -like "*$uniqueId*" | Where-Object ResourceType -ne "Microsoft.Storage/storageAccounts"
        }
        else {
            $resources = Get-AzResource -ResourceGroupName $ResourceGroup | Where-Object Name -like "*$uniqueId*"
        }

        #$resources | ft ResourceId, Name, ResourceType

        if ($PSCmdlet.ShouldProcess($Name, 'DeleteFinOpsHub'))
        {
            $resources | Remove-AzResource -Force:$Force -AsJob
        }
    }
    catch
    {
        throw $script:localizedData.DeleteFinOpsHub
    }
}
