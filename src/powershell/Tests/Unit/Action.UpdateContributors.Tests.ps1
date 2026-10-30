# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'update-contributors GitHub Action' {
    BeforeAll {
        $repoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $workflowPath = Join-Path $repoRoot '.github/workflows/update-contributors.yml'
        $workflowContent = Get-Content -Path $workflowPath -Raw
    }

    It 'Should exist' {
        Test-Path $workflowPath | Should -BeTrue
    }

    It 'Should run weekly and on demand with a since input' {
        $workflowContent | Should -Match 'schedule:\s*\r?\n\s+- cron:'
        $workflowContent | Should -Match 'workflow_dispatch:\s*\r?\n\s+inputs:\s*\r?\n\s+since:'
    }

    It 'Should run on pull requests but never on push or pull_request_target' {
        # pull_request_target would give fork PRs a write token
        $workflowContent | Should -Match 'on:\s*\r?\n\s+pull_request:\s*\r?\n\s+types:\s*\[opened, synchronize, reopened\]'
        $workflowContent | Should -Not -Match '\n\s+(push|pull_request_target):'
    }

    It 'Should only credit same-repo pull requests and skip its own automation branch' {
        $workflowContent | Should -Match 'github\.event\.pull_request\.head\.repo\.full_name == github\.repository'
        $workflowContent | Should -Match "github\.head_ref != 'automation/update-contributors'"
    }

    It 'Should credit the pull request with -PullRequest' {
        $workflowContent | Should -Match 'Update-Contributors\.ps1 -PullRequest \(\[int\]\$env:PR_NUMBER\) -Apply'
        $workflowContent | Should -Match 'PR_NUMBER:\s*\$\{\{\s*github\.event\.pull_request\.number\s*\}\}'
    }

    It 'Should grant no permissions by default and only what each job needs' {
        $workflowContent | Should -Match '(?m)^permissions:\s*\{\}'
        # credit-pr only pushes a commit; update also opens the pull request
        $workflowContent | Should -Match 'credit-pr:[\s\S]*?permissions:\s*\r?\n\s+contents:\s*write\s*\r?\n\s+# '
        $workflowContent | Should -Match 'update:[\s\S]*?permissions:\s*\r?\n\s+contents:\s*write\s*\r?\n\s+pull-requests:\s*write'
    }

    It 'Should set up Node.js 22.22 or later before installing the CLI' {
        $workflowContent | Should -Match "node-version:\s*'22\.22'"
    }

    It 'Should retry the push after rebasing onto the PR branch' {
        $workflowContent | Should -Match 'git pull --rebase origin'
    }

    It 'Should only run the weekly job in the upstream repo, from dev' {
        $workflowContent | Should -Match "if:\s*github\.repository == 'microsoft/finops-toolkit' && github\.ref == 'refs/heads/dev'"
    }

    It 'Should pin every action to a full commit SHA' {
        $uses = [regex]::Matches($workflowContent, '(?m)^\s*(?:-\s*)?uses:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value }
        $uses | Should -Not -BeNullOrEmpty
        foreach ($u in $uses) { $u | Should -Match '@[0-9a-f]{40}$' }
    }

    It 'Should install only the declared dev dependencies without running install scripts' {
        $workflowContent | Should -Match 'npm ci --ignore-scripts'
    }

    It 'Should run the script in apply mode' {
        $workflowContent | Should -Match 'Update-Contributors\.ps1 -Since \$since -Apply'
    }

    It 'Should not put workflow inputs directly in a script' {
        # Inputs reach scripts through env vars so they can't inject commands
        # (single-line values and | or > blocks)
        $runs = [regex]::Matches($workflowContent, '(?m)^( *)(?:- )?run:[ \t]*(?:[|>][-+]?[ \t]*\r?\n((?:\1 +.*\r?\n|[ \t]*\r?\n)+)|(.*))') |
            ForEach-Object { $_.Groups[2].Value + $_.Groups[3].Value }
        $runs | Should -Not -BeNullOrEmpty
        foreach ($run in $runs) { $run | Should -Not -Match '\$\{\{' }
        $workflowContent | Should -Match 'SINCE_INPUT:\s*\$\{\{\s*inputs\.since\s*\}\}'
    }

    It 'Should push a fixed automation branch and open or update a PR to dev' {
        $workflowContent | Should -Match 'BRANCH:\s*automation/update-contributors'
        $workflowContent | Should -Match 'gh pr create --base dev'
        $workflowContent | Should -Match 'gh pr edit'
    }

    It 'Should only stage the contributor files' {
        $workflowContent | Should -Match 'git add \.all-contributorsrc README\.md docs/README\.md'
    }
}
