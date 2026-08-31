# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Generates Bicep loadTextContent entries for ingestion query files.

    .DESCRIPTION
    Scans query JSON files in the Recommendations and Quota apps and generates the
    corresponding Bicep variable blocks in each app.bicep. Each query file specifies
    an opt-in group via an optional "group" field. Files without a group are added to
    the core set.

    This script runs as a post-copy build step, modifying the release copy of app.bicep
    rather than the source files. The source app.bicep contains placeholder markers that
    are replaced with the generated content during the build.

    .PARAMETER DestDir
    Required. Path to the finops-hub template destination (release) directory.

    .EXAMPLE
    ./Build-HubIngestionQueries.ps1 -DestDir ./release/finops-hub

    Regenerates the loadTextContent entries in the release copies of the Recommendations
    and Quota app.bicep files.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DestDir
)

function Update-HubIngestionQueriesApp
{
    param(
        [Parameter(Mandatory)][string]$AppName,
        [Parameter(Mandatory)][hashtable]$GroupConfig,
        [Parameter(Mandatory)][string[]]$GroupOrder
    )

$queriesPath = Join-Path $DestDir "modules/Microsoft.FinOpsHubs/$AppName/queries"
$appBicepPath = Join-Path $DestDir "modules/Microsoft.FinOpsHubs/$AppName/app.bicep"

if (-not (Test-Path $queriesPath))
{
    Write-Verbose "No queries directory found at $queriesPath; skipping"
    return
}

if (-not (Test-Path $appBicepPath))
{
    Write-Warning "$AppName app.bicep not found at $appBicepPath; skipping"
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

# Build the generated block
$startMarker = '// <generated-query-files>'
$endMarker = '// </generated-query-files>'

$generatedLines = @($startMarker)
$varNames = @()

foreach ($groupName in $GroupOrder)
{
    if (-not $groups.ContainsKey($groupName)) { continue }

    $config = $GroupConfig[$groupName]
    $varNames += $config.VarName

    if ($generatedLines.Count -gt 1) { $generatedLines += '' }

    switch ("$AppName/$groupName")
    {
        'Recommendations/core' { $generatedLines += '// Load query files -- core recommendations are always included' }
        'Recommendations/ahb' { $generatedLines += '// Optional: Azure Hybrid Benefit recommendations (may generate noise without on-premises licenses)' }
        'Recommendations/spot' { $generatedLines += '// Optional: Spot VM recommendations (may generate noise for non-interruptible workloads)' }
        'Quota/core' { $generatedLines += '// Load query files -- quota queries are always included' }
    }

    $generatedLines += Format-BicepVar $config.VarName $groups[$groupName] $config.Conditional
}

foreach ($groupName in ($groups.Keys | Sort-Object))
{
    if ($GroupConfig.ContainsKey($groupName)) { continue }
    throw "Unknown query group '$groupName' in $AppName. Expected groups: $($GroupOrder -join ', ')"
}

# Add the union line
$generatedLines += ''
$generatedLines += if ($varNames.Count -eq 1) {
    "var queryFiles = $($varNames[0])"
}
else {
    "var queryFiles = union($($varNames -join ', '))"
}
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
}

Update-HubIngestionQueriesApp `
    -AppName 'Recommendations' `
    -GroupConfig @{
        'core' = @{ VarName = 'coreQueryFiles'; Conditional = $null }
        'ahb'  = @{ VarName = 'ahbQueryFiles'; Conditional = 'enableAHBRecommendations ?' }
        'spot' = @{ VarName = 'spotQueryFiles'; Conditional = 'enableSpotRecommendations ?' }
    } `
    -GroupOrder @('core', 'ahb', 'spot')

Update-HubIngestionQueriesApp `
    -AppName 'Quota' `
    -GroupConfig @{
        'core' = @{ VarName = 'coreQueryFiles'; Conditional = $null }
    } `
    -GroupOrder @('core')
