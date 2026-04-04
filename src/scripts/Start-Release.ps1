# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Starts or continues the release process.

    .DESCRIPTION
    The Start-Release command determines the current release state and performs the next steps that can be automated.
    Currently, it ensures a release tracking issue exists on GitHub.

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

$issues = $existingIssues | ConvertFrom-Json
if ($issues.Count -gt 0)
{
    $issue = $issues[0]
    Write-Host "Found existing release issue: #$($issue.number) - $($issue.title)" -ForegroundColor Green
    Write-Host "  $($issue.url)" -ForegroundColor Gray
    return @{
        Action = 'existing'
        Number = $issue.number
        Title  = $issue.title
        Url    = $issue.url
    }
}

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
    return @{
        Action = 'created'
        Number = [int]$issueNumber
        Title  = $title
        Url    = $issueUrl
    }
}
finally
{
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
