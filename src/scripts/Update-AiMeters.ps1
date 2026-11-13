# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#Requires -Version 7.0

<#
    .SYNOPSIS
    Generates the AI meters open data file from an Azure price sheet.

    .DESCRIPTION
    Reads a price sheet and classifies AI-related meters (tokens, Copilot, agents, and
    commitments) into AiMeters.csv. No price, billing ID, meter ID, product ID, or SKU ID
    is written to the output.

    .PARAMETER PricesheetPath
    Path to the price sheet to read.

    .PARAMETER OutputPath
    Path of the CSV file to write. Defaults to AiMeters.csv in the open-data folder.
#>
param(
    [Parameter(Mandatory)]
    [string]$PricesheetPath,

    [string]$OutputPath = "$PSScriptRoot/../open-data/AiMeters.csv"
)

function Get-AiMeterRuleLiteral
{
    <#
        .SYNOPSIS
        Returns the literals that decide which meters are AI meters, and how Copilot, commitment,
        and agent meters are recognized.

        .DESCRIPTION
        The single source for these literals. The inclusion rule, the classification, and the
        pre-filter of the price sheet reader all read them from here, so they can't drift apart.
        All comparisons with these literals are case-insensitive.

        .OUTPUTS
        An ordered hashtable with these entries:
        - TokenNameKeyword: a meter name containing it is a token meter.
        - CopilotNameKeyword: a meter name containing it is a Copilot meter.
        - ConsumptionUnitsMeterId: the meter ID of the Claude consumption units meter.
        - GitHubCreditCategory and GitHubCreditMeterName: the category and meter name of the GitHub AI credit meter.
        - AgentSubcategories: agent subcategories mapped to their agent type.
        - GitHubPlanSubcategories: GitHub pre-purchase plan subcategories.
        - PrePurchasePlanSubcategories: all agent and GitHub pre-purchase plan subcategories.
        - CopilotCommitmentSubcategories: subcategories that make a Copilot meter a commitment.
        - DragonCopilotSubcategory: the subcategory of the Dragon Copilot type.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    $githubPlans = @('GitHub Pre-Purchase Plan', 'GitHub AI Credits Pre-Purchase Plan')
    return [ordered]@{
        TokenNameKeyword               = 'tokens'
        CopilotNameKeyword             = 'copilot'
        ConsumptionUnitsMeterId        = 'claude-consumption-units'
        GitHubCreditCategory           = 'GitHub'
        GitHubCreditMeterName          = 'AI Credit GAC'
        AgentSubcategories             = [ordered]@{
            'Azure Agent Unit'                  = 'Azure SRE Agent'
            'Azure Monitor Observability Agent' = 'Azure Monitor Observability Agent'
            'Microsoft 365 Agent'               = 'Agent 365'
        }
        GitHubPlanSubcategories        = $githubPlans
        PrePurchasePlanSubcategories   = @('Microsoft Agent Pre-Purchase Plan') + $githubPlans
        CopilotCommitmentSubcategories = @('Copilot Credit Reservation', 'Copilot Credit Pre-Purchase Plan')
        DragonCopilotSubcategory       = 'Microsoft Dragon Copilot'
    }
}

function Get-AiMeterColumn
{
    <#
        .SYNOPSIS
        Returns the column names of AiMeters.csv.

        .OUTPUTS
        An ordered hashtable with Input (the five rule-input columns, the first three being the
        key), Classification (the 16 derived columns), and All (the 22 columns in file order:
        the input columns, IsDefault, then the classification columns).
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    $inputColumns = @('x_SkuMeterCategory', 'x_SkuMeterSubcategory', 'SkuMeter', 'x_SkuServiceFamily', 'MeterIdKind')
    $classificationColumns = @(
        'Provider', 'IsTokenMeter', 'TokenType', 'IsCachedToken', 'IsBatchToken', 'TokenContextType', 'TokenLocation',
        'IsCopilotMeter', 'CopilotProvider', 'IsCommitmentMeter', 'IsConsumptionMeter', 'CopilotType', 'IsAgentMeter',
        'AgentType', 'ModelVersion', 'ModelCreator'
    )
    return [ordered]@{
        Input          = $inputColumns
        Classification = $classificationColumns
        All            = $inputColumns + @('IsDefault') + $classificationColumns
    }
}

function Get-AiTokenDirectionAlias
{
    <#
        .SYNOPSIS
        Returns the aliases of the input and output direction hints in token meter names.

        .OUTPUTS
        An ordered hashtable with Output and Input, each an array of lowercase aliases.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        Output = @('outpt', 'output', 'ouput', 'outp', 'out', 'opt')
        Input  = @('input', 'inpt', 'inp', 'gi', 'in')
    }
}

