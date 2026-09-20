# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by hub schema and is not a declared contract.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Reads Azure data and manages private local cache and download files only.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Accepted for signature parity across the hub reader family.')]
param()

###########################################################################
# READ-FINOPSHUBDATA.PS1
# FINOPS HUB STORAGE DATA READER
###########################################################################
# Purpose: Read cost data from a FinOps Hub storage account
# Date: Created for FinOps Multitool TUI integration
#
# Description:
# Reads FOCUS-schema cost data from a Hub storage account.
# Prefers parquet from the ingestion container (normalized FOCUS);
# falls back to CSV from msexports if ingestion is empty.
# Parquet.Net + all transitive deps are restored with whichever NuGet client the
# host has (nuget.exe on Windows, the dotnet SDK elsewhere), honouring the
# machine's configured feeds.
#
# 1. Checks ingestion container for parquet (preferred)
# 2. Falls back to msexports CSV if no parquet found
# 3. Returns FOCUS-schema cost objects for Multitool consumption
#
# ── Parameters ──────────────────────────────────────────────
# StorageAccountName   Hub storage account name
# ResourceGroupName    Resource group containing the storage account
# Months               Number of months to read (default: 1)
#
# Prerequisites:
# - Az.Storage module
# - Storage Blob Data Reader RBAC on the Hub storage account
###########################################################################

function ConvertTo-HashtableFromJson {
    param([string]$Json)
    return ConvertFrom-ExportTagString -Raw $Json
}

function New-FinOpsPrivateDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$RequireNew
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    if ($fullPath -match '^[\\/]{2}|[\x00-\x1f]') { throw 'Private data requires a local filesystem directory.' }
    $items = [Collections.Generic.List[object]]::new()
    $missingDirectories = [Collections.Generic.List[string]]::new()
    $ancestor = $fullPath
    while ($ancestor) {
        try {
            if (([IO.File]::GetAttributes($ancestor) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Private data paths cannot contain links or junctions.' }
            $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
            if (-not $item.PSIsContainer) { throw 'Private data paths must be directories.' }
            $items.Add($item)
        }
        catch [IO.FileNotFoundException] { $missingDirectories.Add($ancestor) }
        catch [IO.DirectoryNotFoundException] { $missingDirectories.Add($ancestor) }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    $parentDirectory = [IO.Path]::GetDirectoryName($fullPath)
    $creationParent = if ($missingDirectories.Count -gt 0) { $items[0].FullName } else { $parentDirectory }
    if (Test-Path -LiteralPath $fullPath) {
        if ($RequireNew) { throw 'The private data directory already exists.' }
        foreach ($item in Get-ChildItem -LiteralPath $fullPath -Force -Recurse -ErrorAction Stop) { $items.Add($item) }
    }
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        try {
            $trusted = @($identity.User.Value, 'S-1-5-18', 'S-1-5-32-544', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
            $writeRights = [Security.AccessControl.FileSystemRights]'Write, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
            $replacementRights = [Security.AccessControl.FileSystemRights]'Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
            foreach ($item in $items) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Private data cannot contain linked files or directories.' }
                $security = Get-Acl -LiteralPath $item.FullName -ErrorAction Stop
                if ($security.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted) { throw 'The private data directory contains an untrusted owner.' }
                $rights = if ($item.FullName -eq $creationParent -or $item.FullName -eq $parentDirectory -or $item.FullName -eq $fullPath -or
                    $item.FullName.StartsWith($fullPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $writeRights } else { $replacementRights }
                foreach ($rule in $security.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
                    if (($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0) { continue }
                    if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin $trusted -and ($rule.FileSystemRights -band $rights) -ne 0) {
                        throw 'The private data directory permits writes by another account.'
                    }
                }
            }
        }
        finally { $identity.Dispose() }
    }
    else {
        $identityCommand = Get-Command id -CommandType Application -ErrorAction Stop
        $ownerId = (& $identityCommand.Source -u).Trim()
        if ($LASTEXITCODE -ne 0 -or $ownerId -notmatch '^\d+$') { throw 'The current user ID could not be verified.' }
        $stat = Get-Command stat -CommandType Application -ErrorAction Stop
        foreach ($item in $items) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Private data cannot contain linked files or directories.' }
            $metadata = if ($IsMacOS) { & $stat.Source -f '%u:%Lp' $item.FullName } else { & $stat.Source -c '%u:%a' -- $item.FullName }
            if ($LASTEXITCODE -ne 0 -or [string]$metadata -notmatch '^(\d+):([0-7]+)$') { throw 'Private data ownership and permissions could not be verified.' }
            $itemOwner = $Matches[1]
            $mode = [Convert]::ToInt32($Matches[2], 8)
            $isAncestor = $item.FullName -ne $fullPath -and -not $item.FullName.StartsWith($fullPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)
            $stickyAncestor = $isAncestor -and $item.FullName -ne $creationParent -and $item.FullName -ne $parentDirectory -and $itemOwner -eq '0' -and ($mode -band 512) -ne 0
            if (($itemOwner -ne $ownerId -and -not ($isAncestor -and $itemOwner -eq '0')) -or (($mode -band 18) -ne 0 -and -not $stickyAncestor)) {
                throw 'Private data must be owned by the current user and not writable by other accounts.'
            }
        }
    }
    $directoriesToCreate = @($missingDirectories.ToArray())
    [array]::Reverse($directoriesToCreate)
    if ($directoriesToCreate.Count -eq 0) { $directoriesToCreate = @($fullPath) }
    foreach ($directoryPath in $directoriesToCreate) {
        if ($IsWindows) {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            try {
                $security = [Security.AccessControl.DirectorySecurity]::new()
                $security.SetAccessRuleProtection($true, $false)
                $security.SetOwner($identity.User)
                $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
                        $identity.User, [Security.AccessControl.FileSystemRights]::FullControl,
                        [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
                        [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Allow))
                $directory = [IO.DirectoryInfo]::new($directoryPath)
                if ($directory.Exists) { [IO.FileSystemAclExtensions]::SetAccessControl($directory, $security) }
                else { [IO.FileSystemAclExtensions]::Create($directory, $security) }
            }
            finally { $identity.Dispose() }
        }
        else {
            $unixModeType = 'System.IO.UnixFileMode' -as [type]
            if ($unixModeType) {
                [void][IO.Directory]::CreateDirectory($directoryPath, [Enum]::ToObject($unixModeType, 448))
                [IO.File]::SetUnixFileMode($directoryPath, [Enum]::ToObject($unixModeType, 448))
            }
            else {
                $command = Get-Command $(if (Test-Path -LiteralPath $directoryPath) { 'chmod' } else { 'mkdir' }) -CommandType Application -ErrorAction Stop
                if ([IO.Directory]::Exists($directoryPath)) { & $command.Source 700 $directoryPath }
                else { & $command.Source -m 700 $directoryPath }
                if ($LASTEXITCODE -ne 0) { throw 'A private data directory could not be created.' }
            }
        }
    }
    return $fullPath
}

function Get-FinOpsParquetCachePath {
    # Per-user cache, not the world-writable shared temp dir. On a multi-user or
    # shared host, %TEMP%/tmp lets another local principal pre-plant DLLs at a
    # predictable path that we would then load into this process.
    $base = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData, [Environment+SpecialFolderOption]::DoNotVerify)
    if ([string]::IsNullOrWhiteSpace($base)) { throw 'Private application data is unavailable. The Parquet cache cannot use a shared temporary directory.' }
    return (Join-Path (Join-Path $base 'FinOpsMultitool') 'parquet')
}

# Every managed/native DLL the loader can pull in, in a stable order.
function Get-ParquetPayloadFile {
    param([Parameter(Mandatory)][string]$BasePath)
    $roots = @((Join-Path $BasePath 'lib'), (Join-Path $BasePath 'runtimes'))
    $files = foreach ($r in $roots) {
        if (Test-Path -LiteralPath $r) {
            # Native payloads are .dll on Windows but .so/.dylib elsewhere, and a
            # .dll-only filter would leave those unhashed on Linux and macOS.
            Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.(dll|dylib|so)(\.\d+)*$' }
        }
    }
    return @($files | Sort-Object FullName)
}

