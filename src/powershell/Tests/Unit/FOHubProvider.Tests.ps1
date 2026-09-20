# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'FinOps Hub Kusto provider' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Endpoint security' {
        It 'Rejects unsafe endpoint <Endpoint> before requesting a token or sending a request' -ForEach @(
            @{ Endpoint = 'http://example.test' }
            @{ Endpoint = 'http://127.0.0.1:8082' }
            @{ Endpoint = 'https://user:password@example.test' }
            @{ Endpoint = 'http://localhost:8082@example.test' }
            @{ Endpoint = 'https://example.test/#fragment' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Endpoint = $Endpoint } {
                param($Endpoint)
                Mock Get-AzAccessToken { throw 'Token acquisition must not occur.' }
                Mock Invoke-RestMethod { throw 'Network I/O must not occur.' }

                { Get-PlainAccessToken -ResourceUrl $Endpoint } | Should -Throw
                { Invoke-StorageBlobRest -Uri $Endpoint -StorageToken 'synthetic' } | Should -Throw
                { Get-StorageBlobBytes -Uri $Endpoint -StorageToken 'synthetic' } | Should -Throw
                (Invoke-FOHubKustoQuery -ClusterUri $Endpoint -Query 'print synthetic=1' -AccessToken 'synthetic').Ok | Should -BeFalse
                (Invoke-FOHubProviderQuery -Provider @{ ClusterUri = $Endpoint; UseAuth = $true; Database = 'Hub' } -Query 'print synthetic=1').Ok | Should -BeFalse
                Should -Invoke Get-AzAccessToken -Times 0 -Exactly
                Should -Invoke Invoke-RestMethod -Times 0 -Exactly
            }
        }

        It 'Allows token-free loopback Kusto requests without following redirects' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-RestMethod { @{ Tables = @() } }

                (Invoke-FOHubKustoQuery -ClusterUri 'http://127.0.0.1:8082' -Query 'print synthetic=1').Ok | Should -BeTrue

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $MaximumRedirection -eq 0 -and -not $Headers.ContainsKey('Authorization')
                }
            }
        }

        It 'Accepts HTTPS storage endpoints without following redirects' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-RestMethod { 'synthetic response' }
                Invoke-StorageBlobRest -Uri 'https://fixture.blob.core.windows.net/container?comp=list' -StorageToken 'synthetic' | Should -Be 'synthetic response'
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $MaximumRedirection -eq 0 }
            }
        }
    }

    Context 'Resolve-FOHubProvider - explicit override' {
        AfterEach {
            Remove-Item Env:FINOPS_HUB_KUSTO_URI -ErrorAction SilentlyContinue
            Remove-Item Env:FINOPS_HUB_KUSTO_DB -ErrorAction SilentlyContinue
        }

        It 'Resolves a localhost override to KustoLocal with no auth' {
            $env:FINOPS_HUB_KUSTO_URI = 'http://localhost:8082'
            $p = Resolve-FOHubProvider
            $p.Found | Should -BeTrue
            $p.Mode | Should -Be 'KustoLocal'
            $p.UseAuth | Should -BeFalse
            $p.Database | Should -Be 'Hub'
            $p.Source | Should -Be 'EnvOverride'
        }

        It 'Resolves a remote cluster override to Kusto with auth' {
            $env:FINOPS_HUB_KUSTO_URI = 'https://myhub.eastus.kusto.windows.net'
            $p = Resolve-FOHubProvider
            $p.Found | Should -BeTrue
            $p.Mode | Should -Be 'Kusto'
            $p.UseAuth | Should -BeTrue
        }

        It 'Honors a custom database name' {
            $env:FINOPS_HUB_KUSTO_URI = 'http://localhost:8082'
            $env:FINOPS_HUB_KUSTO_DB = 'CustomHub'
            $p = Resolve-FOHubProvider
            $p.Database | Should -Be 'CustomHub'
        }
    }

    Context 'Resolve-FOHubProvider - discovery and none' {
        It 'Uses a cluster already discovered on the decision object' {
            $decision = [PSCustomObject]@{ KustoClusterUri = 'https://disc.westus.kusto.windows.net'; KustoDatabase = 'Hub'; HubVersion = '0.10' }
            $p = Resolve-FOHubProvider -Decision $decision
            $p.Found | Should -BeTrue
            $p.Mode | Should -Be 'Kusto'
            $p.ClusterUri | Should -Be 'https://disc.westus.kusto.windows.net'
            $p.Source | Should -Be 'Discovered'
        }

        It 'Returns None when no override and discovery finds nothing' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { @{ Data = @() } }
                $p = Resolve-FOHubProvider -Subscriptions @('00000000-0000-0000-0000-000000000000')
                $p.Found | Should -BeFalse
                $p.Mode | Should -Be 'None'
            }
        }

        It 'Discovers a cluster directly when no decision is passed (TUI path)' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    @{ Data = @(
                            [PSCustomObject]@{ clusterUri = 'https://tui.eastus.kusto.windows.net'; hubVersion = '0.11'; resourceGroup = 'rg-hub'; subscriptionId = '1' }
                        ) }
                }
                $p = Resolve-FOHubProvider -Subscriptions @('1')
                $p.Found | Should -BeTrue
                $p.Mode | Should -Be 'Kusto'
                $p.UseAuth | Should -BeTrue
                $p.ClusterUri | Should -Be 'https://tui.eastus.kusto.windows.net'
                $p.Source | Should -Be 'Discovered'
            }
        }
    }

    Context 'Get-HubKustoCluster - online discovery' {
        It 'Discovers a FinOps hub Kusto cluster via Resource Graph' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    @{ Data = @(
                            [PSCustomObject]@{ clusterUri = 'https://ftk.eastus.kusto.windows.net'; hubVersion = '0.11'; resourceGroup = 'rg-hub'; subscriptionId = '11111111-1111-1111-1111-111111111111' }
                        ) }
                }
                $c = Get-HubKustoCluster -RequestedSubscriptionIds @('11111111-1111-1111-1111-111111111111')
                $c | Should -Not -BeNullOrEmpty
                $c.ClusterUri | Should -Be 'https://ftk.eastus.kusto.windows.net'
                $c.HubVersion | Should -Be '0.11'
            }
        }

        It 'Prefers the cluster in the hub resource group' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    @{ Data = @(
                            [PSCustomObject]@{ clusterUri = 'https://other.eastus.kusto.windows.net'; hubVersion = '0.11'; resourceGroup = 'rg-other'; subscriptionId = '1' }
                            [PSCustomObject]@{ clusterUri = 'https://mine.eastus.kusto.windows.net'; hubVersion = '0.11'; resourceGroup = 'rg-hub'; subscriptionId = '1' }
                        ) }
                }
                $c = Get-HubKustoCluster -RequestedSubscriptionIds @('1') -HubResourceGroup 'rg-hub'
                $c.ClusterUri | Should -Be 'https://mine.eastus.kusto.windows.net'
            }
        }

        It 'Returns null when no cluster is found' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Get-HubKustoCluster -RequestedSubscriptionIds @('1') | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Get-FOHubCostSummary shape' {
        It 'Produces a per-subscription cost map matching the converter shape' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{
                        Ok       = $true
                        RowCount = 2
                        Error    = $null
                        Rows     = @(
                            [PSCustomObject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 2; _MissingSubscriptions = 0 }
                            [PSCustomObject]@{ _sub = 'aaaaaaaa-1111-2222-3333-444444444444'; Actual = 123.456; Currency = 'USD' }
                            [PSCustomObject]@{ _sub = 'bbbbbbbb-1111-2222-3333-444444444444'; Actual = 10.0; Currency = 'USD' }
                        )
                    }
                }
                $prov = @{ Found = $true; Mode = 'KustoLocal'; ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false }
                $map = Get-FOHubCostSummary -Provider $prov

                $map | Should -BeOfType ([hashtable])
                $map.Keys.Count | Should -Be 2
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Actual | Should -Be 123.46
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Forecast | Should -BeNullOrEmpty
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Currency | Should -Be 'USD'
                $map['bbbbbbbb-1111-2222-3333-444444444444'].Currency | Should -Be 'USD'
                Should -Invoke Invoke-FOHubKustoQuery -Times 1 -Exactly -ParameterFilter {
                    $Query.Contains('todouble(BilledCost)') -and -not $Query.Contains('EffectiveCost') -and
                    $Query.Contains('isnull(_cost) or not(isfinite(_cost))')
                }
            }
        }

        It 'Surfaces a query error instead of throwing' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery { @{ Ok = $false; Rows = @(); RowCount = 0; Error = 'boom' } }
                $prov = @{ Found = $true; Mode = 'KustoLocal'; ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false }
                $r = Get-FOHubCostSummary -Provider $prov
                $r.Error | Should -Be 'boom'
            }
        }
    }

    Context 'Get-FOHubResourceCosts shape' {
        It 'Produces sorted resource cost objects with the converter properties' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{
                        Ok       = $true
                        RowCount = 2
                        Error    = $null
                        Rows     = @(
                            [PSCustomObject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 2; _MissingSubscriptions = 0 }
                            [PSCustomObject]@{ Subscription = 'Sub A'; ResourceGroup = 'rg1'; ResourceType = 'Microsoft.Compute/virtualMachines'; ResourcePath = '/subscriptions/x/rg1/vm1'; Actual = 50.0; Currency = 'USD' }
                            [PSCustomObject]@{ Subscription = 'Sub A'; ResourceGroup = 'rg2'; ResourceType = 'Microsoft.Storage/storageAccounts'; ResourcePath = '/subscriptions/x/rg2/sa1'; Actual = 200.0; Currency = 'USD' }
                        )
                    }
                }
                $prov = @{ Found = $true; Mode = 'KustoLocal'; ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false }
                $rows = Get-FOHubResourceCosts -Provider $prov

                @($rows).Count | Should -Be 2
                $rows[0].PSObject.Properties.Name | Should -Contain 'ResourcePath'
                $rows[0].PSObject.Properties.Name | Should -Contain 'Forecast'
                $rows[0].Actual | Should -Be 200.0
                $rows[0].Forecast | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Get-FOHubCostByTag shape' {
        It 'Preserves tag value case and negative untagged credits' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{ Ok = $true; Rows = @(
                        [pscustomobject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 3; _MissingSubscriptions = 0 }
                        [pscustomobject]@{ TagKey = '*TOTAL*'; Cost = 100; Currency = 'USD' }
                        [pscustomobject]@{ TagKey = 'env'; TagValue = 'Prod'; Cost = 50; Currency = 'USD' }
                        [pscustomobject]@{ TagKey = 'env'; TagValue = 'prod'; Cost = 70; Currency = 'USD' }
                    ) }
                }
                $provider = @{ UseAuth = $false; ClusterUri = 'http://localhost:8082'; Database = 'Hub' }

                $result = Get-FOHubCostByTag -Provider $provider -TagKeys @('env')

                @($result.CostByTag.env).Count | Should -Be 3
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 50
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 70
                ($result.CostByTag.env | Where-Object TagValue -EQ '(untagged)').Cost | Should -Be -20
                ($result.CostByTag.env | Measure-Object Cost -Sum).Sum | Should -Be 100
            }
        }

        It 'Validates coverage even when no tags are discovered' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    if ($Query.Contains('_CostValidation')) {
                        return @{ Ok = $true; Rows = @([pscustomobject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 0; _SourceRows = 0; _MissingSubscriptions = 1 }) }
                    }
                    @{ Ok = $true; Rows = @() }
                }
                $provider = @{ UseAuth = $false; ClusterUri = 'http://localhost:8082'; Database = 'Hub' }

                $result = Get-FOHubCostByTag -Provider $provider -SubscriptionIds @('44444444-4444-4444-4444-444444444444')

                $result.Error | Should -BeLike '*validation failed*'
            }
        }

        It 'Derives (untagged) cost per key from the TOTAL sentinel' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{
                        Ok       = $true
                        RowCount = 3
                        Error    = $null
                        Rows     = @(
                            [PSCustomObject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 3; _MissingSubscriptions = 0 }
                            [PSCustomObject]@{ TagKey = '*TOTAL*'; TagValue = '*TOTAL*'; Cost = 1000.0; Currency = 'USD' }
                            [PSCustomObject]@{ TagKey = 'env'; TagValue = 'prod'; Cost = 600.0; Currency = 'USD' }
                            [PSCustomObject]@{ TagKey = 'env'; TagValue = 'dev'; Cost = 300.0; Currency = 'USD' }
                        )
                    }
                }
                $prov = @{ Found = $true; Mode = 'KustoLocal'; ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false }
                $result = Get-FOHubCostByTag -Provider $prov -TagKeys @('env')

                $result.NoTagsFound | Should -BeFalse
                $result.TagsQueried | Should -Contain 'env'
                $envEntries = $result.CostByTag['env']
                ($envEntries | Where-Object { $_.TagValue -eq 'prod' }).Cost | Should -Be 600.0
                ($envEntries | Where-Object { $_.TagValue -eq 'dev' }).Cost | Should -Be 300.0
                ($envEntries | Where-Object { $_.TagValue -eq '(untagged)' }).Cost | Should -Be 100.0
                # Sorted descending: prod (600) first.
                $envEntries[0].TagValue | Should -Be 'prod'
            }
        }
    }

    It 'Rejects failed whole-scope cost validation (<Case>)' -ForEach @(
        @{ Case = 'unknown charge date'; InvalidCosts = 1; CurrencyCount = 1; MissingSubscriptions = 0 }
        @{ Case = 'invalid amount outside top results'; InvalidCosts = 1; CurrencyCount = 1; MissingSubscriptions = 0 }
        @{ Case = 'mixed currencies'; InvalidCosts = 0; CurrencyCount = 2; MissingSubscriptions = 0 }
        @{ Case = 'missing selected subscription'; InvalidCosts = 0; CurrencyCount = 1; MissingSubscriptions = 1 }
    ) {
        InModuleScope FinOpsMultitool -Parameters @{ InvalidCosts = $InvalidCosts; CurrencyCount = $CurrencyCount; MissingSubscriptions = $MissingSubscriptions } {
            param($InvalidCosts, $CurrencyCount, $MissingSubscriptions)
            $validationRow = [pscustomobject]@{ _CostValidation = $true; _InvalidCosts = $InvalidCosts; _CurrencyCount = $CurrencyCount; _SourceRows = 10; _MissingSubscriptions = $MissingSubscriptions }
            Mock Invoke-FOHubKustoQuery {
                @{ Ok = $true; Rows = @($validationRow, [pscustomobject]@{ Actual = 100; Currency = 'USD'; _sub = 'aaaaaaaa-1111-2222-3333-444444444444' }) }
            }
            $provider = @{ UseAuth = $false; ClusterUri = 'http://localhost:8082'; Database = 'Hub' }
            (Get-FOHubCostSummary -Provider $provider).Error | Should -BeLike '*validation failed*'
            (Get-FOHubResourceCosts -Provider $provider -Top 1).Error | Should -BeLike '*validation failed*'
            (Get-FOHubCostByTag -Provider $provider -TagKeys @('env')).Error | Should -BeLike '*validation failed*'
            Should -Invoke Invoke-FOHubKustoQuery -Times 3 -Exactly -ParameterFilter {
                $Query.Contains('where isnull(ChargePeriodStart) or') -and
                $Query.Contains('or isnull(ChargePeriodStart))')
            }
        }
    }
}