function Get-AiMeterIdKind
{
    <#
        .SYNOPSIS
        Classifies a meter ID as a GUID, the Claude consumption units meter, or other.

        .PARAMETER MeterId
        The meter ID from the price sheet.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$MeterId
    )

    if ($MeterId -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { return 'Guid' }
    if ($MeterId -eq (Get-AiMeterRuleLiteral).ConsumptionUnitsMeterId) { return 'ClaudeConsumptionUnits' }
    return 'Other'
}

function Test-AiTokenMeter
{
    <#
        .SYNOPSIS
        Returns true when a meter is a token meter: its name contains tokens, or it's the Claude
        consumption units meter.

        .PARAMETER Name
        The meter name.

        .PARAMETER MeterIdKind
        The meter ID kind from Get-AiMeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name,
        [AllowEmptyString()][AllowNull()][string]$MeterIdKind
    )

    $literals = Get-AiMeterRuleLiteral
    return [bool](($Name -match [regex]::Escape($literals.TokenNameKeyword)) -or $MeterIdKind -eq 'ClaudeConsumptionUnits')
}

function Test-AiCopilotMeter
{
    <#
        .SYNOPSIS
        Returns true when a meter is a Copilot meter: its name contains copilot, it's the GitHub AI
        credit meter, or its subcategory is a GitHub pre-purchase plan.

        .PARAMETER Category
        The meter category.

        .PARAMETER Subcategory
        The meter subcategory.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Category,
        [AllowEmptyString()][AllowNull()][string]$Subcategory,
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    $literals = Get-AiMeterRuleLiteral
    return [bool](($Name -match [regex]::Escape($literals.CopilotNameKeyword)) -or
        ($Category -eq $literals.GitHubCreditCategory -and $Name -eq $literals.GitHubCreditMeterName) -or
        ($literals.GitHubPlanSubcategories -contains $Subcategory))
}

function Test-AiMeterIncluded
{
    <#
        .SYNOPSIS
        Returns true when a meter is an AI meter (inclusion rule).

        .PARAMETER Category
        The meter category.

        .PARAMETER Subcategory
        The meter subcategory.

        .PARAMETER Name
        The meter name.

        .PARAMETER MeterIdKind
        The meter ID kind from Get-AiMeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Category,
        [AllowEmptyString()][AllowNull()][string]$Subcategory,
        [AllowEmptyString()][AllowNull()][string]$Name,
        [AllowEmptyString()][AllowNull()][string]$MeterIdKind
    )

    if (Test-AiTokenMeter $Name $MeterIdKind) { return $true }
    if (Test-AiCopilotMeter $Category $Subcategory $Name) { return $true }

    $literals = Get-AiMeterRuleLiteral
    $subcategories = @($literals.AgentSubcategories.Keys) + $literals.PrePurchasePlanSubcategories
    return $subcategories -contains $Subcategory
}

function Get-AiMeterProvider
{
    <#
        .SYNOPSIS
        Derives the provider of an AI meter: Anthropic, Microsoft, or Vendor.

        .PARAMETER Subcategory
        The meter subcategory.

        .PARAMETER Name
        The meter name.

        .PARAMETER MeterIdKind
        The meter ID kind from Get-AiMeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Subcategory,
        [AllowEmptyString()][AllowNull()][string]$Name,
        [AllowEmptyString()][AllowNull()][string]$MeterIdKind
    )

    if ("$Name $Subcategory" -match 'claude|anthropic') { return 'Anthropic' }
    if ($MeterIdKind -eq 'Guid') { return 'Microsoft' }
    return 'Vendor'
}

function Get-AiTokenType
{
    <#
        .SYNOPSIS
        Derives the token type of a token meter from its name.

        .DESCRIPTION
        Precedence: ConsumptionUnit, Write, Reasoning, Ambiguous (input and output hints),
        Output, Input, Embedding, then N/A. Direction hints are bounded and may carry an
        attached cd prefix.

        .PARAMETER Name
        The meter name.

        .PARAMETER MeterIdKind
        The meter ID kind from Get-AiMeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name,
        [AllowEmptyString()][AllowNull()][string]$MeterIdKind
    )

    $aliases = Get-AiTokenDirectionAlias
    $outputHint = "(?<![a-z0-9])(?:cd)?(?:$($aliases.Output -join '|'))(?![a-z0-9])"
    $inputHint = "(?<![a-z0-9])(?:cd)?(?:$($aliases.Input -join '|'))(?![a-z0-9])"

    if ($MeterIdKind -eq 'ClaudeConsumptionUnits') { return 'ConsumptionUnit' }
    if ($Name -match '\b(?:wr|write)\b') { return 'Write' }
    if ($Name -match 'reasoning') { return 'Reasoning' }
    $hasOutput = $Name -match $outputHint
    $hasInput = $Name -match $inputHint
    if ($hasInput -and $hasOutput) { return 'Ambiguous' }
    if ($hasOutput) { return 'Output' }
    if ($hasInput) { return 'Input' }
    if ($Name -match 'embed') { return 'Embedding' }
    return 'N/A'
}

