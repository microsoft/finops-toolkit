# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param($Timer)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../AzVMQuotaUsage/AzVMQuotaUsage.psm1')

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

function Publish-Csv
{
    param ([string] $CsvPath, [string] $BlobName, [long] $RowCount)

    $blob = [pscustomobject] @{
        blobName = $BlobName
        byteCount = (Get-Item -LiteralPath $CsvPath).Length
        rowCount = $RowCount
        sha256 = (Get-FileHash -LiteralPath $CsvPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $path = ($BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $storageToken = Get-IdentityToken 'https://storage.azure.com/'
    $upload = [Diagnostics.Stopwatch]::StartNew()
    Invoke-WebRequest -Method Put -Uri "$exportStorage/msexports/$path" -InFile $CsvPath -ContentType 'text/csv' `
        -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
        -TimeoutSec 7200 -ErrorAction Stop | Out-Null
    $upload.Stop()
    Remove-Item -LiteralPath $CsvPath -Force -ErrorAction Stop
    Write-Information "Uploaded $BlobName ($($blob.byteCount) bytes, $RowCount rows) in $([math]::Round($upload.Elapsed.TotalSeconds, 2)) seconds; local CSV deleted." -InformationAction Continue
    $blob
}

function Write-Manifest
{
    param ([object[]] $Blobs, [string] $Scope, [string] $Type, [string] $Version, [string] $ExportName)

    $manifest = [ordered] @{
        manifestVersion = '2024-04-01'
        byteCount       = [long] ($Blobs | Measure-Object -Property byteCount -Sum).Sum
        blobCount       = $Blobs.Count
        dataRowCount    = [long] ($Blobs | Measure-Object -Property rowCount -Sum).Sum
        blobs           = @($Blobs)
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
    $manifestPath = Join-Path $outputDirectory ((Split-Path $Blobs[0].blobName) + '/manifest.json')
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    [pscustomobject] @{ ManifestPath = $manifestPath; BlobName = $Blobs[0].blobName }
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
    # Collect the datasets independently and upload CSVs before publishing their manifests.
    try
    {
        Get-SavingsPlanRecommendations -AccessToken $armToken -TenantId $env:AZURE_TENANT_ID `
            -BillingScope $billingScopes -SettingsHash $settingsHash -SettingsETag ([string] $settingsResponse.Headers.ETag) `
            -RunId $runId -OutputDirectory $outputDirectory | ForEach-Object {
            $file = $PSItem
            $blob = Publish-Csv -CsvPath $file.CsvPath -BlobName $file.BlobName -RowCount $file.Rows
            $files.Add((Write-Manifest -Blobs @($blob) -Scope $file.Scope `
                        -Type Recommendations -Version '1.0-savingsplan' -ExportName "SavingsPlan-$($file.Partition)"))
        }
    }
    catch { Write-Warning "Savings plan collection failed: $($_.Exception.Message)" }

    $quotaFailure = $null
    $quotaWriter = $null
    try
    {
        $quotaDirectory = Join-Path $outputDirectory "quota/$runId"
        $null = New-Item -ItemType Directory -Path $quotaDirectory -Force
        $quotaBlobs = [System.Collections.Generic.List[object]]::new()
        $quotaFileSizeBytes = 128MB
        $encoding = [Text.UTF8Encoding]::new($false)
        $newlineBytes = $encoding.GetByteCount([Environment]::NewLine)
        $quotaHeader = $null
        $quotaPart = 1
        $quotaRows = 0
        $quotaBytes = 0

        Get-AzVMQuotaUsage -AccessToken $armToken -AsCsv | ForEach-Object {
            $line = [string] $PSItem
            if ($null -eq $quotaHeader)
            {
                $quotaHeader = $line
                $headerBytes = $encoding.GetByteCount($quotaHeader) + $newlineBytes
                return
            }
            $lineBytes = $encoding.GetByteCount($line) + $newlineBytes
            if ($headerBytes + $lineBytes -gt $quotaFileSizeBytes)
            {
                throw "A quota CSV row exceeds the $quotaFileSizeBytes-byte file limit."
            }
            if ($quotaWriter -and $quotaBytes + $lineBytes -gt $quotaFileSizeBytes)
            {
                $quotaWriter.Dispose()
                $quotaWriter = $null
                $quotaBlobs.Add((Publish-Csv -CsvPath $quotaCsvPath -BlobName $quotaBlobName -RowCount $quotaRows))
                $quotaPart++
            }
            if (-not $quotaWriter)
            {
                $quotaBlobName = "quota/$runId/Quota-$($quotaPart.ToString('D6')).csv"
                $quotaCsvPath = Join-Path $outputDirectory $quotaBlobName
                $quotaWriter = [IO.StreamWriter]::new($quotaCsvPath, $false, $encoding)
                $quotaWriter.WriteLine($quotaHeader)
                $quotaRows = 0
                $quotaBytes = $headerBytes
            }
            $quotaWriter.WriteLine($line)
            $quotaRows++
            $quotaBytes += $lineBytes
        }
        if ($quotaWriter)
        {
            $quotaWriter.Dispose()
            $quotaWriter = $null
            $quotaBlobs.Add((Publish-Csv -CsvPath $quotaCsvPath -BlobName $quotaBlobName -RowCount $quotaRows))
        }
        elseif (-not $quotaBlobs.Count)
        {
            $quotaBlobName = "quota/$runId/Quota-000001.csv"
            $quotaCsvPath = Join-Path $outputDirectory $quotaBlobName
            [IO.File]::WriteAllText($quotaCsvPath, $quotaHeader + [Environment]::NewLine, $encoding)
            $quotaBlobs.Add((Publish-Csv -CsvPath $quotaCsvPath -BlobName $quotaBlobName -RowCount 0))
        }
        $files.Add((Write-Manifest -Blobs $quotaBlobs.ToArray() `
                    -Scope "/tenants/$($env:AZURE_TENANT_ID)" -Type Quota -Version '1.0' -ExportName Quota))
    }
    catch
    {
        $quotaFailure = $PSItem
        Write-Warning "Quota collection failed: $($quotaFailure.Exception.Message)"
    }
    finally
    {
        if ($quotaWriter)
        {
            try { $quotaWriter.Dispose() }
            catch
            {
                if (-not $quotaFailure) { $quotaFailure = $PSItem }
                Write-Warning "Quota CSV cleanup failed: $($PSItem.Exception.Message)"
            }
        }
    }
    if (-not $files.Count)
    {
        if ($quotaFailure) { throw $quotaFailure }
        throw 'No files were produced.'
    }

    $storageToken = Get-IdentityToken 'https://storage.azure.com/'
    foreach ($file in $files)
    {
        $blob = ($file.BlobName -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $manifestUri = "$exportStorage/msexports/$($blob.Substring(0, $blob.LastIndexOf('/')))/manifest.json"
        Invoke-WebRequest -Method Put -Uri $manifestUri -InFile $file.ManifestPath -ContentType 'application/json' `
            -Authentication Bearer -Token $storageToken -Headers ($headers + @{ 'x-ms-blob-type' = 'BlockBlob' }) `
            -ErrorAction Stop | Out-Null
    }
    if ($quotaFailure) { throw $quotaFailure }
    Write-Output "Published $($files.Count) datasets for run $runId."
}
finally
{
    if (Test-Path -LiteralPath $outputDirectory)
    {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
}
