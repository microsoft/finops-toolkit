# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Generates Bicep loadTextContent entries for ingestion query files.

    .DESCRIPTION
    Scans query JSON files in the Recommendations app and generates the corresponding
    Bicep variable blocks in app.bicep. Each query file specifies an opt-in group via
    an optional "group" field. Files without a group are added to the core set.

    This script runs as a post-copy build step, modifying the release copy of app.bicep
    rather than the source files. The source app.bicep contains placeholder markers that
    are replaced with the generated content during the build.

    .PARAMETER DestDir
    Required. Path to the finops-hub template destination (release) directory.

    .EXAMPLE
    ./Build-HubIngestionQueries.ps1 -DestDir ./release/finops-hub

    Regenerates the loadTextContent entries in the release copy of Recommendations/app.bicep.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DestDir
)

$queriesPath = Join-Path $DestDir 'modules/Microsoft.FinOpsHubs/Recommendations/queries'
$appBicepPath = Join-Path $DestDir 'modules/Microsoft.FinOpsHubs/Recommendations/app.bicep'

if (-not (Test-Path $queriesPath))
{
    Write-Verbose "No queries directory found at $queriesPath; skipping"
    return
}

if (-not (Test-Path $appBicepPath))
{
    Write-Warning "Recommendations app.bicep not found at $appBicepPath; skipping"
    return
}

# Read all query files and group them
$queryFiles = Get-ChildItem -Path $queriesPath -Filter '*.json' | Sort-Object Name
$groups = @{}

foreach ($file in $queryFiles)
{
    $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $group = if ($json.PSObject.Properties['group'] -and $json.group) { $json.group } else { 'core' }
    if (-not $groups.ContainsKey($group))
    {
        $groups[$group] = @()
    }
    $groups[$group] += $file
}

Write-Verbose "Found $($queryFiles.Count) query file(s) in $($groups.Count) group(s)"

# Generate the Bicep variable block for each group
function Format-BicepVar($varName, $files, $conditional)
{
    $lines = @()
    if ($conditional)
    {
        $lines += "var $varName = $conditional {"
    }
    else
    {
        $lines += "var $varName = {"
    }
    foreach ($file in $files)
    {
        $key = $file.BaseName
        $lines += "  '$key': loadTextContent('queries/$($file.Name)')"
    }
    if ($conditional)
    {
        $lines += '} : {}'
    }
    else
    {
        $lines += '}'
    }
    return $lines -join "`n"
}

# Known group-to-variable mappings with their conditional expressions
$groupConfig = @{
    'core'    = @{ VarName = 'coreQueryFiles'; Conditional = $null }
    'ahb'     = @{ VarName = 'ahbQueryFiles'; Conditional = 'enableAHBRecommendations ?' }
    'spot'    = @{ VarName = 'spotQueryFiles'; Conditional = 'enableSpotRecommendations ?' }
}

# Build the generated block
$startMarker = '// <generated-query-files>'
$endMarker = '// </generated-query-files>'

$generatedLines = @($startMarker)
$varNames = @()

foreach ($groupName in @('core', 'ahb', 'spot'))
{
    if (-not $groups.ContainsKey($groupName)) { continue }

    $config = $groupConfig[$groupName]
    $varNames += $config.VarName

    if ($generatedLines.Count -gt 1) { $generatedLines += '' }

    # Add comment for non-core groups
    switch ($groupName)
    {
        'core' { $generatedLines += '// Load query files -- core recommendations are always included' }
        'ahb' { $generatedLines += '// Optional: Azure Hybrid Benefit recommendations (may generate noise without on-premises licenses)' }
        'spot' { $generatedLines += '// Optional: Spot VM recommendations (may generate noise for non-interruptible workloads)' }
    }

    $generatedLines += Format-BicepVar $config.VarName $groups[$groupName] $config.Conditional
}

# Handle any unknown groups
foreach ($groupName in ($groups.Keys | Sort-Object))
{
    if ($groupConfig.ContainsKey($groupName)) { continue }

    Write-Warning "Unknown query group '$groupName' found; adding as opt-in variable"
    $varName = "${groupName}QueryFiles"
    $paramName = "enable$($groupName.Substring(0,1).ToUpper())$($groupName.Substring(1))Recommendations"
    $varNames += $varName

    $generatedLines += ''
    $generatedLines += "// Optional: $groupName recommendations"
    $generatedLines += Format-BicepVar $varName $groups[$groupName] "$paramName ?"
}

# Add the union line
$generatedLines += ''
$generatedLines += "var queryFiles = union($($varNames -join ', '))"
$generatedLines += $endMarker

$generatedBlock = $generatedLines -join "`n"

# Read existing app.bicep and replace the generated section
$bicepContent = Get-Content -Path $appBicepPath -Raw

# Match from start marker through end marker
$pattern = "(?ms)$([regex]::Escape($startMarker)).*?$([regex]::Escape($endMarker))"
if ($bicepContent -match $pattern)
{
    $newContent = $bicepContent -replace $pattern, $generatedBlock
    if ($newContent -ne $bicepContent)
    {
        $newContent | Out-File -FilePath $appBicepPath -Encoding utf8 -NoNewline
        Write-Host "    Updated $($queryFiles.Count) query entries in app.bicep"
    }
    else
    {
        Write-Verbose "    app.bicep is already up to date"
    }
}
else
{
    Write-Warning "Could not find generated section markers in app.bicep; manual update required"
    Write-Warning "Expected markers: $startMarker ... $endMarker"
}
