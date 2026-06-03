# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'SRE Agent deploy template' {
    BeforeAll {
        $script:RepoRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
        $script:DeployScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/deploy.sh'
        $script:ApplyExtrasScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/apply-extras.sh'
        $script:PostProvisionScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/post-provision.sh'
        $script:VerifyScript = Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/verify-agent.sh'
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
                $bashPathPrefix = ConvertTo-BashPath $PathPrefix
                $quotedPathPrefix = ConvertTo-BashSingleQuoted $bashPathPrefix
                $output = & bash -c "PATH=${quotedPathPrefix}:`$PATH $Command" 2>&1
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

        function ConvertTo-BashPath {
            param(
                [Parameter(Mandatory)]
                [string] $Path
            )

            $quotedPath = ConvertTo-BashSingleQuoted $Path
            $converted = & bash -lc "command -v cygpath >/dev/null 2>&1 && cygpath -u $quotedPath" 2>$null
            if ($LASTEXITCODE -eq 0 -and $converted) {
                return ($converted -join '')
            }

            return $Path
        }

        function ConvertTo-BashSingleQuoted {
            param(
                [Parameter(Mandatory)]
                [string] $Value
            )

            return "'" + ($Value -replace "'", "'\''") + "'"
        }

        function Set-BashStub {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [Parameter(Mandatory)]
                [string] $Content
            )

            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($Path, ($Content -replace "`r`n", "`n"), $utf8NoBom)
            $bashPath = ConvertTo-BashPath $Path
            $quotedPath = ConvertTo-BashSingleQuoted $bashPath
            & bash -c "chmod +x $quotedPath"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to mark bash stub executable: $Path"
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
                '--deploy-name <name>'
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

        It 'errors when verify-agent expected config is missing its value' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:VerifyScript' 00000000-0000-0000-0000-000000000000 rg-test test-agent --expected"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'flag --expected requires a value'
            $result.Output | Should -Not -Match 'unbound variable'
        }

        It 'rejects unknown verify-agent arguments before Azure calls' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }
            $result = Invoke-BashCommand "bash '$script:VerifyScript' 00000000-0000-0000-0000-000000000000 rg-test test-agent --bogus"
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match "unknown argument '--bogus'"
            $result.Output | Should -Not -Match 'Could not resolve agent endpoint'
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

                $parameters = Get-Content -Path $firstPath -Raw | ConvertFrom-Json
                $parameters.parameters.upgradeChannel.value | Should -Be 'Preview'
                $parameters.parameters.experimentalSettings.value.EnableSandboxGroup | Should -BeTrue
                $parameters.parameters.experimentalSettings.value.EnableWorkspaceTools | Should -BeTrue
                $parameters.parameters.monthlyAgentUnitLimit.value | Should -Be 10000
            }
            finally {
                Remove-Item -Path $deployRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'requires cluster resource ID for dry-run when a Kusto URI is provided' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $result = Invoke-BashCommand "bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test-customer -n customer-sre-agent -l westus3 --cluster-uri https://example.westus3.kusto.windows.net/Hub --dry-run"

            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match '--cluster-resource-id is required with --cluster-uri for --dry-run'
        }

        It 'auto-resolves the Kusto cluster resource ID before deployment' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sre-agent-kusto-resolve-" + [guid]::NewGuid().ToString('N'))
            $binDir = Join-Path $tempRoot 'bin'
            $deployRoot = Join-Path $tempRoot 'deploy'
            New-Item -ItemType Directory -Force -Path $binDir, $deployRoot | Out-Null

            $fakeAz = Join-Path $binDir 'az'
            Set-BashStub -Path $fakeAz -Content @'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"account get-access-token"* ]]; then
  echo "fake-token"
  exit 0
fi

if [[ "${1:-}" == "rest" ]]; then
  echo "{}"
  exit 0
fi

if [[ "$*" == *"resource list"* ]]; then
  exit 0
fi

if [[ "$*" == *"graph query"* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Kusto/clusters/example"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$*" == *"deployment sub show"* ]]; then
  cat <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded",
    "outputs": {
      "SRE_AGENT_ENDPOINT": { "value": "https://example.azuresre.ai" },
      "SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID": { "value": "00000000-0000-0000-0000-000000000001" },
      "AGENT_PORTAL_URL": { "value": "https://sre.azure.com/#/agent/00000000-0000-0000-0000-000000000000/rg-test-customer/customer-sre-agent" }
    }
  }
}
JSON
  exit 0
