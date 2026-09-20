# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Parquet package acquisition' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force

        # A script block rather than a New-* function: the analyzer would demand
        # ShouldProcess support on a state-changing verb for a test fixture.
        $script:NewTempTree = {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) "ftk-pkg-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            return $root
        }
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Private data directories' {
        It 'Uses application data without a shared-temp fallback' {
            $base = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData, [Environment+SpecialFolderOption]::DoNotVerify)
            Get-FinOpsParquetCachePath | Should -Be (Join-Path $base 'FinOpsMultitool/parquet')
            (Get-Command Get-FinOpsParquetCachePath).Definition | Should -Not -Match 'GetTempPath'
        }

        It 'Creates a new owner-only directory and refuses to reuse it' {
            $path = New-FinOpsPrivateDirectory -Path (Join-Path $TestDrive 'private-data') -RequireNew
            if ($IsWindows) {
                $security = Get-Acl -LiteralPath $path
                $security.AreAccessRulesProtected | Should -BeTrue
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                try {
                    $rules = @($security.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
                    $rules.Count | Should -Be 1
                    $rules[0].IdentityReference.Value | Should -Be $identity.User.Value
                }
                finally { $identity.Dispose() }
            }
            else {
                $mode = [IO.File]::GetUnixFileMode($path)
                ([int]$mode -band 511) | Should -Be 448
            }
            { New-FinOpsPrivateDirectory -Path $path -RequireNew } | Should -Throw '*already exists*'
        }

        It 'Refuses a cache writable by other Windows users' -Skip:(-not $IsWindows) {
            $path = New-FinOpsPrivateDirectory -Path (Join-Path $TestDrive 'unsafe-cache') -RequireNew
            $security = Get-Acl -LiteralPath $path
            $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
                [Security.Principal.SecurityIdentifier]::new('S-1-1-0'), [Security.AccessControl.FileSystemRights]::Write,
                [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
                [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Allow))
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($path), $security)

            { New-FinOpsPrivateDirectory -Path $path } | Should -Throw '*writes by another account*'
        }

        It 'Refuses a Windows parent directory writable by other users' -Skip:(-not $IsWindows) {
            $parent = New-FinOpsPrivateDirectory -Path (Join-Path $TestDrive 'unsafe-parent') -RequireNew
            $security = Get-Acl -LiteralPath $parent
            $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
                [Security.Principal.SecurityIdentifier]::new('S-1-1-0'), [Security.AccessControl.FileSystemRights]::Write,
                [Security.AccessControl.InheritanceFlags]::None, [Security.AccessControl.PropagationFlags]::None,
                [Security.AccessControl.AccessControlType]::Allow))
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($parent), $security)

            { New-FinOpsPrivateDirectory -Path (Join-Path $parent 'download') -RequireNew } | Should -Throw '*writes by another account*'
            Test-Path -LiteralPath (Join-Path $parent 'download') | Should -BeFalse
        }

        It 'Rejects replacement permissions on a higher Windows ancestor before creating children' -Skip:(-not $IsWindows) {
            $grandparent = New-FinOpsPrivateDirectory -Path (Join-Path $TestDrive 'unsafe-grandparent') -RequireNew
            $parent = New-FinOpsPrivateDirectory -Path (Join-Path $grandparent 'protected-parent') -RequireNew
            $security = Get-Acl -LiteralPath $grandparent
            $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
                [Security.Principal.SecurityIdentifier]::new('S-1-1-0'), [Security.AccessControl.FileSystemRights]::FullControl,
                [Security.AccessControl.InheritanceFlags]::None, [Security.AccessControl.PropagationFlags]::None,
                [Security.AccessControl.AccessControlType]::Allow))
            [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($grandparent), $security)

            { New-FinOpsPrivateDirectory -Path (Join-Path $parent 'new-parent/cache') -RequireNew } | Should -Throw '*writes by another account*'
            Test-Path -LiteralPath (Join-Path $parent 'new-parent') | Should -BeFalse
        }

        It 'Makes the raw download directory private before downloading and removes it on failure' {
            InModuleScope FinOpsMultitool -Parameters @{ FixtureRoot = (Join-Path $TestDrive 'download-root') } {
                param($FixtureRoot)
                $cachePath = Join-Path $FixtureRoot 'parquet'
                $probe = @{ Path = $null; Private = $false }
                Mock Get-FinOpsParquetCachePath { $cachePath }
                Mock New-AzStorageContext { $null }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion') { return @() }
                    [pscustomobject]@{ IsDirectory = $false; Path = 'fixture/20260901-20260930/202609201200/run/part.csv' }
                }
                Mock Get-AzDataLakeGen2ItemContent {
                    $probe.Path = Split-Path $Destination -Parent
                    $probe.Private = if ($IsWindows) { (Get-Acl -LiteralPath $probe.Path).AreAccessRulesProtected }
                        else { ([int][IO.File]::GetUnixFileMode($probe.Path) -band 511) -eq 448 }
                    throw 'Intentional synthetic stop before downloading.'
                }

                { Read-FinOpsHubData -StorageAccountName 'synthetic' -ResourceGroupName 'synthetic' -Months 1 } | Should -Throw '*Intentional synthetic stop*'

                $probe.Private | Should -BeTrue
                Split-Path $probe.Path -Parent | Should -Be $FixtureRoot
                Test-Path -LiteralPath $probe.Path | Should -BeFalse
            }
        }
    }

    Context 'Pinned restore inputs' {
        It 'Restores exact package versions through <ClientKind>' -ForEach @(
            @{ ClientKind = 'dotnet' }
            @{ ClientKind = 'nuget.exe' }
        ) {
            $root = Join-Path $TestDrive $ClientKind
            [void](New-Item -ItemType Directory -Path $root -Force)
            $clientPath = Join-Path $root 'synthetic-client.ps1'
            Set-Content -LiteralPath $clientPath -Value 'exit 0'

            Invoke-NuGetRestore -Client @{ Kind = $ClientKind; Path = $clientPath } -PackageId 'Parquet.Net' -Version '4.24.0' -PackageDir (Join-Path $root 'packages') -WorkingPath $root

            $fileName = if ($ClientKind -eq 'dotnet') { 'parquet-restore.csproj' } else { 'packages.config' }
            $document = [xml](Get-Content -LiteralPath (Join-Path $root "restore/$fileName") -Raw)
            $locked = @(Get-FinOpsParquetPackageLock)
            $entries = if ($ClientKind -eq 'dotnet') { @($document.Project.ItemGroup.PackageReference) } else { @($document.packages.package) }
            $entries.Count | Should -Be $locked.Count
            foreach ($package in $locked) {
                if ($ClientKind -eq 'dotnet') { ($entries | Where-Object Include -EQ $package.Id).Version | Should -Be "[$($package.Version)]" }
                else { ($entries | Where-Object id -EQ $package.Id).version | Should -Be $package.Version }
            }
            ($locked | Where-Object Id -EQ 'Snappier').Version | Should -Be '1.3.1'
        }
    }

    Context 'Package root discovery' {

        It 'Finds the nuget.exe layout of id.version then lib' {
            $root = & $script:NewTempTree
            try {
                New-Item -ItemType Directory -Path (Join-Path $root 'Parquet.Net.4.24.0\lib\net8.0') -Force | Out-Null

                $found = @(Get-RestoredPackageRoot -PackageDir $root)

                $found.Count | Should -Be 1
                $found[0] | Should -BeLike '*Parquet.Net.4.24.0'
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'Finds the dotnet restore layout of id then version then lib' {
            # dotnet nests the version a level deeper than nuget.exe does; missing
            # this layout would stage zero assemblies on macOS and Linux.
            $root = & $script:NewTempTree
            try {
                New-Item -ItemType Directory -Path (Join-Path $root 'parquet.net\4.24.0\lib\net8.0') -Force | Out-Null

                $found = @(Get-RestoredPackageRoot -PackageDir $root)

                $found.Count | Should -Be 1
                $found[0] | Should -BeLike '*4.24.0'
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'Finds a package that ships only native runtimes' {
            $root = & $script:NewTempTree
            try {
                New-Item -ItemType Directory -Path (Join-Path $root 'ironcompress\1.5.2\runtimes\linux-x64\native') -Force | Out-Null

                $found = @(Get-RestoredPackageRoot -PackageDir $root)

                $found.Count | Should -Be 1
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'Ignores directories that hold neither lib nor runtimes' {
            $root = & $script:NewTempTree
            try {
                New-Item -ItemType Directory -Path (Join-Path $root 'some.tool\1.0.0\tools') -Force | Out-Null

                @(Get-RestoredPackageRoot -PackageDir $root).Count | Should -Be 0
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'Payload hashing covers native libraries' {

        It 'Includes .so and .dylib alongside .dll' {
            # The integrity manifest must cover native payloads too; a .dll-only
            # filter left the Linux and macOS native libraries unverified.
            $root = & $script:NewTempTree
            try {
                $lib = Join-Path $root 'lib'
                $native = Join-Path $root 'runtimes\linux-x64\native'
                New-Item -ItemType Directory -Path $lib -Force | Out-Null
                New-Item -ItemType Directory -Path $native -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $lib 'Parquet.dll') -Value 'x'
                Set-Content -LiteralPath (Join-Path $native 'libironcompress.so') -Value 'x'
                Set-Content -LiteralPath (Join-Path $native 'libironcompress.dylib') -Value 'x'
                Set-Content -LiteralPath (Join-Path $native 'notes.txt') -Value 'x'

                $names = @(Get-ParquetPayloadFile -BasePath $root | ForEach-Object { $_.Name })

                $names | Should -Contain 'Parquet.dll'
                $names | Should -Contain 'libironcompress.so'
                $names | Should -Contain 'libironcompress.dylib'
                $names | Should -Not -Contain 'notes.txt'
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'Cache provenance' {
        It 'Reuses matching cached payloads only after package verification' {
            InModuleScope FinOpsMultitool -Parameters @{ FixturePath = (Join-Path $TestDrive 'verified-cache') } {
                param($FixturePath)
                $cacheRoot = New-FinOpsPrivateDirectory -Path $FixturePath -RequireNew
                $source = Join-Path $cacheRoot 'fixture-source'
                $packageContent = Join-Path $source 'lib/net8.0'
                $packages = Join-Path $cacheRoot 'packages'
                $staged = Join-Path $cacheRoot 'lib'
                foreach ($directory in @($packageContent, $packages, $staged)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
                Set-Content -LiteralPath (Join-Path $packageContent 'Parquet.dll') -Value 'Synthetic package payload'
                [IO.Compression.ZipFile]::CreateFromDirectory($source, (Join-Path $packages 'fixture.nupkg'))
                $algorithm = [Security.Cryptography.SHA512]::Create()
                try { $fixtureHash = [Convert]::ToBase64String($algorithm.ComputeHash([IO.File]::ReadAllBytes((Join-Path $packages 'fixture.nupkg')))) }
                finally { $algorithm.Dispose() }
                Mock Get-FinOpsParquetPackageLock { @{ Id = 'Fixture'; Version = '1.0.0'; Sha512 = $fixtureHash } }
                Copy-Item -LiteralPath (Join-Path $packageContent 'Parquet.dll') -Destination (Join-Path $staged 'Parquet.dll')
                New-ParquetManifest -BasePath $cacheRoot -ManifestPath (Join-Path $cacheRoot 'parquet-manifest.json')
                $events = [Collections.Generic.List[string]]::new()
                Mock Get-FinOpsParquetCachePath { $cacheRoot }
                Mock Resolve-NuGetClient { [pscustomobject]@{ Kind = 'nuget.exe'; Path = 'unused' } }
                Mock Assert-NuGetPackageSignature { [void]$events.Add('Verify') }
                Mock Invoke-NuGetRestore { throw 'A verified cache must not restore packages.' }
                Mock Import-ParquetAssemblies { [void]$events.Add('Load') }

                Install-ParquetReader | Should -BeTrue

                @($events) | Should -Be @('Verify', 'Load')
                Should -Invoke Invoke-NuGetRestore -Times 0 -Exactly
                Should -Invoke Assert-NuGetPackageSignature -Times 1 -Exactly
            }
        }

        It 'Discards incomplete restore state before retrying package acquisition' {
            InModuleScope FinOpsMultitool -Parameters @{ FixturePath = (Join-Path $TestDrive 'partial-cache') } {
                param($FixturePath)
                $cacheRoot = New-FinOpsPrivateDirectory -Path $FixturePath -RequireNew
                $marker = Join-Path $cacheRoot 'restore/obj/unverified-state.txt'
                [void](New-Item -ItemType Directory -Path (Split-Path $marker -Parent) -Force)
                Set-Content -LiteralPath $marker -Value 'Synthetic incomplete restore state'
                Mock Get-FinOpsParquetCachePath { $cacheRoot }
                Mock Resolve-NuGetClient { [pscustomobject]@{ Kind = 'dotnet'; Path = 'unused' } }
                Mock Invoke-NuGetRestore {
                    Test-Path -LiteralPath $marker | Should -BeFalse
                    throw 'Downloads are prohibited in this test.'
                }
                Mock Import-ParquetAssemblies { }

                Install-ParquetReader -WarningAction SilentlyContinue | Should -BeFalse

                Should -Invoke Invoke-NuGetRestore -Times 1 -Exactly
                Should -Invoke Import-ParquetAssemblies -Times 0 -Exactly
            }
        }

        It 'Requires staged payloads to match the verified package archives' {
            $root = Join-Path $TestDrive 'package-payload'
            $packageContent = Join-Path $root 'source/lib/net8.0'
            $otherFramework = Join-Path $root 'source/lib/net6.0'
            $otherRuntime = Join-Path $root 'source/runtimes/other-x64/native'
            $staged = Join-Path $root 'cache/lib'
            $packages = Join-Path $root 'cache/packages'
            foreach ($directory in @($packageContent, $otherFramework, $otherRuntime, $staged, $packages)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
            $assembly = Join-Path $packageContent 'Parquet.dll'
            Set-Content -LiteralPath $assembly -Value 'Synthetic verified package payload'
            Set-Content -LiteralPath (Join-Path $otherFramework 'Parquet.dll') -Value 'Different target framework payload'
            Set-Content -LiteralPath (Join-Path $otherRuntime 'fixture.dll') -Value 'Different runtime payload'
            [IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $root 'source'), (Join-Path $packages 'fixture.nupkg'))
            $algorithm = [Security.Cryptography.SHA512]::Create()
            try { $fixtureHash = [Convert]::ToBase64String($algorithm.ComputeHash([IO.File]::ReadAllBytes((Join-Path $packages 'fixture.nupkg')))) }
            finally { $algorithm.Dispose() }
            Mock Get-FinOpsParquetPackageLock -ModuleName FinOpsMultitool { @{ Id = 'Fixture'; Version = '1.0.0'; Sha512 = $fixtureHash } }
            Copy-Item -LiteralPath $assembly -Destination (Join-Path $staged 'Parquet.dll')

            { Assert-ParquetPackagePayload -BasePath (Join-Path $root 'cache') -PackageDir $packages } | Should -Not -Throw

            Copy-Item -LiteralPath (Join-Path $otherFramework 'Parquet.dll') -Destination (Join-Path $staged 'Parquet.dll') -Force
            { Assert-ParquetPackagePayload -BasePath (Join-Path $root 'cache') -PackageDir $packages } | Should -Throw '*does not match*'

            Copy-Item -LiteralPath $assembly -Destination (Join-Path $staged 'Parquet.dll') -Force
            $runtimeDestination = Join-Path $root 'cache/runtimes/other-x64/native'
            [void](New-Item -ItemType Directory -Path $runtimeDestination -Force)
            Copy-Item -LiteralPath (Join-Path $otherRuntime 'fixture.dll') -Destination $runtimeDestination
            { Assert-ParquetPackagePayload -BasePath (Join-Path $root 'cache') -PackageDir $packages } | Should -Throw '*does not match*'
            Remove-Item -LiteralPath (Join-Path $runtimeDestination 'fixture.dll')

            Set-Content -LiteralPath (Join-Path $staged 'Parquet.dll') -Value 'Different payload'
            New-ParquetManifest -BasePath (Join-Path $root 'cache') -ManifestPath (Join-Path $root 'cache/parquet-manifest.json')
            { Assert-ParquetPackagePayload -BasePath (Join-Path $root 'cache') -PackageDir $packages } | Should -Throw '*does not match*'

            Copy-Item -LiteralPath (Join-Path $packages 'fixture.nupkg') -Destination (Join-Path $packages 'duplicate.nupkg')
            { Get-VerifiedParquetPackage -PackageDir $packages } | Should -Throw '*unexpected or duplicate*'
            Remove-Item -LiteralPath (Join-Path $packages 'duplicate.nupkg')
            Remove-Item -LiteralPath (Join-Path $packages 'fixture.nupkg')
            { Get-VerifiedParquetPackage -PackageDir $packages } | Should -Throw '*missing pinned*'
        }

        It 'Rejects an unrelated package before invoking the signature verifier' {
            $packages = Join-Path $TestDrive 'unexpected-packages'
            [void](New-Item -ItemType Directory -Path $packages -Force)
            Set-Content -LiteralPath (Join-Path $packages 'unrelated.nupkg') -Value 'Synthetic unrelated archive'

            { Assert-NuGetPackageSignature -Client @{ Kind = 'dotnet'; Path = 'must-not-execute' } -PackageDir $packages } | Should -Throw '*unexpected or duplicate package*'
        }

        It 'Does not load a self-hashed cache without verified packages' {
            InModuleScope FinOpsMultitool -Parameters @{ FixturePath = (Join-Path $TestDrive 'unverified-cache') } {
                param($FixturePath)
                $cacheRoot = $FixturePath
                $lib = Join-Path $cacheRoot 'lib'
                [void](New-Item -ItemType Directory -Path $lib -Force)
                Copy-Item -LiteralPath ([object].Assembly.Location) -Destination (Join-Path $lib 'Parquet.dll')
                New-ParquetManifest -BasePath $cacheRoot -ManifestPath (Join-Path $cacheRoot 'parquet-manifest.json')
                Mock Get-FinOpsParquetCachePath { $cacheRoot }
                Mock Resolve-NuGetClient { [pscustomobject]@{ Kind = 'nuget.exe'; Path = 'unused' } }
                Mock Assert-NuGetPackageSignature { throw 'Synthetic package verification failure.' }
                Mock Invoke-NuGetRestore { throw 'Downloads are prohibited in this test.' }
                Mock Import-ParquetAssemblies { }

                Install-ParquetReader -WarningAction SilentlyContinue | Should -BeFalse

                Should -Invoke Import-ParquetAssemblies -Times 0 -Exactly
            }
        }
    }

    Context 'Client resolution' {

        It 'Reports a runtime identifier shaped os-arch' {
            Get-FinOpsNativeRid | Should -Match '^(win|osx|linux)-(x64|x86|arm64|arm)$'
        }

        It 'Rejects and deletes a cached nuget.exe that is not validly signed' -Skip:(-not $IsWindows) {
            # A cached copy lives in a writable path, so it is re-validated on
            # every use rather than trusted because it already exists.
            $root = & $script:NewTempTree
            try {
                $planted = Join-Path $root 'nuget.exe'
                Set-Content -LiteralPath $planted -Value 'not a signed binary'

                { Resolve-NuGetClient -CachePath $root } | Should -Throw '*Authenticode*'
                Test-Path -LiteralPath $planted | Should -BeFalse
            }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
