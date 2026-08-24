# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'Deploy-FinOpsHub' {
        BeforeAll {
            function Get-AzResourceGroup {}
            function New-AzResourceGroup {}
            function New-AzResourceGroupDeployment {
                param($TemplateFile, $TemplateParameterObject, $ResourceGroupName)
            }

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $hubName = 'ftk-test-Deploy-FinOpsHub'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $rgName = 'ftk-test'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $location = 'eastus'
        }

        Context "WhatIf" {
            It 'Should run without error' {
                # Arrange
                Mock -CommandName 'Test-ShouldProcess' { return $false }
                Mock -CommandName 'Get-AzResourceGroup' { return $null }
                Mock -CommandName 'Initialize-FinOpsHubDeployment' { }

                # Act
                Deploy-FinOpsHub -WhatIf -Name $hubName -ResourceGroupName $rgName -Location $location

                # Assert
                Should -Invoke -CommandName 'Initialize-FinOpsHubDeployment' -Times 1 -ParameterFilter { $WhatIf -eq $true }
                @('CreateResourceGroup', 'CreateTempDirectory', 'DownloadTemplate', 'DeployFinOpsHub') | ForEach-Object {
                    Should -Invoke -CommandName 'Test-ShouldProcess' -Times 1 -ParameterFilter { $Action -eq $_ }
                }
            }
        }

        Context 'Resource groups' {
            BeforeAll {
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
            }

            It 'Should create RG if it does not exist' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $null }
                Mock -CommandName 'New-AzResourceGroup' -MockWith { }
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'CreateResourceGroup' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Should -Invoke -CommandName 'Get-AzResourceGroup' -Times 1
                Should -Invoke -CommandName 'New-AzResourceGroup' -Times 1
            }

            It 'Should use RG if it exists' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'New-AzResourceGroup' -MockWith { }
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'CreateResourceGroup' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Should -Invoke -CommandName 'Get-AzResourceGroup' -Times 1
                Should -Invoke -CommandName 'New-AzResourceGroup' -Times 0
            }
        }

        Context 'Initialize' {
            It 'Should call Initialize-FinOpsHubDeployment' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $false }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Should -Invoke -CommandName 'Initialize-FinOpsHubDeployment' -Times 1
            }
        }

        Context 'Download template' {
            It 'Should save the template from GitHub' -Skip {
            }
            It 'Should clean up template after deployment' -Skip {
            }
        }

        Context 'Deploy' {
            BeforeAll {
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
            }

            It 'Should deploy the template' {
                # Arrange
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return $rgName }
                Mock -CommandName 'New-AzResourceGroupDeployment'
                Mock -CommandName 'Test-ShouldProcess' -MockWith { return $Action -eq 'DeployFinOpsHub' }

                # Act
                Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location

                # Assert
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -Times 1
            }
            It 'Should add tags to the deployment' -Skip {
            }
            It 'Should deploy' -Skip {
            }
        }

        Context 'Old tests' {
            BeforeAll {
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return @{ ResourceGroupName = $rgName } }
                Mock -CommandName 'New-AzResourceGroup'
                Mock -CommandName 'Save-FinOpsHubTemplate'
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
            }

            It 'Should throw if template file is not found' {
                Mock -CommandName 'Get-ChildItem'
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Throw
                Should -Invoke -CommandName 'Get-ChildItem' -Times 1
            }

            Context 'More' {
                BeforeAll {
                    $templateFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'FinOps/finops-hub-v1.0.0/main.bicep'
                    Mock -CommandName 'Get-ChildItem' -MockWith { return @{ FullName = $templateFile } }
                    Mock -CommandName 'New-AzResourceGroupDeployment'
                }

                It 'Should deploy the template without throwing' {
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter { @{ TemplateFile = $templateFile } } -Times 1
                }

                It 'Should deploy the template with tags' {
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Tags @{ Test = 'Tag' } -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
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
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -StorageSku $storageSku -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        @{
                            TemplateParameterObject = @{
                                storageSku = $storageSku
                            }
                        }
                    } -Times 1
                }

                It 'Should deploy the template with RemoteHubStorageUri' {
                    $remoteHubStorageUri = 'https://primaryhub.dfs.core.windows.net/'
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -RemoteHubStorageUri $remoteHubStorageUri -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        $TemplateParameterObject.remoteHubStorageUri -eq $remoteHubStorageUri
                    } -Times 1
                }

                It 'Should deploy the template with RemoteHubStorageKey' {
                    $remoteHubStorageKey = 'abc123...xyz789=='
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -RemoteHubStorageKey $remoteHubStorageKey -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        $TemplateParameterObject.remoteHubStorageKey -eq $remoteHubStorageKey
                    } -Times 1
                }

                It 'Should deploy the template with both RemoteHub parameters' {
                    $remoteHubStorageUri = 'https://primaryhub.dfs.core.windows.net/'
                    $remoteHubStorageKey = 'abc123...xyz789=='
                    { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -RemoteHubStorageUri $remoteHubStorageUri -RemoteHubStorageKey $remoteHubStorageKey -Version 'latest' } | Should -Not -Throw
                    Should -Invoke -CommandName 'Get-ChildItem' -Times 1
                    Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                        $TemplateParameterObject.remoteHubStorageUri -eq $remoteHubStorageUri -and $TemplateParameterObject.remoteHubStorageKey -eq $remoteHubStorageKey
                    } -Times 1
                }
            }
        }

        Context 'Network mode' {
            BeforeAll {
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return @{ ResourceGroupName = $rgName } }
                Mock -CommandName 'New-AzResourceGroup'
                Mock -CommandName 'Save-FinOpsHubTemplate'
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
                $templateFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'FinOps/finops-hub-v1.0.0/main.bicep'
                Mock -CommandName 'Get-ChildItem' -MockWith { return @{ FullName = $templateFile } }
                Mock -CommandName 'New-AzResourceGroupDeployment'
            }

            It 'Should default to public access without a NAT Gateway' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $true -and -not $TemplateParameterObject.ContainsKey('enableNatGateway')
                } -Times 1
            }

            It "Should map -NetworkMode 'public' to enablePublicAccess and no NAT Gateway" {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'public' -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $true -and -not $TemplateParameterObject.ContainsKey('enableNatGateway')
                } -Times 1
            }

            It "Should map -NetworkMode 'vnet' to private access without a NAT Gateway" {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'vnet' -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $false -and -not $TemplateParameterObject.ContainsKey('enableNatGateway')
                } -Times 1
            }

            It "Should map -NetworkMode 'private' to private access with a NAT Gateway" {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'private' -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $false -and $TemplateParameterObject.enableNatGateway -eq $true
                } -Times 1
            }

            It 'Should map deprecated -DisablePublicAccess to vnet (no NAT Gateway)' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -DisablePublicAccess -Version 'latest' -WarningAction 'SilentlyContinue' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $false -and -not $TemplateParameterObject.ContainsKey('enableNatGateway')
                } -Times 1
            }

            It 'Should let -NetworkMode win over deprecated -DisablePublicAccess' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'private' -DisablePublicAccess -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enablePublicAccess -eq $false -and $TemplateParameterObject.enableNatGateway -eq $true
                } -Times 1
            }

            It 'Should throw when private mode targets a version older than 15.0' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'private' -Version '14.0' } | Should -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -Times 0
            }

            It 'Should pass enableNatGateway when private mode targets version 15.0 or later' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -NetworkMode 'private' -Version '15.0' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enableNatGateway -eq $true
                } -Times 1
            }
        }

        Context 'Multicloud' {
            BeforeAll {
                Mock -CommandName 'Get-AzResourceGroup' -MockWith { return @{ ResourceGroupName = $rgName } }
                Mock -CommandName 'New-AzResourceGroup'
                Mock -CommandName 'Save-FinOpsHubTemplate'
                Mock -CommandName 'Initialize-FinOpsHubDeployment'
                $templateFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'FinOps/finops-hub-v1.0.0/main.bicep'
                Mock -CommandName 'Get-ChildItem' -MockWith { return @{ FullName = $templateFile } }
                Mock -CommandName 'New-AzResourceGroupDeployment'

                [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
                $awsSecret = ConvertTo-SecureString -String 'ftk-test-secret' -AsPlainText -Force
            }

            It 'Should not pass AWS parameters by default' {
                { Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    -not $TemplateParameterObject.ContainsKey('enableAwsFocusIngestion')
                } -Times 1
            }

            It 'Should pass AWS parameters when AWS FOCUS ingestion is enabled' {
                {
                    Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' `
                        -EnableAwsFocusIngestion `
                        -AwsBucketName 'ftk-test-bucket' `
                        -AwsBucketPath 'reports/focus-export' `
                        -AwsAccountId '123456789012' `
                        -AwsRegion 'us-east-1' `
                        -AwsAccessKeyId 'AKIAIOSFODNN7EXAMPLE' `
                        -AwsSecretAccessKey $awsSecret
                } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.enableAwsFocusIngestion -eq $true -and
                    $TemplateParameterObject.awsBucketName -eq 'ftk-test-bucket' -and
                    $TemplateParameterObject.awsBucketPath -eq 'reports/focus-export' -and
                    $TemplateParameterObject.awsAccountId -eq '123456789012' -and
                    $TemplateParameterObject.awsRegion -eq 'us-east-1' -and
                    $TemplateParameterObject.awsAccessKeyId -eq 'AKIAIOSFODNN7EXAMPLE'
                } -Times 1
            }

            It 'Should default the collection hour to 4' {
                {
                    Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' `
                        -EnableAwsFocusIngestion -AwsBucketName 'ftk-test-bucket' -AwsSecretAccessKey $awsSecret
                } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.multiCloudScheduleHour -eq 4
                } -Times 1
            }

            It 'Should pass the requested collection hour' {
                {
                    Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' `
                        -EnableAwsFocusIngestion -AwsBucketName 'ftk-test-bucket' -AwsSecretAccessKey $awsSecret -MultiCloudScheduleHour 20
                } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    $TemplateParameterObject.multiCloudScheduleHour -eq 20
                } -Times 1
            }

            It 'Should not pass AWS parameters when targeting a version older than 15.0' {
                {
                    Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version '14.0' `
                        -EnableAwsFocusIngestion -AwsBucketName 'ftk-test-bucket' -AwsSecretAccessKey $awsSecret
                } | Should -Not -Throw
                Should -Invoke -CommandName 'New-AzResourceGroupDeployment' -ParameterFilter {
                    -not $TemplateParameterObject.ContainsKey('enableAwsFocusIngestion')
                } -Times 1
            }

            It 'Should reject a collection hour outside of 0-23' {
                {
                    Deploy-FinOpsHub -Name $hubName -ResourceGroup $rgName -Location $location -Version 'latest' `
                        -EnableAwsFocusIngestion -MultiCloudScheduleHour 24
                } | Should -Throw
            }
        }
    }
}