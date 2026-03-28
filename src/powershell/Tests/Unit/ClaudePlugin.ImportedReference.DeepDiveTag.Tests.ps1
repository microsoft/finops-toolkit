# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $referencesRoot = Join-Path $repoRoot 'src/templates/claude-plugin/skills/finops-toolkit/references'
    $queryReferencesRoot = Join-Path $referencesRoot 'queries'
    $catalogRoot = Join-Path $queryReferencesRoot 'catalog'
    $schemaGuidePath = Join-Path $queryReferencesRoot 'finops-hub-database-guide.md'
    $queryIndexPath = Join-Path $queryReferencesRoot 'INDEX.md'

    $schemaAssets = @(
        [pscustomobject]@{
            Label = 'finops-hub-database-guide.md'
            RepoPath = $schemaGuidePath
            Pattern = 'finops-hub-database-guide\.md'
        },
        [pscustomobject]@{
            Label = 'INDEX.md'
            RepoPath = $queryIndexPath
            Pattern = 'INDEX\.md'
        }
    )

    $validFunctionPatterns = @(
        [pscustomobject]@{ Label = 'Costs()'; Pattern = '\bCosts\s*\(\s*\)' },
        [pscustomobject]@{ Label = 'Prices()'; Pattern = '\bPrices\s*\(\s*\)' },
        [pscustomobject]@{ Label = 'Recommendations()'; Pattern = '\bRecommendations\s*\(\s*\)' }
    )

    $validFieldPatterns = @(
        [pscustomobject]@{ Label = 'ServiceName'; Pattern = '\bServiceName\b' },
        [pscustomobject]@{ Label = 'x_ResourceGroupName'; Pattern = '\bx_ResourceGroupName\b' },
        [pscustomobject]@{ Label = 'x_CostCenter'; Pattern = '\bx_CostCenter\b' },
        [pscustomobject]@{ Label = 'x_Project'; Pattern = '\bx_Project\b' },
        [pscustomobject]@{ Label = 'Tags[...]'; Pattern = 'Tags\s*\[\s*["''][^"'']+["'']\s*\]' }
    )

    $unsupportedConstructPatterns = @(
        [pscustomobject]@{ Label = 'get_cost_data'; Pattern = '\bget_cost_data\s*\(' },
        [pscustomobject]@{ Label = 'get_available_dimensions'; Pattern = '\bget_available_dimensions\s*\(' },
        [pscustomobject]@{ Label = 'CZ:'; Pattern = 'CZ:' },
        [pscustomobject]@{ Label = 'User:Defined:'; Pattern = 'User:Defined:' },

    )

    $honestQualifierPatterns = @(
        [pscustomobject]@{ Label = 'observed'; Pattern = '\bobserved\b' },
        [pscustomobject]@{ Label = 'optional'; Pattern = '\boptional\b' },
        [pscustomobject]@{ Label = 'if available'; Pattern = '\bif available\b' },
        [pscustomobject]@{ Label = 'if populated'; Pattern = '\bif populated\b' },
        [pscustomobject]@{ Label = 'when populated'; Pattern = '\bwhen populated\b' }
    )

    $inspectPopulatedFieldPatterns = @(
        [pscustomobject]@{ Label = 'inspect populated fields'; Pattern = '(?is)\binspect\b.{0,120}\b(populated|available|present)\b.{0,120}\b(field|fields|tag|tags|column|columns|key|keys)\b' },
        [pscustomobject]@{ Label = 'check populated fields'; Pattern = '(?is)\b(check|review|verify|look at)\b.{0,120}\b(populated|available|present)\b.{0,120}\b(field|fields|tag|tags|column|columns|key|keys)\b' },
        [pscustomobject]@{ Label = 'identify observed tags'; Pattern = '(?is)\b(identify|discover|determine)\b.{0,120}\b(observed|populated|available)\b.{0,120}\b(field|fields|tag|tags|column|columns|key|keys)\b' }
    )

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-MatchedLabels
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [object[]]$PatternCases
        )

        return @($PatternCases | Where-Object {
                $Content -match $_.Pattern
            } | ForEach-Object {
                $_.Label
            })
    }

    function Get-ReferenceCases
    {
        return @(
            [pscustomobject]@{
                Name = 'service-cost-deep-dive.md'
                Path = Join-Path $referencesRoot 'service-cost-deep-dive.md'
                Content = Get-TestFileContent -Path (Join-Path $referencesRoot 'service-cost-deep-dive.md')
                RelevantCatalogAssets = @(
                    [pscustomobject]@{ Label = 'top-services-by-cost.kql'; RepoPath = Join-Path $catalogRoot 'top-services-by-cost.kql'; Pattern = 'top-services-by-cost\.kql' },
                    [pscustomobject]@{ Label = 'service-price-benchmarking.kql'; RepoPath = Join-Path $catalogRoot 'service-price-benchmarking.kql'; Pattern = 'service-price-benchmarking\.kql' },
                    [pscustomobject]@{ Label = 'costs-enriched-base.kql'; RepoPath = Join-Path $catalogRoot 'costs-enriched-base.kql'; Pattern = 'costs-enriched-base\.kql' }
                )
            },
            [pscustomobject]@{
                Name = 'custom-dimension-analysis.md'
                Path = Join-Path $referencesRoot 'custom-dimension-analysis.md'
                Content = Get-TestFileContent -Path (Join-Path $referencesRoot 'custom-dimension-analysis.md')
                RelevantCatalogAssets = @(
                    [pscustomobject]@{ Label = 'cost-by-financial-hierarchy.kql'; RepoPath = Join-Path $catalogRoot 'cost-by-financial-hierarchy.kql'; Pattern = 'cost-by-financial-hierarchy\.kql' },
                    [pscustomobject]@{ Label = 'costs-enriched-base.kql'; RepoPath = Join-Path $catalogRoot 'costs-enriched-base.kql'; Pattern = 'costs-enriched-base\.kql' }
                )
            },
            [pscustomobject]@{
                Name = 'tag-coverage-analysis.md'
                Path = Join-Path $referencesRoot 'tag-coverage-analysis.md'
                Content = Get-TestFileContent -Path (Join-Path $referencesRoot 'tag-coverage-analysis.md')
                RelevantCatalogAssets = @(
                    [pscustomobject]@{ Label = 'cost-by-financial-hierarchy.kql'; RepoPath = Join-Path $catalogRoot 'cost-by-financial-hierarchy.kql'; Pattern = 'cost-by-financial-hierarchy\.kql' },
                    [pscustomobject]@{ Label = 'costs-enriched-base.kql'; RepoPath = Join-Path $catalogRoot 'costs-enriched-base.kql'; Pattern = 'costs-enriched-base\.kql' }
                )
            }
        )
    }
}

