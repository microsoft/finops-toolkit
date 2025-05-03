# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Stops monitoring a scope within a FinOps hub instance.

    .DESCRIPTION
    The Remove-FinOpsHubScope command removes a scope from being monitored by a FinOps hub instance. Data related to that scope is kept by default. To remove the data, use the -RemoveData option.

    .PARAMETER Id
    Required resource ID of the scope to remove.

    .PARAMETER HubName
    Required. Name of the FinOps hub instance.

    .PARAMETER HubResourceGroupName
    Optional. Name of the resource group the FinOps hub was deployed to.

    .PARAMETER RemoveData
    Optional. Indicates whether to remove data for this scope from storage. Default = false

    .EXAMPLE
    Remove-FinOpsHubScope -Id "/providers/Microsoft.Billing/billingAccounts/123" -HubName "FooHub"

    Deletes the exports configured to use the FooHub hub instance. Existing data is retained in the storage account.

    .EXAMPLE
    Remove-FinOpsHubScope -Id "/subscriptions/##-#-#-#-###" -HubName "FooHub" -RemoveData

    Deletes the exports configured to use the FooHub hub instance and removes data for that scope.

    .LINK
    https://aka.ms/ftk/Remove-FinOpsHubScope
#>
function Remove-FinOpsHubScope
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $HubName,

        [Parameter()]
        [string]
        $HubResourceGroupName,

        [Parameter()]
        [switch]
        $RemoveData
    )

    try
    {
        $hub = Get-FinOpsHub -Name $HubName -ResourceGroupName $HubResourceGroupName
        $hubStorage = $hub.Resources | Where-Object { $_.Type.ToLower() -eq 'microsoft.storage/storageaccounts' }
        $hubStorageId = $hubStorage.ResourceId
        $exports = Get-FinOpsCostExport -Scope $Id | Where-Object { $hubStorageId -contains $_.StorageAccountId }

        # Delete the exports
        foreach ($export in $exports)
        {
            if ($PSCmdlet.ShouldProcess("$($export.Name) export", "Delete"))
            {
                Write-Verbose -Message "Deleting Cost Management export $($export.Name) from storage account $($storageAccount.Name)."
                Remove-FinOpsCostExport -Scope $Id -Name $export.Name -RemoveData:$RemoveData
                Write-Verbose -Message "Complete: Deleted Cost Management export $($export.Name) from storage account $($export.StorageAccountId.Split("/")[-1])."
            }

            # Delete the data if requested
            if ($RemoveData)
            {
                $exportStorageName = $export.StorageAccountId.Split("/")[-1]
                $resourceGroup = (Get-AzResource -ResourceType "Microsoft.Storage/storageAccounts" -Name $exportStorageName).ResourceGroupName
                $exportStorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -Name $exportStorageName).Value[0]
                $context = New-AzStorageContext -StorageAccountName $exportStorageName -StorageAccountKey $exportStorageKey
                Write-Verbose -Message "Deleting data for Cost Management export $($export.Name) in storage account $($exportStorageName) at path $($export.StoragePath)."
                Remove-AzDataLakeGen2Item -FileSystem "ingestion" -Path $export.Id.ToLower().Split("/provider/microsoft.costmanagement/exports/")[0] -Context $context -Force
                Write-Verbose -Message "Complete: Deleted data for Cost Management export $($export.Name) in storage account $($exportStorageName) at path $($export.StoragePath)."
            }
        }
    }
    catch
    {
        throw $_.Exception.Message
    }
}