function New-ParquetManifest {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$ManifestPath
    )
    $entries = @{}
    foreach ($f in (Get-ParquetPayloadFile -BasePath $BasePath)) {
        $rel = $f.FullName.Substring($BasePath.Length).TrimStart('\', '/')
        $entries[$rel] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
    [PSCustomObject]@{
        version = '4.24.0'
        created = (Get-Date).ToUniversalTime().ToString('o')
        files   = $entries
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

# Re-hashes every payload DLL against the manifest recorded at install time.
# Runs on EVERY load, so a tampered cache cannot ride in behind a marker file.
function Test-ParquetManifest {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$ManifestPath
    )
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return $false }
    try {
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch { return $false }
    if (-not $manifest.files) { return $false }

    $recorded = @{}
    foreach ($p in $manifest.files.PSObject.Properties) { $recorded[$p.Name] = [string]$p.Value }
    if ($recorded.Count -eq 0) { return $false }

    $onDisk = Get-ParquetPayloadFile -BasePath $BasePath
    if ($onDisk.Count -ne $recorded.Count) { return $false }

    foreach ($f in $onDisk) {
        $rel = $f.FullName.Substring($BasePath.Length).TrimStart('\', '/')
        if (-not $recorded.ContainsKey($rel)) { return $false }
        if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne $recorded[$rel]) { return $false }
    }
    return $true
}

function Get-FinOpsParquetPackageLock {
    @(
        @{ Id = 'Parquet.Net'; Version = '4.24.0'; Sha512 = 'UAWKArPr96Oea1PfCvZqYhQ7xS+LewgMnMXxZijTAMKuujTYjf9jwLHzOB52e2wrBxGpkdmG3suIPdb7kNRRqQ==' }
        @{ Id = 'IronCompress'; Version = '1.5.2'; Sha512 = '9ZxjgVMP7BBfCQSQ14IT+05XABHz5lTiZWd7t7Jpg+0bVOZHtuwjHKnExUJJgM8OHKqyqolNkqmlyd8b/gJq7Q==' }
        @{ Id = 'Microsoft.Data.Analysis'; Version = '0.21.1'; Sha512 = 'OuEm3LZ6GoZCMU3X5hh02fGye9Iu4tPYvSbcHl62X41jZHQ+W5Z3CoJgzIOOKqUK7lpOkhTz6v/j/5ena2eh8g==' }
        @{ Id = 'Microsoft.IO.RecyclableMemoryStream'; Version = '3.0.0'; Sha512 = '7xVI6zAdiOAKchkPULjy33WRp3MPxwoYIB3kx0QWVdF9flb3DhoiGtSHre7c/1R9DIe3shQrriYeiwXWOkA3yg==' }
        @{ Id = 'Snappier'; Version = '1.3.1'; Sha512 = 'uo6Wvo127r6j6zfBayLdR3LxJ6eu82hM4iH+wJBhyKuN79tpCXlTIKDOE8Du0Cohq3VQ4o7GCpoXQtjF37ZC6w==' }
        @{ Id = 'ZstdSharp.Port'; Version = '0.8.1'; Sha512 = 'se/fJ+LE7xM4dpUxhwHS8DROQZWzZMs3MGF2bcgmnXJ2rcCiKCyA2QDph7soErYohHJYeECavuul95bNgTldhQ==' }
        @{ Id = 'Microsoft.ML.DataView'; Version = '3.0.1'; Sha512 = 'OhBIx0fq4p5ggwJnFFWSthy7FxuTqj61qVzinU4U1e6JuS3LqBt+bMe8MxFX69yjwvCU2lT0ja2ln7Kfuk/N9A==' }
        @{ Id = 'Apache.Arrow'; Version = '11.0.0'; Sha512 = 'PUK1/AQdcQg3epd1DRbiXQ3jhyY0noWm0MVTN3OTmKBsmvaapbO1My827Ui0RzH3u9P4avjKly52sX8sv6rQ3w==' }
        @{ Id = 'System.Buffers'; Version = '4.5.1'; Sha512 = 'gNphWOVbm89+C15jebnPRaYykU8De1PFv1YJV24814IfeGGVa3PXRHDS0MLlbdI1pe9Mpv/n4ZK4INwtAjqv8g==' }
        @{ Id = 'System.Memory'; Version = '4.5.5'; Sha512 = '6MjlNsl7lKw0Q8lAsw2tQ89ul9x6jD2Yk3EEj+dOFoYGOE9eAUO9wNhvd4O/n97oQXlkyzqKXXUnE+kLElFy3A==' }
        @{ Id = 'System.Runtime.CompilerServices.Unsafe'; Version = '6.0.0'; Sha512 = '1AVzAb5OxJNvJLnOADtexNmWgattm2XVOT3TjQTN7Dd4SqoSwai1CsN2fth42uQldJSQdz/sAec0+TzxBFgisw==' }
        @{ Id = 'System.Collections.Immutable'; Version = '1.5.0'; Sha512 = 'T5XGQlcHhEO75Qx38GGCUDPdk4n/7yrRmTgy4yczzJV8alPHaxPU55TBC2UFrkQ42bu34sZPfK0dU+nWZUOEJA==' }
    )
}

function Get-VerifiedParquetPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PackageDir)

    $expected = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($package in Get-FinOpsParquetPackageLock) { $expected[$package.Sha512] = $package }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $verified = [Collections.Generic.List[object]]::new()
    foreach ($package in Get-ChildItem -LiteralPath $PackageDir -Filter '*.nupkg' -Recurse -File -ErrorAction Stop) {
        $stream = [IO.File]::OpenRead($package.FullName)
        $algorithm = [Security.Cryptography.SHA512]::Create()
        try { $hash = [Convert]::ToBase64String($algorithm.ComputeHash($stream)) }
        finally { $algorithm.Dispose(); $stream.Dispose() }
        if (-not $expected.ContainsKey($hash) -or -not $seen.Add($hash)) { throw 'The Parquet cache contains an unexpected or duplicate package archive.' }
        $verified.Add([pscustomobject]@{ Path = $package.FullName; Id = $expected[$hash].Id; Version = $expected[$hash].Version })
    }
    if ($verified.Count -ne $expected.Count) { throw 'The Parquet cache is missing pinned package archives.' }
    return $verified.ToArray()
}

# Validates package signatures with the configured NuGet client.
# TLS alone only proves who we talked to, not that the payload is authentic.
function Assert-NuGetPackageSignature {
    param(
        [Parameter(Mandatory)][object]$Client,
        [Parameter(Mandatory)][string]$PackageDir
    )
    $nupkgs = @(Get-VerifiedParquetPackage -PackageDir $PackageDir)
    foreach ($pkg in $nupkgs) {
        $output = if ($Client.Kind -eq 'dotnet') {
            & $Client.Path nuget verify $pkg.Path --all 2>&1
        }
        else {
            & $Client.Path verify -Signatures $pkg.Path 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            throw "NuGet signature verification failed for $($pkg.Id) $($pkg.Version): $($output -join ' ')"
        }
    }
}

# Runtime identifier for the native payload: IronCompress ships a separate
# native library per RID, so the host's own RID decides which one to stage.
function Get-FinOpsNativeRid {
    $isWin = if ($null -ne $IsWindows) { $IsWindows } else { $true }
    $os = if ($isWin) { 'win' } elseif ($IsMacOS) { 'osx' } else { 'linux' }
    $arch = try {
        [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    }
    catch {
        if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    }
    return "$os-$arch"
}

# Picks a package client that reads the machine's NuGet configuration, so a
# corporate feed proxy, mirror or credential provider keeps working. nuget.exe
# is a Windows binary, so on macOS and Linux it is neither downloaded nor run.
function Resolve-NuGetClient {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CachePath)

    $isWin = if ($null -ne $IsWindows) { $IsWindows } else { $true }

    if (-not $isWin) {
        $dotnet = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
        if (-not $dotnet) {
            return [PSCustomObject]@{ Kind = $null; Path = $null; Reason = 'the .NET SDK is not installed (dotnet is not on PATH)' }
        }
        # A runtime-only install still answers 'dotnet' but cannot restore, and
        # an SDK older than the restore project's target framework fails late
        # with a confusing error, so both are rejected up front.
        $sdks = @(& $dotnet.Source --list-sdks 2>$null)
        if ($sdks.Count -eq 0) {
            return [PSCustomObject]@{ Kind = $null; Path = $null; Reason = 'only the .NET runtime is present and restoring packages needs the .NET SDK' }
        }
        $hasSupportedSdk = $false
        foreach ($line in $sdks) {
            if ([string]$line -match '^\s*(\d+)\.' -and [int]$matches[1] -ge 8) { $hasSupportedSdk = $true; break }
        }
        if (-not $hasSupportedSdk) {
            return [PSCustomObject]@{ Kind = $null; Path = $null; Reason = 'the installed .NET SDK is older than 8.0, which the Parquet packages target' }
        }
        return [PSCustomObject]@{ Kind = 'dotnet'; Path = $dotnet.Source; Reason = $null }
    }

    $nugetExe = Join-Path $CachePath 'nuget.exe'
    if (-not (Test-Path -LiteralPath $nugetExe)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetExe -UseBasicParsing
    }

    # Validated on every use, not just on download: a cached copy in a writable
    # path can be replaced between runs. The download URL is mutable ('/latest/')
    # too, so a tampered or unsigned binary is deleted and refused rather than
    # executed. The subject is matched as a whole RDN so a crafted value such as
    # 'O=Not Microsoft Corporation Ltd' cannot satisfy it.
    $sig = Get-AuthenticodeSignature -FilePath $nugetExe
    $signerSubject = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '<unsigned>' }
    $signerOk = $sig.SignerCertificate -and ($signerSubject -match '(^|,\s*)O=Microsoft Corporation(\s*,|$)')
    if ($sig.Status -ne 'Valid' -or -not $signerOk) {
        Remove-Item $nugetExe -Force -ErrorAction SilentlyContinue
        throw "nuget.exe failed Authenticode validation (status: $($sig.Status); signer: $signerSubject). Refusing to execute it."
    }

    return [PSCustomObject]@{ Kind = 'nuget.exe'; Path = $nugetExe; Reason = $null }
}

