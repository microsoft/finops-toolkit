# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a FinOps hub instance and optionally keep the storage account hosting cost data.

    .PARAMETER Name
    Required when specifying Name. Name of the FinOps Hub.

    .PARAMETER ResourceGroupName
    Optional when specifying Name. Resource Group Name for the FinOps Hub.

    .PARAMETER InputObject
    Required when specifying InputObject. Expected object is the output of Get-FinOpsHub.

    .PARAMETER KeepStorageAccount
    Optional. Indicates that the storage account associated with the FinOps Hub should be retained.

    .EXAMPLE
    Remove-FinOpsHub -Name MyHub -ResourceGroupName MyRG -KeepStorageAccount

    Deletes a FinOps Hub named MyHub and deletes all associated resource except the storagea ccount.
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

        if ($PSCmdlet.ParameterSetName -eq 'Name')
        {
            if (-not [string]::IsNullOrEmpty($ResourceGroupName))
            {
                $hub = Get-FinOpsHub -Name $Name -ResourceGroupName $ResourceGroupName
            }
            else
            {
                $hub = Get-FinOpsHub -Name $Name
            }
        }
        else
        {
            $hub = $InputObject
            $Name = $hub.Name
        }

        if (-not $hub)
        {
            throw $script:localizedData.FinOpsHubNotFound -f $Name
        }

        # Extract unique identifier from Key Vault name
        $kv = $hub.Resources | Where-Object ResourceType -eq "Microsoft.KeyVault/vaults"
        $uniqueId = $kv[0].Substring($kv[0].LastIndexOf("-") + 1)

        $resources = Get-AzResource -ResourceGroupName $ResourceGroup | Where-Object Name -like "*$uniqueId*" | Where-Object {(-not $KeepStorageAccount) -or $_.ResourceType -ne "Microsoft.Storage/storageAccounts"}

        if ($PSCmdlet.ShouldProcess($Name, 'DeleteFinOpsHub'))
        {
            $resources | Remove-AzResource -Force:$Force
        }
    }
    catch
    {
        throw $script:localizedData.DeleteFinOpsHub
    }
}
