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
            @{ Name = 'quota-hdinsight-usage.kql'; SourceTypes = @('HDInsightUsage'); ResourceTypes = @('Microsoft.HDInsight/locations/usages') }
            @{ Name = 'quota-machine-learning-usage.kql'; SourceTypes = @('MachineLearningUsage'); ResourceTypes = @('Microsoft.MachineLearningServices/locations/usages') }
            @{ Name = 'quota-network-usage.kql'; SourceTypes = @('NetworkUsage'); ResourceTypes = @('Microsoft.Network/locations/usages') }
            @{ Name = 'quota-premium-ssd-v2-disks.kql'; SourceTypes = @('PremiumSSDv2Disk'); ResourceTypes = @('Microsoft.Compute/disks') }
            @{ Name = 'quota-purview-usage.kql'; SourceTypes = @('PurviewUsage'); ResourceTypes = @('Microsoft.Purview/locations/usages') }
            @{ Name = 'quota-sql-subscription-usage.kql'; SourceTypes = @('SqlSubscriptionUsage'); ResourceTypes = @('Microsoft.Sql/locations/usages') }
            @{ Name = 'quota-storage-usage.kql'; SourceTypes = @('StorageUsage', 'ComputeUsage'); ResourceTypes = @('Microsoft.Storage/locations/usages', 'Microsoft.Compute/locations/usages') }
        ) | ForEach-Object {
            $_.FullName = Join-Path $repoRoot "src/queries/catalog/$($_.Name)"
            $_
        }
        $quotaResourceIdCases = @(
            @{
                Name             = 'Network native provider ID'
                SourceType       = 'NetworkUsage'
                NativeResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Network/locations/eastus/usages/PublicIPAddresses'
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.Network'
                Location         = 'eastus'
                ResourceName     = 'PublicIPAddresses'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/microsoft.network/locations/eastus/usages/publicipaddresses'
            }
            @{
                Name             = 'HDInsight missing ID'
                SourceType       = 'HDInsightUsage'
                NativeResourceId = $null
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.HDInsight'
                Location         = 'westus'
                ResourceName     = 'cores'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/microsoft.hdinsight/locations/westus/usages/cores'
            }
            @{
                Name             = 'Purview empty ID'
                SourceType       = 'PurviewUsage'
                NativeResourceId = ''
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.Purview'
                Location         = 'eastus2'
                ResourceName     = 'Purview-Account-Subscription'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/microsoft.purview/locations/eastus2/usages/purview-account-subscription'
            }
            @{
                Name             = 'Machine Learning bare subscription usage ID'
                SourceType       = 'MachineLearningUsage'
                NativeResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/usages'
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.MachineLearningServices'
                Location         = 'eastus'
                ResourceName     = 'StandardDSv2Family'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/microsoft.machinelearningservices/locations/eastus/usages/standarddsv2family'
            }
            @{
                Name             = 'Machine Learning named subscription usage ID'
                SourceType       = 'MachineLearningUsage'
                NativeResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/usages/StandardDSv2Family'
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.MachineLearningServices'
                Location         = 'westus2'
                ResourceName     = 'StandardDSv2Family'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/microsoft.machinelearningservices/locations/westus2/usages/standarddsv2family'
            }
            @{
                Name             = 'Machine Learning workspace ID'
                SourceType       = 'MachineLearningUsage'
                NativeResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.MachineLearningServices/workspaces/ws/usages/StandardDSv2Family'
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.MachineLearningServices'
                Location         = 'eastus'
                ResourceName     = 'StandardDSv2Family'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/rg/providers/microsoft.machinelearningservices/workspaces/ws/usages/standarddsv2family'
            }
            @{
                Name             = 'Machine Learning compute ID'
                SourceType       = 'MachineLearningUsage'
                NativeResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.MachineLearningServices/workspaces/ws/computes/cpu-cluster/usages/StandardDSv2Family'
                QueryScope       = '/subscriptions/11111111-1111-1111-1111-111111111111'
                Provider         = 'Microsoft.MachineLearningServices'
                Location         = 'westus2'
                ResourceName     = 'StandardDSv2Family'
                Expected         = '/subscriptions/11111111-1111-1111-1111-111111111111/resourcegroups/rg/providers/microsoft.machinelearningservices/workspaces/ws/computes/cpu-cluster/usages/standarddsv2family'
            }
        )
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
        $quotaAppBicepContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota/app.bicep') -Raw

        $ingestionQueriesContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/IngestionQueries/app.bicep') -Raw
        $queryCoordinatorPipelineContent = [regex]::Match($ingestionQueriesContent, '(?s)resource pipeline_ExecuteQueries .*?(?=\r?\nresource pipeline_ExecuteQueries_query)').Value
        $queryWorkerPipelineContent = [regex]::Match($ingestionQueriesContent, '(?s)resource pipeline_ExecuteQueries_query .*?(?=\r?\n//==============================================================================\r?\n// Outputs)').Value
        $argEngineContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceGraph/app.bicep') -Raw
        $armEngineContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceManager/app.bicep') -Raw
        $armConfiguredScopesPipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_ExecuteConfiguredScopes.*?(?=\r?\nresource pipeline_ExecuteSubscriptionPage)').Value
        $armSubscriptionPagePipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_ExecuteSubscriptionPage.*?(?=\r?\nresource pipeline_ExecuteTenant)').Value
        $armTenantPipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_ExecuteTenant.*?(?=\r?\nresource pipeline_ExecuteSubscription)').Value
        $armLocationPagePipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_ExecuteLocationPage.*?(?=\r?\nresource pipeline_ExecuteRegional)').Value
        $armRegionalPipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_ExecuteRegional.*?(?=\r?\n\r?\n//------------------------------------------------------------------------------\r?\n// Request Copy pipeline)').Value
        $armCopyPipelineContent = [regex]::Match($armEngineContent, '(?s)resource pipeline_CopyQuery.*?(?=\r?\n\r?\n//==============================================================================)').Value
        $armRawCopyActivityContent = [regex]::Match($armCopyPipelineContent, "(?s)name: 'Copy Raw ARM Page'.*?(?=\r?\n\s+name: 'Clear ARM Request Failure')").Value
        $quotaUsageSchemaContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota/schemas/quota_1.0-usage.json') -Raw
        $settingsContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/settings.json') -Raw
        $rawTablesContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_RawTables.kql') -Raw
        $ingestionSetupContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_0.kql') -Raw
        $ingestionSetupV12Content = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql') -Raw
        $hubSetupContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/HubSetup_v1_0.kql') -Raw
        $hubLatestContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/HubSetup_Latest.kql') -Raw
        $mainTemplateContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/main.bicep') -Raw
        $hubModuleContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/hub.bicep') -Raw
        $armHubModuleContent = [regex]::Match($hubModuleContent, '(?ms)^module azureResourceManager .*?^\}').Value
        $deploymentScriptContent = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/modules/fx/hub-deploymentScript.bicep') -Raw
        $portal = Get-Content -Path (Join-Path $repoRoot 'src/templates/finops-hub/createUiDefinition.json') -Raw | ConvertFrom-Json
        $buildScriptContent = Get-Content -Path (Join-Path $repoRoot 'src/scripts/Build-HubIngestionQueries.ps1') -Raw
        $savingsPlanCatalogContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/catalog/savings-plan-recommendation-breakdown.kql') -Raw
        $queryIndexContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/INDEX.md') -Raw
        $quotaGuideContent = Get-Content -Path (Join-Path $repoRoot 'src/queries/finops-hub-database-guide.md') -Raw
        $machineLearningSubscriptionUsageIdPattern = [regex]::Match(
            $ingestionSetupContent,
            "ResourceId matches regex '([^']+)'"
        ).Groups[1].Value
        $quotaCatalogFileNames = @(
            'quota-app-service-usage.kql'
            'quota-availability-zone-mappings.kql'
            'quota-capacity-reservations.kql'
            'quota-cognitive-services-usage.kql'
            'quota-compute-resource-skus.kql'
            'quota-compute-usage.kql'
            'quota-hdinsight-usage.kql'
            'quota-machine-learning-usage.kql'
            'quota-network-usage.kql'
            'quota-premium-ssd-v2-disks.kql'
            'quota-purview-usage.kql'
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

        function Get-CanonicalQuotaResourceId
        {
            param(
                [string] $SourceType,
                [AllowNull()]
                [AllowEmptyString()]
                [string] $NativeResourceId,
                [string] $QueryScope,
                [string] $Provider,
                [string] $Location,
                [string] $ResourceName,
                [string] $MachineLearningSubscriptionUsageIdPattern
            )

            $fallbackResourceId = "$QueryScope/providers/$Provider/locations/$Location/usages/$ResourceName".ToLowerInvariant()
            if ($SourceType -eq 'MachineLearningUsage' -and $NativeResourceId -match $MachineLearningSubscriptionUsageIdPattern)
            {
                return $fallbackResourceId
            }
            if ([string]::IsNullOrEmpty($NativeResourceId))
            {
                return $fallbackResourceId
            }
            return $NativeResourceId.ToLowerInvariant()
        }
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

        It 'Should lifecycle-own Azure Resource Manager query execution' {
            [regex]::Matches($ingestionQueriesContent, "name: 'Loop Thru Queries'").Count | Should -Be 1
            $queryWorkerPipelineContent | Should -Match "(?s)name: 'Run Query Engine Pipeline'.*?type: 'IfCondition'.*?equals\(toLower\(pipeline\(\)\.parameters\.queryEngine\), \\'azureresourcemanager\\'\)"
            $queryWorkerPipelineContent | Should -Match "(?s)name: 'Execute Azure Resource Manager Query'.*?type: 'ExecutePipeline'.*?referenceName: 'queries_AzureResourceManager_ExecuteQuery'.*?waitOnCompletion: true"
            $queryWorkerPipelineContent | Should -Match "(?s)name: 'Check ARM Query Staging'.*?activity: 'Run Query Engine Pipeline'.*?'Succeeded'"
            $queryWorkerPipelineContent | Should -Not -Match "(?s)ifTrueActivities:.*?/createRun\?api-version=2018-06-01.*?ifFalseActivities:"
        }

        It 'Should admit work only at the root and CopyQuery pipeline boundaries' {
            $queryCoordinatorPipelineContent | Should -Match 'properties:\s*\{\s*concurrency:\s+1'
            $queryCoordinatorPipelineContent | Should -Match "(?s)name: 'Loop Thru Queries'.*?batchCount: 50"
            $queryWorkerPipelineContent | Should -Match "(?s)name: 'Delete Old Files Loop'.*?batchCount: 50"
            $armConfiguredScopesPipelineContent | Should -Match "(?s)name: 'ForEach Scope'.*?batchCount: 50"
            $armSubscriptionPagePipelineContent | Should -Match "(?s)name: 'ForEach Subscription'.*?batchCount: 50"
            $armLocationPagePipelineContent | Should -Match "(?s)name: 'ForEach Location'.*?batchCount: 50"
            $armCopyPipelineContent | Should -Match 'properties:\s*\{\s*concurrency: app\.hub\.options\.privateRouting \? 4 : 30'
            $queryCoordinatorPipelineContent | Should -Not -Match 'batchCount: (20|30|4)'
            $queryWorkerPipelineContent | Should -Not -Match 'batchCount: (20|30|4)'
            $armConfiguredScopesPipelineContent | Should -Not -Match 'batchCount: (20|30|4)'
            $armSubscriptionPagePipelineContent | Should -Not -Match 'batchCount: (20|30|4)'
            $armLocationPagePipelineContent | Should -Not -Match 'batchCount: (20|30|4)'
        }

        It 'Should synchronously drain each subscription page before following nextLink' {
            $armTenantPipelineContent | Should -Match "(?s)name: 'Read Subscription Pages'.*?type: 'Until'.*?@empty\(variables\(\\'subscriptionPageUrl\\'\)\)"
            $armTenantPipelineContent | Should -Match "(?s)name: 'Get Subscription Page'.*?type: 'WebActivity'.*?retry: 2.*?retryIntervalInSeconds: 30"
            $armTenantPipelineContent | Should -Match ([regex]::Escape("@activity(\'Get Subscription Page\').output.value"))
            $armTenantPipelineContent | Should -Match "(?s)name: 'Execute Subscription Page'.*?referenceName: pipeline_ExecuteSubscriptionPage\.name.*?waitOnCompletion: true"
            $armTenantPipelineContent | Should -Match "(?s)name: 'Set Next Subscription Page URL'.*?activity: 'Execute Subscription Page'.*?'Succeeded'.*?output\.nextLink"
            $armTenantPipelineContent | Should -Match "(?s)name: 'Capture Subscription Dispatch Failure'.*?activity: 'Execute Subscription Page'.*?'Failed'"
            $armTenantPipelineContent | Should -Match "(?s)name: 'Rethrow Subscription Page Failure'.*?activity: 'Read Subscription Pages'.*?'Succeeded'"
            $armTenantPipelineContent | Should -Match "(?s)name: 'Rethrow Subscription Page Loop Failure'.*?activity: 'Read Subscription Pages'.*?'Failed'"
            $armTenantPipelineContent | Should -Not -Match "type: 'Lookup'|Subscription Inventory|_ftk-query-subscriptions"
            $armSubscriptionPagePipelineContent | Should -Match ([regex]::Escape("@pipeline().parameters.subscriptions"))
            $armSubscriptionPagePipelineContent | Should -Match 'batchCount: 50'
        }

        It 'Should synchronously drain each location page before following nextLink' {
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Read Location Pages'.*?type: 'Until'.*?@empty\(variables\(\\'locationPageUrl\\'\)\)"
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Get Location Page'.*?type: 'WebActivity'.*?retry: 0.*?retryIntervalInSeconds: 30"
            $armRegionalPipelineContent | Should -Match ([regex]::Escape("@activity(\'Get Location Page\').output.value"))
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Execute Location Page'.*?referenceName: pipeline_ExecuteLocationPage\.name.*?waitOnCompletion: true"
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Set Next Location Page URL'.*?activity: 'Execute Location Page'.*?'Succeeded'.*?output\.nextLink"
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Capture Location Dispatch Failure'.*?activity: 'Execute Location Page'.*?'Failed'"
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Rethrow Location Page Failure'.*?activity: 'Read Location Pages'.*?'Succeeded'"
            $armRegionalPipelineContent | Should -Match "(?s)name: 'Rethrow Location Page Loop Failure'.*?activity: 'Read Location Pages'.*?'Failed'"
            $armRegionalPipelineContent | Should -Not -Match "type: 'Lookup'"
            $armLocationPagePipelineContent | Should -Match ([regex]::Escape("@pipeline().parameters.locations"))
            $armLocationPagePipelineContent | Should -Match ([regex]::Escape("pipeline().parameters.supportedLocations"))
            $armLocationPagePipelineContent | Should -Match 'batchCount: 50'
        }

        It 'Should preserve page order beyond the Lookup row limit' {
            $pages = @(
                @{ Value = 1..2500; NextLink = 'page-2' }
                @{ Value = 2501..5000; NextLink = 'page-3' }
                @{ Value = 5001..6001; NextLink = '' }
            )
            $processed = [System.Collections.Generic.List[int]]::new()
            $largestBufferedPage = 0

            foreach ($page in $pages)
            {
                $largestBufferedPage = [math]::Max($largestBufferedPage, $page.Value.Count)
                $processed.AddRange([int[]] $page.Value)
            }

            $processed.Count | Should -Be 6001
            $processed[0] | Should -Be 1
            $processed[-1] | Should -Be 6001
            @(Compare-Object $processed (1..6001)).Count | Should -Be 0
            $largestBufferedPage | Should -Be 2500
        }

        It 'Should publish a manifest only for the current Parquet output' {
            $ingestionQueriesContent | Should -Match "(?s)name: 'Check If Data Was Written'.*?'childItems'"
            $ingestionQueriesContent | Should -Match 'output\.childItems.*pipeline\(\)\.parameters\.ingestionId.*pipeline\(\)\.parameters\.queryType'
        }

        It 'Should derive data and continuation metadata from one stored response' {
            [regex]::Matches($armCopyPipelineContent, "type: 'Copy'").Count | Should -Be 3
            [regex]::Matches($armCopyPipelineContent, "type: 'RestSource'").Count | Should -Be 1
            [regex]::Matches($armCopyPipelineContent, "requestMethod: 'GET'").Count | Should -Be 1
            [regex]::Matches($armCopyPipelineContent, "type: 'JsonSource'").Count | Should -Be 2
            $armCopyPipelineContent | Should -Match "name: 'Read ARM Pages'"
            $armCopyPipelineContent | Should -Match "type: 'Until'"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Validate Page URL'.*?type: 'SetVariable'.*?variableName: 'rawRequestFailure'"
            $armCopyPipelineContent | Should -Not -Match "name: 'Reject Unsafe Page URL'"
            $armCopyPipelineContent | Should -Match 'UnsafeArmContinuation'
            $armCopyPipelineContent | Should -Match ([regex]::Escape("startswith(toLower(variables(\'requestUrl\')), toLower(\'`$`{environment().resourceManager`}\'))"))
            $armCopyPipelineContent | Should -Match "name: 'Copy Raw ARM Page'"
            $armRawCopyActivityContent | Should -Match "(?s)policy:\s*\{\s*timeout: '0\.00:02:30'\s*retry: 0\s*retryIntervalInSeconds: 60"
            [regex]::Matches($armRawCopyActivityContent, 'retry:\s+\d+').Count | Should -Be 1
            $armCopyPipelineContent | Should -Match "name: 'Copy Page Metadata'"
            $armCopyPipelineContent | Should -Match ([regex]::Escape("path: '`$[\'nextLink\']'"))
            $armCopyPipelineContent | Should -Match "name: 'Lookup Page Metadata'"
            $armCopyPipelineContent | Should -Match ([regex]::Escape("activity(\'Lookup Page Metadata\').output.firstRow.nextLink"))
            $armCopyPipelineContent | Should -Match "(?s)name: 'Copy Raw ARM Page'.*?activity: 'Set Page Metadata Path'"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Copy Page Metadata'.*?activity: 'Reset ARM Request Attempts'"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Copy ARM Page'.*?activity: 'Lookup Page Metadata'"
            [regex]::Matches($armCopyPipelineContent, 'dataset_msexports_manifest\.name').Count | Should -Be 3
            $armCopyPipelineContent | Should -Not -Match "type: 'WebActivity'"
            $armCopyPipelineContent | Should -Not -Match "AbsoluteUrl: '\$\.nextLink'"
            $armCopyPipelineContent | Should -Not -Match 'paginationRules'
            $armCopyPipelineContent | Should -Not -Match 'additionalColumns|requestBody|additionalHeaders|queryDefinition'
        }

        It 'Should avoid retrying expected no-data and retry only transient ARM failures' {
            $armCopyPipelineContent | Should -Match "(?s)name: 'Capture ARM Request Failure'.*?activity: 'Copy Raw ARM Page'.*?'Failed'"
            $armCopyPipelineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'/providers/Microsoft.Network/locations/\')"))
            $armCopyPipelineContent | Should -Match 'status code 409 Conflict'
            $armCopyPipelineContent | Should -Match ([regex]::Escape('"code":"SubscriptionHasNoUsages"'))
            $armCopyPipelineContent | Should -Match 'machinelearningusage'
            $armCopyPipelineContent | Should -Match 'status code 400 badrequest'
            $armCopyPipelineContent | Should -Match 'subscriptionnotfounderror'
            $armCopyPipelineContent | Should -Match "(?s)name: 'Classify Expected Empty ARM Response'.*?is not found in quota service.*?statuscode.*?404"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Classify Transient ARM Response'.*?status code 429.*?status code 5.*?systemerror.*?timed out.*?connection reset"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Select ARM Retry URL'.*?less\(length\(variables\(\\'requestAttempts\\'\)\), 3\)"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Wait Before Transient ARM Retry'.*?@if\(empty\(variables\(\\'requestUrl\\'\)\), 0, 60\)"
            $armCopyPipelineContent | Should -Match "(?s)name: 'Rethrow ARM Request Failure'.*?activity: 'Read ARM Pages'.*?'Completed'.*?name: 'ARM Request Failed'.*?type: 'Fail'"
            $armCopyPipelineContent | Should -Match "not\(equals\(activity\(\\'Read ARM Pages\\'\)\.Status, \\'Succeeded\\'\)\)"
            $armCopyPipelineContent | Should -Match "variables\(\\'requestFailureCode\\'\)"
        }

        It 'Should provide explicit Parquet types for every usage field' {
            $schema = $quotaUsageSchemaContent | ConvertFrom-Json
            @($schema.translator.mappings | Where-Object { -not $_.sink.type }).Count | Should -Be 0
            ($schema.translator.mappings | Where-Object { $_.sink.name -in @('ResourceId', 'ResourceName', 'displayName', 'unit') }).sink.type | Should -Not -Contain $null
            ($schema.translator.mappings | Where-Object { $_.sink.name -in @('currentValue', 'limit') }).sink.type | Should -Not -Contain $null
            @($schema.translator.mappings | Where-Object { $_.sink.name -in @('ResourceId', 'ResourceName', 'displayName', 'unit') -and $_.sink.type -ne 'String' }).Count | Should -Be 0
            @($schema.translator.mappings | Where-Object { $_.sink.name -in @('currentValue', 'limit') -and $_.sink.type -ne 'Double' }).Count | Should -Be 0
        }

        It 'Should isolate and delete run-unique continuation metadata' {
            $armCopyPipelineContent | Should -Match ([regex]::Escape("_ftk-arm-pagination/\', pipeline().RunId"))
            $armCopyPipelineContent | Should -Match "guid\(\)"
            $armCopyPipelineContent | Should -Match "name: 'Delete Paging Files'"
            $armCopyPipelineContent | Should -Match 'dataset_msexports_parquet_files\.name'
            $armCopyPipelineContent | Should -Match ([regex]::Escape("@concat(\'_ftk-arm-pagination/\', pipeline().RunId)"))
            $armCopyPipelineContent | Should -Match '_ftk-query-staging/'
        }

        It 'Should pass queryScope through the shared engine contract' {
            $ingestionQueriesContent | Should -Match '"queryScope":"'
            $argEngineContent | Should -Match '(?s)queryScope:\s*\{\s*type:\s*''String'''
            $armEngineContent | Should -Match '(?s)queryScope:\s*\{\s*type:\s*''String'''
        }

        It 'Should reject unsafe ARM request inputs before dispatch' {
            $armEngineContent | Should -Match "name: 'Validate Request'"
            $armEngineContent | Should -Match "name: 'Reject Unsafe Request'"
            $armEngineContent | Should -Match 'UnsafeArmRequest'
            $armEngineContent | Should -Match "name: 'Validate Subscription ID'"
            $armEngineContent | Should -Match 'MalformedAzureResourceId'
            $armEngineContent | Should -Match ([regex]::Escape("startswith(pipeline().parameters.query, \'/\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'//\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'://\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'#\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'@\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.query, \'\\\')"))
            $armEngineContent | Should -Match ([regex]::Escape("contains(pipeline().parameters.queryScope, \'//\')"))
            $armEngineContent | Should -Match ([regex]::Escape("split(pipeline().parameters.queryScope, \'/\')"))
            $armEngineContent | Should -Match ([regex]::Escape("equals(length(split(pipeline().parameters.queryScope, \'/\')[2]), 36)"))
            $armEngineContent | Should -Match ([regex]::Escape("equals(substring(split(pipeline().parameters.queryScope, \'/\')[2], 8, 1), \'-\')"))
            $armEngineContent | Should -Match ([regex]::Escape("toLower(replace(split(pipeline().parameters.queryScope, \'/\')[2], \'-\', \'\'))"))
            $armEngineContent | Should -Match ([regex]::Escape("\'resourcegroups\'"))
            $armEngineContent | Should -Match ([regex]::Escape("\'providers\'"))
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

        It 'Should filter configured scopes by query-compatible resource type' {
            $ingestionQueriesContent | Should -Match '"queryScopeTypes":'
            $argEngineContent | Should -Match '(?s)queryScopeTypes:\s*\{\s*type:\s*''Array'''
            $armEngineContent | Should -Match '(?s)queryScopeTypes:\s*\{\s*type:\s*''Array'''
            $armEngineContent | Should -Match 'Microsoft\.Billing/billingAccounts'
            $armEngineContent | Should -Match 'Microsoft\.Billing/billingAccounts/billingProfiles'
        }

        It 'Should deploy ARM ingestion after its shared datasets' {
            $armHubModuleContent | Should -Match '(?s)dependsOn:\s*\[\s*cmExports\s+ingestionQueries\s*\]'
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

        It 'Should keep intermediate loops at maximum fan-out behind the CopyQuery boundary' {
            [regex]::Matches($armEngineContent, "type: 'ForEach'").Count | Should -Be 3
            [regex]::Matches($armEngineContent, 'batchCount: 50').Count | Should -Be 3
            [regex]::Matches($armEngineContent, 'concurrency: app\.hub\.options\.privateRouting \? 4 : 30').Count | Should -Be 1
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

        It 'Should propagate source metadata without dispatching on it' {
            [regex]::Matches($armEngineContent, 'queryDataset').Count | Should -Be 1
            [regex]::Matches($armEngineContent, 'queryEngine').Count | Should -Be 1
            [regex]::Matches($armEngineContent, 'queryProvider').Count | Should -BeGreaterThan 1
            [regex]::Matches($armEngineContent, 'querySource').Count | Should -BeGreaterThan 1
            $armEngineContent | Should -Match 'x_SourceName=.+parameters\.querySource'
            $armEngineContent | Should -Match 'x_SourceProvider=.+parameters\.queryProvider'
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
            @($savingsPlanQueries.Query.scopeTypes | Sort-Object -Unique) | Should -Be @(
                'Microsoft.Billing/billingAccounts'
                'Microsoft.Billing/billingAccounts/billingProfiles'
            )
        }

        It 'Should derive the Savings Plan recommendation ID from the single mapped ARM ID' {
            $ingestionSetupV12Content | Should -Match 'x_RecommendationId = coalesce\(x_RecommendationId, ResourceId\)'
        }

        It 'Should derive the Savings Plan benefit type from the documented ARM SKU name' {
            $savingsPlanCatalogContent | Should -Match 'BenefitType = replace_regex\(tostring\(x_RecommendationDetails\.x_ArmSkuName\)'
            $savingsPlanCatalogContent | Should -Match 'summarize arg_max\(x_RecommendationDate, \*\) by SubAccountId, BenefitType'
            $savingsPlanCatalogContent | Should -Match '(?m)^\s+SubAccountId,\r?$'
            $savingsPlanCatalogContent | Should -Not -Match 'x_RecommendationType'
        }

        It 'Should define the thirteen approved GET-only quota queries' {
            $quotaQueries = @($queryObjects | Where-Object { $_.AppName -eq 'Quota' })

            $quotaQueries.Count | Should -Be 13
            @($quotaQueries.Query.type | Sort-Object) | Should -Be @(
                'AppServiceUsage'
                'AvailabilityZoneMapping'
                'CapacityReservation'
                'CognitiveServicesUsage'
                'ComputeResourceSku'
                'ComputeUsage'
                'HDInsightUsage'
                'MachineLearningUsage'
                'NetworkUsage'
                'PremiumSSDv2Disk'
                'PurviewUsage'
                'SqlSubscriptionUsage'
                'StorageUsage'
            )
            @($quotaQueries.Query.queryEngine | Sort-Object -Unique) | Should -Be @('AzureResourceManager')
            @($quotaQueries.Query.scope | Sort-Object -Unique) | Should -Be @('Tenant')
            @($quotaQueries.Query.query | Where-Object { $_ -notmatch '^/(providers/|locations\?)' }).Count | Should -Be 0
        }

        It 'Should use the documented stable API for each added regional quota provider' {
            $quotaQueries = @($queryObjects | Where-Object { $_.AppName -eq 'Quota' })
            $expectedQueries = @{
                HDInsightUsage      = '/providers/Microsoft.HDInsight/locations/{location}/usages?api-version=2021-06-01'
                MachineLearningUsage = '/providers/Microsoft.MachineLearningServices/locations/{location}/usages?api-version=2025-04-01'
                NetworkUsage        = '/providers/Microsoft.Network/locations/{location}/usages?api-version=2025-07-01'
                PurviewUsage        = '/providers/Microsoft.Purview/locations/{location}/usages?api-version=2021-12-01'
            }

            foreach ($sourceType in $expectedQueries.Keys)
            {
                $query = @($quotaQueries | Where-Object { $_.Query.type -eq $sourceType })
                $query.Count | Should -Be 1
                $query[0].Query.query | Should -Be $expectedQueries[$sourceType]
                $query[0].Query.version | Should -Be '1.0-usage'
                $quotaAppBicepContent | Should -Match ([regex]::Escape("Quota-Microsoft-$sourceType"))
            }
        }

        It 'Should keep the generated Quota query registration in manifest filename order' {
            $quotaQueryPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota/queries'
            $expectedQueryNames = @(
                Get-ChildItem -Path $quotaQueryPath -Filter '*.json' |
                    Sort-Object Name |
                    Select-Object -ExpandProperty BaseName
            )
            $generatedBlock = [regex]::Match(
                $quotaAppBicepContent,
                '(?s)// <generated-query-files>.*?// </generated-query-files>'
            ).Value
            $actualQueryNames = @(
                [regex]::Matches($generatedBlock, "'([^']+)': loadTextContent") |
                    ForEach-Object { $_.Groups[1].Value }
            )

            $actualQueryNames | Should -Be $expectedQueryNames
        }

        It 'Should define only the thirteen approved type-specific quota catalog files' {
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
            $ingestionSetupContent | Should -Match 'SubAccountId = tolower\(coalesce\(tmp_QueryScope, SubAccountId\)\)'
            $ingestionSetupContent | Should -Match 'bag_pack\('
            $ingestionSetupContent | Should -Match "x_SourceType !~ 'PremiumSSDv2Disk' or displayName =~ 'PremiumV2_LRS'"
            $ingestionSetupContent | Should -Match "x_SourceType =~ 'AppServiceUsage'"
            $ingestionSetupContent | Should -Match ([regex]::Escape("x_SourceType =~ 'HDInsightUsage', 'Microsoft.HDInsight/locations/usages'"))
            $ingestionSetupContent | Should -Match ([regex]::Escape("x_SourceType =~ 'MachineLearningUsage', 'Microsoft.MachineLearningServices/locations/usages'"))
            $ingestionSetupContent | Should -Match ([regex]::Escape("x_SourceType =~ 'NetworkUsage', 'Microsoft.Network/locations/usages'"))
            $ingestionSetupContent | Should -Match ([regex]::Escape("x_SourceType =~ 'PurviewUsage', 'Microsoft.Purview/locations/usages'"))
            $ingestionSetupContent | Should -Match "x_SourceType =~ 'StorageUsage'"
            $ingestionSetupContent | Should -Match ([regex]::Escape("ResourceId matches regex '(?i)^/subscriptions/[^/]+/usages(/[^/]+)?$'"))
            $ingestionSetupContent | Should -Match 'tmp_UsageResourceId'
            $ingestionSetupContent | Should -Match 'coalesce\(ResourceId, case\('
            $regionalUsageFallbackSources = [regex]::Match(
                $ingestionSetupContent,
                "(?s)x_SourceType in~ \((.*?)\),\s+tmp_UsageResourceId"
            ).Groups[1].Value
            foreach ($sourceType in @('HDInsightUsage', 'MachineLearningUsage', 'NetworkUsage', 'PurviewUsage'))
            {
                $regionalUsageFallbackSources | Should -Match ([regex]::Escape("'$sourceType'"))
            }
            $ingestionSetupContent | Should -Match ([regex]::Escape("strcat(SubAccountId, '/providers/Microsoft.Compute/locations/', location, '/skus/', ResourceName)"))
            $hubSetupContent | Should -Match 'Quota_v1_0\(\)'
            $hubSetupContent | Should -Match 'ComputeQuota_v1_0\(\)'
            $hubLatestContent | Should -Match 'Quota\(\)'
            $hubLatestContent | Should -Match 'ComputeQuota\(\)'
        }

        It 'Should preserve or synthesize the canonical quota ResourceId for <Name>' -ForEach $quotaResourceIdCases {
            $actual = Get-CanonicalQuotaResourceId `
                -SourceType $SourceType `
                -NativeResourceId $NativeResourceId `
                -QueryScope $QueryScope `
                -Provider $Provider `
                -Location $Location `
                -ResourceName $ResourceName `
                -MachineLearningSubscriptionUsageIdPattern $machineLearningSubscriptionUsageIdPattern

            $actual | Should -Be $Expected
        }

        It 'Should keep identical Machine Learning quota names distinct across locations' {
            $eastUs = Get-CanonicalQuotaResourceId `
                -SourceType 'MachineLearningUsage' `
                -NativeResourceId '/subscriptions/11111111-1111-1111-1111-111111111111/usages' `
                -QueryScope '/subscriptions/11111111-1111-1111-1111-111111111111' `
                -Provider 'Microsoft.MachineLearningServices' `
                -Location 'eastus' `
                -ResourceName 'StandardDSv2Family' `
                -MachineLearningSubscriptionUsageIdPattern $machineLearningSubscriptionUsageIdPattern
            $westUs2 = Get-CanonicalQuotaResourceId `
                -SourceType 'MachineLearningUsage' `
                -NativeResourceId '/subscriptions/11111111-1111-1111-1111-111111111111/usages/StandardDSv2Family' `
                -QueryScope '/subscriptions/11111111-1111-1111-1111-111111111111' `
                -Provider 'Microsoft.MachineLearningServices' `
                -Location 'westus2' `
                -ResourceName 'StandardDSv2Family' `
                -MachineLearningSubscriptionUsageIdPattern $machineLearningSubscriptionUsageIdPattern

            $eastUs | Should -Not -Be $westUs2
        }

        It 'Should document the four added quota providers without expanding unrelated guide coverage' {
            $supportedSourceTypes = [regex]::Match(
                $quotaGuideContent,
                '(?s)#### Supported source types.*?Use this pattern'
            ).Value
            $expectedCatalogQueries = @{
                HDInsightUsage      = 'quota-hdinsight-usage'
                MachineLearningUsage = 'quota-machine-learning-usage'
                NetworkUsage        = 'quota-network-usage'
                PurviewUsage        = 'quota-purview-usage'
            }
            $documentedSourceTypes = @(
                [regex]::Matches($supportedSourceTypes, '(?m)^\| `([^`]+)` \|') |
                    ForEach-Object { $_.Groups[1].Value } |
                    Where-Object { $_ -ne 'x_SourceType' }
            )

            $documentedSourceTypes.Count | Should -Be 11
            foreach ($sourceType in $expectedCatalogQueries.Keys)
            {
                $documentedSourceTypes | Should -Contain $sourceType
                $queryIndexContent | Should -Match ([regex]::Escape($expectedCatalogQueries[$sourceType]))
            }
            $catalogFiles = @(Get-ChildItem (Join-Path $repoRoot 'src/queries/catalog') -Filter '*.kql')
            $indexedCatalogQueries = @(
                [regex]::Matches($queryIndexContent, '\./catalog/([^)]+)\.kql') |
                    ForEach-Object { $_.Groups[1].Value } |
                    Sort-Object -Unique
            )
            $indexedCatalogQueries.Count | Should -Be $catalogFiles.Count
            $queryIndexContent | Should -Match "This catalog contains $($catalogFiles.Count) scenario-specific"
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

        It 'Azure Resource Manager pipelines should compile with owned execution and selective retries' {
            if (-not (Get-Command 'bicep' -ErrorAction SilentlyContinue))
            {
                Set-ItResult -Skipped -Because 'bicep CLI not found'
                return
            }

            $armBicep = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/AzureResourceManager/app.bicep'
            $armTemplatePath = Join-Path $TestDrive 'azure-resource-manager.json'
            bicep build $armBicep --outfile $armTemplatePath
            $LASTEXITCODE | Should -Be 0

            $armTemplate = Get-Content -Path $armTemplatePath -Raw | ConvertFrom-Json -Depth 100
            $configuredScopesPipeline = $armTemplate.resources.pipeline_ExecuteConfiguredScopes
            $tenantPipeline = $armTemplate.resources.pipeline_ExecuteTenant
            $subscriptionPagePipeline = $armTemplate.resources.pipeline_ExecuteSubscriptionPage
            $regionalPipeline = $armTemplate.resources.pipeline_ExecuteRegional
            $locationPagePipeline = $armTemplate.resources.pipeline_ExecuteLocationPage
            $copyPipeline = $armTemplate.resources.pipeline_CopyQuery
            $readArmPages = $copyPipeline.properties.activities | Where-Object name -EQ 'Read ARM Pages'
            $copyRawArmPage = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Copy Raw ARM Page'
            $classifyExpectedEmpty = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Classify Expected Empty ARM Response'
            $classifyTransient = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Classify Transient ARM Response'
            $selectRetryUrl = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Select ARM Retry URL'
            $waitBeforeRetry = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Wait Before Transient ARM Retry'
            $copyPageMetadata = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Copy Page Metadata'
            $copyArmPage = $readArmPages.typeProperties.activities | Where-Object name -EQ 'Copy ARM Page'
            $rethrowArmFailure = $copyPipeline.properties.activities | Where-Object name -EQ 'Rethrow ARM Request Failure'

            $readSubscriptionPages = $tenantPipeline.properties.activities | Where-Object name -EQ 'Read Subscription Pages'
            $subscriptionPageActivities = $readSubscriptionPages.typeProperties.activities
            $validateSubscriptionPageUrl = $subscriptionPageActivities | Where-Object name -EQ 'Validate Subscription Page URL'
            $executeSubscriptionPage = $subscriptionPageActivities | Where-Object name -EQ 'Execute Subscription Page'
            $setNextSubscriptionPage = $subscriptionPageActivities | Where-Object name -EQ 'Set Next Subscription Page URL'
            $forEachSubscription = $subscriptionPagePipeline.properties.activities | Where-Object name -EQ 'ForEach Subscription'
            $forEachScope = $configuredScopesPipeline.properties.activities | Where-Object name -EQ 'ForEach Scope'
            ($tenantPipeline | ConvertTo-Json -Depth 100) | Should -Not -Match '"type":\s*"Lookup"'
            $readSubscriptionPages.typeProperties.expression.value | Should -Be "@empty(variables('subscriptionPageUrl'))"
            $validateSubscriptionPageUrl.type | Should -Be 'SetVariable'
            $validateSubscriptionPageUrl.typeProperties.variableName | Should -Be 'subscriptionPageFailure'
            $executeSubscriptionPage.typeProperties.waitOnCompletion | Should -BeTrue
            $executeSubscriptionPage.typeProperties.pipeline.referenceName | Should -Be 'queries_AzureResourceManager_ExecuteSubscriptionPage'
            $executeSubscriptionPage.typeProperties.parameters.subscriptions.value | Should -Be "@activity('Filter Enabled Subscriptions').output.value"
            $setNextSubscriptionPage.dependsOn.activity | Should -Be 'Execute Subscription Page'
            $setNextSubscriptionPage.typeProperties.value.value | Should -Match 'output\.nextLink'
            $forEachSubscription.typeProperties.items.value | Should -Be '@pipeline().parameters.subscriptions'
            $forEachScope.typeProperties.batchCount | Should -Be 50
            $forEachSubscription.typeProperties.batchCount | Should -Be 50

            $readLocationPages = $regionalPipeline.properties.activities | Where-Object name -EQ 'Read Location Pages'
            $locationPageActivities = $readLocationPages.typeProperties.activities
            $validateLocationPageUrl = $locationPageActivities | Where-Object name -EQ 'Validate Location Page URL'
            $getLocationPage = $locationPageActivities | Where-Object name -EQ 'Get Location Page'
            $executeLocationPage = $locationPageActivities | Where-Object name -EQ 'Execute Location Page'
            $setNextLocationPage = $locationPageActivities | Where-Object name -EQ 'Set Next Location Page URL'
            $forEachLocation = $locationPagePipeline.properties.activities | Where-Object name -EQ 'ForEach Location'
            ($regionalPipeline | ConvertTo-Json -Depth 100) | Should -Not -Match '"type":\s*"Lookup"'
            $readLocationPages.typeProperties.expression.value | Should -Be "@empty(variables('locationPageUrl'))"
            $validateLocationPageUrl.type | Should -Be 'SetVariable'
            $validateLocationPageUrl.typeProperties.variableName | Should -Be 'locationPageFailure'
            $getLocationPage.policy.retry | Should -Be 0
            $executeLocationPage.typeProperties.waitOnCompletion | Should -BeTrue
            $executeLocationPage.typeProperties.pipeline.referenceName | Should -Be 'queries_AzureResourceManager_ExecuteLocationPage'
            $executeLocationPage.typeProperties.parameters.locations.value | Should -Be "@activity('Get Location Page').output.value"
            $setNextLocationPage.dependsOn.activity | Should -Be 'Execute Location Page'
            $setNextLocationPage.typeProperties.value.value | Should -Match 'output\.nextLink'
            $forEachLocation.typeProperties.items.value | Should -Be "@activity('Filter Physical Locations').output.value"
            $forEachLocation.typeProperties.batchCount | Should -Be 50
            $copyRawArmPage.policy.timeout | Should -Be '0.00:02:30'
            $copyRawArmPage.policy.retry | Should -Be 0
            $copyRawArmPage.policy.retryIntervalInSeconds | Should -Be 60
            ($readSubscriptionPages.typeProperties.activities.type | Where-Object { $_ -in @('ForEach', 'IfCondition', 'Switch', 'Until') }) | Should -BeNullOrEmpty
            ($readLocationPages.typeProperties.activities.type | Where-Object { $_ -in @('ForEach', 'IfCondition', 'Switch', 'Until') }) | Should -BeNullOrEmpty
            ($readArmPages.typeProperties.activities.type | Where-Object { $_ -in @('ForEach', 'IfCondition', 'Switch', 'Until') }) | Should -BeNullOrEmpty
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'machinelearningusage'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'status code 400 badrequest'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'subscriptionnotfounderror'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'is not found in quota service'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'statuscode'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match '404'
            $classifyExpectedEmpty.typeProperties.value.value | Should -Match 'SubscriptionHasNoUsages'
            $classifyTransient.typeProperties.value.value | Should -Match 'status code 429'
            $classifyTransient.typeProperties.value.value | Should -Match 'status code 5'
            $classifyTransient.typeProperties.value.value | Should -Match 'systemerror'
            $classifyTransient.typeProperties.value.value | Should -Match 'connection reset'
            $selectRetryUrl.typeProperties.value.value | Should -Match "less\(length\(variables\('requestAttempts'\)\), 3\)"
            $waitBeforeRetry.typeProperties.waitTimeInSeconds.value | Should -Be "@if(empty(variables('requestUrl')), 0, 60)"
            $copyPageMetadata.dependsOn.activity | Should -Contain 'Reset ARM Request Attempts'
            $copyArmPage.dependsOn.activity | Should -Contain 'Lookup Page Metadata'
            $rethrowArmFailure.typeProperties.expression.value | Should -Match "not\(equals\(activity\('Read ARM Pages'\)\.Status, 'Succeeded'\)\)"
            $copyPipeline.properties.concurrency | Should -Match "if\(parameters\('app'\)\.hub\.options\.privateRouting, 4, 30\)"

            $ingestionBicep = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/IngestionQueries/app.bicep'
            $ingestionTemplatePath = Join-Path $TestDrive 'ingestion-queries.json'
            bicep build $ingestionBicep --outfile $ingestionTemplatePath
            $LASTEXITCODE | Should -Be 0

            $ingestionTemplate = Get-Content -Path $ingestionTemplatePath -Raw | ConvertFrom-Json -Depth 100
            $queryCoordinator = $ingestionTemplate.resources.pipeline_ExecuteQueries
            $queryWorker = $ingestionTemplate.resources.pipeline_ExecuteQueries_query
            $queryLoop = $queryCoordinator.properties.activities | Where-Object name -EQ 'Loop Thru Queries'
            $deleteOldFilesLoop = $queryWorker.properties.activities | Where-Object name -EQ 'Delete Old Files Loop'
            $engineDispatch = $queryWorker.properties.activities | Where-Object name -EQ 'Run Query Engine Pipeline'
            $executeArmQuery = $engineDispatch.typeProperties.ifTrueActivities | Where-Object name -EQ 'Execute Azure Resource Manager Query'
            $queryCoordinator.properties.concurrency | Should -Be 1
            $queryLoop.typeProperties.batchCount | Should -Be 50
            $deleteOldFilesLoop.typeProperties.batchCount | Should -Be 50
            $engineDispatch.type | Should -Be 'IfCondition'
            $engineDispatch.typeProperties.expression.value | Should -Be "@equals(toLower(pipeline().parameters.queryEngine), 'azureresourcemanager')"
            $executeArmQuery.type | Should -Be 'ExecutePipeline'
            $executeArmQuery.typeProperties.pipeline.referenceName | Should -Be 'queries_AzureResourceManager_ExecuteQuery'
            $executeArmQuery.typeProperties.waitOnCompletion | Should -BeTrue
            ($engineDispatch.typeProperties.ifTrueActivities | ConvertTo-Json -Depth 100) | Should -Not -Match 'createRun'
        }

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