# Restores the pinned dependency set with the host's configured feeds.
function Invoke-NuGetRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Client,
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$PackageDir,
        [Parameter(Mandatory)][string]$WorkingPath
    )

    $packages = @(Get-FinOpsParquetPackageLock)
    if (@($packages | Where-Object { $_.Id -eq $PackageId -and $_.Version -eq $Version }).Count -ne 1) {
        throw 'Only the pinned Parquet dependency set can be restored.'
    }
    $projDir = Join-Path $WorkingPath 'restore'
    New-Item -ItemType Directory -Path $projDir -Force | Out-Null
    $document = [Xml.XmlDocument]::new()
    if ($Client.Kind -eq 'dotnet') {
        $document.LoadXml('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup /></Project>')
        foreach ($package in $packages) {
            $reference = $document.CreateElement('PackageReference')
            $reference.SetAttribute('Include', $package.Id)
            $reference.SetAttribute('Version', "[$($package.Version)]")
            [void]$document.SelectSingleNode('/Project/ItemGroup').AppendChild($reference)
        }
        $proj = Join-Path $projDir 'parquet-restore.csproj'
        $document.Save($proj)
        $output = & $Client.Path restore $proj --packages $PackageDir 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet restore failed for $PackageId $Version : $($output -join ' ')"
        }
    }
    else {
        $document.LoadXml('<packages />')
        foreach ($package in $packages) {
            $reference = $document.CreateElement('package')
            $reference.SetAttribute('id', $package.Id)
            $reference.SetAttribute('version', $package.Version)
            $reference.SetAttribute('targetFramework', 'net8.0')
            [void]$document.DocumentElement.AppendChild($reference)
        }
        $config = Join-Path $projDir 'packages.config'
        $document.Save($config)
        $output = & $Client.Path restore $config -PackagesDirectory $PackageDir -NonInteractive 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "nuget.exe restore failed for $PackageId $Version : $($output -join ' ')"
        }
    }
}

# nuget.exe stages <id>.<version>/, dotnet restore stages <id>/<version>/, so a
# package root is any directory that directly holds lib/ or runtimes/.
function Get-RestoredPackageRoot {
    param([Parameter(Mandatory)][string]$PackageDir)
    $roots = [System.Collections.Generic.List[string]]::new()
    foreach ($d in @(Get-ChildItem -LiteralPath $PackageDir -Directory -ErrorAction SilentlyContinue)) {
        if ((Test-Path -LiteralPath (Join-Path $d.FullName 'lib')) -or (Test-Path -LiteralPath (Join-Path $d.FullName 'runtimes'))) {
            [void]$roots.Add($d.FullName)
            continue
        }
        foreach ($v in @(Get-ChildItem -LiteralPath $d.FullName -Directory -ErrorAction SilentlyContinue)) {
            if ((Test-Path -LiteralPath (Join-Path $v.FullName 'lib')) -or (Test-Path -LiteralPath (Join-Path $v.FullName 'runtimes'))) {
                [void]$roots.Add($v.FullName)
            }
        }
    }
    return @($roots)
}

function Assert-ParquetPackagePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$PackageDir
    )

    $payload = @(Get-ParquetPayloadFile -BasePath $BasePath)
    if ($payload.Count -eq 0 -or -not (Test-Path -LiteralPath (Join-Path $BasePath 'lib/Parquet.dll') -PathType Leaf)) {
        throw 'The Parquet payload is incomplete.'
    }
    $verifiedHashes = @{}
    $frameworks = @('net8.0', 'net7.0', 'net6.0', 'net5.0', 'netcoreapp3.1', 'netstandard2.1', 'netstandard2.0')
    $rid = Get-FinOpsNativeRid
    foreach ($package in Get-VerifiedParquetPackage -PackageDir $PackageDir) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($package.Path)
        try {
            $framework = $frameworks | Where-Object { $archive.Entries.FullName -like "lib/$_/*" } | Select-Object -First 1
            foreach ($entry in $archive.Entries) {
                $relative = if ($framework -and $entry.FullName -like "lib/$framework/*.dll" -and $entry.FullName -match '^lib/[^/]+/([^/]+\.dll)$') { "lib/$($Matches[1])" }
                elseif ($entry.FullName.StartsWith("runtimes/$rid/native/", [StringComparison]::Ordinal) -and $entry.FullName -match '^runtimes/[^/]+/native/[^/]+\.(dll|dylib|so)(\.\d+)*$') { $entry.FullName }
                else { continue }
                $stream = $entry.Open()
                $algorithm = [System.Security.Cryptography.SHA256]::Create()
                try { $hash = [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '') }
                finally { $algorithm.Dispose(); $stream.Dispose() }
                if (-not $verifiedHashes.ContainsKey($relative)) { $verifiedHashes[$relative] = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) }
                [void]$verifiedHashes[$relative].Add($hash)
            }
        }
        finally { $archive.Dispose() }
    }
    foreach ($file in $payload) {
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked Parquet payload files are not allowed.' }
        $relative = $file.FullName.Substring($BasePath.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if (-not $verifiedHashes.ContainsKey($relative) -or -not $verifiedHashes[$relative].Contains($hash)) {
            throw "Parquet payload '$relative' does not match a verified package."
        }
    }
}

