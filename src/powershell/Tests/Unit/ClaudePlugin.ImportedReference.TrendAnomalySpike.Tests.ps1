# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $referencesRoot = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references'
    $queriesRoot = Join-Path $repoRoot 'src/queries'
    $queryIndexPath = Join-Path $queriesRoot 'INDEX.md'
    $schemaGuidePath = Join-Path $queriesRoot 'finops-hub-database-guide.md'
    $catalogRoot = Join-Path $queriesRoot 'catalog'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Get-MatchingLabels
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

    function Test-PatternDocumented
    {
        param(
            [Parameter(Mandatory)]
            [string]$Label
        )

        switch ($Label)
        {
            'Costs()' { return $script:SchemaGuideContent -match '\bCosts\(\)' }
            'monthly-cost-trend.kql' { return $script:QueryIndexContent -match 'monthly-cost-trend\.kql' }
            'monthly-cost-change-percentage.kql' { return $script:QueryIndexContent -match 'monthly-cost-change-percentage\.kql' }
            'cost-by-region-trend.kql' { return $script:QueryIndexContent -match 'cost-by-region-trend\.kql' }
            'cost-anomaly-detection.kql' { return $script:QueryIndexContent -match 'cost-anomaly-detection\.kql' }
            'top-services-by-cost.kql' { return $script:QueryIndexContent -match 'top-services-by-cost\.kql' }
            default { throw "No canonical documentation mapping exists for label '$Label'." }
        }
    }

    $script:QueryIndexContent = Get-TestFileContent -Path $queryIndexPath
    $script:SchemaGuideContent = Get-TestFileContent -Path $schemaGuidePath
    $script:AllowedDimensionPatterns = [ordered]@{
        ServiceName = '\bServiceName\b'
        SubAccountName = '\bSubAccountName\b'
        RegionName = '\bRegionName\b'
        x_ResourceGroupName = '\bx_ResourceGroupName\b'
        ResourceName = '\bResourceName\b'
        ResourceType = '\bResourceType\b'
        x_UsageType = '\bx_UsageType\b'
    }
    $script:ForbiddenConstructPatterns = [ordered]@{
        get_cost_data = '\bget_cost_data\s*\('
        get_available_dimensions = '\bget_available_dimensions\s*\('
        'CZ:' = 'CZ:'
        'User:Defined:' = 'User:Defined:'
    }
    $script:ReferenceCases = @(
        [pscustomobject]@{
            Name = 'cost-trend-analysis.md'
            Path = Join-Path $referencesRoot 'cost-trend-analysis.md'
            ValidFinOpsPatterns = [ordered]@{
                'Costs()' = '\bCosts\(\)'
                'monthly-cost-trend.kql' = 'monthly-cost-trend\.kql'
                'monthly-cost-change-percentage.kql' = 'monthly-cost-change-percentage\.kql'
                'cost-by-region-trend.kql' = 'cost-by-region-trend\.kql'
            }
            CatalogQueryPatterns = [ordered]@{
                'monthly-cost-trend.kql' = 'monthly-cost-trend\.kql'
                'monthly-cost-change-percentage.kql' = 'monthly-cost-change-percentage\.kql'
                'cost-by-region-trend.kql' = 'cost-by-region-trend\.kql'
            }
        }
        [pscustomobject]@{
            Name = 'cost-anomaly-detection.md'
            Path = Join-Path $referencesRoot 'cost-anomaly-detection.md'
            ValidFinOpsPatterns = [ordered]@{
                'Costs()' = '\bCosts\(\)'
                'cost-anomaly-detection.kql' = 'cost-anomaly-detection\.kql'
                'monthly-cost-change-percentage.kql' = 'monthly-cost-change-percentage\.kql'
            }
            CatalogQueryPatterns = [ordered]@{
                'cost-anomaly-detection.kql' = 'cost-anomaly-detection\.kql'
            }
        }
        [pscustomobject]@{
            Name = 'cost-spike-investigation.md'
            Path = Join-Path $referencesRoot 'cost-spike-investigation.md'
            ValidFinOpsPatterns = [ordered]@{
                'Costs()' = '\bCosts\(\)'
                'cost-anomaly-detection.kql' = 'cost-anomaly-detection\.kql'
                'monthly-cost-change-percentage.kql' = 'monthly-cost-change-percentage\.kql'
                'top-services-by-cost.kql' = 'top-services-by-cost\.kql'
            }
            CatalogQueryPatterns = [ordered]@{
                'cost-anomaly-detection.kql' = 'cost-anomaly-detection\.kql'
                'monthly-cost-change-percentage.kql' = 'monthly-cost-change-percentage\.kql'
                'top-services-by-cost.kql' = 'top-services-by-cost\.kql'
            }
        }
    )
}

