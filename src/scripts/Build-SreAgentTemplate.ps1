# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds the SRE Agent recipe package used by the portal deployment template.

    .PARAMETER DestDir
    Release directory for the copied sre-agent template.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DestDir
)

$templateRoot = Resolve-Path "$PSScriptRoot/../templates/sre-agent"
$recipeDir = Join-Path $templateRoot "recipes/finops-hub"
$builder = Join-Path $templateRoot "bin/build-extras.py"
$assetsDir = Join-Path $DestDir "assets"
$workDir = Join-Path $assetsDir "sre-agent-recipe"
$extrasPath = Join-Path $workDir "extras.json"
$packagePath = Join-Path $assetsDir "sre-agent-recipe.zip"
$placeholderKustoUri = "https://placeholder.eastus2.kusto.windows.net/Hub"

if (-not (Get-Command python3 -ErrorAction SilentlyContinue))
{
    throw "python3 is required to build the SRE Agent recipe package."
}

& "$PSScriptRoot/New-Directory.ps1" $assetsDir
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
& "$PSScriptRoot/New-Directory.ps1" $workDir

Write-Host "    Building SRE Agent recipe package..."
$summary = python3 $builder --recipe $recipeDir --output $extrasPath --kusto-connector-uri $placeholderKustoUri
if (-not $?)
{
    throw "Failed to build SRE Agent extras manifest."
}

Write-Verbose "    SRE Agent extras summary: $summary"
Remove-Item $packagePath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$workDir/*" -DestinationPath $packagePath -Force
Remove-Item $workDir -Recurse -Force

Write-Host "    Created assets/sre-agent-recipe.zip"
