# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$json = [ordered]@{
    '$schema' = 'https://aka.ms/finops/hubs/settings-schema'
    type      = 'HubInstance'
    version   = '0.0.1'
    learnMore = 'https://aka.ms/finops/hubs'
    scopes    = @()
    retention = @{
        'msexports' = @{
            days = 0
        }
        'ingestion' = @{
            months = 13
        }
    }
}

# Set values from inputs
$json.scopes = $env:scopes.Split('|') | ForEach-Object { @{ 'scope' = $_ } }
$json.retention['msexports'].days = [Int32]::Parse($env:exportRetentionInDays)
$json.retention.ingestion.months = [Int32]::Parse($env:ingestionRetentionInMonths)

$ctx = New-AzStorageContext -StorageAccountName $env:storageAccountName -UseConnectedAccount

# Save config file to storage
$fileName = 'settings.json'
$fileToUpload = Join-Path -Path .\ -ChildPath $fileName
$json | ConvertTo-Json -Depth 99 | Out-File $fileToUpload
$existingFile = Get-AzStorageBlob -Container config -Context $ctx -Blob $fileName -ErrorAction SilentlyContinue
if ($null -eq $existingFile) {
    Set-AzStorageBlobContent -Container config -Context $ctx -File $fileToUpload
}

# Save schema_ea_normalized file to storage
$fileName = 'schema_ea_normalized.json'
$fileToUpload = Join-Path -Path .\ -ChildPath $fileName
$env:schema_ea_normalized | Out-File $fileToUpload
$existingFile = Get-AzStorageBlob -Container config -Context $ctx -Blob $fileName -ErrorAction SilentlyContinue
if ($null -eq $existingFile) {
    Set-AzStorageBlobContent -Container config -Context $ctx -File $fileToUpload
}

# Save schema_mca_normalized file to storage
$fileName = 'schema_mca_normalized.json'
$fileToUpload = Join-Path -Path .\ -ChildPath $fileName
$env:schema_mca_normalized | Out-File $fileToUpload
$existingFile = Get-AzStorageBlob -Container config -Context $ctx -Blob $fileName -ErrorAction SilentlyContinue
if ($null -eq $existingFile) {
    Set-AzStorageBlobContent -Container config -Context $ctx -File $fileToUpload
}