# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
$directory = Join-Path ([IO.Path]::GetTempPath()) ("quota-package-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $directory
try
{
    $files = $env:files | ConvertFrom-Json -Depth 10
    foreach ($file in $files.PSObject.Properties)
    {
        $path = Join-Path $directory $file.Name
        $null = New-Item -ItemType Directory -Path (Split-Path $path) -Force
        [IO.File]::WriteAllText($path, $file.Value, [Text.UTF8Encoding]::new($false))
    }
    $package = Join-Path ([IO.Path]::GetTempPath()) ("quota-" + [guid]::NewGuid().ToString('N') + '.zip')
    Compress-Archive -Path (Join-Path $directory '*') -DestinationPath $package
    $context = New-AzStorageContext -StorageAccountName $env:storageAccountName -UseConnectedAccount
    Set-AzStorageBlobContent -Context $context -Container $env:containerName -File $package `
        -Blob $env:blobName -Force | Out-Null
    $packageUri = New-AzStorageBlobSASToken -Context $context -Container $env:containerName `
        -Blob $env:blobName -Permission r -Protocol HttpsOnly `
        -ExpiryTime (Get-Date).ToUniversalTime().AddMinutes(30) -FullUri
    $DeploymentScriptOutputs = @{ packageUri = $packageUri }
}
finally
{
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
    if ($package -and (Test-Path -LiteralPath $package)) { Remove-Item -LiteralPath $package -Force }
}
