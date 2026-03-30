# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $referencesRoot = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references'
    $schemaGuidePath = Join-Path $repoRoot 'src/queries/finops-hub-database-guide.md'
    $queryIndexPath = Join-Path $repoRoot 'src/queries/INDEX.md'
    $testFilePath = Join-Path $repoRoot 'src/powershell/Tests/Unit/ClaudePlugin.ImportedCostAnalysisReferences.Tests.ps1'
    $expectedReferenceFiles = @(
        'cost-anomaly-detection.md',
        'cost-comparison.md',
        'cost-spike-investigation.md',
        'cost-trend-analysis.md',
        'custom-dimension-analysis.md',
        'service-cost-deep-dive.md',
        'tag-coverage-analysis.md',
        'top-cost-drivers.md',
        'understand-finops-hub-context.md'
    )

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-ImportedReferenceCases
    {
        return @($expectedReferenceFiles | ForEach-Object {
                $path = Join-Path $referencesRoot $_
                [pscustomobject]@{
                    Name = $_
                    Path = $path
                    Content = Get-TestFileContent -Path $path
                }
            })
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
}

Describe 'Claude plugin imported cost analysis reference post-adaptation validation' {
    # // T-1.12: RTM FR-7.1
    It 'FR7_1_AC1_ImportedReferences_ReadAuthoritativeSchemaDocs' {
        $schemaGuidePath | Should -Exist
        $queryIndexPath | Should -Exist

        $schemaGuideContent = Get-TestFileContent -Path $schemaGuidePath
        $queryIndexContent = Get-TestFileContent -Path $queryIndexPath

        $schemaGuideContent | Should -Match '^# FinOps hubs database schema'
        $schemaGuideContent | Should -Match '## Query Best Practices'
        $schemaGuideContent | Should -Match 'Costs\(\)'
        $queryIndexContent | Should -Match '^# FinOps hub query catalog'
        $queryIndexContent | Should -Match 'finops-hub-database-guide\.md'
        $queryIndexContent | Should -Match 'cost-anomaly-detection\.kql'
    }

    # // T-1.12: RTM FR-7.2
    It 'FR7_2_AC1_ImportedReferences_RemoveUnsupportedConstructs' {
        $unsupportedPatterns = [ordered]@{
            get_cost_data = '\bget_cost_data\b'
            get_available_dimensions = '\bget_available_dimensions\b'
            get_org_context = '\bget_org_context\b'
            'CZ:' = 'CZ:'
            'User:Defined:' = 'User:Defined:'
        }

        foreach ($reference in Get-ImportedReferenceCases)
        {
            $reference.Path | Should -Exist

            $foundMarkers = @(Get-FoundMarkers -Content $reference.Content -Patterns $unsupportedPatterns)
            $foundMarkers.Count | Should -Be 0 -Because "$($reference.Name) should no longer depend on unsupported constructs after FinOps Toolkit adaptation"
        }
    }

    # // T-1.12: RTM FR-7.2
    It 'FR7_2_AC2_ImportedReferences_UseFinOpsToolkitGrounding' {
        $finOpsConceptPatterns = [ordered]@{
            FinOpsToolkit = 'FinOps Toolkit'
            FinOpsHub = 'FinOps hub'
            FinOpsHubs = 'FinOps hubs'
        }

        $authoritativeGroundingPatterns = [ordered]@{
            SchemaGuide = '(?:references/queries/|\./queries/)?finops-hub-database-guide\.md|FinOps hub database guide'
            QueryIndex = '(?:references/queries/|\./queries/)?INDEX\.md|query catalog'
        }

        $catalogOrFunctionPatterns = [ordered]@{
            Costs = 'Costs\(\)'
            Prices = 'Prices\(\)'
            Recommendations = 'Recommendations\(\)'
            Transactions = 'Transactions\(\)'
            costs_enriched_base = 'costs-enriched-base\.kql'
            monthly_cost_trend = 'monthly-cost-trend\.kql'
            monthly_cost_change_percentage = 'monthly-cost-change-percentage\.kql'
            cost_by_region_trend = 'cost-by-region-trend\.kql'
            top_services_by_cost = 'top-services-by-cost\.kql'
            cost_by_financial_hierarchy = 'cost-by-financial-hierarchy\.kql'
            cost_anomaly_detection = 'cost-anomaly-detection\.kql'
            service_price_benchmarking = 'service-price-benchmarking\.kql'
        }

        foreach ($reference in Get-ImportedReferenceCases)
        {
            $reference.Path | Should -Exist

            $conceptHits = @(Get-FoundMarkers -Content $reference.Content -Patterns $finOpsConceptPatterns)
            $groundingHits = @(Get-FoundMarkers -Content $reference.Content -Patterns $authoritativeGroundingPatterns)
            $catalogOrFunctionHits = @(Get-FoundMarkers -Content $reference.Content -Patterns $catalogOrFunctionPatterns)

            $conceptHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference FinOps Toolkit or FinOps hubs concepts after adaptation"
            $groundingHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference authoritative schema or query catalog docs after adaptation"
            $catalogOrFunctionHits.Count | Should -BeGreaterThan 0 -Because "$($reference.Name) should reference a FinOps hub function or catalog query after adaptation"
        }
    }

    # // T-1.12: RTM FR-7.3
    # // T-1.12: RTM NFR-6
    It 'FR7_3_AC1_ImportedReferences_TestFirstBaselineRunsInRepoEnvironment' {
        $repoRoot | Should -Not -BeNullOrEmpty
        (Split-Path -Path $repoRoot -Leaf) | Should -Be 'finops-toolkit'
        (Join-Path $repoRoot 'package.json') | Should -Exist
        $testFilePath | Should -Exist
        $referencesRoot | Should -Exist
        $schemaGuidePath | Should -Exist
        $queryIndexPath | Should -Exist

        $cases = @(Get-ImportedReferenceCases)
        $cases.Count | Should -Be 9
        @($cases.Name | Sort-Object) | Should -Be @($expectedReferenceFiles | Sort-Object)

        foreach ($reference in $cases)
        {
            $reference.Path | Should -Exist
            $reference.Content | Should -Not -BeNullOrEmpty
        }
    }
}
