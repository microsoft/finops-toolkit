# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Packages the three Power BI release files and reports what's left to do.

    .DESCRIPTION
    Power BI releases ship three files: PowerBI-kql.zip and PowerBI-storage.zip hold the PBIT
    templates, and PowerBI-demo.zip holds the demo PBIX files.

    Everything except saving the PBIX files is automated. Power BI Desktop has to load and save
    those, so this command is resumable: run it, save the projects it opens, then run it again.
    It works out which steps are already done, does the next one, and validates the result, so a
    missed step fails here instead of shipping.

    .PARAMETER Open
    Optional. Opens the Power BI projects that still need to be saved as PBIX files. Default = false.

    .PARAMETER Build
    Optional. Rebuilds the PBIT templates and PBIP projects even if they already exist. Default = false.

    .PARAMETER Status
    Optional. Reports what's done and what's left without changing anything. Default = false.

    .EXAMPLE
    ./Package-PowerBI

    Builds whatever is missing and reports the next step.

    .EXAMPLE
    ./Package-PowerBI -Open

    Opens the Power BI projects that still need to be saved as PBIX files.

    .EXAMPLE
    ./Package-PowerBI -Status

    Reports what's done and what's left.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-package-powerbi
#>
param(
    [switch] $Open,

    [switch] $Build,

    [switch] $Status
)

$ErrorActionPreference = 'Stop'

$relDir = "$PSScriptRoot/../../release"
$pbitDir = "$relDir/pbit"
$pbixDir = "$relDir/pbix"
$manifestPath = "$pbixDir/.manifest.json"

$version = & "$PSScriptRoot/Get-Version.ps1"

Add-Type -AssemblyName System.IO.Compression.FileSystem

#region Helpers

function Format-Size([long] $Bytes)
{
    if ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N0} KB" -f ($Bytes / 1KB)
}

<#
    .SYNOPSIS
    Reads a single entry from a ZIP-based file (PBIX, PBIT) without extracting it.
#>
function Get-ArchiveEntry([string] $Path, [string] $EntryName)
{
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try
    {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq $EntryName } | Select-Object -First 1
        if (-not $entry) { return $null }

        $stream = $entry.Open()
        try
        {
            $buffer = New-Object System.IO.MemoryStream
            $stream.CopyTo($buffer)
            return $buffer.ToArray()
        }
        finally { $stream.Dispose() }
    }
    finally { $archive.Dispose() }
}

function Get-ArchiveEntryName([string] $Path)
{
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try { return @($archive.Entries | ForEach-Object { $_.FullName }) }
    finally { $archive.Dispose() }
}

function Get-ArchiveEntrySize([string] $Path, [string] $EntryName)
{
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try
    {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq $EntryName } | Select-Object -First 1
        if (-not $entry) { return -1 }
        return $entry.Length
    }
    finally { $archive.Dispose() }
}

<#
    .SYNOPSIS
    Parses a JSON part from a PBIX file, which Power BI writes as UTF-16LE.
