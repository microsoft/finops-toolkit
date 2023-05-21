<#
.SYNOPSIS
Adds an export scope configuration to the specified Resource group.

.PARAMETER ResourceGroupName
The name of the Resource group.

.PARAMETER Scope
The Export Scope to add to the Resource group configuration.

.PARAMETER TenantId
The Azure AD Tenant linked to the export scope.

.PARAMETER Cloud
The Azure Cloud the export scope belongs to.

.EXAMPLE
Add-FinOpsHubScope -ResourceGroupName FinOps-Hub -TenantId 00000000-0000-0000-0000-000000000000 -Cloud AzureCloud -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"

Adds an export scope configuration to the specified Resource group.
#>
Function Add-FinOpsHubScope {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $ResourceGroupName,    
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

    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if ($null -eq $resourceGroup) {
        Write-Output ("{0}    Resource group {1} not found" -f (Get-Date), $ResourceGroupName)
        Throw ("Resource group {0} not found" -f $ResourceGroupName)
    }

    Write-Output ("{0}    Resource group {1} found" -f (Get-Date), $ResourceGroupName)

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($null -eq $storageAccount) {
        Write-Output ("{0}    Storage account not found" -f (Get-Date))
        Throw ("Storage account not found")
    }

    if ($storageAccount.Count -gt 1) {
        Write-Output ("{0}    Multiple storage accounts found" -f (Get-Date))
        Throw ("Multiple storage accounts found")
    } # handle this better later on to select the correct one.

    Write-Output ("{0}    Storage account found" -f (Get-Date))

    $storageContext = $StorageAccount.Context
    Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $storageContext | Get-AzStorageBlobContent -Force | Out-Null
    $settings = Get-Content 'settings.json' | ConvertFrom-Json

    # To deal with the case where there's nothing but a blank export scope in the settings.json file
    if (($settings.exportScopes.Count -eq 1) -and ([string]::IsNullOrEmpty($settings.exportScopes[0]))) {
        $settings.exportScopes = @()
        $operation = 'create'
        Write-Output ("{0}    No export scopes defined" -f (Get-Date), $Scope)
    }

    foreach ($exportScope in $settings.exportScopes) {
        if ($exportScope.scope -eq $Scope) {
            Write-Output ("{0}    Export scope {1} already exists" -f (Get-Date), $Scope)
            $operation = 'none'
        }
    }

    if ($operation -eq 'create') {
        Write-Output ("{0}    Adding export scope {1} with tenant ID {2}" -f (Get-Date), $Scope, $TenantId)
        [PSCustomObject]$ScopeToAdd = @{scope = $Scope}
        $settings.exportScopes += $ScopeToAdd
        Write-Output ("{0}    Saving settings.json" -f (Get-Date))
        $settings | ConvertTo-Json -Depth 100 | Set-Content 'settings.json' -Force | Out-Null
        Set-AzStorageBlobContent -Container 'config' -File 'settings.json' -Context $storageContext -Force | Out-Null
    }

    Write-Output ("{0}    Finished" -f (Get-Date))
    Write-Output ''
}

Export-ModuleMember -Function 'Add-FinOpsHubScope'