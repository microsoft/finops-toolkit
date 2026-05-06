# Packaged one-shot deployment wrapper for the FinOps toolkit SRE Agent template.
# References:
# - Azure Developer CLI environment workflow:
#   https://learn.microsoft.com/azure/developer/azure-developer-cli/work-with-environments
# - Official Azure SRE Agent repo packaging pattern:
#   https://github.com/microsoft/sre-agent/tree/main/samples/hands-on-lab
# - Azure management locks:
#   https://learn.microsoft.com/azure/azure-resource-manager/management/lock-resources
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
    [string]$EnvFile,
    [string]$CloneEnv,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$PostProvisionMarkerName = 'postprovision.succeeded'
# Bounded eventual-consistency budgets. Connector state changes are usually
# visible quickly after ARM deployment, but ADX principal assignments can lag.
$ConnectorPollAttempts = 30
$ConnectorPollSeconds = 10
$AdxAssignmentPollAttempts = 30
$AdxAssignmentPollSeconds = 10

function Write-Log($Message) { Write-Host "[deploy] $Message" }
function Fail($Message) { throw $Message }

function Get-PostProvisionMarkerPath {
    Join-Path $RepoRoot ".azure/$Environment/$PostProvisionMarkerName"
}

function Clear-PostProvisionMarker {
    $marker = Get-PostProvisionMarkerPath
    Remove-Item -Path $marker -Force -ErrorAction SilentlyContinue
}

function Confirm-PostProvisionMarker {
    $marker = Get-PostProvisionMarkerPath
    if (-not (Test-Path $marker)) {
        Fail "Post-provision success marker was not written by the azure.yaml postprovision hook: $marker"
    }

    $content = Get-Content -Path $marker -ErrorAction Stop
    if ($content -notcontains 'status=success') {
        Fail "Post-provision marker is invalid: $marker"
    }
}

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
  -FinopsHubClusterName <name>           Optional ADX cluster name override when URI lookup is ambiguous.
  -FinopsHubClusterResourceGroup <name>  Optional ADX cluster resource group override.
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

