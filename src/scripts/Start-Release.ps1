# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Starts or continues the release process.

    .DESCRIPTION
    The Start-Release command determines the current release state and performs the next steps that can be automated.
    Steps include: ensuring a release tracking issue exists, updating the Bicep CLI, and querying milestone data.

    .PARAMETER DaysUntilRelease
    Optional. Number of days until the expected release date. Used to determine the release month when running
    near the end of a month. Default = 7.

    .EXAMPLE
    ./Start-Release

    Detects the version from package.json, checks for an existing release issue, and creates one if needed.
    Uses the date 7 days from now to determine the release month.

    .EXAMPLE
    ./Start-Release -DaysUntilRelease 14

    Uses the date 14 days from now to determine the release month.
#>
param(
    [int]
    $DaysUntilRelease = 7
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

# Get version from package.json
$version = & (Join-Path $PSScriptRoot 'Get-Version.ps1')
$versionTag = & (Join-Path $PSScriptRoot 'Get-Version.ps1') -AsTag

# Determine release month/year based on expected release date
$releaseDate = (Get-Date).AddDays($DaysUntilRelease)
$Month = $releaseDate.ToString('MMMM')
$Year = $releaseDate.Year

Write-Host "Release: $versionTag ($Month $Year)" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Ensure release issue exists ---

# Read the issue template
$templatePath = Join-Path $repoRoot '.github/ISSUE_TEMPLATE/-internal-only--release-checklist.md'
if (-not (Test-Path $templatePath))
{
    Write-Error "Issue template not found at $templatePath"
    return
}

$templateContent = Get-Content $templatePath -Raw

# Parse YAML frontmatter
$frontmatterMatch = [regex]::Match($templateContent, '(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)')
if (-not $frontmatterMatch.Success)
{
    Write-Error "Failed to parse YAML frontmatter from issue template"
    return
}

$frontmatter = $frontmatterMatch.Groups[1].Value
$body = $frontmatterMatch.Groups[2].Value

# Extract title pattern from frontmatter
$titleMatch = [regex]::Match($frontmatter, 'title:\s*"(.+)"')
if (-not $titleMatch.Success)
{
    Write-Error "Failed to extract title from issue template frontmatter"
    return
}
$titlePattern = $titleMatch.Groups[1].Value

# Extract labels from frontmatter
$labelsMatch = [regex]::Match($frontmatter, 'labels:\s*"(.+)"')
$labels = if ($labelsMatch.Success) { $labelsMatch.Groups[1].Value } else { '' }

# Fill in placeholders
$title = $titlePattern `
    -replace 'Mmmm', $Month `
    -replace 'yyyy', $Year `
    -replace '#\.#', $version `
    -replace '\\U0001F4CB', ([char]::ConvertFromUtf32(0x1F4CB))

$title = $title -replace '\\U([0-9A-Fa-f]{8})', { [char]::ConvertFromUtf32([Convert]::ToInt32($_.Groups[1].Value, 16)) }

# Check for existing release issue
Write-Host "Checking for existing release issue..." -ForegroundColor Gray
$existingIssues = gh issue list --state open --label "Type: Release 🚀" --search "$versionTag release checklist" --json number,title,url 2>&1
if ($LASTEXITCODE -ne 0)
{
    Write-Error "Failed to search for existing issues: $existingIssues"
    return
}

$matchingIssues = $existingIssues | ConvertFrom-Json
if ($matchingIssues.Count -gt 0)
{
    $releaseIssue = $matchingIssues[0]
    Write-Host "Found existing release issue: #$($releaseIssue.number) - $($releaseIssue.title)" -ForegroundColor Green
    Write-Host "  $($releaseIssue.url)" -ForegroundColor Gray
}
else
{
    # Create the issue
    Write-Host "Creating release issue..." -ForegroundColor Gray
    Write-Host "  Title: $title" -ForegroundColor Gray

    # Write body to a temp file to avoid shell escaping issues
    $tempFile = [System.IO.Path]::GetTempFileName()
    try
    {
        Set-Content -Path $tempFile -Value $body -NoNewline
        $result = gh issue create --title $title --label $labels --body-file $tempFile 2>&1
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Failed to create issue: $result"
            return
        }

        # gh issue create returns the URL
        $issueUrl = $result.Trim()
        $issueNumber = [regex]::Match($issueUrl, '/issues/(\d+)').Groups[1].Value

        Write-Host "Created release issue: #$issueNumber" -ForegroundColor Green
        Write-Host "  $issueUrl" -ForegroundColor Gray
    }
    finally
    {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

# --- Step 2: Update Bicep CLI ---

Write-Host ""
Write-Host "Updating Bicep CLI..." -ForegroundColor Cyan
$bicepResult = az bicep upgrade 2>&1
if ($LASTEXITCODE -ne 0)
{
    Write-Warning "Bicep CLI update failed: $bicepResult"
}
else
{
    Write-Host "Bicep CLI updated." -ForegroundColor Green
}

# --- Step 3: Query milestone issues and PRs ---

Write-Host ""
Write-Host "Querying milestone data..." -ForegroundColor Cyan

# Find the milestone matching this version tag
$milestones = gh api 'repos/{owner}/{repo}/milestones?state=open' 2>&1 | ConvertFrom-Json
$milestone = $milestones | Where-Object { $_.title -eq $versionTag -or $_.title -eq $version }

if (-not $milestone)
{
    Write-Warning "No open milestone found matching '$versionTag' or '$version'. Skipping milestone query."
}
else
{
    $milestoneNumber = $milestone.number
    Write-Host "Found milestone: $($milestone.title) (#$milestoneNumber) — $($milestone.open_issues) open issue(s)" -ForegroundColor Green

    # Query all open issues and PRs in this milestone
    $milestoneItems = gh api "repos/{owner}/{repo}/issues?milestone=$milestoneNumber&state=open&per_page=100" 2>&1 | ConvertFrom-Json

    $milestoneIssues = @()
    $milestonePRs = @()
    foreach ($item in $milestoneItems)
    {
        # Extract a short summary from the body for triage context
        $summary = ''
        if ($item.body)
        {
            # Strip HTML comments, then grab first non-empty, non-header, non-checkbox line
            $cleanBody = $item.body -replace '(?s)<!--.*?-->', ''
            $lines = $cleanBody -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object {
                $_ -ne '' -and
                $_ -notmatch '^#{1,3}\s' -and
                $_ -notmatch '^[-*]\s*\[' -and
                $_ -notmatch '^\*\*Changes' -and
                $_ -notmatch '^[⚠️|>|---]'
            }
            if ($lines.Count -gt 0)
            {
                $summary = ($lines | Select-Object -First 2) -join ' '
                if ($summary.Length -gt 200) { $summary = $summary.Substring(0, 200) + '...' }
            }
        }

        $entry = @{
            Number    = $item.number
            Title     = $item.title
            Summary   = $summary
            Labels    = @($item.labels | ForEach-Object { $_.name })
            Assignees = @($item.assignees | ForEach-Object { $_.login })
            Url       = $item.html_url
        }

        if ($item.pull_request)
        {
            $milestonePRs += $entry
        }
        else
        {
            $milestoneIssues += $entry
        }
    }

    Write-Host "  Issues: $($milestoneIssues.Count)  PRs: $($milestonePRs.Count)" -ForegroundColor Gray
}

# --- Return result object ---

return @{
    Version      = $version
    VersionTag   = $versionTag
    Month        = $Month
    Year         = $Year
    ReleaseIssue = if ($releaseIssue) { @{ Number = $releaseIssue.number; Title = $releaseIssue.title; Url = $releaseIssue.url } } else { $null }
    Milestone    = if ($milestone) {
        @{
            Number     = $milestoneNumber
            Title      = $milestone.title
            OpenIssues = $milestone.open_issues
            Issues     = $milestoneIssues
            PRs        = $milestonePRs
        }
    } else { $null }
}
