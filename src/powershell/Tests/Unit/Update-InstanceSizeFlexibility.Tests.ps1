# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Update-InstanceSizeFlexibility' {
    BeforeAll {
        $generatorPath = "$PSScriptRoot/../../../scripts/Update-InstanceSizeFlexibility.ps1"

        # Stub Az.Accounts commands so they can be mocked without the module installed
        function Get-AzContext {}
        function Invoke-AzRestMethod { param($Uri, $Method) }

        function New-CatalogItem
        {
            param([string]$Sku, [string]$Group, [string]$Ratio)
            @{
                name          = $Sku
                armSkuName    = $Sku
                skuProperties = @(
                    @{ name = 'InstanceSizeFlexibilityGroup'; value = $Group },
                    @{ name = 'InstanceSizeFlexibilityRatio'; value = $Ratio }
                )
            }
        }

        function New-CatalogResponse
        {
            param([int]$StatusCode = 200, [object[]]$Items = @(), [string]$NextLink = $null, [string]$RawContent = $null)
            [PSCustomObject]@{
                StatusCode = $StatusCode
                Content    = if ($RawContent) { $RawContent } else { @{ value = $Items; nextLink = $NextLink } | ConvertTo-Json -Depth 20 }
            }
        }

        function Invoke-Generator
        {
            param([hashtable]$Parameters)
            & $generatorPath @Parameters 6>$null 3>$null
        }
    }

    BeforeEach {
        Mock Get-AzContext { @{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
        Mock Start-Sleep {}
        $outFile = Join-Path $TestDrive 'InstanceSizeFlexibility.csv'
        if (Test-Path $outFile) { Remove-Item $outFile -Force }  # the generator cache-merges an existing file
        $baseParams = @{
            OutputPath           = $outFile
            Location             = @('eastus')
            ReservedResourceType = @('VirtualMachines')
        }
    }

    Context 'Pagination' {
        It 'Follows nextLink across pages without duplicating or dropping items' {
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*skipToken*')
                {
                    New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D4' -Group 'DSeries' -Ratio '2'))
                }
                else
                {
                    New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1')) -NextLink 'https://management.azure.com/next?skipToken=abc'
                }
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.Count | Should -Be 2
            $rows.ArmSkuName | Should -Be @('Standard_D2', 'Standard_D4')
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 2
        }

        It 'Handles a bare array response with no nextLink' {
            Mock Invoke-AzRestMethod {
                [PSCustomObject]@{
                    StatusCode = 200
                    Content    = ConvertTo-Json @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1')) -Depth 20 -AsArray
                }
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1
        }
    }

    Context 'Retry behavior' {
        It 'Retries 429 and 5xx responses on the same page without advancing' {
            $script:isfCallCount = 0
            Mock Invoke-AzRestMethod {
                $script:isfCallCount++
                switch ($script:isfCallCount)
                {
                    1 { New-CatalogResponse -StatusCode 429 -RawContent '{"error":"throttled"}' }
                    2 { New-CatalogResponse -StatusCode 503 -RawContent '{"error":"unavailable"}' }
                    default { New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1')) }
                }
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 3
            Should -Invoke Start-Sleep -Exactly -Times 2
        }

        It 'Does not retry non-transient 4xx and preserves cached data when a scope fails' {
            @([PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' }) `
            | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod { New-CatalogResponse -StatusCode 403 -RawContent '{"error":"forbidden"}' }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1
        }
    }

    Context 'Record extraction' {
        It 'Filters placeholder SKU names out of the output' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'arm_sku_name_placeholder' -Group 'DSeries' -Ratio '2')
                )
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.Count | Should -Be 1
            $rows[0].ArmSkuName | Should -Be 'Standard_D2'
        }

        It 'Falls back to the catalog name when armSkuName is missing' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    @{
                        name          = 'Standard_E2s_v5'
                        skuProperties = @(
                            @{ name = 'ReservationsAutofitGroup'; value = 'ESv5 Series' },
                            @{ name = 'ReservationsAutofitRatio'; value = '1' }
                        )
                    }
                )
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_E2s_v5'
        }

        It 'Skips items without ISF group or ratio properties' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    @{ name = 'Standard_NoIsf'; armSkuName = 'Standard_NoIsf'; skuProperties = @(@{ name = 'UsageType'; value = 'Consumption' }) }
                )
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
        }

        It 'Unions regions without duplicating group/SKU pairs' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'))
            }
            $params = $baseParams.Clone()
            $params.Location = @('eastus', 'westeurope')

            Invoke-Generator $params

            @(Import-Csv $outFile).Count | Should -Be 1
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 2
        }
    }

    Context 'Cache merge' {
        It 'Updates changed ratios, adds new SKUs, and preserves unseen cached SKUs' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D4'; Ratio = '2' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D4' -Group 'DSeries' -Ratio '4'),
                    (New-CatalogItem -Sku 'Standard_D8' -Group 'DSeries' -Ratio '8')
                )
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.Count | Should -Be 3
            ($rows | Where-Object ArmSkuName -eq 'Standard_D2').Ratio | Should -Be '1'   # unseen -> preserved
            ($rows | Where-Object ArmSkuName -eq 'Standard_D4').Ratio | Should -Be '4'   # seen -> updated
            ($rows | Where-Object ArmSkuName -eq 'Standard_D8').Ratio | Should -Be '8'   # new -> added
        }
    }

    Context 'Normalization' {
        It 'Rescales each group so the smallest ratio is 1 when -Normalize is set' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_B1s' -Group 'BS Series' -Ratio '0.25'),
                    (New-CatalogItem -Sku 'Standard_B2s' -Group 'BS Series' -Ratio '0.5'),
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'Standard_D4' -Group 'DSeries' -Ratio '2')
                )
            }
            $params = $baseParams.Clone()
            $params.Normalize = $true

            Invoke-Generator $params

            $rows = @(Import-Csv $outFile)
            ($rows | Where-Object ArmSkuName -eq 'Standard_B1s').Ratio | Should -Be '1'
            ($rows | Where-Object ArmSkuName -eq 'Standard_B2s').Ratio | Should -Be '2'
            ($rows | Where-Object ArmSkuName -eq 'Standard_D2').Ratio | Should -Be '1'
            ($rows | Where-Object ArmSkuName -eq 'Standard_D4').Ratio | Should -Be '2'
        }

        It 'Keeps raw ratios by default' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_B1s' -Group 'BS Series' -Ratio '0.25'),
                    (New-CatalogItem -Sku 'Standard_B2s' -Group 'BS Series' -Ratio '0.5')
                )
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            ($rows | Where-Object ArmSkuName -eq 'Standard_B1s').Ratio | Should -Be '0.25'
            ($rows | Where-Object ArmSkuName -eq 'Standard_B2s').Ratio | Should -Be '0.5'
        }
    }
}
