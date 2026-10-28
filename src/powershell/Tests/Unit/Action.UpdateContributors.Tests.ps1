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

    It 'Should not run on push or pull_request events' {
        $workflowContent | Should -Not -Match '\n\s+(push|pull_request|pull_request_target):'
    }

    It 'Should use only the minimal permissions' {
        $workflowContent | Should -Match 'permissions:\s*\r?\n\s+contents:\s*write\s*\r?\n\s+pull-requests:\s*write\s*\r?\n\r?\n'
    }

    It 'Should only run in the upstream repo, from dev' {
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
        $workflowContent | Should -Not -Match 'run:[^\n]*\$\{\{\s*(inputs|github\.event)\.'
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