function Install-ParquetReader {
    [CmdletBinding()]
    param()

    # Check if Parquet is already loaded in this session
    $loaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.GetName().Name -eq 'Parquet'
    }
    if ($loaded) { return $true }

    try { $parquetDir = New-FinOpsPrivateDirectory -Path (Get-FinOpsParquetCachePath) }
    catch {
        $script:FinOpsParquetUnavailableReason = $_.Exception.Message
        Write-Warning "The Parquet cache is unavailable: $($_.Exception.Message)"
        return $false
    }
    $manifestFile = Join-Path $parquetDir 'parquet-manifest.json'

    # Cached checksums are not provenance: verify packages and staged bytes too.
    if (Test-Path -LiteralPath $manifestFile) {
        if (Test-ParquetManifest -BasePath $parquetDir -ManifestPath $manifestFile) {
            try {
                $cachedClient = Resolve-NuGetClient -CachePath $parquetDir
                if (-not $cachedClient.Kind) { throw 'A package signature verifier is required before loading the Parquet cache.' }
                Assert-NuGetPackageSignature -Client $cachedClient -PackageDir (Join-Path $parquetDir 'packages')
                Assert-ParquetPackagePayload -BasePath $parquetDir -PackageDir (Join-Path $parquetDir 'packages')
                $null = New-FinOpsPrivateDirectory -Path $parquetDir
                Import-ParquetAssemblies -BasePath $parquetDir
                return $true
            }
            catch {
                $null = New-FinOpsPrivateDirectory -Path $parquetDir
                Remove-Item -LiteralPath $parquetDir -Recurse -Force -ErrorAction Stop
            }
        }
        else {
            Write-Warning "Parquet cache failed integrity check - reinstalling."
            $null = New-FinOpsPrivateDirectory -Path $parquetDir
            Remove-Item -LiteralPath $parquetDir -Recurse -Force -ErrorAction Stop
        }
    }

    $script:FinOpsParquetUnavailableReason = $null
    $client = $null
    try {
        if (Test-Path -LiteralPath $parquetDir) {
            $null = New-FinOpsPrivateDirectory -Path $parquetDir
            Remove-Item -LiteralPath $parquetDir -Recurse -Force -ErrorAction Stop
        }
        $null = New-FinOpsPrivateDirectory -Path $parquetDir
        $client = Resolve-NuGetClient -CachePath $parquetDir
    }
    catch {
        $script:FinOpsParquetUnavailableReason = $_.Exception.Message
        Write-Warning "Failed to prepare the Parquet reader: $($_.Exception.Message)"
        return $false
    }

    # No usable client is a reportable outcome, not a silent downgrade: the
    # caller states the reason before it changes where the numbers come from.
    if (-not $client.Kind) {
        $script:FinOpsParquetUnavailableReason = $client.Reason
        return $false
    }

    Write-Host "    Installing Parquet reader (one-time setup)..." -ForegroundColor DarkGray

    try {
        $pkgDir = Join-Path $parquetDir 'packages'
        Invoke-NuGetRestore -Client $client -PackageId 'Parquet.Net' -Version '4.24.0' -PackageDir $pkgDir -WorkingPath $parquetDir

        # Verify package signatures on the fetched packages before any of
        # their assemblies are copied or loaded into this process.
        Assert-NuGetPackageSignature -Client $client -PackageDir $pkgDir

        # Copy managed DLLs to flat directory (prefer net8.0 > net6.0 > netstandard2.0)
        $libDir = Join-Path $parquetDir 'lib'
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null

        $fxPriority = @('net8.0', 'net7.0', 'net6.0', 'net5.0', 'netcoreapp3.1', 'netstandard2.1', 'netstandard2.0')
        $rid = Get-FinOpsNativeRid
        $ridCandidates = @($rid)
        # Matches what the integrity manifest hashes, including versioned names
        # such as libfoo.so.1 - a plain *.so filter would skip those and stage
        # an incomplete set.
        $nativePattern = if ($rid.StartsWith('win')) { '\.dll$' } elseif ($rid.StartsWith('osx')) { '\.dylib(\.\d+)*$' } else { '\.so(\.\d+)*$' }

        foreach ($pkgRoot in (Get-RestoredPackageRoot -PackageDir $pkgDir)) {
            $libRoot = Join-Path $pkgRoot 'lib'
            if (Test-Path -LiteralPath $libRoot) {
                foreach ($fx in $fxPriority) {
                    $fxDir = Join-Path $libRoot $fx
                    if (Test-Path -LiteralPath $fxDir) {
                        Get-ChildItem -LiteralPath $fxDir -Filter '*.dll' -File | ForEach-Object {
                            Copy-Item $_.FullName $libDir -Force
                        }
                        break
                    }
                }
            }

            # IronCompress ships one native library per RID; stage the one this
            # host can actually load rather than assuming win-x64.
            foreach ($candidate in $ridCandidates) {
                $nativeDir = Join-Path (Join-Path (Join-Path $pkgRoot 'runtimes') $candidate) 'native'
                if (-not (Test-Path -LiteralPath $nativeDir)) { continue }
                $targetNative = Join-Path (Join-Path (Join-Path $parquetDir 'runtimes') $candidate) 'native'
                New-Item -ItemType Directory -Path $targetNative -Force | Out-Null
                Get-ChildItem -LiteralPath $nativeDir -File | Where-Object { $_.Name -match $nativePattern } | ForEach-Object {
                    Copy-Item $_.FullName $targetNative -Force
                }
                break
            }
        }

        # Record hashes of everything we just staged so later loads can detect
        # tampering instead of trusting a bare marker file.
        Assert-ParquetPackagePayload -BasePath $parquetDir -PackageDir $pkgDir
        New-ParquetManifest -BasePath $parquetDir -ManifestPath $manifestFile

        $null = New-FinOpsPrivateDirectory -Path $parquetDir
        Import-ParquetAssemblies -BasePath $parquetDir
        Write-Host "    Parquet reader installed." -ForegroundColor DarkGray
        return $true
    }
    catch {
        $script:FinOpsParquetUnavailableReason = $_.Exception.Message
        Write-Warning "Failed to install Parquet reader: $($_.Exception.Message)"
        return $false
    }
}

function Import-ParquetAssemblies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    $libDir = Join-Path $BasePath 'lib'

    # Load order matters — dependencies before dependents
    $loadOrder = @(
        'System.Buffers.dll'
        'System.Memory.dll'
        'System.Runtime.CompilerServices.Unsafe.dll'
        'System.Collections.Immutable.dll'
        'Microsoft.IO.RecyclableMemoryStream.dll'
        'ZstdSharp.dll'
        'Snappier.dll'
        'IronCompress.dll'
        'Apache.Arrow.dll'
        'Microsoft.ML.DataView.dll'
        'Microsoft.Data.Analysis.dll'
        'Parquet.dll'
    )

    foreach ($dll in $loadOrder) {
        $path = Join-Path $libDir $dll
        if (-not (Test-Path $path)) { continue }

        $asmName = [IO.Path]::GetFileNameWithoutExtension($dll)
        $already = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
            $_.GetName().Name -eq $asmName
        }
        if ($already) { continue }

        try {
            Add-Type -Path $path -ErrorAction Stop
        }
        catch {
            # Swallow if the runtime already provides this assembly
            $recheck = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
                $_.GetName().Name -eq $asmName
            }
            if (-not $recheck) { throw }
        }
    }
}

function Read-ParquetFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $table = [Parquet.ParquetReader]::ReadTableFromFileAsync($Path, $null).GetAwaiter().GetResult()
        if (-not $table -or $table.Count -eq 0) { return @() }

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $colNames = @($table.Schema.GetDataFields() | ForEach-Object { $_.Name })

        for ($i = 0; $i -lt $table.Count; $i++) {
            $obj = [ordered]@{}
            foreach ($colName in $colNames) {
                $col = $table[$colName]
                $obj[$colName] = if ($col -and $i -lt $col.Data.Length) { $col.Data[$i] } else { $null }
            }
            $results.Add([PSCustomObject]$obj)
        }

        return $results
    }
    catch {
        throw "Failed to read Parquet file '$Path'; cost coverage is incomplete. $($_.Exception.Message)"
    }
}

# Resolve a row's subscription GUID. FOCUS exports use SubAccountId, older
# exports use SubscriptionId or x_SubscriptionId, and any of them may hold a
# full resource path rather than a bare GUID.
function Get-FinOpsHubRowSubscriptionId {
    param([object]$Row)

    $props = $Row.PSObject.Properties.Name
    $subId = if ($props -contains 'SubAccountId' -and $Row.SubAccountId) { $Row.SubAccountId }
    elseif ($props -contains 'SubscriptionId' -and $Row.SubscriptionId) { $Row.SubscriptionId }
    elseif ($props -contains 'x_SubscriptionId' -and $Row.x_SubscriptionId) { $Row.x_SubscriptionId }
    else { '' }

    if ($subId -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
        return $Matches[0].ToLower()
    }
    return ([string]$subId).ToLower()
}

function Format-FinOpsByteSize {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N1} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

function Test-FinOpsHubAccessDenied {
    # Separates "storage refused us" from ordinary misses like a month with no
    # data, which decides whether the caller reports unreachable or just unknown.
    param([string]$Message)
    return [bool]($Message -match 'not authorized|AuthorizationFailure|\(403\)|Forbidden|public access is not permitted|no longer allowed|denied')
}

function Get-FinOpsHubSizeClass {
    # Pure classification, deliberately free of I/O so every branch is testable
    # without reaching storage.
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Items,

        [Parameter()]
        [long]$LargeThresholdBytes = 256MB,

        [Parameter()]
        [int]$MaxFiles = 2000,

        # Set when the listing was cut short, which proves "large" on its own.
        [Parameter()]
        [switch]$Truncated
    )

    $bytes = 0L
    $count = 0
    foreach ($item in @($Items)) {
        if (-not $item) { continue }
        if ($item.IsDirectory) { continue }
        $bytes += [long]$item.Length
        $count++
    }

    $partial = ($Truncated -or $count -ge $MaxFiles)
    $atLeast = if ($partial) { 'at least ' } else { '' }
    return @{
        Known     = $true
        Reachable = $true
        Bytes     = $bytes
        FileCount = $count
        IsLarge   = ($bytes -ge $LargeThresholdBytes -or $partial)
        Display   = "$atLeast$(Format-FinOpsByteSize $bytes) across $atLeast$count file(s)"
        Issue     = $null
    }
}