function Test-AiCachedToken
{
    <#
        .SYNOPSIS
        Returns true when a token meter name marks cached tokens.

        .DESCRIPTION
        Cached when the name contains cache, or has a bounded cd followed by a direction,
        reasoning, embedding, or write alias. A negative form such as non-cached wins.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    if ($Name -match 'non[\s_-]?cached?|uncached?|not\s+cached?') { return $false }
    if ($Name -match 'cache') { return $true }
    $direction = Get-AiTokenDirectionAlias
    $aliases = (@($direction.Output) + $direction.Input + @('reasoning', 'embedding', 'embed', 'write', 'wr')) -join '|'
    return [bool]($Name -match "(?<![a-z0-9])cd[\s_-]*(?:$aliases)(?![a-z0-9])")
}

function Test-AiBatchToken
{
    <#
        .SYNOPSIS
        Returns true when a token meter name marks batch tokens.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    return [bool]($Name -match '\bbatch\b')
}

function Get-AiTokenContextType
{
    <#
        .SYNOPSIS
        Derives the context type of a token meter: Short Context, Long Context, a context
        descriptor, Ambiguous, or N/A.

        .DESCRIPTION
        Collects hints. No hints is N/A, one distinct hint is that value, more is Ambiguous.
        Descriptors keep their original casing; the same descriptor in another case counts once.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    $short = 'shortco|\bshco\b|short[\s_-]context'
    $long = 'longco|\blongctx\b|\bloco\b|long[\s_-]context'
    $hints = [System.Collections.Generic.List[string]]::new()

    if ($Name -match $short) { $hints.Add('Short Context') }
    if ($Name -match $long) { $hints.Add('Long Context') }

    $rest = [regex]::Replace([regex]::Replace("$Name", $short, ' ', 'IgnoreCase'), $long, ' ', 'IgnoreCase')
    foreach ($m in [regex]::Matches($rest, '\b(?:contextualisation|contextualization|contextual|context)\b', 'IgnoreCase'))
    {
        if (-not ($hints | Where-Object { $_ -eq $m.Value })) { $hints.Add($m.Value) }
    }

    $distinct = @($hints | Group-Object { $_.ToLowerInvariant() } | ForEach-Object { $_.Group[0] })
    if ($distinct.Count -eq 0) { return 'N/A' }
    if ($distinct.Count -eq 1) { return $distinct[0] }
    return 'Ambiguous'
}

function Get-AiTokenLocation
{
    <#
        .SYNOPSIS
        Derives the location of a token meter: Global, Regional, DataZone, Ambiguous, or N/A.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    $groups = @(
        @{ Value = 'Global'; Pattern = '(?<![a-z0-9])(?:global|glbl|glb|gl)(?![a-z0-9])' }
        @{ Value = 'Regional'; Pattern = '(?<![a-z0-9])(?:regional|regnl|regn|rg)(?![a-z0-9])|-rgnl(?![a-z0-9])' }
        @{ Value = 'DataZone'; Pattern = '(?<![a-z0-9])(?:datazone|data zone|dzone|dzn|dz)(?![a-z0-9])' }
    )
    $found = @($groups | Where-Object { $Name -match $_.Pattern } | ForEach-Object { $_.Value })
    if ($found.Count -eq 0) { return 'N/A' }
    if ($found.Count -eq 1) { return $found[0] }
    return 'Ambiguous'
}

