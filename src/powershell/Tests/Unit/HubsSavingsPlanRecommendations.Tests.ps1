# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Coverage for savings plan purchase recommendations (#2434):
    - Copy-FileToAzureBlob.ps1 writes recommendations.savingsPlans.lookbackPeriods/terms to settings.json only when the
      deployment specifies them, like retention. When omitted, the stored values are kept.
    - The SavingsPlanRecommendations app follows the IngestionQueries engine contract and is only deployed when enabled.
    - The schema file maps the Benefit Recommendations API response to the columns Recommendations_transform_v1_2() reads.

    The script tests run the real script with stubbed Az cmdlets and assert on the JSON it writes.
#>

Describe 'HubsSavingsPlanRecommendations' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $hubRoot = Join-Path $repoRoot 'src/templates/finops-hub'
        $modulesRoot = Join-Path $hubRoot 'modules'
        $scriptPath = Join-Path $modulesRoot 'Microsoft.FinOpsHubs/Core/Copy-FileToAzureBlob.ps1'
        $appPath = Join-Path $modulesRoot 'Microsoft.FinOpsHubs/SavingsPlanRecommendations/app.bicep'
        $schemaPath = Join-Path $modulesRoot 'Microsoft.FinOpsHubs/SavingsPlanRecommendations/schemas/recommendations_savingsplans_2025-03-01.json'
        $hubPath = Join-Path $modulesRoot 'hub.bicep'
        $kqlPath = Join-Path $modulesRoot 'Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_v1_2.kql'
        $envVars = 'msexportRetentionInDays', 'ingestionRetentionInMonths', 'rawRetentionInDays', 'finalRetentionInMonths', 'savingsPlanRecommendationLookbackPeriods', 'savingsPlanRecommendationTerms'

        function Invoke-CopyScript
        {
            param([string] $ExistingJson, [string] $LookbackPeriods, [string] $Terms)

            $workDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $workDir | Out-Null
            $existingJson = $ExistingJson

            function New-AzStorageContext { param($StorageAccountName, [switch] $UseConnectedAccount) 'ctx' }
            function Get-AzStorageBlobContent
            {
                param($Context, $Container, $Blob, $Destination, [switch] $Force)
                if (-not $existingJson) { return $null }
                Set-Content -Path $Destination -Value $existingJson
                return 'blob'
            }
            function Set-AzStorageBlobContent { param($Context, $Container, $File, [switch] $Force) }

            $env:storageAccountName = 'sa'
            $env:containerName = 'config'
            $env:scopes = ''
            $env:ftkVersion = '0.0.0'
            # The template omits these environment variables when the deployment doesn't specify them
            $env:savingsPlanRecommendationLookbackPeriods = $LookbackPeriods
            $env:savingsPlanRecommendationTerms = $Terms

            Push-Location $workDir
            try
            {
                . $scriptPath *> $null
                return (Get-Content -Path (Join-Path $workDir settings.json) -Raw | ConvertFrom-Json)
            }
            finally
            {
                Pop-Location
                Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
                $envVars | ForEach-Object { Remove-Item "env:$_" -ErrorAction SilentlyContinue }
            }
        }

        $existing = '{"version":"","scopes":[],"retention":{"msexports":{"days":0},"ingestion":{"months":13},"raw":{"days":0},"final":{"months":13}},"recommendations":{"savingsPlans":{"lookbackPeriods":["Last30Days"],"terms":["P3Y"]}}}'
    }

    Context 'settings.json' {

        It 'Should not add savings plan settings when they are not specified' {
            $s = Invoke-CopyScript -ExistingJson $null
            $s.PSObject.Properties.Name | Should -Not -Contain 'recommendations' -Because 'the pipeline falls back to all lookback periods and terms'
        }

        It 'Should keep stored values when they are not specified' {
            $s = Invoke-CopyScript -ExistingJson $existing
            @($s.recommendations.savingsPlans.lookbackPeriods) | Should -Be @('Last30Days') -Because 'a redeploy must not reset values edited in settings.json'
            @($s.recommendations.savingsPlans.terms) | Should -Be @('P3Y')
        }

        It 'Should apply explicitly specified values' {
            $s = Invoke-CopyScript -ExistingJson $existing -LookbackPeriods 'Last7Days|Last60Days' -Terms 'P1Y'
            @($s.recommendations.savingsPlans.lookbackPeriods) | Should -Be @('Last7Days', 'Last60Days')
            @($s.recommendations.savingsPlans.terms) | Should -Be @('P1Y') -Because 'a single value must still be written as an array'
        }

        It 'Should add the settings object to a new hub when values are specified' {
            $s = Invoke-CopyScript -ExistingJson $null -LookbackPeriods 'Last30Days' -Terms 'P1Y|P3Y'
            @($s.recommendations.savingsPlans.lookbackPeriods) | Should -Be @('Last30Days')
            @($s.recommendations.savingsPlans.terms) | Should -Be @('P1Y', 'P3Y')
            $s.retention.ingestion.months | Should -Be 13 -Because 'writing nested settings must not break retention'
        }
    }

    Context 'Templates' {

        BeforeAll {
            $app = Get-Content -Path $appPath -Raw
            $hub = Get-Content -Path $hubPath -Raw
        }

        It 'Should only deploy the app when enableSavingsPlanRecommendations is true' {
            $hub | Should -Match "module savingsPlanRecommendations 'Microsoft\.FinOpsHubs/SavingsPlanRecommendations/app\.bicep' = if \(enableSavingsPlanRecommendations\)"
        }

        It 'Should deploy the ingestion queries app when either recommendations feature is enabled' {
            $hub | Should -Match "module ingestionQueries 'Microsoft\.FinOpsHubs/IngestionQueries/app\.bicep' = if \(enableRecommendations \|\| enableSavingsPlanRecommendations\)"
        }

        It 'Should start the savings plan trigger after the app is deployed' {
            $hub | Should -Match '(?s)module startTriggers.*?dependsOn: \[[^\]]*savingsPlanRecommendations'
        }

        It 'Should name the engine pipeline per the IngestionQueries contract' {
            $app | Should -Match "var QUERY_ENGINE = 'CostManagement'"
            $app | Should -Match "name: '\$\{ingestionQueries\.queries\.folder\}_\$\{QUERY_ENGINE\}_ExecuteQuery'"
        }

        It 'Should not write Parquet for an empty response' {
            $app | Should -Match "(?s)name: 'If Results Returned'.*?name: 'Write Results'"
        }

        It 'Should follow nextLink when paging' {
            $app | Should -Match "AbsoluteUrl: '\`$\.nextLink'"
        }

        It 'Should use API version 2025-03-01 with usage and all recommendation details' {
            $app | Should -Match "var API_VERSION = '2025-03-01'"
            $app | Should -Match '\$expand=properties/usage,properties/allRecommendationDetails'
        }

        It 'Should write each combination to a folder without a date' {
            $app | Should -Match "concat\(\\'Microsoft-SavingsPlans-\\', item\(\)\.term, \\'-\\', item\(\)\.lookbackPeriod\)"
        }
    }

    Context 'Schema and transform' {

        It 'Should map the columns the transform reads' {
            $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json
            $schema.translator.collectionReference | Should -Be "`$['value']"
            $schema.translator.mapComplexValuesToString | Should -BeTrue -Because 'properties is written as a JSON string'
            $sinks = $schema.translator.mappings | ForEach-Object { $_.sink.name }
            $sinks | Should -Contain 'x_RecommendationId'
            $sinks | Should -Contain 'x_SourceType'
            $sinks | Should -Contain 'x_RecommendationDetails'
        }

        It 'Should handle savings plan recommendations in Recommendations_transform_v1_2' {
            $kql = Get-Content -Path $kqlPath -Raw
            $kql | Should -Match "x_SourceType == 'SavingsPlan' and x_RecommendationId has 'benefitRecommendations'"
            $kql | Should -Match "x_SourceType == 'SavingsPlanRecommendations', bag_pack\("
            $kql | Should -Match "'AllRecommendationDetails', tmp_SP\.allRecommendationDetails\.value"
            $kql | Should -Match "'UsageCharges', tmp_SP\.usage\.charges"
        }
    }
}
