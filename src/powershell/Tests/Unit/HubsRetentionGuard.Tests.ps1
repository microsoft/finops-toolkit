# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for the settings.json retention guard (#2206):
    Copy-FileToAzureBlob.ps1 unconditionally overwrote retention.ingestion.months / retention.final.months
    with whatever the deploymentScript's Bicep parameters passed in. Bicep always resolves a value for an
    optional parameter (defaulting to 13 if the caller didn't specify one), so the script cannot tell an
    explicit redeploy value from a silently-defaulted one. A redeploy that omitted a previously-customized
    retention value therefore silently reset it to the toolkit default, and the next purge pipeline run
    aged out historical data older than the new (lower) cutoff -- oldest data first.

    The fix: a value already stored in settings.json is kept on redeploy. The requested value only applies
    when nothing is stored yet (new hub, or settings.json from before retention existed).

    These tests run the real script with stubbed Az cmdlets and assert on the JSON it uploads.
#>

Describe 'HubsRetentionGuard' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/Copy-FileToAzureBlob.ps1'

        function Invoke-CopyScript
        {
            param([string] $ExistingJson, [int] $Ingestion, [int] $Final)

            $workDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $workDir | Out-Null
            $existingJson = $ExistingJson

            function New-AzStorageContext { param($StorageAccountName, [switch] $UseConnectedAccount) 'ctx' }
            function Get-AzStorageBlobContent
            {
                param($Context, $Container, $Blob, $Destination, [switch] $Force)
                if ($null -eq $existingJson) { return $null }
                Set-Content -Path $Destination -Value $existingJson
                return 'blob'
            }
            function Set-AzStorageBlobContent { param($Context, $Container, $File, [switch] $Force) }

            $env:storageAccountName = 'sa'
            $env:containerName = 'config'
            $env:scopes = ''
            $env:ftkVersion = '0.0.0'
            $env:msexportRetentionInDays = '0'
            $env:rawRetentionInDays = '0'
            $env:ingestionRetentionInMonths = "$Ingestion"
            $env:finalRetentionInMonths = "$Final"

            Push-Location $workDir
            try
            {
                & $scriptPath *> $null
                # The script writes the final settings.json to the working directory before uploading it
                return (Get-Content -Path (Join-Path $workDir settings.json) -Raw | ConvertFrom-Json)
            }
            finally { Pop-Location; Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'Existing settings.json' {

        It 'Should keep a stored value that is higher than the requested one' {
            $r = Invoke-CopyScript -ExistingJson '{"version":"","scopes":[],"retention":{"msexports":{"days":0},"ingestion":{"months":36},"raw":{"days":0},"final":{"months":60}}}' -Ingestion 13 -Final 13
            $r.retention.ingestion.months | Should -Be 36 -Because 'a redeploy without an explicit value must not reset customized retention (#2206)'
            $r.retention.final.months | Should -Be 60
        }

        It 'Should keep a stored value that is lower than the requested one' {
            $r = Invoke-CopyScript -ExistingJson '{"version":"","scopes":[],"retention":{"msexports":{"days":0},"ingestion":{"months":6},"raw":{"days":0},"final":{"months":6}}}' -Ingestion 13 -Final 13
            $r.retention.ingestion.months | Should -Be 6 -Because 'a stored value is never changed on redeploy'
            $r.retention.final.months | Should -Be 6
        }

        It 'Should seed retention from the request when settings.json predates retention' {
            $r = Invoke-CopyScript -ExistingJson '{"version":"","scopes":[]}' -Ingestion 24 -Final 30
            $r.retention.ingestion.months | Should -Be 24
            $r.retention.final.months | Should -Be 30
        }
    }

    Context 'First deploy' {

        It 'Should honor the requested retention when no settings.json exists' {
            $r = Invoke-CopyScript -ExistingJson $null -Ingestion 6 -Final 8
            $r.retention.ingestion.months | Should -Be 6 -Because 'there is no stored value to protect on a brand-new hub'
            $r.retention.final.months | Should -Be 8
        }
    }
}