function Measure-FinOpsHubSize {
    # Size probe of the ingestion container, used to decide whether the storage
    # reader is a reasonable choice before any data is downloaded. MaxCount bounds
    # the listing itself, so a 40 GB hub costs no more to classify than a 40 MB one.
    #
    # Known = $false means the probe could not run (no permission, no container).
    # Callers must treat that as "assume large" - an unknown hub is not a small one.
    # Reachable = $false is stronger: storage denied access outright, so the reader
    # cannot work at all and the caller should say so rather than warn about speed.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName,

        [Parameter()]
        [int]$Months = 1,

        # Parquet is columnar and compressed; PSCustomObject rows are neither, so
        # in-memory size is a large multiple of what is measured here. This stays
        # deliberately conservative rather than modelling that expansion exactly.
        [Parameter()]
        [long]$LargeThresholdBytes = 256MB,

        # A hub can be large by file count as well as by bytes, and either shape
        # makes the reader slow.
        [Parameter()]
        [int]$MaxFiles = 2000
    )

    $result = @{ Known = $false; Reachable = $true; Bytes = 0L; FileCount = 0; IsLarge = $true; Display = 'unknown size'; Issue = $null }

    try { $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop }
    catch {
        $result.Reachable = $false
        $result.Issue = $_.Exception.Message
        return $result
    }

    $collected = [System.Collections.Generic.List[object]]::new()
    $enumerated = $false
    $truncated = $false
    $now = Get-Date

    for ($m = 0; $m -lt $Months -and -not $truncated; $m++) {
        $d = $now.AddMonths(-$m)
        $basePath = "Costs/$($d.ToString('yyyy'))/$($d.ToString('MM'))"
        try {
            # One over the cap is enough to prove the listing was truncated.
            $items = @(Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'ingestion' -Path $basePath -Recurse -MaxCount ($MaxFiles + 1) -ErrorAction Stop)
            $enumerated = $true
            foreach ($item in $items) { [void]$collected.Add($item) }
            if ($items.Count -gt $MaxFiles) { $truncated = $true }
        }
        catch {
            # A missing month is normal; an auth or network denial is not.
            $msg = [string]$_.Exception.Message
            if (Test-FinOpsHubAccessDenied -Message $msg) {
                $result.Reachable = $false
                $result.Issue = $msg
                return $result
            }
            continue
        }
    }

    if (-not $enumerated) { return $result }

    return Get-FinOpsHubSizeClass -Items $collected.ToArray() -LargeThresholdBytes $LargeThresholdBytes -MaxFiles $MaxFiles -Truncated:$truncated
}

