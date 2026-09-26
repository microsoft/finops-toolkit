# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param($Timer)

$ErrorActionPreference = 'Stop'

function Get-IdentityToken
{
    param([string] $Resource)

    if (-not $env:IDENTITY_ENDPOINT -or -not $env:IDENTITY_HEADER -or -not $env:AZURE_CLIENT_ID)
    {
        throw 'The Function managed identity endpoint or client ID is unavailable.'
    }
    $uri = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=$([uri]::EscapeDataString($Resource))&client_id=$($env:AZURE_CLIENT_ID)"
    $response = Invoke-RestMethod -Uri $uri -Headers @{ 'X-IDENTITY-HEADER' = $env:IDENTITY_HEADER } -ErrorAction Stop
    if (-not $response.access_token) { throw "No managed identity token was returned for $Resource." }
    ConvertTo-SecureString $response.access_token -AsPlainText -Force
}

$settingsStorage = "https://$($env:HUB_STORAGE_ACCOUNT).blob.core.windows.net"
$exportStorage = "https://$($env:EXPORT_STORAGE_ACCOUNT).blob.core.windows.net"
$storageToken = Get-IdentityToken 'https://storage.azure.com/'
$headers = @{ 'x-ms-version' = '2023-11-03' }
$settingsUri = "$settingsStorage/$($env:HUB_SETTINGS_CONTAINER)/$($env:HUB_SETTINGS_FILE)"
$settingsResponse = Invoke-WebRequest -Uri $settingsUri -Authentication Bearer -Token $storageToken -Headers $headers -ErrorAction Stop
$settingsText = [Text.Encoding]::UTF8.GetString($settingsResponse.Content)
$settings = $settingsText | ConvertFrom-Json -ErrorAction Stop
$billingScopes = @($settings.scopes | ForEach-Object { $_.scope } |
        Where-Object { $_ -match '^/providers/Microsoft\.Billing/billingAccounts/[^/]+(/billingProfiles/[^/]+)?$' } |
        Select-Object -Unique)
$settingsHash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($settingsText))).ToLowerInvariant()
$outputDirectory = Join-Path ([IO.Path]::GetTempPath()) ("quota-" + [guid]::NewGuid().ToString('N'))

try
{
    $armToken = Get-IdentityToken 'https://management.azure.com/'
    $result = & (Join-Path $PSScriptRoot '../Export-Quota.ps1') `
        -AccessToken $armToken -TenantId ([guid] $env:AZURE_TENANT_ID) `
        -OutputDirectory $outputDirectory -BillingScope $billingScopes `
        -SettingsHash $settingsHash -SettingsETag ([string] $settingsResponse.Headers.ETag)
    if (-not $result.Files.Count) { throw 'The quota collector produced no files.' }
    if (-not $result.Complete)
    {
        $failures = @($result.Sources | Where-Object Error | ForEach-Object { "$($_.SourceType) $($_.Scope) $($_.Location): $($_.Error)" })
        throw "Quota collection was incomplete: $($failures -join '; ')"
    }

    $storageToken = Get-IdentityToken 'https://storage.azure.com/'
    foreach ($file in $result.Files)
    {
        $blob = ($file.BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $csvUri = "$exportStorage/msexports/$blob"
        Invoke-WebRequest -Method Put -Uri $csvUri -InFile $file.CsvPath -ContentType 'text/csv' `
            -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
            -TimeoutSec 7200 -ErrorAction Stop | Out-Null
    }
    foreach ($file in $result.Files)
    {
        $blob = ($file.BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $manifestUri = "$exportStorage/msexports/$($blob.Substring(0, $blob.LastIndexOf('/')))/manifest.json"
        Invoke-WebRequest -Method Put -Uri $manifestUri -InFile $file.ManifestPath -ContentType 'application/json' `
            -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
            -ErrorAction Stop | Out-Null
    }
    Write-Output "Published $($result.Files.Count) quota datasets for run $($result.RunId)."
}
finally
{
    if (Test-Path -LiteralPath $outputDirectory)
    {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
}
