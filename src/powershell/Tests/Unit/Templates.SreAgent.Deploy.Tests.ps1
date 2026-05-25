# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'SRE Agent deploy template' {
    BeforeAll {
        $script:RepoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $script:DeployScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/deploy.sh'
        $script:PostProvisionScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/post-provision.sh'
        $script:RecipeDir = Join-Path $script:RepoRoot 'src/templates/sre-agent/recipes/finops-hub'
        $script:ScheduledTaskDir = Join-Path $script:RecipeDir 'automations/scheduled-tasks'
        $script:OutputStylePath = Join-Path $script:RepoRoot 'src/templates/claude-plugin/output-styles/ftk-output-style.md'
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
                    Match   = 'subscription'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 --dry-run"
                    Match   = 'resource-group'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-x --dry-run"
                    Match   = 'name'
                }
                @{
                    Command = "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-x -n a --dry-run"
                    Match   = 'location'
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
            $result.Output | Should -Match 'unknown argument'
        }

        It 'shows customer values and not maintainer defaults on happy-path dry-run' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test-customer -n customer-sre-agent -l westus3 --cluster-uri https://example.westus3.kusto.windows.net/Hub --cluster-resource-id /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Kusto/clusters/fake --dry-run"
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'rg-test-customer'
            $result.Output | Should -Match 'customer-sre-agent'
            $result.Output | Should -Match 'westus3'
            $result.Output | Should -Not -Match 'rg-finops-sre-agent|finops-sre-agent|eastus2'
        }

        It 'uses a deterministic default deployment name across dry-runs' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $deployRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sre-agent-deploy-name-" + [guid]::NewGuid().ToString('N'))
            try {
                $command = "SRE_AGENT_DEPLOY_DIR='$deployRoot' bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test-customer -n customer-sre-agent -l westus3 --cluster-uri https://example.westus3.kusto.windows.net/Hub --cluster-resource-id /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Kusto/clusters/fake --dry-run"
                $first = Invoke-BashCommand $command
                $second = Invoke-BashCommand $command

                $first.ExitCode | Should -Be 0
                $second.ExitCode | Should -Be 0
                $firstPath = [regex]::Match($first.Output, 'Parameters:\s+(.+)').Groups[1].Value.Trim()
                $secondPath = [regex]::Match($second.Output, 'Parameters:\s+(.+)').Groups[1].Value.Trim()

                $firstPath | Should -Be $secondPath
                $firstPath | Should -Match 'sre-agent-customer-sre-agent-[a-f0-9]{12}'
            }
            finally {
                Remove-Item -Path $deployRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'routes deploy through the copied starter-lab infra and post-provision path' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $deployContent = Get-Content -Path $script:DeployScript -Raw
            $deployContent | Should -Match 'INFRA_DIR=.*infra'
            $deployContent | Should -Match '\$\{INFRA_DIR\}/main\.bicep'
            $deployContent | Should -Match 'post-provision\.sh'
            $deployContent | Should -Not -Match 'bicep/assemble-agent|apply-extras|hydrate-extensions'

            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/main.bicep') | Should -BeTrue
            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/post-provision.sh') | Should -BeTrue
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
            $result = Invoke-BashCommand "git grep -nE 'connectors\.secrets\.env' -- src/templates/sre-agent/bin src/templates/sre-agent/infra"
            $result.ExitCode | Should -Be 1
        }

        It 'removes the legacy custom bicep deployment surface' {
            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bicep') | Should -BeFalse
            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/hydrate-extensions.sh') | Should -BeFalse
        }

        It 'uses deterministic subscription and resource group identity for support resource names' {
            $mainBicep = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/main.bicep') -Raw
            $resourcesBicep = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/resources.bicep') -Raw

            $mainBicep | Should -Match "agentResourceGroupId = subscriptionResourceId\('Microsoft\.Resources/resourceGroups', resourceGroupName\)"
            $mainBicep | Should -Match 'namingSeed = toLower'
            $mainBicep | Should -Match 'subscription\(\)\.subscriptionId'
            $mainBicep | Should -Match 'agentResourceGroupId'
            $mainBicep | Should -Match 'agentName'

            $resourcesBicep | Should -Match 'param namingSeed string'
            $resourcesBicep | Should -Match 'uniqueSuffix = uniqueString\(namingSeed\)'
            $resourcesBicep | Should -Not -Match 'resourceGroup\(\)\.id|deployment\(\)\.name'
        }

        It 'applies subagents after their local handoff targets' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sre-agent-post-provision-" + [guid]::NewGuid().ToString('N'))
            $binDir = Join-Path $tempRoot 'bin'
            $buildDir = Join-Path $tempRoot 'build'
            $logPath = Join-Path $tempRoot 'srectl.log'
            New-Item -ItemType Directory -Force -Path $binDir, $buildDir | Out-Null

            $fakeSrectl = Join-Path $binDir 'srectl'
            @'
