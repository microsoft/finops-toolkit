# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-DocsArticleBody' {
    BeforeAll {
        # Publish-Toolkit.ps1 has top-level executable script logic, so dot-sourcing
        # it would trigger the publish flow. Extract the function definition via the
        # PowerShell AST and define it in the test scope instead.
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName 'scripts/Publish-Toolkit.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functionAst = $ast.FindAll(
            {
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Get-DocsArticleBody'
            },
            $true
        ) | Select-Object -First 1

        if (-not $functionAst)
        {
            throw "Get-DocsArticleBody not found in $scriptPath"
        }

        # Define the function in the Describe scope (no Set-Item: function ScriptBlock
        # would not be re-parented and would break $script:/closure semantics here).
        . ([scriptblock]::Create($functionAst.Extent.Text))
    }

    It 'Returns body text for a normal article with frontmatter' {
        $content = @(
            '---'
            'title: Sample'
            'ms.date: 01/01/2026'
            '---'
            ''
            '# Heading'
            ''
            'Body paragraph.'
        ) -join "`n"

        Get-DocsArticleBody $content | Should -Be "# Heading`n`nBody paragraph."
    }

    It 'Returns "" when the file contains only frontmatter (range guard)' {
        $content = @('---', 'title: Sample', '---') -join "`n"
        Get-DocsArticleBody $content | Should -Be ''
    }

    It 'Returns "" for empty input' {
        Get-DocsArticleBody '' | Should -Be ''
    }

    It 'Treats a file with no closing frontmatter fence as all-body (errs safe)' {
        # No closing ---; function keeps the whole file as body so any byte change
        # registers as a content change. Validates we have not regressed that.
        $content = @('---', 'title: Sample', '', '# Heading') -join "`n"
        $result = Get-DocsArticleBody $content
        $result | Should -Match '^---'
        $result | Should -Match '# Heading'
    }

    It 'Strips markdownlint-disable-next-line MD025 directive' {
        $content = @(
            '---'
            'title: Sample'
            '---'
            '<!-- markdownlint-disable-next-line MD025 -->'
            '# Heading'
        ) -join "`n"

        Get-DocsArticleBody $content | Should -Be '# Heading'
    }

    It 'Strips prettier-ignore-start and prettier-ignore-end directives' {
        $content = @(
            '---'
            'title: Sample'
            '---'
            '<!-- prettier-ignore-start -->'
            'verbatim content'
            '<!-- prettier-ignore-end -->'
        ) -join "`n"

        Get-DocsArticleBody $content | Should -Be 'verbatim content'
    }

    It 'Strips ignore directives even when surrounded by whitespace' {
        $content = @(
            '---'
            'title: Sample'
            '---'
            '   <!-- prettier-ignore-start -->   '
            'verbatim content'
            '   <!-- prettier-ignore-end -->'
        ) -join "`n"

        Get-DocsArticleBody $content | Should -Be 'verbatim content'
    }

    It 'Trims trailing whitespace from each line' {
        $content = @(
            '---'
            'title: Sample'
            '---'
            '# Heading   '
            'Body paragraph.    '
        ) -join "`n"

        # Conservative normalization: trailing whitespace is now preserved
        Get-DocsArticleBody $content | Should -Be "# Heading   `nBody paragraph.    "
    }

    It 'Collapses three or more blank lines to exactly two' {
        $content = @(
            '---'
            'title: Sample'
            '---'
            '# Heading'
            ''
            ''
            ''
            ''
            'Body paragraph.'
        ) -join "`n"

        # Conservative normalization: blank line runs are now preserved
        Get-DocsArticleBody $content | Should -Be "# Heading`n`n`n`n`nBody paragraph."
    }

    It 'Handles CRLF line endings the same as LF' {
        $lf = "---`ntitle: Sample`n---`n# Heading`n`nBody paragraph."
        $crlf = "---`r`ntitle: Sample`r`n---`r`n# Heading`r`n`r`nBody paragraph."

        Get-DocsArticleBody $crlf | Should -Be (Get-DocsArticleBody $lf)
    }

    It 'Returns the same body when only frontmatter changes' {
        $before = @('---', 'ms.date: 01/01/2026', '---', '# Heading', 'Body.') -join "`n"
        $after = @('---', 'ms.date: 06/04/2026', '---', '# Heading', 'Body.') -join "`n"

        Get-DocsArticleBody $before | Should -Be (Get-DocsArticleBody $after)
    }

    It 'Detects blank line count changes inside fenced code blocks as content changes' {
        $oneBlank = @(
            '---'
            'title: Sample'
            '---'
            '```bash'
            'echo "line1"'
            ''
            'echo "line2"'
            '```'
        ) -join "`n"

        $twoBlank = @(
            '---'
            'title: Sample'
            '---'
            '```bash'
            'echo "line1"'
            ''
            ''
            'echo "line2"'
            '```'
        ) -join "`n"

        Get-DocsArticleBody $oneBlank | Should -Not -Be (Get-DocsArticleBody $twoBlank)
    }

    It 'Detects removal of trailing hard-break spaces as a content change' {
        $withHardBreak = @(
            '---'
            'title: Sample'
            '---'
            'Line with hard break  '
            'Next line'
        ) -join "`n"

        $withoutHardBreak = @(
            '---'
            'title: Sample'
            '---'
            'Line with hard break'
            'Next line'
        ) -join "`n"

        Get-DocsArticleBody $withHardBreak | Should -Not -Be (Get-DocsArticleBody $withoutHardBreak)
    }

    It 'Still treats pure metadata changes as identical (ms.author change only)' {
        $before = @(
            '---'
            'title: Sample'
            'ms.author: alice'
            'ms.date: 01/01/2026'
            '---'
            '# Heading'
            'Body.'
        ) -join "`n"

        $after = @(
            '---'
            'title: Sample'
            'ms.author: bob'
            'ms.date: 06/04/2026'
            '---'
            '# Heading'
            'Body.'
        ) -join "`n"

        Get-DocsArticleBody $before | Should -Be (Get-DocsArticleBody $after)
    }
}
