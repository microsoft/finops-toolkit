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

function Remove-PluginBundle([string]$Path)
{
    if (-not (Test-Path -LiteralPath $Path))
    {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
    {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
    else
    {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

if (-not (Test-Path $skillsDir))
{
    return
}

$finopsSkill = Join-Path $skillsDir 'finops-toolkit'
if (Test-Path $finopsSkill)
{
    $queryDest = Join-Path $finopsSkill 'references/queries'
    Remove-PluginBundle $queryDest
    Copy-Item (Join-Path $repoRoot 'src/queries') -Destination $queryDest -Recurse -Force

    $docsDest = Join-Path $finopsSkill 'references/docs-mslearn'
    Remove-PluginBundle $docsDest
    $docsSource = Join-Path $repoRoot 'docs-mslearn'
    Get-ChildItem $docsSource -File -Recurse -Filter '*.md' | ForEach-Object {
        $relativePath = $_.FullName.Substring($docsSource.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $destination = Join-Path $docsDest $relativePath
        New-Item (Split-Path $destination) -ItemType Directory -Force | Out-Null
        Copy-Item $_ -Destination $destination -Force
    }
}

Get-ChildItem $DestDir -Force -Recurse -Filter '.DS_Store' | Remove-Item -Force
