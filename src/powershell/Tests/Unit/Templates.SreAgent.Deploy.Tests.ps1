# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'SRE Agent deploy template' {
    BeforeAll {
        $script:RepoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $script:DeployScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/deploy.sh'
        $script:RecipeDir = Join-Path $script:RepoRoot 'src/templates/sre-agent/recipes/finops-hub'
        $script:ReadmePath = Join-Path $script:RepoRoot 'src/templates/sre-agent/README.md'
        $script:DocsPath = Join-Path $script:RepoRoot 'docs-mslearn/toolkit/sre-agent/deploy.md'
        $script:AgentJsonPath = Join-Path $script:RecipeDir 'agent.json'
        $script:SkipBash = -not (Get-Command bash -ErrorAction SilentlyContinue)

        function Invoke-BashCommand {
            param(
                [Parameter(Mandatory)]
                [string] $Command
            )

            Push-Location $script:RepoRoot
            try {
                $output = & bash -lc $Command 2>&1
                [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    Output   = ($output -join "`n")
                }
            }
            finally {
                Pop-Location
            }
        }

        function Invoke-BashCommandWithPath {
            param(
                [Parameter(Mandatory)]
                [string] $Command,

                [Parameter(Mandatory)]
                [string] $PathPrefix
            )

            Push-Location $script:RepoRoot
            try {
                $originalPath = $env:PATH
                $env:PATH = "${PathPrefix}:$originalPath"
                $output = & bash -lc $Command 2>&1
                [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    Output   = ($output -join "`n")
                }
            }
            finally {
                $env:PATH = $originalPath
                Pop-Location
            }
        }
    }

    Context 'bash availability' {
        It 'has bash available for hermetic tests' {
            if ($script:SkipBash) {
                Set-ItResult -Skipped -Because 'bash is unavailable'
            }
            $true | Should -BeTrue
        }
    }

    Context 'help and parsing' {
        It 'prints help with portal labels and required flags' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --help"
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'Resource group'
            $result.Output | Should -Match 'Agent name'
            $result.Output | Should -Match 'Region'
            $result.Output | Should -Match 'Subscription'
            $result.Output | Should -Match '--cluster-uri'
        }

        It 'documents the same help lines in README and docs' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $help = Invoke-BashCommand "bash '$script:DeployScript' --help"
            $help.ExitCode | Should -Be 0
            $readme = Get-Content -Path $script:ReadmePath -Raw
            $docs = Get-Content -Path $script:DocsPath -Raw

            @(
                '--recipe <dir>',
                '--resource-group <name>',
                '--name <name>',
                '--location <region>',
                '--subscription <id>',
                '--cluster-uri <uri>',
                '--cluster-resource-id <id>',
                '--deploy-name <name>',
                '--fallback-srectl'
            ) | ForEach-Object {
                $escaped = [regex]::Escape($_)
                $help.Output | Should -Match $escaped
                $readme | Should -Match $escaped
                $docs | Should -Match $escaped
            }
        }

        It 'errors for each missing required recipe flag' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $cases = @(
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' --dry-run"
                    Match   = 'Resource group'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' -g rg-x --dry-run"
                    Match   = 'Agent name'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' -g rg-x -n a --dry-run"
                    Match   = 'Region'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' -g rg-x -n a -l westus3 --dry-run"
                    Match   = 'cluster-uri'
                }
            )

            foreach ($case in $cases) {
                $result = Invoke-BashCommand $case.Command
                $result.ExitCode | Should -Be 2
                $result.Output | Should -Match $case.Match
            }
        }

        It 'errors on unknown flags' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --recipes '$script:RecipeDir' --dry-run"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'unknown flag'
        }

        It 'errors when a value-taking flag is missing its value' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --recipe '$script:RecipeDir' -g -n foo --dry-run"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'requires a value'
        }

        It 'rejects the positional footgun' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --dry-run rg-test"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match '--recipe <dir> is required'
        }

        It 'shows customer values and not maintainer defaults on happy-path dry-run' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand @"