fi

if [[ "$*" == *"deployment sub create"* ]]; then
  cat <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded",
    "outputs": {
      "SRE_AGENT_ENDPOINT": { "value": "https://example.azuresre.ai" },
      "SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID": { "value": "00000000-0000-0000-0000-000000000001" },
      "AGENT_PORTAL_URL": { "value": "https://sre.azure.com/#/agent/00000000-0000-0000-0000-000000000000/rg-test-customer/customer-sre-agent" }
    }
  }
}
JSON
  exit 0
fi

case "$*" in
  *"account show"*|*"account set"*|*"provider register"*|*"version"*)
    exit 0
    ;;
esac

exit 0
'@

            $fakeCurl = Join-Path $binDir 'curl'
            Set-BashStub -Path $fakeCurl -Content @'
#!/usr/bin/env bash
set -euo pipefail

out=""
url=""
method="GET"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -w)
      shift 2
      ;;
    -X)
      method="$2"
      shift 2
      ;;
    -H|--data-binary)
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$url" == */api/v2/extendedAgent/connectors/finops-hub-kusto ]]; then
  cat > "$out" <<'JSON'
{"name":"finops-hub-kusto","properties":{"dataConnectorType":"Kusto"}}
JSON
  printf "201"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/connectors ]]; then
  cat > "$out" <<'JSON'
{
  "value": [
    { "name": "chart-artifact-verification-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "chart-artifact-verification.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "document-index-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "document-index.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "ftk-output-style-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "ftk-output-style.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "known-issues-and-workarounds-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "known-issues-and-workarounds.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "onboarding-recommendations-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "onboarding-recommendations.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "teams-notification-guide-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "teams-notification-guide.md", "createdAt": "2026-05-25T19:57:31Z" } } }
  ]
}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/connectors/* ]]; then
  cat > "$out" <<'JSON'
{
  "properties": {
    "dataConnectorType": "KnowledgeFile",
    "extendedProperties": {
      "createdAt": "2026-05-25T19:57:31Z",
      "lastModifiedAt": "2026-05-25T19:57:31Z"
    }
  }
}
JSON
  if [[ "$method" == "PUT" ]]; then printf "201"; else printf "200"; fi
  exit 0
fi

if [[ "$url" == */api/v2/agent/tools/configure ]]; then
  cat > "$out" <<'JSON'
{}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v1/scheduledtasks ]]; then
  cat > "$out" <<'JSON'
