Describe 'FinOps multitool real Parquet integration' -Tag 'MultitoolLocal' {
    BeforeAll {
        $script:ParquetHelper = (Resolve-Path (Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/modules/helpers/Read-FinOpsHubData.ps1')).Path
        $script:ParquetCache = Join-Path $TestDrive 'reader-cache'
        $script:ParquetFixture = Join-Path $TestDrive 'synthetic-focus.parquet'
        $script:ColdProcessId = $null

        function Invoke-ParquetIntegrationProcess {
            param([bool]$ReuseCache)

            $helperPath = $script:ParquetHelper
            $cachePath = $script:ParquetCache
            $fixturePath = $script:ParquetFixture
            $cacheReuseRequested = $ReuseCache
            $job = Start-Job -ScriptBlock {
                $helperPath = $using:helperPath
                $cachePath = $using:cachePath
                $fixturePath = $using:fixturePath
                $reuseCache = $using:cacheReuseRequested
                $ErrorActionPreference = 'Stop'
                . $HelperPath
                function Get-FinOpsParquetCachePath { return $CachePath }

                $loadedAtStart = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Parquet' }).Count
                if ($loadedAtStart -ne 0) { throw 'The integration process must start without Parquet loaded.' }
                $privateRoot = Split-Path $CachePath -Parent
                $env:NUGET_HTTP_CACHE_PATH = Join-Path $privateRoot 'nuget-http'
                $env:NUGET_PACKAGES = Join-Path $privateRoot 'nuget-global'
                $env:NUGET_SCRATCH = Join-Path $privateRoot 'nuget-scratch'
                $manifestPath = Join-Path $CachePath 'parquet-manifest.json'
                $manifestBefore = if ($ReuseCache) { (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash } else { $null }
                if (-not $ReuseCache -and (Test-Path -LiteralPath $CachePath)) { throw 'The cold reader cache must not exist.' }
                if (-not (Install-ParquetReader)) { throw "Real Parquet installation failed: $script:FinOpsParquetUnavailableReason" }
                $manifestAfter = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
                if ($ReuseCache -and $manifestBefore -ne $manifestAfter) { throw 'The cache was reinstalled instead of reused.' }

                if (-not $ReuseCache) {
                    $metadataFields = [Parquet.Schema.Field[]]@(
                        [Parquet.Schema.DataField]::new('Region', [string], $false, $false, $null)
                        [Parquet.Schema.DataField]::new('Service', [string], $false, $false, $null)
                    )
                    $fields = [Parquet.Schema.Field[]]@(
                        [Parquet.Schema.DataField]::new('ResourceId', [string], $false, $false, $null)
                        [Parquet.Schema.StructField]::new('Metadata', $metadataFields)
                        [Parquet.Schema.DataField]::new('BilledCost', [double], $true, $false, $null)
                        [Parquet.Schema.DataField]::new('BillingCurrency', [string], $false, $false, $null)
                    )
                    $schema = [Parquet.Schema.ParquetSchema]::new($fields)
                    $stream = [IO.File]::Create($FixturePath)
                    try {
                        $writer = [Parquet.ParquetWriter]::CreateAsync($schema, $stream, $null, $false, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
                        try {
                            $writer.CompressionMethod = [Parquet.CompressionMethod]::Snappy
                            foreach ($group in @(
                                    @{ Names = [string[]]@('charge', 'zero'); Costs = [Nullable[double][]]@(12.5, 0) }
                                    @{ Names = [string[]]@('credit', 'missing'); Costs = [Nullable[double][]]@(-2.25, $null) }
                                )) {
                                $rowGroup = $writer.CreateRowGroup()
                                try {
                                    $columns = @(
                                        [Parquet.Data.DataColumn]::new($fields[0], $group.Names)
                                        [Parquet.Data.DataColumn]::new($metadataFields[0], [string[]]@('test-region', 'test-region'))
                                        [Parquet.Data.DataColumn]::new($metadataFields[1], [string[]]@('test-service', 'test-service'))
                                        [Parquet.Data.DataColumn]::new($fields[2], $group.Costs)
                                        [Parquet.Data.DataColumn]::new($fields[3], [string[]]@('EUR', 'EUR'))
                                    )
                                    foreach ($column in $columns) {
                                        [void]$rowGroup.WriteColumnAsync($column, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
                                    }
                                }
                                finally { $rowGroup.Dispose() }
                            }
                        }
                        finally { $writer.Dispose() }
                    }
                    finally { $stream.Dispose() }
                }

                $rows = @(Read-ParquetFile -Path $FixturePath)
                [pscustomobject]@{
                    ProcessId      = $PID
                    LoadedAtStart  = $loadedAtStart
                    AssemblyPath   = [Parquet.ParquetReader].Assembly.Location
                    PackageCount   = @(Get-VerifiedParquetPackage -PackageDir (Join-Path $CachePath 'packages')).Count
                    ManifestValid  = Test-ParquetManifest -BasePath $CachePath -ManifestPath $manifestPath
                    ManifestReused = $ReuseCache -and $manifestBefore -eq $manifestAfter
                    Rows           = $rows
                } | ConvertTo-Json -Depth 6 -Compress
            }
            try {
                $output = @($job | Receive-Job -Wait -ErrorAction Stop)
                if ($job.State -ne 'Completed' -or $output.Count -ne 1) { throw 'The Parquet process did not produce one completed result.' }
                return ($output[0] | ConvertFrom-Json -ErrorAction Stop)
            }
            finally { $job | Remove-Job -Force }
        }
    }

    It 'Reads real Snappy-compressed data after <Phase> installation in a fresh process' -ForEach @(
        @{ Phase = 'cold'; ReuseCache = $false }
        @{ Phase = 'cached'; ReuseCache = $true }
    ) {
        $result = Invoke-ParquetIntegrationProcess -ReuseCache $ReuseCache
        $result.LoadedAtStart | Should -Be 0
        $result.AssemblyPath | Should -Be (Join-Path $script:ParquetCache 'lib/Parquet.dll')
        $result.PackageCount | Should -Be 12
        $result.ManifestValid | Should -BeTrue
        if ($ReuseCache) {
            $result.ManifestReused | Should -BeTrue
            $result.ProcessId | Should -Not -Be $script:ColdProcessId
        }
        else { $script:ColdProcessId = $result.ProcessId }
        $result.Rows.Count | Should -Be 4
        $result.Rows[0].PSObject.Properties.Name | Should -Be @('ResourceId', 'Metadata', 'BilledCost', 'BillingCurrency')
        $result.Rows.ResourceId | Should -Be @('charge', 'zero', 'credit', 'missing')
        $result.Rows.BillingCurrency | Should -Be @('EUR', 'EUR', 'EUR', 'EUR')
        $result.Rows[0].BilledCost | Should -Be 12.5
        $result.Rows[1].BilledCost | Should -Be 0
        $result.Rows[2].BilledCost | Should -Be -2.25
        $result.Rows[3].BilledCost | Should -BeNullOrEmpty
    }
}