# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Unit tests for the pure functions in src/scripts/Update-AiMeters.ps1. The script body
# reads a price sheet, so rather than dot-source it we extract just the named function
# definitions via the AST and evaluate those in isolation.

Describe 'Update-AiMeters' {
    BeforeAll {
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/Update-AiMeters.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        # Add each new function name to this list as later tasks introduce it.
        $functionNames = @(
            'Get-AiMeterIdKind'
            'Test-AiMeterIncluded'
            'Get-AiMeterProvider'
        )
        foreach ($name in $functionNames)
        {
            $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Function $name not found in $scriptPath" }
            . ([scriptblock]::Create($fn.Extent.Text))
        }
    }

    Context 'Get-AiMeterIdKind' {
        It 'classifies meter ID <Id> as <Expected>' -ForEach @(
            @{ Id = '0000b7f7-3b31-5534-9c09-4b23944d397c'; Expected = 'Guid' }
            @{ Id = 'Claude-Consumption-Units';             Expected = 'ClaudeConsumptionUnits' }
            @{ Id = 'some-vendor-meter';                    Expected = 'Other' }
            @{ Id = '';                                     Expected = 'Other' }
        ) { Get-AiMeterIdKind $Id | Should -Be $Expected }
    }

    Context 'Test-AiMeterIncluded' {
        It 'includes <Name> / <Sub> = <Expected>' -ForEach @(
            @{ Cat = 'Foundry Models'; Sub = 'Azure OpenAI GPT5'; Name = '5.4 opt Dz 1M Tokens'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'Y'; Name = 'Pay As You Go COPILOT Credit'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'Y'; Name = 'Consumption Unit'; Kind = 'ClaudeConsumptionUnits'; Expected = $true }
            @{ Cat = 'GitHub'; Sub = 'GitHub Copilot'; Name = 'AI Credit GAC'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'NotGitHub'; Sub = 'Y'; Name = 'AI Credit GAC'; Kind = 'Guid'; Expected = $false }
            @{ Cat = 'X'; Sub = 'Azure Agent Unit'; Name = 'SRE Agent Unit'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'Azure Monitor Observability Agent'; Name = 'n'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'microsoft 365 agent'; Name = 'n'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'Microsoft Agent Pre-Purchase Plan'; Name = 'n'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'GitHub Pre-Purchase Plan'; Name = 'n'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'X'; Sub = 'GitHub AI Credits Pre-Purchase Plan'; Name = 'n'; Kind = 'Guid'; Expected = $true }
            @{ Cat = 'Virtual Machines'; Sub = 'Dv5 Series'; Name = 'D2 v5'; Kind = 'Guid'; Expected = $false }
        ) { Test-AiMeterIncluded $Cat $Sub $Name $Kind | Should -Be $Expected }
    }

    Context 'Get-AiMeterProvider' {
        It 'derives provider <Expected>' -ForEach @(
            @{ Sub = 'Claude Models'; Name = 'Sonnet Input Tokens'; Kind = 'Other'; Expected = 'Anthropic' }
            @{ Sub = 'X'; Name = 'Anthropic Opus Output Tokens'; Kind = 'Guid'; Expected = 'Anthropic' }
            @{ Sub = 'X'; Name = 'Input Tokens'; Kind = 'Guid'; Expected = 'Microsoft' }
            @{ Sub = 'X'; Name = 'Input Tokens'; Kind = 'Other'; Expected = 'Vendor' }
            @{ Sub = 'X'; Name = 'Units'; Kind = 'ClaudeConsumptionUnits'; Expected = 'Vendor' }
        ) { Get-AiMeterProvider $Sub $Name $Kind | Should -Be $Expected }
    }
}