[]
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/agents/* ]]; then
  [[ -n "${AGENT_APPLY_LOG:-}" ]] && basename "$url" >> "$AGENT_APPLY_LOG"
  cat > "$out" <<'JSON'
{
  "type": "ExtendedAgent",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
JSON
  printf "201"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/tools/* || "$url" == */api/v2/extendedAgent/skills/* || "$url" == */api/v2/extendedAgent/scheduledtasks/* ]]; then
  cat > "$out" <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded"
  }
}
JSON
  printf "201"
  exit 0
fi

cat > "$out" <<'JSON'
{
  "files": [
    { "name": "chart-artifact-verification-md", "isIndexed": true, "errorReason": null },
    { "name": "document-index-md", "isIndexed": true, "errorReason": null },
    { "name": "ftk-output-style-md", "isIndexed": true, "errorReason": null },
    { "name": "known-issues-and-workarounds-md", "isIndexed": true, "errorReason": null },
    { "name": "onboarding-recommendations-md", "isIndexed": true, "errorReason": null },
    { "name": "teams-notification-guide-md", "isIndexed": true, "errorReason": null }
  ],
  "continuationToken": ""
}
JSON
printf "200"
'@

            Set-BashStub -Path (Join-Path $binDir 'sleep') -Content @'
#!/usr/bin/env bash
exit 0
'@

            try {
                $command = "SRE_AGENT_DEPLOY_DIR='$deployRoot' SRE_AGENT_APPLY_REQUEST_DELAY_SECONDS=0 SRE_AGENT_APPLY_RETRY_DELAY_SECONDS=0 bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test-customer -n customer-sre-agent -l eastus2 --cluster-uri https://example.westus3.kusto.windows.net/Hub"
                $result = Invoke-BashCommandWithPath $command $binDir
                $result.ExitCode | Should -Be 0 -Because $result.Output
                $result.Output | Should -Match 'Resolving Kusto cluster resource ID from --cluster-uri'
                $result.Output | Should -Match '/providers/Microsoft\.Kusto/clusters/example'

                $parametersFile = (Get-ChildItem -Path $deployRoot -Recurse -Filter 'deploy.parameters.json' | Select-Object -First 1).FullName
                $parametersFile | Should -Not -BeNullOrEmpty
                $parameters = Get-Content -Path $parametersFile -Raw | ConvertFrom-Json
                $parameters.parameters.finopsHubKustoClusterResourceId.value | Should -Be '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Kusto/clusters/example'
            }
            finally {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'warns but continues when the Kusto cluster denies public query access' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sre-agent-kusto-private-" + [guid]::NewGuid().ToString('N'))
            $binDir = Join-Path $tempRoot 'bin'
            $deployRoot = Join-Path $tempRoot 'deploy'
            New-Item -ItemType Directory -Force -Path $binDir, $deployRoot | Out-Null

            $fakeAz = Join-Path $binDir 'az'
            Set-BashStub -Path $fakeAz -Content @'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"account get-access-token"* ]]; then
  echo "fake-token"
  exit 0
fi

if [[ "${1:-}" == "rest" ]]; then
  echo "{}"
  exit 0
fi

if [[ "$*" == *"resource show"* ]]; then
  cat <<'JSON'
{
  "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Kusto/clusters/privateadx",
  "properties": {
    "uri": "https://privateadx.westus.kusto.windows.net",
    "publicNetworkAccess": "Disabled",
    "privateEndpointConnections": [
      {
        "name": "privateadx-ep",
        "properties": {
          "privateLinkServiceConnectionState": {
            "status": "Approved"
          }
        }
      }
    ]
  }
}
JSON
  exit 0
fi

if [[ "$*" == *"deployment sub show"* ]]; then
  cat <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded",
    "outputs": {
      "SRE_AGENT_ENDPOINT": { "value": "https://example.azuresre.ai" },
      "SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID": { "value": "00000000-0000-0000-0000-000000000001" },
      "AGENT_PORTAL_URL": { "value": "https://sre.azure.com/#/agent/00000000-0000-0000-0000-000000000000/rg-test-customer/customer-sre-agent" }
    }
  }
}
JSON
  exit 0
fi

if [[ "$*" == *"deployment sub create"* ]]; then
  cat <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded",
    "outputs": {
      "SRE_AGENT_ENDPOINT": { "value": "https://example.azuresre.ai" },
      "SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID": { "value": "00000000-0000-0000-0000-000000000001" },
      "AGENT_PORTAL_URL": { "value": "https://sre.azure.com/#/agent/00000000-0000-0000-0000-000000000000/rg-test-customer/customer-sre-agent" }
    }
  }
}
JSON
  exit 0
fi

case "$*" in
  *"account show"*|*"account set"*|*"provider register"*|*"version"*)
    exit 0
    ;;
esac

exit 0
'@

            $fakeCurl = Join-Path $binDir 'curl'
            Set-BashStub -Path $fakeCurl -Content @'
#!/usr/bin/env bash
set -euo pipefail

out=""
url=""
method="GET"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -w)
      shift 2
      ;;
    -X)
      method="$2"
      shift 2
      ;;
    -H|--data-binary)
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$url" == */api/v2/extendedAgent/connectors/finops-hub-kusto ]]; then
  cat > "$out" <<'JSON'
{"name":"finops-hub-kusto","properties":{"dataConnectorType":"Kusto"}}
JSON
  printf "201"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/connectors ]]; then
  cat > "$out" <<'JSON'
{
  "value": [
    { "name": "chart-artifact-verification-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "chart-artifact-verification.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "document-index-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "document-index.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "ftk-output-style-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "ftk-output-style.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "known-issues-and-workarounds-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "known-issues-and-workarounds.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "onboarding-recommendations-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "onboarding-recommendations.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "teams-notification-guide-md", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "teams-notification-guide.md", "createdAt": "2026-05-25T19:57:31Z" } } }
  ]
}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/connectors/* ]]; then
  cat > "$out" <<'JSON'
{
  "properties": {
    "dataConnectorType": "KnowledgeFile",
    "extendedProperties": {
      "createdAt": "2026-05-25T19:57:31Z",
      "lastModifiedAt": "2026-05-25T19:57:31Z"
    }
  }
}
JSON
  if [[ "$method" == "PUT" ]]; then printf "201"; else printf "200"; fi
  exit 0
fi

if [[ "$url" == */api/v1/scheduledtasks ]]; then
  cat > "$out" <<'JSON'