#!/usr/bin/env bash
set -euo pipefail

seen() {
  [[ -f "${SRECTL_LOG:?}" ]] && grep -qx "$1" "$SRECTL_LOG"
}

case "${1:-}" in
  init|doc|skill|scheduledtask)
    exit 0
    ;;
  apply-yaml)
    file=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --file)
          file="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ "$file" == */config/subagents/* ]]; then
      base="$(basename "$file")"
      if [[ "$base" == "finops-practitioner.yaml" ]]; then
        seen "chief-financial-officer.yaml" || exit 17
        seen "ftk-database-query.yaml" || exit 18
        seen "ftk-hubs-agent.yaml" || exit 19
      fi
      echo "$base" >> "$SRECTL_LOG"
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
'@ | Set-Content -Path $fakeSrectl -NoNewline
            & chmod +x $fakeSrectl

            try {
                $command = "PATH='$binDir':`$PATH SRECTL_LOG='$logPath' bash '$script:PostProvisionScript' --endpoint https://example.azuresre.ai --recipe '$script:RecipeDir' --build-dir '$buildDir'"
                $result = Invoke-BashCommand $command
                $result.ExitCode | Should -Be 0

                $order = @(Get-Content -Path $logPath)
                [array]::IndexOf($order, 'chief-financial-officer.yaml') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner.yaml'))
                [array]::IndexOf($order, 'ftk-database-query.yaml') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner.yaml'))
                [array]::IndexOf($order, 'ftk-hubs-agent.yaml') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner.yaml'))
            }
            finally {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'derives expected recipe connectors for verification' {
            $verifyScript = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/verify-agent.sh') -Raw

            $verifyScript | Should -Match 'connectors\.json'
            $verifyScript | Should -Match 'EXPECTED_CONNECTORS'
            $verifyScript | Should -Match 'EXP_CONN_CT=.*EXPECTED_CONNECTORS'
            $verifyScript | Should -Match 'EXP_CONN_NAMES=.*EXPECTED_CONNECTORS'
        }

        It 'uploads the shared FinOps output style as knowledge' {
            $postProvisionScript = Get-Content -Path $script:PostProvisionScript -Raw

            Test-Path $script:OutputStylePath | Should -BeTrue
            $postProvisionScript | Should -Match 'claude-plugin/output-styles/ftk-output-style\.md'
            $postProvisionScript | Should -Match 'upload_knowledge_file'
            $postProvisionScript | Should -Match 'srectl doc upload'
            $postProvisionScript | Should -Match 'output style knowledge document not found'
        }

        It 'requires every scheduled task to apply the shared output style' {
            $taskFiles = @(Get-ChildItem -Path $script:ScheduledTaskDir -Filter '*.yaml')
            $taskFiles.Count | Should -Be 19

            $expectedInstruction = [regex]::Escape('Output style: Apply `ftk-output-style.md`')
            foreach ($file in $taskFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                $content | Should -Match $expectedInstruction
            }
        }

        It 'extends the shared output style for Azure capacity management' {
            $outputStyle = Get-Content -Path $script:OutputStylePath -Raw

            $outputStyle | Should -Match 'Azure capacity management reporting'
            $outputStyle | Should -Match 'Forecast'
            $outputStyle | Should -Match 'Procure'
            $outputStyle | Should -Match 'Allocate'
            $outputStyle | Should -Match 'Monitor'
            $outputStyle | Should -Match 'Capacity reservation group'
            $outputStyle | Should -Match 'Quota group'
            $outputStyle | Should -Match 'Logical zone'
            $outputStyle | Should -Match 'CRG utilization'
        }
    }

    Context 'copy-and-update deployment contract' {
        It 'rejects what-if because the copied starter-lab flow deploys directly' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test -n test-agent -l westus3 --what-if"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'unknown flag'
        }

        It 'documents that azd is not used' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "git grep -nF 'azd' -- src/templates/sre-agent/bin src/templates/sre-agent/infra docs-mslearn/toolkit/sre-agent/deploy.md src/templates/sre-agent/README.md"
            $result.Output | Should -Match 'azd'
            $result.Output | Should -Match 'not used|doesn''t use'
        }
    }
}
