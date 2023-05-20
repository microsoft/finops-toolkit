<#
.SYNOPSIS
Creates secrets in Azure KeyVault for the Service Principal.

.PARAMETER HubName
The name of the FinOps Hub.  
Assumes HubName = ResourceGroupName.

.PARAMETER ClientId
The Application ID (Client ID) of the Service Principal to create the secret for.

.PARAMETER TenantId
The ID of the Azure AD Tenant ID containing the Service Principal.

.PARAMETER Secret
The Secret (Password) of the service principal.

.EXAMPLE
$clientId = ConvertTo-SecureString -AsPlainText -String '00000000-0000-0000-0000-000000000000'
$secret = ConvertTo-SecureString -AsPlainText -String 'SomePassword'
Add-ExportScopeCredential -HubName $hubName  -TenantId $tenantid -ClientId $clientId -Secret $secret

Creates secrets in Azure KeyVault for the Service Principal.
#>
function Add-ExportScopeCredential {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        $HubName,
        [Parameter()]
        [String]
        [ValidateNotNullOrEmpty()]
        $TenantId,
        [Parameter()]
        [Securestring]
        [ValidateNotNullOrEmpty()]
        $ClientId,
        [Parameter()]
        [Securestring]
        [ValidateNotNullOrEmpty()]
        $Secret
    )
    $ErrorActionPreference = 'Stop'
    [string]$ClientIdSecretName = 'clientId{0}' -f $TenantId
    [string]$SecretSecretName = 'secret{0}' -f $TenantId

    # Functions
    function Set-secret {
        param (
            [string]$vaultName,
            [string]$SecretName,
            [SecureString]$SecretValue
        )

        $Secret = Get-AzKeyVaultsecret -VaultName $vaultName -Name $SecretName -ErrorAction SilentlyContinue
        if (($null -ne $Secret) -and ((ConvertFrom-SecureString -SecureString $Secret.secretValue -AsPlainText) -eq (ConvertFrom-SecureString -SecureString $SecretValue -AsPlainText)) ) {
            Write-Output ("{0}    secret {1} already exists and is up to date" -f (Get-Date), $SecretName)
            return
        }

        if ($null -eq $Secret) {
            Write-Output ("{0}    Create secret {1}" -f (Get-Date), $SecretName)
        } else {
            Write-Output ("{0}    Update secret {1}" -f (Get-Date), $SecretName)
        }
        
        Set-AzKeyVaultsecret -vaultName $vaultName -Name $SecretName -secretValue $SecretValue | Out-Null
    }

    # Main
    Write-Output ''
    Write-Output ("{0}    Starting" -f (Get-Date))

    $resourceGroup = Get-AzResourceGroup -Name $HubName -ErrorAction SilentlyContinue
    if ($null -eq $resourceGroup) {
        Write-Output ("{0}    FinOps Hub {1} Not Found" -f (Get-Date), $HubName)
        Throw ("FinOps Hub {0} Not Found" -f $HubName)
    }

    Write-Output ("{0}    FinOps Hub {1} Found" -f (Get-Date), $HubName)

    $keyVault = Get-AzKeyVault -ResourceGroupName $HubName -ErrorAction SilentlyContinue
    if ($null -eq $keyVault) {
        Write-Output ("{0}    Key Vault Not Found" -f (Get-Date))
        Throw ("Key Vault Not Found")
    }

    if ($keyVault.Count -gt 1) {
        Write-Output ("{0}    Multiple Key Vaults Found" -f (Get-Date))
        Throw ("Multiple Key Vaults Found")
    } # handle this better later on to select the correct one.

    Write-Output ("{0}    Key Vault Found" -f (Get-Date))

    Write-Output ("{0}    Create or Update KeyVault Access Policy" -f (Get-Date))
    $objectId = (Get-AzContext).Account.ExtendedProperties.HomeAccountId.Split('.')[0]
    Set-AzKeyVaultAccessPolicy -vaultName $keyVault.vaultName -PermissionsTosecrets Get, Set, List -ObjectId $objectId

    Write-Output ("{0}    Create or Update Export Scope Credentials" -f (Get-Date))
    Set-secret -vaultName $keyVault.vaultName -secretName $ClientIdSecretName -secretValue $ClientId
    Set-secret -vaultName $keyVault.vaultName -secretName $SecretSecretName -secretValue $Secret

    Write-Output ("{0}    Finished" -f (Get-Date))
    Write-Output ''
}

Export-ModuleMember -Function 'Add-ExportScopeCredential'