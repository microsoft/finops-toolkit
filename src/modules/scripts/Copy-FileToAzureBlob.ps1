$json = [ordered]@{
    '$schema'    = 'https://aka.ms/finops/toolkit/settings-schema'
    type         = 'HubInstance'
    version      = '0.0.1'
    learnMore    = 'https://aka.ms/finops/toolkit'
    exportScopes = @()    
}

$json.exportScopes = $env:exportScopes.Split('|')
$settingsFile = Join-Path -Path .\ -ChildPath 'settings.json'
$json | ConvertTo-Json | Out-File $settingsFile
$ctx = New-AzStorageContext -StorageAccountName $env:storageAccountName -StorageAccountKey $env:storageAccountKey
Set-AzStorageBlobContent -Container $env:containerName -Context $ctx -File $settingsFile
