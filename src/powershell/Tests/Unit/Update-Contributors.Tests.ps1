# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Update-Contributors' {
    BeforeAll {
        # Update-Contributors.ps1 has top-level script logic that calls GitHub, so load only its functions via
        # the PowerShell AST. They are pure (no gh calls) except the ones under "GitHub access", which are not
        # exercised here.
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName 'scripts/Update-Contributors.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
        if (-not $functions) { throw "No functions found in $scriptPath" }
        foreach ($function in $functions) { . ([scriptblock]::Create($function.Extent.Text)) }

        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $configText = Get-Content -Path (Join-Path $repoRoot '.all-contributorsrc') -Raw

        # Simulates the prettier pass in all-contributors-cli, which puts arrays of strings on one line
        function ConvertTo-CollapsedArray([string]$Text)
        {
            [regex]::Replace($Text, '\[\s*\r?\n((?:\s*"[^"]*",?\s*\r?\n)+)\s*\]', {
                    param($m)
                    $items = [regex]::Matches($m.Groups[1].Value, '"[^"]*"') | ForEach-Object { $_.Value }
                    '[' + ($items -join ', ') + ']'
                })
        }

        function Join-ConfigLine([string[]]$Lines) { ($Lines -join "`n") + "`n" }
    }

    Context 'Test-BotLogin' {
        It 'Skips <login>' -ForEach @(
            @{ login = 'app/dependabot' }
            @{ login = 'app/copilot-swe-agent' }
            @{ login = 'dependabot[bot]' }
            @{ login = 'copilot-pull-request-reviewer[bot]' }
            @{ login = 'github-actions' }
            @{ login = 'allcontributors' }
            @{ login = 'allcontributors[bot]' }
            @{ login = 'OssSecurityBot' }
            @{ login = 'Copilot' }
            @{ login = 'some-new-app[bot]' }
            @{ login = '' }
        ) {
            Test-BotLogin -Login $login | Should -BeTrue
        }

        It 'Skips accounts flagged as bots even when the name looks human' {
            Test-BotLogin -Login 'someone' -IsBot $true | Should -BeTrue
        }

        It 'Keeps <login>' -ForEach @(
            @{ login = 'flanakin' }
            @{ login = 'MSBrett' }
            @{ login = 'RolandKrummenacher' }
            @{ login = 'robot-fan' }
            @{ login = 'apple' }
        ) {
            Test-BotLogin -Login $login -IsBot $false | Should -BeFalse
        }
    }

    Context 'Get-FileContributionType' {
        It 'Returns code for files outside the docs paths' {
            Get-FileContributionType -Path 'src/templates/finops-hub/main.bicep', 'src/powershell/Public/Get-FinOpsHub.ps1' | Should -Be @('code')
        }

        It 'Returns doc for <path>' -ForEach @(
            @{ path = 'docs-mslearn/toolkit/hubs/overview.md' }
            @{ path = 'docs-wiki/Home.md' }
            @{ path = 'docs/_layouts/default.html' }
            @{ path = 'README.md' }
            @{ path = 'src/templates/finops-hub/README.md' }
        ) {
            Get-FileContributionType -Path $path | Should -Be @('doc')
        }

        It 'Returns both code and doc, code first, when a PR touches both' {
            Get-FileContributionType -Path 'docs-mslearn/toolkit/hubs/overview.md', 'src/scripts/Build-Toolkit.ps1' | Should -Be @('code', 'doc')
        }

        It 'Accepts Windows path separators and leading slashes' {
            Get-FileContributionType -Path 'docs-wiki\Home.md', '/docs/index.md' | Should -Be @('doc')
        }

        It 'Ignores changelog entries, which almost every code PR has' {
            Get-FileContributionType -Path 'docs-mslearn/toolkit/changelog.md', 'src/templates/finops-hub/main.bicep' | Should -Be @('code')
            Get-FileContributionType -Path 'docs-mslearn/toolkit/changelog.md' | Should -BeNullOrEmpty
        }

        It 'Ignores the contributor list itself' {
            Get-FileContributionType -Path '.all-contributorsrc' | Should -BeNullOrEmpty
        }

        It 'Returns nothing for no files' {
            Get-FileContributionType -Path @() | Should -BeNullOrEmpty
        }
    }

    Context 'Get-IssueContributionType' {
        It 'Maps Type: Bug to bug and Type: Feature to ideas' {
            Get-IssueContributionType -Label 'Type: Bug 🐛', 'Tool: FinOps hubs' | Should -Be @('bug')
            Get-IssueContributionType -Label 'Type: Feature 💎' | Should -Be @('ideas')
        }

        It 'Returns nothing for other labels' {
            Get-IssueContributionType -Label 'Type: Cleanup', 'Type: Documentation 📃' | Should -BeNullOrEmpty
            Get-IssueContributionType -Label @() | Should -BeNullOrEmpty
        }
    }

    Context 'Test-IssueCredit' {
        It 'Credits issues closed as completed' {
            Test-IssueCredit -Label 'Type: Bug 🐛' -StateReason 'COMPLETED' | Should -BeTrue
        }

        It 'Credits open issues that are in a milestone' {
            Test-IssueCredit -Label 'Type: Bug 🐛' -StateReason '' -HasMilestone $true | Should -BeTrue
        }

        It 'Does not credit open, unplanned issues' {
            Test-IssueCredit -Label 'Type: Bug 🐛', 'Needs: Attention 👋' -StateReason '' | Should -BeFalse
        }

        It 'Does not credit issues closed as <reason>' -ForEach @(
            @{ reason = 'NOT_PLANNED' }
            @{ reason = 'DUPLICATE' }
        ) {
            Test-IssueCredit -Label 'Type: Bug 🐛' -StateReason $reason -HasMilestone $true | Should -BeFalse
        }

        It 'Does not credit issues labeled <label>, even when completed' -ForEach @(
            @{ label = 'Resolution: Duplicate' }
            @{ label = "Resolution: Won't fix" }
            @{ label = 'Resolution: External' }
            @{ label = 'Resolution: No activity' }
        ) {
            Test-IssueCredit -Label 'Type: Bug 🐛', $label -StateReason 'COMPLETED' | Should -BeFalse
        }
    }

    Context 'Add-ContributionNeed' {
        It 'Dedupes logins case-insensitively and merges types' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'MSBrett' -Type 'code' -Evidence 'PR #1'
            Add-ContributionNeed -Needs $needs -Login 'msbrett' -Type 'code', 'review' -Evidence 'PR #2'
            Add-ContributionNeed -Needs $needs -Login 'MSBRETT' -Type 'Code' -Evidence 'PR #1'

            $needs.Count | Should -Be 1
            $needs['msbrett'].Login | Should -Be 'MSBrett'
            @($needs['msbrett'].Types | Sort-Object) | Should -Be @('code', 'review')
            $needs['msbrett'].Evidence['code'] | Should -Be @('PR #1', 'PR #2')
            $needs['msbrett'].Evidence['review'] | Should -Be @('PR #2')
        }
    }

    Context 'Get-MissingContribution' {
        BeforeAll {
            $contributors = @(
                [pscustomobject]@{ login = 'MSBrett'; contributions = @('leader', 'code', 'doc', 'review') }
                [pscustomobject]@{ login = 'flanakin'; contributions = @('code') }
            )
        }

        It 'Finds only the types that are missing, matching logins case-insensitively' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'msbrett' -Type 'code', 'doc', 'bug' -Evidence 'issue #9'
            $missing = @(Get-MissingContribution -Needs $needs -Contributor $contributors)

            $missing.Count | Should -Be 1
            $missing[0].Login | Should -Be 'MSBrett'   # config casing, so the CLI updates the existing entry
            $missing[0].Missing | Should -Be @('bug')
            $missing[0].IsNew | Should -BeFalse
        }

        It 'Reports nothing when everyone is already credited' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'MSBrett' -Type 'code', 'review'
            Add-ContributionNeed -Needs $needs -Login 'FLANAKIN' -Type 'code'
            @(Get-MissingContribution -Needs $needs -Contributor $contributors) | Should -BeNullOrEmpty
        }

        It 'Reports new people with every type, ordered code, doc, bug, ideas, review' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'newperson' -Type 'review', 'ideas', 'doc', 'bug', 'code'
            $missing = @(Get-MissingContribution -Needs $needs -Contributor $contributors)

            $missing[0].IsNew | Should -BeTrue
            $missing[0].Missing | Should -Be @('code', 'doc', 'bug', 'ideas', 'review')
        }

        It 'Treats maintainers like everyone else' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'flanakin' -Type 'doc'
            @(Get-MissingContribution -Needs $needs -Contributor $contributors)[0].Missing | Should -Be @('doc')
        }

        It 'Cites evidence only for the missing types' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'flanakin' -Type 'code' -Evidence 'PR #1'
            Add-ContributionNeed -Needs $needs -Login 'flanakin' -Type 'bug' -Evidence 'issue #2'
            @(Get-MissingContribution -Needs $needs -Contributor $contributors)[0].Evidence | Should -Be @('issue #2')
        }

        It 'Skips excluded logins' {
            $needs = @{}
            Add-ContributionNeed -Needs $needs -Login 'newperson' -Type 'code'
            @(Get-MissingContribution -Needs $needs -Contributor $contributors -Exclude 'NewPerson') | Should -BeNullOrEmpty
        }
    }

    Context 'Expand-JsonInlineArray' {
        It 'Puts each item on its own line using the indentation of the line' {
            $text = Join-ConfigLine '{', '  "contributors": [', '    {', '      "login": "a",', '      "contributions": ["code", "bug"]', '    }', '  ]', '}'
            $expected = Join-ConfigLine '{', '  "contributors": [', '    {', '      "login": "a",', '      "contributions": [', '        "code",', '        "bug"', '      ]', '    }', '  ]', '}'
            Expand-JsonInlineArray -Text $text | Should -Be $expected
        }

        It 'Keeps the trailing comma and handles a single item' {
            Expand-JsonInlineArray -Text '  "files": ["README.md"],' | Should -Be ('  "files": [', '    "README.md"', '  ],' -join "`n")
        }

        It 'Keeps items verbatim, including commas and escapes inside strings' {
            Expand-JsonInlineArray -Text '"a": ["x, y", "q\"r"]' | Should -Be ('"a": [', '  "x, y",', '  "q\"r"', ']' -join "`n")
        }

        It 'Leaves empty arrays, nested arrays, and already expanded arrays alone' {
            $text = ('"a": [],', '"b": [[1, 2]],', '"c": [', '  "x"', ']' -join "`n")
            Expand-JsonInlineArray -Text $text | Should -Be $text
        }

        It 'Is idempotent' {
            $once = Expand-JsonInlineArray -Text ('{', '  "a": 1,', '  "b": ["x", "y"]', '}' -join "`n")
            Expand-JsonInlineArray -Text $once | Should -Be $once
        }

        It 'Converts CRLF input to LF' {
            Expand-JsonInlineArray -Text "{`r`n  `"a`": [`"x`"]`r`n}" | Should -Be ('{', '  "a": [', '    "x"', '  ]', '}' -join "`n")
        }

        It 'Restores the committed .all-contributorsrc after the prettier collapse' {
            $collapsed = ConvertTo-CollapsedArray $configText
            $collapsed.Split("`n").Count | Should -BeLessThan ($configText.Split("`n").Count - 100)   # sanity check that it collapsed
            $expanded = Expand-JsonInlineArray -Text $collapsed.TrimEnd()
            $expanded | Should -Be (($configText -replace '\r\n', "`n").TrimEnd())
        }
    }

    Context 'ConvertTo-LineEnding' {
        It 'Converts to CRLF' { ConvertTo-LineEnding -Text "a`nb`r`nc" -Crlf $true | Should -Be "a`r`nb`r`nc" }
        It 'Converts to LF' { ConvertTo-LineEnding -Text "a`r`nb`nc" -Crlf $false | Should -Be "a`nb`nc" }
    }

    Context 'Test-ContributorConfigChange' {
        BeforeAll {
            $before = Expand-JsonInlineArray -Text (@(
                    '{'
                    '  "files": ["README.md"],'
                    '  "contributors": ['
                    '    {'
                    '      "login": "a",'
                    '      "name": "A",'
                    '      "contributions": ["code"]'
                    '    },'
                    '    {'
                    '      "login": "b",'
                    '      "name": "B",'
                    '      "contributions": ["doc"]'
                    '    }'
                    '  ],'
                    '  "contributorsPerLine": 6'
                    '}'
                ) -join "`n")
        }

        It 'Accepts a new credit and a new contributor' {
            $after = $before -replace '"doc"', "`"doc`",`n        `"bug`""
            $after = $after -replace '(?s)\}\n  \],', "},`n    {`n      `"login`": `"c`",`n      `"name`": `"C`",`n      `"contributions`": [`n        `"code`"`n      ]`n    }`n  ],"
            $result = Test-ContributorConfigChange -Before $before -After $after
            $result.Ok | Should -BeTrue -Because $result.Reason
            $result.Removed | Should -BeLessOrEqual 2
        }

        It 'Rejects a file that prettier collapsed' {
            $result = Test-ContributorConfigChange -Before $before -After (ConvertTo-CollapsedArray $before)
            $result.Ok | Should -BeFalse
            $result.Reason | Should -Match 'reformatted'
        }

        It 'Rejects removed credits' {
            $result = Test-ContributorConfigChange -Before $before -After ($before -replace '"doc"', '"bug"')
            $result.Ok | Should -BeFalse
            $result.Reason | Should -Match 'removed'
        }

        It 'Rejects reordered contributors' {
            $after = $before -replace '"login": "a"', '"login": "x"' -replace '"login": "b"', '"login": "a"' -replace '"login": "x"', '"login": "b"'
            (Test-ContributorConfigChange -Before $before -After $after).Ok | Should -BeFalse
        }

        It 'Rejects changed settings' {
            (Test-ContributorConfigChange -Before $before -After ($before -replace '"contributorsPerLine": 6', '"contributorsPerLine": 7')).Ok | Should -BeFalse
        }

        It 'Rejects invalid JSON' {
            (Test-ContributorConfigChange -Before $before -After '{ nope').Ok | Should -BeFalse
        }
    }

    Context 'Format-MissingContributionMarkdown' {
        It 'Says so when nothing is missing' {
            Format-MissingContributionMarkdown -Missing @() | Should -Be 'No missing contributor credits.'
        }

        It 'Lists credits with links to the evidence' {
            $missing = [pscustomobject]@{ Login = 'newperson'; Missing = @('code', 'bug'); IsNew = $true; Evidence = @('PR #12', 'issue #34') }
            $markdown = Format-MissingContributionMarkdown -Missing $missing -Repository 'microsoft/finops-toolkit'
            $markdown | Should -Match '\[@newperson\]\(https://github.com/newperson\) \| code, bug \| New'
            $markdown | Should -Match '\[#12\]\(https://github.com/microsoft/finops-toolkit/issues/12\), \[#34\]'
        }

        It 'Lists issue authors that need a human to pick a type' {
            $human = [pscustomobject]@{ Login = 'reporter'; Evidence = @('issue #5') }
            $markdown = Format-MissingContributionMarkdown -Missing @() -NeedsHuman $human
            $markdown | Should -Match 'human needs to choose a type'
            $markdown | Should -Match '\[@reporter\]'
        }
    }
}
