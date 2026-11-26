# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Sets up a local FinOps hub in a running Kusto emulator.

    .DESCRIPTION
    The Initialize-FinOpsHubLocal command configures a local FinOps hub in a running Kusto emulator. It creates the Ingestion and Hub databases, then downloads and applies the released FinOps hub setup scripts and open data load script so the local hub uses the same KQL, transforms, and open data as a deployed hub.

    This command does not install Docker or manage the emulator container. Start the emulator first, then run this command against its endpoint. It does not ingest cost data; stage and ingest your own exports after setup.

    Database storage paths assume the emulator's default data root (/kustodata), matching the container setup in the "Run FinOps hubs locally" guide. If your emulator mounts data elsewhere, create the Ingestion and Hub databases manually before running this command.

    .PARAMETER ClusterUri
    Optional. Base URI of the running Kusto emulator. Default = http://localhost:8082.

    .PARAMETER ReleaseUri
    Optional. Base URI to download the setup scripts and open data load script from. Default = the latest FinOps toolkit GitHub release. Point this at a local file server or a specific release to run offline or pin a version.

    .PARAMETER RawRetentionInDays
    Optional. Number of days to keep raw data in the Ingestion database. Default = 90.

    .PARAMETER OpenDataPath
    Optional. Path, as seen by the emulator, to the folder that holds the open data CSV files. Default = /data/export/open-data.

    .PARAMETER SkipOpenData
    Optional. Skips loading the open data reference tables. Default = false.

    .PARAMETER Destination
    Optional. Local folder used to download the setup scripts. Default = temp folder.

    .PARAMETER TimeoutSec
    Optional. Maximum number of seconds to wait for each emulator request or asset download. Default = 30. Use 0 to wait indefinitely (for example, on slow hardware).

    .EXAMPLE
    Initialize-FinOpsHubLocal

    Sets up a local FinOps hub in the emulator at http://localhost:8082 using the latest release.

    .EXAMPLE
    Initialize-FinOpsHubLocal -ClusterUri 'http://localhost:8082' -RawRetentionInDays 30 -SkipOpenData

    Sets up the databases and schema with 30-day raw retention and skips loading open data.

    .LINK
    https://aka.ms/ftk/Initialize-FinOpsHubLocal
