# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for retention on redeploy and upgrade (#2206, #2348):
    - All retention parameters are nullable. The template only passes them to Copy-FileToAzureBlob.ps1 when the
      deployment specifies them. When omitted, the script keeps the value stored in settings.json (defaults for new
      hubs) and returns the effective raw value for the Data Explorer setup. Explicit values always apply.
    - IngestionSetup_RawTables.kql no longer sets raw retention to 0 days before applying the requested value.

    The script tests run the real script with stubbed Az cmdlets and assert on the JSON it writes and its outputs.
#>

Describe 'HubsRetentionRedeploy' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $scriptPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/Copy-FileToAzureBlob.ps1'
        $kqlPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/IngestionSetup_RawTables.kql'
        $retentionVars = 'msexportRetentionInDays', 'ingestionRetentionInMonths', 'rawRetentionInDays', 'finalRetentionInMonths'

        function Invoke-CopyScript
        {
            param([string] $ExistingJson, [string] $MsexportDays, [string] $IngestionMonths, [string] $RawDays, [string] $FinalMonths)

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
            $env:msexportRetentionInDays = $MsexportDays
            $env:ingestionRetentionInMonths = $IngestionMonths
            $env:rawRetentionInDays = $RawDays
            $env:finalRetentionInMonths = $FinalMonths

            Push-Location $workDir
            try
            {
                # Dot-source so $DeploymentScriptOutputs is visible to the test
                . $scriptPath *> $null
                return [PSCustomObject]@{
                    Settings = (Get-Content -Path (Join-Path $workDir settings.json) -Raw | ConvertFrom-Json)
                    Outputs  = $DeploymentScriptOutputs
                }
            }
            finally
            {
                Pop-Location
                Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
                $retentionVars | ForEach-Object { Remove-Item "env:$_" -ErrorAction SilentlyContinue }
            }
        }

        $existing = '{"version":"","scopes":[],"retention":{"msexports":{"days":7},"ingestion":{"months":36},"raw":{"days":30},"final":{"months":60}}}'
    }

    Context 'settings.json' {

        It 'Should keep stored values when retention is not specified' {
            $r = Invoke-CopyScript -ExistingJson $existing
            $r.Settings.retention.msexports.days | Should -Be 7 -Because 'a redeploy without exportRetentionInDays must not reset export retention (#2348)'
            $r.Settings.retention.ingestion.months | Should -Be 36 -Because 'a redeploy without ingestionRetentionInMonths must not reset ingestion retention (#2206)'
            $r.Settings.retention.raw.days | Should -Be 30 -Because 'a redeploy without dataExplorerRawRetentionInDays must not reset raw retention (#2348)'
            $r.Settings.retention.final.months | Should -Be 60 -Because 'a redeploy without dataExplorerFinalRetentionInMonths must not reset final retention (#2206)'
            $r.Outputs.rawRetentionInDays | Should -Be 30 -Because 'Data Explorer must reapply the stored raw retention'
        }

        It 'Should apply explicitly specified values, including lower values and 0' {
            $r = Invoke-CopyScript -ExistingJson $existing -MsexportDays '0' -IngestionMonths '6' -RawDays '0' -FinalMonths '12'
            $r.Settings.retention.msexports.days | Should -Be 0
            $r.Settings.retention.ingestion.months | Should -Be 6 -Because 'an intentional value always applies'
            $r.Settings.retention.raw.days | Should -Be 0
            $r.Settings.retention.final.months | Should -Be 12
            $r.Outputs.rawRetentionInDays | Should -Be 0
        }

        It 'Should use documented defaults for a new hub when retention is not specified' {
            $r = Invoke-CopyScript -ExistingJson $null
            $r.Settings.retention.msexports.days | Should -Be 0
            $r.Settings.retention.ingestion.months | Should -Be 13
            $r.Settings.retention.raw.days | Should -Be 0
            $r.Settings.retention.final.months | Should -Be 13
            $r.Outputs.rawRetentionInDays | Should -Be 0
        }

        It 'Should use requested values for a new hub' {
            $r = Invoke-CopyScript -ExistingJson $null -MsexportDays '5' -IngestionMonths '24' -RawDays '14' -FinalMonths '30'
            $r.Settings.retention.msexports.days | Should -Be 5
            $r.Settings.retention.ingestion.months | Should -Be 24
            $r.Settings.retention.raw.days | Should -Be 14
            $r.Settings.retention.final.months | Should -Be 30
            $r.Outputs.rawRetentionInDays | Should -Be 14
        }

        It 'Should seed defaults when settings.json predates retention' {
            $r = Invoke-CopyScript -ExistingJson '{"version":"","scopes":[]}'
            $r.Settings.retention.msexports.days | Should -Be 0
            $r.Settings.retention.ingestion.months | Should -Be 13
            $r.Settings.retention.raw.days | Should -Be 0
            $r.Settings.retention.final.months | Should -Be 13
        }

        It 'Should seed only missing values when settings.json is partial' {
            $r = Invoke-CopyScript -ExistingJson '{"version":"","scopes":[],"retention":{"ingestion":{"months":24},"final":{"months":48}}}'
            $r.Settings.retention.msexports.days | Should -Be 0
            $r.Settings.retention.ingestion.months | Should -Be 24
            $r.Settings.retention.raw.days | Should -Be 0
            $r.Settings.retention.final.months | Should -Be 48
        }
    }

    Context 'Raw table retention script' {

        It 'Should never set raw retention to 0 days before applying the requested value' {
            $kql = Get-Content -Path $kqlPath -Raw
            $kql | Should -Not -Match 'softdelete\s*=\s*0d' -Because 'reapplying 0d on every deploy can purge raw data (#2348)'
        }

        It 'Should set every raw table retention policy from the deployment value' {
            $kql = Get-Content -Path $kqlPath -Raw
            $policies = [regex]::Matches($kql, '(?m)^\.alter-merge table \w+_raw policy retention .*$')
            $policies.Count | Should -BeGreaterThan 0
            $policies | ForEach-Object { $_.Value | Should -Match 'softdelete = \$\$rawRetentionInDays\$\$d' }
        }
    }
}