bash '$script:DeployScript' \
  --recipe '$script:RecipeDir' \
  -g rg-test-customer \
  -n customer-sre-agent \
  -l westus3 \
  --cluster-uri https://example.westus3.kusto.windows.net/hub \
  --dry-run
"@
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'rg-test-customer'
            $result.Output | Should -Match 'customer-sre-agent'
            $result.Output | Should -Match 'westus3'
            $result.Output | Should -Not -Match 'rg-finops-sre-agent|finops-sre-agent|eastus2'
        }
    }

    Context 'repo invariants' {
        It 'removes shipped recipe identity defaults' {
            $agentJson = Get-Content -Path $script:AgentJsonPath -Raw
            $agentJson | Should -Not -Match '"identity"'
        }

        It 'limits legacy config env-var references to the allowlist' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "git grep -nE 'FINOPS_HUB_CLUSTER_URI|FINOPS_HUB_CLUSTER_RESOURCE_ID|SRE_AGENT_NO_TELEMETRY' -- docs-mslearn/toolkit/sre-agent/deploy.md src/templates/sre-agent"
            $result.ExitCode | Should -Be 0

            $paths = $result.Output -split "`n" |
                Where-Object { $_ } |
                ForEach-Object { ($_ -split ':', 2)[0] } |
                Sort-Object -Unique

            $paths | Should -Be @(
                'docs-mslearn/toolkit/sre-agent/deploy.md',
                'src/templates/sre-agent/README.md',
                'src/templates/sre-agent/recipes/finops-hub/connectors.json'
            )
        }

        It 'keeps connectors.secrets.env out of scripts' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "git grep -nE 'connectors\.secrets\.env' -- src/templates/sre-agent/bin src/templates/sre-agent/bicep"
            $result.ExitCode | Should -Be 1
        }

        It 'removes the old generic env resolver' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "git grep -nF 'resolve_env_vars' -- src/templates/sre-agent/bicep/assemble-agent.sh"
            $result.ExitCode | Should -Be 1
        }
    }

    Context 'what-if regressions' {
        It 'returns nonzero when az deployment sub what-if fails' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $shimDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sre-agent-az-shim-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
            try {
                $azShim = @'
#!/usr/bin/env bash
set -eu
if [[ "$1 $2 $3" == "deployment sub what-if" ]]; then
  echo "simulated what-if failure" >&2
  exit 1
fi
if [[ "$1 $2" == "account show" ]]; then
  if [[ "${*: -2}" == "-o tsv" ]]; then
    if printf '%s\n' "$*" | grep -q -- '--query name'; then
      echo "Test Subscription"
    else
      echo "00000000-0000-0000-0000-000000000000"
    fi
    exit 0
  fi
fi
if [[ "$1 $2" == "group exists" ]]; then
  echo "false"
  exit 0
fi
if [[ "$1 $2" == "kusto cluster" ]]; then
  echo "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Kusto/clusters/fake"
  exit 0
fi
echo "unexpected az call: $*" >&2
exit 0
'@
                $azShimPath = Join-Path $shimDir 'az'
                Set-Content -Path $azShimPath -Value $azShim -NoNewline
                & chmod +x $azShimPath

                # Captures the exit code from deploy.sh what-if handling around bin/deploy.sh:566-585.
                $result = Invoke-BashCommandWithPath @"
bash '$script:DeployScript' \
  --recipe '$script:RecipeDir' \
  --subscription 00000000-0000-0000-0000-000000000000 \
  -g rg-test \
  -n test-agent \
  -l westus3 \
  --cluster-uri https://example.westus3.kusto.windows.net/hub \
  --cluster-resource-id /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Kusto/clusters/fake \
  --what-if
"@ $shimDir

                $result.ExitCode | Should -Not -Be 0
                $result.Output | Should -Match 'What-if found errors'
                $result.Output | Should -Match 'simulated what-if failure'
            }
            finally {
                Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'can verify what-if bypasses change detection when a safe shim strategy exists' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            Set-ItResult -Skipped -Because 'deploy.sh invokes diff-agent.sh by absolute repo path; PATH shimming cannot safely intercept it in this harness'
        }
    }
}
