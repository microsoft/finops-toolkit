#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Standalone chunked backfill for Prices_final_v1_2.

.DESCRIPTION
    Recovery backfill for Prices_transform_v1_2. Dot-sources ingest.ps1 and
    backfills Prices_final_v1_2 from Prices_raw one extent at a time, with the same
    update-policy disable/restore and Rosetta crash retry behavior as ingest.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ingest.ps1')

function Get-TableCount {
    param([Parameter(Mandatory)] [string] $TableName)
    $postResult = Invoke-KustoPost -CslText "$TableName | count" -EndpointUrl $script:KustainerQuery -TimeoutSec 60
    if ($postResult.Status -ge 200 -and $postResult.Status -lt 300) {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        return [int64](Get-PrimaryRows $jsonObject)[0][0]
    }
    return -1
}

function Invoke-ChunkedPricesBackfillMain {
    Write-InfoLine ("Before: Prices_final_v1_2 = {0:N0}" -f (Get-TableCount -TableName 'Prices_final_v1_2'))
    $savedPolicies = Disable-UpdatePolicies
    Write-InfoLine "Disabled update policies on $($savedPolicies.Count) table(s)"
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $result = Invoke-ChunkedBackfillFinalTable -RawTableName 'Prices_raw' -FinalTableName 'Prices_final_v1_2' -TransformFunctionName 'Prices_transform_v1_2' -ExtentsPerBatch 1
    }
    finally {
        Restore-UpdatePolicies -SavedPolicies $savedPolicies
    }
    $stopwatch.Stop()
    $afterCount = Get-TableCount -TableName 'Prices_final_v1_2'
    Write-InfoLine ("After: Prices_final_v1_2 = {0:N0}" -f $afterCount)
    Write-InfoLine ("Wall-clock: {0:N1}s ({1:N1} min). OK={2}, reported_rows={3:N0}" -f $stopwatch.Elapsed.TotalSeconds, ($stopwatch.Elapsed.TotalSeconds / 60.0), $result.Ok, $result.Rows)
    if ($result.Ok) { return 0 }
    return 1
}

exit (Invoke-ChunkedPricesBackfillMain)
