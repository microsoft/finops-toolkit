$rootDirectory = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
$modulePath = (Get-ChildItem -Path $rootDirectory -Include 'FinOpsToolKit.psm1').FullName

Import-Module -FullyQualifiedName $modulePath

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
                $AsJson
            )

            $output = @()
            foreach ($hashtable in $Releases)
            {
                $hashtable['tag_name'] = $hashtable.Version
                $output += New-Object -TypeName 'psobject' -Property $hashtable
            }

            if ($AsJson)
            {
                $output = ConvertTo-Json -InputObject $output
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
                PreRelease = $PreRelease
                Assets     = $Assets
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
                $Url,

                [Parameter()]
                [switch]
                $Base
            )

            $output = @{ Name = $Name }

            if ($Base)
            {
                $output['browser_download_url']  = $Url
            }
            else
            {
                $output['Url']  = $Url
            }

            return $output
        }

        $previewVersion = '1.0.0-alpha.01'
        $releaseVersion = '1.0.0'
    }

    Describe 'Localized Data' {
        It 'Should import FinOpsToolKit.strings.psd1' {
            $script:localizedData | Should -Not -BeNullOrEmpty
        }
    }

    Describe 'Get-FinOpsToolkitVersion' {
        Context 'Parameter [Latest]' {
            BeforeAll {
                $release1 = New-MockRelease -Name 'fake' -Version $releaseVersion
                $release2 = New-MockRelease -Name 'fake' -Version $releaseVersion

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -AsJson }
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
                $asset = New-MockAsset -Name $assetName -Url $url -Base
                $release = New-MockRelease -Name $releaseName -Version $releaseVersion -Assets $asset
                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release -AsJson }
            }

            It 'Should return an object with correct properties' {
                $result = Get-FinOpsToolkitVersion
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be $releaseName
                $result.Version | Should -Be $releaseVersion
                $result.Assets.Name | Should -Be $assetName
                $result.Assets.Url | Should -Be $url
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

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -AsJson}
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

                Mock -CommandName 'Invoke-WebRequest' -MockWith { New-MockReleaseObject -Releases $release1, $release2 -AsJson}
            }

            It 'Should only include latest prerelease when [Latest] and [Preview] is used' {
                $result = Get-FinOpsToolkitVersion -Latest -Preview
                $result.Count | Should -Be 1
                $result.Version | Should -Be $previewVersion
                Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1
            }
        }
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

    Describe 'New-Directory' {
        BeforeAll {
            Mock -CommandName 'New-Item'
            $path = 'TestDrive:\FakeDirectory'
        }

        It 'Should not create a directory if it exists' {
            Mock -CommandName 'Test-Path' -MockWith { return $true }
            New-Directory -Path $path
            Assert-MockCalled -CommandName 'Test-Path'
            Assert-MockCalled -CommandName 'New-Item' -Times 0
        }

        It 'Should create a directory if it does not exist' {
            Mock -CommandName 'Test-Path' -MockWith { return $false }
            New-Directory -Path $path
            Assert-MockCalled -CommandName 'Test-Path'
            Assert-MockCalled -CommandName 'New-Item' -Times 1
        }
    }

    Describe 'Deploy-FinOpsHub' {
        BeforeAll {
            $hubName = 'hub'
            $rgName = 'hubRg'
            $location = 'eastus'
        }

        Context 'Resource groups' {
            BeforeAll {
                Mock -CommandName 'New-Directory'
            }
            
            Context 'Create new resource group' {
                BeforeAll {
                    Mock -CommandName 'Get-AzResourceGroup'
                }

                Context 'Failure' {
                    BeforeAll {
                        Mock -CommandName 'New-AzResourceGroup' -MockWith { throw 'failure' }
                    }

                    It 'Should throw if error creating resource group' {
                        { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location } | Should -Throw
                        Assert-MockCalled -CommandName 'Get-AzResourceGroup' -Times 1
                        Assert-MockCalled -CommandName 'New-AzResourceGroup' -Times 1
                        Assert-MockCalled -CommandName 'New-Directory' -Times 0
                    }
                }
            }

            Context 'Use existing resource group' {
                BeforeAll {
                    Mock -CommandName 'Get-AzResourceGroup' -MockWith { return @{ ResourceGroupName = $rgName } }
                    Mock -CommandName 'New-AzResourceGroup'
                    Mock -CommandName 'Save-FinOpsHubTemplate'
                }

                Context 'Failures' {
                    BeforeAll {
                        Mock -CommandName 'Get-ChildItem'
                    }

                    It 'Should throw if template file is not found' {
                        { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location } | Should -Throw
                        Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                    }
                }

                Context 'Success' {
                    BeforeAll {
                        $templateFile = Join-Path -Path $env:temp -ChildPath 'FinOps\finops-hub-v1.0.0\main.bicep'
                        Mock -CommandName 'Get-ChildItem' -MockWith { return @{ FullName = $templateFile}}
                        Mock -CommandName 'New-AzResourceGroupDeployment'
                    }

                    It 'Should deploy the template without throwing' {
                        { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location } | Should -Not -Throw
                        Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                        Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter { @{ TemplateFile = $templateFile } } -Times 1
                    }

                    It 'Should deploy the template with tags' {
                        { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Tags @{ Test = 'Tag' } } | Should -Not -Throw
                        Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                        Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                            @{
                                TemplateParameterObject = @{
                                    tags = @{
                                        Test = 'Tag'
                                    }
                                }
                            }
                        } -Times 1
                    }

                    It 'Should deploy the template with StorageSku' {
                        $storageSku = 'Premium_ZRS'
                        { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -StorageSku $storageSku } | Should -Not -Throw
                        Assert-MockCalled -CommandName 'Get-ChildItem' -Times 1
                        Assert-MockCalled -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                            @{
                                TemplateParameterObject = @{
                                    storageSku = $storageSku
                                }
                            }
                        } -Times 1
                    }
                }
            }
        }
    }
}