function Get-AiModelVersion
{
    <#
        .SYNOPSIS
        Extracts the model version from a meter name, or N/A when none is present.

        .DESCRIPTION
        Blanks out dates, sizes, precision markers, and four-digit stamps, then returns the first
        decimal number. Without one, returns the first standalone integer, v-number, GPT or Grok
        number, Kimi K-number, or Deepseek R-number, whichever comes first in the name.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    if ([string]::IsNullOrEmpty($Name)) { return 'N/A' }

    $blank = @(
        '(?<![a-z0-9])(?:19|20)\d{2}[-/.](?:0?[1-9]|1[0-2])(?:[-/.](?:0?[1-9]|[12]\d|3[01]))?(?![a-z0-9])'
        '(?<![a-z0-9])\d{1,2}[-/.]\d{1,2}[-/.](?:19|20)\d{2}(?![a-z0-9])'
        '(?<![a-z0-9])(?:0?[1-9]|1[0-2])[-/](?:19|20)\d{2}(?![a-z0-9])'
        '(?<![a-z0-9.])\d+(?:\.\d+)?(?:kb|mb|gb|tb|bits?|[bkmte])(?![a-z0-9])'
        '(?<![a-z0-9])(?:fp|bf|u?int)\d+(?![a-z0-9])'
        '(?<![a-z0-9.])\d{4}(?![a-z0-9.])'
    )
    $rest = $Name
    foreach ($pattern in $blank)
    {
        $rest = [regex]::Replace($rest, $pattern, ' ', 'IgnoreCase')
    }

    $decimal = [regex]::Match($rest, '\d+\.\d+')
    if ($decimal.Success) { return $decimal.Value }

    $candidates = @(
        @{ Pattern = '(?<![a-z0-9.])(\d+)(?![a-z0-9.])'; Gpt = $false }
        @{ Pattern = '(?<![a-z0-9])v(\d+)(?![a-z0-9])'; Gpt = $false }
        @{ Pattern = '(?<![a-z0-9])(?:gpt|grok)[-\s]?(\d+)'; Gpt = $true }
    )
    if ($rest -match '(?<![a-z0-9])kimi(?![a-z0-9])') { $candidates += @{ Pattern = '(?<![a-z0-9])k(\d+)(?![a-z0-9])'; Gpt = $false } }
    if ($rest -match '(?<![a-z0-9])deepseek(?![a-z0-9])') { $candidates += @{ Pattern = '(?<![a-z0-9])r(\d+)(?![a-z0-9])'; Gpt = $false } }

    $best = $null
    foreach ($candidate in $candidates)
    {
        $match = [regex]::Match($rest, $candidate.Pattern, 'IgnoreCase')
        if ($match.Success -and ($null -eq $best -or $match.Index -lt $best.Match.Index))
        {
            $best = @{ Match = $match; Gpt = $candidate.Gpt }
        }
    }
    if ($null -eq $best) { return 'N/A' }

    $number = $best.Match.Groups[1].Value
    if ($best.Gpt -and $number -eq '35' -and $best.Match.Value -match '^gpt') { return '3.5' }
    return $number
}

function Get-AiModelCreator
{
    <#
        .SYNOPSIS
        Maps a meter subcategory to the model creator. The first matching rule wins.

        .PARAMETER Subcategory
        The meter subcategory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Subcategory
    )

    $rules = @(
        @{ Creator = 'Anthropic'; Pattern = 'claude|anthropic' }
        @{ Creator = 'Meta'; Pattern = '^(?:meta|llama|azure llama)' }
        @{ Creator = 'Mistral'; Pattern = '^(?:mistral|ministral|codestral|azure mistral)' }
        @{ Creator = 'OpenAi'; Pattern = 'openai' }
        @{ Creator = 'Microsoft'; Pattern = '^(?:mai|phi|azure phi)' }
        @{ Creator = 'SpaceX'; Pattern = 'grok' }
        @{ Creator = 'Moonshot'; Pattern = 'kimi' }
        @{ Creator = 'Microsoft'; Pattern = 'azure ai search|azure speech' }
        @{ Creator = 'Deepseek'; Pattern = 'deepseek' }
        @{ Creator = 'Cohere'; Pattern = 'cohere' }
    )
    foreach ($rule in $rules)
    {
        if ($Subcategory -match $rule.Pattern) { return $rule.Creator }
    }
    return 'Other'
}

