# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

BeforeAll {
    $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
    Import-Module $script:MultitoolModule -Force
}

AfterAll {
    Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
}

Describe 'FinOps Hub Kusto provider' {

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
                            [PSCustomObject]@{ _sub = 'aaaaaaaa-1111-2222-3333-444444444444'; Actual = 123.456; Currency = 'USD' }
                            [PSCustomObject]@{ _sub = 'bbbbbbbb-1111-2222-3333-444444444444'; Actual = 10.0; Currency = 'EUR' }
                        )
                    }
                }
                $prov = @{ Found = $true; Mode = 'KustoLocal'; ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false }
                $map = Get-FOHubCostSummary -Provider $prov

                $map | Should -BeOfType ([hashtable])
                $map.Keys.Count | Should -Be 2
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Actual | Should -Be 123.46
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Forecast | Should -Be 0.0
                $map['aaaaaaaa-1111-2222-3333-444444444444'].Currency | Should -Be 'USD'
                $map['bbbbbbbb-1111-2222-3333-444444444444'].Currency | Should -Be 'EUR'
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
                $rows[0].Forecast | Should -Be 0.0
            }
        }
    }

    Context 'Get-FOHubCostByTag shape' {
        It 'Derives (untagged) cost per key from the TOTAL sentinel' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{
                        Ok       = $true
                        RowCount = 3
                        Error    = $null
                        Rows     = @(
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
}
