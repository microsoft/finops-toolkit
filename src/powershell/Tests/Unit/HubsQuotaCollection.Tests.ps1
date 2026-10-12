# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Quota collection working set' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $quotaPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota'
        foreach ($file in Get-ChildItem "$quotaPath/AzVMQuotaUsage/Private/*.ps1", "$quotaPath/AzVMQuotaUsage/Public/*.ps1") {
            . $file.FullName
        }
        $token = ConvertTo-SecureString 'fixture-token' -AsPlainText -Force
    }

    BeforeEach {
        $script:batches = [Collections.Generic.List[object]]::new()
        Mock Get-Subscriptions {
            1..5 | ForEach-Object { [pscustomobject]@{ subscriptionId = "s$_"; id = "/subscriptions/s$_"; displayName = "Subscription $_" } }
        }
        Mock Get-Locations { 'eastus', 'westus' }
        Mock Get-ArmResponses {
            param($Requests, $Client, $ConcurrentSubscriptions, $ConcurrentRequests)
            $script:batches.Add([pscustomobject]@{
                Subscriptions = @($Requests | ForEach-Object { $_.Subscription.subscriptionId } | Select-Object -Unique)
                Count = $Requests.Count
                Sources = @($Requests | ForEach-Object { $_.SourceType } | Select-Object -Unique)
            })
            foreach ($request in $Requests) {
                $data = if (-not $request.SourceType) {
                    @([pscustomobject]@{
                        type = 'Region'; name = 'eastus'; availabilityZoneMappings = @([pscustomobject]@{ logicalZone = '1'; physicalZone = 'eastus-az2' })
                    })
                } else { @() }
                @{ Request = $request; Data = $data; Error = $null }
            }
        }
        Mock Get-ResourceDetails { "resource,$($Subscription.subscriptionId),$SourceType" }
        Mock Get-QuotaDetails {
            if ($Location -eq 'eastus' -and $AvailabilityZoneMappings[0].physicalZone -ne 'eastus-az2') {
                throw 'Physical zone mapping was lost.'
            }
            "quota,$($Subscription.subscriptionId),$Location,$UsageSourceType"
        }
    }

    It 'bounds requests and zone mappings to the current subscription batch while retaining every source' {
        $rows = @(Get-AzVMQuotaUsage -AccessToken $token -ConcurrentSubscriptions 2 -AsCsv)
        $script:batches.Count | Should -Be 6
        @($script:batches.Subscriptions | Select-Object -Unique).Count | Should -Be 5
        foreach ($batch in $script:batches) {
            $batch.Subscriptions.Count | Should -BeLessOrEqual 2
            $batch.Count | Should -BeLessOrEqual 48
        }
        $script:batches[1].Sources | Should -Contain 'ComputeResourceSku'
        $script:batches[1].Sources | Should -Contain 'PostgreSqlUsage'
        $script:batches[1].Sources | Should -Contain 'CapacityReservation'
        $script:batches[1].Sources | Should -Contain 'PremiumSSDv2Disk'
        $script:batches[1].Sources.Count | Should -Be 13
        @($rows | Where-Object { $_ -like 'ProviderName,*' }).Count | Should -Be 1
        @($rows | Where-Object { $_ -like 'quota,*' }).Count | Should -Be 110
    }

    It 'preserves the standalone output-file behavior' {
        $path = Join-Path $TestDrive 'Quota.csv'
        Get-AzVMQuotaUsage -AccessToken $token -ConcurrentSubscriptions 2 -OutputFile $path
        $lines = [IO.File]::ReadAllLines($path)
        $lines[0] | Should -BeLike 'ProviderName,*'
        $lines.Count | Should -Be 126
        [IO.File]::ReadAllBytes($path)[0] | Should -Be ([byte][char]'P')
    }

    It 'does not swallow a downstream CSV write or upload failure' {
        { Get-AzVMQuotaUsage -AccessToken $token -AsCsv | ForEach-Object { throw [IO.IOException]::new('CSV fixture failure') } } |
            Should -Throw '*CSV fixture failure*'
    }

    It 'does not build tenant-wide queues at 5000 subscriptions and 49 regions' {
        # Pester's mock call history retains arguments, so use non-recording stubs for this lifetime test.
        $metrics = New-Module -ReturnResult -ArgumentList "$quotaPath/AzVMQuotaUsage/Public/Get-AzVMQuotaUsage.ps1" -ScriptBlock {
            param($publicPath)
            . $publicPath
            $script:metrics = @{ RequestCount = 0; LargestQueue = 0; LargestHeap = 0 }
            function Get-Subscriptions {
                1..5000 | ForEach-Object { [pscustomobject]@{ subscriptionId = "s$_"; id = "/subscriptions/s$_"; displayName = "Subscription $_" } }
            }
            function Get-Locations { 1..49 | ForEach-Object { "region$_" } }
            function Get-ArmResponses {
                param($Requests, $Client, $ConcurrentSubscriptions, $ConcurrentRequests)
                $script:metrics.RequestCount += $Requests.Count
                $script:metrics.LargestQueue = [math]::Max($script:metrics.LargestQueue, $Requests.Count)
                $script:metrics.LargestHeap = [math]::Max($script:metrics.LargestHeap, [GC]::GetTotalMemory($true))
            }
            Get-AzVMQuotaUsage -AccessToken (ConvertTo-SecureString 'fixture-token' -AsPlainText -Force) -AsCsv | Out-Null
            [pscustomobject]$script:metrics
        }
        $metrics.RequestCount | Should -Be 2710000
        $metrics.LargestQueue | Should -Be 34624
        $metrics.LargestHeap | Should -BeLessThan 1GB
        Write-Host "5000-subscription fixture: largest queue $($metrics.LargestQueue); largest sampled live managed heap $($metrics.LargestHeap) bytes."
    }
}

