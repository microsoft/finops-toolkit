# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $quotaPath = Join-Path $PSScriptRoot '../../../../src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota'
    Add-Type -Path (Join-Path $quotaPath 'CollectQuota/QuotaBlobStream.cs')
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $quotaPath 'CollectQuota/run.ps1'), [ref]$null, [ref]$null)
    $manifestFunction = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Write-Manifest'
    }, $false)
    . ([scriptblock]::Create($manifestFunction.Extent.Text))
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
public sealed class QuotaTestHandler : HttpMessageHandler
{
    private readonly IncrementalHash hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
    public readonly List<byte[]> Blocks = new List<byte[]>();
    public readonly List<string> BlockIds = new List<string>();
    public bool RetainBlocks = true;
    public int Status = 201;
    public int Commits;
    public int Requests;
    public int MaximumBlockBytes;
    public long Bytes;
    public string CommitXml;
    public bool CommitHasCreateCondition;
    public bool CommitHasCsvType;
    public bool RequiredHeaders = true;
    public string Sha256 => Convert.ToHexString(hash.GetCurrentHash()).ToLowerInvariant();
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests++;
        RequiredHeaders &= request.Method == HttpMethod.Put &&
            request.Headers.Authorization?.Scheme == "Bearer" &&
            request.Headers.Contains("x-ms-version") && request.Headers.Contains("x-ms-date");
        byte[] body = await request.Content.ReadAsByteArrayAsync(cancellationToken);
        if (request.RequestUri.Query.StartsWith("?comp=blocklist"))
        {
            Commits++;
            CommitXml = Encoding.UTF8.GetString(body);
            CommitHasCreateCondition = request.Headers.IfNoneMatch.ToString() == "*";
            CommitHasCsvType = request.Headers.Contains("x-ms-blob-content-type") &&
                string.Join("", request.Headers.GetValues("x-ms-blob-content-type")) == "text/csv";
        }
        else
        {
            BlockIds.Add(Uri.UnescapeDataString(request.RequestUri.Query.Split("blockid=")[1]));
            MaximumBlockBytes = Math.Max(MaximumBlockBytes, body.Length);
            Bytes += body.Length;
            hash.AppendData(body);
            if (RetainBlocks) Blocks.Add(body);
        }
        var response = new HttpResponseMessage((HttpStatusCode)Status);
        if (Status != 201) response.Headers.Add("x-ms-error-code", "SimulatedStorageFailure");
        return response;
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) hash.Dispose();
        base.Dispose(disposing);
    }
}
'@
}

