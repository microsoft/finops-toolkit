$json = [ordered]@{
    '$schema'    = 'https://aka.ms/finops/hubs/settings-schema'
    type         = 'HubInstance'
    version      = '0.0.1'
    learnMore    = 'https://aka.ms/finops/hubs'
    exportScopes = @()
    retention    = @{
        'msexports' = @{
            days = 0
        }
        'ingestion'     = @{
            months = 13
        }
    }
}

# Set values from inputs
$json.exportScopes = $env:exportScopes.Split('|')
$json.retention['msexports'].days = [Int32]::Parse($env:exportRetentionInDays)
$json.retention.ingestion.months = [Int32]::Parse($env:ingestionRetentionInMonths)

# Save file to storage
$fileName = 'settings.json'
$fileToUpload = Join-Path -Path .\ -ChildPath $fileName
$json | ConvertTo-Json -Depth 99 | Out-File $fileToUpload
$ctx = New-AzStorageContext -StorageAccountName $env:storageAccountName -UseConnectedAccount
$existingFile = Get-AzStorageBlob -Container config -Context $ctx -Blob $fileName -ErrorAction SilentlyContinue
if ($null -eq $existingFile) {
    Set-AzStorageBlobContent -Container config -Context $ctx -File $fileToUpload
}
