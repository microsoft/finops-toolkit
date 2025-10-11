# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Get-FinOpsToolkitVersion' {
        BeforeAll {
            function New-MockReleaseObject
            {
                param
                (
                    [Parameter(Mandatory = $true)]
                    [hashtable[]]
                    $Releases,

                    [Parameter()]
                    [switch]
                    $GitHub
                )

                $output = @()
                foreach ($hashtable in $Releases)
                {
                    # Duplicate Files as "assets" to mock GitHub requests
                    $hashtable['assets'] = $hashtable.Files
                    $output += New-Object -TypeName 'psobject' -Property $hashtable
                }

                if ($GitHub)
                {
                    $output = ConvertTo-Json -InputObject $output -Depth 10
                }

                return $output
            }

            function New-MockRelease
            {
                [OutputType([hashtable])]
                [CmdletBinding()]
                param
                (
                    [Parameter(Mandatory = $true)]
                    [string]
                    $Name,

                    [Parameter(Mandatory = $true)]
                    [string]
                    $Version,

                    [Parameter()]
                    [bool]
                    $PreRelease = $false,

                    [Parameter()]
                    $Assets = @()
                )

                return @{
                    Name       = $Name
                    Version    = $Version
                    tag_name   = "v$Version"  # For mocking GitHub requests
                    PreRelease = $PreRelease
                    Files      = @($Assets)
                }
            }

            function New-MockAsset
            {
                [OutputType([hashtable])]
                [CmdletBinding()]
                param
                (
                    [Parameter(Mandatory = $true)]
                    [string]
                    $Name,

                    [Parameter(Mandatory = $true)]
                    [string]
                    $Url
                )

                return @{
                    Name                 = $Name
                    Url                  = $Url
                    browser_download_url = $Url  # For mocking GitHub requests
                }
            }

            $previewVersion = '1.0.0-alpha.01'
            $releaseVersion = '1.0.0'
        }

        Context 'Parameter [Latest]' {
            BeforeAll {
                $release1 = New-MockRelease -Name 'fake' -Version $releaseVersion
                $release2 = New-MockRelease -Name 'fake' -Version $releaseVersion

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -GitHub }
            }

            It 'Should return 1 result when [Latest] is used' {
                $result = Get-FinOpsToolkitVersion -Latest
                $result.Count | Should -Be 1
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }

            It 'Should return all versions if [Latest] not used' {
                $result = Get-FinOpsToolkitVersion
                $result.Count | Should -Be 2
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }
        }

        Context 'Output' {
            BeforeAll {
                $url = 'https://fakeasseturl'
                $assetName = 'fakeasset'
                $releaseName = 'fake'
                $releaseVersion = '1.0.0'
                $asset = New-MockAsset -Name $assetName -Url $url
                $release = New-MockRelease -Name $releaseName -Version $releaseVersion -Assets $asset
                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release -GitHub }
            }

            It 'Should return an object with correct properties' {
                $result = Get-FinOpsToolkitVersion
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be $releaseName
                $result.Version | Should -Be $releaseVersion
                $result.Files.Name | Should -Be $assetName
                $result.Files.Url | Should -Be $url
            }
        }

        Context 'Failures' {
            BeforeAll {
                Mock -CommandName 'Invoke-WebRequest' -MockWith { throw 'failed' }
                Mock -CommandName 'New-Object'
            }

            It 'Should throw if the Uri is unreachable' {
                { Get-FinOpsToolkitVersion } | Should -Throw
                Assert-MockCalled -CommandName 'Invoke-WebRequest'
                Assert-MockCalled -CommandName 'New-Object' -Times 0
            }
        }

        Context 'Parameter [Preview]' {
            BeforeAll {
                $release1 = New-MockRelease -Name 'fake' -Version $previewVersion -PreRelease $true
                $release2 = New-MockRelease -Name 'fake' -Version $releaseVersion

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -GitHub }
            }

            It 'Should include prereleases when [Preview] is used' {
                $result = Get-FinOpsToolkitVersion -Preview
                $result.Count | Should -Be 2
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }

            It 'Should not include prereleases when [Preview] is not used' {
                $result = Get-FinOpsToolkitVersion
                $result.Count | Should -Be 1
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }
        }

        Context 'Parameter [Latest] and [Preview]' {
            BeforeAll {
                $release1 = New-MockRelease -Name 'fake' -Version $previewVersion -PreRelease $true
                $release2 = New-MockRelease -Name 'fake' -Version $releaseVersion

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -GitHub }
            }

            It 'Should only include latest prerelease when [Latest] and [Preview] is used' {
                $result = Get-FinOpsToolkitVersion -Latest -Preview
                $result.Count | Should -Be 1
                $result.Version | Should -Be $previewVersion
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }
        }
    }
}
