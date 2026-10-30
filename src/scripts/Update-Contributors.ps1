# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#Requires -Version 7.0

<#
    .SYNOPSIS
    Finds contributors who are missing from the all-contributors list and adds them.

    .DESCRIPTION
    Collects recent contributions from GitHub with the gh CLI, compares them with .all-contributorsrc, prints
    what is missing, and (with -Apply) adds the missing credits with the repo's own all-contributors-cli.

    Only contribution types that can be inferred from GitHub data are handled. Everything else (question,
    design, security, mentoring, promotion, leader) is left to humans. See "Recognizing contributors" in
    CONTRIBUTING.md.

    | Type   | Inferred from                                                                                   |
    | ------ | ----------------------------------------------------------------------------------------------- |
    | code   | Author of a merged PR that changed any file outside the documentation paths                     |
    | doc    | Author of a merged PR that changed a file in docs/, docs-mslearn/, docs-wiki/, or any *.md file |
    | review | Human who submitted a review (approved, requested changes, or commented) on a merged PR        |
    | bug    | Author of an issue labeled "Type: Bug" that was fixed or accepted (see below)                   |
    | ideas  | Author of an issue labeled "Type: Feature" that was implemented or accepted (see below)         |

    An issue is fixed or accepted when it was closed as completed or is assigned to a milestone. Issues closed as
    not planned or duplicate, and issues labeled Resolution: Duplicate, Won't fix, Can't repro, No activity,
    External, or Support request, are not credited.

    Changelog entries and .all-contributorsrc itself do not count toward code or doc, because nearly every code PR
    touches the changelog.

    Bots and apps are skipped (names ending in [bot], starting with app/, and a short list of known bot
    accounts). Nobody else is skipped: maintainers who are missing a type are credited too. Logins are compared
    case-insensitively.

    The default is a dry run that only prints what is missing. With -Apply, the script runs the all-contributors
    CLI once per login and then puts the arrays in .all-contributorsrc back on multiple lines. The CLI
    runs the file through prettier, which collapses short arrays onto one line and would turn a 20-line change
    into a ~500-line diff. The script verifies that the result only adds entries and restores the original files if
    it does not. Running the script twice changes nothing the second time.

    Prerequisites: PowerShell 7, an authenticated gh CLI (gh auth login, or GH_TOKEN), and for -Apply, Node.js and
    "npm ci --ignore-scripts" run once at the repo root.

    .PARAMETER Since
    Optional. Credit contributions since this date: PRs merged on or after it, and issues created or closed on or
    after it. At least one of -Since or -Milestone is required. If both are specified, both must match.

    .PARAMETER Milestone
    Optional. Credit contributions in this milestone (for example, v15).

    .PARAMETER PullRequest
    Optional. Credit only this pull request: its author (code, doc) and its reviewers (review), whether or not it is
    merged. Issues are not checked. Use alone; it replaces -Since and -Milestone. The workflow uses this to credit
    a pull request's author on the pull request itself.

    .PARAMETER Repository
    Optional. Repository to read from, as owner/name. Default = microsoft/finops-toolkit.

    .PARAMETER ConfigPath
    Optional. Path to the all-contributors config file. The CLI runs in this file's folder, so the files it lists
    (README.md, docs/README.md) are resolved from there. Default = .all-contributorsrc at the repo root.

    .PARAMETER Exclude
    Optional. Logins to never credit (for example, someone who asked to be removed from the list).

    .PARAMETER Apply
    Optional. Updates the config and the README files. Without this switch, the script only prints what is missing.
    Combine with -WhatIf to see what would run.

    .PARAMETER SummaryPath
    Optional. Writes a markdown summary of what was missing (or added) to this file. The workflow uses it as the
    PR description.

    .PARAMETER PassThru
    Optional. Returns the missing credits as objects.

    .EXAMPLE
    ./Update-Contributors.ps1 -Milestone v15

    Prints who is missing from the contributor list for milestone v15. Changes nothing.

    .EXAMPLE
    ./Update-Contributors.ps1 -Since 2026-04-29 -Apply

    Adds everyone who is missing credits for work since April 29, 2026.

    .EXAMPLE
    ./Update-Contributors.ps1 -PullRequest 2395 -Apply

    Adds the author and reviewers of pull request 2395 if they are missing credits for it.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [datetime]
    $Since,

    [string]
    $Milestone,

    [int]
    $PullRequest,

    [ValidatePattern('^[\w.-]+/[\w.-]+$')]
    [string]
    $Repository = 'microsoft/finops-toolkit',

    [string]
    $ConfigPath = (Join-Path $PSScriptRoot '../../.all-contributorsrc'),

    [string[]]
    $Exclude = @(),

    [switch]
    $Apply,

    [string]
    $SummaryPath,

    [switch]
    $PassThru
)

