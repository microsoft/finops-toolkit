#!/usr/bin/env bash
# Packaged one-shot deployment wrapper for the FinOps SRE Agent template.
# References:
# - Azure Developer CLI environment workflow:
#   https://learn.microsoft.com/azure/developer/azure-developer-cli/work-with-environments
# - Official Azure SRE Agent repo packaging pattern:
#   https://github.com/microsoft/sre-agent/tree/main/samples/hands-on-lab

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { printf '[deploy] %s\n' "$*"; }
fail() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  bash ./scripts/deploy.sh --environment <name> [options]

Deployment modes:
  Agent only:           omit --finops-hub-cluster-uri and --deploy-hub
  Agent + existing hub: set --finops-hub-cluster-uri
  Agent + new hub:      set --deploy-hub (optionally --hub-sku)

Options:
  --environment <name>                    Target azd environment name.
  --location <region>                     Azure location. Default: eastus2.
  --subscription <subscription-id>        Azure subscription ID. Defaults to current az account.
  --resource-group <name>                 Azure resource group. Defaults to the environment name.
  --principal-type <type>                 Deployer principal type. Default: User.
  --finops-hub-cluster-uri <uri>          Optional. Existing FinOps Hub Kusto cluster URI.
  --finops-hub-cluster-name <name>        Optional. ADX cluster name for AllDatabasesViewer (external hub).
  --finops-hub-cluster-resource-group <name>
                                           Optional. ADX cluster resource group (external hub).
  --deploy-hub                            Deploy a FinOps hub alongside the SRE agent.
  --hub-sku <sku>                         ADX SKU for the deployed hub. Default: Standard_E2ads_v5.
  --env-file <path>                       Load azd-style values from a .env file before applying overrides.
  --clone-env <name>                      Load values from .azure/<name>/.env before applying overrides.
  -h, --help                              Show this help.

Examples:
  # Agent only
  bash ./scripts/deploy.sh --environment ftk-sre-demo

  # Agent + existing hub
  bash ./scripts/deploy.sh --environment ftk-sre-demo \
    --finops-hub-cluster-uri https://cluster.region.kusto.windows.net

  # Agent + new hub (batteries included)
  bash ./scripts/deploy.sh --environment ftk-sre-demo --deploy-hub
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

load_env_file() {
  local file="$1"
  [ -f "$file" ] || fail "Environment file not found: $file"
  # shellcheck disable=SC1090
  set -a
  source "$file"
  set +a
}

env_exists() {
  [ -d "$REPO_ROOT/.azure/$1" ]
}

current_subscription() {
  az account show --query id -o tsv 2>/dev/null || true
}

ENV_NAME=''
LOCATION=''
SUBSCRIPTION=''
RESOURCE_GROUP=''
RESOURCE_GROUP_EXPLICIT=false
PRINCIPAL_TYPE=''
FINOPS_HUB_CLUSTER_URI=''
FINOPS_HUB_CLUSTER_NAME=''
FINOPS_HUB_CLUSTER_RESOURCE_GROUP=''
ENV_FILE=''
CLONE_ENV=''
DEPLOY_HUB=false
HUB_SKU='Standard_E2ads_v5'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      ENV_NAME="${2:-}"; shift 2 ;;
    --location)
      LOCATION="${2:-}"; shift 2 ;;
    --subscription)
      SUBSCRIPTION="${2:-}"; shift 2 ;;
    --resource-group)
      RESOURCE_GROUP="${2:-}"; RESOURCE_GROUP_EXPLICIT=true; shift 2 ;;
    --principal-type)
      PRINCIPAL_TYPE="${2:-}"; shift 2 ;;
    --finops-hub-cluster-uri)
      FINOPS_HUB_CLUSTER_URI="${2:-}"; shift 2 ;;
    --finops-hub-cluster-name)
      FINOPS_HUB_CLUSTER_NAME="${2:-}"; shift 2 ;;
    --finops-hub-cluster-resource-group)
      FINOPS_HUB_CLUSTER_RESOURCE_GROUP="${2:-}"; shift 2 ;;
    --deploy-hub)
      DEPLOY_HUB=true; shift ;;
    --hub-sku)
      HUB_SKU="${2:-}"; shift 2 ;;
    --env-file)
      ENV_FILE="${2:-}"; shift 2 ;;
    --clone-env)
      CLONE_ENV="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown argument: $1" ;;
  esac
done

require_command az
require_command azd
require_command dotnet
require_command python3

[ -n "$ENV_FILE" ] && [ -n "$CLONE_ENV" ] && fail "Use either --env-file or --clone-env, not both."

if [ -n "$ENV_FILE" ]; then
  load_env_file "$ENV_FILE"
fi

if [ -n "$CLONE_ENV" ]; then
  load_env_file "$REPO_ROOT/.azure/$CLONE_ENV/.env"
  # Unset identity vars so the cloned env doesn't override the new environment name/RG.
  # Connection values (FINOPS_HUB_*) are preserved — that's why we cloned.
  unset AZURE_ENV_NAME AZURE_RESOURCE_GROUP SRE_AGENT_ENDPOINT SRE_AGENT_NAME 2>/dev/null || true
