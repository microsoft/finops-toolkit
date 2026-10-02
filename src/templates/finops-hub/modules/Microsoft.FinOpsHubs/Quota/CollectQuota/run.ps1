# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param($Timer)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../AzVMQuotaUsage/AzVMQuotaUsage.psm1')
if (-not ('FinOpsToolkit.QuotaBlobStream' -as [type]))
{
    Add-Type -Path (Join-Path $PSScriptRoot 'QuotaBlobStream.cs')
}

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

function Write-Manifest
{
    param ([string] $CsvPath, [string] $BlobName, [long] $RowCount, [string] $Scope, [string] $Type, [string] $Version,
        [string] $ExportName, [long] $ByteCount = -1, [string] $Sha256, [switch] $Uploaded)

    $bytes = if ($ByteCount -ge 0) { $ByteCount } else { (Get-Item -LiteralPath $CsvPath).Length }
    $hash = if ($Sha256) { $Sha256 } else { (Get-FileHash -LiteralPath $CsvPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    $manifest = [ordered] @{
        manifestVersion = '2024-04-01'
        byteCount       = $bytes
        blobCount       = 1
        dataRowCount    = $RowCount
        blobs           = @(@{
                blobName = $BlobName; byteCount = $bytes; rowCount = $RowCount
                sha256 = $hash
            })
        exportConfig    = @{
            exportName  = $ExportName
            resourceId  = "$Scope/providers/Microsoft.CostManagement/exports/$ExportName"
            dataVersion = $Version
            type        = $Type
        }
        runInfo         = @{
            runId     = $runId
            startDate = $started.ToString('o')
            endDate   = [datetime]::UtcNow.ToString('o')
        }
    }
    $manifestPath = Join-Path (Split-Path $CsvPath) 'manifest.json'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    [pscustomobject] @{ CsvPath = $CsvPath; ManifestPath = $manifestPath; BlobName = $BlobName; Uploaded = $Uploaded.IsPresent }
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
    $started = [datetime]::UtcNow
    $runId = $started.ToString('yyyyMMddTHHmmssZ')
    $armToken = Get-IdentityToken 'https://management.azure.com/'
    $files = [System.Collections.Generic.List[object]]::new()
    # Savings plan and quota failures are warnings, so one dataset does not block the upload of the other
    try
    {
        $savingsPlans = Get-SavingsPlanRecommendations -AccessToken $armToken -TenantId $env:AZURE_TENANT_ID `
            -BillingScope $billingScopes -SettingsHash $settingsHash -SettingsETag ([string] $settingsResponse.Headers.ETag) `
            -RunId $runId -OutputDirectory $outputDirectory
        foreach ($file in $savingsPlans)
        {
            $files.Add((Write-Manifest -CsvPath $file.CsvPath -BlobName $file.BlobName -RowCount $file.Rows -Scope $file.Scope `
                        -Type Recommendations -Version '1.0-savingsplan' -ExportName "SavingsPlan-$($file.Partition)"))
        }
    }
    catch { Write-Warning "Savings plan collection failed: $($_.Exception.Message)" }

    $quotaStream = $null
    $uploadClient = $null
    try
    {
        $quotaBlobName = "quota/$runId/Quota.csv"
        $quotaCsvPath = Join-Path $outputDirectory $quotaBlobName
        $null = New-Item -ItemType Directory -Path (Split-Path $quotaCsvPath) -Force
        $uploadClient = [Net.Http.HttpClient]::new()
        $uploadClient.Timeout = [TimeSpan]::FromSeconds(120)
        $quotaStream = [FinOpsToolkit.QuotaBlobStream]::new(
            [uri]"$exportStorage/msexports/$quotaBlobName",
            [Func[securestring]]{ Get-IdentityToken 'https://storage.azure.com/' }, $uploadClient)
        $quota = Get-AzVMQuotaUsage -AccessToken $armToken -AccessTokenProvider { Get-IdentityToken 'https://management.azure.com/' } `
            -OutputStream $quotaStream -OutputFile $quotaBlobName
        $quotaStream.Complete()
        $files.Add((Write-Manifest -CsvPath $quotaCsvPath -BlobName $quotaBlobName -RowCount $quota.Rows `
                    -ByteCount $quota.Bytes -Sha256 $quotaStream.Sha256 -Uploaded `
                    -Scope "/tenants/$($env:AZURE_TENANT_ID)" -Type Quota -Version '1.0' -ExportName Quota))
        Write-Output "Quota CSV committed: subscriptions=$($quota.Subscriptions); requests=$($quota.Requests); rows=$($quota.Rows); bytes=$($quota.Bytes); blocks=$($quotaStream.BlockCount)."
    }
    catch { Write-Warning "Quota collection failed: $($_.Exception.Message)" }
    finally
    {
        if ($quotaStream) { $quotaStream.Dispose() }
        if ($uploadClient) { $uploadClient.Dispose() }
    }
    if (-not $files.Count) { throw 'No files were produced.' }

    $storageToken = Get-IdentityToken 'https://storage.azure.com/'
    foreach ($file in $files | Where-Object { -not $_.Uploaded })
    {
        $blob = ($file.BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $csvUri = "$exportStorage/msexports/$blob"
        Invoke-WebRequest -Method Put -Uri $csvUri -InFile $file.CsvPath -ContentType 'text/csv' `
            -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
            -TimeoutSec 7200 -ErrorAction Stop | Out-Null
    }
    foreach ($file in $files)
    {
        $blob = ($file.BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $manifestUri = "$exportStorage/msexports/$($blob.Substring(0, $blob.LastIndexOf('/')))/manifest.json"
        Invoke-WebRequest -Method Put -Uri $manifestUri -InFile $file.ManifestPath -ContentType 'application/json' `
            -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
            -ErrorAction Stop | Out-Null
    }
    Write-Output "Published $($files.Count) datasets for run $runId."
}
finally
{
    if (Test-Path -LiteralPath $outputDirectory)
    {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
}