#==============================================================================
# Pure logic (unit tested in src/powershell/Tests/Unit/Update-Contributors.Tests.ps1)
#==============================================================================

# Order credits are listed in (and added in). Anything else sorts after these.
function Get-ContributionTypeOrder
{
    return @('code', 'doc', 'bug', 'ideas', 'review')
}

# Accounts that look like people but aren't. Compared after removing "app/" and "[bot]".
function Get-KnownBotLogin
{
    return @(
        'dependabot'
        'copilot'
        'copilot-swe-agent'
        'copilot-pull-request-reviewer'
        'github-actions'
        'github-advanced-security'
        'allcontributors'
        'osssecuritybot'
        'microsoft-github-policy-service'
    )
}

function Test-BotLogin
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [AllowNull()][AllowEmptyString()]
        [string]
        $Login,

        [bool]
        $IsBot = $false
    )

    if ($IsBot -or [string]::IsNullOrWhiteSpace($Login)) { return $true }
    if ($Login -match '^app/' -or $Login -match '\[bot\]$') { return $true }
    return (Get-KnownBotLogin) -contains $Login.ToLowerInvariant()
}

# Returns 'code' and/or 'doc' for the files a PR changed.
function Get-FileContributionType
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [AllowNull()][AllowEmptyCollection()]
        [string[]]
        $Path,

        # Files the contributor CLI rewrites (the "files" in .all-contributorsrc), which are bookkeeping too
        [AllowNull()][AllowEmptyCollection()]
        [string[]]
        $IgnorePath = @()
    )

    $ignored = @($IgnorePath | ForEach-Object { ("$_" -replace '\\', '/').TrimStart('/') } | Where-Object { $_ })
    $code = $false
    $doc = $false
    foreach ($file in $Path)
    {
        $file = ($file -replace '\\', '/').TrimStart('/')
        if (-not $file) { continue }

        # The contributor list and the files generated from it are bookkeeping, and every code PR adds a changelog
        # entry, so none of them earn credit
        if ($file -ieq '.all-contributorsrc' -or $ignored -contains $file -or $file -match '(^|/)changelog\.md$') { continue }

        if ($file -match '^(docs-mslearn|docs-wiki|docs)/' -or $file -match '\.(md|mdx)$') { $doc = $true }
        else { $code = $true }
    }

    return @(
        if ($code) { 'code' }
        if ($doc) { 'doc' }
    )
}

# Records that a login deserves a type. Logins are deduplicated case-insensitively and types are a set.
function Add-ContributionNeed
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]
        $Needs,

        [Parameter(Mandatory)]
        [string]
        $Login,

        [Parameter(Mandatory)]
        [string[]]
        $Type,

        [string]
        $Evidence
    )

    $key = $Login.ToLowerInvariant()
    if (-not $Needs.ContainsKey($key))
    {
        $Needs[$key] = [pscustomobject]@{
            Login    = $Login
            Types    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            Evidence = @{}   # type -> references, so a row only cites what it is missing
        }
    }

    foreach ($t in $Type)
    {
        $t = $t.ToLowerInvariant()
        $null = $Needs[$key].Types.Add($t)
        if (-not $Needs[$key].Evidence.ContainsKey($t)) { $Needs[$key].Evidence[$t] = [System.Collections.Generic.List[string]]::new() }
        if ($Evidence -and -not $Needs[$key].Evidence[$t].Contains($Evidence)) { $Needs[$key].Evidence[$t].Add($Evidence) }
    }
}

