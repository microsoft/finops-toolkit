# Post-provision: configure SRE Agent with repo-defined skills, agents, tools,
# and scheduled tasks via srectl.
# OAuth-based Outlook and Teams connectors are intentionally excluded here:
# Microsoft Learn currently documents them as interactive portal setup only.
#Requires -Version 7.0
param(
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$script:DryRun = $DryRun.IsPresent
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SrectlSource = 'https://pkgs.dev.azure.com/msazure/One/_packaging/SREAgentCli/nuget/v3/index.json'
$PostProvisionMarkerName = 'postprovision.succeeded'

function Write-Log($Message) { Write-Host "[post-provision] $Message" }
function Write-DryRun($Message) { Write-Host "[DRY-RUN] $Message" }

function Write-SuccessMarker {
    if ($script:DryRun) { return }

    $environmentName = $env:AZURE_ENV_NAME
    if (-not $environmentName) {
        throw 'AZURE_ENV_NAME is required to write the post-provision success marker.'
    }

    $markerDir = Join-Path $RepoRoot ".azure/$environmentName"
    $marker = Join-Path $markerDir $PostProvisionMarkerName
    New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
    @(
        'status=success'
        "environment=$environmentName"
        "completedUtc=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    ) | Set-Content -Path $marker -Encoding utf8
}

function Invoke-SrectlOrDryRun {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    if ($script:DryRun) {
        Write-DryRun "would run: srectl $($Arguments -join ' ')"
        $global:LASTEXITCODE = 0
        return
    }

    & srectl @Arguments
}

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

function Resolve-SubscriptionId {
    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID
    if (-not $subscriptionId) {
        $subscriptionId = az account show --query id -o tsv 2>$null
    }
    if (-not $subscriptionId -or $subscriptionId -match '^ERROR') {
        throw 'AZURE_SUBSCRIPTION_ID is required for RBAC assignment.'
    }
    return $subscriptionId.Trim()
}

function Resolve-IdentityPrincipalId {
    $principalId = $env:IDENTITY_PRINCIPAL_ID
    if (-not $principalId -and (Get-Command azd -ErrorAction SilentlyContinue)) {
        $principalId = azd env get-value IDENTITY_PRINCIPAL_ID --no-prompt 2>$null
    }
    if (-not $principalId -or $principalId -match '^ERROR') {
        throw 'IDENTITY_PRINCIPAL_ID is required for RBAC assignment. Run azd env refresh after provisioning if this output is missing.'
    }
    return $principalId.Trim()
}

function Install-Srectl {
    if (Get-Command srectl -ErrorAction SilentlyContinue) {
        Invoke-SrectlOrDryRun --version | Out-Null
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

function Add-RoleAssignmentIfMissing {
    param(
        [string]$PrincipalId,
        [string]$RoleId,
        [string]$RoleName,
        [string]$Scope
    )

    $existing = az role assignment list --assignee $PrincipalId --role $RoleId --scope $Scope --query 'length(@)' -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check $RoleName assignment for $PrincipalId at $Scope."
    }

    if ([int]$existing -gt 0) {
        Write-Log "$RoleName already assigned to UAMI ($PrincipalId) at subscription scope."
        return
    }

    Write-Log "Assigning $RoleName to UAMI ($PrincipalId) at subscription scope..."
    az role assignment create `
        --assignee-object-id $PrincipalId `
        --assignee-principal-type ServicePrincipal `
        --role $RoleId `
        --scope $Scope `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign $RoleName to $PrincipalId at $Scope."
    }
}

function Add-CustomRoleAssignmentIfMissing {
    param(
        [string]$PrincipalId,
        [string]$RoleName,
        [string]$Scope
    )

    $existing = az role assignment list --assignee $PrincipalId --role $RoleName --scope $Scope --query 'length(@)' -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check custom role assignment $RoleName for $PrincipalId at $Scope."
    }

    if ([int]$existing -gt 0) {
        Write-Log "$RoleName already assigned to UAMI ($PrincipalId) at subscription scope."
        return
    }

    Write-Log "Assigning $RoleName to UAMI ($PrincipalId)"
    az role assignment create `
        --assignee-object-id $PrincipalId `
        --assignee-principal-type ServicePrincipal `
        --role $RoleName `
        --scope $Scope `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign custom role $RoleName to $PrincipalId at $Scope."
    }
}

function Add-CustomPermissions {
    $subscriptionId = Resolve-SubscriptionId
    $principalId = Resolve-IdentityPrincipalId
    $roleName = 'FinOps SRE Zone Peers Reader'
    $scope = "/subscriptions/$subscriptionId"

    $roleExists = az role definition list --name $roleName --scope $scope --query 'length(@)' -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check custom role $roleName."
    }

    if ([int]$roleExists -eq 0) {
        Write-Log "Creating custom role: $roleName"
        $roleDefinition = @{
            Name = $roleName
            Description = 'Allows checking availability zone peer mappings across subscriptions. Used by the zone-mapping Python tool.'
            Actions = @('Microsoft.Resources/checkZonePeers/action')
            AssignableScopes = @($scope)
        } | ConvertTo-Json -Compress

        az role definition create --role-definition $roleDefinition --output none
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create custom role $roleName."
        }
    } else {
        Write-Log "Custom role $roleName already exists."
    }

    Add-CustomRoleAssignmentIfMissing -PrincipalId $principalId -RoleName $roleName -Scope $scope
}

