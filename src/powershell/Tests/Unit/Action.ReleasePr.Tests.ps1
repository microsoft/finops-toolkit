# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'release-pr GitHub Action' {
    BeforeAll {
        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $workflowPath = Join-Path $repoRoot '.github/workflows/release-pr.yml'
        $scriptPath = Join-Path $repoRoot 'src/scripts/New-ReleasePr.ps1'
        $workflowContent = Get-Content -Path $workflowPath -Raw

        # Strip comments and the PR body here-string so documentation about forbidden operations does not trigger the guards below
        $workflowCode = ($workflowContent -split '\r?\n' | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $scriptCode = ((Get-Content -Path $scriptPath -Raw) -replace '(?s)<#.*?#>', '' -replace '(?s)@"\r?\n.*?\r?\n"@', '' -split '\r?\n' | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
    }

    Context 'Triggers' {
        It 'Should exist' {
            Test-Path $workflowPath | Should -BeTrue
            Test-Path $scriptPath | Should -BeTrue
        }

        It 'Should be manually dispatchable' {
            $workflowContent | Should -Match '(?m)^\s+workflow_dispatch:'
        }

        It 'Should default dry_run to true' {
            $workflowContent | Should -Match '(?s)dry_run:.*?default:\s*true'
        }

        It 'Should treat every non-manual trigger as a dry run' {
            $workflowContent | Should -Match "DRY_RUN:\s*\`$\{\{\s*github\.event_name != 'workflow_dispatch' \|\| inputs\.dry_run\s*\}\}"
        }

        It 'Should fail, not skip, when run from another ref' {
            $workflowContent | Should -Not -Match "(?m)^    if:"
            $workflowContent | Should -Match "(?s)- name: Require dev\s+if: \$\{\{ github\.ref != 'refs/heads/dev' \}\}.*?exit 1"
        }

        It 'Should not persist the write token in git config' {
            $workflowContent | Should -Match 'persist-credentials: false'
        }

        It 'Should not use pull_request_target or push triggers' {
            $workflowCode | Should -Not -Match '(?m)^\s+(pull_request_target|push):'
        }
    }

    Context 'Supply chain' {
        It 'Should pin every action to a full commit SHA' {
            $uses = [regex]::Matches($workflowCode, '(?m)^\s*-?\s*uses:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value }
            $uses | Should -Not -BeNullOrEmpty
            $uses | ForEach-Object { $_ | Should -Match '@[0-9a-f]{40}$' }
        }

        It 'Should not expand untrusted event data in run steps' {
            $workflowCode | Should -Not -Match '\$\{\{\s*github\.(event\.(issue|pull_request|comment)|head_ref)'
        }
    }

    Context 'Safety' {
        It 'Should never merge, rebase, reset, or force-push' {
            foreach ($pattern in 'rebase', 'reset\s+--hard', '--force', '--force-with-lease', 'push\s+-f\b', 'gh\s+pr\s+merge', '--auto\b', 'filter-branch', '--admin')
            {
                $workflowCode | Should -Not -Match $pattern -Because "workflow must not use '$pattern'"
                $scriptCode | Should -Not -Match $pattern -Because "script must not use '$pattern'"
            }
        }

        It 'Should only push the bot prep branch' {
            $pushes = [regex]::Matches($scriptCode, '(?m)^.*\bpush\b.*$') | ForEach-Object { $_.Value }
            $pushes | Should -Not -BeNullOrEmpty
            $pushes | ForEach-Object { $_ | Should -Match '\$state\.Branch' }
        }

        It 'Should use a bot branch name' {
            $scriptCode | Should -Match 'bot/release-'
        }

        It 'Should open PRs as draft unless asked' {
            $scriptCode | Should -Match "if \(-not \`$Ready\) \{ \`$prArgs \+= '--draft' \}"
        }

        It 'Should not push or create anything in dry run' {
            $scriptCode | Should -Match '(?s)if \(\$DryRun\)\s*\{.*?skipping push and PR'
        }

        It 'Should keep live counts out of checklist lines' {
            # Ticked boxes are kept on re-run by matching the line text, so a count in the line would reset the box
            $body = [regex]::Match((Get-Content -Path $scriptPath -Raw), '(?s)\$body = @"\r?\n(.*?)\r?\n"@').Groups[1].Value
            $body | Should -Not -BeNullOrEmpty
            $body -split '\r?\n' | Where-Object { $_ -match '^\s*- \[ \]' } | ForEach-Object { $_ | Should -Not -Match '\.Count' }
        }
    }
}

Describe 'New-ReleasePr merge helpers' {
    BeforeAll {
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName 'src/scripts/New-ReleasePr.ps1'

        # Load the helper functions without running the script
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in 'Invoke-Git', 'Stop-Merge', 'Invoke-Merge', 'Get-MarkdownBody', 'Resolve-MsDateConflicts' }, $false) |
            ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

        function New-ConflictRepo([string]$DevText, [string]$BotText)
        {
            # Creates a repo where dev and bot both changed docs.md from the same base, then merges dev into bot
            $dir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('n'))
            $null = New-Item -ItemType Directory -Path $dir
            Push-Location $dir
            $null = & git init --quiet --initial-branch=bot 2>&1
            $null = & git config user.email 'test@example.com' 2>&1
            $null = & git config user.name 'test' 2>&1
            $null = & git config core.autocrlf false 2>&1
            [System.IO.File]::WriteAllText("$dir/docs.md", "---`ntitle: Test`nms.date: 01/01/2026`n---`n`nBody`n")
            $null = & git add -A 2>&1
            $null = & git commit --quiet -m base 2>&1
            $null = & git checkout --quiet -b dev 2>&1
            [System.IO.File]::WriteAllText("$dir/docs.md", $DevText)
            $null = & git commit --quiet -am dev 2>&1
            $null = & git checkout --quiet bot 2>&1
            [System.IO.File]::WriteAllText("$dir/docs.md", $BotText)
            $null = & git commit --quiet -am bot 2>&1
            $null = & git merge --no-edit dev 2>&1
            Pop-Location
            return $dir
        }
    }

    AfterEach {
        if ($script:dir)
        {
            Pop-Location -ErrorAction SilentlyContinue
            Remove-Item $script:dir -Recurse -Force -ErrorAction SilentlyContinue
            $script:dir = $null
        }
    }

    It 'Should resolve ms.date-only conflicts to today and commit the merge' {
        $script:dir = New-ConflictRepo "---`ntitle: Test`nms.date: 03/03/2026`n---`n`nBody`n" "---`ntitle: Test`nms.date: 02/02/2026`n---`n`nBody v2`n"
        Push-Location $script:dir
        $repoRoot = $script:dir
        Resolve-MsDateConflicts | Should -BeTrue
        $today = (Get-Date).ToString('MM/dd/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
        Get-Content "$script:dir/docs.md" -Raw | Should -Be "---`ntitle: Test`nms.date: $today`n---`n`nBody v2`n"
        Test-Path (Join-Path (& git rev-parse --git-dir) 'MERGE_HEAD') | Should -BeFalse
        @(& git rev-list --parents -n 1 HEAD) -split ' ' | Should -HaveCount 3
    }

    It 'Should leave the merge in progress when a body line also conflicts' {
        $script:dir = New-ConflictRepo "---`ntitle: Test`nms.date: 03/03/2026`n---`n`nBody dev`n" "---`ntitle: Test`nms.date: 02/02/2026`n---`n`nBody bot`n"
        Push-Location $script:dir
        $repoRoot = $script:dir
        Resolve-MsDateConflicts | Should -BeFalse
        Test-Path (Join-Path (& git rev-parse --git-dir) 'MERGE_HEAD') | Should -BeTrue
        Get-Content "$script:dir/docs.md" -Raw | Should -Match '<<<<<<<'
    }

    It 'Should not resolve when one side deleted the ms.date line' {
        $script:dir = New-ConflictRepo "---`ntitle: Test`n---`n`nBody`n" "---`ntitle: Test`nms.date: 02/02/2026`n---`n`nBody`n"
        Push-Location $script:dir
        $repoRoot = $script:dir
        if (@(& git diff --name-only --diff-filter=U).Count -gt 0)
        {
            Resolve-MsDateConflicts | Should -BeFalse
        }
        Get-Content "$script:dir/docs.md" -Raw | Should -Not -Match "ms\.date: $((Get-Date).ToString('MM/dd/yyyy', [System.Globalization.CultureInfo]::InvariantCulture))"
    }

    It 'Should throw the git error when a merge fails without conflicts' {
        $script:dir = New-ConflictRepo "---`ntitle: Test`nms.date: 01/01/2026`n---`n`nBody`n" "---`ntitle: Test`nms.date: 01/01/2026`n---`n`nBody`n"
        Push-Location $script:dir
        { Invoke-Merge --no-edit 'does-not-exist' } | Should -Throw '*does-not-exist*'
    }

    It 'Should return false on conflicts and true on a clean merge' {
        $script:dir = New-ConflictRepo "---`ntitle: Test`nms.date: 01/01/2026`n---`n`nBody dev`n" "---`ntitle: Test`nms.date: 01/01/2026`n---`n`nBody bot`n"
        Push-Location $script:dir
        Stop-Merge
        Invoke-Merge --no-edit dev | Should -BeFalse
        Stop-Merge
        Test-Path (Join-Path (& git rev-parse --git-dir) 'MERGE_HEAD') | Should -BeFalse
        Stop-Merge  # No merge in progress: must not throw
        Invoke-Merge --no-edit bot | Should -BeTrue
    }

    It 'Should ignore front matter when comparing bodies' {
        Get-MarkdownBody "---`nms.date: 01/01/2026`n---`nBody`n" | Should -Be (Get-MarkdownBody "---`nms.date: 02/02/2026`n---`nBody`n")
        Get-MarkdownBody "---`nms.date: 01/01/2026`n---`nBody`n" | Should -Be "Body`n"
    }
}