# Compares what people deserve with what the config says. Returns one row per login that is missing a type.
function Get-MissingContribution
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]
        $Needs,

        [AllowNull()]
        [object[]]
        $Contributor,

        [string[]]
        $Exclude = @()
    )

    $order = Get-ContributionTypeOrder
    $excluded = @($Exclude | ForEach-Object { $_.ToLowerInvariant() })
    $existingByLogin = @{}
    foreach ($c in $Contributor) { if ($c.login) { $existingByLogin[$c.login.ToLowerInvariant()] = $c } }

    foreach ($key in ($Needs.Keys | Sort-Object))
    {
        if ($excluded -contains $key) { continue }

        $need = $Needs[$key]
        $existing = $existingByLogin[$key]
        $have = @(if ($existing) { $existing.contributions | ForEach-Object { "$_".ToLowerInvariant() } })
        $missing = @(
            $need.Types
            | Where-Object { $have -notcontains $_ }
            | Sort-Object { $i = [array]::IndexOf($order, $_); if ($i -lt 0) { 99 } else { $i } }, { $_ }
        )
        if ($missing.Count -eq 0) { continue }

        [pscustomobject]@{
            # Use the casing from the config so the CLI updates the existing entry instead of adding a duplicate
            Login    = if ($existing) { $existing.login } else { $need.Login }
            Missing  = $missing
            IsNew    = -not $existing
            Evidence = @($missing | ForEach-Object { $need.Evidence[$_] } | Select-Object -Unique)
        }
    }
}

# Decides whether an issue's author earns credit. CONTRIBUTING.md credits bugs that were "confirmed or fixed" and
# ideas that "shaped the product", so a label alone is not enough: the issue must have been fixed (closed as
# completed) or accepted (assigned to a milestone), and must not be a duplicate, external, or won't-fix.
function Test-IssueCredit
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [AllowNull()][AllowEmptyCollection()]
        [string[]]
        $Label,

        [AllowNull()][AllowEmptyString()]
        [string]
        $StateReason,

        [bool]
        $HasMilestone = $false
    )

    if (@($Label | Where-Object { $_ -match "^Resolution:\s*(Duplicate|Won't fix|Can't repro|No activity|External|Support request)" })) { return $false }
    if ($StateReason -in 'NOT_PLANNED', 'DUPLICATE') { return $false }
    return ($StateReason -eq 'COMPLETED') -or $HasMilestone
}

# Returns 'bug' for Type: Bug and 'ideas' for Type: Feature labels.
function Get-IssueContributionType
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [AllowNull()][AllowEmptyCollection()]
        [string[]]
        $Label
    )

    return @(
        if (@($Label) -match '^Type:\s*Bug') { 'bug' }
        if (@($Label) -match '^Type:\s*Feature') { 'ideas' }
    )
}

# Puts single-line JSON arrays of simple values back on multiple lines, one item per line, using the indentation
# of the line they are on. Lines with nested arrays/objects and empty arrays are left alone.
function Expand-JsonInlineArray
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]
        $Text
    )

    $lines = $Text -split '\r?\n', 0   # 0 = no limit (-1 would not split)
    $result = foreach ($line in $lines)
    {
        $m = [regex]::Match($line, '^(?<indent>\s*)(?<key>"(?:[^"\\]|\\.)*":\s*)\[(?<items>[^\[\]{}]*)\](?<comma>,?)\s*$')
        if (-not $m.Success -or -not $m.Groups['items'].Value.Trim()) { $line; continue }

        # Tokens are kept verbatim so strings are not re-escaped
        $items = @([regex]::Matches($m.Groups['items'].Value, '"(?:[^"\\]|\\.)*"|[^,\s]+') | ForEach-Object { $_.Value })
        $indent = $m.Groups['indent'].Value
        "$indent$($m.Groups['key'].Value)["
        for ($i = 0; $i -lt $items.Count; $i++)
        {
            "$indent  $($items[$i])$(if ($i -lt $items.Count - 1) { ',' })"
        }
        "$indent]$($m.Groups['comma'].Value)"
    }

    return $result -join "`n"
}

# Converts line endings to match a previous version of the text (CRLF or LF).
function ConvertTo-LineEnding
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]
        $Text,

        [Parameter(Mandatory)]
        [bool]
        $Crlf
    )

    $lf = $Text -replace '\r\n', "`n"
    if ($Crlf) { return $lf -replace '\n', "`r`n" }
    return $lf
}

