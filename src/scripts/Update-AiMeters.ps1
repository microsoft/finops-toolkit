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
    if ($MeterId -eq 'claude-consumption-units') { return 'ClaudeConsumptionUnits' }
    return 'Other'
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

    if ($Name -match 'tokens' -or $Name -match 'copilot') { return $true }
    if ($MeterIdKind -eq 'ClaudeConsumptionUnits') { return $true }
    if ($Category -eq 'GitHub' -and $Name -eq 'AI Credit GAC') { return $true }

    $subcategories = @(
        'Azure Agent Unit'
        'Azure Monitor Observability Agent'
        'Microsoft 365 Agent'
        'Microsoft Agent Pre-Purchase Plan'
        'GitHub Pre-Purchase Plan'
        'GitHub AI Credits Pre-Purchase Plan'
    )
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

    $outputHint = '(?<![a-z0-9])(?:cd)?(?:outpt|output|ouput|outp|out|opt)(?![a-z0-9])'
    $inputHint = '(?<![a-z0-9])(?:cd)?(?:input|inpt|inp|gi|in)(?![a-z0-9])'

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
    $aliases = 'outpt|output|ouput|outp|out|opt|input|inpt|inp|gi|in|reasoning|embedding|embed|write|wr'
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

    $provider = Get-AiMeterProvider $Subcategory $Name $MeterIdKind
    $isToken = ($Name -match 'tokens') -or $MeterIdKind -eq 'ClaudeConsumptionUnits'

    $githubPlans = @('GitHub Pre-Purchase Plan', 'GitHub AI Credits Pre-Purchase Plan')
    $isCopilot = ($Name -match 'copilot') -or
        ($Category -eq 'GitHub' -and $Name -eq 'AI Credit GAC') -or
        ($githubPlans -contains $Subcategory)

    $copilotProvider = 'N/A'
    if ($isCopilot)
    {
        if ($provider -eq 'Anthropic')
        {
            throw "Copilot meter has the Anthropic provider, which the ruleset doesn't define: category '$Category', subcategory '$Subcategory', meter name '$Name'."
        }
        $copilotProvider = $provider
    }

    $commitmentPlans = @('Microsoft Agent Pre-Purchase Plan') + $githubPlans
    $isCommitment = ($isCopilot -and @('Copilot Credit Reservation', 'Copilot Credit Pre-Purchase Plan') -contains $Subcategory) -or
        ($commitmentPlans -contains $Subcategory)

    $copilotType = 'N/A'
    if ($isCopilot)
    {
        if ($Subcategory -eq 'Microsoft Dragon Copilot') { $copilotType = 'Dragon' }
        elseif ($githubPlans -contains $Subcategory) { $copilotType = 'GitHub' }
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

    $isAgent = $true
    switch ($Subcategory)
    {
        'Azure Agent Unit' { $agentType = 'Azure SRE Agent' }
        'Azure Monitor Observability Agent' { $agentType = 'Azure Monitor Observability Agent' }
        'Microsoft 365 Agent' { $agentType = 'Agent 365' }
        'Microsoft Agent Pre-Purchase Plan' { $agentType = 'Generic' }
        'GitHub Pre-Purchase Plan' { $agentType = 'Generic' }
        'GitHub AI Credits Pre-Purchase Plan' { $agentType = 'Generic' }
        default
        {
            if ($isCopilot) { $agentType = "Copilot - $copilotType" }
            else
            {
                $isAgent = $false
                $agentType = 'N/A'
            }
        }
    }

    $classification = [ordered]@{
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
        $classification.TokenType = Get-AiTokenType $Name $MeterIdKind
        $classification.IsCachedToken = [bool](Test-AiCachedToken $Name)
        $classification.IsBatchToken = [bool](Test-AiBatchToken $Name)
        $classification.TokenContextType = Get-AiTokenContextType $Name
        $classification.TokenLocation = Get-AiTokenLocation $Name
        $classification.ModelVersion = Get-AiModelVersion $Name
        $classification.ModelCreator = Get-AiModelCreator $Subcategory
    }

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

        Throws when the zip has no .json entry, when no line has a meter name field, when two
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

    # Every literal that makes Test-AiMeterIncluded return true, plus a backslash so that a
    # value written with JSON escapes is always parsed.
    $candidate = [regex]::new(
        'tokens|copilot|claude-consumption-units|AI Credit GAC|Azure Agent Unit|Azure Monitor Observability Agent|Microsoft 365 Agent|Microsoft Agent Pre-Purchase Plan|GitHub Pre-Purchase Plan|GitHub AI Credits Pre-Purchase Plan|\\',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled)

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
            try
            {
                while ($null -ne ($line = $reader.ReadLine()))
                {
                    if (-not $sawName -and $line.IndexOf('metername', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $sawName = $true }
                    if (-not $candidate.IsMatch($line)) { continue }

                    $fields = @{ metercategory = ''; metersubcategory = ''; metername = ''; meterid = ''; servicefamily = '' }
                    $document = [System.Text.Json.JsonDocument]::Parse($line)
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
