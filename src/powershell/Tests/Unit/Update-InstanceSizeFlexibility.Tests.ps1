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
        if (Test-Path $outFile) { Remove-Item $outFile -Force }  # the generator replaces the file, so start clean
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

        It 'Fails the run on non-retryable 4xx without touching the existing output file' {
            @([PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' }) `
            | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod { New-CatalogResponse -StatusCode 403 -RawContent '{"error":"forbidden"}' }

            { Invoke-Generator $baseParams } | Should -Throw

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

        It 'Skips SKUs the API reports with a zero ratio' {
            # A zero ratio carries no flexibility information, and the Optimization Engine's
            # benefits simulation divides by it.
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'azure_redis_cache_isolated_i100' -Group 'Azure Redis Cache Isolated' -Ratio '0')
                )
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
        }

        It 'Parses and writes ratios independently of the current culture' {
            # A comma-decimal culture reads "2.1" as 21 (de-DE) or rejects it (fr-CH), and
            # Export-Csv writes "2,1" back out, which breaks every consumer of the file.
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::new('de-DE')
                Mock Invoke-AzRestMethod {
                    New-CatalogResponse -Items @(
                        (New-CatalogItem -Sku 'Standard_A1_v2' -Group 'Av2 Series' -Ratio '2'),
                        (New-CatalogItem -Sku 'Standard_A2_v2' -Group 'Av2 Series' -Ratio '2.1')
                    )
                }

                Invoke-Generator $baseParams

                # 2.1 / 2 = 1.05. Culture-aware parsing reads "2.1" as 21 and would write "10,5".
                $raw = Get-Content $outFile -Raw
                $raw | Should -BeLike '*"Standard_A1_v2","1"*'
                $raw | Should -BeLike '*"Standard_A2_v2","1.05"*'
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
            }
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

    Context 'Convergence' {
        It 'Replaces the output with exactly what the API returned, removing retired records' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_Retired'; Ratio = '2' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'Standard_D8' -Group 'DSeries' -Ratio '8')
                )
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.ArmSkuName | Should -Be @('Standard_D2', 'Standard_D8')   # retired record is gone
        }

        It 'Fails instead of publishing when the same SKU appears in multiple flexibility groups' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'GroupA' -Ratio '1'),
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'GroupB' -Ratio '2')
                )
            }

            { Invoke-Generator $baseParams } | Should -Throw -ExpectedMessage '*Duplicate ArmSkuName*'

            Test-Path $outFile | Should -BeFalse
        }
    }

    Context 'Default scope' {
        It 'Queries VirtualMachines, RedisCache, and DedicatedHost but not BlockBlob by default' {
            Mock Invoke-AzRestMethod { New-CatalogResponse -Items @() }

            Invoke-Generator @{ OutputPath = $outFile; Location = @('eastus') }

            Should -Invoke Invoke-AzRestMethod -Exactly -Times 3
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*reservedResourceType=VirtualMachines*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*reservedResourceType=RedisCache*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*reservedResourceType=DedicatedHost*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 0 -ParameterFilter { $Uri -like '*reservedResourceType=BlockBlob*' }
        }
    }

    Context 'Region enumeration' {
        BeforeEach {
            function New-LocationsResponse
            {
                param([object[]]$Locations, [int]$StatusCode = 200)
                [PSCustomObject]@{
                    StatusCode = $StatusCode
                    Content    = @{ value = $Locations } | ConvertTo-Json -Depth 20
                }
            }
        }

        It 'Sweeps every physical region returned by the ARM locations API when -Location is omitted' {
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*/locations?*')
                {
                    # regionType is nested under metadata in the real ARM response.
                    New-LocationsResponse -Locations @(
                        @{ name = 'eastus'; metadata = @{ regionType = 'Physical' } },
                        @{ name = 'switzerlandnorth'; metadata = @{ regionType = 'Physical' } },
                        @{ name = 'global'; metadata = @{ regionType = 'Logical' } },
                        @{ name = 'nometadata' }
                    )
                }
                else
                {
                    New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'))
                }
            }

            Invoke-Generator @{ OutputPath = $outFile; ReservedResourceType = @('VirtualMachines') }

            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*/locations?*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*location=eastus*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*location=switzerlandnorth*' }
            # Logical groupings are not valid catalog scopes, and neither is an entry with no metadata.
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 0 -ParameterFilter { $Uri -like '*location=global*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 0 -ParameterFilter { $Uri -like '*location=nometadata*' }
        }

        It 'Does not enumerate regions when -Location is supplied' {
            Mock Invoke-AzRestMethod { New-CatalogResponse -Items @() }

            Invoke-Generator $baseParams

            Should -Invoke Invoke-AzRestMethod -Exactly -Times 0 -ParameterFilter { $Uri -like '*/locations?*' }
        }

        It 'Fails rather than sweeping a partial region set when enumeration returns nothing' {
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*/locations?*') { New-LocationsResponse -Locations @(@{ name = 'global'; metadata = @{ regionType = 'Logical' } }) }
                else { New-CatalogResponse -Items @() }
            }

            { Invoke-Generator @{ OutputPath = $outFile } } | Should -Throw -ExpectedMessage '*no physical regions*'
        }

        It 'Fails when the locations API returns an error' {
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*/locations?*') { New-LocationsResponse -Locations @() -StatusCode 403 }
                else { New-CatalogResponse -Items @() }
            }

            { Invoke-Generator @{ OutputPath = $outFile } } | Should -Throw -ExpectedMessage '*HTTP 403 enumerating regions*'
        }

        It 'Retries a transient failure when enumerating regions instead of failing the run' {
            # Region enumeration is a hard prerequisite for every catalog call, so a single 429 or
            # 5xx here would otherwise fail the whole weekly refresh before it fetched anything.
            $script:locationsCallCount = 0
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*/locations?*')
                {
                    $script:locationsCallCount++
                    if ($script:locationsCallCount -eq 1)
                    {
                        New-LocationsResponse -Locations @() -StatusCode 503
                    }
                    else
                    {
                        New-LocationsResponse -Locations @(@{ name = 'eastus'; metadata = @{ regionType = 'Physical' } })
                    }
                }
                else
                {
                    New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'))
                }
            }

            Invoke-Generator @{ OutputPath = $outFile; ReservedResourceType = @('VirtualMachines') }

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_D2'
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 2 -ParameterFilter { $Uri -like '*/locations?*' }
            Should -Invoke Invoke-AzRestMethod -Exactly -Times 1 -ParameterFilter { $Uri -like '*location=eastus*' }
        }
    }

    Context 'Published dataset' {
        It 'Has globally unique ArmSkuName values' {
            $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"
            $duplicates = @($csv | Group-Object ArmSkuName | Where-Object Count -gt 1)
            $duplicates.Name | Should -BeNullOrEmpty
        }

        It 'Has every flexibility group normalized to a smallest ratio of 1' {
            $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"
            $notNormalized = @(
                $csv | Group-Object InstanceSizeFlexibilityGroup | Where-Object {
                    [Math]::Abs((($_.Group.Ratio | ForEach-Object { [double]$_ } | Measure-Object -Minimum).Minimum) - 1) -gt 0.0001
                }
            )
            $notNormalized.Name | Should -BeNullOrEmpty
        }

        It 'Has no zero or negative ratios' {
            # Consumers multiply and divide by Ratio, so a non-positive value is unusable.
            $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"
            @($csv | Where-Object { [double]$_.Ratio -le 0 }).ArmSkuName | Should -BeNullOrEmpty
        }

        It 'Has the documented three-column schema' {
            $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"
            @($csv[0].PSObject.Properties.Name) | Should -Be @('InstanceSizeFlexibilityGroup', 'ArmSkuName', 'Ratio')
        }
    }

    Context 'Normalization' {
        It 'Rescales each group so the smallest ratio is 1 by default' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_B1s' -Group 'BS Series' -Ratio '0.25'),
                    (New-CatalogItem -Sku 'Standard_B2s' -Group 'BS Series' -Ratio '0.5'),
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'Standard_D4' -Group 'DSeries' -Ratio '2')
                )
            }
            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            ($rows | Where-Object ArmSkuName -eq 'Standard_B1s').Ratio | Should -Be '1'
            ($rows | Where-Object ArmSkuName -eq 'Standard_B2s').Ratio | Should -Be '2'
            ($rows | Where-Object ArmSkuName -eq 'Standard_D2').Ratio | Should -Be '1'
            ($rows | Where-Object ArmSkuName -eq 'Standard_D4').Ratio | Should -Be '2'
        }

        It 'Keeps the API ratios verbatim when -Raw is set' {
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_B1s' -Group 'BS Series' -Ratio '0.25'),
                    (New-CatalogItem -Sku 'Standard_B2s' -Group 'BS Series' -Ratio '0.5')
                )
            }

            $params = $baseParams.Clone()
            $params.Raw = $true

            Invoke-Generator $params

            $rows = @(Import-Csv $outFile)
            ($rows | Where-Object ArmSkuName -eq 'Standard_B1s').Ratio | Should -Be '0.25'
            ($rows | Where-Object ArmSkuName -eq 'Standard_B2s').Ratio | Should -Be '0.5'
        }
    }
}