# Verifies that the config only gained credits: same contributors in the same order, no credits removed, other
# settings unchanged, and a text diff that is limited to added lines (plus the comma on the line before an addition).
function Test-ContributorConfigChange
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Before,

        [Parameter(Mandatory)]
        [string]
        $After
    )

    $fail = { param($reason) [pscustomobject]@{ Ok = $false; Reason = $reason; Added = 0; Removed = 0 } }

    try
    {
        $b = $Before | ConvertFrom-Json -Depth 20
        $a = $After | ConvertFrom-Json -Depth 20
    }
    catch { return & $fail "Config is not valid JSON: $($_.Exception.Message)" }

    $oldContributors = @($b.contributors)
    $newContributors = @($a.contributors)
    if ($newContributors.Count -lt $oldContributors.Count) { return & $fail 'Contributors were removed.' }

    $touched = 0
    for ($i = 0; $i -lt $oldContributors.Count; $i++)
    {
        $o = $oldContributors[$i]
        $n = $newContributors[$i]
        if ($o.login -ne $n.login) { return & $fail "Contributor order changed at position $($i + 1) ($($o.login))." }

        $oMeta = $o | Select-Object -Property * -ExcludeProperty contributions | ConvertTo-Json -Depth 5 -Compress
        $nMeta = $n | Select-Object -Property * -ExcludeProperty contributions | ConvertTo-Json -Depth 5 -Compress
        if ($oMeta -ne $nMeta) { return & $fail "Details changed for $($o.login)." }

        $lost = @($o.contributions | Where-Object { @($n.contributions) -notcontains $_ })
        if ($lost) { return & $fail "Credits were removed from $($o.login): $($lost -join ', ')." }
        if (@($n.contributions).Count -ne @($o.contributions).Count) { $touched++ }
    }

    $oSettings = $b | Select-Object -Property * -ExcludeProperty contributors | ConvertTo-Json -Depth 20 -Compress
    $nSettings = $a | Select-Object -Property * -ExcludeProperty contributors | ConvertTo-Json -Depth 20 -Compress
    if ($oSettings -ne $nSettings) { return & $fail 'Settings other than contributors changed.' }

    # Text diff: additions are expected; the only removals allowed are the last item of an array that grew
    # (it gains a trailing comma), one per touched contributor, plus one for the last contributor object.
    $beforeLines = @($Before -split '\r?\n' | Where-Object { $_.Trim() })
    $afterLines = @($After -split '\r?\n' | Where-Object { $_.Trim() })
    $diff = @(Compare-Object -ReferenceObject $beforeLines -DifferenceObject $afterLines)
    $removed = @($diff | Where-Object SideIndicator -eq '<=').Count
    $added = @($diff | Where-Object SideIndicator -eq '=>').Count
    if ($removed -gt $touched + 1)
    {
        return [pscustomobject]@{ Ok = $false; Reason = "Diff removes $removed lines; expected at most $($touched + 1). The file was probably reformatted."; Added = $added; Removed = $removed }
    }

    return [pscustomobject]@{ Ok = $true; Reason = ''; Added = $added; Removed = $removed }
}

# Formats the missing credits as a markdown table.
function Format-MissingContributionMarkdown
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [AllowNull()]
        [object[]]
        $Missing,

        [string]
        $Repository = 'microsoft/finops-toolkit',

        [AllowNull()]
        [object[]]
        $NeedsHuman
    )

    # GitHub redirects /issues/N to the PR when N is a pull request. Long lists are shortened.
    $link = {
        param($evidence)
        $refs = @($evidence | Select-Object -First 8 | ForEach-Object { $_ -replace '^(?:PR|issue) #(\d+)$', "[#`$1](https://github.com/$Repository/issues/`$1)" })
        ($refs -join ', ') + $(if (@($evidence).Count -gt 8) { " (+$(@($evidence).Count - 8) more)" })
    }

    $sections = @()
    if ($Missing)
    {
        $rows = foreach ($m in $Missing)
        {
            "| [@$($m.Login)](https://github.com/$($m.Login)) | $($m.Missing -join ', ') | $(if ($m.IsNew) { 'New' } else { 'Existing' }) | $(& $link $m.Evidence) |"
        }
        $sections += (@('| Contributor | Credits | Entry | Evidence |', '| ----------- | ------- | ----- | -------- |') + $rows) -join "`n"
    }
    else { $sections += 'No missing contributor credits.' }

    if ($NeedsHuman)
    {
        $rows = foreach ($h in $NeedsHuman) { "| [@$($h.Login)](https://github.com/$($h.Login)) | $(& $link $h.Evidence) |" }
        $sections += (@(
                'These people filed fixed or accepted issues that have no `Type:` label, so a human needs to choose a type (for example, `bug` or `ideas`):'
                ''
                '| Contributor | Issues |'
                '| ----------- | ------ |'
            ) + $rows) -join "`n"
    }

    return $sections -join "`n`n"
}