function Read-FinOpsHubData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter()]
        [ValidateRange(1, 36)]
        [int]$Months = 1,

        # Restrict returned rows to these subscriptions. A hub holds every
        # subscription it ingests, so without this a scoped scan reports on
        # subscriptions the user did not select.
        [Parameter()]
        [string[]]$SubscriptionIds
    )

    Write-Host "    Connecting to Hub storage: $StorageAccountName" -ForegroundColor DarkGray

    $wanted = @{}
    foreach ($subscriptionId in $SubscriptionIds) {
        $parsedId = [guid]::Empty
        if (-not [guid]::TryParse($subscriptionId, [ref]$parsedId)) { throw 'Invalid subscription ID; refusing an unscoped hub read.' }
        $wanted[$parsedId.ToString()] = $true
    }
    try {
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop
    }
    catch {
        throw "Failed to connect to hub storage; cost coverage is incomplete. $($_.Exception.Message)"
    }

    $allData = [System.Collections.Generic.List[PSCustomObject]]::new()
    $loadedFormat = $null
    $tempDir = New-FinOpsPrivateDirectory -Path (Join-Path (Split-Path (Get-FinOpsParquetCachePath) -Parent) "download-$([guid]::NewGuid().ToString('N'))") -RequireNew

    try {
        # -- Strategy 1: Parquet from ingestion (normalized FOCUS) ---------
        $now = Get-Date
        for ($m = 0; $m -lt $Months; $m++) {
            $d = $now.AddMonths(-$m)
            $basePath = "Costs/$($d.ToString('yyyy'))/$($d.ToString('MM'))"
            $listed = $false
            try {
                $blobs = @(Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'ingestion' -Path $basePath -Recurse -ErrorAction Stop |
                    Where-Object { -not $_.IsDirectory -and $_.Name -like '*.parquet' })
                $listed = $true

                if ($blobs.Count -gt 0) {
                    # Install parquet reader on first parquet file encountered
                    if ($allData.Count -eq 0) {
                        $hasParquet = Install-ParquetReader
                        if (-not $hasParquet) {
                            # Name the cause and the change of source: a bare
                            # "falling back" line reads like a clean scan.
                            $why = if ($script:FinOpsParquetUnavailableReason) { $script:FinOpsParquetUnavailableReason } else { 'the Parquet reader could not be installed' }
                            Write-Warning "Reading Hub CSV exports instead of Parquet because $why. Figures come from msexports rather than normalized ingestion."
                            break
                        }
                    }

                    Write-Host "    Reading ingestion: $basePath ($($blobs.Count) file(s))" -ForegroundColor DarkGray
                    foreach ($blob in $blobs) {
                        $localFile = Join-Path $tempDir "$([guid]::NewGuid().ToString('N')).parquet"
                        try {
                            Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem 'ingestion' -Path $blob.Path -Destination $localFile -Force -ErrorAction Stop | Out-Null
                            $rows = @(Read-ParquetFile -Path $localFile -ErrorAction Stop)
                            if ($rows -and @($rows).Count -gt 0) {
                                $loadedFormat = 'Parquet'
                                foreach ($row in $rows) { $allData.Add($row) }
                                Write-Host "    Loaded $(@($rows).Count) rows from $(Split-Path $blob.Path -Leaf)" -ForegroundColor DarkGray
                            }
                        }
                        finally {
                            Remove-Item -LiteralPath $localFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
            catch {
                if (-not $listed -and $_.Exception.Message -match 'PathNotFound|FilesystemNotFound|\b404\b') { continue }
                throw "Hub ingestion read failed; cost coverage is incomplete. $($_.Exception.Message)"
            }
        }

        # -- Strategy 2: CSV from msexports (raw FOCUS export) -------------
        if ($allData.Count -eq 0) {
            Write-Host "    No parquet in ingestion — reading CSV from msexports..." -ForegroundColor DarkGray

            $csvBlobs = @(Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'msexports' -Recurse -ErrorAction Stop |
                Where-Object { -not $_.IsDirectory -and $_.Path -like '*.csv' })

            if ($csvBlobs.Count -gt 0) {
                # Export layout is: .../<billingPeriod>/<runTimestamp>/<guid>/part_*.csv
                # where billingPeriod = yyyyMMdd-yyyyMMdd and runTimestamp = 12 digits.
                # Group by billing period, and within each period keep only the latest
                # run. Walking periods newest-first and skipping empty ones means a
                # just-started current month (header-only export) falls back to the
                # latest populated period instead of returning nothing.
                $periods = [ordered]@{}
                foreach ($blob in $csvBlobs) {
                    $period = [regex]::Match($blob.Path, '(\d{8}-\d{8})').Value
                    $run = [regex]::Match($blob.Path, '[\\/](\d{12})[\\/]').Groups[1].Value
                    if (-not $period) { $period = Split-Path (Split-Path $blob.Path -Parent) -Parent }
                    if (-not $periods.Contains($period)) {
                        $periods[$period] = @{ Runs = [ordered]@{} }
                    }
                    if (-not $periods[$period].Runs.Contains($run)) {
                        $periods[$period].Runs[$run] = [System.Collections.Generic.List[object]]::new()
                    }
                    $periods[$period].Runs[$run].Add($blob)
                }

                # Newest billing period first.
                $orderedPeriods = $periods.Keys | Sort-Object -Descending
                $periodsLoaded = 0

                foreach ($period in $orderedPeriods) {
                    if ($periodsLoaded -ge $Months) { break }

                    # Latest run within this period.
                    $latestRunKey = $periods[$period].Runs.Keys | Sort-Object -Descending | Select-Object -First 1
                    $runBlobs = $periods[$period].Runs[$latestRunKey]
                    Write-Host "    Period $period — latest run has $($runBlobs.Count) CSV file(s)" -ForegroundColor DarkGray

                    $periodRows = 0
                    foreach ($blob in $runBlobs) {
                        $localFile = Join-Path $tempDir "$([guid]::NewGuid().ToString('N'))-$(Split-Path $blob.Path -Leaf)"
                        try {
                            Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem 'msexports' -Path $blob.Path -Destination $localFile -Force -ErrorAction Stop | Out-Null
                            $rows = Import-Csv -Path $localFile -ErrorAction Stop
                            if ($rows -and @($rows).Count -gt 0) {
                                $loadedFormat = 'CSV'
                                foreach ($row in $rows) { $allData.Add($row) }
                                $periodRows += @($rows).Count
                            }
                        }
                        catch {
                            throw "Hub CSV read failed; cost coverage is incomplete. $($_.Exception.Message)"
                        }
                        finally {
                            Remove-Item -LiteralPath $localFile -Force -ErrorAction SilentlyContinue
                        }
                    }

                    if ($periodRows -gt 0) {
                        Write-Host "    Loaded $periodRows rows from period $period" -ForegroundColor DarkGray
                        $periodsLoaded++
                    }
                    else {
                        Write-Host "    Period $period had no rows — skipping to next" -ForegroundColor DarkGray
                    }
                }
            }
            else {
                Write-Host "    No cost data found in Hub storage" -ForegroundColor Yellow
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($allData.Count -gt 0) {
        Write-Host "    Total rows from Hub ($loadedFormat): $($allData.Count)" -ForegroundColor Green
    }

    if ($wanted.Count -gt 0) {
        $before = $allData.Count
        $covered = @{}
        $selectedRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($row in $allData) {
            $rowSubscription = Get-FinOpsHubRowSubscriptionId $row
            if (-not $rowSubscription) { throw 'A hub row has no subscription ID; cost coverage is incomplete.' }
            if ($wanted.ContainsKey($rowSubscription)) {
                [void]$selectedRows.Add($row)
                $covered[$rowSubscription] = $true
            }
        }
        foreach ($subscriptionId in $wanted.Keys) {
            if (-not $covered.ContainsKey($subscriptionId)) { throw "No hub rows for selected subscription '$subscriptionId'; cost coverage is incomplete." }
        }
        $allData = $selectedRows.ToArray()
        Write-Host "    Scoped to $($SubscriptionIds.Count) selected subscription(s): $($allData.Count) of $before rows" -ForegroundColor DarkGray
    }

    return $allData
}

function ConvertTo-CostDataFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Convert FOCUS-schema Hub data into the same hashtable format
    # that Get-CostData returns: @{ subscriptionId = @{ Actual; Forecast; Currency } }
    $costMap = @{}
    $props = $HubData[0].PSObject.Properties.Name
    $costSchema = Get-HubCostSchema -HubData $HubData
    $costCol = $costSchema.CostColumn

    foreach ($row in $HubData) {
        $subId = if ($props -contains 'SubAccountId' -and $row.SubAccountId) { $row.SubAccountId }
        elseif ($props -contains 'SubscriptionId' -and $row.SubscriptionId) { $row.SubscriptionId }
        elseif ($props -contains 'x_SubscriptionId' -and $row.x_SubscriptionId) { $row.x_SubscriptionId }
        else { 'unknown' }

        # FOCUS SubAccountId may be full resource path — extract just the GUID
        if ($subId -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
            $subId = $Matches[0]
        }

        # Display name from the FOCUS data so the UI can label by name, not GUID.
        $subName = if ($props -contains 'SubAccountName' -and $row.SubAccountName) { [string]$row.SubAccountName }
        elseif ($props -contains 'SubscriptionName' -and $row.SubscriptionName) { [string]$row.SubscriptionName }
        else { '' }

        $cost = Get-HubCostValue -Row $row -Column $costCol

        $currency = if ($props -contains 'BillingCurrency' -and $row.BillingCurrency) { $row.BillingCurrency }
        elseif ($props -contains 'BillingCurrencyCode' -and $row.BillingCurrencyCode) { $row.BillingCurrencyCode }
        else { $costSchema.Currency }

        if (-not $costMap.ContainsKey($subId)) {
            $subscriptionPeriod = $costSchema.PeriodsBySubscription[$subId]
            $costMap[$subId] = @{
                Actual = 0.0; Forecast = $null; ForecastSource = 'Unavailable'; Currency = $currency; Name = $subName
                ActualPeriodStart = $subscriptionPeriod.PeriodStart; ActualPeriodEnd = $subscriptionPeriod.PeriodEnd
                ActualPeriod = if ($subscriptionPeriod) { $subscriptionPeriod.Period } else { 'Unknown' }
            }
        }
        $costMap[$subId].Actual += $cost
    }

    return $costMap
}

function ConvertTo-ResourceCostsFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Aggregate by resource and return in the same format as Get-ResourceCosts
    $resourceMap = @{}
    $props = $HubData[0].PSObject.Properties.Name
    $costSchema = Get-HubCostSchema -HubData $HubData
    $costCol = $costSchema.CostColumn

    foreach ($row in $HubData) {
        $subName = if ($props -contains 'SubAccountName' -and $row.SubAccountName) { $row.SubAccountName }
        elseif ($props -contains 'SubscriptionName' -and $row.SubscriptionName) { $row.SubscriptionName }
        elseif ($props -contains 'SubAccountId') { $row.SubAccountId }
        else { 'unknown' }

        $rg = if ($props -contains 'x_ResourceGroupName' -and $row.x_ResourceGroupName) { $row.x_ResourceGroupName }
        elseif ($props -contains 'ResourceGroup' -and $row.ResourceGroup) { $row.ResourceGroup }
        elseif ($props -contains 'ResourceGroupName' -and $row.ResourceGroupName) { $row.ResourceGroupName }
        else { 'unknown' }

        $resType = if ($props -contains 'ResourceType' -and $row.ResourceType) { $row.ResourceType }
        elseif ($props -contains 'x_ResourceType' -and $row.x_ResourceType) { $row.x_ResourceType }
        elseif ($props -contains 'ConsumedService' -and $row.ConsumedService) { $row.ConsumedService }
        else { 'unknown' }

        $resId = if ($props -contains 'ResourceId' -and $row.ResourceId) { $row.ResourceId }
        elseif ($props -contains 'x_ResourceId' -and $row.x_ResourceId) { $row.x_ResourceId }
        else { "$rg/$resType" }

        $cost = Get-HubCostValue -Row $row -Column $costCol

        $currency = if ($props -contains 'BillingCurrency' -and $row.BillingCurrency) { $row.BillingCurrency }
        elseif ($props -contains 'BillingCurrencyCode' -and $row.BillingCurrencyCode) { $row.BillingCurrencyCode }
        else { $costSchema.Currency }

        $key = $resId
        if (-not $resourceMap.ContainsKey($key)) {
            $subscriptionPeriod = $costSchema.PeriodsBySubscription[(Get-FinOpsHubRowSubscriptionId $row)]
            $resourceMap[$key] = [PSCustomObject]@{
                Subscription  = $subName
                ResourceGroup = $rg
                ResourceType  = $resType
                ResourcePath  = $resId
                Actual        = 0.0
                Forecast      = $null
                Currency      = $currency
                ActualPeriod  = if ($subscriptionPeriod) { $subscriptionPeriod.Period } else { 'Unknown' }
            }
        }
        $resourceMap[$key].Actual += $cost
    }

    return @($resourceMap.Values | Sort-Object { $_.Actual } -Descending)
}

# Helper: pick the first present/non-empty property from a row.
function Get-HubRowValue {
    param(
        [Parameter(Mandatory)][object]$Row,
        [Parameter(Mandatory)][string[]]$Names,
        [string[]]$Props
    )
    if (-not $Props) { $Props = $Row.PSObject.Properties.Name }
    foreach ($n in $Names) {
        if ($Props -contains $n -and $null -ne $Row.$n -and "$($Row.$n)".Trim() -ne '') {
            return $Row.$n
        }
    }
    return $null
}

function Resolve-HubCostColumn {
    param(
        [string[]]$Props,
        [ValidateSet('ActualCost', 'AmortizedCost')]
        [string]$CostBasis = 'ActualCost'
    )

    $candidates = if ($CostBasis -eq 'AmortizedCost') { @('EffectiveCost') }
    else { @('BilledCost', 'CostInBillingCurrency', 'PreTaxCost', 'Cost') }
    foreach ($column in $candidates) {
        if ($Props -contains $column) { return $column }
    }
    if ($CostBasis -eq 'AmortizedCost') {
        throw 'AmortizedCost is unavailable in the selected Hub data. This scan requires EffectiveCost from a FOCUS export. Billed cost is not substituted. Use a FOCUS export with EffectiveCost or select API for a separate live scan.'
    }
    throw "No $CostBasis column is available; cost results are incomplete."
}

function Get-HubCostValue {
    param(
        [Parameter(Mandatory)][object]$Row,
        [string]$Column
    )
    if (-not $Column) { throw 'No cost column was selected; cost results are incomplete.' }
    $raw = $Row.$Column
    $text = ([string]$raw).Trim()
    if ($text.Contains(',') -and $text -notmatch '^[+-]?\d{1,3}(,\d{3})+(\.\d+)?([eE][+-]?\d+)?$') {
        throw "Invalid numeric grouping in '$Column'; cost results are incomplete."
    }
    $amount = 0.0
    $styles = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
    if ($null -eq $raw -or
        -not [double]::TryParse($text, $styles, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$amount) -or
        [double]::IsNaN($amount) -or [double]::IsInfinity($amount)) {
        throw "Missing or invalid cost in '$Column'; cost results are incomplete."
    }
    return $amount
}

function Get-HubCostSchema {
    param(
        [Parameter(Mandatory)][object[]]$HubData,
        [ValidateSet('ActualCost', 'AmortizedCost')]
        [string]$CostBasis = 'ActualCost'
    )

    $headers = [System.Collections.Generic.HashSet[string]]::new([string[]]$HubData[0].PSObject.Properties.Name, [System.StringComparer]::OrdinalIgnoreCase)
    $costColumn = Resolve-HubCostColumn -Props @($headers) -CostBasis $CostBasis
    $currency = $null
    $periodStart = $null
    $periodEnd = $null
    $periodKnown = $true
    $periodsBySubscription = @{}
    foreach ($row in $HubData) {
        if (-not $headers.SetEquals([string[]]$row.PSObject.Properties.Name)) {
            throw 'Hub row schemas differ; cost results are incomplete.'
        }
        $null = Get-HubCostValue -Row $row -Column $costColumn
        $rowCurrency = [string](Get-HubRowValue -Row $row -Names @('BillingCurrency', 'BillingCurrencyCode', 'Currency'))
        if ([string]::IsNullOrWhiteSpace($rowCurrency)) {
            throw 'Billing currency is missing; cost results are incomplete.'
        }
        $rowCurrency = $rowCurrency.Trim().ToUpperInvariant()
        if ($currency -and $currency -ne $rowCurrency) {
            throw 'Multiple billing currencies cannot be combined into one cost total.'
        }
        $currency = $rowCurrency
        $rawDate = Get-HubRowValue -Row $row -Names @('ChargePeriodStart', 'Date', 'UsageDate', 'UsageDateTime')
        $date = $null
        try {
            $date = if ($rawDate -is [datetime]) { $rawDate.ToUniversalTime() }
            elseif ([string]$rawDate -match '^\d{8}$') { [datetime]::ParseExact([string]$rawDate, 'yyyyMMdd', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
            else { [datetimeoffset]::Parse([string]$rawDate, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime }
            if ($null -eq $periodStart -or $date -lt $periodStart) { $periodStart = $date }
            if ($null -eq $periodEnd -or $date -gt $periodEnd) { $periodEnd = $date }
        }
        catch { $periodKnown = $false }
        $subscriptionId = Get-FinOpsHubRowSubscriptionId $row
        if ($subscriptionId) {
            if (-not $periodsBySubscription.ContainsKey($subscriptionId)) {
                $periodsBySubscription[$subscriptionId] = @{ PeriodStart = $null; PeriodEnd = $null; Known = $true }
            }
            $subscriptionPeriod = $periodsBySubscription[$subscriptionId]
            if ($null -eq $date) { $subscriptionPeriod.Known = $false }
            else {
                if ($null -eq $subscriptionPeriod.PeriodStart -or $date -lt $subscriptionPeriod.PeriodStart) { $subscriptionPeriod.PeriodStart = $date }
                if ($null -eq $subscriptionPeriod.PeriodEnd -or $date -gt $subscriptionPeriod.PeriodEnd) { $subscriptionPeriod.PeriodEnd = $date }
            }
        }
    }
    if (-not $periodKnown) { $periodStart = $null; $periodEnd = $null }
    foreach ($subscriptionPeriod in $periodsBySubscription.Values) {
        if (-not $subscriptionPeriod.Known) { $subscriptionPeriod.PeriodStart = $null; $subscriptionPeriod.PeriodEnd = $null }
        $subscriptionPeriod.Period = if ($subscriptionPeriod.Known) {
            '{0:yyyy-MM-dd} to {1:yyyy-MM-dd}' -f $subscriptionPeriod.PeriodStart, $subscriptionPeriod.PeriodEnd
        }
        else { 'Unknown' }
    }
    return @{
        CostColumn = $costColumn; Currency = $currency; CostBasis = $CostBasis
        PeriodStart = $periodStart; PeriodEnd = $periodEnd
        PeriodsBySubscription = $periodsBySubscription
        Period = if ($null -ne $periodStart -and $null -ne $periodEnd) { '{0:yyyy-MM-dd} to {1:yyyy-MM-dd}' -f $periodStart, $periodEnd } else { 'Unknown' }
    }
}

# Helper: convert a billing unit string (e.g. "1K", "1M", "1,000",
# "100 Tokens") into the number of tokens one unit of quantity represents.
# Azure OpenAI token meters are billed per-1K tokens, so an unqualified
# unit defaults to 1000 (flagged as approximate by the caller).
function Get-TokenUnitMultiplier {
    param([string]$Unit)
    if (-not $Unit) { return @{ Multiplier = 1000.0; Known = $false } }
    $u = $Unit.Trim()

    # Pure number, e.g. "1000" or "1,000,000".
    $numOnly = ($u -replace '[,\s]', '')
    if ($numOnly -match '^\d+(\.\d+)?$') { return @{ Multiplier = [double]$numOnly; Known = $true } }

    # Scaled, e.g. "1K", "10K", "1M".
    $m = [regex]::Match($u, '(?i)([\d,\.]+)?\s*([KM])\b')
    if ($m.Success) {
        $n = if ($m.Groups[1].Value) { [double]($m.Groups[1].Value -replace ',', '') } else { 1.0 }
        $scale = if ($m.Groups[2].Value -match '(?i)M') { 1e6 } else { 1e3 }
        return @{ Multiplier = ($n * $scale); Known = $true }
    }

    # Plain "tokens" / "count" / "units" — quantity is already raw tokens.
    if ($u -match '(?i)\b(token|tokens|count|units|unit)\b') { return @{ Multiplier = 1.0; Known = $true } }

    # Unknown unit — assume the AOAI per-1K convention but flag it.
    return @{ Multiplier = 1000.0; Known = $false }
}

# Helper: strip token-type and qualifier words from an Azure OpenAI meter
# name to derive a model/deployment grouping key.
function Get-AIModelKeyFromMeter {
    param([string]$Meter)
    if (-not $Meter) { return 'unknown' }
    $k = $Meter -replace '(?i)\b(inp|input|prompt|outp|output|generated|completion|cached|cache|regional|global|glbl|reg|data|stored|tokens|token)\b', ''
    $k = ($k -replace '\s+', ' ').Trim(' -')
    if ([string]::IsNullOrWhiteSpace($k)) { return ([string]$Meter).Trim() }
    return $k
}

function ConvertTo-AIHubAggregates {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$HubData
    )

    # Aggregate Azure OpenAI / Cognitive Services spend and billed token
    # volume straight from FOCUS export rows. Only cognitiveservices/accounts
    # rows are priced (matching the live Cost Management filter). Request
    # counts are not billed line items, so cost-per-request is unavailable
    # on this path.
    $modelTokens = @{}   # modelKey -> @{ Prompt; Generated; Total }
    $acctTokens = @{}   # resourceId(lower) -> @{ Name; Tokens; Requests }
    $costByAcct = @{}   # resourceId(lower) -> cost
    $totalPrompt = 0.0
    $totalGen = 0.0
    $totalTokens = 0.0
    $aiCost = 0.0
    $currency = 'USD'
    $tokenRows = 0
    $approximate = $false

    if (-not $HubData -or @($HubData).Count -eq 0) {
        return [PSCustomObject]@{
            RowCount = 0; TotalPrompt = 0; TotalGen = 0; TotalTokens = 0
            AICost = 0; Currency = $currency; ModelTokens = $modelTokens
            AcctTokens = $acctTokens; CostByAcct = $costByAcct
            HasTokens = $false; HasCost = $false; Approximate = $false
        }
    }

    $props = $HubData[0].PSObject.Properties.Name
    $costSchema = Get-HubCostSchema -HubData $HubData -CostBasis 'AmortizedCost'
    $costCol = $costSchema.CostColumn
    $currency = $costSchema.Currency

    foreach ($row in $HubData) {
        $resType = Get-HubRowValue -Row $row -Props $props -Names @('ResourceType', 'x_ResourceType', 'ConsumedService')
        if (-not $resType -or "$resType".ToLowerInvariant() -notmatch 'cognitiveservices') { continue }

        $rid = Get-HubRowValue -Row $row -Props $props -Names @('ResourceId', 'x_ResourceId')
        if (-not $rid) { continue }
        $ridKey = "$rid".ToLowerInvariant()

        $name = Get-HubRowValue -Row $row -Props $props -Names @('ResourceName')
        if (-not $name) { $name = Split-Path "$rid" -Leaf }

        $cost = Get-HubCostValue -Row $row -Column $costCol

        $cur = Get-HubRowValue -Row $row -Props $props -Names @('BillingCurrency', 'BillingCurrencyCode')
        if ($cur) { $currency = "$cur" }

        if (-not $acctTokens.ContainsKey($ridKey)) {
            $acctTokens[$ridKey] = @{ Name = "$name"; Tokens = 0.0; Requests = 0.0 }
        }
        if (-not $costByAcct.ContainsKey($ridKey)) { $costByAcct[$ridKey] = 0.0 }
        $costByAcct[$ridKey] += $cost
        $aiCost += $cost

        # Token attribution from the meter name + billed quantity.
        $meter = Get-HubRowValue -Row $row -Props $props -Names @('x_SkuMeterName', 'MeterName', 'SkuMeterName', 'x_SkuDescription')
        if (-not $meter -or "$meter" -notmatch '(?i)token') { continue }

        $qty = Get-HubRowValue -Row $row -Props $props -Names @('ConsumedQuantity', 'x_ConsumedQuantity', 'Quantity', 'UsageQuantity')
        $qty = if ($null -ne $qty) { [double]$qty } else { 0.0 }
        if ($qty -le 0) { continue }

        $unit = Get-HubRowValue -Row $row -Props $props -Names @('ConsumedUnit', 'x_PricingUnitDescription', 'UnitOfMeasure', 'PricingUnit')
        $mult = Get-TokenUnitMultiplier -Unit "$unit"
        if (-not $mult.Known) { $approximate = $true }
        $tokens = $qty * $mult.Multiplier

        $modelKey = Get-AIModelKeyFromMeter -Meter "$meter"
        if (-not $modelTokens.ContainsKey($modelKey)) {
            $modelTokens[$modelKey] = @{ Prompt = 0.0; Generated = 0.0; Total = 0.0 }
        }

        if ("$meter" -match '(?i)\b(inp|input|prompt|cached|cache)\b') {
            $modelTokens[$modelKey].Prompt += $tokens
            $totalPrompt += $tokens
            $acctTokens[$ridKey].Tokens += $tokens
        }
        elseif ("$meter" -match '(?i)\b(outp|output|generated|completion)\b') {
            $modelTokens[$modelKey].Generated += $tokens
            $totalGen += $tokens
            $acctTokens[$ridKey].Tokens += $tokens
        }
        else {
            $acctTokens[$ridKey].Tokens += $tokens
        }
        $modelTokens[$modelKey].Total += $tokens
        $totalTokens += $tokens
        $tokenRows++
    }

    return [PSCustomObject]@{
        RowCount    = $tokenRows
        TotalPrompt = $totalPrompt
        TotalGen    = $totalGen
        TotalTokens = $totalTokens
        AICost      = $aiCost
        Currency    = $currency
        ModelTokens = $modelTokens
        AcctTokens  = $acctTokens
        CostByAcct  = $costByAcct
        HasTokens   = ($totalTokens -gt 0)
        HasCost     = ($aiCost -gt 0)
        Approximate = $approximate
        Period      = $costSchema.Period
    }
}

function ConvertTo-TagInventoryFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Extract tag inventory from FOCUS cost data Tags JSON column
    # Returns same structure as Get-TagInventory
    $tagNames = @{}
    $totalResources = 0
    $taggedCount = 0
    $untaggedResources = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenResources = @{}
    $props = $HubData[0].PSObject.Properties.Name

    foreach ($row in $HubData) {
        $resId = if ($props -contains 'ResourceId' -and $row.ResourceId) { $row.ResourceId }
        elseif ($props -contains 'x_ResourceId' -and $row.x_ResourceId) { $row.x_ResourceId }
        else { $null }

        # Deduplicate by resource ID (cost rows repeat per line item)
        if (-not $resId -or $seenResources.ContainsKey($resId)) { continue }
        $seenResources[$resId] = $true
        $totalResources++

        $resName = if ($props -contains 'ResourceName' -and $row.ResourceName) { $row.ResourceName } else { Split-Path $resId -Leaf }
        $resType = if ($props -contains 'ResourceType' -and $row.ResourceType) { $row.ResourceType }
        elseif ($props -contains 'x_ResourceType' -and $row.x_ResourceType) { $row.x_ResourceType }
        else { 'unknown' }
        $rg = if ($props -contains 'x_ResourceGroupName' -and $row.x_ResourceGroupName) { $row.x_ResourceGroupName }
        elseif ($props -contains 'ResourceGroup' -and $row.ResourceGroup) { $row.ResourceGroup }
        else { 'unknown' }
        $sub = if ($props -contains 'SubAccountName' -and $row.SubAccountName) { $row.SubAccountName }
        elseif ($props -contains 'SubscriptionName' -and $row.SubscriptionName) { $row.SubscriptionName }
        else { 'unknown' }

        # Parse Tags JSON
        $tagsJson = if ($props -contains 'Tags') { $row.Tags } else { $null }
        $tagDict = $null
        if ($tagsJson -and $tagsJson.Trim() -ne '' -and $tagsJson.Trim() -ne '{}') {
            try { $tagDict = ConvertTo-HashtableFromJson -Json $tagsJson } catch {
                Write-Verbose "Non-fatal: $($_.Exception.Message)"
            }
        }

        if ($tagDict -and $tagDict.Count -gt 0) {
            $taggedCount++
            foreach ($kv in $tagDict.GetEnumerator()) {
                $tName = $kv.Key
                $tVal = if ($kv.Value) { "$($kv.Value)" } else { '(empty)' }

                if (-not $tagNames.ContainsKey($tName)) {
                    $tagNames[$tName] = @{
                        Values         = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
                        TotalResources = 0
                    }
                }
                $tagNames[$tName].TotalResources++

                if (-not $tagNames[$tName].Values.ContainsKey($tVal)) {
                    $tagNames[$tName].Values[$tVal] = @{ ResourceCount = 0; ResourceTypes = @{} }
                }
                $tagNames[$tName].Values[$tVal].ResourceCount++
                $tagNames[$tName].Values[$tVal].ResourceTypes[$resType] = $true
            }
        }
        else {
            if ($untaggedResources.Count -lt 500) {
                $untaggedResources.Add([PSCustomObject]@{
                        ResourceName  = $resName
                        ResourceType  = $resType
                        ResourceGroup = $rg
                        Subscription  = $sub
                        Location      = ''
                    })
            }
        }
    }

    # Convert Values hashes to arrays matching Get-TagInventory format
    $tagNamesOut = @{}
    foreach ($kv in $tagNames.GetEnumerator()) {
        $valArray = @()
        foreach ($v in $kv.Value.Values.GetEnumerator()) {
            $valArray += [PSCustomObject]@{
                Value         = $v.Key
                ResourceCount = $v.Value.ResourceCount
                ResourceTypes = @($v.Value.ResourceTypes.Keys)
            }
        }
        $tagNamesOut[$kv.Key] = @{
            Values         = ($valArray | Sort-Object ResourceCount -Descending)
            TotalResources = $kv.Value.TotalResources
        }
    }

    $untaggedCount = $totalResources - $taggedCount
    $coverage = if ($totalResources -gt 0) { [math]::Round(($taggedCount / $totalResources) * 100, 1) } else { 0 }

    return [PSCustomObject]@{
        TagNames          = $tagNamesOut
        TagCount          = $tagNamesOut.Count
        TotalResources    = $totalResources
        TaggedCount       = $taggedCount
        UntaggedCount     = $untaggedCount
        TagCoverage       = $coverage
        UntaggedResources = @($untaggedResources)
        Source            = 'Hub'
    }
}

function ConvertTo-CostByTagFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData,

        [Parameter()]
        [hashtable]$ExistingTags
    )

    # Aggregate cost by tag key/value from FOCUS cost data
    # Returns same structure as Get-CostByTag
    $props = $HubData[0].PSObject.Properties.Name
    $costSchema = Get-HubCostSchema -HubData $HubData
    $costCol = $costSchema.CostColumn
    $costByTag = @{}
    $currency = $costSchema.Currency

    $targetTags = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tagKey in $ExistingTags.Keys) { [void]$targetTags.Add($tagKey) }
    $tagRows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $HubData) {
        $cost = Get-HubCostValue -Row $row -Column $costCol
        $tagsJson = if ($props -contains 'Tags') { $row.Tags } else { $null }
        $tagDict = ConvertFrom-ExportTagString -Raw $tagsJson
        if (-not $ExistingTags -or $ExistingTags.Count -eq 0) {
            foreach ($tagKey in $tagDict.Keys) { [void]$targetTags.Add($tagKey) }
        }
        [void]$tagRows.Add(@{ Cost = $cost; Tags = $tagDict })
    }

    foreach ($row in $tagRows) {
        foreach ($tagKey in $targetTags) {
            if (-not $costByTag.ContainsKey($tagKey)) { $costByTag[$tagKey] = [System.Collections.Generic.Dictionary[string, double]]::new([System.StringComparer]::Ordinal) }
            $tagVal = if ($row.Tags.ContainsKey($tagKey)) { [string]$row.Tags[$tagKey] } else { '(untagged)' }
            if (-not $tagVal -or $tagVal -eq '') { $tagVal = '(empty)' }

            if (-not $costByTag[$tagKey].ContainsKey($tagVal)) { $costByTag[$tagKey][$tagVal] = 0.0 }
            $costByTag[$tagKey][$tagVal] += $row.Cost
        }
    }

    # Convert to output format matching Get-CostByTag
    $costByTagOut = @{}
    foreach ($kv in $costByTag.GetEnumerator()) {
        $costByTagOut[$kv.Key] = @($kv.Value.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{
                    TagValue = $_.Key
                    Cost     = [math]::Round($_.Value, 2)
                    Currency = $currency
                }
            } | Sort-Object Cost -Descending)
    }

    return [PSCustomObject]@{
        TagsQueried   = @($costByTagOut.Keys)
        CostByTag     = $costByTagOut
        NoTagsFound   = ($costByTagOut.Count -eq 0)
        UsedTimeframe = 'Hub export period'
        Source        = 'Hub'
    }
}