Describe 'ARM response lifetime' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $quotaPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota'
        . "$quotaPath/AzVMQuotaUsage/Private/Get-ArmResponses.ps1"
        . "$quotaPath/AzVMQuotaUsage/Private/Get-QuotaDetails.ps1"
        if (-not ('QuotaFixtureHandler' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public sealed class QuotaFixtureContent : HttpContent {
    private readonly byte[] bytes;
    public int Reads;
    public int Disposals;
    public bool OutOfMemory;
    public QuotaFixtureContent(string body) { bytes = Encoding.UTF8.GetBytes(body); }
    protected override Task SerializeToStreamAsync(Stream stream, TransportContext context) {
        Reads++;
        if (OutOfMemory) return Task.FromException(new OutOfMemoryException("OOM fixture failure"));
        return stream.WriteAsync(bytes, 0, bytes.Length);
    }
    protected override bool TryComputeLength(out long length) { length = bytes.Length; return true; }
    protected override void Dispose(bool disposing) { if (disposing) Disposals++; base.Dispose(disposing); }
}

public sealed class QuotaFixtureHandler : HttpMessageHandler {
    public readonly Dictionary<string, HttpResponseMessage> Routes = new Dictionary<string, HttpResponseMessage>();
    public readonly List<string> Requests = new List<string>();
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) {
        Requests.Add(request.RequestUri.AbsoluteUri);
        if (!Routes.TryGetValue(request.RequestUri.AbsoluteUri, out var response))
            return Task.FromException<HttpResponseMessage>(new InvalidOperationException("Unexpected fixture URL"));
        return Task.FromResult(response);
    }
}
'@
        }
    }

    BeforeEach {
        $handler = [QuotaFixtureHandler]::new()
        $client = [Net.Http.HttpClient]::new($handler)
        $requests = [Collections.Generic.List[object]]::new()
        $subscription = [pscustomobject]@{ subscriptionId = 's1'; id = '/subscriptions/s1'; displayName = 'Fixture' }
        $firstContent = [QuotaFixtureContent]::new('{"value":[{"name":"first"}]}')
        $secondContent = [QuotaFixtureContent]::new('{"value":[{"name":"second"}]}')
        foreach ($pair in @(@('/first', $firstContent), @('/second', $secondContent))) {
            $response = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]::OK)
            $response.Content = $pair[1]
            $handler.Routes.Add("https://management.azure.com$($pair[0])", $response)
            $requests.Add(@{ Subscription = $subscription; Path = $pair[0] })
        }
    }

    AfterEach { $client.Dispose() }

    It 'reads only the selected body and disposes all completed responses' {
        $script:received = 0
        Get-ArmResponses $requests $client 1 2 | ForEach-Object {
            $script:received++
            if ($script:received -eq 1) {
                ($firstContent.Reads + $secondContent.Reads) | Should -Be 1
            }
        }
        $script:received | Should -Be 2
        $firstContent.Disposals | Should -Be 1
        $secondContent.Disposals | Should -Be 1
    }

    It 'retains cross-page SKU family selection and physical zones' {
        $sku = @{ resourceType = 'virtualMachines'; family = 'family'; tier = 'Standard'; locationInfo = @(@{ location = 'eastus'; zones = @('1') }); restrictions = @() }
        $firstContent = [QuotaFixtureContent]::new((@{ value = @($sku + @{ name = 'D4'; size = 'D4' }); nextLink = 'https://management.azure.com/next' } | ConvertTo-Json -Depth 10 -Compress))
        $handler.Routes['https://management.azure.com/first'].Content = $firstContent
        $next = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]::OK)
        $next.Content = [QuotaFixtureContent]::new((@{ value = @($sku + @{ name = 'D2'; size = 'D2' }) } | ConvertTo-Json -Depth 10 -Compress))
        $handler.Routes.Add('https://management.azure.com/next', $next)
        $requests.RemoveAt(1)
        $result = @(Get-ArmResponses $requests $client 1 2)
        $rows = @(Get-QuotaDetails -Subscription $subscription -Location eastus -ComputeSkus $result[0].Data `
                -AvailabilityZoneMappings @([pscustomobject]@{ logicalZone = '1'; physicalZone = 'eastus-az3' }))
        $rows.Count | Should -Be 1
        $rows[0] | Should -Match '"D2"'
        $rows[0] | Should -Match 'ZonesPresent"":""3'
        $rows[0] | Should -Match ',,,,'
        $next.Content.Disposals | Should -Be 1
    }

    It 'returns ordinary HTTP failures without aborting unrelated requests' {
        $handler.Routes['https://management.azure.com/first'].StatusCode = [Net.HttpStatusCode]::NotFound
        $result = @(Get-ArmResponses $requests $client 1 2)
        @($result | Where-Object Error).Count | Should -Be 1
        @($result | Where-Object { -not $_.Error }).Count | Should -Be 1
        $firstContent.Reads | Should -Be 0
    }

    It 'stops on OOM and disposes the other completed response' {
        $firstContent.OutOfMemory = $true
        { Get-ArmResponses $requests $client 1 2 } | Should -Throw '*OOM fixture failure*'
        $firstContent.Disposals | Should -Be 1
        $secondContent.Reads | Should -BeLessOrEqual 1
        $secondContent.Disposals | Should -Be 1
    }

    It 'disposes pending responses when downstream output fails' {
        { Get-ArmResponses $requests $client 1 2 | ForEach-Object { throw [IO.IOException]::new('Output fixture failure') } } |
            Should -Throw '*Output fixture failure*'
        $firstContent.Disposals | Should -Be 1
        $secondContent.Disposals | Should -Be 1
    }
}

Describe 'Quota CSV publication' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $quotaPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota'
        $runnerSource = Get-Content "$quotaPath/CollectQuota/run.ps1" -Raw
        function Get-AzVMQuotaUsage { param($AccessToken, [switch]$AsCsv) }
        function Get-SavingsPlanRecommendations { param($AccessToken, $TenantId, $BillingScope, $SettingsHash, $SettingsETag, $RunId, $OutputDirectory) }
        $fixtureHeader = 'ProviderName,ResourceId,ResourceName,ResourceType,SubAccountId,displayName,location,currentValue,limit,unit,x_QuotaDetails,x_SourceName,x_SourceProvider,x_SourceType,x_SourceVersion'
        function New-FixtureRow {
            param([string]$Name = 'name', [string]$Details = '{}')
            (@('Microsoft', '/id', $Name, 'Microsoft.Compute/skus', '/subscriptions/s1', $Name, 'eastus', '', '', '', $Details,
                    'Azure Resource Manager', 'Microsoft', 'ComputeResourceSku', '1.0') -replace '"', '""' -replace '(?s)^(.+)\z', '"$1"') -join ','
        }
        $environmentNames = @('IDENTITY_ENDPOINT', 'IDENTITY_HEADER', 'AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'HUB_STORAGE_ACCOUNT',
            'EXPORT_STORAGE_ACCOUNT', 'HUB_SETTINGS_CONTAINER', 'HUB_SETTINGS_FILE')
    }

    BeforeEach {
        $savedEnvironment = @{}
        foreach ($name in $environmentNames) {
            $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, 'quota-fixture')
        }
        $env:IDENTITY_ENDPOINT = 'https://quota-fixture.invalid/token'
        $publication = @{
            Uploads = [Collections.Generic.List[object]]::new()
            Header = $fixtureHeader
            Rows = @((New-FixtureRow), (New-FixtureRow -Name ('comma, "quote" ' + [char]0xe9 + "`nnewline")))
            RepeatCount = 1; CollectionFinished = $false; FailCollection = $false
            FailCsvNumber = 0; FailManifest = $false; LargeFixture = $false
        }
        $fixtureDirectory = Join-Path $TestDrive 'CollectQuota'
        $null = New-Item -ItemType Directory -Path $fixtureDirectory -Force
        $runnerPath = Join-Path $fixtureDirectory 'run.ps1'
        $runnerSource.Replace('$quotaFileSizeBytes = 128MB', '$quotaFileSizeBytes = 1024') |
            Set-Content -LiteralPath $runnerPath -Encoding utf8NoBOM
        Mock Import-Module {}
        Mock Invoke-RestMethod { @{ access_token = 'fixture-token' } }
        Mock Get-SavingsPlanRecommendations {}
        Mock Get-AzVMQuotaUsage {
            $publication.Header
            for ($repeat = 0; $repeat -lt $publication.RepeatCount; $repeat++) {
                foreach ($row in $publication.Rows) { $row }
            }
            if ($publication.FailCollection) { throw [OutOfMemoryException]::new('Collector OOM fixture') }
            $publication.CollectionFinished = $true
        }
        Mock Invoke-WebRequest {
            param($Uri, $InFile, $ContentType)
            if (-not $InFile) {
                return @{ Content = [Text.Encoding]::UTF8.GetBytes('{"scopes":[]}'); Headers = @{ ETag = 'fixture-etag' } }
            }
            foreach ($previous in $publication.Uploads | Where-Object { $_.ContentType -eq 'text/csv' }) {
                Test-Path -LiteralPath $previous.Path | Should -BeFalse -Because 'completed CSVs must be deleted before another upload'
            }
            $bytes = (Get-Item -LiteralPath $InFile).Length
            $hash = (Get-FileHash -LiteralPath $InFile -Algorithm SHA256).Hash.ToLowerInvariant()
            $content = if ($ContentType -eq 'application/json' -or -not $publication.LargeFixture) { [IO.File]::ReadAllText($InFile) } else { $null }
            $publication.Uploads.Add([pscustomobject]@{
                Uri = $Uri; Path = $InFile; Bytes = $bytes; Hash = $hash; Content = $content; ContentType = $ContentType
                DuringCollection = -not $publication.CollectionFinished
            })
            $csvCount = @($publication.Uploads | Where-Object { $_.ContentType -eq 'text/csv' }).Count
            if ($ContentType -eq 'text/csv' -and $csvCount -eq $publication.FailCsvNumber) { throw 'CSV upload fixture failure' }
            if ($ContentType -eq 'application/json' -and $publication.FailManifest) { throw 'Manifest upload fixture failure' }
            @{ StatusCode = 201 }
        }
    }

    AfterEach {
        foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    }

    It 'uploads and deletes completed files during collection, preserving bytes and one manifest last' {
        $publication.RepeatCount = 8
        & $runnerPath
        $csvs = @($publication.Uploads | Where-Object { $_.ContentType -eq 'text/csv' })
        $csvs.Count | Should -BeGreaterThan 1
        @($csvs | Where-Object DuringCollection).Count | Should -BeGreaterThan 0
        @($publication.Uploads | Where-Object { $_.ContentType -eq 'application/json' }).Count | Should -Be 1
        $publication.Uploads[-1].ContentType | Should -Be 'application/json'
        $manifest = $publication.Uploads[-1].Content | ConvertFrom-Json
        $manifest.blobCount | Should -Be $csvs.Count
        $manifest.dataRowCount | Should -Be 16
        $manifest.byteCount | Should -Be ($csvs | Measure-Object Bytes -Sum).Sum
        $manifest.exportConfig.type | Should -Be 'Quota'
        $manifest.exportConfig.resourceId | Should -Be '/tenants/quota-fixture/providers/Microsoft.CostManagement/exports/Quota'
        for ($index = 0; $index -lt $csvs.Count; $index++) {
            $csvs[$index].Bytes | Should -BeLessOrEqual 1024
            $manifest.blobs[$index].sha256 | Should -Be $csvs[$index].Hash
            $manifest.blobs[$index].byteCount | Should -Be $csvs[$index].Bytes
            $manifest.blobs[$index].blobName | Should -BeLike "quota/$($manifest.runInfo.runId)/Quota-*.csv"
        }
        $actualRows = @($csvs | ForEach-Object { $_.Content | ConvertFrom-Csv })
        $actualRows.Count | Should -Be 16
        $actualRows[1].ResourceName | Should -Be ('comma, "quote" ' + [char]0xe9 + "`nnewline")
        $actualRows[0].currentValue | Should -BeNullOrEmpty
        $csvs[0].Content | Should -Match ',,,,'
        foreach ($file in $publication.Uploads) { Test-Path -LiteralPath $file.Path | Should -BeFalse }
    }

    It 'rolls over at the exact UTF-8 byte limit without a trailing empty file' {
        $publication.Rows = @((New-FixtureRow -Name ([string][char]0xe9)))
        $publication.RepeatCount = 4
        $encoding = [Text.Encoding]::UTF8
        $limit = $encoding.GetByteCount($fixtureHeader + [Environment]::NewLine) +
            2 * $encoding.GetByteCount($publication.Rows[0] + [Environment]::NewLine)
        $runnerSource.Replace('$quotaFileSizeBytes = 128MB', "`$quotaFileSizeBytes = $limit") |
            Set-Content -LiteralPath $runnerPath -Encoding utf8NoBOM
        & $runnerPath
        $csvs = @($publication.Uploads | Where-Object { $_.ContentType -eq 'text/csv' })
        $csvs.Count | Should -Be 2
        foreach ($csv in $csvs) { $csv.Bytes | Should -Be $limit }
        @(($publication.Uploads[-1].Content | ConvertFrom-Json).blobs.rowCount) | Should -Be @(2, 2)
    }

    It 'keeps zero-row output compatible without producing multiple header-only files' {
        $publication.Rows = @()
        & $runnerPath
        $publication.Uploads.Count | Should -Be 2
        ($publication.Uploads[-1].Content | ConvertFrom-Json).dataRowCount | Should -Be 0
        ($publication.Uploads[-1].Content | ConvertFrom-Json).blobCount | Should -Be 1
    }

    It 'does not publish a quota manifest after a CSV upload failure' {
        $publication.RepeatCount = 8
        $publication.FailCsvNumber = 2
        { & $runnerPath } | Should -Throw '*CSV upload fixture failure*'
        @($publication.Uploads | Where-Object { $_.ContentType -eq 'application/json' }).Count | Should -Be 0
        Test-Path -LiteralPath $publication.Uploads[0].Path | Should -BeFalse
    }

    It 'preserves the real collection error rather than reporting no files were produced' {
        $publication.RepeatCount = 8
        $publication.FailCollection = $true
        { & $runnerPath } | Should -Throw '*Collector OOM fixture*'
        @($publication.Uploads | Where-Object { $_.ContentType -eq 'application/json' }).Count | Should -Be 0
    }

    It 'does not hide a manifest upload failure' {
        $publication.FailManifest = $true
        { & $runnerPath } | Should -Throw '*Manifest upload fixture failure*'
    }

    It 'publishes savings plans independently when quota fails' {
        Mock Get-SavingsPlanRecommendations {
            param($RunId, $OutputDirectory)
            $blobName = "savings-plan/$RunId/fixture/SavingsPlan.csv"
            $path = Join-Path $OutputDirectory $blobName
            $null = New-Item -ItemType Directory -Path (Split-Path $path) -Force
            [IO.File]::WriteAllText($path, "name`nfixture`n")
            [pscustomobject]@{ CsvPath = $path; BlobName = $blobName; Rows = 1; Scope = '/providers/Microsoft.Billing/billingAccounts/fixture'; Partition = 'fixture' }
        }
        $publication.FailCollection = $true
        { & $runnerPath } | Should -Throw '*Collector OOM fixture*'
        $manifests = @($publication.Uploads | Where-Object { $_.ContentType -eq 'application/json' })
        $manifests.Count | Should -Be 1
        ($manifests[0].Content | ConvertFrom-Json).exportConfig.type | Should -Be 'Recommendations'
    }

    It 'rejects a single oversized row before creating a massive CSV' {
        $publication.Rows = @((New-FixtureRow -Name ('x' * 2048)))
        { & $runnerPath } | Should -Throw '*row exceeds*'
        $publication.Uploads.Count | Should -Be 0
    }

    It 'uploads more than the Flex temporary-storage allowance while retaining only one 128 MiB CSV locally' {
        $runnerSource | Set-Content -LiteralPath $runnerPath -Encoding utf8NoBOM
        $publication.Rows = @((New-FixtureRow -Details ('{"payload":"' + ('x' * 512KB) + '"}')))
        $publication.RepeatCount = 1792
        $publication.LargeFixture = $true
        & $runnerPath
        $csvs = @($publication.Uploads | Where-Object { $_.ContentType -eq 'text/csv' })
        ($csvs | Measure-Object Bytes -Sum).Sum | Should -BeGreaterThan 0.8GB
        foreach ($csv in $csvs) { $csv.Bytes | Should -BeLessOrEqual 128MB }
        ($publication.Uploads[-1].Content | ConvertFrom-Json).dataRowCount | Should -Be 1792
        $csvs.Count | Should -Be 8
        Write-Host "Production-size file fixture: $($csvs.Count) CSVs, $(($csvs | Measure-Object Bytes -Sum).Sum) total bytes, $((($csvs | Measure-Object Bytes -Maximum).Maximum)) maximum local CSV bytes; network uploads mocked."
    }
}