#==============================================================================
# GitHub access
#==============================================================================

# Runs gh and returns stdout lines. Retries transient server errors and turns auth and rate limit failures
# into clear messages.
function Invoke-Gh
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]
        $Argument
    )

    for ($attempt = 1; $attempt -le 3; $attempt++)
    {
        $output = & $script:GhPath @Argument 2>&1
        if ($LASTEXITCODE -eq 0)
        {
            return @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
        }

        $err = ($output | ForEach-Object { "$_" }) -join "`n"
        Resolve-GhError -Message $err -Command ($Argument -join ' ')
        if ($attempt -eq 3) { throw "gh $($Argument -join ' ') failed after $attempt attempts: $err" }
        Start-Sleep -Seconds (2 * $attempt)
    }
}

# Throws a friendly error for failures that retrying will not fix. Returns for transient failures.
function Resolve-GhError
{
    [CmdletBinding()]
    param (
        [string]
        $Message,

        [string]
        $Command
    )

    if ($Message -match 'rate limit|HTTP 429|secondary rate')
    {
        $reset = ''
        try
        {
            $epoch = & $script:GhPath api rate_limit --jq '[.resources.core.reset, .resources.graphql.reset, .resources.search.reset] | max' 2>$null
            if ($epoch) { $reset = " Limits reset at $([DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).UtcDateTime.ToString('u'))." }
        }
        catch { Write-Verbose "Could not read the rate limit reset time: $($_.Exception.Message)" }
        throw "GitHub API rate limit exceeded.$reset Wait and run again, or authenticate with a token that has a higher limit (gh auth login). Command: gh $Command"
    }

    if ($Message -match 'HTTP 401|Bad credentials|gh auth login|authentication')
    {
        throw "gh is not authenticated or the token was rejected. Run 'gh auth login' (or set GH_TOKEN) and try again. Command: gh $Command"
    }

    if ($Message -match 'HTTP 404|Could not resolve to a Repository')
    {
        throw "GitHub returned not found for '$Command'. Check -Repository and that your gh account can read it. $Message"
    }

    if ($Message -match 'HTTP 403')
    {
        throw "GitHub denied access for '$Command' (HTTP 403). $Message"
    }

    # Anything else (HTTP 5xx, timeouts, connection resets) is treated as transient by the caller
}

function Get-MergedPullRequest
{
    [CmdletBinding()]
    param (
        [string]
        $Repository,

        [AllowNull()]
        [Nullable[datetime]]
        $Since,

        [string]
        $Milestone
    )

    $query = @(
        if ($Since) { "merged:>=$($Since.ToString('yyyy-MM-dd'))" }
        if ($Milestone) { "milestone:`"$Milestone`"" }
    ) -join ' '
    $json = Invoke-Gh @('pr', 'list', '-R', $Repository, '--state', 'merged', '--search', $query, '--limit', '1000', '--json', 'number,author,mergedAt')
    $prs = @($json -join '' | ConvertFrom-Json)
    if ($prs.Count -ge 1000) { Write-Warning 'Found 1000 merged PRs, which is the limit. Use a narrower -Since or -Milestone.' }
    return $prs
}

# Reads the changed files and reviews of many PRs in parallel (two REST calls per PR).
function Get-PullRequestDetail
{
    [CmdletBinding()]
    param (
        [string]
        $Repository,

        [object[]]
        $PullRequest
    )

    $gh = $script:GhPath
    $details = $PullRequest | ForEach-Object -ThrottleLimit 6 -Parallel {
        $number = $_.number
        $result = [pscustomobject]@{ Number = $number; Files = @(); Reviews = @(); Error = $null }
        $calls = @{
            Files   = @('api', '--paginate', "repos/$($using:Repository)/pulls/$number/files", '--jq', '.[].filename')
            Reviews = @('api', '--paginate', "repos/$($using:Repository)/pulls/$number/reviews", '--jq', '.[] | select(.user != null) | [.user.login, .state, .user.type] | @tsv')
        }
        foreach ($name in $calls.Keys)
        {
            for ($attempt = 1; $attempt -le 3; $attempt++)
            {
                $out = & $using:gh @($calls[$name]) 2>&1
                if ($LASTEXITCODE -eq 0)
                {
                    $result.$name = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
                    $result.Error = $null
                    break
                }
                $result.Error = ($out | ForEach-Object { "$_" }) -join "`n"
                if ($result.Error -match 'rate limit|HTTP 4\d\d') { break }
                Start-Sleep -Seconds (2 * $attempt)
            }
            if ($result.Error) { break }
        }
        $result
    }

    # Surface the first failure with the same friendly messages as everywhere else
    $failed = @($details | Where-Object Error | Select-Object -First 1)
    if ($failed) { Resolve-GhError -Message $failed.Error -Command "api pulls/$($failed.Number)"; throw "Could not read PR #$($failed.Number): $($failed.Error)" }

    return $details
}

