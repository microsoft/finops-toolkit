
$settingsFile = Join-Path -Path .\ -ChildPath 'settings.json'
$env:updatedFileContent | Out-File $settingsFile
$ctx = New-AzStorageContext -StorageAccountName $env:storageAccountName -StorageAccountKey $env:storageAccountKey
Set-AzStorageBlobContent -Container $env:containerName -Context $ctx -File $settingsFile