#>
function Initialize-FinOpsHubLocal
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClusterUri = 'http://localhost:8082',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseUri = 'https://github.com/microsoft/finops-toolkit/releases/latest/download',

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $RawRetentionInDays = 90,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $OpenDataPath = '/data/export/open-data',

        [Parameter()]
        [switch]
        $SkipOpenData,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination = [System.IO.Path]::GetTempPath(),

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $TimeoutSec = 30
    )

    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try
    {
        # Verify the emulator is reachable. This command does not start the container.
        try
        {
            $null = Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'NetDefaultDB' -Command '.show version' -TimeoutSec $TimeoutSec
        }
        catch
        {
            throw ($script:LocalizedData.HubLocal_Initialize_NotReachable -f $ClusterUri)
        }

        # Download the required release assets by name from the release URI.
        $assetNames = @('finops-hub-fabric-setup-Ingestion.kql', 'finops-hub-fabric-setup-Hub.kql')
        if (-not $SkipOpenData)
        {
            $assetNames += 'finops-hub-local-opendata.kql'
        }

        $scripts = @{}
        if ($PSCmdlet.ShouldProcess($Destination, 'Download release assets'))
        {
            New-Directory -Path $Destination
            foreach ($assetName in $assetNames)
            {
                $filePath = Join-Path -Path $Destination -ChildPath $assetName
                try
                {
                    $null = Invoke-WebRequest -Uri "$($ReleaseUri.TrimEnd('/'))/$assetName" -OutFile $filePath -TimeoutSec $TimeoutSec -Verbose:$false -ErrorAction 'Stop'
                }
                catch
                {
                    throw ($script:LocalizedData.HubLocal_Initialize_DownloadFailed -f $assetName, $ReleaseUri)
                }

                $scripts[$assetName] = Get-Content -Path $filePath -Raw
                if ([string]::IsNullOrWhiteSpace($scripts[$assetName]))
                {
                    throw ($script:LocalizedData.HubLocal_Initialize_AssetEmpty -f $assetName, $ReleaseUri)
                }
            }
        }

        # Create the Ingestion and Hub databases. Uses create-merge so re-running this command
        # (for example, after a failed setup step) does not fail if the databases already exist.
        foreach ($database in @('Ingestion', 'Hub'))
        {
            $createCommand = '.create-merge database {0} persist (@"/kustodata/dbs/{0}/md", @"/kustodata/dbs/{0}/data")' -f $database
            if ($PSCmdlet.ShouldProcess($database, 'Create database'))
            {
                $null = Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'NetDefaultDB' -Command $createCommand -TimeoutSec $TimeoutSec
            }
        }

        # Apply the Ingestion setup with the requested raw retention. Uses .Replace() (not -replace)
        # since the replacement value flows into the replacement string, where -replace would treat
        # sequences like $1 or $& as regex substitution tokens instead of literal text.
        if ($PSCmdlet.ShouldProcess('Ingestion', 'Apply setup script'))
        {
            if (-not $scripts.ContainsKey('finops-hub-fabric-setup-Ingestion.kql'))
            {
                throw ($script:LocalizedData.HubLocal_Initialize_ScriptsNotDownloaded -f 'Ingestion setup')
            }

            $ingestionScript = $scripts['finops-hub-fabric-setup-Ingestion.kql'].Replace('$$rawRetentionInDays$$', $RawRetentionInDays.ToString())
            $null = Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'Ingestion' -Command $ingestionScript -TimeoutSec $TimeoutSec
        }

        # Apply the Hub setup
        if ($PSCmdlet.ShouldProcess('Hub', 'Apply setup script'))
        {
            if (-not $scripts.ContainsKey('finops-hub-fabric-setup-Hub.kql'))
            {
                throw ($script:LocalizedData.HubLocal_Initialize_ScriptsNotDownloaded -f 'Hub setup')
            }

            $null = Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'Hub' -Command $scripts['finops-hub-fabric-setup-Hub.kql'] -TimeoutSec $TimeoutSec
        }

        # Load the open data reference tables
        if (-not $SkipOpenData)
        {
            if ($PSCmdlet.ShouldProcess('Ingestion', 'Load open data'))
            {
                if (-not $scripts.ContainsKey('finops-hub-local-opendata.kql'))
                {
                    throw ($script:LocalizedData.HubLocal_Initialize_ScriptsNotDownloaded -f 'open data load')
                }

                $openDataScript = $scripts['finops-hub-local-opendata.kql'].Replace('$$openDataPath$$', $OpenDataPath)

                # The emulator's first external data read after setup can return no rows without
                # raising an error. Load, verify the tables filled, and retry before giving up.
                $openDataTables = @('PricingUnits', 'Regions', 'ResourceTypes', 'Services')
                $maxAttempts = 5
                for ($attempt = 1; $attempt -le $maxAttempts; $attempt++)
                {
                    $null = Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'Ingestion' -Command $openDataScript -TimeoutSec $TimeoutSec
                    $empty = @($openDataTables | Where-Object {
                            [int64](Invoke-FinOpsHubLocalCommand -ClusterUri $ClusterUri -Database 'Ingestion' -Command "$_ | count" -Endpoint 'query' -TimeoutSec $TimeoutSec).Tables[0].Rows[0][0] -eq 0
                        })

                    if ($empty.Count -eq 0)
                    {
                        break
                    }

                    if ($attempt -eq $maxAttempts)
                    {
                        throw ($script:LocalizedData.HubLocal_Initialize_OpenDataEmpty -f $maxAttempts, ($empty -join ', '))
                    }

                    Start-Sleep -Seconds 2
                }
            }
        }
    }
    finally
    {
        $ProgressPreference = $progress
    }
}
