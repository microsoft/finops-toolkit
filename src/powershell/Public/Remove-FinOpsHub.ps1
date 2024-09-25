# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a FinOps hub instance and optionally keep the storage account hosting cost data.

    .DESCRIPTION
    The Remove-FinOpsHub command deletes a FinOps Hub instance and optionally deletes the storage account hosting cost data.

    The comamnd returns a boolean value indicating whether all resources were successfully deleted.

    .PARAMETER Name
    Required if not specifying InputObject. Name of the FinOps hub instance.

    .PARAMETER ResourceGroupName
    Optional when specifying Name. Resource group name for the FinOps Hub.

    .PARAMETER InputObject
    Required if not specifying Name. Expected object is the output of Get-FinOpsHub.

    .PARAMETER KeepStorageAccount
    Optional. Indicates that the storage account associated with the FinOps Hub should be retained. Default = false.

    .PARAMETER Force
    Optional. Indicates that the hub instance should be deleted without an additional confirmation. Default = false.

    .EXAMPLE
    Remove-FinOpsHub `
        -Name MyHub `
        -ResourceGroupName MyRG `
        -KeepStorageAccount

    ### Remove a FinOps hub instance
    Deletes a FinOps Hub named MyHub and deletes all associated resource except the storage account.
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

        # .PARAMETERSET Delete by name
        [Parameter(ParameterSetName = 'Name')]
        [string]
        $ResourceGroupName,
        
        # .PARAMETERSET Delete by reference
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
        throw $script:LocalizedData.Common_ContextNotFound
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
                $ResourceGroupName = $hub.Resources[0].ResourceGroupName
            }
        }
        else
        {
            $hub = $InputObject
            $Name = $hub.Name
            $ResourceGroupName = $hub.Resources[0].ResourceGroupName
        }

        if (-not $hub)
        {
            throw $script:LocalizedData.Hub_Remove_NotFound -f $Name
        }

        $uniqueId = Get-HubIdentifier -Collection $hub.Resources.Name
        Write-Verbose -Message "Unique identifier: $uniqueId"

        $resources = Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object -FilterScript { $_.Name -like "*$uniqueId*" -and ((-not $KeepStorageAccount) -or $_.ResourceType -ne "Microsoft.Storage/storageAccounts") }

        if ($PSCmdlet.ShouldProcess($Name, 'DeleteFinOpsHub'))
        {
            return ($resources | Remove-AzResource -Force:$Force).Reduce({ $args[0] -and $args[1] }, $true)            
        }
    }
    catch
    {
        throw ($script:LocalizedData.Hub_Remove_Failed -f $_)
    }
}
