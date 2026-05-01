# Packaged one-shot deployment wrapper for the FinOps SRE Agent template.
# References:
# - Azure Developer CLI environment workflow:
#   https://learn.microsoft.com/azure/developer/azure-developer-cli/work-with-environments
# - Official Azure SRE Agent repo packaging pattern:
#   https://github.com/microsoft/sre-agent/tree/main/samples/hands-on-lab
#Requires -Version 7.0
param(
    [string]$Environment,
    [string]$Location,
    [string]$Subscription,
    [string]$ResourceGroup,
    [string]$PrincipalType,
    [string]$FinopsHubClusterUri,
    [string]$FinopsHubClusterName,
    [string]$FinopsHubClusterResourceGroup,
    [switch]$DeployHub,
    [string]$HubSku,
    [string]$EnvFile,
    [string]$CloneEnv,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

function Write-Log($Message) { Write-Host "[deploy] $Message" }
function Fail($Message) { throw $Message }

function Show-Usage {
    @"
Usage:
  pwsh ./scripts/deploy.ps1 -Environment <name> [options]

Options:
  -Environment <name>                    Target azd environment name.
  -Location <region>                     Azure location. Default: eastus2.
  -Subscription <subscription-id>        Azure subscription ID. Defaults to current az account.
  -ResourceGroup <name>                  Azure resource group. Defaults to the environment name.
  -PrincipalType <type>                  Deployer principal type. Default: User.
  -FinopsHubClusterUri <uri>             Optional. FinOps Hub Kusto cluster URI. Kusto connector is skipped if omitted.
  -FinopsHubClusterName <name>           Optional ADX cluster name for AllDatabasesViewer assignment.
  -FinopsHubClusterResourceGroup <name>  Optional ADX cluster resource group.
  -DeployHub                             Deploy a FinOps hub alongside the SRE agent.
  -HubSku <sku>                          ADX SKU for the deployed hub. Default: Standard_E2ads_v5.
  -EnvFile <path>                        Load azd-style values from a .env file before applying overrides.
  -CloneEnv <name>                       Load values from .azure/<name>/.env before applying overrides.
"@ | Write-Host
}

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Required command not found: $Name"
    }
}

function Import-DotEnv([string]$Path) {
    if (-not (Test-Path $Path)) {
        Fail "Environment file not found: $Path"
    }

    foreach ($line in Get-Content -Path $Path) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"')
        Set-Item -Path "env:$name" -Value $value
    }
}

function Test-EnvExists([string]$Name) {
    Test-Path (Join-Path $RepoRoot ".azure/$Name")
}

function Get-CurrentSubscription {
    az account show --query id -o tsv 2>$null
}

if ($Help) {
    Show-Usage
    exit 0
}

Require-Command az
Require-Command azd
Require-Command dotnet
Require-Command python3

if ($EnvFile -and $CloneEnv) {
    Fail 'Use either -EnvFile or -CloneEnv, not both.'
}

if ($EnvFile) {
    Import-DotEnv -Path $EnvFile
}

if ($CloneEnv) {
    Import-DotEnv -Path (Join-Path $RepoRoot ".azure/$CloneEnv/.env")
    # Unset identity vars so the cloned env doesn't override the new environment name/RG
    Remove-Item env:AZURE_ENV_NAME, env:AZURE_RESOURCE_GROUP, env:SRE_AGENT_ENDPOINT, env:SRE_AGENT_NAME -ErrorAction SilentlyContinue
}