Describe 'Claude plugin imported deep-dive and tag reference validation' {
    # // T-1.15.4: RTM FR-7.1
    It 'FR7_1_AC1_DeepDiveTag_UsesFinOpsHubFunctionsAndFields' {
        $schemaGuidePath | Should -Exist
        $queryIndexPath | Should -Exist

        foreach ($reference in Get-ReferenceCases)
        {
            $reference.Path | Should -Exist

            $functionHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $validFunctionPatterns)
            $fieldHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $validFieldPatterns)

            $functionHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference at least one valid FinOps hubs analytic function"
            $fieldHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference at least one valid FinOps hubs field or tag access pattern"
        }
    }

    # // T-1.15.4: RTM FR-7.2
    It 'FR7_2_AC1_DeepDiveTag_RemovesUnsupportedConstructs' {
        foreach ($reference in Get-ReferenceCases)
        {
            $unsupportedHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $unsupportedConstructPatterns)

            $unsupportedHits.Count | Should -Be 0 -Because "$($reference.Name) should not retain unsupported third-party tools, dimensions, or terminology after adaptation"
        }
    }

    # // T-1.15.4: RTM FR-7.2
    # // T-1.15.4: RTM NFR-7
    It 'FR7_2_AC2_DeepDiveTag_UsesObservedBusinessFieldsHonestly' {
        foreach ($reference in Get-ReferenceCases)
        {
            $qualifierHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $honestQualifierPatterns)
            $inspectHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $inspectPopulatedFieldPatterns)

            $qualifierHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should describe business fields or tags as observed or optional rather than guaranteed"
            $inspectHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should tell readers to inspect which fields or tags are actually populated in their hub"
        }
    }

    # // T-1.15.4: RTM FR-7.2
    # // T-1.15.4: RTM NFR-7
    It 'FR7_2_AC3_DeepDiveTag_ReferencesValidCatalogOrSchemaAssets' {
        foreach ($asset in $schemaAssets)
        {
            $asset.RepoPath | Should -Exist
        }

        foreach ($reference in Get-ReferenceCases)
        {
            foreach ($asset in $reference.RelevantCatalogAssets)
            {
                $asset.RepoPath | Should -Exist
            }

            $schemaHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $schemaAssets)
            $catalogHits = @(Get-MatchedLabels -Content $reference.Content -PatternCases $reference.RelevantCatalogAssets)

            $schemaHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference a valid FinOps Toolkit schema guide or query index asset"
            $catalogHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference a valid FinOps Toolkit catalog query relevant to the analysis"
        }
    }
}
