# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $referencePath = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references/understand-finops-hub-context.md'
    $queryGuidePath = Join-Path $repoRoot 'src/queries/finops-hub-database-guide.md'
    $queryIndexPath = Join-Path $repoRoot 'src/queries/INDEX.md'
    $hubsConnectPath = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references/workflows/ftk-hubs-connect.md'
    $hubsHealthCheckPath = Join-Path $repoRoot 'src/templates/agent-skills/finops-toolkit/references/workflows/ftk-hubs-healthCheck.md'
    $environmentPath = '/Users/brett/src/trey/.ftk/environments.local.md'
    $testFilePath = Join-Path $repoRoot 'src/powershell/Tests/Unit/ClaudePlugin.ImportedReference.Foundation.Tests.ps1'

    function Get-TestFileContent
    {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        return Get-Content -Path $Path -Raw
    }

    function Assert-ContainsLiteral
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Literal,

            [Parameter(Mandatory)]
            [string]$Because
        )

        $Content | Should -Match ([regex]::Escape($Literal)) -Because $Because
    }

    function Assert-OmitsLiteral
    {
        param(
            [Parameter(Mandatory)]
            [string]$Content,

            [Parameter(Mandatory)]
            [string]$Literal,

            [Parameter(Mandatory)]
            [string]$Because
        )

        $Content | Should -Not -Match ([regex]::Escape($Literal)) -Because $Because
    }
}

Describe 'Claude plugin foundational imported reference post-change validation' {
    # // T-1.15.1: RTM FR-7.1
    It 'FR7_1_AC1_FoundationReference_UsesFinOpsHubContext' {
        $referencePath | Should -Exist
        $content = Get-TestFileContent -Path $referencePath

        $content | Should -Match '(?i)\bFinOps hubs?\b|\bhub context\b' -Because 'the foundational reference should be framed around FinOps hub context'
        $content | Should -Match '(?i)\bcluster-uri\b|\bcluster URI\b|\bKQL\b|\bquery catalog\b|\bAzure Data Explorer\b' -Because 'the foundational reference should ground analysis in Hub connectivity or query execution context'
        $content | Should -Not -Match '(?i)\bthird-party organization\b' -Because 'the foundational reference should be framed around FinOps hub context, not third-party platform context'
    }

    # // T-1.15.1: RTM FR-7.2
    It 'FR7_2_AC1_FoundationReference_RemovesUnsupportedConstructs' {
        $content = Get-TestFileContent -Path $referencePath

        @(
            'get_org_context',
            'User:Defined:',
            'dimensions-reference'
        ) | ForEach-Object {
            Assert-OmitsLiteral -Content $content -Literal $_ -Because "the adapted foundational reference should not depend on $_"
        }
    }

    # // T-1.15.1: RTM FR-7.2
    # // T-1.15.1: RTM NFR-7
    It 'FR7_2_AC2_FoundationReference_UsesValidFinOpsReferences' {
        $content = Get-TestFileContent -Path $referencePath

        @(
            @{ Literal = 'references/queries/finops-hub-database-guide.md'; Path = $queryGuidePath },
            @{ Literal = 'references/queries/INDEX.md'; Path = $queryIndexPath },
            @{ Literal = 'references/workflows/ftk-hubs-connect.md'; Path = $hubsConnectPath },
            @{ Literal = 'references/workflows/ftk-hubs-healthCheck.md'; Path = $hubsHealthCheckPath }
        ) | ForEach-Object {
            $_.Path | Should -Exist
            Assert-ContainsLiteral -Content $content -Literal $_.Literal -Because "the adapted foundational reference should point to $($_.Literal)"
        }

        if (Test-Path $environmentPath)
        {
            $environmentContent = Get-TestFileContent -Path $environmentPath
            $environmentContent | Should -Match '(?m)^default:\s+.+' -Because 'the configured hub environment should declare a default entry'
            $environmentContent | Should -Match '(?m)^\s+cluster-uri:\s+https://.+' -Because 'the configured hub environment should declare a cluster URI for validation evidence'
        }
        else
        {
            Set-ItResult -Skipped -Because 'environment evidence file not present (local-only)'
        }
    }

    # // T-1.15.1: RTM FR-7.2
    It 'FR7_2_AC3_FoundationReference_DescribesOptionalTagsHonestly' {
        $content = Get-TestFileContent -Path $referencePath
        $optionalityPattern = '(?i)(optional|observed|when present|if present|if available|may be blank|not guaranteed|missing)'

        @('team', 'product', 'application', 'environment') | ForEach-Object {
            $tagPattern = "(?is)(\\b$_\\b.{0,160}$optionalityPattern)|($optionalityPattern.{0,160}\\b$_\\b)"
            $content | Should -Match $tagPattern -Because "$_ should be described as optional or observed rather than guaranteed"
        }

        $content | Should -Not -Match '(?i)required tags' -Because 'the adapted foundational reference should not present business tags as universally required'
        $content | Should -Not -Match '(?i)all resources' -Because 'the adapted foundational reference should not claim those business tags are guaranteed across all resources'
    }

    # // T-1.15.1: RTM FR-7.2
    It 'FR7_2_AC4_FoundationReference_NoUnsupportedBusinessClaims' {
        $content = Get-TestFileContent -Path $referencePath

        @(
            '(?i)key stakeholders and reporting requirements',
            '(?i)budget owners and accountability structure',
            '(?i)showback/chargeback policies',
            '(?i)known planned changes',
            '(?i)business events that impact spending',
            '(?i)(FinOps hubs?|hub context).{0,120}(provides|includes|contains|retrieves|derives).{0,120}(budgets?|stakeholders?|showback|chargeback|planned (business )?events?)'
        ) | ForEach-Object {
            $content | Should -Not -Match $_ -Because 'the adapted foundational reference should not claim Hub-only derivation of unsupported business context'
        }
    }

    # // T-1.15.1: RTM NFR-7
    It 'FR7_2_AC5_FoundationReference_TestRunsInRepoEnvironment' {
        $repoRoot | Should -Not -BeNullOrEmpty
        (Split-Path -Path $repoRoot -Leaf) | Should -Be 'finops-toolkit'
        (Join-Path $repoRoot 'package.json') | Should -Exist
        $referencePath | Should -Exist
        $testFilePath | Should -Exist
        $queryGuidePath | Should -Exist
        $queryIndexPath | Should -Exist
        $hubsConnectPath | Should -Exist
        $hubsHealthCheckPath | Should -Exist
        if (Test-Path $environmentPath)
        {
            $environmentPath | Should -Exist
        }
    }
}
