# Post-provision: configure SRE Agent with repo-defined skills, agents, tools,
# and scheduled tasks via srectl.
# OAuth-based Outlook and Teams connectors are intentionally excluded here:
# Microsoft Learn currently documents them as interactive portal setup only.
#Requires -Version 7.0
param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SrectlSource = 'https://pkgs.dev.azure.com/msazure/One/_packaging/SREAgentCli/nuget/v3/index.json'

function Write-Log($Message) { Write-Host "[post-provision] $Message" }

function Resolve-Endpoint {
    $ep = $env:SRE_AGENT_ENDPOINT
    if (-not $ep -and (Get-Command azd -ErrorAction SilentlyContinue)) {
        $ep = azd env get-value SRE_AGENT_ENDPOINT --no-prompt 2>$null
    }
    if (-not $ep -or $ep -match '^ERROR') {
        throw 'SRE_AGENT_ENDPOINT is required.'
    }
    return $ep
}

function Install-Srectl {
    if (Get-Command srectl -ErrorAction SilentlyContinue) {
        srectl --version | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
    }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw '.NET SDK required for srectl.'
    }
    Write-Log 'Installing srectl...'
    dotnet tool install --global sreagent.cli --add-source $SrectlSource | Out-Null
    if (-not (Get-Command srectl -ErrorAction SilentlyContinue)) {
        throw 'srectl installation failed.'
    }
}

function Apply-YamlDir($Dir, $Label) {
    if (-not (Test-Path $Dir)) { return }
    $files = Get-ChildItem $Dir -Include '*.yaml','*.yml' -File
    foreach ($f in $files) {
        Write-Log "Applying ${Label}: $($f.Name)"
        srectl apply-yaml --file $f.FullName
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply $($f.Name)" }
    }
    Write-Log "Applied $($files.Count) $Label."
}

function Apply-Agents {
    $agentsDir = Join-Path $RepoRoot 'sre-config/agents'
    if (-not (Test-Path $agentsDir)) { return }

    # Pass 1: agents without handoffs
    foreach ($f in Get-ChildItem $agentsDir -Include '*.yaml','*.yml' -File) {
        $hasHandoffs = python3 -c @"
import yaml, sys
with open(sys.argv[1]) as fh:
    d = yaml.safe_load(fh)
h = d.get('spec',{}).get('handoffs',[])
print('yes' if h else 'no')
"@ $f.FullName
        if ($hasHandoffs -eq 'no') {
            Write-Log "Applying agent: $($f.Name)"
            srectl apply-yaml --file $f.FullName
            if ($LASTEXITCODE -ne 0) { throw "Failed to apply $($f.Name)" }
        }
    }

    # Pass 2: agents with handoffs
    foreach ($f in Get-ChildItem $agentsDir -Include '*.yaml','*.yml' -File) {
        $hasHandoffs = python3 -c @"
import yaml, sys
with open(sys.argv[1]) as fh:
    d = yaml.safe_load(fh)
h = d.get('spec',{}).get('handoffs',[])
print('yes' if h else 'no')
"@ $f.FullName
        if ($hasHandoffs -eq 'yes') {
            Write-Log "Applying agent: $($f.Name)"
            srectl apply-yaml --file $f.FullName
            if ($LASTEXITCODE -ne 0) { throw "Failed to apply $($f.Name)" }
        }
    }
}

function Apply-Skills {
    $skillsDir = Join-Path $RepoRoot 'sre-config/skills'
    if (-not (Test-Path $skillsDir)) { return }

    $dest = Join-Path (Get-Location) 'skills'
    # Copy resolved skills (dereference symlinks, exclude binary and docs-mslearn)
    if ($IsLinux -or $IsMacOS) {
        rsync -rL --exclude='docs-mslearn' --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.ico' --exclude='*.svg' "$skillsDir/" "$dest/"
    } else {
        Copy-Item $skillsDir $dest -Recurse -Force
    }

    foreach ($skill in Get-ChildItem $dest -Directory) {
        Write-Log "Applying skill: $($skill.Name)"
        srectl skill apply --name $skill.Name
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply skill $($skill.Name)" }
    }
}

function Apply-Knowledge {
    $knowledgeDir = Join-Path $RepoRoot 'sre-config/knowledge'
    if (-not (Test-Path $knowledgeDir)) { return }

    Write-Log 'Uploading knowledge documents from sre-config/knowledge...'
    srectl doc upload --file $knowledgeDir
    if ($LASTEXITCODE -ne 0) { throw 'Failed to upload knowledge documents' }
}

function Apply-ScheduledTasks {
    $tasksDir = Join-Path $RepoRoot 'sre-config/scheduled-tasks'
    if (-not (Test-Path $tasksDir)) { return }
    foreach ($f in Get-ChildItem $tasksDir -Include '*.yaml','*.yml' -File) {
        Write-Log "Applying scheduled task: $($f.Name)"
        srectl scheduledtask apply --file $f.FullName --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WARNING: Failed to apply $($f.Name)"
        }
    }
}

function Add-RepoConnector {
    Write-Log 'Adding finops-toolkit repository connector...'
    srectl repo add --name finops-toolkit --url https://github.com/microsoft/finops-toolkit 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'Repository connector may already exist.'
    }
}

# Main
$endpoint = Resolve-Endpoint
Install-Srectl

$workdir = Join-Path ([System.IO.Path]::GetTempPath()) "finops-sre-$(New-Guid)"
New-Item -ItemType Directory -Path $workdir -Force | Out-Null
try {
    Push-Location $workdir
    Write-Log 'Initializing srectl...'
    srectl init --resource-url $endpoint

    Apply-Skills
    Apply-Agents
    Apply-YamlDir (Join-Path $RepoRoot 'tools') 'tool'
    Apply-Knowledge
    Apply-ScheduledTasks
    Add-RepoConnector

    Write-Log 'Post-provision complete.'
} finally {
    Pop-Location
    Remove-Item $workdir -Recurse -Force -ErrorAction SilentlyContinue
}