function Get-AiMeterClassification
{
    <#
        .SYNOPSIS
        Classifies one AI meter into the 16 derived columns, or returns null when the meter is not an AI meter.

        .DESCRIPTION
        Composes the token, model, Copilot, commitment, consumption, and agent rules. Throws when a
        Copilot meter has the Anthropic provider, because the ruleset doesn't define that case.

        .PARAMETER Category
        The meter category.

        .PARAMETER Subcategory
        The meter subcategory.

        .PARAMETER Name
        The meter name.

        .PARAMETER ServiceFamily
        The service family of the meter.

        .PARAMETER MeterIdKind
        The meter ID kind from Get-AiMeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Category,
        [AllowEmptyString()][AllowNull()][string]$Subcategory,
        [AllowEmptyString()][AllowNull()][string]$Name,
        [AllowEmptyString()][AllowNull()][string]$ServiceFamily,
        [AllowEmptyString()][AllowNull()][string]$MeterIdKind
    )

    if (-not (Test-AiMeterIncluded $Category $Subcategory $Name $MeterIdKind)) { return $null }

    $literals = Get-AiMeterRuleLiteral
    $provider = Get-AiMeterProvider $Subcategory $Name $MeterIdKind
    $isToken = Test-AiTokenMeter $Name $MeterIdKind
    $isCopilot = Test-AiCopilotMeter $Category $Subcategory $Name

    $copilotProvider = 'N/A'
    if ($isCopilot)
    {
        if ($provider -eq 'Anthropic')
        {
            throw "Copilot meter has the Anthropic provider, which the ruleset doesn't define: category '$Category', subcategory '$Subcategory', meter name '$Name'."
        }
        $copilotProvider = $provider
    }

    $isCommitment = ($isCopilot -and $literals.CopilotCommitmentSubcategories -contains $Subcategory) -or
        ($literals.PrePurchasePlanSubcategories -contains $Subcategory)

    $copilotType = 'N/A'
    if ($isCopilot)
    {
        if ($Subcategory -eq $literals.DragonCopilotSubcategory) { $copilotType = 'Dragon' }
        elseif ($literals.GitHubPlanSubcategories -contains $Subcategory) { $copilotType = 'GitHub' }
        else
        {
            $copilotType = switch ($ServiceFamily)
            {
                'Microsoft 365 Copilot' { 'M365' }
                'Security' { 'Security' }
                'Developer Tools' { 'GitHub' }
                'Data' { 'Fabric' }
                default { 'other' }
            }
        }
    }

    # Agent subcategories have their own agent type; pre-purchase plans are generic.
    $isAgent = $true
    $agentKey = @($literals.AgentSubcategories.Keys | Where-Object { $_ -eq $Subcategory })
    if ($agentKey.Count -gt 0) { $agentType = $literals.AgentSubcategories[$agentKey[0]] }
    elseif ($literals.PrePurchasePlanSubcategories -contains $Subcategory) { $agentType = 'Generic' }
    elseif ($isCopilot) { $agentType = "Copilot - $copilotType" }
    else
    {
        $isAgent = $false
        $agentType = 'N/A'
    }

    $values = @{
        Provider           = $provider
        IsTokenMeter       = [bool]$isToken
        TokenType          = 'N/A'
        IsCachedToken      = $false
        IsBatchToken       = $false
        TokenContextType   = 'N/A'
        TokenLocation      = 'N/A'
        IsCopilotMeter     = [bool]$isCopilot
        CopilotProvider    = $copilotProvider
        IsCommitmentMeter  = [bool]$isCommitment
        IsConsumptionMeter = [bool]($MeterIdKind -eq 'ClaudeConsumptionUnits' -or $isCopilot)
        CopilotType        = $copilotType
        IsAgentMeter       = $isAgent
        AgentType          = $agentType
        ModelVersion       = 'N/A'
        ModelCreator       = 'N/A'
    }

    if ($isToken)
    {
        $values.TokenType = Get-AiTokenType $Name $MeterIdKind
        $values.IsCachedToken = [bool](Test-AiCachedToken $Name)
        $values.IsBatchToken = [bool](Test-AiBatchToken $Name)
        $values.TokenContextType = Get-AiTokenContextType $Name
        $values.TokenLocation = Get-AiTokenLocation $Name
        $values.ModelVersion = Get-AiModelVersion $Name
        $values.ModelCreator = Get-AiModelCreator $Subcategory
    }

    $classification = [ordered]@{}
    foreach ($column in (Get-AiMeterColumn).Classification) { $classification[$column] = $values[$column] }
    return $classification
}

function Get-AiMeterKey
{
    <#
        .SYNOPSIS
        Builds the case-insensitive key of a meter name tuple.

        .DESCRIPTION
        Lowercases the three parts with the invariant culture and joins them with the unit
        separator character (char 31). The parts are not trimmed.

        .PARAMETER Category
        The meter category.

        .PARAMETER Subcategory
        The meter subcategory.

        .PARAMETER Name
        The meter name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][AllowNull()][string]$Category,
        [AllowEmptyString()][AllowNull()][string]$Subcategory,
        [AllowEmptyString()][AllowNull()][string]$Name
    )

    return (@($Category, $Subcategory, $Name) | ForEach-Object { "$_".ToLowerInvariant() }) -join [char]31
}