function Get-IssueCandidate
{
    [CmdletBinding()]
    param (
        [string]
        $Repository,

        [AllowNull()]
        [Nullable[datetime]]
        $Since,

        [string]
        $Milestone
    )

    $milestoneQuery = if ($Milestone) { "milestone:`"$Milestone`"" }
    $searches = if ($Since)
    {
        # An issue counts if it was reported or resolved in the window
        $date = $Since.ToString('yyyy-MM-dd')
        @("created:>=$date $milestoneQuery", "closed:>=$date $milestoneQuery")
    }
    else { @($milestoneQuery) }

    $issues = @{}
    foreach ($search in $searches)
    {
        $json = Invoke-Gh @('issue', 'list', '-R', $Repository, '--state', 'all', '--search', $search.Trim(), '--limit', '1000', '--json', 'number,author,labels,stateReason,milestone')
        $found = @($json -join '' | ConvertFrom-Json)
        if ($found.Count -ge 1000) { Write-Warning 'Found 1000 issues, which is the limit. Use a narrower -Since or -Milestone.' }
        foreach ($issue in $found) { $issues[[int]$issue.number] = $issue }
    }
    return $issues.Values
}

#==============================================================================
# Main
#==============================================================================

# Tests extract the functions above, so the main body only runs when the script is executed
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'

if (-not $Since -and -not $Milestone -and -not $PullRequest)
{
    throw 'Specify -Since <date>, -Milestone <name>, or -PullRequest <number> so the script knows which contributions to look at.'
}
if ($PullRequest -and ($Since -or $Milestone))
{
    throw '-PullRequest cannot be combined with -Since or -Milestone.'
}

# Find gh (it is not always on PATH, especially on Windows)
$script:GhPath = (Get-Command gh -ErrorAction SilentlyContinue)?.Source
if (-not $script:GhPath -and $IsWindows) { $script:GhPath = Join-Path $env:ProgramFiles 'GitHub CLI/gh.exe' }
if (-not $script:GhPath -or -not (Test-Path $script:GhPath))
{
    throw 'The GitHub CLI (gh) is required. Install it from https://cli.github.com and run gh auth login.'
}

& $script:GhPath auth status *> $null
if ($LASTEXITCODE -ne 0)
{
    throw "gh is not authenticated. Run 'gh auth login' (or set GH_TOKEN) and try again."
}

$ConfigPath = (Resolve-Path $ConfigPath -ErrorAction Stop).Path
$repoRoot = Split-Path $ConfigPath -Parent
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 20
$needs = @{}
$unclassified = @{}   # authors of fixed/accepted issues with no Type label, which only a human can classify

$scope = @(
    if ($Since) { "since $($Since.ToString('yyyy-MM-dd'))" }
    if ($Milestone) { "in milestone $Milestone" }
    if ($PullRequest) { "in PR #$PullRequest" }
) -join ' and '
Write-Host "Looking for contributions to $Repository $scope..."

# Merged PRs: authors get code/doc, reviewers get review
$prs = if ($PullRequest) { @((Invoke-Gh @('pr', 'view', "$PullRequest", '-R', $Repository, '--json', 'number,author')) -join '' | ConvertFrom-Json) }
       else { @(Get-MergedPullRequest -Repository $Repository -Since $Since -Milestone $Milestone) }
Write-Host "  $($prs.Count) $(if ($PullRequest) { 'PR' } else { 'merged PRs' })"
if ($prs.Count -gt 0)
{
    # PR details use 2 REST calls each. Stop early with a clear message instead of failing partway through.
    $limits = (Invoke-Gh @('api', 'rate_limit', '--jq', '.resources.core | "\(.remaining) \(.reset)"')) -split ' '
    if ([int]$limits[0] -lt (2 * $prs.Count + 50))
    {
        $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$limits[1]).UtcDateTime.ToString('u')
        throw "GitHub API rate limit is too low: $($limits[0]) calls left and about $(2 * $prs.Count) are needed. Limits reset at $reset."
    }

    $details = Get-PullRequestDetail -Repository $Repository -PullRequest $prs
    $authors = @{}
    $prs | ForEach-Object { $authors[[int]$_.number] = $_.author }
    foreach ($detail in $details)
    {
        $author = $authors[[int]$detail.Number]
        $authorLogin = $author.login -replace '^app/', ''
        if (-not (Test-BotLogin -Login $author.login -IsBot ([bool]$author.is_bot)))
        {
            $types = Get-FileContributionType -Path $detail.Files -IgnorePath $config.files
            if ($types) { Add-ContributionNeed -Needs $needs -Login $authorLogin -Type $types -Evidence "PR #$($detail.Number)" }
        }

        foreach ($line in $detail.Reviews)
        {
            $login, $state, $userType = $line -split "`t"
            if ($state -eq 'PENDING') { continue }
            if ($login -ieq $authorLogin -or (Test-BotLogin -Login $login -IsBot ($userType -eq 'Bot'))) { continue }
            Add-ContributionNeed -Needs $needs -Login $login -Type 'review' -Evidence "PR #$($detail.Number)"
        }
    }
}

