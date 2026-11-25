# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Prepares a release and opens a pull request from a release prep branch into main.

    .DESCRIPTION
    The New-ReleasePr command automates every release checklist step that needs no human and no external repo:

    1. Preflight: confirms the release is not already tagged and that dev and main share history.
    2. Creates (or updates) the release prep branch from origin/dev and merges origin/main into it.
    3. Runs Start-Release (release issue, milestones, version bump, changelog section, Bicep CLI).
    4. Builds the toolkit, runs unit, lint, and toolkit integration tests, and packages release files.
    5. Commits the changes, pushes the prep branch, and opens a PR into main with a manual checklist.

    The command only merges. It never rebases, resets, force-pushes, or merges the PR. A human merges the PR using a
    merge commit so history is kept. The prep branch is the only branch that is pushed. Neither dev nor main is
    ever pushed to, so this works with protected branches (unlike Merge-DevBranch, which pushes directly).

    Re-running the command with the same version merges the latest dev into the existing prep branch, pushes, and
    updates the open PR.

    .PARAMETER Base
    Optional. Branch to open the PR against. Default = "main".

    .PARAMETER Source
    Optional. Branch to release from. Default = "dev".

    .PARAMETER DryRun
    Optional. Runs all steps locally but does not push, create issues or milestones, open a PR, or comment. The PR body
    is written to the output folder. Default = false.

    .PARAMETER Ready
    Optional. Opens the PR as ready for review instead of as a draft. Default = false (draft).

    .PARAMETER RefreshEligibility
    Optional. Refreshes commitment discount eligibility data (about 45 minutes). By default, this is skipped because
    the Update Commitment Discount Eligibility workflow refreshes the data weekly. Default = false.

    .PARAMETER OnConflict
    Optional. How to handle conflicts when merging main into the prep branch. "keep-dev" retries the merge keeping the
    dev side of conflicting hunks and lists the affected files in the PR. "fail" stops. Default = "keep-dev".

    .PARAMETER DaysUntilRelease
    Optional. Number of days until the expected release date. Passed to Start-Release. Default = 7.

    .PARAMETER SkipBuild
    Optional. Skips build and packaging. For local testing only. Default = false.

    .PARAMETER SkipTests
    Optional. Skips tests. For local testing only. Default = false.

    .PARAMETER OutputDir
    Optional. Folder for the PR body, summary, and logs. Must be outside the repo. Default = $env:RUNNER_TEMP or the system temp folder.

    .PARAMETER RunUrl
    Optional. URL of the workflow run to link from the PR. Default = built from GitHub Actions environment variables.

    .EXAMPLE
    ./New-ReleasePr -DryRun -SkipBuild -SkipTests

    Runs preflight, branch, merge, and version steps locally without building, testing, pushing, or opening a PR.

    .EXAMPLE
    ./New-ReleasePr

    Prepares the release, pushes the prep branch, and opens a draft PR into main.
#>
[CmdletBinding()]
param(
    [string]
    $Base = 'main',

    [string]
    $Source = 'dev',

    [switch]
    $DryRun,

    [switch]
    $Ready,

    [switch]
    $RefreshEligibility,

    [ValidateSet('keep-dev', 'fail')]
    [string]
    $OnConflict = 'keep-dev',

    [int]
    $DaysUntilRelease = 7,

    [switch]
    $SkipBuild,

    [switch]
    $SkipTests,

    [string]
    $OutputDir,

    [string]
    $RunUrl
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scripts = $PSScriptRoot
$steps = [System.Collections.Generic.List[object]]::new()

if (-not $OutputDir)
{
    $OutputDir = Join-Path ($env:RUNNER_TEMP ?? [System.IO.Path]::GetTempPath()) 'ftk-release-pr'
}
$null = New-Item -ItemType Directory -Path $OutputDir -Force
$OutputDir = (Resolve-Path $OutputDir).Path
if ($OutputDir.StartsWith($repoRoot))
{
    throw "OutputDir must be outside the repo: $OutputDir"
}

if (-not $RunUrl -and $env:GITHUB_SERVER_URL -and $env:GITHUB_RUN_ID)
{
    $RunUrl = "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID)"
}

# ---------------------------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------------------------

function Invoke-Git
{
    # Runs git and throws on failure. Returns output lines.
    $out = & git @args 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        throw "git $($args -join ' ') failed ($LASTEXITCODE): $($out -join [Environment]::NewLine)"
    }
    return $out
}

