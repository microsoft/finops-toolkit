# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    One-time setup for FinOps toolkit CI environments.

    .DESCRIPTION
    Creates the Azure AD app registration, service principal, federated credential, and GitHub environment needed for per-PR deployment CI. Only needs to be run once per repository.

    .EXAMPLE
    Initialize-CI -SubscriptionId "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"

    Sets up CI with the specified subscription for deployments and cost exports.

    .EXAMPLE
    Initialize-CI -SubscriptionId "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" -WhatIf

    Previews what would be created without making changes.

    .PARAMETER SubscriptionId
    Required. Azure subscription ID for PR deployments and cost exports.

    .PARAMETER Repository
    Optional. GitHub repo in "owner/repo" format. Default: "microsoft/finops-toolkit".

    .PARAMETER ReviewerId
    Optional. GitHub user IDs to set as required reviewers on the "ftk-fork" environment. Cleanup uses this environment for closed fork PRs, including earlier test resources. Fork PRs cannot deploy directly. Deployment uses "ftk-pr", which this script creates without required reviewers.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$Repository = "microsoft/finops-toolkit",

    # Required reviewers for cleanup of closed fork PRs, not for fork deployment.
    [int[]]$ReviewerId
)

$ErrorActionPreference = "Stop"

$appName = "FinOps toolkit CI ($Repository)"

# Deployment uses 'ftk-pr' without required reviewers. Cleanup selects 'ftk-pr'
# or 'ftk-fork' from the closed PR's source repository.
$internalEnvironment = "ftk-pr"
$forkEnvironment = "ftk-fork"
$environments = @($internalEnvironment, $forkEnvironment)

$scope = "/subscriptions/$SubscriptionId"

Write-Host "Initializing CI for $Repository..."
Write-Host "  Subscription: $SubscriptionId"
Write-Host "  Environments: $($environments -join ', ')"
Write-Host ""

#------------------------------------------------------------------------------
# Step 1: Azure AD app registration + service principal
#------------------------------------------------------------------------------

Write-Host "Step 1: Creating Azure AD app registration '$appName'..."

$app = Get-AzADApplication -DisplayName $appName -ErrorAction SilentlyContinue `
| Where-Object { $_.DisplayName -eq $appName } `
| Select-Object -First 1

if ($app)
{
    Write-Host "  App registration already exists (AppId: $($app.AppId))."
}
elseif ($PSCmdlet.ShouldProcess($appName, 'Create app registration'))
{
    $app = New-AzADApplication -DisplayName $appName
    Write-Host "  Created app registration (AppId: $($app.AppId))."
}

# Service principal
if ($app)
{
    $sp = Get-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction SilentlyContinue
    if ($sp)
    {
        Write-Host "  Service principal already exists."
    }
    elseif ($PSCmdlet.ShouldProcess($appName, 'Create service principal'))
    {
        $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
        Write-Host "  Created service principal (ObjectId: $($sp.Id))."
    }
}
else
{
    $PSCmdlet.ShouldProcess($appName, 'Create service principal') | Out-Null
}

#------------------------------------------------------------------------------
# Step 2: Federated credential for GitHub Actions OIDC
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 2: Adding federated credential for GitHub Actions..."

# GitHub presents environment-scoped OIDC tokens with an ID-based subject
# (repository_owner_id:...:repository_id:...:environment:...), not the name-based
# "repo:owner/repo:environment:..." form. The federated credential subject must
# match the presented assertion or Azure login fails with AADSTS700213. Each
# environment needs its own credential because the subject includes the env name.
$repoIds = gh api "repos/$Repository" --jq '"\(.owner.id):\(.id)"'
if ($LASTEXITCODE -ne 0 -or -not $repoIds) { throw "Failed to look up owner/repo IDs for '$Repository' via gh." }
$ownerId, $repoId = $repoIds -split ':'