function Add-SubscriptionRbac {
    $subscriptionId = Resolve-SubscriptionId
    $principalId = Resolve-IdentityPrincipalId
    $scope = "/subscriptions/$subscriptionId"

    Add-RoleAssignmentIfMissing `
        -PrincipalId $principalId `
        -RoleId 'acdd72a7-3385-48ef-bd42-f606fba81ae7' `
        -RoleName 'Reader' `
        -Scope $scope

    Add-RoleAssignmentIfMissing `
        -PrincipalId $principalId `
        -RoleId '749f88d5-cbae-40b8-bcfc-e573ddc772fa' `
        -RoleName 'Monitoring Contributor' `
        -Scope $scope
}

function Get-YamlFiles($Dir) {
    @(
        Get-ChildItem -Path (Join-Path $Dir '*.yaml') -File -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $Dir '*.yml') -File -ErrorAction SilentlyContinue
    )
}

function Apply-YamlDir($Dir, $Label) {
    if (-not (Test-Path $Dir)) { return }
    $files = Get-YamlFiles $Dir
    foreach ($f in $files) {
        if ($script:DryRun) {
            Write-DryRun "Would apply ${Label}: $($f.BaseName)"
            continue
        }

        Write-Log "Applying ${Label}: $($f.Name)"
        Invoke-SrectlOrDryRun apply-yaml --file $f.FullName
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply $($f.Name)" }
    }
    Write-Log "Applied $($files.Count) $Label."
}

function Apply-Agents {
    $agentsDir = Join-Path $RepoRoot 'sre-config/agents'
    if (-not (Test-Path $agentsDir)) { return }

    $files = @(Get-YamlFiles $agentsDir)
    if ($script:DryRun) {
        foreach ($f in $files) {
            Write-DryRun "Would apply agent: $($f.BaseName)"
        }
        return
    }

    $maxPasses = 3
    $pending = @($files)
    for ($pass = 1; $pass -le $maxPasses -and $pending.Count -gt 0; $pass++) {
        Write-Log "Agent apply pass $pass ($($pending.Count) remaining)..."
        $failed = @()
        foreach ($f in $pending) {
            Write-Log "Applying agent: $($f.Name)"
            Invoke-SrectlOrDryRun apply-yaml --file $f.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Log "  Deferred: $($f.Name) (will retry)"
                $failed += $f
            }
        }
        $pending = @($failed)
    }

    if ($pending.Count -gt 0) {
        foreach ($f in $pending) {
            Write-Log "Failed to apply agent after $maxPasses passes: $($f.Name)"
        }
        throw "Failed to apply $($pending.Count) agent(s) after $maxPasses passes."
    }
}

function Apply-Skills {
    $skillsDir = Join-Path $RepoRoot 'sre-config/skills'
    if (-not (Test-Path $skillsDir)) { return }

    if ($script:DryRun) {
        foreach ($skill in Get-ChildItem $skillsDir -Directory) {
            Write-DryRun "Would apply skill: $($skill.Name)"
        }
        return
    }

    $dest = Join-Path (Get-Location) 'skills'
    # Copy resolved skills (dereference symlinks, exclude binary and docs-mslearn)
    if ($IsLinux -or $IsMacOS) {
        rsync -rL --exclude='docs-mslearn' --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.ico' --exclude='*.svg' "$skillsDir/" "$dest/"
    } else {
        Copy-Item $skillsDir $dest -Recurse -Force
    }

    foreach ($skill in Get-ChildItem $dest -Directory) {
        Write-Log "Applying skill: $($skill.Name)"
        Invoke-SrectlOrDryRun skill apply --name $skill.Name
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply skill $($skill.Name)" }
    }
}

function Apply-Knowledge {
    $knowledgeDir = Join-Path $RepoRoot 'sre-config/knowledge'
    if (-not (Test-Path $knowledgeDir)) { return }

    if ($script:DryRun) {
        Write-DryRun 'Would upload knowledge from sre-config/knowledge'
        return
    }

    Write-Log 'Uploading knowledge documents from sre-config/knowledge...'
    Invoke-SrectlOrDryRun doc upload --file $knowledgeDir
    if ($LASTEXITCODE -ne 0) { throw 'Failed to upload knowledge documents' }
}

