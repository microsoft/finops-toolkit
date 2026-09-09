# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Checks whether FinOps hubs still ingests the latest published Cost Management price sheet
    dataset schema versions.

    .DESCRIPTION
    FinOps hubs ingests specific Cost Management price sheet dataset schema versions via the
    schema mapping files under Microsoft.CostManagement/Exports/schemas and the Prices_raw /
    Prices_transform_* KQL in Microsoft.FinOpsHubs/Analytics. Microsoft can change the default
    price sheet schema version at any time -- for example, MCA moved from 2023-05-01 to
    2024-08-01 as its default (see https://github.com/microsoft/finops-toolkit/issues/2311) --
    and hubs silently fails to map exports using a version it doesn't know about.

    This test is informational only and must NEVER fail the build. It does a best-effort live
    check against the Microsoft Learn Cost Management dataset schema index and reports (via
    Write-Warning) when a price sheet schema version newer than what hubs supports is published,
    so a human can decide whether to add support. A network failure, an unparsable page, or a
    genuinely newer version are all reported as warnings, never as test failures -- this test
    can't block a PR or a release.
#>

Describe 'Price sheet schema version currency (non-blocking)' {

    BeforeDiscovery {
        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $schemasPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.CostManagement/Exports/schemas'

        # Price sheet dataset schema versions FinOps hubs currently has a schema mapping file
        # for (Microsoft.CostManagement/Exports/schemas/pricesheet_<version>_<ea|mca>.json) and
        # ingestion support for (Prices_raw / Prices_transform_* in Microsoft.FinOpsHubs/Analytics).
        # Update this list -- and add the corresponding mapping file and KQL support -- when
        # adding support for a new version.
        $supportedVersions = @{
            EA  = @('2023-05-01')
            MCA = @('2023-05-01', '2024-08-01')
        }

        $schemaIndexUri = 'https://learn.microsoft.com/azure/cost-management-billing/dataset-schema/schema-index'
    }

    It 'Should warn (never fail) when Microsoft publishes a price sheet schema version hubs does not support' {
        # IMPORTANT: This check is informational only and must NEVER fail CI or block a PR, even
        # when:
        #  - the network call fails (offline runner, DNS/proxy issue, docs site unavailable)
        #  - the docs page layout changes and a version can't be parsed out of it
        #  - a schema mapping file is unexpectedly missing for a version this test thinks is supported
        #  - a genuinely newer version has been published that hubs doesn't support yet
        # In every case, the finding is reported with Write-Warning and the test still passes.
        try
        {
            foreach ($contract in $supportedVersions.Keys)
            {
                foreach ($version in $supportedVersions[$contract])
                {
                    $mappingFile = Join-Path $schemasPath "pricesheet_${version}_$($contract.ToLower()).json"
                    if (-not (Test-Path -Path $mappingFile))
                    {
                        Write-Warning "FinOps hubs claims to support $contract price sheet schema '$version' but is missing the expected schema mapping file: $mappingFile"
                    }
                }
            }

            $response = Invoke-WebRequest -Uri $schemaIndexUri -UseBasicParsing -TimeoutSec 15

            # Collapse HTML to whitespace-separated text so a table row's cells (which may be
            # split across tags and lines in the source) read in order, e.g.:
            # "Price sheet MCA 2024-08-01"
            $text = ($response.Content -replace '<[^>]+>', ' ') -replace '\s+', ' '

            foreach ($contract in 'EA', 'MCA')
            {
                $match = [regex]::Match($text, "Price sheet\s+$contract\s+(\d{4}-\d{2}-\d{2})")
                if (-not $match.Success)
                {
                    Write-Warning "Could not find a $contract price sheet dataset version on $schemaIndexUri -- the page layout may have changed. Check manually against https://learn.microsoft.com/azure/cost-management-billing/dataset-schema/schema-index."
                    continue
                }

                $latestVersion = $match.Groups[1].Value
                if ($latestVersion -notin $supportedVersions[$contract])
                {
                    Write-Warning "Microsoft now publishes $contract price sheet schema '$latestVersion', which FinOps hubs doesn't ingest yet (currently supports: $($supportedVersions[$contract] -join ', ')). Consider adding a pricesheet_${latestVersion}_$($contract.ToLower()).json schema mapping file and corresponding KQL support. See https://learn.microsoft.com/azure/cost-management-billing/dataset-schema/schema-index."
                }
            }
        }
        catch
        {
            Write-Warning "Skipped the live price sheet schema version check -- could not reach or parse $($schemaIndexUri): $($_.Exception.Message)"
        }

        # This test is informational only: it must always pass, regardless of what was found above.
        $true | Should -BeTrue
    }
}
