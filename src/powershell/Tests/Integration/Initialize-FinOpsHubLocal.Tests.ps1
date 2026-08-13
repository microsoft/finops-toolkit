# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Integration tests for Initialize-FinOpsHubLocal. These run the command against a real
# running Kusto emulator and download real release artifacts over HTTP -- no mocks.
#
# They are skipped unless the following environment variables point at live infrastructure:
#   FTK_LOCAL_EMULATOR_URI  Base URI of a running Kusto emulator (for example, http://localhost:8087).
#   FTK_LOCAL_RELEASE_URI   Base URI serving the release artifacts (for example, a local file server).
#   FTK_LOCAL_EXPORT_PATH   Host path mounted into the emulator at /data/export, holding FOCUS exports
#                           and an open-data subfolder.

if (-not (Get-Module -Name 'FinOpsToolkit'))
{
    $rootDirectory = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
    $modulePath = (Get-ChildItem -Path $rootDirectory -Include 'FinOpsToolKit.psm1' -Recurse).FullName
    Import-Module -FullyQualifiedName $modulePath
}

$script:emulatorUri = $env:FTK_LOCAL_EMULATOR_URI
$script:releaseUri = $env:FTK_LOCAL_RELEASE_URI
$script:exportPath = $env:FTK_LOCAL_EXPORT_PATH
$script:ready = [bool]$script:emulatorUri -and [bool]$script:releaseUri -and [bool]$script:exportPath

Describe 'Initialize-FinOpsHubLocal' {
    BeforeAll {
        $script:hub = $env:FTK_LOCAL_EMULATOR_URI
        $script:release = $env:FTK_LOCAL_RELEASE_URI
        $script:exports = $env:FTK_LOCAL_EXPORT_PATH
        # Recompute readiness from the environment: discovery-scope variables do not flow into BeforeAll.
        $script:ready = [bool]$script:hub -and [bool]$script:release -and [bool]$script:exports

        function Invoke-Q
        {
            param([string]$Database, [string]$Command, [ValidateSet('mgmt', 'query')][string]$Endpoint = 'query')
            Invoke-RestMethod -Uri "$script:hub/v1/rest/$Endpoint" -Method 'Post' -ContentType 'application/json' -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
        }

        function Get-Count
        {
            param([string]$Database, [string]$Table)
            [int64](Invoke-Q -Database $Database -Command "$Table | count" -Endpoint 'query').Tables[0].Rows[0][0]
        }

        if ($script:ready)
        {
            # Real setup: download real artifacts over HTTP, create databases, apply schema, load open data.
            Initialize-FinOpsHubLocal -ClusterUri $script:hub -ReleaseUri $script:release -RawRetentionInDays 90 -OpenDataPath '/data/export/open-data' -Destination (Join-Path $TestDrive 'setup')

            # Real ordered ingest: prices first, then costs (the documented pattern).
            $jobs = Get-ChildItem $script:exports -Recurse -Filter manifest.json | ForEach-Object {
                $manifest = Get-Content $_.FullName -Raw
                $isPrice = $manifest -match '"type"\s*:\s*"PriceSheet"' -or $_.FullName -match '(?i)price'
                $tableInfo = if ($isPrice) { 'Prices_raw', 'Prices_raw_mapping' } else { 'Costs_raw', 'Costs_raw_mapping' }
                Get-ChildItem $_.Directory -Filter *.parquet | ForEach-Object {
                    [PSCustomObject]@{ Table = $tableInfo[0]; Mapping = $tableInfo[1]; File = $_.FullName; Phase = [int](-not $isPrice) }
                }
            }

            $script:pricesBeforeCostsPhase = $null
            foreach ($phase in $jobs | Group-Object Phase | Sort-Object Name)
            {
                if ($phase.Name -eq '1') { $script:pricesBeforeCostsPhase = Get-Count -Database 'Ingestion' -Table 'Prices_raw' }
                foreach ($job in $phase.Group)
                {
                    $rel = [System.IO.Path]::GetRelativePath((Resolve-Path $script:exports), $job.File) -replace '\\', '/'
                    Invoke-Q -Database 'Ingestion' -Endpoint 'mgmt' -Command ".ingest into table $($job.Table) (h@'/data/export/$rel') with (format='parquet', ingestionMappingReference='$($job.Mapping)')" | Out-Null
                }
            }
        }
    }

    It 'creates the Ingestion and Hub databases' -Skip:(-not $script:ready) {
        $databases = (Invoke-Q -Database 'NetDefaultDB' -Command '.show databases' -Endpoint 'mgmt').Tables[0].Rows | ForEach-Object { $_[0] }
        $databases | Should -Contain 'Ingestion'
        $databases | Should -Contain 'Hub'
    }

    It 'loads all four open data tables with rows' -Skip:(-not $script:ready) {
        Get-Count -Database 'Ingestion' -Table 'PricingUnits' | Should -BeGreaterThan 0
        Get-Count -Database 'Ingestion' -Table 'Regions' | Should -BeGreaterThan 0
        Get-Count -Database 'Ingestion' -Table 'ResourceTypes' | Should -BeGreaterThan 0
        Get-Count -Database 'Ingestion' -Table 'Services' | Should -BeGreaterThan 0
    }

    It 'applies the requested raw retention to Costs_raw' -Skip:(-not $script:ready) {
        $policy = (Invoke-Q -Database 'Ingestion' -Command '.show table Costs_raw policy retention' -Endpoint 'mgmt').Tables[0].Rows[0][2] | ConvertFrom-Json
        $policy.SoftDeletePeriod | Should -Be '90.00:00:00'
    }

    It 'ingests prices before costs' -Skip:(-not $script:ready) {
        # Captured just before the costs phase started: prices were already present.
        $script:pricesBeforeCostsPhase | Should -BeGreaterThan 0
    }

    It 'fills the final cost and price tables through the update policy' -Skip:(-not $script:ready) {
        $costsRaw = Get-Count -Database 'Ingestion' -Table 'Costs_raw'
        $costsFinal = Get-Count -Database 'Ingestion' -Table 'Costs_final_v1_2'
        $costsRaw | Should -BeGreaterThan 0
        $costsFinal | Should -Be $costsRaw
    }

    It 'enriches costs with open data and prices' -Skip:(-not $script:ready) {
        $total = Get-Count -Database 'Hub' -Table 'Costs_v1_2'
        $enriched = Get-Count -Database 'Hub' -Table 'Costs_v1_2 | where isnotempty(ServiceCategory)'
        $priced = Get-Count -Database 'Hub' -Table 'Costs_v1_2 | where isnotempty(ListUnitPrice) and ListUnitPrice > 0'
        $total | Should -BeGreaterThan 0
        $enriched | Should -Be $total
        $priced | Should -BeGreaterThan 0
    }

    It 'throws a clear error when the emulator is unreachable' -Skip:(-not $script:ready) {
        # Real dead port -- no mock.
        { Initialize-FinOpsHubLocal -ClusterUri 'http://localhost:1' -ReleaseUri $script:release -Destination (Join-Path $TestDrive 'unreachable') } |
            Should -Throw '*Could not reach the Kusto emulator*'
    }
}
