# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]
    $DestDir
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$skillsDir = Join-Path $DestDir 'skills'

if (-not (Test-Path $skillsDir))
{
    return
}

$finopsSkill = Join-Path $skillsDir 'finops-toolkit'
if (Test-Path $finopsSkill)
{
    $queryDest = Join-Path $finopsSkill 'references/queries'
    Remove-Item $queryDest -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $repoRoot 'src/queries') -Destination $queryDest -Recurse -Force

    $docsDest = Join-Path $finopsSkill 'references/docs-mslearn'
    Remove-Item $docsDest -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $repoRoot 'docs-mslearn') -Destination $docsDest -Recurse -Force
}

Get-ChildItem $DestDir -Force -Recurse -Filter '.DS_Store' | Remove-Item -Force
