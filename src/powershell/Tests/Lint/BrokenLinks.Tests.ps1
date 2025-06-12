# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeDiscovery {
    $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent).FullName
    
    # Define test groups
    $docsFiles = Get-ChildItem -Path "$rootPath/docs" -Recurse -Include '*.md' -ErrorAction SilentlyContinue
    $docsMslearnFiles = Get-ChildItem -Path "$rootPath/docs-mslearn" -Recurse -Include '*.md' -ErrorAction SilentlyContinue
    $docsWikiFiles = Get-ChildItem -Path "$rootPath/docs-wiki" -Recurse -Include '*.md' -ErrorAction SilentlyContinue
    
    # Get other repo markdown files (excluding the above folders)
    $otherMarkdownFiles = Get-ChildItem -Path $rootPath -Recurse -Include '*.md' -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.FullName -notmatch [regex]::Escape("$rootPath/docs/") -and
            $_.FullName -notmatch [regex]::Escape("$rootPath/docs-mslearn/") -and
            $_.FullName -notmatch [regex]::Escape("$rootPath/docs-wiki/") -and
            $_.FullName -notmatch [regex]::Escape("$rootPath/.git/") -and
            $_.FullName -notmatch [regex]::Escape("$rootPath/node_modules/")
        }
}

Describe 'Broken Links - docs folder [<_>]' -Tag 'BrokenLinks', 'Docs' -ForEach $docsFiles.FullName {
    BeforeAll {
        $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent).FullName
        $file = $_
        
        function Get-MarkdownLinks {
            param([string]$FilePath)
            
            $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return @() }
            
            # Find markdown links [text](url) and reference links [text]: url
            $linkPattern = '\[([^\]]*)\]\(([^)]+)\)'
            $refLinkPattern = '^\s*\[([^\]]+)\]:\s*(.+)$'
            
            $links = @()
            
            # Extract inline links
            [regex]::Matches($content, $linkPattern) | ForEach-Object {
                $links += @{
                    Text = $_.Groups[1].Value
                    Url = $_.Groups[2].Value.Trim()
                }
            }
            
            # Extract reference links
            $content -split "`n" | ForEach-Object {
                if ($_ -match $refLinkPattern) {
                    $links += @{
                        Text = $matches[1]
                        Url = $matches[2].Trim()
                    }
                }
            }
            
            return $links
        }
        
        function Test-LinkValidity {
            param(
                [string]$FilePath,
                [string]$LinkUrl,
                [string]$FolderType
            )
            
            $relativeFilePath = $FilePath -replace [regex]::Escape($rootPath), ''
            
            # Skip anchors, javascript, and data URLs
            if ($LinkUrl -match '^(#|javascript:|data:|mailto:)') {
                return $true
            }
            
            # Skip Jekyll template variables
            if ($LinkUrl -match '^\{\{.*\}\}$') {
                return $true
            }
            
            # Check for language/locale in URLs (should not exist except for Azure blog)
            if ($LinkUrl -match 'https?://[^/]+/[a-z]{2}-[a-z]{2}/' -and $LinkUrl -notmatch 'azure\.microsoft\.com/blog') {
                Write-Warning "Link contains language/locale: $LinkUrl in $relativeFilePath"
                return $false
            }
            
            switch ($FolderType) {
                'docs' {
                    # docs should use relative links for files in docs, fully qualified for others
                    # Also allow root-relative links for Microsoft Learn content and Jekyll template variables
                    if ($LinkUrl -match '^\.\.?/') {
                        # Relative link - check if it points to a file in docs
                        $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                        if ($targetPath -and $targetPath.Path -like "$rootPath/docs/*") {
                            # Valid relative link within docs
                            return Test-Path $targetPath.Path
                        }
                        else {
                            Write-Warning "Relative link pointing outside docs folder: $LinkUrl in $relativeFilePath"
                            return $false
                        }
                    }
                    elseif ($LinkUrl -match '^/') {
                        # Root-relative link - allow for Microsoft Learn content
                        return $true
                    }
                    elseif ($LinkUrl -match '^https?://') {
                        # Fully qualified link - this is expected for external content
                        return $true
                    }
                    else {
                        Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                'docs-mslearn' {
                    # docs-mslearn should use folder-relative for same folder, root-relative for learn.microsoft.com, fully qualified for others
                    if ($LinkUrl -match '^\.\.?/') {
                        # Relative link - check if it points to a file in docs-mslearn
                        $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                        if ($targetPath -and $targetPath.Path -like "$rootPath/docs-mslearn/*") {
                            return Test-Path $targetPath.Path
                        }
                        else {
                            Write-Warning "Relative link pointing outside docs-mslearn folder: $LinkUrl in $relativeFilePath"
                            return $false
                        }
                    }
                    elseif ($LinkUrl -match '^/') {
                        # Root-relative link - should be for learn.microsoft.com content
                        return $true
                    }
                    elseif ($LinkUrl -match '^https://learn\.microsoft\.com/') {
                        Write-Warning "Should use root-relative link instead of https://learn.microsoft.com/: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                    elseif ($LinkUrl -match '^https?://') {
                        # Fully qualified link for external content
                        return $true
                    }
                    else {
                        Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                'docs-wiki' {
                    # docs-wiki should use relative links for files in docs-wiki, fully qualified for others
                    if ($LinkUrl -match '^\.\.?/') {
                        # Relative link - check if it points to a file in docs-wiki
                        $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                        if ($targetPath -and $targetPath.Path -like "$rootPath/docs-wiki/*") {
                            return Test-Path $targetPath.Path
                        }
                        else {
                            Write-Warning "Relative link pointing outside docs-wiki folder: $LinkUrl in $relativeFilePath"
                            return $false
                        }
                    }
                    elseif ($LinkUrl -match '^https?://') {
                        # Fully qualified link for external content
                        return $true
                    }
                    else {
                        Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                'other' {
                    # Other markdown files should use relative for repo files, fully qualified for external
                    if ($LinkUrl -match '^\.\.?/') {
                        # Relative link - check if it points to a file in the repo
                        $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                        if ($targetPath -and $targetPath.Path -like "$rootPath/*") {
                            return Test-Path $targetPath.Path
                        }
                        else {
                            Write-Warning "Relative link pointing outside repository: $LinkUrl in $relativeFilePath"
                            return $false
                        }
                    }
                    elseif ($LinkUrl -match '^https?://') {
                        # Fully qualified link for external content
                        return $true
                    }
                    else {
                        Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
            }
            
            return $false
        }
    }
    
    It 'Should have valid links' {
        $links = Get-MarkdownLinks -FilePath $file
        
        $invalidLinks = @()
        foreach ($link in $links) {
            if (-not (Test-LinkValidity -FilePath $file -LinkUrl $link.Url -FolderType 'docs')) {
                $invalidLinks += "[$($link.Text)]($($link.Url))"
            }
        }
        
        $invalidLinks | Should -BeNullOrEmpty -Because "All links should be valid in $($file -replace [regex]::Escape($rootPath), '')"
    }
}

Describe 'Broken Links - docs-mslearn folder [<_>]' -Tag 'BrokenLinks', 'DocsMslearn' -ForEach $docsMslearnFiles.FullName {
    BeforeAll {
        $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent).FullName
        $file = $_
        
        function Get-MarkdownLinks {
            param([string]$FilePath)
            
            $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return @() }
            
            $linkPattern = '\[([^\]]*)\]\(([^)]+)\)'
            $refLinkPattern = '^\s*\[([^\]]+)\]:\s*(.+)$'
            
            $links = @()
            
            [regex]::Matches($content, $linkPattern) | ForEach-Object {
                $links += @{
                    Text = $_.Groups[1].Value
                    Url = $_.Groups[2].Value.Trim()
                }
            }
            
            $content -split "`n" | ForEach-Object {
                if ($_ -match $refLinkPattern) {
                    $links += @{
                        Text = $matches[1]
                        Url = $matches[2].Trim()
                    }
                }
            }
            
            return $links
        }
        
        function Test-LinkValidity {
            param([string]$FilePath, [string]$LinkUrl, [string]$FolderType)
            
            $relativeFilePath = $FilePath -replace [regex]::Escape($rootPath), ''
            
            if ($LinkUrl -match '^(#|javascript:|data:|mailto:)') {
                return $true
            }
            
            # Skip Jekyll template variables
            if ($LinkUrl -match '^\{\{.*\}\}$') {
                return $true
            }
            
            if ($LinkUrl -match 'https?://[^/]+/[a-z]{2}-[a-z]{2}/' -and $LinkUrl -notmatch 'azure\.microsoft\.com/blog') {
                Write-Warning "Link contains language/locale: $LinkUrl in $relativeFilePath"
                return $false
            }
            
            if ($FolderType -eq 'docs-mslearn') {
                if ($LinkUrl -match '^\.\.?/') {
                    $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                    if ($targetPath -and $targetPath.Path -like "$rootPath/docs-mslearn/*") {
                        return Test-Path $targetPath.Path
                    }
                    else {
                        Write-Warning "Relative link pointing outside docs-mslearn folder: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                elseif ($LinkUrl -match '^/') {
                    return $true
                }
                elseif ($LinkUrl -match '^https://learn\.microsoft\.com/') {
                    Write-Warning "Should use root-relative link instead of https://learn.microsoft.com/: $LinkUrl in $relativeFilePath"
                    return $false
                }
                elseif ($LinkUrl -match '^https?://') {
                    return $true
                }
                else {
                    Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                    return $false
                }
            }
            
            return $false
        }
    }
    
    It 'Should have valid links' {
        $links = Get-MarkdownLinks -FilePath $file
        
        $invalidLinks = @()
        foreach ($link in $links) {
            if (-not (Test-LinkValidity -FilePath $file -LinkUrl $link.Url -FolderType 'docs-mslearn')) {
                $invalidLinks += "[$($link.Text)]($($link.Url))"
            }
        }
        
        $invalidLinks | Should -BeNullOrEmpty -Because "All links should be valid in $($file -replace [regex]::Escape($rootPath), '')"
    }
}

Describe 'Broken Links - docs-wiki folder [<_>]' -Tag 'BrokenLinks', 'DocsWiki' -ForEach $docsWikiFiles.FullName {
    BeforeAll {
        $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent).FullName
        $file = $_
        
        function Get-MarkdownLinks {
            param([string]$FilePath)
            
            $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return @() }
            
            $linkPattern = '\[([^\]]*)\]\(([^)]+)\)'
            $refLinkPattern = '^\s*\[([^\]]+)\]:\s*(.+)$'
            
            $links = @()
            
            [regex]::Matches($content, $linkPattern) | ForEach-Object {
                $links += @{
                    Text = $_.Groups[1].Value
                    Url = $_.Groups[2].Value.Trim()
                }
            }
            
            $content -split "`n" | ForEach-Object {
                if ($_ -match $refLinkPattern) {
                    $links += @{
                        Text = $matches[1]
                        Url = $matches[2].Trim()
                    }
                }
            }
            
            return $links
        }
        
        function Test-LinkValidity {
            param([string]$FilePath, [string]$LinkUrl, [string]$FolderType)
            
            $relativeFilePath = $FilePath -replace [regex]::Escape($rootPath), ''
            
            if ($LinkUrl -match '^(#|javascript:|data:|mailto:)') {
                return $true
            }
            
            # Skip Jekyll template variables
            if ($LinkUrl -match '^\{\{.*\}\}$') {
                return $true
            }
            
            if ($LinkUrl -match 'https?://[^/]+/[a-z]{2}-[a-z]{2}/' -and $LinkUrl -notmatch 'azure\.microsoft\.com/blog') {
                Write-Warning "Link contains language/locale: $LinkUrl in $relativeFilePath"
                return $false
            }
            
            if ($FolderType -eq 'docs-wiki') {
                if ($LinkUrl -match '^\.\.?/') {
                    $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                    if ($targetPath -and $targetPath.Path -like "$rootPath/docs-wiki/*") {
                        return Test-Path $targetPath.Path
                    }
                    else {
                        Write-Warning "Relative link pointing outside docs-wiki folder: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                elseif ($LinkUrl -match '^https?://') {
                    return $true
                }
                else {
                    Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                    return $false
                }
            }
            
            return $false
        }
    }
    
    It 'Should have valid links' {
        $links = Get-MarkdownLinks -FilePath $file
        
        $invalidLinks = @()
        foreach ($link in $links) {
            if (-not (Test-LinkValidity -FilePath $file -LinkUrl $link.Url -FolderType 'docs-wiki')) {
                $invalidLinks += "[$($link.Text)]($($link.Url))"
            }
        }
        
        $invalidLinks | Should -BeNullOrEmpty -Because "All links should be valid in $($file -replace [regex]::Escape($rootPath), '')"
    }
}

Describe 'Broken Links - other repository markdown files [<_>]' -Tag 'BrokenLinks', 'Other' -ForEach $otherMarkdownFiles.FullName {
    BeforeAll {
        $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent).FullName
        $file = $_
        
        function Get-MarkdownLinks {
            param([string]$FilePath)
            
            $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return @() }
            
            $linkPattern = '\[([^\]]*)\]\(([^)]+)\)'
            $refLinkPattern = '^\s*\[([^\]]+)\]:\s*(.+)$'
            
            $links = @()
            
            [regex]::Matches($content, $linkPattern) | ForEach-Object {
                $links += @{
                    Text = $_.Groups[1].Value
                    Url = $_.Groups[2].Value.Trim()
                }
            }
            
            $content -split "`n" | ForEach-Object {
                if ($_ -match $refLinkPattern) {
                    $links += @{
                        Text = $matches[1]
                        Url = $matches[2].Trim()
                    }
                }
            }
            
            return $links
        }
        
        function Test-LinkValidity {
            param([string]$FilePath, [string]$LinkUrl, [string]$FolderType)
            
            $relativeFilePath = $FilePath -replace [regex]::Escape($rootPath), ''
            
            if ($LinkUrl -match '^(#|javascript:|data:|mailto:)') {
                return $true
            }
            
            # Skip Jekyll template variables
            if ($LinkUrl -match '^\{\{.*\}\}$') {
                return $true
            }
            
            if ($LinkUrl -match 'https?://[^/]+/[a-z]{2}-[a-z]{2}/' -and $LinkUrl -notmatch 'azure\.microsoft\.com/blog') {
                Write-Warning "Link contains language/locale: $LinkUrl in $relativeFilePath"
                return $false
            }
            
            if ($FolderType -eq 'other') {
                if ($LinkUrl -match '^\.\.?/') {
                    $targetPath = Resolve-Path -Path (Join-Path (Split-Path $FilePath) $LinkUrl) -ErrorAction SilentlyContinue
                    if ($targetPath -and $targetPath.Path -like "$rootPath/*") {
                        return Test-Path $targetPath.Path
                    }
                    else {
                        Write-Warning "Relative link pointing outside repository: $LinkUrl in $relativeFilePath"
                        return $false
                    }
                }
                elseif ($LinkUrl -match '^https?://') {
                    return $true
                }
                else {
                    Write-Warning "Invalid link format: $LinkUrl in $relativeFilePath"
                    return $false
                }
            }
            
            return $false
        }
    }
    
    It 'Should have valid links' {
        $links = Get-MarkdownLinks -FilePath $file
        
        $invalidLinks = @()
        foreach ($link in $links) {
            if (-not (Test-LinkValidity -FilePath $file -LinkUrl $link.Url -FolderType 'other')) {
                $invalidLinks += "[$($link.Text)]($($link.Url))"
            }
        }
        
        $invalidLinks | Should -BeNullOrEmpty -Because "All links should be valid in $($file -replace [regex]::Escape($rootPath), '')"
    }
}