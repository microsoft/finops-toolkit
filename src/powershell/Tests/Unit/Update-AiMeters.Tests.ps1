# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Unit tests for the pure functions in src/scripts/Update-AiMeters.ps1. The script body
# reads a price sheet, so rather than dot-source it we extract just the named function
# definitions via the AST and evaluate those in isolation.

BeforeDiscovery {
    # Build one pre-filter case per inclusion literal from Get-AiMeterRuleLiteral itself, so a
    # literal added there is covered without a test change.
    $discoveryScript = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/Update-AiMeters.ps1'
    $discoveryAst = [System.Management.Automation.Language.Parser]::ParseFile($discoveryScript, [ref]$null, [ref]$null)
    $literalFunction = $discoveryAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-AiMeterRuleLiteral' }, $true) | Select-Object -First 1
    . ([scriptblock]::Create($literalFunction.Extent.Text))
    $ruleLiterals = Get-AiMeterRuleLiteral

    # Returns the text in another letter case: uppercase, or lowercase when it's already uppercase.
    $otherCase = { param([string]$Text) if ($Text -cne $Text.ToUpperInvariant()) { $Text.ToUpperInvariant() } else { $Text.ToLowerInvariant() } }
    $guid = '0000b7f7-3b31-5534-9c09-4b23944d397c'

    $literalCases = @(
        foreach ($sub in @($ruleLiterals.AgentSubcategories.Keys) + $ruleLiterals.PrePurchasePlanSubcategories)
        {
            @{ Branch = 'subcategory'; Category = 'X'; Subcategory = (& $otherCase $sub); Name = 'Unit'; MeterId = $guid }
        }
        @{ Branch = 'meter ID'; Category = 'X'; Subcategory = 'Y'; Name = 'Unit'; MeterId = (& $otherCase $ruleLiterals.ConsumptionUnitsMeterId) }
        @{ Branch = 'GitHub credit'; Category = $ruleLiterals.GitHubCreditCategory; Subcategory = 'Y'; Name = (& $otherCase $ruleLiterals.GitHubCreditMeterName); MeterId = $guid }
        @{ Branch = 'token name'; Category = 'X'; Subcategory = 'Y'; Name = "Model $(& $otherCase $ruleLiterals.TokenNameKeyword)"; MeterId = $guid }
        @{ Branch = 'Copilot name'; Category = 'X'; Subcategory = 'Y'; Name = "Model $(& $otherCase $ruleLiterals.CopilotNameKeyword) Unit"; MeterId = $guid }
    )
}