Describe 'HubsQuotaBlobStream' {
    BeforeEach {
        $handler = [QuotaTestHandler]::new()
        $client = [Net.Http.HttpClient]::new($handler)
        $state = @{ Tokens = 0 }
        $provider = [Func[securestring]]({ $state.Tokens++; ConvertTo-SecureString 'test-token' -AsPlainText -Force }.GetNewClosure())
        $stream = [FinOpsToolkit.QuotaBlobStream]::new([uri]'https://example.blob.core.windows.net/msexports/quota/run/Quota.csv',
            $provider, $client, 32)
    }
    AfterEach {
        $stream.Dispose()
        $client.Dispose()
    }

    It 'Stages exact UTF-8 CSV bytes and commits one ordered blob only after explicit completion' {
        $csv = "ProviderName,currentValue,limit,x_QuotaDetails$([Environment]::NewLine)" +
            "`"Microsoft.Compute`",,,`"{`"`"Name`"`":`"`"caf$([char]0xE9)`"`"}`"$([Environment]::NewLine)"
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($csv)
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false), 16, $true)
        $writer.Write($csv)
        $writer.Dispose()
        $handler.Commits | Should -Be 0
        $stream.Length | Should -Be $bytes.Length
        $stream.Complete()
        $combined = [Collections.Generic.List[byte]]::new()
        foreach ($block in $handler.Blocks) { $combined.AddRange($block) }
        [Convert]::ToBase64String($combined.ToArray()) | Should -Be ([Convert]::ToBase64String($bytes))
        $stream.Sha256 | Should -Be ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant())
        $handler.Sha256 | Should -Be $stream.Sha256
        $handler.MaximumBlockBytes | Should -BeLessOrEqual 32
        $handler.Commits | Should -Be 1
        @(([xml]$handler.CommitXml).BlockList.Uncommitted) | Should -Be @($handler.BlockIds)
        $handler.RequiredHeaders | Should -BeTrue
        $handler.CommitHasCreateCondition | Should -BeTrue
        $handler.CommitHasCsvType | Should -BeTrue
        $state.Tokens | Should -Be ($stream.BlockCount + 1)
        { $stream.Complete() } | Should -Throw '*completed or failed*'
    }

    It 'Does not publish incomplete data when disposed' {
        $bytes = [Text.Encoding]::UTF8.GetBytes(('x' * 80))
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $stream.Dispose()
        $handler.Blocks.Count | Should -Be 2
        $handler.Commits | Should -Be 0
        $stream.Sha256 | Should -BeNullOrEmpty
    }

    It 'Propagates block upload failure and prevents a later commit' {
        $handler.Status = 403
        $bytes = [byte[]]::new(64)
        { $stream.Write($bytes, 0, $bytes.Length) } | Should -Throw '*HTTP 403*SimulatedStorageFailure*'
        $handler.Status = 201
        { $stream.Complete() } | Should -Throw '*completed or failed*'
        $handler.Commits | Should -Be 0
    }

    It 'Propagates commit failure without returning a successful hash' {
        $bytes = [byte[]]::new(32)
        $stream.Write($bytes, 0, $bytes.Length)
        $handler.Status = 412
        { $stream.Complete() } | Should -Throw '*HTTP 412*'
        $stream.Sha256 | Should -BeNullOrEmpty
        $stream.CanWrite | Should -BeFalse
    }

    It 'Propagates token renewal failure without publishing a CSV' {
        $stream.Dispose()
        $stream = [FinOpsToolkit.QuotaBlobStream]::new([uri]'https://example.blob.core.windows.net/msexports/quota/run/Quota.csv',
            [Func[securestring]]{ throw 'Storage token renewal failed' }, $client, 32)
        $bytes = [byte[]]::new(32)
        { $stream.Write($bytes, 0, $bytes.Length) } | Should -Throw '*Storage token renewal failed*'
        $handler.Requests | Should -Be 0
        { $stream.Complete() } | Should -Throw '*completed or failed*'
    }

    It 'Streams more than the Flex temporary storage limit with blocks no larger than 8 MiB' {
        $stream.Dispose()
        $handler.RetainBlocks = $false
        $stream = [FinOpsToolkit.QuotaBlobStream]::new([uri]'https://example.blob.core.windows.net/msexports/quota/run/Quota.csv',
            $provider, $client)
        $bytes = [byte[]]::new(8MB)
        foreach ($i in 1..110) { $stream.Write($bytes, 0, $bytes.Length) }
        $handler.Commits | Should -Be 0
        $stream.Complete()
        $stream.Length | Should -Be (880MB)
        $handler.Bytes | Should -Be $stream.Length
        $handler.MaximumBlockBytes | Should -Be (8MB)
        $stream.BlockCount | Should -Be 110
        $handler.Blocks.Count | Should -Be 0
        $handler.Sha256 | Should -Be $stream.Sha256
        $handler.Commits | Should -Be 1
    }

    It 'Uses streamed counts and hash in the existing tenant manifest without reading a local CSV' {
        $runId = '20261002T190000Z'
        $started = [datetime]'2026-10-02T19:00:00Z'
        $hash = 'a' * 64
        $csvPath = Join-Path $TestDrive 'Quota.csv'
        $file = Write-Manifest -CsvPath $csvPath -BlobName "quota/$runId/Quota.csv" -RowCount 3000000000 `
            -ByteCount 9000000000 -Sha256 $hash -Uploaded -Scope '/tenants/test-tenant' -Type Quota -Version '1.0' -ExportName Quota
        Test-Path $csvPath | Should -BeFalse
        $manifest = Get-Content $file.ManifestPath -Raw | ConvertFrom-Json
        $manifest.blobCount | Should -Be 1
        $manifest.dataRowCount | Should -Be 3000000000
        $manifest.byteCount | Should -Be 9000000000
        $manifest.blobs[0].byteCount | Should -Be $manifest.byteCount
        $manifest.blobs[0].rowCount | Should -Be $manifest.dataRowCount
        $manifest.blobs[0].sha256 | Should -Be $hash
        $manifest.blobs[0].blobName | Should -Be "quota/$runId/Quota.csv"
        $manifest.runInfo.runId | Should -Be $runId
        $manifest.exportConfig.resourceId | Should -Be '/tenants/test-tenant/providers/Microsoft.CostManagement/exports/Quota'
        $file.Uploaded | Should -BeTrue
    }

    It 'Includes the stream helper in the Function package and publishes manifests after the CSV commit' {
        $template = Get-Content (Join-Path $quotaPath 'app.bicep') -Raw
        $runner = Get-Content (Join-Path $quotaPath 'CollectQuota/run.ps1') -Raw
        $template | Should -Match "'CollectQuota/QuotaBlobStream.cs': loadTextContent"
        $runner | Should -Match '-OutputStream \$quotaStream'
        $runner | Should -Not -Match '\[IO.File\]::ReadLines\(\$quotaCsvPath\)'
        $runner.IndexOf('$quotaStream.Complete()') | Should -BeLessThan ($runner.IndexOf('-ByteCount $quota.Bytes'))
        $runner | Should -Match 'Where-Object \{ -not \$_.Uploaded \}'
        $runner | Should -Match '\-Sha256 \$quotaStream.Sha256 \-Uploaded'
    }
}