function Normalize-FinopsHubClusterUri {
    if (-not $FinopsHubClusterUri) {
        return
    }

    try {
        $uri = [System.Uri]$FinopsHubClusterUri
    }
    catch {
        Fail '-FinopsHubClusterUri must be a valid HTTPS Azure Data Explorer cluster URI.'
    }

    if ($uri.Scheme -ne 'https') {
        Fail '-FinopsHubClusterUri must be an HTTPS Azure Data Explorer cluster URI.'
    }

    if (-not $uri.Host -or -not $uri.Host.EndsWith('.kusto.windows.net', [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail '-FinopsHubClusterUri must use an Azure Data Explorer host ending in .kusto.windows.net.'
    }

    if (-not $uri.AbsolutePath -or $uri.AbsolutePath -eq '/') {
        Write-Host "[deploy] WARNING: -FinopsHubClusterUri has no database name. Appending '/hub' as default."
        $script:FinopsHubClusterUri = "$($FinopsHubClusterUri.TrimEnd('/'))/hub"
    }

    $script:FinopsHubClusterBaseUri = "https://$($uri.Host)"
}

function Test-ExplicitFinopsHubCluster {
    $clusterId = "/subscriptions/$Subscription/resourceGroups/$FinopsHubClusterResourceGroup/providers/Microsoft.Kusto/clusters/$FinopsHubClusterName"
    $clusterJson = az resource show `
        --ids $clusterId `
        --api-version 2024-04-13 `
        --only-show-errors `
        -o json 2>$null

    if (-not $clusterJson) {
        Fail "FinOps Hub ADX cluster '$FinopsHubClusterName' was not found in resource group '$FinopsHubClusterResourceGroup'."
    }

    $cluster = $clusterJson | ConvertFrom-Json
    if (-not $cluster.properties.uri) {
        Fail "FinOps Hub ADX cluster '$FinopsHubClusterName' did not return a Kusto URI."
    }

    if ($cluster.properties.uri -ine $FinopsHubClusterBaseUri) {
        Fail "FinOps Hub ADX cluster '$FinopsHubClusterName' URI '$($cluster.properties.uri)' does not match '$FinopsHubClusterBaseUri'."
    }

    $script:FinopsHubClusterResourceId = $clusterId
}

function Resolve-FinopsHubCluster {
    if (-not $FinopsHubClusterUri) {
        return
    }

    Normalize-FinopsHubClusterUri

    if (($FinopsHubClusterName -and -not $FinopsHubClusterResourceGroup) -or (-not $FinopsHubClusterName -and $FinopsHubClusterResourceGroup)) {
        Fail 'Provide both -FinopsHubClusterName and -FinopsHubClusterResourceGroup, or provide neither and let the script resolve them from -FinopsHubClusterUri.'
    }

    if ($FinopsHubClusterName) {
        Test-ExplicitFinopsHubCluster
    } else {
        $query = "Resources | where type =~ 'microsoft.kusto/clusters' | where tostring(properties.uri) =~ '$FinopsHubClusterBaseUri' | project name, resourceGroup, id, uri=tostring(properties.uri)"
        $body = @{
            subscriptions = @($Subscription)
            query = $query
        } | ConvertTo-Json -Compress

        $resultJson = az rest `
            --method post `
            --uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' `
            --body $body `
            --only-show-errors `
            -o json 2>$null

        if (-not $resultJson) {
            Fail "Failed to resolve FinOps Hub ADX cluster from '$FinopsHubClusterBaseUri'."
        }

        $result = $resultJson | ConvertFrom-Json
        $clusterMatches = @($result.data)

        if ($clusterMatches.Count -ne 1) {
            Fail "Expected exactly one FinOps Hub ADX cluster with URI '$FinopsHubClusterBaseUri' in subscription '$Subscription'; found $($clusterMatches.Count). Pass -FinopsHubClusterName and -FinopsHubClusterResourceGroup to disambiguate."
        }

        $script:FinopsHubClusterName = $clusterMatches[0].name
        $script:FinopsHubClusterResourceGroup = $clusterMatches[0].resourceGroup
        $script:FinopsHubClusterResourceId = $clusterMatches[0].id
    }

    if (-not $FinopsHubClusterName) { Fail 'Failed to resolve FinOps Hub ADX cluster name.' }
    if (-not $FinopsHubClusterResourceGroup) { Fail 'Failed to resolve FinOps Hub ADX cluster resource group.' }
    if (-not $FinopsHubClusterResourceId) { Fail 'Failed to resolve FinOps Hub ADX cluster resource ID.' }

    Write-Log "Resolved FinOps Hub ADX cluster: $FinopsHubClusterName in resource group $FinopsHubClusterResourceGroup."
}

function Confirm-ScopeHasNoReadOnlyLocks([string]$ScopeId, [string]$Label) {
    $locksJson = az rest `
        --method get `
        --url "https://management.azure.com$ScopeId/providers/Microsoft.Authorization/locks?api-version=2016-09-01" `
        --only-show-errors `
        -o json 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $locksJson) {
        Fail "Failed to inspect Azure management locks on $Label."
    }

    $scopeLockPrefix = "$ScopeId/providers/Microsoft.Authorization/locks/"
    $readOnlyLocks = @((($locksJson | ConvertFrom-Json).value) | Where-Object {
        $_.properties.level -eq 'ReadOnly' -and $_.id.StartsWith($scopeLockPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($readOnlyLocks.Count -gt 0) {
        $details = ($readOnlyLocks | ForEach-Object { "$($_.name) ($($_.id))" }) -join '; '
        Fail "$Label has ReadOnly Azure management lock(s), which block the write operations required to connect the SRE Agent to FinOps Hub ADX: $details. Remove the ReadOnly lock or use an unlocked FinOps Hub scope, then rerun deployment."
    }
}

function Confirm-RequiredWriteScopesUnlocked {
    if (-not $FinopsHubClusterUri) {
        return
    }

    Confirm-ScopeHasNoReadOnlyLocks -ScopeId "/subscriptions/$Subscription" -Label "subscription '$Subscription'"

    $targetResourceGroupExists = az group exists --name $ResourceGroup -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to check whether target resource group '$ResourceGroup' exists."
    }

    if ($targetResourceGroupExists -eq 'true') {
        Confirm-ScopeHasNoReadOnlyLocks -ScopeId "/subscriptions/$Subscription/resourceGroups/$ResourceGroup" -Label "target SRE resource group '$ResourceGroup'"
    }

    Confirm-ScopeHasNoReadOnlyLocks -ScopeId "/subscriptions/$Subscription/resourceGroups/$FinopsHubClusterResourceGroup" -Label "FinOps Hub resource group '$FinopsHubClusterResourceGroup'"
    Confirm-ScopeHasNoReadOnlyLocks -ScopeId $FinopsHubClusterResourceId -Label "FinOps Hub ADX cluster '$FinopsHubClusterName'"
}

function Test-KustoPrincipalAssignment([string]$PrincipalId, [string]$Label) {
    if (-not $PrincipalId) {
        Fail "Missing $Label principal ID for FinOps Hub ADX role verification."
    }

    for ($attempt = 1; $attempt -le $AdxAssignmentPollAttempts; $attempt++) {
        $assignmentCount = az rest `
            --method get `
            --url "https://management.azure.com$FinopsHubClusterResourceId/principalAssignments?api-version=2024-04-13" `
            --query "length(value[?properties.principalId=='$PrincipalId' && properties.role=='AllDatabasesViewer'])" `
            -o tsv 2>$null

        if ($LASTEXITCODE -ne 0) {
            Fail "Failed to verify FinOps Hub ADX role assignments on '$FinopsHubClusterName'."
        }

        if ($assignmentCount -and [int]$assignmentCount -gt 0) {
            return
        }

        if ($attempt -lt $AdxAssignmentPollAttempts) {
            Write-Log "Waiting for ADX AllDatabasesViewer assignment for $Label principal '$PrincipalId' to become visible ($attempt/$AdxAssignmentPollAttempts)..."
            Start-Sleep -Seconds $AdxAssignmentPollSeconds
        }
    }

    Fail "FinOps Hub ADX AllDatabasesViewer role assignment is missing for $Label principal '$PrincipalId' after $AdxAssignmentPollAttempts attempts."
}

function Confirm-FinopsHubConnection([string]$AgentName) {
    if (-not $FinopsHubClusterUri) {
        return
    }

    $agentId = "/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.App/agents/$AgentName"
    $connectorId = "$agentId/connectors/finops-hub-kusto"
    for ($attempt = 1; $attempt -le $ConnectorPollAttempts; $attempt++) {
        $connectorJson = az resource show `
            --ids $connectorId `
            --api-version 2025-05-01-preview `
            --only-show-errors `
            -o json 2>$null

        if (-not $connectorJson -or $LASTEXITCODE -ne 0) {
            Fail 'FinOps Hub Kusto connector resource was not created.'
        }

        $connector = $connectorJson | ConvertFrom-Json

        if ($connector.properties.deploymentError) {
            Fail "FinOps Hub Kusto connector reported deploymentError: $($connector.properties.deploymentError)"
        }

        $connectorState = $connector.properties.provisioningState
        if ($connectorState -eq 'Succeeded') {
            break
        } elseif ($connectorState -in @('Provisioning', 'Updating')) {
            if ($attempt -lt $ConnectorPollAttempts) {
                Write-Log "Waiting for FinOps Hub Kusto connector provisioning state '$connectorState' ($attempt/$ConnectorPollAttempts)..."
                Start-Sleep -Seconds $ConnectorPollSeconds
                continue
            }
            Fail "Timed out waiting for FinOps Hub Kusto connector to succeed; last state was '$connectorState'."
        } elseif ($connectorState -in @('Failed', 'Canceled')) {
            Fail "FinOps Hub Kusto connector provisioning state is '$connectorState'."
        } else {
            Fail "FinOps Hub Kusto connector provisioning state is '$connectorState', expected 'Succeeded'."
        }
    }

    $uamiPrincipalId = azd env get-value IDENTITY_PRINCIPAL_ID --environment $Environment --no-prompt 2>$null
    $systemPrincipalId = az resource show `
        --ids $agentId `
        --api-version 2025-05-01-preview `
        --query identity.principalId `
        -o tsv 2>$null

    Test-KustoPrincipalAssignment -PrincipalId $uamiPrincipalId -Label 'user-assigned managed identity'
    Test-KustoPrincipalAssignment -PrincipalId $systemPrincipalId -Label 'system-assigned managed identity'

    Write-Log 'Verified FinOps Hub Kusto connector and ADX AllDatabasesViewer assignments.'
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

# Resource group defaults to the environment name unless explicitly overridden.
$ResourceGroupExplicit = $PSBoundParameters.ContainsKey('ResourceGroup')
if (-not $ResourceGroupExplicit) { $ResourceGroup = $Environment }

if (-not $Environment) { Fail '-Environment is required.' }

if (-not $Subscription) { Fail 'Azure subscription could not be resolved. Use -Subscription or sign in with az.' }

# Validate URI syntax before any Azure CLI calls. Existence resolution still
# happens after the subscription context is selected.
Normalize-FinopsHubClusterUri

# Resolve the active Azure context before any customer-visible deployment work.
# Existing FinOps Hub connections are a hard contract: if a URI is supplied, the
# deployment must resolve the ADX cluster and wire role assignments or fail.
az account set --subscription $Subscription
if ($LASTEXITCODE -ne 0) { Fail "Failed to set Azure CLI subscription context to '$Subscription'." }
Resolve-FinopsHubCluster
Confirm-RequiredWriteScopesUnlocked

if (-not $FinopsHubClusterUri) {
    Write-Log 'WARNING: No FinOps hub cluster URI provided. Kusto connector will not be configured. You can connect a hub later.'
}

Push-Location $RepoRoot
try {
    if (-not (Test-EnvExists -Name $Environment)) {
        Write-Log "Creating azd environment $Environment..."
        azd env new $Environment --subscription $Subscription --location $Location --no-prompt
        if ($LASTEXITCODE -ne 0) { Fail "Failed to create azd environment '$Environment'." }
    } else {
        Write-Log "Selecting existing azd environment $Environment..."
        azd env select $Environment
        if ($LASTEXITCODE -ne 0) { Fail "Failed to select azd environment '$Environment'." }
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
        "DEPLOY_FINOPS_HUB=false"
    )

    if ($FinopsHubClusterName) {
        $envArgs += "FINOPS_HUB_CLUSTER_NAME=$FinopsHubClusterName"
    }

    if ($FinopsHubClusterResourceGroup) {
        $envArgs += "FINOPS_HUB_CLUSTER_RESOURCE_GROUP=$FinopsHubClusterResourceGroup"
    }

    & azd @envArgs
    if ($LASTEXITCODE -ne 0) { Fail 'Failed to set azd environment values.' }

    Write-Log 'Deploying FinOps toolkit SRE Agent with azd up...'
    Clear-PostProvisionMarker
    azd up --environment $Environment --no-prompt
    if ($LASTEXITCODE -ne 0) { Fail 'azd up failed.' }

    Write-Log 'Refreshing local azd outputs...'
    azd env refresh --environment $Environment --no-prompt
    if ($LASTEXITCODE -ne 0) { Fail 'azd env refresh failed.' }

    Confirm-PostProvisionMarker

    $endpoint = azd env get-value SRE_AGENT_ENDPOINT --environment $Environment --no-prompt 2>$null
    $agentName = azd env get-value SRE_AGENT_NAME --environment $Environment --no-prompt 2>$null

    if (-not $agentName) { Fail 'SRE_AGENT_NAME output was not populated.' }
    Confirm-FinopsHubConnection -AgentName $agentName

    Write-Log 'Deployment complete.'
    Write-Host "Environment: $Environment"
    Write-Host "Resource group: $ResourceGroup"
    if ($agentName) { Write-Host "Agent name: $agentName" }
    if ($endpoint) { Write-Host "Agent endpoint: $endpoint" }
}
finally {
    Pop-Location
}