function Read-AiMeterPricesheet
{
    <#
        .SYNOPSIS
        Reads a price sheet zip and returns the distinct AI meter name tuples.

        .DESCRIPTION
        Streams every .json entry of the zip line by line (JSON Lines) without extracting it
        or loading it into memory. A cheap text test skips lines that cannot be AI meters before
        any JSON is parsed; it only skips lines that Test-AiMeterIncluded would reject. Keeps one
        entry per case-insensitive tuple. Only the five tuple fields are stored.

        Throws when the zip has no .json entry, when a line it parses isn't valid JSON (the message
        names the entry and the line number, not the line's content), when no line has a meter name field, when two
        different tuples share a key, or when one key has more than one service family or meter
        ID kind.

        .PARAMETER Path
        Path to the price sheet zip.

        .OUTPUTS
        A hashtable keyed by Get-AiMeterKey. Each value has Category, Subcategory, Name,
        ServiceFamily, and MeterIdKind.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Every literal that can make Test-AiMeterIncluded return true, plus a backslash so that a
    # value written with JSON escapes is always parsed. Built from Get-AiMeterRuleLiteral, so the
    # pre-filter stays a superset of the inclusion rule.
    $literals = Get-AiMeterRuleLiteral
    $words = @(
        $literals.TokenNameKeyword
        $literals.CopilotNameKeyword
        $literals.ConsumptionUnitsMeterId
        $literals.GitHubCreditMeterName
    ) + @($literals.AgentSubcategories.Keys) + $literals.PrePurchasePlanSubcategories
    $candidate = [regex]::new(
        ((@($words | ForEach-Object { [regex]::Escape($_) }) + '\\') -join '|'),
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant -bor
        [System.Text.RegularExpressions.RegexOptions]::Compiled)

    $meters = @{}
    $conflicts = [System.Collections.Generic.List[string]]::new()
    $conflictKinds = [System.Collections.Generic.HashSet[string]]::new()
    $sawName = $false
    $sawJson = $false

    $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).ProviderPath)
    try
    {
        foreach ($entry in $archive.Entries)
        {
            if (-not $entry.Name.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $sawJson = $true

            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8)
            $lineNumber = 0
            try
            {
                while ($null -ne ($line = $reader.ReadLine()))
                {
                    $lineNumber++
                    if (-not $sawName -and $line.IndexOf('metername', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $sawName = $true }
                    if (-not $candidate.IsMatch($line)) { continue }

                    $fields = @{ metercategory = ''; metersubcategory = ''; metername = ''; meterid = ''; servicefamily = '' }
                    # The parser's own message can quote the line, which can hold prices, so name only
                    # the entry and the line number.
                    try { $document = [System.Text.Json.JsonDocument]::Parse($line) }
                    catch { throw "Line $lineNumber of zip entry '$($entry.FullName)' isn't valid JSON." }
                    try
                    {
                        foreach ($property in $document.RootElement.EnumerateObject())
                        {
                            $field = $property.Name.ToLowerInvariant()
                            if (-not $fields.ContainsKey($field)) { continue }
                            $kind = $property.Value.ValueKind
                            $fields[$field] = if ($kind -eq 'String') { $property.Value.GetString() }
                            elseif ($kind -eq 'Null' -or $kind -eq 'Undefined') { '' }
                            else { $property.Value.GetRawText() }
                            if ($field -eq 'metername') { $sawName = $true }
                        }
                    }
                    finally { $document.Dispose() }

                    $category = $fields.metercategory
                    $subcategory = $fields.metersubcategory
                    $name = $fields.metername
                    $idKind = Get-AiMeterIdKind $fields.meterid
                    if (-not (Test-AiMeterIncluded $category $subcategory $name $idKind)) { continue }

                    $key = Get-AiMeterKey $category $subcategory $name
                    $known = $meters[$key]
                    if ($null -eq $known)
                    {
                        $meters[$key] = [pscustomobject]@{
                            Category      = $category
                            Subcategory   = $subcategory
                            Name          = $name
                            ServiceFamily = $fields.servicefamily
                            MeterIdKind   = $idKind
                        }
                        continue
                    }

                    $problem = $null
                    if ($known.Category -cne $category -or $known.Subcategory -cne $subcategory -or $known.Name -cne $name)
                    {
                        $problem = 'differ only in letter case'
                    }
                    elseif ($known.ServiceFamily -cne $fields.servicefamily) { $problem = 'service families' }
                    elseif ($known.MeterIdKind -ne $idKind) { $problem = 'meter ID kinds' }
                    if ($problem)
                    {
                        $conflictKinds.Add($problem) | Out-Null
                        if ($conflicts.Count -lt 5)
                        {
                            $conflicts.Add("'$($known.Category)' / '$($known.Subcategory)' / '$($known.Name)' ($problem)")
                        }
                    }
                }
            }
            finally { $reader.Dispose() }
        }
    }
    finally { $archive.Dispose() }

    if (-not $sawJson) { throw "The zip has no .json entry, so '$Path' doesn't look like an MCA price sheet." }
    if (-not $sawName) { throw "No row has a meter name field, so '$Path' doesn't look like an MCA price sheet." }
    if ($conflicts.Count -gt 0)
    {
        $kinds = $conflictKinds -join '; '
        throw "The price sheet has conflicting AI meter tuples ($kinds). Up to five examples: $($conflicts -join '; ')."
    }

    return $meters
}

