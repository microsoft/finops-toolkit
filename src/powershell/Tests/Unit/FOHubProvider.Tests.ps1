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

    Context 'Storage lookup diagnostics' {
        It 'Classifies <Message> as <Blocker> without a data-plane probe' -Tag 'DeferredReview' -ForEach @(
            @{ Message = 'The request timed out.'; Blocker = 'LookupFailed' }
            @{ Message = 'ResourceNotFound HTTP 404'; Blocker = 'LookupFailed' }
            @{ Message = 'AuthorizationFailed HTTP 403'; Blocker = 'NoRbac' }
            @{ Message = 'AuthenticationFailed HTTP 401'; Blocker = 'AuthenticationFailed' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Message = $Message; Blocker = $Blocker } {
                param($Message, $Blocker)
                $lookupMessage = $Message
                Mock Get-AzStorageAccount { throw $lookupMessage }
                Mock New-AzStorageContext { throw 'A data-plane probe must not run after a failed lookup.' }

                $result = Test-HubStorageAccess -StorageAccountName 'examplestorage' -ResourceGroupName 'example-group'

                $result.Readable | Should -BeFalse
                $result.Blocker | Should -Be $Blocker
                $result.Detail | Should -Match ([regex]::Escape($Message))
                if ($Blocker -ne 'NoRbac') { $result.Remediation | Should -Not -Match '^Grant' }
                Should -Invoke New-AzStorageContext -Times 0 -Exactly
            }
        }
    }

    Context 'Unknown Hub coverage' {
        It 'Does not turn unreadable subscription metadata into complete coverage' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    if ($Query -like '*microsoft.storage/storageaccounts*') {
                        return @{ Data = @([pscustomobject]@{ name = 'fixture'; resourceGroup = 'fixture'; subscriptionId = '11111111-1111-1111-1111-111111111111'; location = 'eastus' }) }
                    }
                    @{ Data = @([pscustomobject]@{ c = 0 }) }
                }
                Mock Get-HubKustoCluster { $null }
                Mock Test-HubStorageAccess { @{ Readable = $true; Context = [pscustomobject]@{ Synthetic = $true } } }
                Mock Get-HubCoverage { @{ Subs = @(); Freshness = $null } }

                $result = Resolve-CostDataSource -RequestedSubscriptionIds @('11111111-1111-1111-1111-111111111111')

                $result.HubFound | Should -BeTrue
                $result.CoveragePct | Should -BeNullOrEmpty
                $result.CoverageKnown | Should -BeFalse
                $result.Message | Should -Match 'could not be confirmed'
            }
        }
    }

    Context 'Direct provider transport' {
        It 'Maps named columns, null cells, and numeric credits while preserving the request contract' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-RestMethod {
                    '{"Tables":[{"TableName":"PrimaryResult","Columns":[{"ColumnName":"Currency"},{"ColumnName":"Actual"},{"ColumnName":"Label"}],"Rows":[["USD",0,null],["USD",-12.5,"credit"]]},{"TableName":"QueryStatus","Columns":[{"ColumnName":"Severity"},{"ColumnName":"StatusDescription"}],"Rows":[[4,"Query completed successfully"]]}]}' | ConvertFrom-Json
                }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'https://fixture.eastus.kusto.windows.net/' -Database 'Fixture Hub' -Query 'print Actual=0' -AccessToken 'synthetic-token' -TimeoutSec 17

                $result.Ok | Should -BeTrue
                $result.RowCount | Should -Be 2
                $result.Rows[0].Actual | Should -Be 0
                $result.Rows[0].Label | Should -BeNullOrEmpty
                $result.Rows[1].Actual | Should -Be -12.5
                $result.Rows[1].Currency | Should -Be 'USD'
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $request = $Body | ConvertFrom-Json
                    $Uri -eq 'https://fixture.eastus.kusto.windows.net/v1/rest/query' -and
                    $Method -eq 'Post' -and $TimeoutSec -eq 17 -and $MaximumRedirection -eq 0 -and
                    $Headers.Authorization -eq 'Bearer synthetic-token' -and
                    $request.db -eq 'Fixture Hub' -and $request.csl -eq 'print Actual=0'
                }
            }
        }

        It 'Keeps a valid zero-row table as successful empty data' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-RestMethod { '{"Tables":[{"TableName":"PrimaryResult","Columns":[{"ColumnName":"Actual"}],"Rows":[]}]}' | ConvertFrom-Json }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'http://localhost:8082' -Query 'print Actual=0 | take 0'

                $result.Ok | Should -BeTrue
                $result.RowCount | Should -Be 0
                @($result.Rows).Count | Should -Be 0
                $result.Error | Should -BeNullOrEmpty
            }
        }

        It 'Uses v1 status <Severity> with omitted metadata column <OmitColumn>' -Tag 'ProviderTransport', 'ProviderReviewFollowup' -ForEach @(
            @{ Severity = 4; ExpectedSuccess = $true; OmitColumn = $null; FailurePattern = 'partial query failure' }
            @{ Severity = 2; ExpectedSuccess = $false; OmitColumn = $null; FailurePattern = 'partial query failure' }
            @{ Severity = 1; ExpectedSuccess = $false; OmitColumn = $null; FailurePattern = 'partial query failure' }
            @{ Severity = 4; ExpectedSuccess = $false; OmitColumn = 'Name'; FailurePattern = 'incomplete table-of-contents schema' }
            @{ Severity = 4; ExpectedSuccess = $false; OmitColumn = 'Kind'; FailurePattern = 'incomplete table-of-contents schema' }
            @{ Severity = 4; ExpectedSuccess = $false; OmitColumn = 'Ordinal'; FailurePattern = 'incomplete table-of-contents schema' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Severity = $Severity; ExpectedSuccess = $ExpectedSuccess; OmitColumn = $OmitColumn; FailurePattern = $FailurePattern } {
                param($Severity, $ExpectedSuccess, $OmitColumn, $FailurePattern)
                $fixtureResponse = @'
{"Tables":[
  {"TableName":"Table_0","Columns":[{"ColumnName":"Actual"}],"Rows":[[10]]},
  {"TableName":"Table_1","Columns":[{"ColumnName":"Value"}],"Rows":[["{}"]]},
  {"TableName":"Table_2","Columns":[{"ColumnName":"Severity"},{"ColumnName":"StatusDescription"}],"Rows":[[4,"Fixture query status"]]},
  {"TableName":"Table_3","Columns":[{"ColumnName":"Ordinal"},{"ColumnName":"Kind"},{"ColumnName":"Name"},{"ColumnName":"Id"},{"ColumnName":"PrettyName"}],"Rows":[[0,"QueryResult","PrimaryResult","a",""],[1,"QueryProperties","@ExtendedProperties","b",""],[2,"QueryStatus","QueryStatus","c",""]]}
]}
'@ | ConvertFrom-Json
                $fixtureResponse.Tables[2].Rows[0][0] = $Severity
                if ($OmitColumn) {
                    $contents = $fixtureResponse.Tables[3]
                    $removedIndex = [array]::IndexOf(@($contents.Columns.ColumnName), $OmitColumn)
                    $keptIndexes = @(0..($contents.Columns.Count - 1) | Where-Object { $_ -ne $removedIndex })
                    $contents.Columns = @($contents.Columns[$keptIndexes])
                    $contents.Rows = @(foreach ($row in $contents.Rows) { , @($row[$keptIndexes]) })
                }
                Mock Invoke-RestMethod { $fixtureResponse }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'http://localhost:8082' -Query 'print Actual=10'

                $result.Ok | Should -Be $ExpectedSuccess
                if ($ExpectedSuccess) {
                    $result.RowCount | Should -Be 1
                    $result.Rows[0].Actual | Should -Be 10
                }
                else {
                    $result.RowCount | Should -Be 0
                    @($result.Rows).Count | Should -Be 0
                    $result.Error | Should -Match $FailurePattern
                }
            }
        }

        It 'Rejects <Case> without returning partial rows' -Tag 'ProviderTransport' -ForEach @(
            @{ Case = 'null response'; Response = 'null' }
            @{ Case = 'missing tables'; Response = '{}' }
            @{ Case = 'non-array tables'; Response = '{"Tables":{}}' }
            @{ Case = 'null table'; Response = '{"Tables":[null]}' }
            @{ Case = 'missing columns'; Response = '{"Tables":[{"Rows":[[10]]}]}' }
            @{ Case = 'missing rows'; Response = '{"Tables":[{"Columns":[{"ColumnName":"Actual"}]}]}' }
            @{ Case = 'blank column name'; Response = '{"Tables":[{"Columns":[{"ColumnName":" "}],"Rows":[[10]]}]}' }
            @{ Case = 'case-colliding columns'; Response = '{"Tables":[{"Columns":[{"ColumnName":"Cost"},{"ColumnName":"cost"}],"Rows":[[10,20]]}]}' }
            @{ Case = 'array-valued column name'; Response = '{"Tables":[{"Columns":[{"ColumnName":["Actual","Currency"]}],"Rows":[[10,"USD"]]}]}' }
            @{ Case = 'empty-array column name'; Response = '{"Tables":[{"Columns":[{"ColumnName":[]}],"Rows":[[]]}]}' }
            @{ Case = 'invalid status reference'; Response = '{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"Actual"}],"Rows":[[10]]},{"TableName":"Table_1","Columns":[{"ColumnName":"Ordinal"},{"ColumnName":"Kind"},{"ColumnName":"Name"}],"Rows":[[9,"QueryStatus","QueryStatus"]]}]}' }
            @{ Case = 'non-scalar table name'; Response = '{"Tables":[{"TableName":["Table_0"],"Columns":[{"ColumnName":"Actual"}],"Rows":[[10]]}]}' }
            @{ Case = 'non-scalar status kind'; Response = '{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"Actual"}],"Rows":[[10]]},{"TableName":"Table_1","Columns":[{"ColumnName":"Ordinal"},{"ColumnName":"Kind"},{"ColumnName":"Name"}],"Rows":[[0,["QueryStatus","Ignored"],"QueryStatus"]]}]}' }
            @{ Case = 'short row after valid data'; Response = '{"Tables":[{"Columns":[{"ColumnName":"Actual"},{"ColumnName":"Currency"}],"Rows":[[10,"USD"],[20]]}]}' }
            @{ Case = 'long row'; Response = '{"Tables":[{"Columns":[{"ColumnName":"Actual"}],"Rows":[[10,20]]}]}' }
            @{ Case = 'scalar row'; Response = '{"Tables":[{"Columns":[{"ColumnName":"Actual"}],"Rows":[10]}]}' }
            @{ Case = 'partial query failure'; Response = '{"Tables":[{"TableName":"PrimaryResult","Columns":[{"ColumnName":"Actual"}],"Rows":[[10]]},{"TableName":"QueryStatus","Columns":[{"ColumnName":"Severity"},{"ColumnName":"StatusDescription"}],"Rows":[[2,"Partial query failure"]]}]}' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Response = $Response } {
                param($Response)
                $fixtureResponse = $Response | ConvertFrom-Json
                Mock Invoke-RestMethod { $fixtureResponse }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'http://localhost:8082' -Query 'print Actual=10'

                $result.Ok | Should -BeFalse
                $result.RowCount | Should -Be 0
                @($result.Rows).Count | Should -Be 0
                $result.Error | Should -Not -BeNullOrEmpty
            }
        }

        It 'Returns a transport error without success-shaped data' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-RestMethod { throw 'Synthetic transport failure.' }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'http://localhost:8082' -Query 'print Actual=10'

                $result.Ok | Should -BeFalse
                $result.RowCount | Should -Be 0
                @($result.Rows).Count | Should -Be 0
                $result.Error | Should -Match 'Synthetic transport failure'
            }
        }

        It 'Reads PowerShell 7 Kusto error details from <Field>' -Tag 'ProviderTransport' -ForEach @(
            @{ Field = '@message' }
            @{ Field = 'message' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Field = $Field } {
                param($Field)
                $fixtureError = [Management.Automation.ErrorRecord]::new([InvalidOperationException]::new('HTTP 400 Bad Request'), 'FixtureHttpError', [Management.Automation.ErrorCategory]::InvalidOperation, $null)
                $fixtureError.ErrorDetails = [Management.Automation.ErrorDetails]::new((@{ error = @{ $Field = 'Synthetic Kusto query could not resolve Costs.' } } | ConvertTo-Json))
                Mock Invoke-RestMethod { throw $fixtureError }

                $result = Invoke-FOHubKustoQuery -ClusterUri 'http://localhost:8082' -Query 'Costs | take 1'

                $result.Ok | Should -BeFalse
                $result.Error | Should -Be 'Kusto query failed: Synthetic Kusto query could not resolve Costs.'
                @($result.Rows).Count | Should -Be 0
            }
        }

        It 'Stops before transport when provider token acquisition fails' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { throw 'Synthetic authentication failure.' }
                Mock Invoke-FOHubKustoQuery { throw 'Transport must not run after authentication fails.' }

                $result = Invoke-FOHubProviderQuery -Provider @{ ClusterUri = 'https://fixture.eastus.kusto.windows.net'; Database = 'Hub'; UseAuth = $true } -Query 'print Actual=10'

                $result.Ok | Should -BeFalse
                $result.RowCount | Should -Be 0
                @($result.Rows).Count | Should -Be 0
                $result.Error | Should -Match 'Could not acquire a Kusto token.*Synthetic authentication failure'
                Should -Invoke Invoke-FOHubKustoQuery -Times 0 -Exactly
            }
        }

        It 'Rejects an unusable provider token for <Case> before transport' -Tag 'ProviderTransport' -ForEach @(
            @{ Case = 'null'; Token = $null }
            @{ Case = 'empty'; Token = '' }
            @{ Case = 'whitespace'; Token = '   ' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Token = $Token } {
                param($Token)
                $fixtureToken = $Token
                Mock Get-PlainAccessToken { $fixtureToken }
                Mock Invoke-FOHubKustoQuery { throw 'An authenticated provider must not send an anonymous request.' }

                $result = Invoke-FOHubProviderQuery -Provider @{ ClusterUri = 'https://fixture.eastus.kusto.windows.net'; Database = 'Hub'; UseAuth = $true } -Query 'print Actual=10'

                $result.Ok | Should -BeFalse
                @($result.Rows).Count | Should -Be 0
                $result.Error | Should -Match 'token'
                Should -Invoke Invoke-FOHubKustoQuery -Times 0 -Exactly
            }
        }

        It 'Makes shared token acquisition fail for <Case>' -Tag 'ProviderTransport' -ForEach @(
            @{ Case = 'nonterminating authentication error'; Nonterminating = $true }
            @{ Case = 'empty token result'; Nonterminating = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Nonterminating = $Nonterminating } {
                param($Nonterminating)
                $fixtureNonterminating = $Nonterminating
                Mock Get-AzAccessToken {
                    if ($fixtureNonterminating) {
                        Write-Error 'Synthetic authentication failure.'
                        return [pscustomobject]@{ Token = 'must-not-be-returned' }
                    }
                    [pscustomobject]@{ Token = $null }
                }

                { Get-PlainAccessToken -ResourceUrl 'https://fixture.eastus.kusto.windows.net' } | Should -Throw
                Should -Invoke Get-AzAccessToken -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
            }
        }

        It 'Retains valid plain and secure token values' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Get-AzAccessToken { [pscustomobject]@{ Token = 'synthetic-token' } }
                Get-PlainAccessToken -ResourceUrl 'https://fixture.eastus.kusto.windows.net' | Should -Be 'synthetic-token'
                $fixtureSecureToken = [securestring]::new()
                try {
                    foreach ($character in 'synthetic-token'.ToCharArray()) { $fixtureSecureToken.AppendChar($character) }
                    $fixtureSecureToken.MakeReadOnly()
                    Mock Get-AzAccessToken { [pscustomobject]@{ Token = $fixtureSecureToken } }
                    Get-PlainAccessToken -ResourceUrl 'https://fixture.eastus.kusto.windows.net' | Should -Be 'synthetic-token'
                }
                finally { $fixtureSecureToken.Dispose() }
            }
        }

        It 'Builds literal tag filters for quotes and trailing backslashes' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery {
                    @{ Ok = $true; Rows = @(
                        [pscustomobject]@{ _CostValidation = $true; _InvalidCosts = 0; _CurrencyCount = 1; _SourceRows = 1; _MissingSubscriptions = 0 }
                        [pscustomobject]@{ TagKey = '*TOTAL*'; TagValue = '*TOTAL*'; Cost = 10; Currency = 'USD' }
                    ) }
                }

                $null = Get-FOHubCostByTag -Provider @{ ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false } -TagKeys @('owner"label', 'path\', 'both\"tail')

                Should -Invoke Invoke-FOHubKustoQuery -Times 1 -Exactly -ParameterFilter {
                    $Query.Contains('| where k in~ ("owner\"label", "path\\", "both\\\"tail")')
                }
            }
        }

        It 'Normalizes scope GUIDs and rejects an invalid mixed scope before transport' -Tag 'ProviderTransport' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-FOHubKustoQuery { throw 'Invalid scope must not reach transport.' }

                Get-FOHubScopeClause -SubscriptionIds @('AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA') | Should -Be '| where SubAccountId has_any (dynamic(["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]))'
                { Get-FOHubCostSummary -Provider @{ ClusterUri = 'http://localhost:8082'; Database = 'Hub'; UseAuth = $false } -SubscriptionIds @('11111111-1111-1111-1111-111111111111', 'invalid"scope') } | Should -Throw '*Refusing to drop the scope filter*'
                Should -Invoke Invoke-FOHubKustoQuery -Times 0 -Exactly
            }
        }

        It 'Rejects the invalid explicit override <Endpoint> before discovery or authentication' -Tag 'ProviderTransport' -ForEach @(
            @{ Endpoint = 'not a URI' }
            @{ Endpoint = 'http://example.test' }
            @{ Endpoint = 'https://fixture.eastus.kusto.windows.net/?unexpected=true' }
            @{ Endpoint = 'https://user:password@example.test' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Endpoint = $Endpoint } {
                param($Endpoint)
                $previousUri = $env:FINOPS_HUB_KUSTO_URI
                try {
                    $env:FINOPS_HUB_KUSTO_URI = $Endpoint
                    Mock Search-AzGraphSafe { throw 'Invalid override must not trigger discovery.' }
                    Mock Get-PlainAccessToken { throw 'Invalid override must not acquire a token.' }

                    { Resolve-FOHubProvider } | Should -Throw

                    Should -Invoke Search-AzGraphSafe -Times 0 -Exactly
                    Should -Invoke Get-PlainAccessToken -Times 0 -Exactly
                }
                finally { $env:FINOPS_HUB_KUSTO_URI = $previousUri }
            }
        }
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
        It 'Distinguishes <Outcome> discovery from an empty successful lookup' -Tag 'ProviderDiscovery' -ForEach @(
            @{ Outcome = 'exception'; ExpectedWarnings = 1 }
            @{ Outcome = 'null response'; ExpectedWarnings = 1 }
            @{ Outcome = 'empty success'; ExpectedWarnings = 0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Outcome = $Outcome; ExpectedWarnings = $ExpectedWarnings } {
                param($Outcome, $ExpectedWarnings)
                $previousUri = $env:FINOPS_HUB_KUSTO_URI
                try {
                    $env:FINOPS_HUB_KUSTO_URI = $null
                    $fixtureOutcome = $Outcome
                    Mock Search-AzGraphSafe {
                        if ($fixtureOutcome -eq 'exception') { throw "Denied$([char]27)[2J$([char]0x202e)`r`nquery" }
                        if ($fixtureOutcome -eq 'null response') { return $null }
                        @{ Data = @() }
                    }

                    $result = Resolve-FOHubProvider -Subscriptions @('11111111-1111-1111-1111-111111111111') -WarningAction SilentlyContinue -WarningVariable warnings

                    $result.Found | Should -BeFalse
                    $result.Mode | Should -Be 'None'
                    @($warnings).Count | Should -Be $ExpectedWarnings
                    if ($ExpectedWarnings) {
                        ($warnings -join '') | Should -Match 'Kusto.*could not be verified'
                        ($warnings -join '') | Should -Not -Match '[\p{Cc}\p{Cf}]'
                    }
                    Should -Invoke Search-AzGraphSafe -Times 1 -Exactly -ParameterFilter {
                        @($Subscription).Count -eq 1 -and $Subscription[0] -eq '11111111-1111-1111-1111-111111111111' -and $First -eq 1
                    }
                }
                finally { $env:FINOPS_HUB_KUSTO_URI = $previousUri }
            }
        }

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