Describe 'Update-AiMeters' {
    BeforeAll {
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/Update-AiMeters.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        # Add each new function name to this list as later tasks introduce it.
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
            'Read-AiMeterPricesheet'
            'Import-AiMeterInput'
            'Merge-AiMeterInput'
            'ConvertTo-AiMeterRow'
            'Get-AiMeterSummary'
        )
        foreach ($name in $functionNames)
        {
            $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if (-not $fn) { throw "Function $name not found in $scriptPath" }
            . ([scriptblock]::Create($fn.Extent.Text))
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Writes rows as JSON Lines into one entry of a new zip. Every row also gets a price and a
        # billing account ID, so later tests can prove those never reach the output.
        function New-TestPricesheet
        {
            param(
                [string]$Path,
                [hashtable[]]$Rows,
                [string]$EntryName = 'part-0.json'
            )

            $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Create')
            try
            {
                $entry = $zip.CreateEntry($EntryName)
                $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
                try
                {
                    foreach ($row in $Rows)
                    {
                        $copy = $row.Clone()
                        $copy.UnitPrice = 1.23
                        $copy.BillingAccountId = 'secret'
                        $writer.WriteLine(($copy | ConvertTo-Json -Compress))
                    }
                }
                finally { $writer.Dispose() }
            }
            finally { $zip.Dispose() }
            return $Path
        }

        # Builds one rule-input object in the shape Read-AiMeterPricesheet returns.
        function New-MeterInput
        {
            param([string]$Category, [string]$Subcategory, [string]$Name, [string]$Family = 'AI + Machine Learning', [string]$IdKind = 'Guid')
            return [pscustomobject]@{ Category = $Category; Subcategory = $Subcategory; Name = $Name; ServiceFamily = $Family; MeterIdKind = $IdKind }
        }

        # Runs the script in a child process and returns its exit code. Host output is discarded.
        function Invoke-AiMetersScript
        {
            param([string]$Pricesheet, [string]$Output)
            $null = & pwsh -NoProfile -File $scriptPath -PricesheetPath $Pricesheet -OutputPath $Output *>&1
            return $LASTEXITCODE
        }

        function New-IncludedRow
        {
            param([string]$Name, [string]$Id = '0000b7f7-3b31-5534-9c09-4b23944d397c', [string]$Family = 'AI + Machine Learning')
            return @{ MeterCategory = 'X'; MeterSubCategory = 'Y'; MeterName = $Name; MeterId = $Id; ServiceFamily = $Family }
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

        It 'token type of a null or empty name is N/A' {
            Get-AiTokenType $null 'Guid' | Should -Be 'N/A'
            Get-AiTokenType '' 'Guid' | Should -Be 'N/A'
        }

        It 'token type of the consumption units meter wins over a direction hint' {
            Get-AiTokenType 'Claude Input Tokens' 'ClaudeConsumptionUnits' | Should -Be 'ConsumptionUnit'
        }

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

    Context 'Get-AiModelVersion' {
        It 'model version of <Name> is <Version>' -ForEach @(
            @{ Name = 'AI21-Jamba 1.5-Out-FT Tokens';              Version = '1.5' }
            @{ Name = 'AI21-Jamba-1.5L-Out Tokens';                Version = '1.5' }
            @{ Name = 'Mistral Small 3.1 (25.03) Input Tokens';    Version = '3.1' }
            @{ Name = 'Llama-3-70B Input Tokens';                  Version = '3' }
            @{ Name = 'FW Kimi K3 Inp DZ Tokens';                  Version = '3' }
            @{ Name = 'Grok4 Fast Inp DZone Tokens';               Version = '4' }
            @{ Name = 'Az-GPT35-Turbo-16K-0125 Input Tokens';      Version = '3.5' }
            @{ Name = 'Model 1.5B Input Tokens';                   Version = 'N/A' }
            @{ Name = 'Llama-3 1.5B Input Tokens';                 Version = '3' }
            @{ Name = 'Model 2024-08-01 GPT-5 Input Tokens';       Version = '5' }
            @{ Name = 'Model K3 R1 Input Tokens';                  Version = 'N/A' }
            @{ Name = 'GPT35 Turbo 2.0 Input Tokens';              Version = '2.0' }
            @{ Name = 'GPT4omini Input Tokens';                    Version = '4' }
            @{ Name = 'GPT 4o Input Tokens';                       Version = '4' }
            @{ Name = '5.4 opt Dz 1M Tokens';                      Version = '5.4' }
            @{ Name = '6-astra ShortCo Cd Inp Std Gl 1M Tokens';   Version = '6' }
            @{ Name = 'G42 Model Input Tokens';                    Version = 'N/A' }
            @{ Name = 'Model 2407 Input Tokens';                   Version = 'N/A' }
            @{ Name = '';                                          Version = 'N/A' }
        ) { Get-AiModelVersion $Name | Should -Be $Version }

        It 'converts 35 to 3.5 for GPT only, not for Grok' {
            Get-AiModelVersion 'Grok35 Input Tokens' | Should -Be '35'
        }
    }

    Context 'Get-AiModelCreator' {
        It 'model creator of <Sub> is <Creator>' -ForEach @(
            @{ Sub = 'Claude Models'; Creator = 'Anthropic' }
            @{ Sub = 'Azure Llama Models'; Creator = 'Meta' }
            @{ Sub = 'Codestral'; Creator = 'Mistral' }
            @{ Sub = 'Azure OpenAI GPT5'; Creator = 'OpenAi' }
            @{ Sub = 'Azure Phi Models'; Creator = 'Microsoft' }
            @{ Sub = 'Grok Kimi'; Creator = 'SpaceX' }
            @{ Sub = 'FW Kimi'; Creator = 'Moonshot' }
            @{ Sub = 'Azure AI Search Cohere'; Creator = 'Microsoft' }
            @{ Sub = 'Deepseek Models'; Creator = 'Deepseek' }
            @{ Sub = 'Cohere Models'; Creator = 'Cohere' }
            @{ Sub = 'Something else'; Creator = 'Other' }
            @{ Sub = ''; Creator = 'Other' }
        ) { Get-AiModelCreator $Sub | Should -Be $Creator }
    }

    Context 'Get-AiMeterClassification' {
        It 'returns null for a meter that is not included' {
            Get-AiMeterClassification 'Virtual Machines' 'Dv5 Series' 'D2 v5' 'Compute' 'Guid' | Should -BeNullOrEmpty
        }

        It 'classifies a token meter' {
            $c = Get-AiMeterClassification 'Foundry Models' 'Azure OpenAI GPT5' '5.4 opt Dz 1M Tokens' 'AI + Machine Learning' 'Guid'
            @($c.Keys) | Should -Be @('Provider','IsTokenMeter','TokenType','IsCachedToken','IsBatchToken','TokenContextType','TokenLocation','IsCopilotMeter','CopilotProvider','IsCommitmentMeter','IsConsumptionMeter','CopilotType','IsAgentMeter','AgentType','ModelVersion','ModelCreator')
            $c.Provider | Should -Be 'Microsoft';  $c.IsTokenMeter | Should -BeTrue;  $c.TokenType | Should -Be 'Output'
            $c.TokenLocation | Should -Be 'DataZone';  $c.ModelVersion | Should -Be '5.4';  $c.ModelCreator | Should -Be 'OpenAi'
            $c.IsCopilotMeter | Should -BeFalse;  $c.CopilotProvider | Should -Be 'N/A';  $c.CopilotType | Should -Be 'N/A'
            $c.IsAgentMeter | Should -BeFalse;  $c.AgentType | Should -Be 'N/A';  $c.IsConsumptionMeter | Should -BeFalse
            $c.IsCachedToken | Should -BeFalse;  $c.IsBatchToken | Should -BeFalse;  $c.TokenContextType | Should -Be 'N/A'
        }

        It 'classifies a meter that is both a token meter and a Copilot meter' {
            $c = Get-AiMeterClassification 'X' 'Y' 'Copilot Input Tokens' 'Microsoft 365 Copilot' 'Guid'
            $c.IsTokenMeter | Should -BeTrue;  $c.TokenType | Should -Be 'Input';  $c.Provider | Should -Be 'Microsoft'
            $c.IsCopilotMeter | Should -BeTrue;  $c.CopilotProvider | Should -Be 'Microsoft';  $c.CopilotType | Should -Be 'M365'
            $c.IsConsumptionMeter | Should -BeTrue;  $c.IsAgentMeter | Should -BeTrue;  $c.AgentType | Should -Be 'Copilot - M365'
            $c.IsCommitmentMeter | Should -BeFalse
        }

        It 'classifies a Copilot credit reservation as a commitment' {
            $c = Get-AiMeterClassification 'X' 'Copilot Credit Reservation' 'Copilot Credit Unit' 'Microsoft 365 Copilot' 'Guid'
            $c.IsCopilotMeter | Should -BeTrue;  $c.IsCommitmentMeter | Should -BeTrue;  $c.CopilotType | Should -Be 'M365'
        }

        It 'classifies Copilot row <Sub> / <Family>' -ForEach @(
            @{ Cat = 'Microsoft Copilot Studio'; Sub = 'Microsoft Copilot Studio'; Name = 'Pay As You Go Copilot Credit'; Family = 'Microsoft 365 Copilot'; Kind = 'Guid'; Type = 'M365'; Agent = 'Copilot - M365'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'Microsoft Copilot Studio'; Sub = 'Microsoft 365 Agent'; Name = 'Pay As You Go Copilot Credit'; Family = 'Microsoft 365 Copilot'; Kind = 'Guid'; Type = 'M365'; Agent = 'Agent 365'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'X'; Sub = 'Microsoft Dragon Copilot'; Name = 'Dragon Copilot Unit'; Family = 'Security'; Kind = 'Guid'; Type = 'Dragon'; Agent = 'Copilot - Dragon'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'GitHub'; Sub = 'GitHub Copilot'; Name = 'AI Credit GAC'; Family = 'Developer Tools'; Kind = 'Other'; Type = 'GitHub'; Agent = 'Copilot - GitHub'; Commit = $false; CopilotProvider = 'Vendor' }
            @{ Cat = 'Microsoft Fabric'; Sub = 'Fabric Capacity'; Name = 'Copilot and AI Capacity Usage CU'; Family = 'Data'; Kind = 'Guid'; Type = 'Fabric'; Agent = 'Copilot - Fabric'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'X'; Sub = 'Y'; Name = 'Security Copilot Unit'; Family = 'Security'; Kind = 'Guid'; Type = 'Security'; Agent = 'Copilot - Security'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'X'; Sub = 'Y'; Name = 'Some Copilot Unit'; Family = 'Compute'; Kind = 'Guid'; Type = 'other'; Agent = 'Copilot - other'; Commit = $false; CopilotProvider = 'Microsoft' }
            @{ Cat = 'X'; Sub = 'Copilot Credit Pre-Purchase Plan'; Name = 'Copilot Credit Commit Unit'; Family = 'Microsoft 365 Copilot'; Kind = 'Guid'; Type = 'M365'; Agent = 'Copilot - M365'; Commit = $true; CopilotProvider = 'Microsoft' }
            @{ Cat = 'GitHub'; Sub = 'GitHub AI Credits Pre-Purchase Plan'; Name = '100,000 GHAICCUs GitHub AI Credit Commit Unit'; Family = 'Developer Tools'; Kind = 'Guid'; Type = 'GitHub'; Agent = 'Generic'; Commit = $true; CopilotProvider = 'Microsoft' }
        ) {
            $c = Get-AiMeterClassification $Cat $Sub $Name $Family $Kind
            $c.IsCopilotMeter | Should -BeTrue;  $c.IsConsumptionMeter | Should -BeTrue;  $c.IsAgentMeter | Should -BeTrue
            $c.CopilotType | Should -Be $Type;  $c.AgentType | Should -Be $Agent
            $c.IsCommitmentMeter | Should -Be $Commit;  $c.CopilotProvider | Should -Be $CopilotProvider
        }

        It 'classifies agent row <Sub> as <Agent>' -ForEach @(
            @{ Sub = 'Azure Agent Unit'; Agent = 'Azure SRE Agent'; Commit = $false }
            @{ Sub = 'Azure Monitor Observability Agent'; Agent = 'Azure Monitor Observability Agent'; Commit = $false }
            @{ Sub = 'Microsoft 365 Agent'; Agent = 'Agent 365'; Commit = $false }
            @{ Sub = 'Microsoft Agent Pre-Purchase Plan'; Agent = 'Generic'; Commit = $true }
        ) {
            $c = Get-AiMeterClassification 'X' $Sub 'Unit' 'AI + Machine Learning' 'Guid'
            $c.IsAgentMeter | Should -BeTrue;  $c.AgentType | Should -Be $Agent;  $c.IsCommitmentMeter | Should -Be $Commit
            $c.IsCopilotMeter | Should -BeFalse;  $c.IsTokenMeter | Should -BeFalse;  $c.TokenType | Should -Be 'N/A'
        }

        It 'classifies the Claude consumption unit meter' {
            $c = Get-AiMeterClassification 'X' 'Claude Models' 'Consumption Unit' '' 'ClaudeConsumptionUnits'
            $c.Provider | Should -Be 'Anthropic';  $c.IsTokenMeter | Should -BeTrue
            $c.TokenType | Should -Be 'ConsumptionUnit';  $c.IsConsumptionMeter | Should -BeTrue
        }

        It 'stops on a Copilot meter from Anthropic' {
            { Get-AiMeterClassification 'X' 'Claude Models' 'Claude Copilot Unit' '' 'Other' } | Should -Throw '*Claude Copilot Unit*'
        }
    }

    Context 'Read-AiMeterPricesheet' {
        It 'builds a lowercase key joined by the unit separator' {
            Get-AiMeterKey 'A' 'B' 'C' | Should -BeExactly "a$([char]31)b$([char]31)c"
            Get-AiMeterKey $null 'B' '' | Should -BeExactly "$([char]31)b$([char]31)"
        }

        It 'keeps included tuples only, one per key' {
            $zip = New-TestPricesheet "$TestDrive/a.zip" @(
                @{ MeterCategory = 'Foundry Models'; MeterSubCategory = 'Azure OpenAI GPT5'; MeterName = '5.4 opt Dz 1M Tokens'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'AI + Machine Learning' }
                @{ MeterCategory = 'Foundry Models'; MeterSubCategory = 'Azure OpenAI GPT5'; MeterName = '5.4 opt Dz 1M Tokens'; MeterId = '11111111-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'AI + Machine Learning' }
                @{ MeterCategory = 'Virtual Machines'; MeterSubCategory = 'Dv5 Series'; MeterName = 'D2 v5'; MeterId = '22222222-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'Compute' }
            )
            $r = Read-AiMeterPricesheet $zip
            $r.Count | Should -Be 1
            $row = $r[(Get-AiMeterKey 'foundry models' 'AZURE OPENAI GPT5' '5.4 OPT DZ 1M TOKENS')]
            $row.Name | Should -BeExactly '5.4 opt Dz 1M Tokens'
            $row.MeterIdKind | Should -Be 'Guid'
            $row.PSObject.Properties.Name | Should -Be @('Category','Subcategory','Name','ServiceFamily','MeterIdKind')
        }

        It 'reads every json entry in the zip' {
            $zip = New-TestPricesheet "$TestDrive/two.zip" @(New-IncludedRow 'First Input Tokens')
            $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Update')
            try
            {
                $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('part-1.json').Open())
                try { $writer.WriteLine((New-IncludedRow 'Second Input Tokens' | ConvertTo-Json -Compress)) }
                finally { $writer.Dispose() }
            }
            finally { $archive.Dispose() }
            $r = Read-AiMeterPricesheet $zip
            $r.Count | Should -Be 2
            @($r.Values.Name | Sort-Object) | Should -Be @('First Input Tokens', 'Second Input Tokens')
        }

        It 'treats null and missing fields as empty strings' {
            $zip = New-TestPricesheet "$TestDrive/n.zip" @(
                @{ MeterCategory = 'X'; MeterSubCategory = $null; MeterName = 'Input Tokens'; MeterId = 'vendor-1' }
            )
            $row = @((Read-AiMeterPricesheet $zip).Values)[0]
            $row.Subcategory | Should -BeExactly ''
            $row.ServiceFamily | Should -BeExactly ''
            $row.MeterIdKind | Should -Be 'Other'
        }

        It 'stops when one tuple has two service families' {
            $zip = New-TestPricesheet "$TestDrive/f.zip" @(
                (New-IncludedRow 'Input Tokens' -Family 'A')
                (New-IncludedRow 'Input Tokens' -Family 'B')
            )
            { Read-AiMeterPricesheet $zip } | Should -Throw '*service famil*'
        }

        It 'stops when one tuple mixes meter ID kinds' {
            $zip = New-TestPricesheet "$TestDrive/k.zip" @(
                (New-IncludedRow 'Input Tokens' -Id '0000b7f7-3b31-5534-9c09-4b23944d397c')
                (New-IncludedRow 'Input Tokens' -Id 'vendor-1')
            )
            { Read-AiMeterPricesheet $zip } | Should -Throw '*meter ID kind*'
        }

        It 'stops when two tuples differ only in case' {
            $zip = New-TestPricesheet "$TestDrive/c.zip" @(
                (New-IncludedRow 'Input Tokens')
                (New-IncludedRow 'INPUT TOKENS')
            )
            { Read-AiMeterPricesheet $zip } | Should -Throw '*differ only in letter case*'
        }

        It 'stops when the zip has no json entry' {
            $zip = New-TestPricesheet "$TestDrive/t.zip" @(New-IncludedRow 'Input Tokens') -EntryName 'readme.txt'
            { Read-AiMeterPricesheet $zip } | Should -Throw '*no .json entry*'
        }

        It 'stops when no row has a meter name field' {
            $zip = New-TestPricesheet "$TestDrive/s.zip" @(@{ Foo = 1 }, @{ Bar = 2 })
            { Read-AiMeterPricesheet $zip } | Should -Throw '*price sheet*'
        }

        It 'reads field names in any letter case' {
            $zip = New-TestPricesheet "$TestDrive/l.zip" @(
                @{ meterCategory = 'X'; meterSubCategory = 'Y'; meterName = 'Input Tokens'; meterId = 'claude-consumption-units'; serviceFamily = 'Fam' }
            )
            $r = Read-AiMeterPricesheet $zip
            $r.Count | Should -Be 1
            $row = @($r.Values)[0]
            $row.Category | Should -BeExactly 'X'
            $row.Subcategory | Should -BeExactly 'Y'
            $row.ServiceFamily | Should -BeExactly 'Fam'
            $row.MeterIdKind | Should -Be 'ClaudeConsumptionUnits'
        }

        It 'finds a meter whatever the letter case of the inclusion word' {
            $zip = New-TestPricesheet "$TestDrive/u.zip" @(
                (New-IncludedRow 'INPUT TOKENS')
                (New-IncludedRow 'Pay As You Go COPILOT Credit')
            )
            (Read-AiMeterPricesheet $zip).Count | Should -Be 2
        }

        It 'finds a meter included only through its subcategory, meter ID, or GitHub rule' {
            $zip = New-TestPricesheet "$TestDrive/p.zip" @(
                @{ MeterCategory = 'X'; MeterSubCategory = 'AZURE AGENT UNIT'; MeterName = 'SRE Unit'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'F' }
                @{ MeterCategory = 'X'; MeterSubCategory = 'GitHub AI Credits Pre-Purchase Plan'; MeterName = 'Commit Unit'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397d'; ServiceFamily = 'F' }
                @{ MeterCategory = 'X'; MeterSubCategory = 'Y'; MeterName = 'Consumption Unit'; MeterId = 'Claude-Consumption-Units'; ServiceFamily = 'F' }
                @{ MeterCategory = 'github'; MeterSubCategory = 'Y'; MeterName = 'ai credit gac'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397e'; ServiceFamily = 'F' }
            )
            (Read-AiMeterPricesheet $zip).Count | Should -Be 4
        }

        It 'finds a meter whose name is written with JSON escapes' {
            $zip = "$TestDrive/e.zip"
            $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
            try
            {
                $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('part-0.json').Open())
                try { $writer.WriteLine('{"MeterCategory":"X","MeterSubCategory":"Y","MeterName":"Input Tokens","MeterId":"v","ServiceFamily":"F"}') }
                finally { $writer.Dispose() }
            }
            finally { $archive.Dispose() }
            @((Read-AiMeterPricesheet $zip).Values)[0].Name | Should -BeExactly 'Input Tokens'
        }

        It 'pre-filter passes the <Branch> literal in another letter case: <Category> / <Subcategory> / <Name> / <MeterId>' -ForEach $literalCases {
            $zip = New-TestPricesheet "$TestDrive/lit.zip" @(
                @{ MeterCategory = $Category; MeterSubCategory = $Subcategory; MeterName = $Name; MeterId = $MeterId; ServiceFamily = 'F' }
            )
            try { (Read-AiMeterPricesheet $zip).Count | Should -Be 1 }
            finally { Remove-Item -LiteralPath $zip }
        }

        It 'names the entry and line number of a malformed JSON line, without its content' {
            $zip = "$TestDrive/bad.zip"
            $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
            try
            {
                $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('part-7.json').Open())
                try
                {
                    $writer.WriteLine('{"MeterCategory":"Virtual Machines","MeterName":"D2 v5","UnitPrice":1.0}')
                    $writer.WriteLine('{"MeterName":"Input Tokens","UnitPrice":9.87,"Note":"SECRETVALUE"')
                }
                finally { $writer.Dispose() }
            }
            finally { $archive.Dispose() }
            $err = { Read-AiMeterPricesheet $zip } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike '*part-7.json*'
            $err.Exception.Message | Should -BeLike '*Line 2 *'
            $err.Exception.Message | Should -Not -Match 'SECRETVALUE|9\.87|Input Tokens'
        }

        It 'keeps no field beyond the five tuple fields' {
            $zip = New-TestPricesheet "$TestDrive/x.zip" @(New-IncludedRow 'Input Tokens')
            $text = @((Read-AiMeterPricesheet $zip).Values) | ConvertTo-Json -Compress
            $text | Should -Not -Match 'secret|1\.23'
        }
    }

    Context 'Import-AiMeterInput' {
        It 'returns an empty hashtable for a missing file' {
            $r = Import-AiMeterInput "$TestDrive/missing.csv"
            $r | Should -BeOfType [hashtable]
            $r.Count | Should -Be 0
        }

        It 'reads the five rule inputs exactly as written and ignores classification columns' {
            $path = "$TestDrive/in.csv"
            $rows = @(
                [pscustomobject]@{ x_SkuMeterCategory = ''; x_SkuMeterSubcategory = 'Sub, "q"'; SkuMeter = 'Modèle ß  Input Tokens'; x_SkuServiceFamily = 'F'; MeterIdKind = 'Other'; Provider = 'Zzz' }
                [pscustomobject]@{ x_SkuMeterCategory = 'C'; x_SkuMeterSubcategory = 'S'; SkuMeter = 'N Tokens'; x_SkuServiceFamily = ''; MeterIdKind = 'Guid'; Provider = 'Zzz' }
            )
            $rows | Export-Csv -Path $path -UseQuotes Always -NoTypeInformation -Encoding utf8
            $r = Import-AiMeterInput $path
            $r.Count | Should -Be 2
            $a = $r[(Get-AiMeterKey '' 'Sub, "q"' 'Modèle ß  Input Tokens')]
            $a.Category | Should -BeExactly ''
            $a.Subcategory | Should -BeExactly 'Sub, "q"'
            $a.Name | Should -BeExactly 'Modèle ß  Input Tokens'
            $a.MeterIdKind | Should -BeExactly 'Other'
            $a.PSObject.Properties.Name | Should -Be @('Category', 'Subcategory', 'Name', 'ServiceFamily', 'MeterIdKind')
            $r[(Get-AiMeterKey 'C' 'S' 'N Tokens')].ServiceFamily | Should -BeExactly ''
        }

        It 'returns an empty hashtable for a file with only the header' {
            $path = "$TestDrive/header.csv"
            Set-Content -LiteralPath $path -Value '"x_SkuMeterCategory","x_SkuMeterSubcategory","SkuMeter","x_SkuServiceFamily","MeterIdKind","IsDefault"' -Encoding utf8
            (Import-AiMeterInput $path).Count | Should -Be 0
        }

        It 'stops on a CSV without the rule-input columns and names the file and the missing columns' {
            $path = "$TestDrive/other.csv"
            @([pscustomobject]@{ x_SkuMeterCategory = 'C'; SkuMeter = 'N'; ServiceName = 'S' }) | Export-Csv -Path $path -UseQuotes Always -NoTypeInformation -Encoding utf8
            $err = { Import-AiMeterInput $path } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike '*other.csv*'
            $err.Exception.Message | Should -BeLike '*x_SkuMeterSubcategory, x_SkuServiceFamily, MeterIdKind*'
        }

        It 'stops on an empty file' {
            $path = "$TestDrive/empty.csv"
            Set-Content -LiteralPath $path -Value '' -NoNewline
            { Import-AiMeterInput $path } | Should -Throw '*x_SkuMeterCategory*'
        }
    }

    Context 'Merge-AiMeterInput' {
        It 'lets the price sheet win and keeps rows that left the price sheet' {
            $old = @{ k1 = [pscustomobject]@{ Name = 'old casing' }; k2 = [pscustomobject]@{ Name = 'retired' } }
            $new = @{ k1 = [pscustomobject]@{ Name = 'Old Casing' }; k3 = [pscustomobject]@{ Name = 'added' } }
            $m = Merge-AiMeterInput $old $new
            $m.Count | Should -Be 3
            $m.k1.Name | Should -BeExactly 'Old Casing'
            $m.k2.Name | Should -Be 'retired'
            $m.k3.Name | Should -Be 'added'
        }

        It 'does not change its arguments' {
            $old = @{ k1 = [pscustomobject]@{ Name = 'a' } }
            $new = @{ k2 = [pscustomobject]@{ Name = 'b' } }
            $null = Merge-AiMeterInput $old $new
            $old.Count | Should -Be 1
            $new.Count | Should -Be 1
        }
    }

    Context 'ConvertTo-AiMeterRow' {
        It 'marks the row whose subcategory equals the category as default' {
            $in = @{}
            foreach ($sub in 'Microsoft 365 Agent', 'Microsoft Copilot Studio', 'Microsoft Contact Center Intelligence')
            {
                $in[(Get-AiMeterKey 'Microsoft Copilot Studio' $sub 'Pay As You Go Copilot Credit')] = New-MeterInput 'Microsoft Copilot Studio' $sub 'Pay As You Go Copilot Credit' 'Microsoft 365 Copilot'
            }
            $rows = ConvertTo-AiMeterRow $in
            @($rows | Where-Object IsDefault -eq 'true').x_SkuMeterSubcategory | Should -Be 'Microsoft Copilot Studio'
            @($rows | Where-Object IsDefault -eq 'false').Count | Should -Be 2
        }

        It 'falls back to the first subcategory when none equals the category' {
            $in = @{}
            foreach ($sub in 'b sub', 'A sub')
            {
                $in[(Get-AiMeterKey 'Cat' $sub 'Input Tokens')] = New-MeterInput 'Cat' $sub 'Input Tokens'
            }
            $rows = ConvertTo-AiMeterRow $in
            @($rows | Where-Object IsDefault -eq 'true').x_SkuMeterSubcategory | Should -Be 'A sub'
            @($rows | Where-Object IsDefault -eq 'true').Count | Should -Be 1
        }

        It 'picks one default per category and meter name pair' {
            $in = @{}
            foreach ($n in 'One Tokens', 'Two Tokens')
            {
                foreach ($sub in 'S1', 'S2')
                {
                    $in[(Get-AiMeterKey 'Cat' $sub $n)] = New-MeterInput 'Cat' $sub $n
                }
            }
            $rows = ConvertTo-AiMeterRow $in
            $rows.Count | Should -Be 4
            @($rows | Where-Object IsDefault -eq 'true').Count | Should -Be 2
        }

        It 'writes the 22 columns in order, with lowercase booleans' {
            $in = @{ (Get-AiMeterKey 'Cat' 'Sub' 'GPT-4o Input Tokens') = New-MeterInput 'Cat' 'Sub' 'GPT-4o Input Tokens' }
            $rows = @(ConvertTo-AiMeterRow $in)
            $rows[0].PSObject.Properties.Name | Should -Be @(
                'x_SkuMeterCategory', 'x_SkuMeterSubcategory', 'SkuMeter', 'x_SkuServiceFamily', 'MeterIdKind', 'IsDefault',
                'Provider', 'IsTokenMeter', 'TokenType', 'IsCachedToken', 'IsBatchToken', 'TokenContextType', 'TokenLocation',
                'IsCopilotMeter', 'CopilotProvider', 'IsCommitmentMeter', 'IsConsumptionMeter', 'CopilotType', 'IsAgentMeter',
                'AgentType', 'ModelVersion', 'ModelCreator')
            $rows[0].IsTokenMeter | Should -BeExactly 'true'
            $rows[0].IsCopilotMeter | Should -BeExactly 'false'
            $rows[0].IsDefault | Should -BeExactly 'true'
            $rows[0].x_SkuMeterCategory | Should -BeExactly 'Cat'
            $rows[0].SkuMeter | Should -BeExactly 'GPT-4o Input Tokens'
        }

        It 'sorts with an ordinal comparison of lowercased keys' {
            $in = @{}
            foreach ($n in 'b Tokens', 'A Tokens', 'a2 Tokens')
            {
                $in[(Get-AiMeterKey 'Cat' 'Sub' $n)] = New-MeterInput 'Cat' 'Sub' $n
            }
            @(ConvertTo-AiMeterRow $in).SkuMeter | Should -Be @('A Tokens', 'a2 Tokens', 'b Tokens')
        }

        It 'drops rows the inclusion rule no longer includes' {
            $in = @{ (Get-AiMeterKey 'Virtual Machines' 'Dv5 Series' 'D2 v5') = New-MeterInput 'Virtual Machines' 'Dv5 Series' 'D2 v5' 'Compute' }
            @(ConvertTo-AiMeterRow $in).Count | Should -Be 0
        }

        It 'does not write to the host' {
            $in = @{ (Get-AiMeterKey 'Cat' 'Sub' 'Input Tokens') = New-MeterInput 'Cat' 'Sub' 'Input Tokens' }
            $out = ConvertTo-AiMeterRow $in 6>&1 5>&1 4>&1 3>&1
            @($out | Where-Object { $_ -isnot [pscustomobject] }).Count | Should -Be 0
        }
    }

    Context 'Get-AiMeterSummary' {
        BeforeAll {
            # Builds one CSV row with the key, the given token type, and fixed values elsewhere.
            function New-SummaryRow
            {
                param([string]$Name, [string]$TokenType = 'Input')
                $row = [ordered]@{ x_SkuMeterCategory = 'Cat'; x_SkuMeterSubcategory = 'Sub'; SkuMeter = $Name }
                foreach ($column in (Get-AiMeterColumn).Classification) { $row[$column] = 'N/A' }
                $row.TokenType = $TokenType
                return [pscustomobject]$row
            }
        }

        It 'counts new, changed, kept, and dropped rows' {
            $old = @((New-SummaryRow 'Same Tokens'), (New-SummaryRow 'Changed Tokens' 'Input'), (New-SummaryRow 'Dropped Tokens'))
            $new = @((New-SummaryRow 'same tokens'), (New-SummaryRow 'Changed Tokens' 'Output'), (New-SummaryRow 'Added Tokens'))
            $sheetKeys = @((Get-AiMeterKey 'Cat' 'Sub' 'Same Tokens'), (Get-AiMeterKey 'Cat' 'Sub' 'Added Tokens'))
            $s = Get-AiMeterSummary -OldRows $old -NewRows $new -SheetKeys $sheetKeys
            $s.Written | Should -Be 3
            $s.New | Should -Be 1
            $s.Changed | Should -Be 1
            $s.Kept | Should -Be 1
            $s.Dropped | Should -Be 1
        }

        It 'counts the values of every classification column, sorted by value' {
            $new = @((New-SummaryRow 'A Tokens' 'Output'), (New-SummaryRow 'B Tokens' 'Input'), (New-SummaryRow 'C Tokens' 'Output'))
            $s = Get-AiMeterSummary -OldRows @() -NewRows $new -SheetKeys @()
            @($s.ValueCounts.Keys) | Should -Be (Get-AiMeterColumn).Classification
            $s.ValueCounts.TokenType | Should -Be @('Input=1', 'Output=2')
            $s.ValueCounts.Provider | Should -Be @('N/A=3')
        }

        It 'counts every row as new when there is no existing file' {
            $s = Get-AiMeterSummary -OldRows @() -NewRows @((New-SummaryRow 'A Tokens')) -SheetKeys @((Get-AiMeterKey 'Cat' 'Sub' 'A Tokens'))
            $s.New | Should -Be 1
            $s.Changed | Should -Be 0
            $s.Kept | Should -Be 0
            $s.Dropped | Should -Be 0
        }

        It 'does not write to the host' {
            $out = Get-AiMeterSummary -OldRows @() -NewRows @((New-SummaryRow 'A Tokens')) -SheetKeys @() 6>&1 5>&1 4>&1 3>&1
            @($out).Count | Should -Be 1
        }
    }

    Context 'Script run end to end' {
        It 'is idempotent: a second run gives a byte-identical file' {
            $zip = New-TestPricesheet "$TestDrive/idem.zip" @((New-IncludedRow 'Input Tokens'), (New-IncludedRow 'Output Tokens'))
            $out = "$TestDrive/idem.csv"
            Invoke-AiMetersScript $zip $out | Should -Be 0
            $first = (Get-FileHash $out).Hash
            Invoke-AiMetersScript $zip $out | Should -Be 0
            (Get-FileHash $out).Hash | Should -Be $first
            @(Import-Csv $out).Count | Should -Be 2
        }

        It 'keeps a retired meter and reclassifies it from its stored inputs' {
            $out = "$TestDrive/retired.csv"
            $zip1 = New-TestPricesheet "$TestDrive/r1.zip" @((New-IncludedRow 'Alpha Input Tokens'), (New-IncludedRow 'Beta Output Tokens'))
            Invoke-AiMetersScript $zip1 $out | Should -Be 0
            $before = @(Import-Csv $out)
            $zip2 = New-TestPricesheet "$TestDrive/r2.zip" @((New-IncludedRow 'Alpha Input Tokens'))
            Invoke-AiMetersScript $zip2 $out | Should -Be 0
            $after = @(Import-Csv $out)
            $after.Count | Should -Be 2
            $b = $after | Where-Object SkuMeter -eq 'Beta Output Tokens'
            $b | Should -Not -BeNullOrEmpty
            $b.TokenType | Should -Be (($before | Where-Object SkuMeter -eq 'Beta Output Tokens').TokenType)
            $b.IsTokenMeter | Should -BeExactly 'true'
        }

        It 'round-trips keys with commas, quotes, non-ASCII characters, and repeated spaces' {
            $names = @('Input, "Pro"  Tokens', 'Modèle ß Input Tokens')
            $zip = New-TestPricesheet "$TestDrive/rt.zip" @($names | ForEach-Object { New-IncludedRow $_ })
            $out = "$TestDrive/rt.csv"
            Invoke-AiMetersScript $zip $out | Should -Be 0
            $first = (Get-FileHash $out).Hash
            Invoke-AiMetersScript $zip $out | Should -Be 0
            (Get-FileHash $out).Hash | Should -Be $first
            $read = @(Import-Csv $out -Encoding utf8).SkuMeter
            foreach ($n in $names) { $read | Should -Contain $n }
            foreach ($n in $names) { ($read | Where-Object { $_ -ceq $n }).Count | Should -Be 1 }
        }

        It 'round-trips keys with a leading and a trailing space' {
            $names = @(' Leading Input Tokens', 'Trailing Input Tokens ')
            $zip = New-TestPricesheet "$TestDrive/sp.zip" @($names | ForEach-Object { New-IncludedRow $_ })
            $out = "$TestDrive/sp.csv"
            Invoke-AiMetersScript $zip $out | Should -Be 0
            $first = (Get-FileHash $out).Hash
            Invoke-AiMetersScript $zip $out | Should -Be 0
            (Get-FileHash $out).Hash | Should -Be $first
            $read = @(Import-Csv $out -Encoding utf8).SkuMeter
            $read.Count | Should -Be 2
            foreach ($n in $names) { ($read | Where-Object { $_ -ceq $n }).Count | Should -Be 1 }
        }

        It 'leaves a file that is not an AI meters file untouched' {
            $out = "$TestDrive/other.csv"
            @([pscustomobject]@{ ServiceName = 'S'; ServiceCategory = 'C' }) | Export-Csv -Path $out -UseQuotes Always -NoTypeInformation -Encoding utf8
            $hash = (Get-FileHash $out).Hash
            Invoke-AiMetersScript (New-TestPricesheet "$TestDrive/o1.zip" @(New-IncludedRow 'Input Tokens')) $out | Should -Not -Be 0
            (Get-FileHash $out).Hash | Should -Be $hash
        }

        It 'stops on a price sheet without AI meters and leaves an existing file untouched' {
            $out = "$TestDrive/noai.csv"
            Invoke-AiMetersScript (New-TestPricesheet "$TestDrive/a1.zip" @(New-IncludedRow 'Input Tokens')) $out | Should -Be 0
            $hash = (Get-FileHash $out).Hash
            $noAi = New-TestPricesheet "$TestDrive/a2.zip" @(@{ MeterCategory = 'Virtual Machines'; MeterSubCategory = 'Dv5 Series'; MeterName = 'D2 v5'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'Compute' })
            Invoke-AiMetersScript $noAi $out | Should -Not -Be 0
            (Get-FileHash $out).Hash | Should -Be $hash
        }

        It 'stops on a price sheet without AI meters and creates no file' {
            $out = "$TestDrive/noai-new.csv"
            $noAi = New-TestPricesheet "$TestDrive/a3.zip" @(@{ MeterCategory = 'Virtual Machines'; MeterSubCategory = 'Dv5 Series'; MeterName = 'D2 v5'; MeterId = '0000b7f7-3b31-5534-9c09-4b23944d397c'; ServiceFamily = 'Compute' })
            Invoke-AiMetersScript $noAi $out | Should -Not -Be 0
            Test-Path -LiteralPath $out | Should -BeFalse
        }

        It 'never writes prices, billing IDs, or meter IDs' {
            $zip = New-TestPricesheet "$TestDrive/np.zip" @(New-IncludedRow 'Input Tokens')
            $out = "$TestDrive/np.csv"
            Invoke-AiMetersScript $zip $out | Should -Be 0
            Get-Content -Raw $out | Should -Not -Match 'secret|1\.23|0000b7f7'
        }

        It 'leaves the existing file untouched when the price sheet has a conflict' {
            $out = "$TestDrive/conf.csv"
            Invoke-AiMetersScript (New-TestPricesheet "$TestDrive/c1.zip" @(New-IncludedRow 'Input Tokens')) $out | Should -Be 0
            $hash = (Get-FileHash $out).Hash
            $bad = New-TestPricesheet "$TestDrive/c2.zip" @((New-IncludedRow 'Input Tokens' -Family 'A'), (New-IncludedRow 'Input Tokens' -Family 'B'))
            Invoke-AiMetersScript $bad $out | Should -Not -Be 0
            (Get-FileHash $out).Hash | Should -Be $hash
        }

        It 'leaves the existing file untouched when the price sheet has no price rows' {
            $out = "$TestDrive/nop.csv"
            Invoke-AiMetersScript (New-TestPricesheet "$TestDrive/n1.zip" @(New-IncludedRow 'Input Tokens')) $out | Should -Be 0
            $hash = (Get-FileHash $out).Hash
            $empty = New-TestPricesheet "$TestDrive/n2.zip" @(New-IncludedRow 'Input Tokens') -EntryName 'readme.txt'
            Invoke-AiMetersScript $empty $out | Should -Not -Be 0
            (Get-FileHash $out).Hash | Should -Be $hash
        }

        It 'leaves no temporary file behind' {
            $out = "$TestDrive/tmp/clean.csv"
            New-Item -ItemType Directory -Path "$TestDrive/tmp" | Out-Null
            Invoke-AiMetersScript (New-TestPricesheet "$TestDrive/t1.zip" @(New-IncludedRow 'Input Tokens')) $out | Should -Be 0
            @(Get-ChildItem "$TestDrive/tmp").Name | Should -Be @('clean.csv')
        }
    }
}