function Import-AiMeterInput
{
    <#
        .SYNOPSIS
        Reads the rule inputs of an existing AiMeters.csv.

        .DESCRIPTION
        Reads the five rule-input columns and ignores the classification columns, so the rules can
        derive them again. A missing file gives an empty hashtable. Throws when the file lacks any of
        the five rule-input columns, so that a file that isn't an AI meters file is never overwritten.

        .PARAMETER Path
        Path to the CSV file.

        .OUTPUTS
        A hashtable keyed by Get-AiMeterKey, in the same shape as Read-AiMeterPricesheet.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $meters = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $meters }

    # Parse the header line twice, as header and as data, to get the column names even when the
    # file has no data rows.
    $headerLine = Get-Content -LiteralPath $Path -TotalCount 1 -Encoding utf8
    $header = if ([string]::IsNullOrEmpty($headerLine)) { @() }
    else { @((ConvertFrom-Csv -InputObject @($headerLine, $headerLine)).PSObject.Properties.Name) }
    $missing = @((Get-AiMeterColumn).Input | Where-Object { $header -notcontains $_ })
    if ($missing.Count -gt 0)
    {
        throw "'$Path' isn't an AI meters file because it doesn't have the columns $($missing -join ', '). The file was left untouched."
    }

    foreach ($row in (Import-Csv -LiteralPath $Path -Encoding utf8))
    {
        $category = "$($row.x_SkuMeterCategory)"
        $subcategory = "$($row.x_SkuMeterSubcategory)"
        $name = "$($row.SkuMeter)"
        $meters[(Get-AiMeterKey $category $subcategory $name)] = [pscustomobject]@{
            Category      = $category
            Subcategory   = $subcategory
            Name          = $name
            ServiceFamily = "$($row.x_SkuServiceFamily)"
            MeterIdKind   = "$($row.MeterIdKind)"
        }
    }

    return $meters
}

function Merge-AiMeterInput
{
    <#
        .SYNOPSIS
        Merges the rule inputs of the existing file with those of the price sheet.

        .DESCRIPTION
        Returns the union by key. Where both have a key, the price sheet's entry wins. Neither
        argument is changed.

        .PARAMETER Existing
        Rule inputs read from the existing file.

        .PARAMETER Sheet
        Rule inputs read from the price sheet.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Existing,

        [Parameter(Mandatory)]
        [hashtable]$Sheet
    )

    $merged = @{}
    foreach ($key in $Existing.Keys) { $merged[$key] = $Existing[$key] }
    foreach ($key in $Sheet.Keys) { $merged[$key] = $Sheet[$key] }
    return $merged
}

function ConvertTo-AiMeterRow
{
    <#
        .SYNOPSIS
        Converts rule inputs to sorted output rows with the 22 CSV columns.

        .DESCRIPTION
        Classifies every input and drops those that are not AI meters. Marks one default row per
        lowercased category and meter name: the row whose subcategory equals the category, otherwise
        the first row by lowercased subcategory (ordinal). Sorts the rows by Get-AiMeterKey with an
        ordinal comparison. Booleans become the strings true and false.

        .PARAMETER Inputs
        Rule inputs keyed by Get-AiMeterKey.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Inputs
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Inputs.Values)
    {
        $classification = Get-AiMeterClassification $item.Category $item.Subcategory $item.Name $item.ServiceFamily $item.MeterIdKind
        if ($null -eq $classification) { continue }
        $entries.Add([pscustomobject]@{
                Item           = $item
                Classification = $classification
                SortKey        = Get-AiMeterKey $item.Category $item.Subcategory $item.Name
                PairKey        = (@($item.Category, $item.Name) | ForEach-Object { "$_".ToLowerInvariant() }) -join [char]31
            })
    }

    # Choose one default per (category, meter name) pair.
    $defaults = @{}
    foreach ($entry in $entries)
    {
        $subcategory = "$($entry.Item.Subcategory)".ToLowerInvariant()
        $isOwnCategory = $subcategory -ceq "$($entry.Item.Category)".ToLowerInvariant()
        $current = $defaults[$entry.PairKey]
        if ($null -ne $current -and ($current.IsOwnCategory -or (-not $isOwnCategory -and [string]::CompareOrdinal($subcategory, $current.Subcategory) -ge 0)))
        {
            continue
        }
        $defaults[$entry.PairKey] = [pscustomobject]@{ SortKey = $entry.SortKey; Subcategory = $subcategory; IsOwnCategory = $isOwnCategory }
    }

    $entries.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.SortKey, $b.SortKey) })

    $columns = (Get-AiMeterColumn).All
    $rows = [object[]]::new($entries.Count)
    for ($i = 0; $i -lt $entries.Count; $i++)
    {
        $entry = $entries[$i]
        $values = @{
            x_SkuMeterCategory    = [string]$entry.Item.Category
            x_SkuMeterSubcategory = [string]$entry.Item.Subcategory
            SkuMeter              = [string]$entry.Item.Name
            x_SkuServiceFamily    = [string]$entry.Item.ServiceFamily
            MeterIdKind           = [string]$entry.Item.MeterIdKind
            IsDefault             = $defaults[$entry.PairKey].SortKey -ceq $entry.SortKey
        }
        foreach ($column in $entry.Classification.Keys) { $values[$column] = $entry.Classification[$column] }

        $row = [ordered]@{}
        foreach ($column in $columns)
        {
            $value = $values[$column]
            $row[$column] = if ($value -is [bool]) { if ($value) { 'true' } else { 'false' } } else { $value }
        }
        $rows[$i] = [pscustomobject]$row
    }

    return $rows
}

