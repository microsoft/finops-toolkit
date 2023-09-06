# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $helperPath = Join-Path -Path $PSScriptRoot -ChildPath 'testHelper.ps1'
    . $helperPath
    $functionRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
    $functionName = Split-Path -Path ($PSCommandPath.Replace('.Tests.ps1', '.ps1')) -Leaf
    $functionPath = Get-ChildItem -Path $functionRoot -Recurse -Include $functionName
    if (-not $functionPath)
    {
        throw "Cannot find associated function for test: '$PSCommandPath'."
    }

    . $functionPath

    function Get-FinOpsToolkitVersion {}
}

Describe 'Save-FinOpsHubTemplate' {
    BeforeAll {
        Mock -CommandName 'Invoke-WebRequest'
        Mock -CommandName 'Expand-Archive'
        Mock -CommandName 'Remove-Item'
        Mock -CommandName 'New-Directory'
        $release1 = New-MockRelease -Name 'fake' -Version '1.0.0'

        Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { New-MockReleaseObject -Releases $release1}
    }

    Context 'No releases found' {
        It 'Should stop processing if no assets found' {
            Save-FinOpsHubTemplate
            Assert-MockCalled -CommandName 'Get-FinOpsToolkitVersion' -Times 1
            Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 0
        }
    }

    Context 'Releases found' {
        BeforeAll {
            $asset = New-MockAsset -Name 'fakeAsset' -Url 'https://fakeAsset'
            $release = New-MockRelease -Name 'fake' -Version '1.0.0' -Assets $asset
            Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { New-MockReleaseObject -Releases $release }
            Mock -CommandName 'Test-Path' -MockWith { return $true }
        }

        It 'Should download each asset found' {
            Save-FinOpsHubTemplate
            Assert-MockCalled -CommandName 'Get-FinOpsToolkitVersion' -Times 1
            Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
        }
    }

    Context 'Release filtering' {
        BeforeAll {
            $downloadVersion = '2.0.0'
            $downloadUrl = 'https://fakeAsset2.zip'
            $asset1 = New-MockAsset -Name 'fakeAsset1.zip' -Url 'https://fakeAsset1.zip'
            $asset2 = New-MockAsset -Name 'fakeAsset2.zip' -Url $downloadUrl

            $release1 = New-MockRelease -Name 'fake' -Version '1.0.0' -Assets $asset1
            $release2 = New-MockRelease -Name 'fake' -Version $downloadVersion -Assets $asset2
            Mock -CommandName 'Get-FinOpsToolkitVersion' -MockWith { New-MockReleaseObject -Releases $release1, $release2 }
        }

        It 'Should only download version specified' {
            { Save-FinOpsHubTemplate -Version $downloadVersion } | Should -Not -Throw
            Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1 -ParameterFilter { @{ Uri = $downloadUrl } }
            Assert-MockCalled -CommandName 'Expand-Archive' -Times 1
            Assert-MockCalled -CommandName 'Remove-Item' -Times 1
        }
    }

    Context 'Failures' {
        BeforeAll {
            Mock -CommandName 'Get-FinOpsToolKitVersion' -MockWith { throw 'failue' }
        }

        It 'Should throw' {
            { Save-FinOpsHubTemplate } | Should -Throw
            Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 0
        }
    }
}