#>
function ConvertFrom-PbixJson([byte[]] $Bytes)
{
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE)
    {
        $text = [System.Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    elseif ($Bytes.Length -ge 2 -and $Bytes[1] -eq 0)
    {
        $text = [System.Text.Encoding]::Unicode.GetString($Bytes)
    }
    else
    {
        $text = [System.Text.Encoding]::UTF8.GetString($Bytes)
        $text = $text.TrimStart([char]0xFEFF)
    }

    return $text | ConvertFrom-Json -Depth 100
}

<#
    .SYNOPSIS
    Checks a saved demo PBIX for the mistakes that are easy to make when saving by hand.

    .DESCRIPTION
    Catches a report saved without data, saved from the wrong (unpruned) project, saved on the
    wrong page, or saved from a stale build with the previous version number.
#>
function Test-DemoPbix([string] $Path, $Report)
{
    $issues = New-Object System.Collections.Generic.List[string]

    try { $entries = Get-ArchiveEntryName $Path }
    catch
    {
        $issues.Add("isn't a readable PBIX file ($($_.Exception.Message)). Save it again from Power BI Desktop.")
        return $issues
    }

    foreach ($required in @('DataModel', 'Report/Layout', 'Metadata', 'Settings', 'Version'))
    {
        if ($entries -notcontains $required) { $issues.Add("is missing the $required part. Save it again from Power BI Desktop.") }
    }
    if ($issues.Count -gt 0) { return $issues }

    # A PBIX saved without loading data has a tiny data model
    $dataModelSize = Get-ArchiveEntrySize $Path 'DataModel'
    if ($dataModelSize -lt 1MB)
    {
        $issues.Add("has a $(Format-Size $dataModelSize) data model, so it was saved without loading demo data. Refresh the report before saving.")
    }

    $layout = $null
    try { $layout = ConvertFrom-PbixJson (Get-ArchiveEntry $Path 'Report/Layout') }
    catch { $issues.Add("has a Report/Layout part that couldn't be read ($($_.Exception.Message)).") }

    if ($layout)
    {
        # Version placeholders are replaced at build time, so finding one means the PBIX was
        # saved from the source project instead of the generated project in release/pbix
        $sections = @($layout.sections)
        $displayOrder = @($sections | Sort-Object @{ Expression = { if ($null -eq $_.ordinal) { 0 } else { $_.ordinal } } })
        $expected = [array]::FindIndex($displayOrder, [Predicate[object]] { param($section) $section.displayName -eq 'Get started' })

        $config = $layout.config | ConvertFrom-Json -Depth 100
        if ($expected -ge 0 -and $config.activeSectionIndex -ne $expected)
        {
            $active = if ($config.activeSectionIndex -lt $displayOrder.Count) { $displayOrder[$config.activeSectionIndex].displayName } else { "page $($config.activeSectionIndex)" }
            $issues.Add("opens on '$active'. Switch to the Get started page and save again.")
        }

        $layoutText = ($layout | ConvertTo-Json -Depth 100 -Compress)
        if ($layoutText -match '\$\$ftkver\$\$|\$\$build-date\$\$')
        {
            $issues.Add("still has version placeholders, so it was saved from src/power-bi instead of release/pbix. Open the project from release/pbix and save again.")
        }
        elseif ($layoutText -notmatch [regex]::Escape($version))
        {
            $issues.Add("doesn't mention version $version, so it was saved from an older build. Rebuild and save again.")
        }
    }

    # A report saved from the shared project carries every table, not just the ones it needs
    if ($entries -contains 'DiagramLayout')
    {
        try
        {
            $diagram = ConvertFrom-PbixJson (Get-ArchiveEntry $Path 'DiagramLayout')
            $tables = @($diagram.diagrams.nodes | ForEach-Object { $_.nodeIndex } | Where-Object { $_ })
            $extra = @($tables | Where-Object { $Report.tables -notcontains $_ } | Sort-Object -Unique)
            if ($extra.Count -gt 0)
            {
                $issues.Add("includes $($extra.Count) table$(if ($extra.Count -ne 1) { 's' }) the report doesn't use ($($extra -join ', ')). Open the project from release/pbix and save again.")
            }
        }
        catch { Write-Verbose "Could not read DiagramLayout from $Path" }
    }

    return $issues
}

#endregion Helpers

#region State

if ($Build -and -not $Status)
{
    Write-Host 'Building Power BI templates and projects...'
    & "$PSScriptRoot/Build-PowerBI.ps1"
    Write-Host ''
}

$hasManifest = Test-Path $manifestPath
$manifest = if ($hasManifest) { Get-Content $manifestPath -Raw | ConvertFrom-Json } else { $null }
$isStale = $hasManifest -and $manifest.version -ne $version

if ((-not $hasManifest -or $isStale) -and -not $Status -and -not $Build)
{
    if ($isStale) { Write-Host "Templates were built for $($manifest.version) but the current version is $version. Rebuilding..." }
    else { Write-Host 'No Power BI build found. Building...' }
    & "$PSScriptRoot/Build-PowerBI.ps1"
    Write-Host ''
    $hasManifest = Test-Path $manifestPath
    $manifest = if ($hasManifest) { Get-Content $manifestPath -Raw | ConvertFrom-Json } else { $null }
    $isStale = $false
}

if (-not $hasManifest)
{
    Write-Host '⏳ Power BI templates have not been built.'
    Write-Host '     Run: ' -NoNewline
    Write-Host './Package-PowerBI -Build' -ForegroundColor Cyan
    return
}

# Only storage reports ship as demo PBIX files
$demoReports = @($manifest.reports | Where-Object { $_.type -eq 'storage' })
$templateZips = @("$relDir/PowerBI-kql.zip", "$relDir/PowerBI-storage.zip")
$demoZip = "$relDir/PowerBI-demo.zip"

$saved = @()
$missing = @()
foreach ($report in $demoReports)
{
    if (Test-Path "$pbixDir/$($report.pbix)") { $saved += $report } else { $missing += $report }
}

#endregion State

#region Report status

Write-Host "Power BI release files for $version" -ForegroundColor White
Write-Host ''

$builtTemplates = @(Get-ChildItem "$pbitDir/*.pbit" -ErrorAction SilentlyContinue)
$zipsBuilt = @($templateZips | Where-Object { Test-Path $_ })
Write-Host "  $(if ($builtTemplates.Count -eq $manifest.reports.Count -and $zipsBuilt.Count -eq 2) { '✅' } else { '⏳' }) Templates    $($builtTemplates.Count)/$($manifest.reports.Count) PBIT, $($zipsBuilt.Count)/2 ZIP"
Write-Host "  $(if ($missing.Count -eq 0) { '✅' } else { '⏳' }) Demo reports $($saved.Count)/$($demoReports.Count) PBIX saved"
Write-Host "  $(if (Test-Path $demoZip) { '✅' } else { '⏳' }) Demo package $(if (Test-Path $demoZip) { Format-Size (Get-Item $demoZip).Length } else { 'PowerBI-demo.zip not created' })"
Write-Host ''

if ($Status) { return }

#endregion Report status

#region Save PBIX files

if ($missing.Count -gt 0)
{
    Write-Host "⏳ $($missing.Count) Power BI project$(if ($missing.Count -ne 1) { 's' }) still $(if ($missing.Count -eq 1) { 'needs' } else { 'need' }) to be saved as PBIX:"
    $missing | ForEach-Object { Write-Host "     $($_.pbip) → $($_.pbix)" }
    Write-Host ''

    if (-not $Open)
    {
        Write-Host '     To open them, run: ' -NoNewline
        Write-Host './Package-PowerBI -Open' -ForegroundColor Cyan
        return
    }

    Write-Host 'For each project that opens:'
    Write-Host '  1. Refresh the report so demo data is loaded.'
    Write-Host '  2. Select File > Save as, keep the release/pbix folder, and change the file type to PBIX.'
    Write-Host '  3. Set the sensitivity to "Public" when prompted.'
    Write-Host '  4. Switch to the Get started page and save again.'
    Write-Host ''
    Write-Host 'Queries are already trimmed to what each report needs, so there is nothing to remove by hand.'
    Write-Host ''

    if ($IsWindows -or $null -eq $IsWindows)
    {
        $missing | ForEach-Object { Invoke-Item "$pbixDir/$($_.pbip)" }
        Write-Host "Opened $($missing.Count) project$(if ($missing.Count -ne 1) { 's' }) in Power BI Desktop."
    }
    else
    {
        Write-Warning 'Power BI Desktop only runs on Windows. Open these projects there:'
        $missing | ForEach-Object { Write-Host "     $((Resolve-Path "$pbixDir/$($_.pbip)").Path)" }
    }

    Write-Host ''
    Write-Host '     When they are all saved, run: ' -NoNewline
    Write-Host './Package-PowerBI' -ForegroundColor Cyan
    return
}

#endregion Save PBIX files

#region Validate and package

Write-Host "Checking $($saved.Count) demo report$(if ($saved.Count -ne 1) { 's' })..."
$failed = 0
foreach ($report in $saved)
{
    $path = "$pbixDir/$($report.pbix)"
    $issues = Test-DemoPbix $path $report
    if ($issues.Count -eq 0)
    {
        Write-Host "  ✅ $($report.pbix)  $(Format-Size (Get-Item $path).Length)"
    }
    else
    {
        $failed++
        Write-Host "  ❌ $($report.pbix)" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "       $_" -ForegroundColor Red }
    }
}

if ($failed -gt 0)
{
    Write-Host ''
    throw "$failed demo report$(if ($failed -ne 1) { 's' }) failed validation. Fix the issues above, save again, and rerun this command."
}

Write-Host ''
Write-Host 'Packaging PowerBI-demo.zip...'

# PBIX files are already compressed, so the fastest level takes far less time for the same size
Remove-Item $demoZip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$pbixDir/*.storage.pbix" -DestinationPath $demoZip -CompressionLevel Fastest

Write-Host ''
Write-Host "✅ Power BI release files for $version" -ForegroundColor Green
@($templateZips + $demoZip) `
| Where-Object { Test-Path $_ } `
| ForEach-Object { Write-Host "     $(Split-Path $_ -Leaf)  $(Format-Size (Get-Item $_).Length)" }

#endregion Validate and package
