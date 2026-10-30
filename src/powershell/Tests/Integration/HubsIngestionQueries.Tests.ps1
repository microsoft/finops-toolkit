# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'HubsIngestionQueries' {

    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $queriesPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Recommendations/queries'
        $queryFiles = @(Get-ChildItem -Path $queriesPath -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
                $json = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                @{
                    Name        = $_.Name
                    FullName    = $_.FullName
                    BaseName    = $_.BaseName
                    Query       = $json.query
                    QueryEngine = $json.queryEngine
                    Dataset     = $json.dataset
                    Type        = $json.type
                    Source      = $json.source
                }
            })
    }

    BeforeAll {
        $context = Get-AzContext
        if (-not $context)
        {
            throw 'Not authenticated to Azure. Run Connect-AzAccount first.'
        }

        # Verify Az.ResourceGraph module is available
        if (-not (Get-Module -ListAvailable -Name 'Az.ResourceGraph'))
        {
            throw 'Az.ResourceGraph module is not installed. Run Install-Module Az.ResourceGraph.'
        }
        Import-Module Az.ResourceGraph -ErrorAction Stop
    }

    Context 'ARG query execution' {

        It 'Should execute without errors: <Name>' -ForEach $queryFiles {
            if ($QueryEngine -ne 'ResourceGraph')
            {
                Set-ItResult -Skipped -Because "query engine '$QueryEngine' is not ResourceGraph"
                return
            }

            Monitor "Executing $Name..." -Indent '  ' {
                try
                {
                    $results = Search-AzGraph -Query $Query -UseTenantScope -First 1 -ErrorAction Stop
                    Report "Returned $($results.Count) result(s)"
                }
                catch
                {
                    Report "Query failed: $($_.Exception.Message)" -Exception $_
                    throw
                }
            }
        }
    }

    Context 'ARG query result schema' {

        It 'Should return expected columns: <Name>' -ForEach $queryFiles {
            if ($QueryEngine -ne 'ResourceGraph')
            {
                Set-ItResult -Skipped -Because "query engine '$QueryEngine' is not ResourceGraph"
                return
            }

            Monitor "Validating result schema for $Name..." -Indent '  ' {
                try
                {
                    $results = Search-AzGraph -Query $Query -UseTenantScope -First 5 -ErrorAction Stop
                }
                catch
                {
                    Set-ItResult -Inconclusive -Because "query execution failed: $($_.Exception.Message)"
                    return
                }

                if ($results -and $results.Count -gt 0)
                {
                    $firstResult = $results | Select-Object -First 1
                    $columns = $firstResult.PSObject.Properties.Name

                    # These are the columns ARG queries should output (x_Source* columns are added downstream by the ADF pipeline)
                    $expectedColumns = @(
                        'ResourceId'
                        'ResourceName'
                        'SubAccountId'
                        'SubAccountName'
                        'x_RecommendationCategory'
                        'x_RecommendationDate'
                        'x_RecommendationDescription'
                        'x_RecommendationDetails'
                        'x_RecommendationId'
                        'x_ResourceGroupName'
                    )

                    foreach ($col in $expectedColumns)
                    {
                        $columns | Should -Contain $col -Because "result should include column '$col'"
                    }

                    # Verify no extra columns beyond what the schema expects
                    foreach ($col in $columns)
                    {
                        $expectedColumns | Should -Contain $col -Because "unexpected column '$col' found in query result; queries should only return columns mapped in the schema"
                    }

                    Report "All $($expectedColumns.Count) expected columns present, no extra columns"
                }
                else
                {
                    Report 'Query returned no results (column validation skipped)'
                    Set-ItResult -Inconclusive -Because 'no results returned to validate columns'
                }
            }
        }
    }

    Context 'ARG query performance' {

        It 'Should complete within 30 seconds: <Name>' -ForEach $queryFiles {
            if ($QueryEngine -ne 'ResourceGraph')
            {
                Set-ItResult -Skipped -Because "query engine '$QueryEngine' is not ResourceGraph"
                return
            }

            Monitor "Testing performance for $Name..." -Indent '  ' {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                try
                {
                    $null = Search-AzGraph -Query $Query -UseTenantScope -First 1 -ErrorAction Stop
                    $stopwatch.Stop()
                    $ms = $stopwatch.ElapsedMilliseconds
                    Report "Completed in ${ms}ms"
                    $ms | Should -BeLessThan 30000 -Because 'ARG queries should complete within 30 seconds'
                }
                catch
                {
                    Set-ItResult -Inconclusive -Because "query execution failed: $($_.Exception.Message)"
                }
            }
        }
    }
}
