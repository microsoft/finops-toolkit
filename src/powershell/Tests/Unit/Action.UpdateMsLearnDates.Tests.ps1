# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'update-mslearn-dates GitHub Action' {
    BeforeAll {
        $workflowPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName '.github/workflows/update-mslearn-dates.yml'
        $workflowContent = Get-Content -Path $workflowPath -Raw
    }

    Context 'Workflow file structure' {
        It 'Should exist' {
            Test-Path $workflowPath | Should -BeTrue
        }

        It 'Should have a name' {
            $workflowContent | Should -Match '^name:\s*.+'
        }
    }

    Context 'Trigger configuration' {
        It 'Should trigger on pull_request' {
            $workflowContent | Should -Match 'on:\s*\r?\n\s+pull_request:'
        }

        It 'Should only trigger for docs-mslearn markdown files' {
            $workflowContent | Should -Match "paths:\s*\r?\n\s+- 'docs-mslearn/\*\*/\*\.md'"
        }

        It 'Should not trigger on push events' {
            # Ensure there's no 'push:' trigger at the top level
            $workflowContent | Should -Not -Match 'on:\s*\r?\n\s+push:'
        }
    }

    Context 'Permissions' {
        It 'Should have contents write permission' {
            $workflowContent | Should -Match 'contents:\s*write'
        }

        It 'Should have pull-requests write permission' {
            $workflowContent | Should -Match 'pull-requests:\s*write'
        }
    }

    Context 'Job configuration' {
        It 'Should have update-dates job' {
            $workflowContent | Should -Match 'jobs:\s*\r?\n\s+update-dates:'
        }

        It 'Should run on ubuntu-latest' {
            $workflowContent | Should -Match 'runs-on:\s*ubuntu-latest'
        }

        It 'Should have fork protection condition' {
            $workflowContent | Should -Match 'if:\s*github\.event\.pull_request\.head\.repo\.full_name\s*==\s*github\.repository'
        }
    }

    Context 'Workflow steps' {
        It 'Should checkout the PR branch' {
            $workflowContent | Should -Match 'uses:\s*actions/checkout@v\d+'
            $workflowContent | Should -Match 'ref:\s*\$\{\{\s*github\.head_ref\s*\}\}'
        }

        It 'Should use changed-files action' {
            $workflowContent | Should -Match 'uses:\s*tj-actions/changed-files@v\d+'
        }

        It 'Should filter changed-files to docs-mslearn markdown' {
            $workflowContent | Should -Match "files:\s*'docs-mslearn/\*\*/\*\.md'"
        }

        It 'Should have step to update ms.date' {
            $workflowContent | Should -Match 'name:\s*Update ms\.date'
        }

        It 'Should use correct date format (MM/DD/YYYY)' {
            $workflowContent | Should -Match "date \+'%m/%d/%Y'"
        }

        It 'Should use sed to replace ms.date line' {
            $workflowContent | Should -Match 'sed -i'
            $workflowContent | Should -Match 's/\^ms\\\.date:'
        }

        It 'Should have step to check for changes before committing' {
            $workflowContent | Should -Match 'name:\s*Check for changes'
            $workflowContent | Should -Match 'git diff --quiet'
        }

        It 'Should have step to commit and push' {
            $workflowContent | Should -Match 'name:\s*Commit and push'
        }

        It 'Should only commit when there are changes' {
            $workflowContent | Should -Match "if:\s*steps\.check-changes\.outputs\.has_changes\s*==\s*'true'"
        }

        It 'Should use github-actions bot for commits' {
            $workflowContent | Should -Match 'github-actions\[bot\]@users\.noreply\.github\.com'
            $workflowContent | Should -Match 'user\.name.*github-actions\[bot\]'
        }

        It 'Should use conventional commit format' {
            $workflowContent | Should -Match 'git commit -m.*chore:'
        }
    }

    Context 'Sed command validation' {
        It 'Should have correct sed regex to match ms.date at line start' {
            # The sed command should use ^ to anchor to start of line
            $workflowContent | Should -Match 's/\^ms\\\.date:\.\*\$/ms\.date:'
        }

        It 'Should replace entire ms.date line' {
            # Pattern should end with .* to match rest of line
            $workflowContent | Should -Match 'ms\\\.date:\.\*\$'
        }
    }

    Context 'Security considerations' {
        It 'Should use GITHUB_TOKEN for checkout' {
            $workflowContent | Should -Match 'token:\s*\$\{\{\s*secrets\.GITHUB_TOKEN\s*\}\}'
        }

        It 'Should only add docs-mslearn files to commit' {
            $workflowContent | Should -Match 'git add docs-mslearn/'
        }
    }
}