fi

ENV_NAME="${ENV_NAME:-${AZURE_ENV_NAME:-}}"
LOCATION="${LOCATION:-${AZURE_LOCATION:-eastus2}}"
SUBSCRIPTION="${SUBSCRIPTION:-${AZURE_SUBSCRIPTION_ID:-$(current_subscription)}}"
PRINCIPAL_TYPE="${PRINCIPAL_TYPE:-${AZURE_PRINCIPAL_TYPE:-User}}"
FINOPS_HUB_CLUSTER_URI="${FINOPS_HUB_CLUSTER_URI:-${FINOPS_HUB_CLUSTER_URI_FROM_ENV:-}}"
FINOPS_HUB_CLUSTER_NAME="${FINOPS_HUB_CLUSTER_NAME:-${FINOPS_HUB_CLUSTER_NAME_FROM_ENV:-}}"
FINOPS_HUB_CLUSTER_RESOURCE_GROUP="${FINOPS_HUB_CLUSTER_RESOURCE_GROUP:-${FINOPS_HUB_CLUSTER_RESOURCE_GROUP_FROM_ENV:-}}"

# Resource group defaults to the environment name unless explicitly overridden.
# This prevents cloned envs from leaking their resource group name into a new deployment.
if ! $RESOURCE_GROUP_EXPLICIT; then
  RESOURCE_GROUP="${ENV_NAME}"
fi

[ -n "$ENV_NAME" ] || fail "--environment is required."

[ -n "$SUBSCRIPTION" ] || fail "Azure subscription could not be resolved. Use --subscription or sign in with az."
if $DEPLOY_HUB && [ -n "$FINOPS_HUB_CLUSTER_URI" ]; then
  fail "--deploy-hub and --finops-hub-cluster-uri are mutually exclusive. Use one or the other."
fi
if ! $DEPLOY_HUB && [ -z "$FINOPS_HUB_CLUSTER_URI" ]; then
  log "Deploying agent only — no FinOps hub. Kusto connector will not be configured."
fi

cd "$REPO_ROOT"

if ! env_exists "$ENV_NAME"; then
  log "Creating azd environment $ENV_NAME..."
  azd env new "$ENV_NAME" --subscription "$SUBSCRIPTION" --location "$LOCATION" --no-prompt
else
  log "Selecting existing azd environment $ENV_NAME..."
  azd env select "$ENV_NAME"
fi

log "Setting azd environment values..."
env_args=(
  --environment "$ENV_NAME"
  "AZURE_ENV_NAME=$ENV_NAME"
  "AZURE_LOCATION=$LOCATION"
  "AZURE_PRINCIPAL_TYPE=$PRINCIPAL_TYPE"
  "AZURE_RESOURCE_GROUP=$RESOURCE_GROUP"
  "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION"
  "FINOPS_HUB_CLUSTER_URI=$FINOPS_HUB_CLUSTER_URI"
  "DEPLOY_FINOPS_HUB=$DEPLOY_HUB"
  "FINOPS_HUB_DATA_EXPLORER_SKU=$HUB_SKU"
)

if [ -n "$FINOPS_HUB_CLUSTER_NAME" ]; then
  env_args+=("FINOPS_HUB_CLUSTER_NAME=$FINOPS_HUB_CLUSTER_NAME")
fi

if [ -n "$FINOPS_HUB_CLUSTER_RESOURCE_GROUP" ]; then
  env_args+=("FINOPS_HUB_CLUSTER_RESOURCE_GROUP=$FINOPS_HUB_CLUSTER_RESOURCE_GROUP")
fi

azd env set "${env_args[@]}"

# Ensure az CLI is on the correct subscription/tenant for the post-provision hook.
# In B2B environments the default az context may be in a different tenant,
# causing srectl to get 403 during the postprovision hook.
log "Setting az CLI subscription context..."
az account set --subscription "$SUBSCRIPTION"

log "Deploying FinOps SRE Agent with azd up..."
azd up --environment "$ENV_NAME" --no-prompt

log "Refreshing local azd outputs..."
azd env refresh --environment "$ENV_NAME" --no-prompt

endpoint="$(azd env get-value SRE_AGENT_ENDPOINT --environment "$ENV_NAME" --no-prompt 2>/dev/null || true)"
agent_name="$(azd env get-value SRE_AGENT_NAME --environment "$ENV_NAME" --no-prompt 2>/dev/null || true)"

log "Deployment complete."
printf 'Environment: %s\n' "$ENV_NAME"
printf 'Resource group: %s\n' "$RESOURCE_GROUP"
[ -n "$agent_name" ] && printf 'Agent name: %s\n' "$agent_name"
[ -n "$endpoint" ] && printf 'Agent endpoint: %s\n' "$endpoint"
