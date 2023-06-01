<#
.SYNOPSIS
Adds an export scope configuration to the specified Resource group.

.PARAMETER HubName
The name of the Resource group.

.PARAMETER Location
The Export Scope to add to the Resource group configuration.

.EXAMPLE
Get-FinOpsHub -HubName FinOps-Hub -Location WestUS

Adds an export scope configuration to the specified Resource group.
#>
Function Get-FinOpsHub {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $HubName
    )

    $tagSuffix = "Microsoft.Cloud/hubs/$HubName"
    $hubResource = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -TagName 'cm-resource-parent' | Where-Object {$_.Tags['cm-resource-parent'].EndsWith($tagSuffix) }
    if ($null -eq $hubResource) {
        Write-Output ("{0}    Hub not found" -f (Get-Date))
        Throw ("Hub not found")
    }

    if ($hubResource.Count -gt 1) {
        Write-Output ("{0}    Multiple hubs found" -f (Get-Date))
        Throw ("Multiple hubs found")
    }

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $hubResource.ResourceGroupName -Name $hubResource.Name -ErrorAction SilentlyContinue
    if ($null -eq $storageAccount) {
        Write-Output ("{0}    Storage account not found" -f (Get-Date))
        Throw ("Storage account not found")
    }

    $storageContext = $StorageAccount.Context
    Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $storageContext | Get-AzStorageBlobContent -Force | Out-Null
    $settings = Get-Content 'settings.json' 
    return $settings
}

Export-ModuleMember -Function 'Get-FinOpsHub'