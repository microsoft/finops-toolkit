# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Validates documentation links across all documentation folders.

    .DESCRIPTION
    Tests that internal markdown links resolve to real files and anchors across
    docs-mslearn, docs (Jekyll site), docs-wiki (GitHub Wiki), and root markdown
    files. Also validates that wiki double-bracket links reference existing pages,
    that wiki repo-relative links point to real files, that no
    https://learn.microsoft.com links appear in docs-mslearn (they should be
    root-relative), and that no language locale segments appear in MS Learn links.
#>

BeforeDiscovery {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName

    # Helper: Remove HTML comments from content to avoid matching links inside <!-- ... -->
    function Remove-HtmlComments([string]$text)
    {
        return [regex]::Replace($text, '<!--[\s\S]*?-->', { param($m) "`n" * ($m.Value -split "`n").Count })
    }

    # Helper: Collect markdown files from a folder
    function Get-MarkdownFiles([string]$folderPath, [string]$rootForRelative)
    {
        if (-not (Test-Path $folderPath)) { return @() }
        Get-ChildItem -Path $folderPath -Recurse -Include '*.md' | ForEach-Object {
            @{
                FullName     = $_.FullName
                RelativePath = $_.FullName.Substring($rootForRelative.Length + 1) -replace '\\', '/'
                Content      = Get-Content -Path $_.FullName -Raw
            }
        }
    }

    # Helper: Extract internal relative markdown links from files
    function Get-InternalMdLinks([array]$mdFiles)
    {
        $links = @()
        foreach ($file in $mdFiles)
        {
            $cleanContent = Remove-HtmlComments $file.Content
            $linkMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\(([^)]+)\)')
            foreach ($match in $linkMatches)
            {
                $linkTarget = $match.Groups[2].Value

                # Skip external links, absolute paths, anchor-only links, special schemes, and Jekyll templates
                if ($linkTarget -match '^(https?://|mailto:|/|#|\{\{)') { continue }

                # Parse out any anchor
                $pathPart = $linkTarget -replace '#.*$', ''
                $anchorPart = if ($linkTarget -match '#(.+)$') { $Matches[1] } else { $null }

                # Skip empty path parts (anchor-only links that somehow got through)
                if ([string]::IsNullOrEmpty($pathPart) -and -not [string]::IsNullOrEmpty($anchorPart)) { continue }

                # Only check .md files
                if ($pathPart -and $pathPart -notmatch '\.md$') { continue }

                $links += @{
                    SourceFile  = $file.FullName
                    SourceRel   = $file.RelativePath
                    LinkText    = $match.Groups[1].Value
                    LinkTarget  = $linkTarget
                    PathPart    = $pathPart
                    AnchorPart  = $anchorPart
                    LineNumber  = ($file.Content.Substring(0, $match.Index) -split "`n").Count
                }
            }
        }
        return $links
    }

    # Helper: Extract all URLs from markdown files
    function Get-MarkdownUrls([array]$mdFiles)
    {
        $urls = @()
        foreach ($file in $mdFiles)
        {
            $cleanContent = Remove-HtmlComments $file.Content
            $urlMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\((https?://[^)]+)\)')
            foreach ($match in $urlMatches)
            {
                $urls += @{
                    SourceFile  = $file.FullName
                    SourceRel   = $file.RelativePath
                    LinkText    = $match.Groups[1].Value
                    Url         = $match.Groups[2].Value
                    LineNumber  = ($file.Content.Substring(0, $match.Index) -split "`n").Count
                }
            }
        }
        return $urls
    }

    # Known issues to skip before a specific version (remove entries as links are fixed)
    $toolkitVersion = (Get-Content (Join-Path $repoRoot 'package.json') | ConvertFrom-Json).version
    $knownIssues = @(
        # configure-recommendations.md will be created as part of 14.0
        @{ MaxVersion = '14.0'; PathPattern = 'toolkit/hubs/data-processing.md'; LinkPattern = 'configure-recommendations.md' }
    )

    # Helper: Check if a link should be skipped as a known issue
    function Test-KnownIssue([string]$sourceRel, [string]$linkTarget)
    {
        foreach ($issue in $knownIssues)
        {
            if ([version]$toolkitVersion -lt [version]$issue.MaxVersion -and
                $sourceRel -match $issue.PathPattern -and
                $linkTarget -match $issue.LinkPattern)
            {
                return $true
            }
        }
        return $false
    }

    #region docs-mslearn
    $mslearnRoot = Join-Path $repoRoot 'docs-mslearn'
    $mslearnFiles = Get-MarkdownFiles $mslearnRoot $mslearnRoot
    $mslearnInternalLinks = Get-InternalMdLinks $mslearnFiles | Where-Object { -not (Test-KnownIssue $_.SourceRel $_.LinkTarget) }
    $mslearnUrls = Get-MarkdownUrls $mslearnFiles
    #endregion

    #region docs (Jekyll site)
    $jekyllRoot = Join-Path $repoRoot 'docs'
    # Exclude _automation/ (parked files pending migration to docs-mslearn)
    $jekyllFiles = Get-MarkdownFiles $jekyllRoot $jekyllRoot | Where-Object { $_.RelativePath -notmatch '^_automation/' }
    $jekyllInternalLinks = Get-InternalMdLinks $jekyllFiles
    #endregion

    #region docs-wiki (GitHub Wiki)
    $wikiRoot = Join-Path $repoRoot 'docs-wiki'
    $wikiFiles = Get-MarkdownFiles $wikiRoot $wikiRoot
    # Exclude ../tree/ and ../wiki/ GitHub navigation links from internal link checks
    $wikiInternalLinks = Get-InternalMdLinks $wikiFiles | Where-Object { $_.LinkTarget -notmatch '^\.\./tree/' -and $_.LinkTarget -notmatch '^\.\./wiki/' }

    # Get all wiki page filenames for case-insensitive lookup
    $wikiPageFileNames = @()
    if (Test-Path $wikiRoot)
    {
        $wikiPageFileNames = Get-ChildItem -Path $wikiRoot -Filter '*.md' -File | ForEach-Object { $_.Name }
    }

    # Extract wiki double-bracket links: [[Page]] or [[Display|Page]]
    $wikiPageLinks = @()
    foreach ($file in $wikiFiles)
    {
        $cleanContent = Remove-HtmlComments $file.Content
        $wikiMatches = [regex]::Matches($cleanContent, '\[\[(?:([^\]|]+)\|)?([^\]]+)\]\]')
        foreach ($match in $wikiMatches)
        {
            $pageName = $match.Groups[2].Value.Trim()
            $wikiPageLinks += @{
                SourceFile  = $file.FullName
                SourceRel   = $file.RelativePath
                DisplayText = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $pageName }
                PageName    = $pageName
                LineNumber  = ($file.Content.Substring(0, $match.Index) -split "`n").Count
            }
        }
    }

    # Extract wiki ../tree/dev/ repo-relative links
    $wikiRepoLinks = @()
    foreach ($file in $wikiFiles)
    {
        $cleanContent = Remove-HtmlComments $file.Content
        $repoMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\((\.\./tree/dev/[^)]+)\)')
        foreach ($match in $repoMatches)
        {
            $linkTarget = $match.Groups[2].Value
            $repoPath = $linkTarget -replace '^\.\./tree/dev/', '' -replace '#.*$', ''
            $wikiRepoLinks += @{
                SourceFile  = $file.FullName
                SourceRel   = $file.RelativePath
                LinkText    = $match.Groups[1].Value
                LinkTarget  = $linkTarget
                RepoPath    = $repoPath
                LineNumber  = ($file.Content.Substring(0, $match.Index) -split "`n").Count
            }
        }
    }
    #endregion

    #region Root markdown files
    $rootMdFiles = @()
    if (Test-Path $repoRoot)
    {
        $rootMdFiles = Get-ChildItem -Path $repoRoot -Filter '*.md' -File | ForEach-Object {
            @{
                FullName     = $_.FullName
                RelativePath = $_.Name
                Content      = Get-Content -Path $_.FullName -Raw
            }
        }
    }
    $rootInternalLinks = Get-InternalMdLinks $rootMdFiles
    #endregion
}

