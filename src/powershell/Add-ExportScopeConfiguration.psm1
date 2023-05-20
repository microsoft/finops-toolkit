<#
.SYNOPSIS
Adds an export scope configuration to the specified FinOps Hub.

.PARAMETER HubName
The name of the FinOps Hub.
Assumes HubName = ResourceGroupName.

.PARAMETER Scope
The Export Scope to add to the FinOps Hub configuration.

.PARAMETER TenantId
The Azure AD Tenant linked to the export scope.

.PARAMETER Cloud
The Azure Cloud the export scope belongs to.

.EXAMPLE
Add-ExportScopeConfiguration -HubName FinOps-Hub -TenantId 00000000-0000-0000-0000-000000000000 -Cloud AzureCloud -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"

Adds an export scope configuration to the specified FinOps Hub.
#>
Function Add-ExportScopeConfiguration {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $HubName,    
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("AzureCloud", "AzureUSGovernment")]
        $Cloud,
        [Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $Scope,
        [Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $TenantId
        
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
    Write-Output ("{0}    tenantId for scope: {1}" -f (Get-Date), $TenantId)

    $resourceGroup = Get-AzResourceGroup -Name $HubName -ErrorAction SilentlyContinue
    if ($null -eq $resourceGroup) {
        Write-Output ("{0}    FinOps Hub {1} Not Found" -f (Get-Date), $HubName)
        Throw ("FinOps Hub {0} Not Found" -f $HubName)
    }

    Write-Output ("{0}    FinOps Hub {1} Found" -f (Get-Date), $HubName)

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $HubName -ErrorAction SilentlyContinue
    if ($null -eq $storageAccount) {
        Write-Output ("{0}    Storage Account Not Found" -f (Get-Date))
        Throw ("Storage Account Not Found")
    }

    if ($storageAccount.Count -gt 1) {
        Write-Output ("{0}    Multiple Storage Accounts Found" -f (Get-Date))
        Throw ("Multiple Storage Accounts Found")
    } # handle this better later on to select the correct one.

    Write-Output ("{0}    Storage Account Found" -f (Get-Date))

    $storageContext = $StorageAccount.Context
    Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $storageContext | Get-AzStorageBlobContent -Force | Out-Null
    $settings = Get-Content 'settings.json' | ConvertFrom-Json

    if (($settings.exportScopes.Count -eq 1) -and ([string]::IsNullOrEmpty($settings.exportScopes[0]))) {
        $settings.exportScopes = @()
        $operation = 'create'
    }

    foreach ($ScopeToUpdate in $settings.exportScopes) {
        if ($ScopeToUpdate.scope -eq $Scope) {
            Write-Output ("{0}    Export Scope {1} Already Exists" -f (Get-Date), $Scope)
            if ($ScopeToUpdate.tenantId -eq $TenantId) {
                Write-Output ("{0}    tenantId {1} Matches" -f (Get-Date), $TenantId)
                $operation = 'none'
            } else {
                Write-Output ("{0}    tenantId {1} <> {2}" -f (Get-Date), $ScopeToUpdate.tenantId, $TenantId)
                $operation = 'update'
            }

            if ($ScopeToUpdate.cloud -eq $Cloud) {
                Write-Output ("{0}    cloud {1} Matches" -f (Get-Date), $Cloud)
                $operation = 'none'
            } else {
                Write-Output ("{0}    cloud {1} <> {2}" -f (Get-Date), $ScopeToUpdate.cloud, $Cloud)
                $operation = 'update'
            }
        } else {
            Write-Output ("{0}    Export Scope {1} Skipped" -f (Get-Date), $ScopeToUpdate.scope)
        }
    }

    if ($operation -eq 'create') {
        Write-Output ("{0}    Adding Export Scope {1} with tenantId {2}" -f (Get-Date), $Scope, $TenantId)
        [PSCustomObject]$ScopeToAdd = @{cloud = $Cloud; scope = $Scope; tenantId = $TenantId }
        $settings.exportScopes += $ScopeToAdd
    }

    if ($operation -eq 'update') {
        Write-Output ("{0}    Updating Export Scope {1} with tenantId {2}" -f (Get-Date), $Scope, $TenantId)
        $settings.exportScopes | Where-Object { $_.scope -eq $Scope } | ForEach-Object { $_.tenantId = $TenantId; $_.cloud = $Cloud }
    }

    if ($operation -eq 'update' -or $operation -eq 'create') {
        Write-Output ("{0}    Saving settings.json" -f (Get-Date))
        $settings | ConvertTo-Json -Depth 100 | Set-Content 'settings.json' -Force | Out-Null
        Set-AzStorageBlobContent -Container 'config' -File 'settings.json' -Context $storageContext -Force | Out-Null
    }

    Write-Output ("{0}    Finished" -f (Get-Date))
    Write-Output ''
}

Export-ModuleMember -Function 'Add-ExportScopeConfiguration'