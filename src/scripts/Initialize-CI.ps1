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

    .PARAMETER WhatIf
    Optional. Preview without making changes.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md
#>
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$Repository = "microsoft/finops-toolkit",

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$appName = "FinOps toolkit CI"
$environmentName = "ftk-pr"

$scope = "/subscriptions/$SubscriptionId"

Write-Host "Initializing CI for $Repository..."
Write-Host "  Subscription: $SubscriptionId"
Write-Host "  Environment: $environmentName"
Write-Host ""

#------------------------------------------------------------------------------
# Step 1: Azure AD app registration + service principal
#------------------------------------------------------------------------------

Write-Host "Step 1: Creating Azure AD app registration '$appName'..."

$existingApp = Get-AzADApplication -DisplayName $appName -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingApp)
{
    Write-Host "  App registration already exists (AppId: $($existingApp.AppId))."
    $app = $existingApp
}
elseif ($WhatIf)
{
    Write-Host "  [WhatIf] Would create app registration '$appName'."
}
else
{
    $app = New-AzADApplication -DisplayName $appName
    Write-Host "  Created app registration (AppId: $($app.AppId))."
}

# Service principal
if ($app)
{
    $existingSp = Get-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction SilentlyContinue
    if ($existingSp)
    {
        Write-Host "  Service principal already exists."
        $sp = $existingSp
    }
    elseif ($WhatIf)
    {
        Write-Host "  [WhatIf] Would create service principal."
    }
    else
    {
        $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
        Write-Host "  Created service principal (ObjectId: $($sp.Id))."
    }
}

#------------------------------------------------------------------------------
# Step 2: Federated credential for GitHub Actions OIDC
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 2: Adding federated credential for GitHub Actions..."

$credName = "github-$environmentName"
$subject = "repo:${Repository}:environment:${environmentName}"

if ($app)
{
    $existingCred = Get-AzADAppFederatedCredential -ApplicationObjectId $app.Id -ErrorAction SilentlyContinue | Where-Object { $_.Subject -eq $subject }
    if ($existingCred)
    {
        Write-Host "  Federated credential already exists."
    }
    elseif ($WhatIf)
    {
        Write-Host "  [WhatIf] Would add federated credential (subject: $subject)."
    }
    else
    {
        New-AzADAppFederatedCredential `
            -ApplicationObjectId $app.Id `
            -Name $credName `
            -Issuer "https://token.actions.githubusercontent.com" `
            -Subject $subject `
            -Audience @("api://AzureADTokenExchange") | Out-Null
        Write-Host "  Added federated credential (subject: $subject)."
    }
}

#------------------------------------------------------------------------------
# Step 3: RBAC on the target subscription
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 3: Granting RBAC on subscription $SubscriptionId..."

$subscriptionScope = "/subscriptions/$SubscriptionId"
$roles = @("Contributor", "User Access Administrator")

if ($sp)
{
    foreach ($role in $roles)
    {
        $existing = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $role -Scope $subscriptionScope -ErrorAction SilentlyContinue
        if ($existing)
        {
            Write-Host "  $role already assigned."
        }
        elseif ($WhatIf)
        {
            Write-Host "  [WhatIf] Would grant $role."
        }
        else
        {
            New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName $role -Scope $subscriptionScope | Out-Null
            Write-Host "  Granted $role."
        }
    }
}

#------------------------------------------------------------------------------
# Step 4: GitHub environment + secrets
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "Step 4: Creating GitHub environment '$environmentName'..."

# Verify gh CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue))
{
    Write-Warning "GitHub CLI (gh) not found. Install it from https://cli.github.com/ and run this step manually."
    Write-Host ""
    Write-Host "Manual steps:"
    Write-Host "  1. Create environment '$environmentName' in $Repository settings"
    Write-Host "  2. Add secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, CI_SCOPE"
    return
}

if ($WhatIf)
{
    Write-Host "  [WhatIf] Would create environment '$environmentName' in $Repository."
    Write-Host "  [WhatIf] Would add secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, CI_SCOPE."
}
else
{
    # Create environment
    gh api "repos/$Repository/environments/$environmentName" -X PUT --silent 2>$null
    Write-Host "  Created environment '$environmentName'."

    # Get tenant ID from current context
    $tenantId = (Get-AzContext).Tenant.Id

    # Set secrets
    $secrets = @{
        AZURE_CLIENT_ID       = $app.AppId
        AZURE_TENANT_ID       = $tenantId
        AZURE_SUBSCRIPTION_ID = $SubscriptionId
        CI_SCOPE              = $scope
    }

    foreach ($name in $secrets.Keys)
    {
        $secrets[$name] | gh secret set $name --repo $Repository --env $environmentName
        Write-Host "  Set secret: $name"
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
Write-Host "  GitHub environment: $environmentName"
Write-Host "  Subscription: $SubscriptionId"
Write-Host ""
Write-Host "CI is ready. The ftk-pr-deploy workflow will use the '$environmentName' environment."
