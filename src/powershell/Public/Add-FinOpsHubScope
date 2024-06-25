<#
    .SYNOPSIS
    Adds an export scope configuration to the specified Resource group.

    .PARAMETER HubName
    The name of the resource group.

    .PARAMETER Scope
    The export scope to add to the FinOps Hub configuration.

    .EXAMPLE
    Add-FinOpsHubScope -HubName ftk-FinOps-Hub -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"

    Adds an export scope configuration to the specified Resource group.
#>
Function Add-FinOpsHubScope {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $HubName,
        [Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $Scope
    )
    $ErrorActionPreference = 'Stop'
    [string]$operation = 'create'

    # Main
    Write-Output ''
    Write-Output ("{0}    Starting" -f (Get-Date))

    if (!$Scope.StartsWith('/')) {
        $Scope = '/' + $Scope
    }

    if ($Scope.EndsWith('/')) {
        $Scope = $Scope.Substring(0, $Scope.Length - 1)
    }

    Write-Output ("{0}    Export Scope to add: {1}" -f (Get-Date), $Scope)

    $tagSuffix = "Microsoft.Cloud/hubs/$HubName"
    $hubResource = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' -TagName 'cm-resource-parent' | Where-Object { $_.Tags['cm-resource-parent'].EndsWith($tagSuffix) }
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
    $settings = Get-Content 'settings.json' | ConvertFrom-Json

    # To deal with the case where there's nothing but a blank scope in the settings.json file
    if (($settings.scopes.Count -eq 1) -and ([string]::IsNullOrEmpty($settings.scopes[0]))) {
        $settings.scopes = @()
        $operation = 'create'
        Write-Output ("{0}    No scopes defined" -f (Get-Date), $Scope)
    }

    foreach ($exportScope in $settings.scopes) {
        if ($exportScope.scope -eq $Scope) {
            Write-Output ("{0}    Scope {1} already exists" -f (Get-Date), $Scope)
            $operation = 'none'
        }
    }

    if ($operation -eq 'create') {
        Write-Output ("{0}    Adding scope {1} with tenant ID {2}" -f (Get-Date), $Scope, $TenantId)
        [PSCustomObject]$ScopeToAdd = @{scope = $Scope }
        $settings.scopes += $ScopeToAdd
        Write-Output ("{0}    Saving settings.json" -f (Get-Date))
        $settings | ConvertTo-Json -Depth 100 | Set-Content 'settings.json' -Force | Out-Null
        Set-AzStorageBlobContent -Container 'config' -File 'settings.json' -Context $storageContext -Force | Out-Null
    }

    Write-Output ("{0}    Finished" -f (Get-Date))
    Write-Output ''
}
