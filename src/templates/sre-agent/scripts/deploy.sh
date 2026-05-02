#!/usr/bin/env bash
# Packaged one-shot deployment wrapper for the FinOps SRE Agent template.
# References:
# - Azure Developer CLI environment workflow:
#   https://learn.microsoft.com/azure/developer/azure-developer-cli/work-with-environments
# - Official Azure SRE Agent repo packaging pattern:
#   https://github.com/microsoft/sre-agent/tree/main/samples/hands-on-lab
# - Azure management locks:
#   https://learn.microsoft.com/azure/azure-resource-manager/management/lock-resources

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POST_PROVISION_MARKER_NAME="postprovision.succeeded"
# Bounded eventual-consistency budgets. Connector state changes are usually
# visible quickly after ARM deployment, but ADX principal assignments can lag.
CONNECTOR_POLL_ATTEMPTS=30
CONNECTOR_POLL_SECONDS=10
ADX_ASSIGNMENT_POLL_ATTEMPTS=30
ADX_ASSIGNMENT_POLL_SECONDS=10

log() { printf '[deploy] %s\n' "$*"; }
fail() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  bash ./scripts/deploy.sh --environment <name> [options]

Deployment modes:
  Agent only:           omit --finops-hub-cluster-uri
  Agent + existing hub: set --finops-hub-cluster-uri

Options:
  --environment <name>                    Target azd environment name.
  --location <region>                     Azure location. Default: eastus2.
  --subscription <subscription-id>        Azure subscription ID. Defaults to current az account.
  --resource-group <name>                 Azure resource group. Defaults to the environment name.
  --principal-type <type>                 Deployer principal type. Default: User.
  --finops-hub-cluster-uri <uri>          Optional. Existing FinOps Hub Kusto cluster URI
                                           (must include database name, e.g.
                                           https://cluster.region.kusto.windows.net/hub).
                                           If the database suffix is missing, '/hub' is appended.
  --finops-hub-cluster-name <name>        Optional. ADX cluster name override when URI lookup is ambiguous.
  --finops-hub-cluster-resource-group <name>
                                           Optional. ADX cluster resource group override.
  --env-file <path>                       Load azd-style values from a .env file before applying overrides.
  --clone-env <name>                      Load values from .azure/<name>/.env before applying overrides.
  -h, --help                              Show this help.

Examples:
  # Agent only
  bash ./scripts/deploy.sh --environment ftk-sre-demo

  # Agent + existing hub
  bash ./scripts/deploy.sh --environment ftk-sre-demo \
    --finops-hub-cluster-uri https://cluster.region.kusto.windows.net

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

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

post_provision_marker_path() {
  printf '%s/.azure/%s/%s' "$REPO_ROOT" "$ENV_NAME" "$POST_PROVISION_MARKER_NAME"
}

clear_post_provision_marker() {
  rm -f "$(post_provision_marker_path)"
}

verify_post_provision_marker() {
  local marker
  marker="$(post_provision_marker_path)"
  [ -f "$marker" ] || fail "Post-provision success marker was not written by the azure.yaml postprovision hook: $marker"
  grep -q '^status=success$' "$marker" || fail "Post-provision marker is invalid: $marker"
}

normalize_finops_hub_cluster_uri() {
  [ -n "$FINOPS_HUB_CLUSTER_URI" ] || return 0

  case "$FINOPS_HUB_CLUSTER_URI" in
    https://*) ;;
    *) fail "--finops-hub-cluster-uri must be an HTTPS Azure Data Explorer cluster URI." ;;
  esac

  local uri_without_scheme host uri_path
  uri_without_scheme="${FINOPS_HUB_CLUSTER_URI#https://}"
  host="${uri_without_scheme%%/*}"
  [ -n "$host" ] || fail "--finops-hub-cluster-uri is missing a host name."

  case "$host" in
    *.kusto.windows.net) ;;
    *) fail "--finops-hub-cluster-uri must use an Azure Data Explorer host ending in .kusto.windows.net." ;;
  esac

  uri_path="${uri_without_scheme#*/}"
  if [ -z "$uri_path" ] || [ "$uri_path" = "$uri_without_scheme" ]; then
    log "WARNING: --finops-hub-cluster-uri has no database name. Appending '/hub' as default."
    FINOPS_HUB_CLUSTER_URI="${FINOPS_HUB_CLUSTER_URI%/}/hub"
  fi

  FINOPS_HUB_CLUSTER_BASE_URI="https://$host"
}