# Issues: Bug label gets bug, Feature label gets ideas
$issues = if ($PullRequest) { @() } else { @(Get-IssueCandidate -Repository $Repository -Since $Since -Milestone $Milestone) }
Write-Host "  $($issues.Count) issues"
foreach ($issue in $issues)
{
    if (Test-BotLogin -Login $issue.author.login -IsBot ([bool]$issue.author.is_bot)) { continue }
    $labels = @($issue.labels.name)
    if (-not (Test-IssueCredit -Label $labels -StateReason $issue.stateReason -HasMilestone ([bool]$issue.milestone))) { continue }
    $types = Get-IssueContributionType -Label $labels
    if ($types) { Add-ContributionNeed -Needs $needs -Login $issue.author.login -Type $types -Evidence "issue #$($issue.number)" }
    elseif (-not ($labels -match '^Type:')) { Add-ContributionNeed -Needs $unclassified -Login $issue.author.login -Type 'unknown' -Evidence "issue #$($issue.number)" }
}

$missing = @(Get-MissingContribution -Needs $needs -Contributor $config.contributors -Exclude $Exclude)

# People who aren't listed at all and filed a fixed/accepted issue we couldn't classify
$listed = @($config.contributors.login + $missing.Login + $Exclude | ForEach-Object { "$_".ToLowerInvariant() })
$manual = @(
    $unclassified.Keys | Sort-Object | Where-Object { $listed -notcontains $_ }
    | ForEach-Object { [pscustomobject]@{ Login = $unclassified[$_].Login; Evidence = @($unclassified[$_].Evidence['unknown']) } }
)