if (-not $Environment) { $Environment = $env:AZURE_ENV_NAME }
if (-not $Location) { $Location = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { 'eastus2' } }
if (-not $Subscription) { $Subscription = if ($env:AZURE_SUBSCRIPTION_ID) { $env:AZURE_SUBSCRIPTION_ID } else { Get-CurrentSubscription } }
if (-not $PrincipalType) { $PrincipalType = if ($env:AZURE_PRINCIPAL_TYPE) { $env:AZURE_PRINCIPAL_TYPE } else { 'User' } }
if (-not $FinopsHubClusterUri) { $FinopsHubClusterUri = $env:FINOPS_HUB_CLUSTER_URI }
if (-not $FinopsHubClusterName) { $FinopsHubClusterName = $env:FINOPS_HUB_CLUSTER_NAME }
if (-not $FinopsHubClusterResourceGroup) { $FinopsHubClusterResourceGroup = $env:FINOPS_HUB_CLUSTER_RESOURCE_GROUP }
if (-not $HubSku) { $HubSku = if ($env:FINOPS_HUB_DATA_EXPLORER_SKU) { $env:FINOPS_HUB_DATA_EXPLORER_SKU } else { 'Standard_E2ads_v5' } }
$DeployHubValue = if ($DeployHub.IsPresent -or $env:DEPLOY_FINOPS_HUB -eq 'true') { 'true' } else { 'false' }

# Resource group defaults to the environment name unless explicitly overridden.
$ResourceGroupExplicit = $PSBoundParameters.ContainsKey('ResourceGroup')
if (-not $ResourceGroupExplicit) { $ResourceGroup = $Environment }

if (-not $Environment) { Fail '-Environment is required.' }

if (-not $Subscription) { Fail 'Azure subscription could not be resolved. Use -Subscription or sign in with az.' }
if ($DeployHubValue -eq 'true' -and $FinopsHubClusterUri) {
    Fail '-DeployHub and -FinopsHubClusterUri are mutually exclusive. Use one or the other.'
}
if ($DeployHubValue -eq 'false' -and -not $FinopsHubClusterUri) {
    Write-Log 'WARNING: No FinOps hub cluster URI provided. Kusto connector will not be configured. You can connect a hub later.'
}

Push-Location $RepoRoot
try {
    if (-not (Test-EnvExists -Name $Environment)) {
        Write-Log "Creating azd environment $Environment..."
        azd env new $Environment --subscription $Subscription --location $Location --no-prompt
    } else {
        Write-Log "Selecting existing azd environment $Environment..."
        azd env select $Environment
    }

    Write-Log 'Setting azd environment values...'
    $envArgs = @(
        'env', 'set',
        '--environment', $Environment,
        "AZURE_ENV_NAME=$Environment",
        "AZURE_LOCATION=$Location",
        "AZURE_PRINCIPAL_TYPE=$PrincipalType",
        "AZURE_RESOURCE_GROUP=$ResourceGroup",
        "AZURE_SUBSCRIPTION_ID=$Subscription",
        "FINOPS_HUB_CLUSTER_URI=$FinopsHubClusterUri",
        "DEPLOY_FINOPS_HUB=$DeployHubValue",
        "FINOPS_HUB_DATA_EXPLORER_SKU=$HubSku"
    )

    if ($FinopsHubClusterName) {
        $envArgs += "FINOPS_HUB_CLUSTER_NAME=$FinopsHubClusterName"
    }

    if ($FinopsHubClusterResourceGroup) {
        $envArgs += "FINOPS_HUB_CLUSTER_RESOURCE_GROUP=$FinopsHubClusterResourceGroup"
    }

    & azd @envArgs

    # Ensure az CLI is on the correct subscription/tenant for the post-provision hook.
    az account set --subscription $Subscription

    Write-Log 'Deploying FinOps SRE Agent with azd up...'
    azd up --environment $Environment --no-prompt

    Write-Log 'Refreshing local azd outputs...'
    azd env refresh --environment $Environment --no-prompt

    $endpoint = azd env get-value SRE_AGENT_ENDPOINT --environment $Environment --no-prompt 2>$null
    $agentName = azd env get-value SRE_AGENT_NAME --environment $Environment --no-prompt 2>$null

    Write-Log 'Deployment complete.'
    Write-Host "Environment: $Environment"
    Write-Host "Resource group: $ResourceGroup"
    if ($agentName) { Write-Host "Agent name: $agentName" }
    if ($endpoint) { Write-Host "Agent endpoint: $endpoint" }
}
finally {
    Pop-Location
}