[]
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/agent/tools/configure ]]; then
  cat > "$out" <<'JSON'
{}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/agents/* || "$url" == */api/v2/extendedAgent/tools/* || "$url" == */api/v2/extendedAgent/skills/* || "$url" == */api/v2/extendedAgent/scheduledtasks/* ]]; then
  cat > "$out" <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded"
  }
}
JSON
  printf "201"
  exit 0
fi

cat > "$out" <<'JSON'
{}
JSON
printf "200"
'@

            Set-BashStub -Path (Join-Path $binDir 'sleep') -Content @'
#!/usr/bin/env bash
exit 0
'@

            try {
                $clusterId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Kusto/clusters/privateadx'
                $command = "SRE_AGENT_DEPLOY_DIR='$deployRoot' SRE_AGENT_APPLY_REQUEST_DELAY_SECONDS=0 SRE_AGENT_APPLY_RETRY_DELAY_SECONDS=0 bash '$script:DeployScript' --recipe '$script:RecipeDir' --subscription 00000000-0000-0000-0000-000000000000 -g rg-test-customer -n customer-sre-agent -l eastus2 --cluster-uri https://privateadx.westus.kusto.windows.net/Hub --cluster-resource-id $clusterId"
                $result = Invoke-BashCommandWithPath $command $binDir
                $result.ExitCode | Should -Be 0 -Because $result.Output
                $result.Output | Should -Match 'Warning: The Kusto cluster denies public query access'
                $result.Output | Should -Match 'private endpoint ADX blocks direct KQL queries'
                $result.Output | Should -Match 'https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations'
                $result.Output | Should -Match 'SRE Agent ready'
            }
            finally {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'routes deploy through the copied starter-lab infra and apply-extras path' {
            if ($script:SkipBash) { Set-ItResult -Skipped -Because 'bash is unavailable' }

            $deployContent = Get-Content -Path $script:DeployScript -Raw
            $deployContent | Should -Match 'INFRA_DIR=.*infra'
            $deployContent | Should -Match '\$\{INFRA_DIR\}/main\.bicep'
            $deployContent | Should -Match 'apply-extras\.sh'
            $deployContent | Should -Not -Match 'bicep/assemble-agent|hydrate-extensions'

            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/main.bicep') | Should -BeTrue
            Test-Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/apply-extras.sh') | Should -BeTrue
        }
    }

    Context 'repo invariants' {
        It 'removes shipped recipe identity defaults' {
            $agentJson = Get-Content -Path $script:AgentJsonPath -Raw
            $agentJson | Should -Not -Match '"identity"'
        }

        It 'uses the current SRE Agent API, model provider, and sandbox configuration' {
            $agentJson = Get-Content -Path $script:AgentJsonPath -Raw | ConvertFrom-Json
            $mainBicep = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/main.bicep') -Raw
            $sreAgentBicep = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/infra/modules/sre-agent.bicep') -Raw
            $verifyScript = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/verify-agent.sh') -Raw

            $agentJson.upgradeChannel | Should -Be 'Preview'
            $agentJson.defaultModelProvider | Should -Be 'MicrosoftFoundry'
            $agentJson.defaultModelName | Should -Be 'Automatic'
            $agentJson.experimentalSettings.EnableSandboxGroup | Should -BeTrue
            $agentJson.experimentalSettings.EnableWorkspaceTools | Should -BeTrue
            $sreAgentBicep | Should -Match 'Microsoft\.App/agents@2026-01-01'
            $sreAgentBicep | Should -Not -Match 'Microsoft\.App/agents@2025-05-01-preview'
            $sreAgentBicep | Should -Match 'defaultModel:'
            $sreAgentBicep | Should -Match 'provider: defaultModelProvider'
            $sreAgentBicep | Should -Match 'name: defaultModelName'
            $sreAgentBicep | Should -Match 'upgradeChannel: upgradeChannel'
            $mainBicep | Should -Match 'defaultModelProvider'
            $mainBicep | Should -Match 'defaultModelName'
            $mainBicep | Should -Match 'EnableSandboxGroup'
            $mainBicep | Should -Match 'EnableWorkspaceTools'
            $verifyScript | Should -Match 'API_VERSION="2026-01-01"'
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
                'src/templates/sre-agent/bin/build-extras.py',
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
            $logPath = Join-Path $tempRoot 'agent-apply.log'
            New-Item -ItemType Directory -Force -Path $binDir, $buildDir | Out-Null

            $fakeAz = Join-Path $binDir 'az'
            Set-BashStub -Path $fakeAz -Content @'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"account get-access-token"* ]]; then
  echo "fake-token"
  exit 0
fi

if [[ "${1:-}" == "rest" ]]; then
  echo "{}"
  exit 0
fi

case "$*" in
  *"account show"*|*"account set"*|*"version"*)
    exit 0
    ;;
esac

exit 1
'@

            $fakeCurl = Join-Path $binDir 'curl'
            Set-BashStub -Path $fakeCurl -Content @'
#!/usr/bin/env bash
set -euo pipefail

out=""
url=""
method="GET"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -w)
      shift 2
      ;;
    -X)
      method="$2"
      shift 2
      ;;
    -H|--data-binary)
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$url" == */api/v2/extendedAgent/connectors ]]; then
  cat > "$out" <<'JSON'
{
  "value": [
    { "name": "chart-artifact-verification-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "chart-artifact-verification.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "document-index-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "document-index.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "ftk-output-style-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "ftk-output-style.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "known-issues-and-workarounds-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "known-issues-and-workarounds.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "onboarding-recommendations-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "onboarding-recommendations.md", "createdAt": "2026-05-25T19:57:31Z" } } },
    { "name": "teams-notification-guide-md", "type": "KnowledgeItem", "properties": { "dataConnectorType": "KnowledgeFile", "extendedProperties": { "displayName": "teams-notification-guide.md", "createdAt": "2026-05-25T19:57:31Z" } } }
  ]
}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/connectors/* ]]; then
  cat > "$out" <<'JSON'
{
  "type": "KnowledgeItem",
  "properties": {
    "dataConnectorType": "KnowledgeFile",
    "extendedProperties": {
      "createdAt": "2026-05-25T19:57:31Z",
      "lastModifiedAt": "2026-05-25T19:57:31Z"
    }
  }
}
JSON
  if [[ "$method" == "PUT" ]]; then printf "201"; else printf "200"; fi
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/agents/* ]]; then
  [[ -n "${AGENT_APPLY_LOG:-}" ]] && basename "$url" >> "$AGENT_APPLY_LOG"
  cat > "$out" <<'JSON'
{
  "type": "ExtendedAgent",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
JSON
  printf "201"
  exit 0
fi

if [[ "$url" == */api/v2/extendedAgent/tools/* || "$url" == */api/v2/extendedAgent/skills/* || "$url" == */api/v2/extendedAgent/scheduledtasks/* ]]; then
  cat > "$out" <<'JSON'
{
  "properties": {
    "provisioningState": "Succeeded"
  }
}
JSON
  printf "201"
  exit 0
fi

if [[ "$url" == */api/v2/agent/tools/configure ]]; then
  cat > "$out" <<'JSON'
{}
JSON
  printf "200"
  exit 0
