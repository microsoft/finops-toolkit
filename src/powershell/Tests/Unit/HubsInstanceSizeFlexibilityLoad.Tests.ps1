# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for loading the instance size flexibility open data into the hub database:
    - IngestionSetup_HubInfra.kql creates the table and HubSetup_OpenData.kql wraps it for the hub database.
    - The InitializeHub pipeline and the local emulator script both load the table with the columns the CSV publishes,
      and the pipeline doesn't report ingestion as complete until the load succeeds.

    KQL can't run locally, so these tests assert on the deployed scripts and compare the load schema to the real CSV.
#>

Describe 'HubsInstanceSizeFlexibilityLoad' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $analyticsPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics'
        $scriptsPath = Join-Path $analyticsPath 'scripts'
        $appBicep = Get-Content -Path (Join-Path $analyticsPath 'app.bicep') -Raw
        $hubInfra = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_HubInfra.kql') -Raw
        $hubOpenData = Get-Content -Path (Join-Path $scriptsPath 'HubSetup_OpenData.kql') -Raw
        $localOpenData = Get-Content -Path (Join-Path $scriptsPath 'IngestionSetup_OpenDataExternal.kql') -Raw
        $csvColumns = (Get-Content -Path (Join-Path $repoRoot 'src/open-data/InstanceSizeFlexibility.csv') -TotalCount 1) -replace '"', '' -split ','

        function Get-ExternalDataColumn
        {
            param([string] $Content)
            $match = [regex]::Match($Content, '\.set-or-replace InstanceSizeFlexibility <\| externaldata\(([^)]*)\)')
            if (-not $match.Success) { return @() }
            return @($match.Groups[1].Value -split ',' | ForEach-Object { ($_ -split ':')[0].Trim() })
        }
    }

    It 'Should create the table with the CSV columns' {
        $match = [regex]::Match($hubInfra, '\.create-merge table InstanceSizeFlexibility\(([^)]*)\)')
        $match.Success | Should -BeTrue
        @($match.Groups[1].Value -split ',' | ForEach-Object { ($_ -split ':')[0].Trim() }) | Should -Be $csvColumns
    }

    It 'Should wrap the ingestion table in a hub function' {
        $hubOpenData | Should -Match "InstanceSizeFlexibility\(\)\s*\{\s*database\('Ingestion'\)\.InstanceSizeFlexibility\s*\}"
    }

    It 'Should load the CSV columns in order in the InitializeHub pipeline' {
        Get-ExternalDataColumn -Content $appBicep | Should -Be $csvColumns
        $appBicep | Should -Match '\$\{ftkReleaseUri\}/InstanceSizeFlexibility\.csv'
    }

    It 'Should load the CSV columns in order in the local emulator script' {
        Get-ExternalDataColumn -Content $localOpenData | Should -Be $csvColumns
        $localOpenData | Should -Match '\$\$openDataPath\$\$/InstanceSizeFlexibility\.csv'
    }

    It 'Should stage the CSV in each local hub download step' {
        $guide = Get-Content -Path (Join-Path $repoRoot 'docs-mslearn/toolkit/hubs/run-hubs-locally.md')
        $downloadLines = @($guide | Where-Object { $_ -match "foreach \(\`$f in 'PricingUnits'" })
        $downloadLines.Count | Should -BeGreaterThan 0
        $downloadLines | ForEach-Object { $_ | Should -Match "'InstanceSizeFlexibility'" }
    }

    It 'Should complete ingestion only after the load succeeds' {
        $appBicep | Should -Match "name: 'Ingestion Complete'\s+type: 'SetVariable'\s+dependsOn: \[\s*\{\s*activity: 'Update InstanceSizeFlexibility in ADX'"
    }
}