function Get-AiMeterSummary
{
    <#
        .SYNOPSIS
        Counts what a run changes in AiMeters.csv.

        .DESCRIPTION
        Compares the rows of the existing file with the rows about to be written, by
        Get-AiMeterKey. A classification counts as changed when any of the 16 classification
        columns differs (case-sensitive) for a key in both.

        .PARAMETER OldRows
        The rows of the existing file, as Import-Csv returns them. Empty when there's no file.

        .PARAMETER NewRows
        The rows about to be written, as ConvertTo-AiMeterRow returns them.

        .PARAMETER SheetKeys
        The keys of the meters found in the price sheet.

        .OUTPUTS
        An object with Written, New (keys not in the existing file), Changed, Kept (keys not in
        the price sheet), Dropped (keys of the existing file that the inclusion rule no longer
        includes), and ValueCounts (for each classification column, the "value=count" entries
        sorted by value).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()][object[]]$OldRows = @(),
        [AllowEmptyCollection()][object[]]$NewRows = @(),
        [AllowEmptyCollection()][string[]]$SheetKeys = @()
    )

    $classificationColumns = (Get-AiMeterColumn).Classification
    $sheet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($SheetKeys), [System.StringComparer]::OrdinalIgnoreCase)

    $stored = @{}
    foreach ($old in $OldRows)
    {
        $stored[(Get-AiMeterKey $old.x_SkuMeterCategory $old.x_SkuMeterSubcategory $old.SkuMeter)] = ($classificationColumns | ForEach-Object { "$($old.$_)" }) -join [char]31
    }

    $written = @{}
    $new = 0
    $changed = 0
    $kept = 0
    foreach ($row in $NewRows)
    {
        $key = Get-AiMeterKey $row.x_SkuMeterCategory $row.x_SkuMeterSubcategory $row.SkuMeter
        $written[$key] = $true
        if (-not $stored.ContainsKey($key)) { $new++ }
        if (-not $sheet.Contains($key)) { $kept++ }
        if ($stored.ContainsKey($key) -and $stored[$key] -cne (($classificationColumns | ForEach-Object { "$($row.$_)" }) -join [char]31)) { $changed++ }
    }
    $dropped = @($stored.Keys | Where-Object { -not $written.ContainsKey($_) }).Count

    $valueCounts = [ordered]@{}
    foreach ($column in $classificationColumns)
    {
        $valueCounts[$column] = @($NewRows | Group-Object -Property $column -NoElement | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" })
    }

    return [pscustomobject]@{
        Written     = @($NewRows).Count
        New         = $new
        Changed     = $changed
        Kept        = $kept
        Dropped     = $dropped
        ValueCounts = $valueCounts
    }
}

$ErrorActionPreference = 'Stop'

$sheet = Read-AiMeterPricesheet $PricesheetPath
if ($sheet.Count -eq 0)
{
    throw "The price sheet has no AI meters, so '$OutputPath' was left untouched."
}
$existing = Import-AiMeterInput $OutputPath
$rows = @(ConvertTo-AiMeterRow (Merge-AiMeterInput $existing $sheet))

$oldRows = if (Test-Path -LiteralPath $OutputPath -PathType Leaf) { @(Import-Csv -LiteralPath $OutputPath -Encoding utf8) } else { @() }
$summary = Get-AiMeterSummary -OldRows $oldRows -NewRows $rows -SheetKeys @($sheet.Keys)

# Write with a fixed encoding (UTF-8 without BOM), newline (LF), and quoting, to a temporary file
# next to the target, then move it over the target.
$lines = if ($rows.Count -gt 0) { @($rows | ConvertTo-Csv -UseQuotes Always -NoTypeInformation) }
else { , (((Get-AiMeterColumn).All | ForEach-Object { '"' + $_ + '"' }) -join ',') }
$target = [System.IO.Path]::GetFullPath($OutputPath, (Get-Location).ProviderPath)
$temp = "$target.$([guid]::NewGuid().ToString('N')).tmp"
try
{
    [System.IO.File]::WriteAllText($temp, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $target -Force
}
finally
{
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}

Write-Host "Rows written: $($summary.Written)"
Write-Host "Rows new: $($summary.New)"
Write-Host "Rows whose classification changed: $($summary.Changed)"
Write-Host "Rows kept that aren't in the price sheet: $($summary.Kept)"
Write-Host "Rows dropped (no longer included): $($summary.Dropped)"
foreach ($column in $summary.ValueCounts.Keys)
{
    Write-Host "${column}: $($summary.ValueCounts[$column] -join ', ')"
}
