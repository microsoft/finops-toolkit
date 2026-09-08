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
        if (Test-Path $outFile) { Remove-Item $outFile -Force }  # the generator merges into an existing file
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
            # benefits simulation divides by it. The API returns one (Azure Redis Cache Isolated).
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
            # On a comma-decimal culture, culture-aware parsing turns "2.1" into 21 (de-DE) or
            # drops the row outright (fr-CH), and Export-Csv writes "2,1" back out, which breaks
            # every consumer of the published file.
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::new('de-DE')
                @([PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A2_v2'; Ratio = '2.1' }) `
                | Export-Csv $outFile -NoTypeInformation
                Mock Invoke-AzRestMethod {
                    New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '4.5'))
                }

                Invoke-Generator $baseParams

                $raw = Get-Content $outFile -Raw
                $raw | Should -BeLike '*"Standard_A2_v2","2.1"*'   # carried forward, not 21
                $raw | Should -BeLike '*"Standard_D2","4.5"*'      # from the API, not 45
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

    Context 'Additive merge' {
        It 'Carries forward published records the API no longer returns' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A1_v2'; Ratio = '2' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '1'),
                    (New-CatalogItem -Sku 'Standard_D8' -Group 'DSeries' -Ratio '8')
                )
            }

            Invoke-Generator $baseParams

            # Standard_A1_v2 is no longer purchasable, so the API omits it, but reservations still
            # cover it -- issue #2300.
            @(Import-Csv $outFile).ArmSkuName | Should -Be @('Standard_A1_v2', 'Standard_D2', 'Standard_D8')
        }

        It 'Lets the API supersede a published record for the same SKU' {
            @([PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '1' }) `
            | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries v2' -Ratio '4'))
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.Count | Should -Be 1
            $rows[0].InstanceSizeFlexibilityGroup | Should -Be 'DSeries v2'
            $rows[0].Ratio | Should -Be '4'
        }

        It 'Drops published SKUs that map to more than one flexibility group' {
            # Ambiguous SKUs would break the ArmSkuName join key that Power BI's model
            # relationship and the Optimization Engine's externaldata() joins depend on.
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'PTU_Area_US East'; ArmSkuName = 'Provisioned_Managed'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'PTU_Area_EU West'; ArmSkuName = 'Provisioned_Managed'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A1_v2'; Ratio = '1' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod { New-CatalogResponse -Items @() }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_A1_v2'
        }

        It 'Ignores published rows with a blank, non-numeric or non-positive ratio' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MDC_PrePurchase_Plan'; ArmSkuName = 'Free'; Ratio = '' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Isolated'; ArmSkuName = 'azure_redis_cache_isolated_i100'; Ratio = '0' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A1_v2'; Ratio = '1' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod { New-CatalogResponse -Items @() }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_A1_v2'
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

    Context 'Ratio scale' {
        It 'Fails when a carried-forward group is on a different scale than the API' {
            # The retired files normalized each group to smallest-SKU-=-1; the API reports vCPU
            # counts. Azure retires individual sizes, so the API returns only part of Ev3 Series
            # and merging per SKU would leave both units in one group.
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E2_v3'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E4_v3'; Ratio = '2' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E8_v3'; Ratio = '4' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @(
                    (New-CatalogItem -Sku 'Standard_E2_v3' -Group 'Ev3 Series' -Ratio '2'),
                    (New-CatalogItem -Sku 'Standard_E4_v3' -Group 'Ev3 Series' -Ratio '4')
                )
            }

            { Invoke-Generator $baseParams } | Should -Throw -ExpectedMessage '*different ratio scale*'
        }

        It 'Accepts a migrated group whose ratios already match the API' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E2_v3'; Ratio = '2' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E4_v3'; Ratio = '4' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev3 Series'; ArmSkuName = 'Standard_E8_v3'; Ratio = '8' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_E2_v3' -Group 'Ev3 Series' -Ratio '2'))
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            $rows.Count | Should -Be 3
            ($rows | Where-Object ArmSkuName -eq 'Standard_E8_v3').Ratio | Should -Be '8'
        }

        It 'Takes a small ratio correction from the API without failing the run' {
            # A genuine correction from Microsoft is small; only scale-sized gaps are fatal.
            @([PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSeries'; ArmSkuName = 'Standard_D2'; Ratio = '2' }) `
            | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '2.1'))
            }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).Ratio | Should -Be '2.1'
        }

        It 'Ignores a group the API does not cover' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A1_v2'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A2_v2'; Ratio = '2.1' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod {
                New-CatalogResponse -Items @((New-CatalogItem -Sku 'Standard_D2' -Group 'DSeries' -Ratio '2'))
            }

            Invoke-Generator $baseParams

            $rows = @(Import-Csv $outFile)
            ($rows | Where-Object ArmSkuName -eq 'Standard_A1_v2').Ratio | Should -Be '1'
            ($rows | Where-Object ArmSkuName -eq 'Standard_A2_v2').Ratio | Should -Be '2.1'
        }

        It 'Drops placeholder SKU names carried in the published file' {
            @(
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NV Series'; ArmSkuName = 'arm_sku_name_placeholder'; Ratio = '1' },
                [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Av2 Series'; ArmSkuName = 'Standard_A1_v2'; Ratio = '1' }
            ) | Export-Csv $outFile -NoTypeInformation
            Mock Invoke-AzRestMethod { New-CatalogResponse -Items @() }

            Invoke-Generator $baseParams

            @(Import-Csv $outFile).ArmSkuName | Should -Be 'Standard_A1_v2'
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
            # Logical groupings are not valid catalog scopes, and neither is an entry whose
            # metadata is missing entirely.
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

            { Invoke-Generator @{ OutputPath = $outFile } } |
                Should -Throw -ExpectedMessage '*no physical regions*'
        }

        It 'Fails when the locations API returns an error' {
            Mock Invoke-AzRestMethod {
                if ($Uri -like '*/locations?*') { New-LocationsResponse -Locations @() -StatusCode 403 }
                else { New-CatalogResponse -Items @() }
            }

            { Invoke-Generator @{ OutputPath = $outFile } } |
                Should -Throw -ExpectedMessage '*HTTP 403 enumerating regions*'
        }
    }

    Context 'Published dataset' {
        It 'Has globally unique ArmSkuName values' {
            $csv = Import-Csv "$PSScriptRoot/../../../open-data/InstanceSizeFlexibility.csv"
            $duplicates = @($csv | Group-Object ArmSkuName | Where-Object Count -gt 1)
            $duplicates.Name | Should -BeNullOrEmpty
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
