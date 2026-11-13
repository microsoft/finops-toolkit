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
            'Get-AiTokenType'
            'Test-AiCachedToken'
            'Test-AiBatchToken'
            'Get-AiTokenContextType'
            'Get-AiTokenLocation'
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

    Context 'Token rules' {
        It 'classifies <Name>' -ForEach @(
            @{ Name = 'Cache Inp Tokens';             Type = 'Input';  Cached = $true;  Batch = $false; Context = 'N/A' }
            @{ Name = 'cached Tokens';                Type = 'N/A';    Cached = $true;  Batch = $false; Context = 'N/A' }
            @{ Name = 'Non-Cached Input Tokens';      Type = 'Input';  Cached = $false; Batch = $false; Context = 'N/A' }
            @{ Name = 'ShortCo Batch cd inp Tokens';  Type = 'Input';  Cached = $true;  Batch = $true;  Context = 'Short Context' }
            @{ Name = 'ShortCo Batch Cd Wr Tokens';   Type = 'Write';  Cached = $true;  Batch = $true;  Context = 'Short Context' }
            @{ Name = 'cache-write Tokens';           Type = 'Write';  Cached = $true;  Batch = $false; Context = 'N/A' }
            @{ Name = 'longco batch opt Tokens';      Type = 'Output'; Cached = $false; Batch = $true;  Context = 'Long Context' }
            @{ Name = 'shco CdInput Tokens';          Type = 'Input';  Cached = $true;  Batch = $false; Context = 'Short Context' }
            @{ Name = 'loco Output Tokens';           Type = 'Output'; Cached = $false; Batch = $false; Context = 'Long Context' }
            @{ Name = 'shco loco Input Tokens';       Type = 'Input';  Cached = $false; Batch = $false; Context = 'Ambiguous' }
            @{ Name = 'Pro Contextualization Tokens'; Type = 'N/A';    Cached = $false; Batch = $false; Context = 'Contextualization' }
        ) {
            Get-AiTokenType $Name 'Guid'  | Should -Be $Type
            Test-AiCachedToken $Name      | Should -Be $Cached
            Test-AiBatchToken $Name       | Should -Be $Batch
            Get-AiTokenContextType $Name  | Should -Be $Context
        }

        It 'token type of <Name> is <Type>' -ForEach @(
            @{ Name = 'Units'; Kind = 'ClaudeConsumptionUnits'; Type = 'ConsumptionUnit' }
            @{ Name = 'Model writer Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = 'Model rewrite Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = 'Model CdWr Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = 'Model reasoning Tokens'; Kind = 'Guid'; Type = 'Reasoning' }
            @{ Name = 'Model Inp Out Tokens'; Kind = 'Guid'; Type = 'Ambiguous' }
            @{ Name = 'Model embed Tokens'; Kind = 'Guid'; Type = 'Embedding' }
            @{ Name = 'Cache read Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = 'xCdInput Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = 'CdInputExtra Tokens'; Kind = 'Guid'; Type = 'N/A' }
            @{ Name = '6-astra ShortCo Cd Inp Std Gl 1M Tokens'; Kind = 'Guid'; Type = 'Input' }
        ) { Get-AiTokenType $Name $Kind | Should -Be $Type }

        It 'cached flag of <Name> is <Cached>' -ForEach @(
            @{ Name = 'CD-Output Tokens'; Cached = $true }
            @{ Name = 'cd_embedding Tokens'; Cached = $true }
            @{ Name = 'Model CdWr Tokens'; Cached = $true }
            @{ Name = 'uncached Input Tokens'; Cached = $false }
            @{ Name = 'not cached Input Tokens'; Cached = $false }
            @{ Name = 'non cache Input Tokens'; Cached = $false }
            @{ Name = 'xCdInput Tokens'; Cached = $false }
        ) { Test-AiCachedToken $Name | Should -Be $Cached }

        It 'batch flag of <Name> is <Batch>' -ForEach @(
            @{ Name = 'batch-input Tokens'; Batch = $true }
            @{ Name = 'non-batch Input Tokens'; Batch = $true }
            @{ Name = 'microbatch Tokens'; Batch = $false }
            @{ Name = 'batching Tokens'; Batch = $false }
            @{ Name = 'batch_input Tokens'; Batch = $false }
        ) { Test-AiBatchToken $Name | Should -Be $Batch }

        It 'context of <Name> is <Context>' -ForEach @(
            @{ Name = 'model-longctx-input Tokens'; Context = 'Long Context' }
            @{ Name = 'model-shco-input Tokens'; Context = 'Short Context' }
            @{ Name = 'xshco Tokens'; Context = 'N/A' }
            @{ Name = 'loco2 Tokens'; Context = 'N/A' }
            @{ Name = 'shco_input Tokens'; Context = 'N/A' }
            @{ Name = 'Short_Context Input Tokens'; Context = 'Short Context' }
            @{ Name = 'shco Short Context Tokens'; Context = 'Short Context' }
            @{ Name = 'Adv Contextual Tokens'; Context = 'Contextual' }
            @{ Name = 'Context context Tokens'; Context = 'Context' }
        ) { Get-AiTokenContextType $Name | Should -Be $Context }

        It 'location of <Name> is <Location>' -ForEach @(
            @{ Name = '5.4 opt Dz 1M Tokens'; Location = 'DataZone' }
            @{ Name = 'Grok 4.2 Inp Dzone Tokens'; Location = 'DataZone' }
            @{ Name = '6-luna ShortCo Opt Std Gl 1M Tokens'; Location = 'Global' }
            @{ Name = 'Model Inp Regnl Tokens'; Location = 'Regional' }
            @{ Name = 'Model-rgnl Inp Tokens'; Location = 'Regional' }
            @{ Name = 'Model Gl Dz Tokens'; Location = 'Ambiguous' }
            @{ Name = 'English Single Input Tokens'; Location = 'N/A' }
        ) { Get-AiTokenLocation $Name | Should -Be $Location }
    }
}
