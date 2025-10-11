# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
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

    Describe 'New-Directory' {
        BeforeAll {
            Mock -CommandName 'New-Item'
            $path = 'TestDrive:\FakeDirectory'
        }

        It 'Should not create a directory if it exists' {
            # Arrange
            Mock -CommandName 'Test-Path' -MockWith { return $true }

            # Act
            New-Directory -Path $path

            # Assert
            Assert-MockCalled -CommandName 'Test-Path'
            Assert-MockCalled -CommandName 'New-Item' -Times 0
        }

        It 'Should create a directory if it does not exist' {
            # Arrange
            Mock -CommandName 'Test-Path' -MockWith { return $false }

            # Act
            New-Directory -Path $path

            # Assert
            Assert-MockCalled -CommandName 'Test-Path'
            Assert-MockCalled -CommandName 'New-Item' -Times 1
        }
    }
}
