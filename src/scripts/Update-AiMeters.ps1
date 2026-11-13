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