fi

if [[ "$url" == */api/v1/scheduledtasks ]]; then
  cat > "$out" <<'JSON'
[]
JSON
  printf "200"
  exit 0
fi

cat > "$out" <<'JSON'
{
  "files": [
    { "name": "chart-artifact-verification-md", "isIndexed": true, "errorReason": null },
    { "name": "document-index-md", "isIndexed": true, "errorReason": null },
    { "name": "ftk-output-style-md", "isIndexed": true, "errorReason": null },
    { "name": "known-issues-and-workarounds-md", "isIndexed": true, "errorReason": null },
    { "name": "onboarding-recommendations-md", "isIndexed": true, "errorReason": null },
    { "name": "teams-notification-guide-md", "isIndexed": true, "errorReason": null }
  ],
  "continuationToken": ""
}
JSON
printf "200"
'@

            Set-BashStub -Path (Join-Path $binDir 'sleep') -Content @'
#!/usr/bin/env bash
exit 0
'@

            try {
                $command = "AGENT_APPLY_LOG='$logPath' SRE_AGENT_APPLY_REQUEST_DELAY_SECONDS=0 SRE_AGENT_APPLY_RETRY_DELAY_SECONDS=0 bash '$script:PostProvisionScript' --endpoint https://example.azuresre.ai --subscription 00000000-0000-0000-0000-000000000000 --resource-group rg-test-customer --name customer-sre-agent --recipe '$script:RecipeDir' --build-dir '$buildDir'"
                $result = Invoke-BashCommandWithPath $command $binDir
                $result.ExitCode | Should -Be 0 -Because $result.Output

                $order = @(Get-Content -Path $logPath)
                [array]::IndexOf($order, 'chief-financial-officer') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner'))
                [array]::IndexOf($order, 'ftk-database-query') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner'))
                [array]::IndexOf($order, 'ftk-hubs-agent') | Should -BeLessThan ([array]::IndexOf($order, 'finops-practitioner'))
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

        It 'uploads the shared FinOps output style as a portal knowledge source' {
            $applyExtrasScript = Get-Content -Path $script:ApplyExtrasScript -Raw
            $buildExtrasScript = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/build-extras.py') -Raw

            Test-Path $script:OutputStylePath | Should -BeTrue
            $buildExtrasScript | Should -Match 'claude-plugin/output-styles/ftk-output-style\.md'
            $buildExtrasScript | Should -Match 'Output style knowledge document not found'
            $applyExtrasScript | Should -Match 'knowledgeItems'
            $applyExtrasScript | Should -Match '/api/v2/extendedAgent/connectors'
            $applyExtrasScript | Should -Match 'Knowledge sources failed to index'
            $applyExtrasScript | Should -Match 'KnowledgeFile'
            $applyExtrasScript | Should -Not -Match ('sr' + 'ectl')
            $applyExtrasScript | Should -Not -Match '/api/v1/agentmemory/files'
        }

        It 'requires expected knowledge sources and verifies indexing' {
            $expectedConfig = Get-Content -Path (Join-Path $script:RecipeDir 'expected-config.json') -Raw | ConvertFrom-Json
            $verifyScript = Get-Content -Path $script:VerifyScript -Raw

            $expectedConfig.knowledgeSources.Count | Should -Be 6
            $expectedConfig.knowledgeSources | Should -Contain 'ftk-output-style.md'
            $expectedConfig.PSObject.Properties.Name | Should -Not -Contain 'knowledgeDocs'
            $verifyScript | Should -Match '/api/v2/extendedAgent/connectors'
            $verifyScript | Should -Match '\$expected\[\] \| \. as \$name \| select\(\$actual \| index\(\$name\)\)'
            $verifyScript | Should -Match 'Knowledge sources expected'
            $verifyScript | Should -Match 'Knowledge sources indexed'
            $verifyScript | Should -Match 'Unindexed knowledge sources'
            $verifyScript | Should -Not -Match '/api/v1/agentmemory'
            $verifyScript | Should -Not -Match '"knowledge_" \+'
            $verifyScript | Should -Not -Match 'Knowledge connector rows'
        }

        It 'does not duplicate response plan verification with dead incident-filter scan state' {
            $verifyScript = Get-Content -Path $script:VerifyScript -Raw

            ([regex]::Matches($verifyScript, 'check "Filter names"')).Count | Should -Be 1
            $verifyScript | Should -Not -Match 'EXP_FILTERS'
            $verifyScript | Should -Not -Match 'automations/incident-filters'
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

        It 'deletes existing scheduled tasks before applying manifests' {
            $applyExtrasScript = Get-Content -Path $script:ApplyExtrasScript -Raw
            $verifyScript = Get-Content -Path (Join-Path $script:RepoRoot 'src/templates/sre-agent/bin/verify-agent.sh') -Raw

            $applyExtrasScript | Should -Match 'delete_existing_scheduled_tasks'
            $applyExtrasScript | Should -Match '/api/v1/scheduledtasks'
            $applyExtrasScript | Should -Match 'dataplane_put_extended "scheduledtasks"'
            $verifyScript | Should -Match 'Scheduled task duplicates'
            $verifyScript | Should -Match '0 duplicates'
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
