# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a Cost Management export and optionally data associated with the export.

    .PARAMETER Id
    Required Resource ID of the scope to remove.

    .PARAMETER HubName
    Optional. Name of the hub instance to update.

    .PARAMETER RemoveData
    Optional. Indicates whether to remove data for this scope from storage. Default = false

    .EXAMPLE
    Remove-FinOpsHubScope -Id "ResourceID of Scope" -HubName "Hub Name" 
    Remove-FinOpsHubScope -Id "ResourceID of Scope" -HubName "Hub Name" -RemoveData
    
    .LINK
    https://aka.ms/ftk/Initialize-FinOpsHubDeployment
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
            Remove-FinOpsCostExport -Scope $Id -Name $export.Name 
            Write-Verbose -Message "Deleted Cost Management export $($export.Name) from storage account $($export.StorageAccountId.Split("/")[-1])."
        

            # Delete the data if requested
            if ($RemoveData) 
            {
                # This can use the standard storage Az commands
                $storageAccountName = $export.StorageAccountId.Split("/")[-1]
                $storageAccount = Get-AzStorageAccount -ResourceGroupName (Get-AzResource -ResourceId $export.StorageAccountId).ResourceGroupName -Name $storageAccountName | Select-Object -ExpandProperty Kind
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