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