validate_explicit_finops_hub_cluster() {
  local cluster_id actual_uri
  cluster_id="/subscriptions/${SUBSCRIPTION}/resourceGroups/${FINOPS_HUB_CLUSTER_RESOURCE_GROUP}/providers/Microsoft.Kusto/clusters/${FINOPS_HUB_CLUSTER_NAME}"
  actual_uri="$(
    az resource show \
      --ids "$cluster_id" \
      --api-version 2024-04-13 \
      --query properties.uri \
      -o tsv 2>/dev/null
  )" || fail "FinOps Hub ADX cluster '$FINOPS_HUB_CLUSTER_NAME' was not found in resource group '$FINOPS_HUB_CLUSTER_RESOURCE_GROUP'."

  [ -n "$actual_uri" ] || fail "FinOps Hub ADX cluster '$FINOPS_HUB_CLUSTER_NAME' did not return a Kusto URI."

  if [ "$(lower "$actual_uri")" != "$(lower "$FINOPS_HUB_CLUSTER_BASE_URI")" ]; then
    fail "FinOps Hub ADX cluster '$FINOPS_HUB_CLUSTER_NAME' URI '$actual_uri' does not match '$FINOPS_HUB_CLUSTER_BASE_URI'."
  fi

  FINOPS_HUB_CLUSTER_RESOURCE_ID="$cluster_id"
}

resolve_finops_hub_cluster() {
  [ -n "$FINOPS_HUB_CLUSTER_URI" ] || return 0

  normalize_finops_hub_cluster_uri

  if { [ -n "$FINOPS_HUB_CLUSTER_NAME" ] && [ -z "$FINOPS_HUB_CLUSTER_RESOURCE_GROUP" ]; } ||
     { [ -z "$FINOPS_HUB_CLUSTER_NAME" ] && [ -n "$FINOPS_HUB_CLUSTER_RESOURCE_GROUP" ]; }; then
    fail "Provide both --finops-hub-cluster-name and --finops-hub-cluster-resource-group, or provide neither and let the script resolve them from --finops-hub-cluster-uri."
  fi

  if [ -n "$FINOPS_HUB_CLUSTER_NAME" ]; then
    validate_explicit_finops_hub_cluster
  else
    local query body result_count resolved
    query="Resources | where type =~ 'microsoft.kusto/clusters' | where tostring(properties.uri) =~ '$(json_escape "$FINOPS_HUB_CLUSTER_BASE_URI")' | project name, resourceGroup, id, uri=tostring(properties.uri)"
    body="{\"subscriptions\":[\"$(json_escape "$SUBSCRIPTION")\"],\"query\":\"$(json_escape "$query")\"}"

    result_count="$(
      az rest \
        --method post \
        --uri "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" \
        --body "$body" \
        --query 'length(data)' \
        -o tsv 2>/dev/null
    )" || fail "Failed to resolve FinOps Hub ADX cluster from '$FINOPS_HUB_CLUSTER_BASE_URI'."

    [ "$result_count" = "1" ] || fail "Expected exactly one FinOps Hub ADX cluster with URI '$FINOPS_HUB_CLUSTER_BASE_URI' in subscription '$SUBSCRIPTION'; found $result_count. Pass --finops-hub-cluster-name and --finops-hub-cluster-resource-group to disambiguate."

    resolved="$(
      az rest \
        --method post \
        --uri "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" \
        --body "$body" \
        --query 'data[0].{name:name,resourceGroup:resourceGroup,id:id}' \
        -o tsv
    )" || fail "Failed to read resolved FinOps Hub ADX cluster details."

    read -r FINOPS_HUB_CLUSTER_NAME FINOPS_HUB_CLUSTER_RESOURCE_GROUP FINOPS_HUB_CLUSTER_RESOURCE_ID <<<"$resolved"
  fi

  [ -n "$FINOPS_HUB_CLUSTER_NAME" ] || fail "Failed to resolve FinOps Hub ADX cluster name."
  [ -n "$FINOPS_HUB_CLUSTER_RESOURCE_GROUP" ] || fail "Failed to resolve FinOps Hub ADX cluster resource group."
  [ -n "$FINOPS_HUB_CLUSTER_RESOURCE_ID" ] || fail "Failed to resolve FinOps Hub ADX cluster resource ID."

  log "Resolved FinOps Hub ADX cluster: $FINOPS_HUB_CLUSTER_NAME in resource group $FINOPS_HUB_CLUSTER_RESOURCE_GROUP."
}

