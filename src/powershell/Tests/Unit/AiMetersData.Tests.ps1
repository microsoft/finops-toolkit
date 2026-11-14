# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'AiMeters open data' {
    BeforeAll {
        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $scriptPath = Join-Path $repoRoot 'src/scripts/Update-AiMeters.ps1'
        $csvPath = Join-Path $repoRoot 'src/open-data/AiMeters.csv'

        # Load only the functions the data checks need, so the script body never runs.
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functionNames = @(
            'Get-AiMeterRuleLiteral'
            'Get-AiMeterColumn'
            'Get-AiTokenDirectionAlias'
            'Get-AiMeterIdKind'
            'Test-AiTokenMeter'
            'Test-AiCopilotMeter'
            'Test-AiMeterIncluded'
            'Get-AiMeterProvider'
            'Get-AiTokenType'
            'Test-AiCachedToken'
            'Test-AiBatchToken'
            'Get-AiTokenContextType'
            'Get-AiTokenLocation'
            'Get-AiModelVersion'
            'Get-AiModelCreator'
            'Get-AiMeterClassification'
            'Get-AiMeterKey'
        )
        foreach ($name in $functionNames)
        {
            $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Function $name not found in $scriptPath" }
            . ([scriptblock]::Create($fn.Extent.Text))
        }

        $expectedColumns = @(
            'x_SkuMeterCategory', 'x_SkuMeterSubcategory', 'SkuMeter', 'x_SkuServiceFamily', 'MeterIdKind', 'IsDefault',
            'Provider', 'IsTokenMeter', 'TokenType', 'IsCachedToken', 'IsBatchToken', 'TokenContextType', 'TokenLocation',
            'IsCopilotMeter', 'CopilotProvider', 'IsCommitmentMeter', 'IsConsumptionMeter', 'CopilotType', 'IsAgentMeter',
            'AgentType', 'ModelVersion', 'ModelCreator'
        )

        $rows = @(Import-Csv $csvPath)
        $header = @($rows[0].PSObject.Properties.Name)

        # Do the per-row work once, so the tests only assert.
        $keys = @($rows | ForEach-Object { Get-AiMeterKey $_.x_SkuMeterCategory $_.x_SkuMeterSubcategory $_.SkuMeter })
        $derivedColumns = $expectedColumns[6..21]
        $mismatches = [System.Collections.Generic.List[string]]::new()
        foreach ($row in $rows)
        {
            $c = Get-AiMeterClassification $row.x_SkuMeterCategory $row.x_SkuMeterSubcategory $row.SkuMeter $row.x_SkuServiceFamily $row.MeterIdKind
            if ($null -eq $c)
            {
                $mismatches.Add("not an AI meter: $($row.x_SkuMeterCategory) | $($row.x_SkuMeterSubcategory) | $($row.SkuMeter)")
                continue
            }
            foreach ($column in $derivedColumns)
            {
                $actual = $c[$column]
                $text = if ($actual -is [bool]) { if ($actual) { 'true' } else { 'false' } } else { [string]$actual }
                if ($text -cne $row.$column)
                {
                    $mismatches.Add("$column expected '$text' but is '$($row.$column)': $($row.x_SkuMeterCategory) | $($row.x_SkuMeterSubcategory) | $($row.SkuMeter)")
                }
            }
        }
    }

    It 'is skipped by Build-OpenData -PowerShell' {
        $build = Get-Content "$PSScriptRoot/../../../scripts/Build-OpenData.ps1" -Raw
        $build | Should -Match "\`$skipPowerShell\s*=\s*@\('AiMeters'\)"
        $build | Should -Match '\$_\.BaseName -notin \$skipPowerShell'
        Test-Path "$PSScriptRoot/../../Private/Get-OpenDataAiMeter.ps1" | Should -BeFalse
    }

    It 'has the 22 columns in order' {
        $header | Should -HaveCount 22
        ($header -join ',') | Should -BeExactly ($expectedColumns -join ',')
    }

    It 'has unique keys when lowercased' {
        $duplicates = @($keys | Group-Object | Where-Object Count -gt 1 | ForEach-Object { $_.Name -replace [char]31, ' | ' })
        $duplicates | Should -BeNullOrEmpty
    }

    It 'has exactly one default row per category and meter name' {
        $bad = @($rows | Group-Object { "$($_.x_SkuMeterCategory)".ToLowerInvariant() + [char]31 + "$($_.SkuMeter)".ToLowerInvariant() } |
                Where-Object { @($_.Group | Where-Object IsDefault -ceq 'true').Count -ne 1 } |
                ForEach-Object { $_.Name -replace [char]31, ' | ' })
        $bad | Should -BeNullOrEmpty
    }

    It 'has a known meter ID kind in every row' {
        $unknown = @($rows | Where-Object { $_.MeterIdKind -cnotin @('Guid', 'ClaudeConsumptionUnits', 'Other') })
        $unknown | Should -BeNullOrEmpty
    }

    It 'matches the ruleset for every row' {
        $rows.Count | Should -BeGreaterThan 0
        $mismatches | Should -BeNullOrEmpty
    }

    It 'has no column for prices or identifiers' {
        $forbidden = @('MeterId', 'ProductId', 'SkuId', 'SkuPriceId', 'UnitPrice', 'BillingAccountId')
        @($header | Where-Object { $_ -in $forbidden }) | Should -BeNullOrEmpty
    }

    It 'is sorted by key' {
        $sorted = [string[]]$keys.Clone()
        [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
        ($keys -join "`n") | Should -BeExactly ($sorted -join "`n")
    }
}
