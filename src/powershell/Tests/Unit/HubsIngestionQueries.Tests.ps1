# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'HubsIngestionQueries' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $appNames = @('Recommendations', 'Quota')
        $queryFiles = @($appNames | ForEach-Object {
                $appName = $_
                $appPath = Join-Path $repoRoot "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/$appName"
                $schemaFileNames = @(Get-ChildItem -Path "$appPath/schemas" -Filter '*.json' | ForEach-Object { $_.Name })

                Get-ChildItem -Path "$appPath/queries" -Filter '*.json' | ForEach-Object {
                    @{
                        AppName         = $appName
                        Name            = $_.Name
                        FullName        = $_.FullName
                        BaseName        = $_.BaseName
                        SchemaFileNames = $schemaFileNames
                    }
                }
            })
        $schemaFiles = @($appNames | ForEach-Object {
                $appName = $_
                Get-ChildItem -Path (Join-Path $repoRoot "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/$appName/schemas") -Filter '*.json' | ForEach-Object {
                    @{ AppName = $appName; Name = $_.Name; FullName = $_.FullName; BaseName = $_.BaseName }
                }
            })
        $quotaCatalogContracts = @(
            @{ Name = 'quota-app-service-usage.kql'; SourceTypes = @('AppServiceUsage'); ResourceTypes = @('Microsoft.Web/locations/usages') }
            @{ Name = 'quota-availability-zone-mappings.kql'; SourceTypes = @('AvailabilityZoneMapping'); ResourceTypes = @('Region') }
            @{ Name = 'quota-capacity-reservations.kql'; SourceTypes = @('CapacityReservation'); ResourceTypes = @('Microsoft.Compute/capacityReservationGroups') }
            @{ Name = 'quota-cognitive-services-usage.kql'; SourceTypes = @('CognitiveServicesUsage'); ResourceTypes = @('Microsoft.CognitiveServices/locations/usages') }
            @{ Name = 'quota-compute-resource-skus.kql'; SourceTypes = @('ComputeResourceSku'); ResourceTypes = @('virtualMachines') }
            @{ Name = 'quota-compute-usage.kql'; SourceTypes = @('ComputeUsage'); ResourceTypes = @('Microsoft.Compute/locations/usages') }
            @{ Name = 'quota-premium-ssd-v2-disks.kql'; SourceTypes = @('PremiumSSDv2Disk'); ResourceTypes = @('Microsoft.Compute/disks') }
            @{ Name = 'quota-sql-subscription-usage.kql'; SourceTypes = @('SqlSubscriptionUsage'); ResourceTypes = @('Microsoft.Sql/locations/usages') }
            @{ Name = 'quota-storage-usage.kql'; SourceTypes = @('StorageUsage', 'ComputeUsage'); ResourceTypes = @('Microsoft.Storage/locations/usages', 'Microsoft.Compute/locations/usages') }
        ) | ForEach-Object {
            $_.FullName = Join-Path $repoRoot "src/queries/catalog/$($_.Name)"
            $_
        }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $appNames = @('Recommendations', 'Quota')
        $queryFileCount = @($appNames | ForEach-Object { Get-ChildItem -Path (Join-Path $repoRoot "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/$_/queries") -Filter '*.json' }).Count
        $schemaFileCount = @($appNames | ForEach-Object { Get-ChildItem -Path (Join-Path $repoRoot "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/$_/schemas") -Filter '*.json' }).Count
        $queryObjects = @($appNames | ForEach-Object {
                $appName = $_
                Get-ChildItem -Path (Join-Path $repoRoot "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/$appName/queries") -Filter '*.json' | ForEach-Object {
                    [pscustomobject]@{
                        AppName = $appName
                        Query   = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                    }
                }
            })
        $knownEngines = @('ResourceGraph', 'AzureResourceManager')
        $requiredQueryFields = @('dataset', 'provider', 'query', 'queryEngine', 'scope', 'source', 'type', 'version')
        $forbiddenQueryFields = @('queryDefinition', 'method', 'headers', 'body', 'authority', 'authenticationResource')

        # Derive known groups from Recommendations/app.bicep parameters.
        # Non-core groups need a corresponding "enable{Group}Recommendations" bool parameter in app.bicep.
        $appBicepPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/app.bicep'
        $appBicepContent = Get-Content -Path $appBicepPath -Raw
        $recommendationGroups = @('core') + @([regex]::Matches($appBicepContent, 'param enable(\w+)Recommendations bool') | ForEach-Object { $_.Groups[1].Value.ToLower() })

        $ingestionQueriesContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/IngestionQueries/app.bicep') -Raw
        $argEngineContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceGraph/app.bicep') -Raw
        $armEngineContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceManager/app.bicep') -Raw
        $settingsContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/settings.json') -Raw
        $rawTablesContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_RawTables.kql') -Raw
        $ingestionSetupContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_0.kql') -Raw
        $ingestionSetupV12Content = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql') -Raw
        $hubSetupContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/HubSetup_v1_0.kql') -Raw
        $hubLatestContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/HubSetup_Latest.kql') -Raw
        $mainTemplateContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/main.bicep') -Raw
        $hubModuleContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/hub.bicep') -Raw
        $deploymentScriptContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/fx/hub-deploymentScript.bicep') -Raw
        $portal = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/createUiDefinition.json') -Raw | ConvertFrom-Json
        $buildScriptContent = Get-Content -Path (Join-Path $repoRoot 'src/scripts/Build-HubIngestionQueries.ps1') -Raw
        $savingsPlanCatalogContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/catalog/savings-plan-recommendation-breakdown.kql') -Raw
        $quotaCatalogFileNames = @(
            'quota-app-service-usage.kql'
            'quota-availability-zone-mappings.kql'
            'quota-capacity-reservations.kql'
            'quota-cognitive-services-usage.kql'
            'quota-compute-resource-skus.kql'
            'quota-compute-usage.kql'
            'quota-premium-ssd-v2-disks.kql'
            'quota-sql-subscription-usage.kql'
            'quota-storage-usage.kql'
        )
        $quotaCatalogColumns = @(
            'ProviderName'
            'ResourceId'
            'ResourceName'
            'ResourceType'
            'SubAccountId'
            'displayName'
            'location'
            'currentValue'
            'limit'
            'unit'
            'x_QuotaDetails'
            'x_SourceType'
            'x_SourceVersion'
            'x_IngestionTime'
        )
    }

    Context 'Query files' {

        It 'Should have at least one query file' {
            $queryFileCount | Should -BeGreaterThan 0
        }

        It 'Should be valid JSON: <Name>' -ForEach $queryFiles {
            { Get-Content -Path $FullName -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have all required fields: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($field in $requiredQueryFields)
            {
                $json.PSObject.Properties.Name | Should -Contain $field -Because "query file '$Name' is missing required field '$field'"
            }
        }

        It 'Should not have empty fields: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($field in $requiredQueryFields)
            {
                $json.$field | Should -Not -BeNullOrEmpty -Because "field '$field' in '$Name' should not be empty"
            }
        }

        It 'Should not configure ARM request behavior: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($field in $forbiddenQueryFields)
            {
                $json.PSObject.Properties.Name | Should -Not -Contain $field -Because "query file '$Name' must use the engine's fixed request behavior"
            }
        }

        It 'Should use a known query engine: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.queryEngine | Should -BeIn $knownEngines -Because "queryEngine '$($json.queryEngine)' in '$Name' is not a known engine ($($knownEngines -join ', '))"
        }

        It 'Should match naming convention: <Name>' -ForEach $queryFiles {
            $Name | Should -Match '^[A-Za-z]+-[A-Za-z]+-[A-Za-z0-9-]+\.json$' -Because "query file '$Name' should follow the '{Dataset}-{Provider}-{Name}.json' naming convention"
        }

        It 'Should use a known query group: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $group = if ($json.PSObject.Properties['group'] -and $json.group) { $json.group } else { 'core' }
            $knownGroups = if ($AppName -eq 'Recommendations') { $recommendationGroups } else { @('core') }
            $group | Should -BeIn $knownGroups -Because "query group '$group' in '$Name' is not a known group ($($knownGroups -join ', '))."
        }

        It 'Should be consistent with dataset field: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $expectedPrefix = "$($json.dataset)-"
            $BaseName | Should -BeLike "$expectedPrefix*" -Because "file name '$Name' should start with dataset '$($json.dataset)-'"
        }
    }

    Context 'Schema files' {

        It 'Should have at least one schema file' {
            $schemaFileCount | Should -BeGreaterThan 0
        }

        It 'Should be valid JSON: <Name>' -ForEach $schemaFiles {
            { Get-Content -Path $FullName -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have a translator property: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'translator'
        }

        It 'Should have translator mappings: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.translator.PSObject.Properties.Name | Should -Contain 'mappings'
            $json.translator.mappings.Count | Should -BeGreaterThan 0
        }

        It 'Should be TabularTranslator type: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $json.translator.type | Should -Be 'TabularTranslator'
        }

        It 'Should have source and sink in mappings: <Name>' -ForEach $schemaFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            foreach ($mapping in $json.translator.mappings)
            {
                $mapping.PSObject.Properties.Name | Should -Contain 'source' -Because 'each mapping needs a source'
                $mapping.PSObject.Properties.Name | Should -Contain 'sink' -Because 'each mapping needs a sink'
                $mapping.source.path | Should -Not -BeNullOrEmpty -Because 'source path should not be empty'
                ($mapping.sink.name -or $mapping.sink.path) | Should -BeTrue -Because 'sink name or path should not be empty'
            }
        }

        It 'Should use sink.name for new ARM tabular schemas: <Name>' -ForEach ($schemaFiles | Where-Object { $_.Name -in @('recommendations_1.1.json', 'quota_1.0-capacity-reservation.json', 'quota_1.0-compute-sku.json', 'quota_1.0-disk.json', 'quota_1.0-sql.json', 'quota_1.0-usage.json', 'quota_1.0-zone-mapping.json') }) {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            @($json.translator.mappings | Where-Object { -not $_.sink.name -or $_.sink.path }).Count | Should -Be 0
        }

        It 'Should construct quota details in KQL instead of the REST translator: <Name>' -ForEach ($schemaFiles | Where-Object { $_.AppName -eq 'Quota' }) {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            @($json.translator.mappings | Where-Object { $_.sink.name -eq 'x_QuotaDetails' }).Count | Should -Be 0
        }

        It 'Should not map one REST source path more than once: <Name>' -ForEach ($schemaFiles | Where-Object { $_.Name -in @('recommendations_1.1.json', 'quota_1.0-capacity-reservation.json', 'quota_1.0-compute-sku.json', 'quota_1.0-disk.json', 'quota_1.0-sql.json', 'quota_1.0-usage.json', 'quota_1.0-zone-mapping.json') }) {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $sourcePaths = @($json.translator.mappings | ForEach-Object { $_.source.path })
            @($sourcePaths | Group-Object | Where-Object { $_.Count -gt 1 }).Count | Should -Be 0
        }

        It 'Should define sink types for empty Savings Plan responses' -ForEach ($schemaFiles | Where-Object { $_.Name -eq 'recommendations_1.1.json' }) {
            $schema = Get-Content -Path $FullName -Raw | ConvertFrom-Json

            @($schema.translator.mappings | Where-Object { -not $_.sink.type }).Count | Should -Be 0
            @($schema.translator.mappings | Where-Object { $_.sink.name -in @('x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings') -and $_.sink.type -ne 'Double' }).Count | Should -Be 0
            @($schema.translator.mappings | Where-Object { $_.sink.name -notin @('x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings') -and $_.sink.type -ne 'String' }).Count | Should -Be 0
        }

        It 'Should define sink types for empty SQL responses' -ForEach ($schemaFiles | Where-Object { $_.Name -eq 'quota_1.0-sql.json' }) {
            $schema = Get-Content -Path $FullName -Raw | ConvertFrom-Json

            @($schema.translator.mappings | Where-Object { -not $_.sink.type }).Count | Should -Be 0
            ($schema.translator.mappings | Where-Object { $_.sink.name -eq 'currentValue' }).sink.type | Should -Be 'Double'
            ($schema.translator.mappings | Where-Object { $_.sink.name -eq 'limit' }).sink.type | Should -Be 'Double'
            @($schema.translator.mappings | Where-Object { $_.sink.name -notin @('currentValue', 'limit') -and $_.sink.type -ne 'String' }).Count | Should -Be 0
        }

        It 'Should define the ResourceId sink type for usage responses without IDs' -ForEach ($schemaFiles | Where-Object { $_.Name -eq 'quota_1.0-usage.json' }) {
            $schema = Get-Content -Path $FullName -Raw | ConvertFrom-Json

            ($schema.translator.mappings | Where-Object { $_.sink.name -eq 'ResourceId' }).sink.type | Should -Be 'String'
        }
    }

    Context 'Query-to-schema consistency' {

        It 'Should have a matching schema file: <Name>' -ForEach $queryFiles {
            $json = Get-Content -Path $FullName -Raw | ConvertFrom-Json
            $expectedSchemaName = "$($json.dataset.ToLower())_$($json.version).json"
            $SchemaFileNames | Should -Contain $expectedSchemaName -Because "query '$Name' references dataset '$($json.dataset)' version '$($json.version)' but no schema file '$expectedSchemaName' exists"
        }
    }

    Context 'Template boundaries' {

        It 'Should rerun storage deployment scripts when files change' {
            $deploymentScriptContent | Should -Match 'param forceUpdateTag string = utcNow\(\)'
        }

        It 'Should run ingestion queries every four hours' {
            $ingestionQueriesContent | Should -Match "(?s)frequency: 'Hour'\s+interval: 4"
            $deploymentScriptContent | Should -Match 'forceUpdateTag: forceUpdateTag'
        }

        It 'Should keep one shared query loop without engine-specific routing' {
            [regex]::Matches($ingestionQueriesContent, "name: 'Loop Thru Queries'").Count | Should -Be 1
            $ingestionQueriesContent | Should -Not -Match 'pipeline_(AzureResourceManager|ResourceGraph)'
        }

        It 'Should match managed export query concurrency limits' {
            $ingestionQueriesContent | Should -Match 'batchCount: app\.hub\.options\.privateRouting \? 4 : 30'
        }

        It 'Should publish a manifest only for the current Parquet output' {
            $ingestionQueriesContent | Should -Match "(?s)name: 'Check If Data Was Written'.*?'childItems'"
            $ingestionQueriesContent | Should -Match 'output\.childItems.*pipeline\(\)\.parameters\.ingestionId.*pipeline\(\)\.parameters\.queryType'
        }

        It 'Should keep the ARM engine as one GET Copy with native paging' {
            [regex]::Matches($armEngineContent, "type: 'Copy'").Count | Should -Be 1
            $armEngineContent | Should -Match "requestMethod: 'GET'"
            $armEngineContent | Should -Match "AbsoluteUrl: '\$\.nextLink'"
            $armEngineContent | Should -Not -Match 'additionalColumns|requestBody|additionalHeaders|queryDefinition'
            $armEngineContent | Should -Not -Match "type: 'Until'"
        }

        It 'Should pass queryScope through the shared engine contract' {
            $ingestionQueriesContent | Should -Match '"queryScope":"'
            $argEngineContent | Should -Match '(?s)queryScope:\s*\{\s*type:\s*''String'''
            $armEngineContent | Should -Match '(?s)queryScope:\s*\{\s*type:\s*''String'''
        }

        It 'Should not add subscription scopes to settings' {
            $settingsContent | Should -Not -Match '"subscriptions"\s*:'
        }

        It 'Should normalize the configured billing scope loader without expected activity failures' {
            $armEngineContent | Should -Match "name: 'Get Config'"
            $armEngineContent | Should -Match "name: 'Set Scopes'"
            $armEngineContent | Should -Match "name: 'Filter Invalid Scopes'"
            $armEngineContent | Should -Match 'dataset_config\.name'
            $armEngineContent | Should -Match 'microsoft\.billing'
            $armEngineContent | Should -Match ([regex]::Escape("@if(startswith(string(activity(\'Get Config\').output.firstRow.scopes), \'[\'), activity(\'Get Config\').output.firstRow.scopes, createArray(activity(\'Get Config\').output.firstRow.scopes))"))
            $armEngineContent | Should -Not -Match "name: 'Set Scopes as Array'"
            $armEngineContent | Should -Not -Match 'billingScopes'
        }

        It 'Should use fixed tenant and physical region discovery' {
            $armEngineContent | Should -Match 'subscriptions\?api-version=2022-12-01'
            $armEngineContent | Should -Match 'locations\?api-version=2022-12-01'
            $armEngineContent | Should -Match 'providers/.+api-version=2021-04-01'
            $armEngineContent | Should -Match 'item\(\)\.state'
            $armEngineContent | Should -Match 'item\(\)\.metadata\.regionType'
            $armEngineContent | Should -Match 'Filter Provider Resource Type'
            $armEngineContent | Should -Match 'item\(\)\.displayName'
            $armEngineContent | Should -Match '\{location\}'
        }

        It 'Should use the copied parallel child pipeline boundary' {
            [regex]::Matches($armEngineContent, "type: 'ForEach'").Count | Should -Be 3
            [regex]::Matches($armEngineContent, 'batchCount: app\.hub\.options\.privateRouting \? 4 : 30').Count | Should -Be 3
            $armEngineContent | Should -Not -Match 'concurrency:\s+1'
            $armEngineContent | Should -Match "(?s)type: 'ForEach'.*?activities: \[\s*\{\s*name: 'Execute"
            $armEngineContent | Should -Match 'waitOnCompletion: true'
        }

        It 'Should preserve request context in the output identity' {
            $armEngineContent | Should -Match 'parameters\.queryScope'
            $armEngineContent | Should -Match 'parameters\.queryLocation'
            $armEngineContent | Should -Match 'parameters\.queryVersion'
            $armEngineContent | Should -Match ([regex]::Escape("pipeline().parameters.queryType, \'--\', pipeline().parameters.queryVersion, \'--\', replace(pipeline().parameters.queryScope, \'/\', \'_\'), \'--\', pipeline().parameters.queryLocation"))
        }

        It 'Should not dispatch on query metadata' {
            [regex]::Matches($armEngineContent, 'queryDataset').Count | Should -Be 1
            [regex]::Matches($armEngineContent, 'queryProvider').Count | Should -Be 1
            [regex]::Matches($armEngineContent, 'queryEngine').Count | Should -Be 1
            [regex]::Matches($armEngineContent, 'querySource').Count | Should -Be 1
            $armEngineContent | Should -Not -Match "type: 'Switch'"
        }
    }

    Context 'Savings Plan and quota contracts' {

        It 'Should define both unfiltered Savings Plan terms on configured billing scopes' {
            $savingsPlanQueries = @($queryObjects | Where-Object { $_.AppName -eq 'Recommendations' -and $_.Query.type -like 'Microsoft-SavingsPlan-*' })

            $savingsPlanQueries.Count | Should -Be 2
            @($savingsPlanQueries.Query.query | Where-Object { $_ -match 'armSkuName' }).Count | Should -Be 0
            @($savingsPlanQueries.Query.query | Where-Object { $_ -match "term eq 'P1Y'" }).Count | Should -Be 1
            @($savingsPlanQueries.Query.query | Where-Object { $_ -match "term eq 'P3Y'" }).Count | Should -Be 1
            @($savingsPlanQueries.Query.scope | Sort-Object -Unique) | Should -Be @('Configured')
            @($savingsPlanQueries.Query.queryEngine | Sort-Object -Unique) | Should -Be @('AzureResourceManager')
        }

        It 'Should derive the Savings Plan recommendation ID from the single mapped ARM ID' {
            $ingestionSetupV12Content | Should -Match 'x_RecommendationId = coalesce\(x_RecommendationId, ResourceId\)'
        }

        It 'Should derive the Savings Plan benefit type from the documented ARM SKU name' {
            $savingsPlanCatalogContent | Should -Match 'BenefitType = replace_regex\(tostring\(x_RecommendationDetails\.x_ArmSkuName\)'
            $savingsPlanCatalogContent | Should -Not -Match 'x_RecommendationType'
        }

        It 'Should define the nine approved GET-only quota queries' {
            $quotaQueries = @($queryObjects | Where-Object { $_.AppName -eq 'Quota' })

            $quotaQueries.Count | Should -Be 9
            @($quotaQueries.Query.type | Sort-Object) | Should -Be @(
                'AppServiceUsage'
                'AvailabilityZoneMapping'
                'CapacityReservation'
                'CognitiveServicesUsage'
                'ComputeResourceSku'
                'ComputeUsage'
                'PremiumSSDv2Disk'
                'SqlSubscriptionUsage'
                'StorageUsage'
            )
            @($quotaQueries.Query.queryEngine | Sort-Object -Unique) | Should -Be @('AzureResourceManager')
            @($quotaQueries.Query.scope | Sort-Object -Unique) | Should -Be @('Tenant')
            @($quotaQueries.Query.query | Where-Object { $_ -notmatch '^/(providers/|locations\?)' }).Count | Should -Be 0
        }

        It 'Should define only the nine approved type-specific quota catalog files' {
            $catalogPath = Join-Path $repoRoot 'src/queries/catalog'
            $aggregateFiles = @('quota-current-usage.kql', 'quota-headroom.kql')
            $actualFiles = @(Get-ChildItem -Path $catalogPath -Filter 'quota-*.kql' |
                Where-Object { $_.Name -notin $aggregateFiles } |
                Select-Object -ExpandProperty Name |
                Sort-Object)
            $expectedFiles = @($quotaCatalogFileNames | Sort-Object)

            $actualFiles | Should -Be $expectedFiles
        }

        It 'Should rehydrate the intended resource contract in <Name>' -ForEach $quotaCatalogContracts {
            Test-Path $FullName | Should -BeTrue
            $content = Get-Content -Path $FullName -Raw

            foreach ($sourceType in $SourceTypes)
            {
                $content | Should -Match ([regex]::Escape("x_SourceType =~ '$sourceType'"))
            }
            foreach ($resourceType in $ResourceTypes)
            {
                $content | Should -Match ([regex]::Escape("ResourceType =~ '$resourceType'"))
            }
            $content | Should -Match 'ResourceName'
            $content | Should -Match '\| summarize arg_max\(x_IngestionTime, \*\) by ResourceId'
            $content | Should -Not -Match 'PostgreSQL'

            foreach ($column in $quotaCatalogColumns)
            {
                $content | Should -Match "(?m)^\s+$column,?\r?$" -Because "quota catalog query '$Name' should project '$column'"
            }
        }

        It 'Should separate Compute quota from Storage quota by resource name' {
            $computeContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/catalog/quota-compute-usage.kql') -Raw
            $storageContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/catalog/quota-storage-usage.kql') -Raw

            $computeContent | Should -Match ([regex]::Escape("ResourceName endswith 'Family'"))
            $computeContent | Should -Match ([regex]::Escape("ResourceName in~ ('cores', 'lowPriorityCores', 'dedicatedVCpus')"))
            $computeContent | Should -Not -Match '(?i)disk|snapshot'
            $storageContent | Should -Match ([regex]::Escape("ResourceName =~ 'StorageAccounts'"))
            $storageContent | Should -Match 'isnotempty\(location\)'
            $storageContent | Should -Match ([regex]::Escape("ResourceName matches regex '(?i)(disk|snapshot)'"))
        }

        It 'Should limit quota schemas to the approved public raw fields' {
            $quotaRawFields = @(
                'ProviderName'
                'ResourceId'
                'ResourceName'
                'ResourceType'
                'SubAccountId'
                'displayName'
                'location'
                'currentValue'
                'limit'
                'unit'
                'x_QuotaDetails'
                'x_SourceName'
                'x_SourceProvider'
                'x_SourceType'
                'x_SourceVersion'
                'x_AvailabilityZoneMappings'
                'x_Capabilities'
                'x_Family'
                'x_Kind'
                'x_LocationInfo'
                'x_LocationMetadata'
                'x_Locations'
                'x_RegionalDisplayName'
                'x_Restrictions'
                'x_Size'
                'x_Tier'
            )

            foreach ($schemaFile in ($schemaFiles | Where-Object { $_.AppName -eq 'Quota' }))
            {
                $schema = Get-Content -Path $schemaFile.FullName -Raw | ConvertFrom-Json
                @($schema.translator.mappings | Where-Object { $_.sink.name -notin $quotaRawFields }).Count | Should -Be 0
            }
        }

        It 'Should define the exact quota raw and final table boundaries' {
            $rawColumns = [regex]::Match($rawTablesContent, '(?s)// Quota_raw table -- Redefine all columns\s+\.alter table Quota_raw \((.*?)\)\s+// Quota_raw ingestion mapping').Groups[1].Value
            $finalColumns = [regex]::Match($ingestionSetupContent, '(?s)// Quota_final_v1_0 table\s+\.create-merge table Quota_final_v1_0 \((.*?)\)\s+// Update policy').Groups[1].Value

            [regex]::Matches($rawColumns, '(?m)^\s+\w+\s*:').Count | Should -Be 26
            [regex]::Matches($finalColumns, '(?m)^\s+\w+\s*:').Count | Should -Be 16
            $ingestionSetupContent | Should -Match 'Quota_transform_v1_0\(\)'
            $ingestionSetupContent | Should -Match 'extent_tags\(\)'
            $ingestionSetupContent | Should -Match 'bag_pack\('
            $ingestionSetupContent | Should -Match "x_SourceType !~ 'PremiumSSDv2Disk' or displayName =~ 'PremiumV2_LRS'"
            $ingestionSetupContent | Should -Match "x_SourceType =~ 'AppServiceUsage'"
            $ingestionSetupContent | Should -Match "x_SourceType =~ 'StorageUsage'"
            $ingestionSetupContent | Should -Match ([regex]::Escape("strcat(SubAccountId, '/providers/Microsoft.Compute/locations/', location, '/skus/', ResourceName)"))
            $hubSetupContent | Should -Match 'Quota_v1_0\(\)'
            $hubSetupContent | Should -Match 'ComputeQuota_v1_0\(\)'
            $hubLatestContent | Should -Match 'Quota\(\)'
            $hubLatestContent | Should -Match 'ComputeQuota\(\)'
        }

        It 'Should use the approved four-state deployment matrix' {
            $mainTemplateContent | Should -Match 'param enableQuota bool = false'
            $mainTemplateContent | Should -Match 'enableQuota: enableQuota'
            $hubModuleContent | Should -Match "module ingestionQueries .+ = if \(enableRecommendations \|\| enableQuota\)"
            $hubModuleContent | Should -Match "module azureResourceGraph .+ = if \(enableRecommendations\)"
            $hubModuleContent | Should -Match "module azureResourceManager .+ = if \(enableRecommendations \|\| enableQuota\)"
            $hubModuleContent | Should -Match "module recommendations .+ = if \(enableRecommendations\)"
            $hubModuleContent | Should -Match "module quota .+ = if \(enableQuota\)"
        }

        It 'Should expose one quota portal checkbox and output' {
            $quotaControls = @($portal.parameters.steps | ForEach-Object { $_.elements } | Where-Object { $_.name -eq 'enableQuota' })
            $quotaControls.Count | Should -Be 1
            $portal.parameters.outputs.enableQuota | Should -Be "[steps('recommendations').enableQuota]"
        }

        It 'Should describe Savings Plans and quota in the portal' {
            $recommendationsStep = $portal.parameters.steps | Where-Object { $_.name -eq 'recommendations' }
            $recommendationsStep.label | Should -Be 'Recommendations and quota'
            ($recommendationsStep.elements | Where-Object { $_.name -eq 'included' }).elements.name | Should -Contain 'savingsPlans'
            $quotaSection = $recommendationsStep.elements | Where-Object { $_.name -eq 'quota' }
            $quotaSection.visible | Should -Be "[steps('recommendations').enableQuota]"
            $quotaSection.elements.name | Should -Contain 'quotaDataTypes'
            $quotaSection.elements.name | Should -Contain 'quotaAppService'
            $quotaSection.elements.name | Should -Contain 'quotaStorage'
        }

        It 'Should invoke one query generator function for the two approved apps' {
            $buildScriptContent | Should -Match 'function Update-HubIngestionQueriesApp'
            [regex]::Matches($buildScriptContent, "-AppName '(Recommendations|Quota)'").Count | Should -Be 2
        }
    }

    Context 'Bicep compilation' {

        It 'finops-hub template should compile without errors' {
            $mainBicep = Join-Path $repoRoot 'src/templates/finops-hub/main.bicep'
            if (Get-Command 'bicep' -ErrorAction SilentlyContinue)
            {
                $result = bicep build $mainBicep --stdout 2>&1
                $LASTEXITCODE | Should -Be 0 -Because "Bicep compilation failed: $($result | Out-String)"
            }
            else
            {
                Set-ItResult -Skipped -Because 'bicep CLI not found'
            }
        }
    }
}
