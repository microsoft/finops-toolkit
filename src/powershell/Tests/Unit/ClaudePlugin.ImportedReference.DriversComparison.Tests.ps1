# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $referencesRoot = Join-Path $repoRoot 'src/templates/claude-plugin/skills/finops-toolkit/references'
    $queryCatalogPath = Join-Path $referencesRoot 'queries/INDEX.md'
    $schemaGuidePath = Join-Path $referencesRoot 'queries/finops-hub-database-guide.md'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-FoundMarkers
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [hashtable]$Patterns
        )

        return @($Patterns.Keys | Where-Object {
                $Content -match $Patterns[$_]
            } | Sort-Object)
    }

    function Get-DriversComparisonCases
    {
        return @(
            [pscustomobject]@{
                Name = 'top-cost-drivers.md'
                Path = Join-Path $referencesRoot 'top-cost-drivers.md'
                RelevantQueries = @(
                    'costs-enriched-base',
                    'top-services-by-cost',
                    'cost-by-region-trend',
                    'cost-by-financial-hierarchy'
                )
            },
            [pscustomobject]@{
                Name = 'cost-comparison.md'
                Path = Join-Path $referencesRoot 'cost-comparison.md'
                RelevantQueries = @(
                    'costs-enriched-base',
                    'monthly-cost-change-percentage',
                    'cost-by-region-trend',
                    'cost-by-financial-hierarchy'
                )
            }
        ) | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Path = $_.Path
                Content = Get-TestFileContent -Path $_.Path
                RelevantQueries = $_.RelevantQueries
            }
        }
    }

    $queryIndexContent = Get-TestFileContent -Path $queryCatalogPath
    $schemaGuideContent = Get-TestFileContent -Path $schemaGuidePath
}

Describe 'Claude plugin drivers and comparison imported reference post-change validation' {
    # // T-1.15.2: RTM FR-7.1
    It 'FR7_1_AC1_DriversComparison_UsesFinOpsHubFields' {
        $finOpsHubFieldPatterns = [ordered]@{
            ServiceName = '\bServiceName\b'
            SubAccountName = '\bSubAccountName\b'
            RegionName = '\bRegionName\b'
            x_ResourceGroupName = '\bx_ResourceGroupName\b'
            x_BillingProfileName = '\bx_BillingProfileName\b'
            x_InvoiceSectionName = '\bx_InvoiceSectionName\b'
        }

        foreach ($fieldName in $finOpsHubFieldPatterns.Keys)
        {
            $schemaGuideContent | Should -Match $finOpsHubFieldPatterns[$fieldName]
        }

        foreach ($reference in Get-DriversComparisonCases)
        {
            $reference.Path | Should -Exist
            $foundFields = @(Get-FoundMarkers -Content $reference.Content -Patterns $finOpsHubFieldPatterns)
            $foundFields.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should use FinOps hubs schema fields such as ServiceName, SubAccountName, RegionName, x_ResourceGroupName, or billing hierarchy fields"
        }
    }

    # // T-1.15.2: RTM FR-7.2
    It 'FR7_2_AC1_DriversComparison_RemovesUnsupportedConstructs' {
        $unsupportedPatterns = [ordered]@{
            get_cost_data = '\bget_cost_data\s*\('
            get_available_dimensions = '\bget_available_dimensions\s*\('
            'CZ:' = 'CZ:'
            'User:Defined:' = 'User:Defined:'
        }

        foreach ($reference in Get-DriversComparisonCases)
        {
            $reference.Path | Should -Exist
            $foundMarkers = @(Get-FoundMarkers -Content $reference.Content -Patterns $unsupportedPatterns)
            $foundMarkers.Count | Should -Be 0 -Because "$($reference.Name) should remove unsupported tools, dimensions, and terminology"
        }
    }

    # // T-1.15.2: RTM FR-7.2
    # // T-1.15.2: RTM NFR-7
    It 'FR7_2_AC2_DriversComparison_ReferencesValidCatalogQueries' {
        foreach ($reference in Get-DriversComparisonCases)
        {
            $reference.Path | Should -Exist

            $matchedQueries = @()
            foreach ($queryName in $reference.RelevantQueries)
            {
                $catalogPath = Join-Path $referencesRoot "queries/catalog/$queryName.kql"
                $catalogPath | Should -Exist
                $queryIndexContent | Should -Match ([regex]::Escape("[$queryName](./catalog/$queryName.kql)"))

                if ($reference.Content -match ([regex]::Escape($queryName)))
                {
                    $matchedQueries += $queryName
                }
            }

            $matchedQueries.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference at least one valid FinOps Toolkit query/catalog asset relevant to its analysis workflow"
        }
    }

    # // T-1.15.2: RTM FR-7.2
    # // T-1.15.2: RTM NFR-7
    It 'FR7_2_AC3_DriversComparison_UsesOptionalTagFallbacks' {
        $optionalTagPattern = '(?is)(optional|if available|when available|if your organization uses tags|if tag coverage is incomplete|if tags are missing).{0,240}(tag|tags|Tags\[)|(tag|tags|Tags\[).{0,240}(optional|if available|when available|if your organization uses tags|if tag coverage is incomplete|if tags are missing)'
        $fallbackPattern = '(?is)(fallback|fall back|otherwise|instead use|use .* instead|if tag coverage is incomplete|if tags are missing).{0,240}(ServiceName|SubAccountName|RegionName|x_ResourceGroupName|x_BillingProfileName|x_InvoiceSectionName|service|subscription|region|resource group|billing profile|invoice section)'

        foreach ($reference in Get-DriversComparisonCases)
        {
            $reference.Path | Should -Exist
            $reference.Content | Should -Match $optionalTagPattern
            $reference.Content | Should -Match $fallbackPattern
        }
    }
}