verify_scope_has_no_readonly_locks() {
  local scope_id="$1"
  local label="$2"
  local read_only_locks scoped_read_only_locks lock_name lock_id

  read_only_locks="$(
    az rest \
      --method get \
      --url "https://management.azure.com${scope_id}/providers/Microsoft.Authorization/locks?api-version=2016-09-01" \
      --query "value[?properties.level=='ReadOnly'].[name,id]" \
      -o tsv 2>/dev/null
  )" || fail "Failed to inspect Azure management locks on $label."

  scoped_read_only_locks=''
  while IFS=$'\t' read -r lock_name lock_id; do
    [ -n "$lock_id" ] || continue
    case "$lock_id" in
      "${scope_id}/providers/Microsoft.Authorization/locks/"*)
        scoped_read_only_locks="${scoped_read_only_locks}${lock_name} ${lock_id}"$'\n'
        ;;
    esac
  done <<<"$read_only_locks"

  if [ -n "$scoped_read_only_locks" ]; then
    fail "$label has ReadOnly Azure management lock(s), which block the write operations required to connect the SRE Agent to FinOps Hub ADX: $(printf '%s' "$scoped_read_only_locks" | tr '\n' '; '). Remove the ReadOnly lock or use an unlocked FinOps Hub scope, then rerun deployment."
  fi
}

verify_required_write_scopes_unlocked() {
  [ -n "$FINOPS_HUB_CLUSTER_URI" ] || return 0

  local target_resource_group_exists
  verify_scope_has_no_readonly_locks "/subscriptions/${SUBSCRIPTION}" "subscription '$SUBSCRIPTION'"

  target_resource_group_exists="$(az group exists --name "$RESOURCE_GROUP" -o tsv 2>/dev/null)" || fail "Failed to check whether target resource group '$RESOURCE_GROUP' exists."
  if [ "$target_resource_group_exists" = "true" ]; then
    verify_scope_has_no_readonly_locks "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}" "target SRE resource group '$RESOURCE_GROUP'"
  fi

  verify_scope_has_no_readonly_locks "/subscriptions/${SUBSCRIPTION}/resourceGroups/${FINOPS_HUB_CLUSTER_RESOURCE_GROUP}" "FinOps Hub resource group '$FINOPS_HUB_CLUSTER_RESOURCE_GROUP'"
  verify_scope_has_no_readonly_locks "$FINOPS_HUB_CLUSTER_RESOURCE_ID" "FinOps Hub ADX cluster '$FINOPS_HUB_CLUSTER_NAME'"
}

verify_kusto_principal_assignment() {
  local principal_id="$1"
  local label="$2"
  local assignment_count attempt

  [ -n "$principal_id" ] || fail "Missing $label principal ID for FinOps Hub ADX role verification."

  for ((attempt = 1; attempt <= ADX_ASSIGNMENT_POLL_ATTEMPTS; attempt++)); do
    assignment_count="$(
      az rest \
        --method get \
        --url "https://management.azure.com${FINOPS_HUB_CLUSTER_RESOURCE_ID}/principalAssignments?api-version=2024-04-13" \
        --query "length(value[?properties.principalId=='${principal_id}' && properties.role=='AllDatabasesViewer'])" \
        -o tsv 2>/dev/null
    )" || fail "Failed to verify FinOps Hub ADX role assignments on '$FINOPS_HUB_CLUSTER_NAME'."

    if [ "${assignment_count:-0}" != "0" ]; then
      return 0
    fi

    if [ "$attempt" -lt "$ADX_ASSIGNMENT_POLL_ATTEMPTS" ]; then
      log "Waiting for ADX AllDatabasesViewer assignment for $label principal '$principal_id' to become visible ($attempt/$ADX_ASSIGNMENT_POLL_ATTEMPTS)..."
      sleep "$ADX_ASSIGNMENT_POLL_SECONDS"
    fi
  done

  fail "FinOps Hub ADX AllDatabasesViewer role assignment is missing for $label principal '$principal_id' after ${ADX_ASSIGNMENT_POLL_ATTEMPTS} attempts."
}

