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

        It 'Should only run from dev' {
            $workflowContent | Should -Match "if:\s*github\.ref == 'refs/heads/dev'"
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
    }
}