function Test-KnowledgeDocuments {
    $knowledgeDir = Join-Path $RepoRoot 'sre-config/knowledge'
    if (-not (Test-Path $knowledgeDir)) { return }

    if ($script:DryRun) {
        Write-DryRun 'Would verify uploaded knowledge documents with srectl doc get'
        return
    }

    $documents = ''
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $documents = (& srectl doc get 2>&1) | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list uploaded knowledge documents with 'srectl doc get'."
        }
        if ($documents.Trim() -and $documents -match 'document-index\.md') {
            return
        }
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 5
        }
    }

    if (-not $documents.Trim()) {
        throw 'srectl doc get returned no uploaded knowledge documents after uploading sre-config/knowledge.'
    }
    if ($documents -notmatch 'document-index\.md') {
        throw 'Uploaded knowledge document list did not include document-index.md.'
    }
}

function Apply-ScheduledTasks {
    $tasksDir = Join-Path $RepoRoot 'sre-config/scheduled-tasks'
    if (-not (Test-Path $tasksDir)) { return }

    $existingTasks = ''
    if (-not $script:DryRun) {
        $existingTasks = (& srectl scheduledtask list --verbose 2>&1) | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to list existing scheduled tasks.'
        }
    }

    foreach ($f in Get-YamlFiles $tasksDir) {
        $taskName = Get-ScheduledTaskName -File $f.FullName
        if (-not $taskName) {
            throw "Scheduled task manifest $($f.Name) is missing metadata.name/spec.name."
        }

        if ($script:DryRun) {
            Write-DryRun "Would remove existing scheduled task(s) named: $taskName"
            Write-DryRun "Would apply scheduled task: $($f.Name)"
            continue
        }

        foreach ($id in Get-ScheduledTaskIdsByName -ScheduledTasksText $existingTasks -Name $taskName) {
            Write-Log "Removing existing scheduled task '$taskName' ($id) before applying managed definition..."
            Invoke-SrectlOrDryRun scheduledtask delete --id $id --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to delete existing scheduled task $taskName ($id)."
            }
        }

        Write-Log "Applying scheduled task: $($f.Name)"
        Invoke-SrectlOrDryRun scheduledtask apply --file $f.FullName --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to apply scheduled task $($f.Name)"
        }
    }
}

function Get-ScheduledTaskName {
    param([string]$File)

    foreach ($line in Get-Content -Path $File) {
        if ($line -match '^\s*name:\s*(.+?)\s*$') {
            return $Matches[1].Trim(' ', '"', "'")
        }
    }
    return $null
}

function Get-ScheduledTaskIdsByName {
    param(
        [string]$ScheduledTasksText,
        [string]$Name
    )

    $current = $null
    foreach ($line in ($ScheduledTasksText -split "`r?`n")) {
        if ($line -match '^\[\d+\]\s+(.+?)\s*$') {
            $current = $Matches[1]
            continue
        }
        if ($current -eq $Name -and $line -match '^ID\s*:\s*(.+?)\s*$') {
            $Matches[1]
        }
    }
}

# Repo connector intentionally removed — the agent was searching the full
# codebase and attempting git commits. Knowledge docs provide the reference
# material the agent needs without repo access.
# function Add-RepoConnector { ... }

# Main
if ($script:DryRun) {
    $endpoint = if ($env:SRE_AGENT_ENDPOINT) { $env:SRE_AGENT_ENDPOINT } else { 'https://dry-run.invalid' }
    Write-DryRun 'Dry-run mode enabled; skipping endpoint validation.'
    Write-DryRun 'Skipping srectl installation check.'
} else {
    $endpoint = Resolve-Endpoint
    Install-Srectl
    Add-CustomPermissions
    Add-SubscriptionRbac
}

$workdir = Join-Path ([System.IO.Path]::GetTempPath()) "finops-sre-$(New-Guid)"
New-Item -ItemType Directory -Path $workdir -Force | Out-Null
try {
    Push-Location $workdir
    if ($script:DryRun) {
        Write-DryRun "Skipping srectl init for endpoint: $endpoint"
    } else {
        Write-Log 'Initializing srectl...'
        Invoke-SrectlOrDryRun init --resource-url $endpoint
        if ($LASTEXITCODE -ne 0) { throw 'srectl init failed.' }
    }

    Apply-Skills
    Apply-Agents
    Apply-YamlDir (Join-Path $RepoRoot 'tools') 'tool'
    Apply-Knowledge
    Test-KnowledgeDocuments
    Apply-ScheduledTasks

    Write-SuccessMarker
    Write-Log 'Post-provision complete.'
} finally {
    Pop-Location
    Remove-Item $workdir -Recurse -Force -ErrorAction SilentlyContinue
}