foreach ($env in $environments)
{
    $credName = "github-$env"
    $subject = "repository_owner_id:${ownerId}:repository_id:${repoId}:environment:${env}"

    if ($app)
    {
        $existingCred = Get-AzADAppFederatedCredential -ApplicationObjectId $app.Id -ErrorAction SilentlyContinue | Where-Object { $_.Subject -eq $subject }
        if ($existingCred)
        {
            Write-Host "  Federated credential for '$env' already exists."
        }
        elseif ($PSCmdlet.ShouldProcess($subject, 'Add federated credential'))
        {
            New-AzADAppFederatedCredential `
                -ApplicationObjectId $app.Id `
                -Name $credName `
                -Issuer "https://token.actions.githubusercontent.com" `
                -Subject $subject `
                -Audience @("api://AzureADTokenExchange") | Out-Null
            Write-Host "  Added federated credential for '$env' (subject: $subject)."
        }
    }
    else
    {
        $PSCmdlet.ShouldProcess($subject, 'Add federated credential') | Out-Null
    }
}

#------------------------------------------------------------------------------
# Step 3: RBAC on the target subscription
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 3: Granting RBAC on subscription $SubscriptionId..."

$roles = @("Contributor", "User Access Administrator")

if ($sp)
{
    foreach ($role in $roles)
    {
        $existing = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $role -Scope $scope -ErrorAction SilentlyContinue
        if ($existing)
        {
            Write-Host "  $role already assigned."
        }
        elseif ($PSCmdlet.ShouldProcess("$role on $scope", 'Grant role'))
        {
            New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $role -Scope $scope | Out-Null
            Write-Host "  Granted $role."
        }
    }
}
else
{
    foreach ($role in $roles)
    {
        $PSCmdlet.ShouldProcess("$role on $scope", 'Grant role') | Out-Null
    }
}

#------------------------------------------------------------------------------
# Step 4: GitHub environment + secrets
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 4: Creating GitHub environments $($environments -join ', ')..."

# Verify gh CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue))
{
    Write-Warning "GitHub CLI (gh) not found. Install it from https://cli.github.com/ and run this step manually."
    Write-Host ""
    Write-Host "Manual steps:"
    Write-Host "  1. Create environments '$internalEnvironment' and '$forkEnvironment' in $Repository settings"
    Write-Host "  2. Add required reviewers to '$forkEnvironment' only"
    Write-Host "  3. Add secrets to BOTH: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, CI_SCOPE"
    return
}

if ($PSCmdlet.ShouldProcess("$($environments -join ', ') in $Repository", 'Create GitHub environments'))
{
    # Get tenant ID from current context (shared by both environments)
    $tenantId = (Get-AzContext).Tenant.Id
    $secrets = @{
        AZURE_CLIENT_ID       = $app.AppId
        AZURE_TENANT_ID       = $tenantId
        AZURE_SUBSCRIPTION_ID = $SubscriptionId
        CI_SCOPE              = $scope
    }

    foreach ($env in $environments)
    {
        # Fork cleanup can require approval. Deployment uses only 'ftk-pr'.
        if ($env -eq $forkEnvironment)
        {
            if ($ReviewerId)
            {
                $reviewers = @($ReviewerId | ForEach-Object { @{ type = 'User'; id = $_ } })
                $body = @{ reviewers = $reviewers; prevent_self_review = $true } | ConvertTo-Json -Depth 5 -Compress
                $body | gh api "repos/$Repository/environments/$env" -X PUT --input - --silent
            }
            else
            {
                Write-Warning "No -ReviewerId supplied: '$env' will have no required reviewers. Cleanup for closed fork PRs can delete test resource groups without environment approval. This does not enable fork deployment."
                gh api "repos/$Repository/environments/$env" -X PUT --silent
            }
        }
        else
        {
            # Explicitly clear reviewers so a re-run always leaves the internal
            # environment ungated, even if it previously had reviewers.
            '{"reviewers":[]}' | gh api "repos/$Repository/environments/$env" -X PUT --input - --silent
        }
        if ($LASTEXITCODE -ne 0) { throw "Failed to create GitHub environment '$env'." }
        Write-Host "  Created environment '$env'."

        foreach ($name in $secrets.Keys)
        {
            $secrets[$name] | gh secret set $name --repo $Repository --env $env
            if ($LASTEXITCODE -ne 0) { throw "Failed to set secret '$name' on '$env'." }
            Write-Host "    Set secret: $name"
        }
    }
}

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Summary ---"
if ($app)
{
    Write-Host "  App registration: $appName (AppId: $($app.AppId))"
}
Write-Host "  GitHub environments: $($environments -join ', ') ('$forkEnvironment' gated by reviewers)"
Write-Host "  Subscription: $SubscriptionId"
Write-Host ""
Write-Host "CI is ready. Internal PRs use '$internalEnvironment'; fork PRs use '$forkEnvironment'."