Describe 'Documentation links' {

    BeforeAll {
        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $wikiRoot = Join-Path $repoRoot 'docs-wiki'
        $wikiPageFileNames = @()
        if (Test-Path $wikiRoot)
        {
            $wikiPageFileNames = Get-ChildItem -Path $wikiRoot -Filter '*.md' -File | ForEach-Object { $_.Name }
        }
    }

    #region docs-mslearn

    Context 'docs-mslearn: Internal relative links' {

        It 'Should resolve to an existing file: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $mslearnInternalLinks {
            $sourceDir = Split-Path $SourceFile -Parent

            if ([string]::IsNullOrEmpty($PathPart))
            {
                Set-ItResult -Skipped -Because 'anchor-only link'
                return
            }

            $resolvedPath = Join-Path $sourceDir $PathPart | Resolve-Path -ErrorAction SilentlyContinue
            $resolvedPath | Should -Not -BeNullOrEmpty -Because "link target '$PathPart' in ${SourceRel}:${LineNumber} should resolve to an existing file"
        }

        It 'Should have a valid anchor: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach ($mslearnInternalLinks | Where-Object { $_.AnchorPart }) {
            $sourceDir = Split-Path $SourceFile -Parent
            $resolvedPath = Join-Path $sourceDir $PathPart

            if (-not (Test-Path $resolvedPath))
            {
                Set-ItResult -Skipped -Because 'target file does not exist (covered by file resolution test)'
                return
            }

            $targetContent = Get-Content -Path $resolvedPath -Raw

            # Extract anchors from headings (e.g., ## My Heading -> my-heading)
            $headings = [regex]::Matches($targetContent, '(?m)^#{1,6}\s+(.+)$')
            $anchors = @($headings | ForEach-Object {
                $heading = $_.Groups[1].Value.Trim()
                $heading `
                    -replace '<!--.*?-->', '' `
                    -replace '\[([^\]]*)\]\([^)]*\)', '$1' `
                    -replace '`([^`]*)`', '$1' `
                    -replace '[^a-zA-Z0-9\s\-_]', '' `
                    -replace '\s+', '-' `
                    | ForEach-Object { $_.Trim('-').ToLower() }
            })

            # Extract anchors from HTML elements (e.g., <a name="datasets"> or <a id="datasets">)
            $htmlAnchors = [regex]::Matches($targetContent, '<a\s+(?:name|id)=[''"]([^''"]+)[''"]')
            $anchors += @($htmlAnchors | ForEach-Object { $_.Groups[1].Value.ToLower() })

            $anchors | Should -Contain $AnchorPart -Because "anchor '#$AnchorPart' should match a heading or HTML anchor in $(Split-Path $resolvedPath -Leaf) (link in ${SourceRel}:${LineNumber})"
        }
    }

    Context 'docs-mslearn: No learn.microsoft.com URLs' {

        It 'Should not contain https://learn.microsoft.com links: <SourceRel>:<LineNumber>' -ForEach ($mslearnUrls | Where-Object { $_.Url -match 'learn\.microsoft\.com' }) {
            $Url | Should -Not -Match 'learn\.microsoft\.com' -Because "links in docs-mslearn should use root-relative paths (e.g., /azure/...) instead of full URLs since docs are deployed to learn.microsoft.com (${SourceRel}:${LineNumber})"
        }
    }

    Context 'docs-mslearn: No language locale in MS Learn links' {

        It 'Should not contain language locale in URL: <SourceRel>:<LineNumber> <Url>' -ForEach ($mslearnUrls | Where-Object { $_.Url -match 'learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/' }) {
            $Url | Should -Not -Match 'learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/' -Because "MS Learn links should not include language locale segments like /en-us/ (${SourceRel}:${LineNumber})"
        }
    }

    #endregion

    #region docs (Jekyll site)

    Context 'docs: Internal relative links' {

        It 'Should resolve to an existing file: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $jekyllInternalLinks {
            $sourceDir = Split-Path $SourceFile -Parent

            if ([string]::IsNullOrEmpty($PathPart))
            {
                Set-ItResult -Skipped -Because 'anchor-only link'
                return
            }

            $resolvedPath = Join-Path $sourceDir $PathPart | Resolve-Path -ErrorAction SilentlyContinue
            $resolvedPath | Should -Not -BeNullOrEmpty -Because "link target '$PathPart' in ${SourceRel}:${LineNumber} should resolve to an existing file"
        }

        It 'Should have a valid anchor: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach ($jekyllInternalLinks | Where-Object { $_.AnchorPart }) {
            $sourceDir = Split-Path $SourceFile -Parent
            $resolvedPath = Join-Path $sourceDir $PathPart

            if (-not (Test-Path $resolvedPath))
            {
                Set-ItResult -Skipped -Because 'target file does not exist (covered by file resolution test)'
                return
            }

            $targetContent = Get-Content -Path $resolvedPath -Raw

            $headings = [regex]::Matches($targetContent, '(?m)^#{1,6}\s+(.+)$')
            $anchors = @($headings | ForEach-Object {
                $heading = $_.Groups[1].Value.Trim()
                $heading `
                    -replace '<!--.*?-->', '' `
                    -replace '\[([^\]]*)\]\([^)]*\)', '$1' `
                    -replace '`([^`]*)`', '$1' `
                    -replace '[^a-zA-Z0-9\s\-_]', '' `
                    -replace '\s+', '-' `
                    | ForEach-Object { $_.Trim('-').ToLower() }
            })

            $htmlAnchors = [regex]::Matches($targetContent, '<a\s+(?:name|id)=[''"]([^''"]+)[''"]')
            $anchors += @($htmlAnchors | ForEach-Object { $_.Groups[1].Value.ToLower() })

            $anchors | Should -Contain $AnchorPart -Because "anchor '#$AnchorPart' should match a heading or HTML anchor in $(Split-Path $resolvedPath -Leaf) (link in ${SourceRel}:${LineNumber})"
        }
    }

    #endregion

    #region docs-wiki (GitHub Wiki)

    Context 'docs-wiki: Wiki page links' {

        It 'Should reference an existing wiki page: <SourceRel>:<LineNumber> [[<DisplayText>]]' -ForEach $wikiPageLinks {
            $pageFileName = ($PageName -replace '\s', '-') + '.md'
            # Case-insensitive match against actual wiki files
            $found = $wikiPageFileNames | Where-Object { $_ -ieq $pageFileName }
            $found | Should -Not -BeNullOrEmpty -Because "wiki link '[[${PageName}]]' in ${SourceRel}:${LineNumber} should reference an existing wiki page (expected file: $pageFileName)"
        }
    }

    Context 'docs-wiki: Repo-relative links' {

        It 'Should resolve to an existing repo path: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $wikiRepoLinks {
            $fullPath = Join-Path $repoRoot $RepoPath
            $exists = (Test-Path $fullPath) -or (Test-Path "$fullPath.md")
            $exists | Should -BeTrue -Because "repo-relative link '$RepoPath' in ${SourceRel}:${LineNumber} should point to an existing file or directory"
        }
    }

    Context 'docs-wiki: Internal relative links' {

        It 'Should resolve to an existing file: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $wikiInternalLinks {
            $sourceDir = Split-Path $SourceFile -Parent

            if ([string]::IsNullOrEmpty($PathPart))
            {
                Set-ItResult -Skipped -Because 'anchor-only link'
                return
            }

            $resolvedPath = Join-Path $sourceDir $PathPart | Resolve-Path -ErrorAction SilentlyContinue
            $resolvedPath | Should -Not -BeNullOrEmpty -Because "link target '$PathPart' in ${SourceRel}:${LineNumber} should resolve to an existing file"
        }
    }

    #endregion

    #region Root markdown files

    Context 'Root files: Internal relative links' {

        It 'Should resolve to an existing file: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $rootInternalLinks {
            $sourceDir = Split-Path $SourceFile -Parent

            if ([string]::IsNullOrEmpty($PathPart))
            {
                Set-ItResult -Skipped -Because 'anchor-only link'
                return
            }

            $resolvedPath = Join-Path $sourceDir $PathPart | Resolve-Path -ErrorAction SilentlyContinue
            $resolvedPath | Should -Not -BeNullOrEmpty -Because "link target '$PathPart' in ${SourceRel}:${LineNumber} should resolve to an existing file"
        }
    }

    #endregion
}
