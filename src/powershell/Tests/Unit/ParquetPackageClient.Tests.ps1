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