Write-Host ''
if ($manual.Count -gt 0)
{
    Write-Host "$($manual.Count) issue author(s) are not listed but their issues have no Type label, so a human needs to choose a type (bug, ideas, ...):" -ForegroundColor Yellow
    $manual | Select-Object Login, @{ n = 'Evidence'; e = { $_.Evidence -join ', ' } } | Format-Table -AutoSize | Out-Host
}
if ($missing.Count -eq 0)
{
    Write-Host "Nobody is missing. All $($needs.Count) people with inferable contributions are already credited in $(Split-Path $ConfigPath -Leaf)." -ForegroundColor Green
}
else
{
    Write-Host "$($missing.Count) contributor(s) missing credits:" -ForegroundColor Yellow
    $missing `
    | Select-Object Login, @{ n = 'Missing'; e = { $_.Missing -join ', ' } }, @{ n = 'Entry'; e = { if ($_.IsNew) { 'new' } else { 'existing' } } }, @{ n = 'Evidence'; e = { (($_.Evidence | Select-Object -First 4) -join ', ') + $(if ($_.Evidence.Count -gt 4) { " (+$($_.Evidence.Count - 4) more)" }) } } `
    | Format-Table -AutoSize -Wrap `
    | Out-Host
}

$failed = @()
if ($missing.Count -gt 0 -and $Apply)
{
    if (-not $PSCmdlet.ShouldProcess($ConfigPath, "Add $($missing.Count) contributor(s) with all-contributors"))
    {
        Write-Host 'Skipped (WhatIf).'
    }
    else
    {
        $cli = Join-Path $PSScriptRoot '../../node_modules/all-contributors-cli/dist/cli.js'
        if (-not (Test-Path $cli)) { throw "all-contributors-cli is not installed. Run 'npm ci --ignore-scripts' at the repo root first." }
        $node = (Get-Command node -ErrorAction SilentlyContinue)?.Source
        if (-not $node) { throw 'Node.js is required for -Apply (it runs all-contributors-cli).' }

        # Snapshot everything the CLI can change so a bad result can be rolled back
        $targets = @($ConfigPath) + @($config.files | ForEach-Object { Join-Path $repoRoot $_ })
        $snapshots = @{}
        foreach ($t in $targets) { if (Test-Path $t) { $snapshots[$t] = [System.IO.File]::ReadAllText($t) } }

        # The CLI looks up each profile on GitHub; a token avoids the low anonymous rate limit
        $previousToken = $env:PRIVATE_TOKEN
        if (-not $env:PRIVATE_TOKEN) { $env:PRIVATE_TOKEN = $env:GH_TOKEN ?? $env:GITHUB_TOKEN ?? (& $script:GhPath auth token 2>$null) }

        Push-Location $repoRoot
        try
        {
            foreach ($m in $missing)
            {
                Write-Host "Adding $($m.Login): $($m.Missing -join ', ')"
                $out = & $node $cli add $m.Login ($m.Missing -join ',') 2>&1
                if ($LASTEXITCODE -ne 0)
                {
                    $failed += $m.Login
                    Write-Warning "all-contributors failed for $($m.Login): $($out -join ' ')"
                }
            }
        }
        finally
        {
            Pop-Location
            $env:PRIVATE_TOKEN = $previousToken
        }

        # The CLI writes LF and collapses arrays. Match the original line endings and trailing blank lines, then
        # expand the arrays so the diff only shows what was added.
        $original = $snapshots[$ConfigPath]
        $crlf = $original.Contains("`r`n")
        $trailing = [regex]::Match($original, '\s*$').Value
        $text = Expand-JsonInlineArray -Text ([System.IO.File]::ReadAllText($ConfigPath).TrimEnd())
        $text = ConvertTo-LineEnding -Text ($text + (ConvertTo-LineEnding -Text $trailing -Crlf $false)) -Crlf $crlf
        [System.IO.File]::WriteAllText($ConfigPath, $text)
        foreach ($t in $targets | Where-Object { $_ -ne $ConfigPath -and $snapshots.ContainsKey($_) })
        {
            [System.IO.File]::WriteAllText($t, (ConvertTo-LineEnding -Text ([System.IO.File]::ReadAllText($t)) -Crlf $snapshots[$t].Contains("`r`n")))
        }

        $check = Test-ContributorConfigChange -Before $original -After $text
        if (-not $check.Ok)
        {
            foreach ($t in $snapshots.Keys) { [System.IO.File]::WriteAllText($t, $snapshots[$t]) }
            throw "Unexpected changes to $(Split-Path $ConfigPath -Leaf), so the original files were restored. $($check.Reason)"
        }

        Write-Host "Updated $(Split-Path $ConfigPath -Leaf): $($check.Added) lines added, $($check.Removed) removed." -ForegroundColor Green
        Write-Host 'Review and commit the changed files: ' -NoNewline
        Write-Host (($snapshots.Keys | ForEach-Object { [System.IO.Path]::GetRelativePath($repoRoot, $_) -replace '\\', '/' } | Sort-Object) -join ', ')
    }
}
elseif ($missing.Count -gt 0)
{
    Write-Host 'Dry run. Run again with -Apply to add them.'
}

if ($SummaryPath)
{
    # Built after -Apply so logins that failed aren't listed as added
    $added = @($missing | Where-Object { $failed -notcontains $_.Login })
    $summary = Format-MissingContributionMarkdown -Missing $added -Repository $Repository -NeedsHuman $manual
    [System.IO.File]::WriteAllText($SummaryPath, $summary + "`n")
}

if ($PassThru) { $missing }

if ($failed.Count -gt 0)
{
    Write-Error "Could not add: $($failed -join ', '). Everyone else was added." -ErrorAction Continue
    exit 1
}
