# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Copies the FinOps hub Grafana dashboards into the finops-workbooks release output.

    .DESCRIPTION
    The dashboards are maintained in src/workbooks/grafana alongside the example
    dashboards they were built from. Only the ftk-*.json dashboards are deployed,
    so the examples in that folder are intentionally not copied.

    .PARAMETER DestDir
    Required. Path to the release folder for the finops-workbooks template.
#>
Param (
  [Parameter(Mandatory = $true)][string] $DestDir
)

$srcDir = "$PSScriptRoot/../workbooks/grafana"
$outDir = Join-Path $DestDir 'modules/dashboards'

& "$PSScriptRoot/New-Directory" $outDir

$dashboards = Get-ChildItem $srcDir -Filter 'ftk-*.json' -File
if ($dashboards.Count -eq 0)
{
  throw "No ftk-*.json dashboards found in $srcDir"
}

$dashboards | ForEach-Object {
  Write-Verbose "    Copying dashboard: $($_.Name)"
  Copy-Item $_.FullName $outDir -Force
}

Write-Verbose "    Copied $($dashboards.Count) dashboard(s) to $outDir"