function Invoke-Step
{
    # Runs a step, records status and duration, and rethrows on failure.
    param([string]$Name, [scriptblock]$Script)

    Write-Host "::group::$Name"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try
    {
        & $Script
        $steps.Add([pscustomobject]@{ Name = $Name; Status = 'passed'; Seconds = [int]$sw.Elapsed.TotalSeconds })
    }
    catch
    {
        $steps.Add([pscustomobject]@{ Name = $Name; Status = 'failed'; Seconds = [int]$sw.Elapsed.TotalSeconds })
        Write-Host "::endgroup::"
        Write-Host "::error::$Name failed: $($_.Exception.Message)"
        Write-StepSummary
        throw
    }
    Write-Host "::endgroup::"
}

function Write-StepSummary
{
    if (-not $env:GITHUB_STEP_SUMMARY) { return }
    $lines = @('### Release PR steps', '', '| Step | Status | Time |', '| --- | --- | --- |')
    foreach ($s in $steps)
    {
        $icon = if ($s.Status -eq 'passed') { '✅' } else { '❌' }
        $lines += "| $($s.Name) | $icon $($s.Status) | $($s.Seconds)s |"
    }
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ($lines -join [Environment]::NewLine)
}

function Invoke-Tests
{
    param([string]$Name, [hashtable]$Parameters)

    $global:ftk_TestPowerShell_Results = $null
    & (Join-Path $scripts 'Test-PowerShell.ps1') @Parameters
    $result = $global:ftk_TestPowerShell_Results
    if ($null -eq $result)
    {
        throw "$Name found no tests to run."
    }
    if ($result.Result -ne 'Passed')
    {
        throw "$Name did not pass ($($result.FailedCount) failed tests, $($result.FailedContainersCount) failed containers)."
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------------------------------------------------

Set-Location $repoRoot
$state = @{
    Branch    = $null
    Version   = $null
    Tag       = $null
    Existing  = $false
    Conflicts = @()
    Release   = $null
    PrUrl     = $null
    PrNumber  = $null
    Pushed    = $false
}

Invoke-Step 'Preflight' {
    if (Invoke-Git status --porcelain)
    {
        throw 'Working tree is not clean. Commit or stash changes first.'
    }

    Invoke-Git fetch origin --tags --prune --quiet | Out-Null
    Invoke-Git rev-parse --verify --quiet "origin/$Source" | Out-Null
    Invoke-Git rev-parse --verify --quiet "origin/$Base" | Out-Null

    $mergeBase = & git merge-base "origin/$Source" "origin/$Base" 2>$null
    if (-not $mergeBase)
    {
        throw "origin/$Source and origin/$Base share no history. Restore $Base before releasing."
    }

    # Read the version from the tip of source without touching any branch
    Invoke-Git checkout --detach --quiet "origin/$Source" | Out-Null
    $ver = (& (Join-Path $scripts 'Get-Version.ps1'))
    $state.Tag = & (Join-Path $scripts 'Get-Version.ps1') -AsTag
    $state.Branch = "bot/release-$($state.Tag)"
    Write-Host "Source version: $ver -> release $($state.Tag)"

    if (& git tag --list $state.Tag)
    {
        throw "Release $($state.Tag) is already tagged. $Source still has version $ver. Run /update-version to start the next release first."
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. Prep branch and merge of main
# ---------------------------------------------------------------------------------------------------------------------

Invoke-Step "Prep branch ($($state.Branch))" {
    if (-not (& git config user.email)) { Invoke-Git config user.email 'github-actions[bot]@users.noreply.github.com' | Out-Null }
    if (-not (& git config user.name)) { Invoke-Git config user.name 'github-actions[bot]' | Out-Null }

    $state.Existing = [bool](& git ls-remote --heads origin $state.Branch)
    if ($state.Existing)
    {
        Write-Host "Prep branch exists. Merging origin/$Source into it."
        if (& git branch --list $state.Branch)
        {
            Invoke-Git checkout --quiet $state.Branch | Out-Null
            Invoke-Git merge --no-edit "origin/$($state.Branch)" | Out-Null
        }
        else
        {
            Invoke-Git checkout --quiet -b $state.Branch "origin/$($state.Branch)" | Out-Null
        }
        Invoke-Git merge --no-edit "origin/$Source" | Out-Null
    }
    else
    {
        Invoke-Git checkout --quiet -b $state.Branch "origin/$Source" | Out-Null
    }

    # Merge main into the prep branch so the PR is conflict-free and history is kept.
    $mergeMessage = "chore: Merge $Base into $($state.Branch)"
    & git merge --no-ff --no-edit -m $mergeMessage "origin/$Base" 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0)
    {
        $state.Conflicts = @(& git diff --name-only --diff-filter=U)
        Invoke-Git merge --abort | Out-Null
        Write-Host "Conflicts merging ${Base}: $($state.Conflicts -join ', ')"
        if ($OnConflict -eq 'fail')
        {
            throw "Conflicts merging $Base into $($state.Branch): $($state.Conflicts -join ', ')"
        }
        & git merge --no-ff --no-edit -X ours -m $mergeMessage "origin/$Base" 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0)
        {
            $unresolved = @(& git diff --name-only --diff-filter=U)
            Invoke-Git merge --abort | Out-Null
            throw "Conflicts could not be resolved automatically (kept $Source): $($unresolved -join ', ')"
        }
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# 3. Start release (issue, milestones, version, changelog, Bicep CLI)
# ---------------------------------------------------------------------------------------------------------------------

Invoke-Step 'Start release (version, changelog, milestones)' {
    $json = Join-Path $OutputDir 'start-release.json'
    Remove-Item $json -ErrorAction SilentlyContinue
    $startArgs = @{
        DaysUntilRelease = $DaysUntilRelease
        OutputFile       = $json
        SkipEligibility  = (-not $RefreshEligibility)
        DryRun           = [bool]$DryRun
    }
    $null = & (Join-Path $scripts 'Start-Release.ps1') @startArgs
    $state.Release = Get-Content $json -Raw | ConvertFrom-Json
    $state.Version = & (Join-Path $scripts 'Get-Version.ps1')

    # The ms.date update workflow does not run for PRs opened with the default token, so update dates here
    # for docs-mslearn files changed by the version bump (body changes only).
    $today = (Get-Date).ToString('MM/dd/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    @(& git diff --name-only -- 'docs-mslearn/*.md') | ForEach-Object {
        $path = Join-Path $repoRoot $_
        $text = Get-Content $path -Raw
        $updated = $text -replace '(?m)^ms\.date:.*$', "ms.date: $today"
        if ($updated -ne $text)
        {
            [System.IO.File]::WriteAllText($path, $updated)
            Write-Host "Updated ms.date: $_"
        }
    }

    $changelog = Get-Content (Join-Path $repoRoot 'docs-mslearn/toolkit/changelog.md') -Raw
    if ($changelog -notmatch "(?m)^## $([regex]::Escape($state.Tag))\s*$")
    {
        throw "Changelog has no '## $($state.Tag)' section."
    }

    Invoke-Git add -A | Out-Null
    if (& git status --porcelain)
    {
        Invoke-Git commit --quiet -m "chore: Prepare $($state.Tag) release" -m 'Bump version, update changelog section, and update release data.' | Out-Null
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# 4. Build, test, package
# ---------------------------------------------------------------------------------------------------------------------

if (-not $SkipBuild)
{
    Invoke-Step 'Build toolkit' {
        & (Join-Path $scripts 'Build-Toolkit.ps1')
    }
}

if (-not $SkipTests)
{
    Invoke-Step 'Unit and lint tests' {
        Invoke-Tests 'Unit and lint tests' @{ Unit = $true; Lint = $true }
    }
    Invoke-Step 'Toolkit integration tests' {
        # Other integration tests deploy to Azure and run in the PR deployment workflow instead.
        Invoke-Tests 'Toolkit integration tests' @{ Integration = $true; Toolkit = $true }
    }
}

if (-not $SkipBuild)
{
    Invoke-Step 'Package release files (except Power BI)' {
        & (Join-Path $scripts 'Package-Toolkit.ps1') -Build -CopyFiles
        $relDir = Join-Path $repoRoot 'release'
        $zips = @(Get-ChildItem $relDir -Filter *.zip -ErrorAction SilentlyContinue)
        if ($zips.Count -eq 0)
        {
            throw 'Packaging produced no ZIP files.'
        }
        Write-Host "Packaged $($zips.Count) ZIP files."
        Invoke-Git add -A | Out-Null
        if (& git status --porcelain)
        {
            Invoke-Git commit --quiet -m "chore: Update $($state.Tag) deployment files" -m 'Generated by Package-Toolkit.' | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. PR body
# ---------------------------------------------------------------------------------------------------------------------

$release = $state.Release
$milestoneIssues = @($release.Milestone.Issues)
$milestonePrs = @($release.Milestone.PRs)
$needsReview = @($release.NeedsReview)
$issueLink = if ($release.ReleaseIssue) { "[$($release.ReleaseIssue.Number)]($($release.ReleaseIssue.Url))" } else { '_none yet_' }
$sourceSha = (& git rev-parse --short "origin/$Source")
$baseSha = (& git rev-parse --short "origin/$Base")
$tag = $state.Tag

function Format-Items($items, $max = 10)
{
    if (-not $items -or $items.Count -eq 0) { return '    - _none_' }
    $lines = @($items | Select-Object -First $max | ForEach-Object { "    - [$($_.Number)]($($_.Url)) $($_.Title)" })
    if ($items.Count -gt $max) { $lines += "    - _...and $($items.Count - $max) more_" }
    return $lines -join "`n"
}

$stepRows = ($steps | ForEach-Object { "| $($_.Name) | $(if ($_.Status -eq 'passed') { '✅' } else { '❌' }) | $($_.Seconds)s |" }) -join "`n"
$conflictNote = if ($state.Conflicts.Count -gt 0)
{
    "`n> ⚠️ Merging ``$Base`` conflicted. The ``$Source`` side was kept for: " + (($state.Conflicts | ForEach-Object { "``$_``" }) -join ', ') + ". Review these files in the diff.`n"
}
else { '' }
$runLine = if ($RunUrl) { "[workflow run]($RunUrl)" } else { 'local run' }
$milestoneLine = if ($release.Milestone) { "$($release.Milestone.Title) ($($release.Milestone.OpenIssues) open)" } else { '_not found_' }

$body = @"
🤖 [Release bot] Automated release prep for **$tag** from ``$Source`` ($sourceSha) into ``$Base`` ($baseSha). Created by the $runLine. Tracking issue: $issueLink. Milestone: $milestoneLine.

> [!IMPORTANT]
> Merge this PR with **Create a merge commit**. Never squash or rebase, or ``$Base`` loses ``$Source`` history. If ``$Source`` changes before you merge, re-run the **Release PR** workflow. It merges ``$Source`` into this branch and updates this PR.
$conflictNote
## Automated (done)

| Step | Status | Time |
| --- | --- | --- |
$stepRows

Covers: version bump, changelog section, ms.date, open data and deployment files, build, unit and lint tests, toolkit integration tests, and packaging (except Power BI). Packaged files are in the **release-files** artifact on the workflow run. Hub, export, and workbook integration tests run in the PR deployment workflow, not here.

## Manual: before merge

- [ ] Review the [changelog](https://github.com/microsoft/finops-toolkit/blob/$($state.Branch)/docs-mslearn/toolkit/changelog.md) against the coding guidelines. Move any unreleased entries into the $tag section.
- [ ] Update what's new blurbs in ``/docs/`` marketing pages.
- [ ] Review FinOps hubs docs: upgrade guide, data model, data processing, compatibility.
- [ ] If adding a new tool: marketing page and landing page, MS Learn overview page and TOC, Advisory council doc.
- [ ] Triage open milestone items (keep, push, or skip):
  - Issues ($($milestoneIssues.Count)):
$(Format-Items $milestoneIssues)
  - PRs ($($milestonePrs.Count)):
$(Format-Items $milestonePrs)
- [ ] Triage untriaged issues ($($needsReview.Count) with the review label).
- [ ] Merge ready PRs and feature branches into ``$Source``, then re-run this workflow.
- [ ] Package Power BI files (needs Power BI Desktop): ``Package-Toolkit.ps1 -OpenPBI``, save PBIX files, then ``Package-Toolkit.ps1 -ZipPBI``.
- [ ] Check the docs for broken links (fork with GitHub Pages).
- [ ] Publish the PowerShell module: run the **Publish PowerShell** workflow.
- [ ] Submit a PR to the Microsoft Docs repo: ``Publish-Toolkit.ps1 "docs" -Commit``.
- [ ] Submit PRs to the Bicep Registry: ``Publish-Toolkit.ps1 "scheduledactions" -Commit``.
- [ ] Submit PRs to Azure Quickstart Templates: ``finops-hub``, ``governance-workbook``, ``optimization-workbook``.
- [ ] Check AQT PR checks after 1 hour. Fix issues in this repo and re-publish.
- [ ] Check AQT PRs merged after 2-3 days.

## Manual: merge

- [ ] Mark this PR ready for review (it is a draft by default).
- [ ] Approve and **Create a merge commit**.

## Manual: after merge

- [ ] Verify the [documentation site](https://aka.ms/finops/toolkit) updated.
- [ ] Update the milestone: move open items, close it.
- [ ] Tag and publish the [GitHub release](https://github.com/microsoft/finops-toolkit/releases/new): tag ``$tag``, target ``$Base``, upload files from the **release-files** artifact plus Power BI PBIX and PBIT files. Do not upload Bicep, PowerShell, PBIP, or image files.
- [ ] Update the related discussion and set released issues to ``Status: Released``.
- [ ] Announcements: FinOps blog, LinkedIn, X, Engage, F2 Slack.
- [ ] Run ``/update-version`` to start the next dev cycle on ``$Source``.

🤖 Generated by ``src/scripts/New-ReleasePr.ps1``. See the [release process](https://github.com/microsoft/finops-toolkit/blob/dev/docs-wiki/Release-process.md).
"@

$bodyFile = Join-Path $OutputDir 'pr-body.md'
[System.IO.File]::WriteAllText($bodyFile, $body)
if ($env:GITHUB_STEP_SUMMARY)
{
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $body
}

# ---------------------------------------------------------------------------------------------------------------------
# 6. Push and open PR
# ---------------------------------------------------------------------------------------------------------------------

if ($DryRun)
{
    Write-Host ''
    Write-Host "Dry run: skipping push and PR. Branch $($state.Branch) is local only." -ForegroundColor Yellow
    Write-Host "PR body: $bodyFile"
}
else
{
    Invoke-Step "Push $($state.Branch) and open PR" {
        Invoke-Git push --set-upstream origin $state.Branch | Out-Null
        $state.Pushed = $true

        $title = "chore: Release $tag to $Base"
        $existingPr = @(gh pr list --head $state.Branch --base $Base --state open --json number,url | ConvertFrom-Json)
        if ($existingPr.Count -gt 0)
        {
            $state.PrUrl = $existingPr[0].url
            $state.PrNumber = $existingPr[0].number
            gh pr edit $state.PrNumber --title $title --body-file $bodyFile | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Failed to update PR $($state.PrNumber)." }
            Write-Host "Updated PR: $($state.PrUrl)"
            return
        }

        $prArgs = @('pr', 'create', '--base', $Base, '--head', $state.Branch, '--title', $title, '--body-file', $bodyFile)
        if (-not $Ready) { $prArgs += '--draft' }
        if ($release.Milestone) { $prArgs += @('--milestone', $release.Milestone.Title) }
        $out = & gh @prArgs --label 'Type: Release 🚀' 2>&1
        if ($LASTEXITCODE -ne 0 -and ($out -join ' ') -match 'label|milestone')
        {
            # Retry without optional metadata that may not exist
            $prArgs = $prArgs | Where-Object { $_ -ne '--milestone' -and $_ -ne $release.Milestone.Title }
            $out = & gh @prArgs 2>&1
        }
        if ($LASTEXITCODE -ne 0)
        {
            $compare = "$($env:GITHUB_SERVER_URL ?? 'https://github.com')/$($env:GITHUB_REPOSITORY ?? 'microsoft/finops-toolkit')/compare/$Base...$($state.Branch)?expand=1"
            if ($env:GITHUB_STEP_SUMMARY)
            {
                Add-Content $env:GITHUB_STEP_SUMMARY "### ⚠️ PR not created`n`nBranch ``$($state.Branch)`` was pushed. [Create pull request →]($compare)`n`n``````n$($out -join "`n")`n``````"
            }
            throw "Branch pushed, but the PR could not be created: $($out -join ' '). Open it manually: $compare"
        }
        $state.PrUrl = ($out | Select-Object -Last 1).ToString().Trim()
        $state.PrNumber = [int]([regex]::Match($state.PrUrl, '/pull/(\d+)').Groups[1].Value)
        Write-Host "Opened PR: $($state.PrUrl)"

        if ($release.ReleaseIssue)
        {
            gh issue comment $release.ReleaseIssue.Number --body "🤖 [Release bot] Release PR for $tag is ready for manual steps: $($state.PrUrl)" | Out-Null
        }
    }
}

Write-StepSummary

$summary = [ordered]@{
    Version  = $state.Version
    Tag      = $tag
    Branch   = $state.Branch
    DryRun   = [bool]$DryRun
    Pushed   = $state.Pushed
    PrUrl    = $state.PrUrl
    PrNumber = $state.PrNumber
    Conflicts = $state.Conflicts
    Steps    = $steps
}
$summary | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputDir 'summary.json')
if ($env:GITHUB_OUTPUT)
{
    Add-Content $env:GITHUB_OUTPUT "tag=$tag"
    Add-Content $env:GITHUB_OUTPUT "branch=$($state.Branch)"
    Add-Content $env:GITHUB_OUTPUT "pr_url=$($state.PrUrl)"
}

return [pscustomobject]$summary
