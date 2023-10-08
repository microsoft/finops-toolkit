# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a Cost Management export and optionally data associated with the export.

    .PARAMETER Id
    Required resource ID of the scope to remove.

    .PARAMETER HubName
    Optional. Name of the hub instance to update.

    .PARAMETER RemoveData
    Optional. Indicates whether to remove data for this scope from storage. Default = false

    .EXAMPLE
    Remove-FinOpsHubScope -Id "/providers/Microsoft.Billing/billingAccounts/123" -HubName "FooHub" 
    Deletes the exports configured to use the FooHub hub instance. Existing data is retained in the storage account.
    
    Remove-FinOpsHubScope -Id "/subscriptions/##-#-#-#-###" -HubName "FooHub" -RemoveData
    Deletes the exports configured to use the FooHub hub instance and removes data for that scope.
    
    .LINK
    https://aka.ms/ftk/Remove-FinOpsHubScope
#>


function Remove-FinOpsHubScope {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [string]$HubName,
        [switch]$RemoveData
    )

    try {
        # Get all exports for the scope that are pointed to the included storage account and the msexports container
        $exports = Get-FinOpsCostExport -Scope $Id  

        # Delete the exports
        foreach ($export in $exports) 
        {
            Remove-FinOpsCostExport -Scope $Id -Name $export.Name -RemoveData:$RemoveData
            Write-Verbose -Message "Deleted Cost Management export $($export.Name) from storage account $($export.StorageAccountId.Split("/")[-1])."
        

            # Delete the data if requested
            if ($RemoveData) 
            {
                # This can use the standard storage Az commands
                $storageAccountName = $export.StorageAccountId.Split("/")[-1]
                $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName (Get-AzResource -ResourceId $export.StorageAccountId).ResourceGroupName -Name $storageAccountName).Value[0]
                $context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
                Remove-AzDataLakeGen2Item -FileSystem "ingestion" -Path $export.StoragePath -Context $context -Force
                Write-Verbose -Message "Deleted data for Cost Management export $($export.Name) in storage account $($export.StorageAccountId.Split("/")[-1]) at path $($export.StoragePath)."
            }
        }
    }
    catch {
        throw $_.Exception.Message
    }
}