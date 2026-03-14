# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Validates documentation links in the docs-mslearn folder.

    .DESCRIPTION
    Tests that internal markdown links resolve to real files and anchors, that no
    https://learn.microsoft.com links appear (they should be root-relative), and
    that no language locale segments appear in MS Learn links.
#>

BeforeDiscovery {
    $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
    $docsRoot = Join-Path $repoRoot 'docs-mslearn'

    if (-not (Test-Path $docsRoot))
    {
        return
    }

    # Collect all markdown files
    $mdFiles = Get-ChildItem -Path $docsRoot -Recurse -Include '*.md' | ForEach-Object {
        @{
            FullName     = $_.FullName
            RelativePath = $_.FullName.Substring($docsRoot.Length + 1) -replace '\\', '/'
            Content      = Get-Content -Path $_.FullName -Raw
        }
    }

    # Helper: Remove HTML comments from content to avoid matching links inside <!-- ... -->
    function Remove-HtmlComments([string]$text)
    {
        return [regex]::Replace($text, '<!--[\s\S]*?-->', { param($m) "`n" * ($m.Value -split "`n").Count })
    }

    # Extract internal relative links (not starting with http, /, or #-only)
    $internalLinks = @()
    foreach ($file in $mdFiles)
    {
        $cleanContent = Remove-HtmlComments $file.Content
        $linkMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\(([^)]+)\)')
        foreach ($match in $linkMatches)
        {
            $linkTarget = $match.Groups[2].Value

            # Skip external links, absolute paths, anchor-only links, and special schemes
            if ($linkTarget -match '^(https?://|mailto:|/|#)') { continue }

            # Parse out any anchor
            $pathPart = $linkTarget -replace '#.*$', ''
            $anchorPart = if ($linkTarget -match '#(.+)$') { $Matches[1] } else { $null }

            # Skip empty path parts (anchor-only links that somehow got through)
            if ([string]::IsNullOrEmpty($pathPart) -and -not [string]::IsNullOrEmpty($anchorPart)) { continue }

            # Only check .md files
            if ($pathPart -and $pathPart -notmatch '\.md$') { continue }

            $internalLinks += @{
                SourceFile   = $file.FullName
                SourceRel    = $file.RelativePath
                LinkText     = $match.Groups[1].Value
                LinkTarget   = $linkTarget
                PathPart     = $pathPart
                AnchorPart   = $anchorPart
                LineNumber   = ($file.Content.Substring(0, $match.Index) -split "`n").Count
            }
        }
    }

    # Extract all URLs from markdown files (excluding HTML comments)
    $allUrls = @()
    foreach ($file in $mdFiles)
    {
        $cleanContent = Remove-HtmlComments $file.Content
        $urlMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\((https?://[^)]+)\)')
        foreach ($match in $urlMatches)
        {
            $allUrls += @{
                SourceFile   = $file.FullName
                SourceRel    = $file.RelativePath
                LinkText     = $match.Groups[1].Value
                Url          = $match.Groups[2].Value
                LineNumber   = ($file.Content.Substring(0, $match.Index) -split "`n").Count
            }
        }
    }

}

Describe 'Documentation links' {

    Context 'Internal relative links' {

        It 'Should resolve to an existing file: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach $internalLinks {
            $sourceDir = Split-Path $SourceFile -Parent

            if ([string]::IsNullOrEmpty($PathPart))
            {
                # Anchor-only link within the same file — the file exists by definition
                Set-ItResult -Skipped -Because 'anchor-only link'
                return
            }

            $resolvedPath = Join-Path $sourceDir $PathPart | Resolve-Path -ErrorAction SilentlyContinue
            $resolvedPath | Should -Not -BeNullOrEmpty -Because "link target '$PathPart' in ${SourceRel}:${LineNumber} should resolve to an existing file"
        }

        It 'Should have a valid anchor: <SourceRel>:<LineNumber> [<LinkText>](<LinkTarget>)' -ForEach ($internalLinks | Where-Object { $_.AnchorPart }) {
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
                # Convert heading to anchor: lowercase, replace spaces with hyphens, remove special chars
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

    Context 'No learn.microsoft.com URLs in docs-mslearn' {

        It 'Should not contain https://learn.microsoft.com links: <SourceRel>:<LineNumber>' -ForEach ($allUrls | Where-Object { $_.Url -match 'learn\.microsoft\.com' }) {
            $Url | Should -Not -Match 'learn\.microsoft\.com' -Because "links in docs-mslearn should use root-relative paths (e.g., /azure/...) instead of full URLs since docs are deployed to learn.microsoft.com (${SourceRel}:${LineNumber})"
        }
    }

    Context 'No language locale in MS Learn links' {

        It 'Should not contain language locale in URL: <SourceRel>:<LineNumber> <Url>' -ForEach ($allUrls | Where-Object { $_.Url -match 'learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/' }) {
            $Url | Should -Not -Match 'learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/' -Because "MS Learn links should not include language locale segments like /en-us/ (${SourceRel}:${LineNumber})"
        }
    }

}