Describe 'Claude plugin imported trend, anomaly, and spike reference validation' {
    # // T-1.15.3: RTM FR-7.1
    # // T-1.15.3: RTM NFR-7
    It 'FR7_1_AC1_TrendAnomalySpike_UsesValidFinOpsPatterns' {
        $queryIndexPath | Should -Exist
        $schemaGuidePath | Should -Exist
        $catalogRoot | Should -Exist

        foreach ($case in $ReferenceCases)
        {
            $case.Path | Should -Exist
            $content = Get-TestFileContent -Path $case.Path

            foreach ($label in $case.ValidFinOpsPatterns.Keys)
            {
                (Test-PatternDocumented -Label $label) | Should -BeTrue -Because "$label should be documented in canonical FinOps hubs query guidance"
            }

            $hits = @(Get-MatchingLabels -Content $content -Patterns $case.ValidFinOpsPatterns)
            $hits.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should reference at least one valid FinOps hubs query pattern or documented catalog asset"
        }
    }

    # // T-1.15.3: RTM FR-7.2
    It 'FR7_2_AC1_TrendAnomalySpike_RemovesUnsupportedConstructs' {
        foreach ($case in $ReferenceCases)
        {
            $case.Path | Should -Exist
            $content = Get-TestFileContent -Path $case.Path

            foreach ($patternName in $ForbiddenConstructPatterns.Keys)
            {
                $content | Should -Not -Match $ForbiddenConstructPatterns[$patternName] -Because "$($case.Name) should not contain unsupported construct '$patternName'"
            }
        }
    }

    # // T-1.15.3: RTM FR-7.2
    # // T-1.15.3: RTM NFR-7
    It 'FR7_2_AC2_TrendAnomalySpike_UsesFinOpsDimensions' {
        foreach ($dimensionName in $AllowedDimensionPatterns.Keys)
        {
            $SchemaGuideContent | Should -Match $AllowedDimensionPatterns[$dimensionName] -Because "$dimensionName should be grounded in the FinOps hubs schema guide"
        }

        foreach ($case in $ReferenceCases)
        {
            $case.Path | Should -Exist
            $content = Get-TestFileContent -Path $case.Path
            $hits = @(Get-MatchingLabels -Content $content -Patterns $AllowedDimensionPatterns)

            $hits.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should use FinOps hubs dimensions or fields documented in the schema guide"
        }
    }

    # // T-1.15.3: RTM FR-7.2
    # // T-1.15.3: RTM NFR-7
    It 'FR7_2_AC3_TrendAnomalySpike_ReferencesCatalogQueries' {
        foreach ($case in $ReferenceCases)
        {
            $case.Path | Should -Exist
            $content = Get-TestFileContent -Path $case.Path

            foreach ($queryName in $case.CatalogQueryPatterns.Keys)
            {
                $catalogPath = Join-Path $catalogRoot $queryName
                $catalogPath | Should -Exist -Because "$queryName should exist in the FinOps hubs query catalog"
                $QueryIndexContent | Should -Match ([regex]::Escape($queryName)) -Because "$queryName should be listed in the query catalog index"
            }

            $hits = @(Get-MatchingLabels -Content $content -Patterns $case.CatalogQueryPatterns)
            $hits.Count | Should -BeGreaterThan 0 -Because "$($case.Name) should reference an appropriate FinOps hubs catalog query"
        }
    }
}