verify_finops_hub_connection() {
  local agent_name="$1"
  [ -n "$FINOPS_HUB_CLUSTER_URI" ] || return 0

  local agent_id connector_id connector_state connector_error uami_principal_id system_principal_id attempt
  agent_id="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/agents/${agent_name}"
  connector_id="${agent_id}/connectors/finops-hub-kusto"

  for ((attempt = 1; attempt <= CONNECTOR_POLL_ATTEMPTS; attempt++)); do
    connector_state="$(
      az resource show \
        --ids "$connector_id" \
        --api-version 2025-05-01-preview \
        --query 'properties.provisioningState' \
        -o tsv 2>/dev/null
    )" || fail "FinOps Hub Kusto connector resource was not created."

    connector_error="$(
      az resource show \
        --ids "$connector_id" \
        --api-version 2025-05-01-preview \
        --query 'properties.deploymentError' \
        -o tsv 2>/dev/null
    )" || fail "Failed to read FinOps Hub Kusto connector deploymentError."

    [ -z "$connector_error" ] || fail "FinOps Hub Kusto connector reported deploymentError: $connector_error"

    case "$connector_state" in
      Succeeded)
        break
        ;;
      Provisioning|Updating)
        if [ "$attempt" -lt "$CONNECTOR_POLL_ATTEMPTS" ]; then
          log "Waiting for FinOps Hub Kusto connector provisioning state '$connector_state' ($attempt/$CONNECTOR_POLL_ATTEMPTS)..."
          sleep "$CONNECTOR_POLL_SECONDS"
          continue
        fi
        fail "Timed out waiting for FinOps Hub Kusto connector to succeed; last state was '$connector_state'."
        ;;
      Failed|Canceled)
        fail "FinOps Hub Kusto connector provisioning state is '$connector_state'."
        ;;
      *)
        fail "FinOps Hub Kusto connector provisioning state is '$connector_state', expected 'Succeeded'."
        ;;
    esac
  done

  uami_principal_id="$(azd env get-value IDENTITY_PRINCIPAL_ID --environment "$ENV_NAME" --no-prompt 2>/dev/null || true)"
  system_principal_id="$(
    az resource show \
      --ids "$agent_id" \
      --api-version 2025-05-01-preview \
      --query identity.principalId \
      -o tsv 2>/dev/null
  )" || fail "Failed to read SRE Agent system-assigned principal ID."

  verify_kusto_principal_assignment "$uami_principal_id" "user-assigned managed identity"
  verify_kusto_principal_assignment "$system_principal_id" "system-assigned managed identity"

  log "Verified FinOps Hub Kusto connector and ADX AllDatabasesViewer assignments."
}

ENV_NAME=''
LOCATION=''
SUBSCRIPTION=''
RESOURCE_GROUP=''
RESOURCE_GROUP_EXPLICIT=false
PRINCIPAL_TYPE=''
FINOPS_HUB_CLUSTER_URI="${FINOPS_HUB_CLUSTER_URI:-}"
FINOPS_HUB_CLUSTER_BASE_URI=''
FINOPS_HUB_CLUSTER_NAME="${FINOPS_HUB_CLUSTER_NAME:-}"
FINOPS_HUB_CLUSTER_RESOURCE_GROUP="${FINOPS_HUB_CLUSTER_RESOURCE_GROUP:-}"
FINOPS_HUB_CLUSTER_RESOURCE_ID=''
ENV_FILE=''
CLONE_ENV=''

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

# Validate URI syntax before any Azure CLI calls. Existence resolution still
# happens after the subscription context is selected.
normalize_finops_hub_cluster_uri

# Resolve the active Azure context before any customer-visible deployment work.
# Existing FinOps Hub connections are a hard contract: if a URI is supplied, the
# deployment must resolve the ADX cluster and wire role assignments or fail.
log "Setting az CLI subscription context..."
az account set --subscription "$SUBSCRIPTION"
resolve_finops_hub_cluster
verify_required_write_scopes_unlocked

if [ -z "$FINOPS_HUB_CLUSTER_URI" ]; then
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
  "DEPLOY_FINOPS_HUB=false"
)

if [ -n "$FINOPS_HUB_CLUSTER_NAME" ]; then
  env_args+=("FINOPS_HUB_CLUSTER_NAME=$FINOPS_HUB_CLUSTER_NAME")
fi

if [ -n "$FINOPS_HUB_CLUSTER_RESOURCE_GROUP" ]; then
  env_args+=("FINOPS_HUB_CLUSTER_RESOURCE_GROUP=$FINOPS_HUB_CLUSTER_RESOURCE_GROUP")
fi

azd env set "${env_args[@]}"

log "Deploying FinOps SRE Agent with azd up..."
clear_post_provision_marker
azd up --environment "$ENV_NAME" --no-prompt

log "Refreshing local azd outputs..."
azd env refresh --environment "$ENV_NAME" --no-prompt

verify_post_provision_marker

endpoint="$(azd env get-value SRE_AGENT_ENDPOINT --environment "$ENV_NAME" --no-prompt 2>/dev/null || true)"
agent_name="$(azd env get-value SRE_AGENT_NAME --environment "$ENV_NAME" --no-prompt 2>/dev/null || true)"

[ -n "$agent_name" ] || fail "SRE_AGENT_NAME output was not populated."
verify_finops_hub_connection "$agent_name"

log "Deployment complete."
printf 'Environment: %s\n' "$ENV_NAME"
printf 'Resource group: %s\n' "$RESOURCE_GROUP"
[ -n "$agent_name" ] && printf 'Agent name: %s\n' "$agent_name"
[ -n "$endpoint" ] && printf 'Agent endpoint: %s\n' "$endpoint"
