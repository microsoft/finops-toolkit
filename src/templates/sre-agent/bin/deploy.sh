#!/usr/bin/env bash
# =============================================================================
# deploy.sh - FinOps Toolkit SRE Agent setup
#
# Copied from microsoft/sre-agent labs/starter-lab/scripts/setup.sh and updated
# for this template:
#   - uses Azure CLI + Bicep directly, not azd
#   - deploys the FinOps SRE Agent infrastructure only, not the Grubify lab app
#   - applies non-Bicep recipe assets with apply-extras after ARM succeeds
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="${PROJECT_DIR}/infra"

usage() {
  cat <<EOF
Usage: bash bin/deploy.sh --recipe <dir> [options]

Required:
  --recipe <dir>                      Recipe directory
  --subscription <id>                 Azure subscription
  -g, --resource-group <name>         Resource group for the agent
  -n, --name <name>                   Agent name
  -l, --location <region>             Azure region

Optional:
  --target-resource-group <name>      Repeatable target resource group. The agent resource group is always included.
  --cluster-uri <uri>                 Kusto connector URI, including database name.
                                      Example: https://<cluster>.<region>.kusto.windows.net/Hub
  --cluster-resource-id <id>          Optional Kusto cluster ARM resource ID. Real deployments resolve this from --cluster-uri when possible; dry-run requires it.
  --deploy-name <name>                Deployment name override. Defaults to a deterministic name.
  --dry-run                           Validate inputs and write parameters without Azure calls.
  --force                             Accepted for compatibility.
  --fallback-srectl                   Accepted for compatibility; ignored.
  --no-telemetry                      Accepted for compatibility.
  -h, --help                          Show this help.
EOF
  exit "${1:-0}"
}

fail() {
  echo -e "${RED}$1${NC}" >&2
  exit "${2:-1}"
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == -* ]]; then
    fail "Error: flag ${flag} requires a value" 2
  fi
}

recipe_value() {
  local file="$1"
  local path="$2"
  jq -r "$path // empty | if . == null or . == \"null\" then \"\" else . end" "$file"
}

deterministic_deploy_name() {
  "$PYTHON_CMD" - "$SUBSCRIPTION_ID" "$RESOURCE_GROUP" "$AGENT_NAME" <<'PY'
import hashlib
import re
import sys

subscription_id, resource_group, agent_name = sys.argv[1:4]
resource_group_id = f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}"
seed = f"{subscription_id}|{resource_group_id}|{agent_name}".lower()
slug = re.sub(r"[^a-z0-9-]+", "-", agent_name.lower()).strip("-") or "agent"
digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()[:12]
name = f"sre-agent-{slug}-{digest}"
print(name[:64].rstrip("-"))
PY
}

deployment_output_value() {
  local file="$1"
  local key="$2"
  local default="${3:-}"
  jq -r \
    --arg key "$key" \
    --arg default "$default" \
    '(.properties.outputs // {})
      | to_entries
      | map(select((.key | ascii_upcase) == ($key | ascii_upcase)) | .value.value)
      | first // $default' \
    "$file"
}

normalize_action_mode() {
  case "$1" in
    Autonomous|autonomous|Automatic|automatic) printf 'autonomous' ;;
    Review|review) printf 'review' ;;
    ReadOnly|readOnly|readonly) printf 'readOnly' ;;
    *) fail "Error: unsupported action mode '$1'" 2 ;;
  esac
}

validate_kusto_uri() {
  local uri="$1"
  [[ -z "$uri" ]] && return 0
  if [[ "$uri" != https://*.kusto.windows.net/* ]]; then
    fail "Error: --cluster-uri must be a database-qualified Kusto URI. Example: https://<cluster>.<region>.kusto.windows.net/Hub" 2
  fi
  local path="${uri#https://}"
  if [[ "$path" != */* || -z "${path#*/}" ]]; then
    fail "Error: --cluster-uri must include the Kusto database name. Example: https://<cluster>.<region>.kusto.windows.net/Hub" 2
  fi
}

parse_kusto_cluster_name() {
  local uri="$1"
  local host
  host="${uri#https://}"
  host="${host%%/*}"
  printf '%s\n' "${host%%.*}"
}

parse_kusto_database_name() {
  local uri="$1"
  local path
  path="${uri#https://}"
  path="${path#*/}"
  path="${path%%\?*}"
  path="${path%%#*}"
  printf '%s\n' "${path%%/*}"
}

to_lower() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

append_target_rg() {
  local rg="$1"
  local existing
  [[ -n "$rg" ]] || return 0
  if [[ "${#TARGET_RGS[@]}" -gt 0 ]]; then
    for existing in "${TARGET_RGS[@]}"; do
      if [[ "$(to_lower "$existing")" == "$(to_lower "$rg")" ]]; then
        return 0
      fi
    done
  fi
  TARGET_RGS+=("$rg")
}

resource_id_subscription() {
  local resource_id="$1"
  printf '%s\n' "$resource_id" | awk -F/ '{print $3}'
}

resource_id_resource_group() {
  local resource_id="$1"
  printf '%s\n' "$resource_id" | awk -F/ '{print $5}'
}

resolve_kusto_cluster_resource_id() {
  local uri="$1"
  local cluster_name
  local cluster_uri
  local resource_id
  local graph_result_count

  cluster_name="$(parse_kusto_cluster_name "$uri")"
  [[ -n "$cluster_name" ]] || fail "Error: could not parse Kusto cluster name from --cluster-uri" 2
  cluster_uri="${uri%/*}"

  resource_id="$(az resource list \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-type Microsoft.Kusto/clusters \
    --query "[?name=='${cluster_name}'].id | [0]" \
    -o tsv 2>/dev/null || true)"

  if [[ -n "$resource_id" && "$resource_id" != "null" ]]; then
    printf '%s\n' "$resource_id"
    return 0
  fi

  resource_id="$(az graph query \
    -q "Resources | where type =~ 'microsoft.kusto/clusters' | where name =~ '${cluster_name}' or tostring(properties.uri) =~ '${cluster_uri}' | project id | limit 2" \
    -o json 2>/dev/null | jq -r '.data[].id' 2>/dev/null || true)"
  graph_result_count="$(printf '%s\n' "$resource_id" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "$graph_result_count" == "1" ]]; then
    printf '%s\n' "$resource_id"
    return 0
  fi

  if [[ -z "$resource_id" || "$resource_id" == "null" ]]; then
    fail "Error: could not resolve Kusto cluster '${cluster_name}'. Pass --cluster-resource-id so deployment can assign AllDatabasesViewer before creating the connector." 2
  fi

  fail "Error: Kusto cluster '${cluster_name}' resolved to multiple resources. Pass --cluster-resource-id explicitly so deployment assigns AllDatabasesViewer to the intended cluster." 2
}

warn_kusto_private_query_limitation() {
  local cluster_id="$1"
  local cluster_json
  local public_network_access
  local private_endpoint_count
  local cluster_uri
  local docs_url="https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations"

  [[ -n "$cluster_id" ]] || return 0

  cluster_json="$(az resource show --ids "$cluster_id" --api-version 2023-08-15 -o json 2>/dev/null || true)"
  if [[ -z "$cluster_json" ]]; then
    echo -e "${YELLOW}Warning: Could not inspect Kusto cluster network access. Deployment will continue.${NC}"
    echo "  Cluster: $cluster_id"
    echo "  Review SRE Agent private endpoint limitations: $docs_url"
    echo ""
    return 0
  fi

  public_network_access="$(echo "$cluster_json" | jq -r '.properties.publicNetworkAccess // .publicNetworkAccess // ""' 2>/dev/null || true)"
  private_endpoint_count="$(echo "$cluster_json" | jq -r '((.properties.privateEndpointConnections // .privateEndpointConnections // []) | length)' 2>/dev/null || echo 0)"
  cluster_uri="$(echo "$cluster_json" | jq -r '.properties.uri // .uri // empty' 2>/dev/null || true)"

  if [[ "$public_network_access" == "Disabled" ]]; then
    echo -e "${YELLOW}Warning: The Kusto cluster denies public query access.${NC}"
    echo "  Cluster: ${cluster_uri:-$cluster_id}"
    echo "  publicNetworkAccess: ${public_network_access}"
    echo "  private endpoint connections: ${private_endpoint_count}"
    echo "  SRE Agent will still be deployed and the finops-hub-kusto connector will still be created."
    echo "  Per the SRE Agent known limitations, private endpoint ADX blocks direct KQL queries."
    echo "  The customer can enable public query access if they want the Kusto connector to become healthy:"
    echo "  $docs_url"
    echo ""
  fi
}

RECIPE_DIR=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
AGENT_NAME=""
LOCATION=""
CLUSTER_URI=""
CLUSTER_RESOURCE_ID=""
DEPLOY_NAME=""
DRY_RUN=""
TARGET_RGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recipe)
      require_value "--recipe" "${2:-}"
      RECIPE_DIR="$2"
      shift 2
      ;;
    --subscription)
      require_value "--subscription" "${2:-}"
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    -g|--resource-group)
      require_value "--resource-group / -g" "${2:-}"
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -n|--name)
      require_value "--name / -n" "${2:-}"
      AGENT_NAME="$2"
      shift 2
      ;;
    -l|--location)
      require_value "--location / -l" "${2:-}"
      LOCATION="$2"
      shift 2
      ;;
    --target-resource-group)
      require_value "--target-resource-group" "${2:-}"
      TARGET_RGS+=("$2")
      shift 2
      ;;
    --cluster-uri)
      require_value "--cluster-uri" "${2:-}"
      CLUSTER_URI="$2"
      shift 2
      ;;
    --cluster-resource-id)
      require_value "--cluster-resource-id" "${2:-}"
      CLUSTER_RESOURCE_ID="$2"
      shift 2
      ;;
    --deploy-name)
      require_value "--deploy-name" "${2:-}"
      DEPLOY_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --force|--fallback-srectl|--no-telemetry)
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      fail "Error: unknown flag '$1'" 2
      ;;
    *)
      fail "Error: unknown argument '$1'" 2
      ;;
  esac
done

[[ -n "$RECIPE_DIR" ]] || fail "Error: --recipe <dir> is required" 2
[[ -d "$RECIPE_DIR" ]] || fail "Error: recipe directory not found: $RECIPE_DIR" 1
[[ -f "${RECIPE_DIR}/agent.json" ]] || fail "Error: recipe agent.json not found: ${RECIPE_DIR}/agent.json" 1
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Error: --subscription <id> is required" 2
[[ -n "$RESOURCE_GROUP" ]] || fail "Error: --resource-group <name> is required" 2
[[ -n "$AGENT_NAME" ]] || fail "Error: --name <name> is required" 2
[[ -n "$LOCATION" ]] || fail "Error: --location <region> is required" 2
validate_kusto_uri "$CLUSTER_URI"
if [[ -n "$CLUSTER_URI" ]]; then
  [[ -n "$(parse_kusto_database_name "$CLUSTER_URI")" ]] || fail "Error: could not parse Kusto database name from --cluster-uri" 2
fi

append_target_rg "$RESOURCE_GROUP"

command -v az >/dev/null || fail "Azure CLI (az) is required" 1
command -v jq >/dev/null || fail "jq is required" 1
command -v git >/dev/null || fail "git is required" 1

PYTHON_CMD=""
if command -v python3 >/dev/null; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null && python --version 2>&1 | grep -q "Python 3"; then
  PYTHON_CMD="python"
else
  fail "Python 3 is required" 1
fi

if [[ -n "$CLUSTER_URI" && -z "$CLUSTER_RESOURCE_ID" ]]; then
  if [[ -n "$DRY_RUN" ]]; then
    fail "Error: --cluster-resource-id is required with --cluster-uri for --dry-run because dry-run makes no Azure calls. Real deployments can resolve it from the Kusto URI." 2
  fi

  echo "Resolving Kusto cluster resource ID from --cluster-uri..."
  az account show --subscription "$SUBSCRIPTION_ID" >/dev/null
  az account set --subscription "$SUBSCRIPTION_ID"
  CLUSTER_RESOURCE_ID="$(resolve_kusto_cluster_resource_id "$CLUSTER_URI")"
  echo "  Kusto cluster: $CLUSTER_RESOURCE_ID"
fi

if [[ -n "$CLUSTER_RESOURCE_ID" && -z "$DRY_RUN" ]]; then
  warn_kusto_private_query_limitation "$CLUSTER_RESOURCE_ID"
fi

if [[ -n "$CLUSTER_RESOURCE_ID" ]]; then
  CLUSTER_SUBSCRIPTION_ID="$(resource_id_subscription "$CLUSTER_RESOURCE_ID")"
  CLUSTER_RESOURCE_GROUP="$(resource_id_resource_group "$CLUSTER_RESOURCE_ID")"
  if [[ "$(to_lower "$CLUSTER_SUBSCRIPTION_ID")" == "$(to_lower "$SUBSCRIPTION_ID")" ]]; then
    append_target_rg "$CLUSTER_RESOURCE_GROUP"
  else
    echo -e "${YELLOW}Warning: FinOps Hub cluster is in subscription ${CLUSTER_SUBSCRIPTION_ID}; add agent managed-resource scope and resource-group RBAC for ${CLUSTER_RESOURCE_GROUP} separately.${NC}" >&2
  fi
fi

ACCESS_LEVEL="$(recipe_value "${RECIPE_DIR}/agent.json" '.access.accessLevel')"
[[ -n "$ACCESS_LEVEL" ]] || ACCESS_LEVEL="Low"
ACTION_MODE_RAW="$(recipe_value "${RECIPE_DIR}/agent.json" '.access.actionMode')"
[[ -n "$ACTION_MODE_RAW" ]] || ACTION_MODE_RAW="Review"
ACTION_MODE="$(normalize_action_mode "$ACTION_MODE_RAW")"
UPGRADE_CHANNEL="$(recipe_value "${RECIPE_DIR}/agent.json" '.upgradeChannel')"
[[ -n "$UPGRADE_CHANNEL" ]] || UPGRADE_CHANNEL="Preview"
DEFAULT_MODEL_PROVIDER="$(recipe_value "${RECIPE_DIR}/agent.json" '.defaultModelProvider')"
[[ -n "$DEFAULT_MODEL_PROVIDER" ]] || DEFAULT_MODEL_PROVIDER="MicrosoftFoundry"
DEFAULT_MODEL_NAME="$(recipe_value "${RECIPE_DIR}/agent.json" '.defaultModelName')"
[[ -n "$DEFAULT_MODEL_NAME" ]] || DEFAULT_MODEL_NAME="Automatic"
MONTHLY_AGENT_UNIT_LIMIT="$(recipe_value "${RECIPE_DIR}/agent.json" '.monthlyAgentUnitLimit')"
[[ -n "$MONTHLY_AGENT_UNIT_LIMIT" ]] || MONTHLY_AGENT_UNIT_LIMIT="10000"
EXPERIMENTAL_SETTINGS="$(jq -c '.experimentalSettings // {"EnableSandboxGroup": true, "EnableWorkspaceTools": true}' "${RECIPE_DIR}/agent.json")"
TAGS="$(jq -c '.tags // {"finops-toolkit":"sre-agent","source":"microsoft-finops-toolkit"}' "${RECIPE_DIR}/agent.json")"
TARGET_RGS_JSON="$(printf '%s\n' "${TARGET_RGS[@]}" | jq -R . | jq -sc '.')"

[[ -n "$DEPLOY_NAME" ]] || DEPLOY_NAME="$(deterministic_deploy_name)"
BUILD_ROOT="${SRE_AGENT_DEPLOY_DIR:-${HOME}/.cache/finops-toolkit/sre-agent}"
BUILD_DIR="${BUILD_ROOT}/${AGENT_NAME}-${DEPLOY_NAME}"
mkdir -p "$BUILD_DIR"

PARAMETERS_FILE="${BUILD_DIR}/deploy.parameters.json"
RESULT_FILE="${BUILD_DIR}/deployment-result.json"

jq -n \
  --arg resourceGroupName "$RESOURCE_GROUP" \
  --arg agentName "$AGENT_NAME" \
  --arg location "$LOCATION" \
  --arg accessLevel "$ACCESS_LEVEL" \
  --arg actionMode "$ACTION_MODE" \
  --arg upgradeChannel "$UPGRADE_CHANNEL" \
  --arg defaultModelProvider "$DEFAULT_MODEL_PROVIDER" \
  --arg defaultModelName "$DEFAULT_MODEL_NAME" \
  --argjson monthlyAgentUnitLimit "$MONTHLY_AGENT_UNIT_LIMIT" \
  --arg kustoClusterId "$CLUSTER_RESOURCE_ID" \
  --argjson targetResourceGroups "$TARGET_RGS_JSON" \
  --argjson experimentalSettings "$EXPERIMENTAL_SETTINGS" \
  --argjson tags "$TAGS" \
  '{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "resourceGroupName": { "value": $resourceGroupName },
      "agentName": { "value": $agentName },
      "location": { "value": $location },
      "targetResourceGroups": { "value": $targetResourceGroups },
      "accessLevel": { "value": $accessLevel },
      "actionMode": { "value": $actionMode },
      "upgradeChannel": { "value": $upgradeChannel },
      "defaultModelProvider": { "value": $defaultModelProvider },
      "defaultModelName": { "value": $defaultModelName },
      "monthlyAgentUnitLimit": { "value": $monthlyAgentUnitLimit },
      "experimentalSettings": { "value": $experimentalSettings },
      "tags": { "value": $tags },
      "finopsHubKustoClusterResourceId": { "value": $kustoClusterId }
    }
  }' > "$PARAMETERS_FILE"

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Azure SRE Agent - FinOps Toolkit Setup${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "${YELLOW}[1/4] Checking prerequisites...${NC}"
echo "  az:       $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null || echo found)"
echo "  jq:       $(jq --version)"
echo "  python:   $($PYTHON_CMD --version 2>&1)"
echo "  azd:      not used"
echo ""

if [[ -n "$DRY_RUN" ]]; then
  echo -e "${YELLOW}[2/4] Planned deployment...${NC}"
  echo "  Subscription: $SUBSCRIPTION_ID"
  echo "  Resource group: $RESOURCE_GROUP"
  echo "  Agent: $AGENT_NAME"
  echo "  Region: $LOCATION"
  echo "  Target resource groups: ${TARGET_RGS[*]}"
  echo "  Parameters: $PARAMETERS_FILE"
  echo ""
  echo "Dry run complete. No Azure calls were made."
  exit 0
fi

echo -e "${YELLOW}[2/4] Checking Azure account...${NC}"
az account show --subscription "$SUBSCRIPTION_ID" --query "{subscription:name, id:id}" -o table >/dev/null
az account set --subscription "$SUBSCRIPTION_ID"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Agent: $AGENT_NAME"
echo "  Region: $LOCATION"
echo "  Target resource groups: ${TARGET_RGS[*]}"
echo "  Parameters: $PARAMETERS_FILE"
echo ""

echo -e "${YELLOW}[3/4] Deploying infrastructure with Azure CLI + Bicep...${NC}"
echo "  Registering Microsoft.App provider..."
az provider register -n Microsoft.App --wait --output none

echo "  Starting deployment: $DEPLOY_NAME"
az deployment sub create \
  --subscription "$SUBSCRIPTION_ID" \
  --location "$LOCATION" \
  --name "$DEPLOY_NAME" \
  --template-file "${INFRA_DIR}/main.bicep" \
  --parameters "@${PARAMETERS_FILE}" \
  --no-wait \
  --output none

echo "  Waiting for deployment to complete..."
DEPLOYMENT_START="$(date +%s)"
DEPLOYMENT_JSON="{}"
STATE=""
while true; do
  DEPLOYMENT_JSON="$(az deployment sub show \
    --subscription "$SUBSCRIPTION_ID" \
    --name "$DEPLOY_NAME" \
    --output json 2>/dev/null || echo "{}")"
  STATE="$(echo "$DEPLOYMENT_JSON" | jq -r '.properties.provisioningState // "Accepted"' 2>/dev/null)"

  case "$STATE" in
    Succeeded|Failed|Canceled)
      break
      ;;
    *)
      NOW="$(date +%s)"
      echo "  Deployment state: ${STATE} ($((NOW - DEPLOYMENT_START))s elapsed)"
      sleep 10
      ;;
  esac
done

printf '%s\n' "$DEPLOYMENT_JSON" > "$RESULT_FILE"

STATE="$(jq -r '.properties.provisioningState // "Failed"' "$RESULT_FILE")"
if [[ "$STATE" != "Succeeded" ]]; then
  echo ""
  echo "Deployment failed. Diagnostic command:"
  echo "  az deployment operation sub list --subscription ${SUBSCRIPTION_ID} -n ${DEPLOY_NAME} -o table"
  exit 1
fi

AGENT_ENDPOINT="$(deployment_output_value "$RESULT_FILE" "SRE_AGENT_ENDPOINT")"
SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID="$(deployment_output_value "$RESULT_FILE" "SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID")"
AGENT_PORTAL_URL="$(deployment_output_value "$RESULT_FILE" "AGENT_PORTAL_URL" "https://sre.azure.com")"

[[ -n "$AGENT_ENDPOINT" ]] || fail "Deployment succeeded but did not return SRE_AGENT_ENDPOINT" 1
[[ -n "$SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID" ]] || fail "Deployment succeeded but did not return SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID" 1

echo ""
echo -e "${YELLOW}[4/4] Applying SRE Agent extras...${NC}"
APPLY_EXTRAS_ARGS=(
  --endpoint "$AGENT_ENDPOINT"
  --subscription "$SUBSCRIPTION_ID"
  --resource-group "$RESOURCE_GROUP"
  --name "$AGENT_NAME"
  --recipe "$RECIPE_DIR"
  --build-dir "${BUILD_DIR}/extras"
)

if [[ -n "$CLUSTER_URI" ]]; then
  APPLY_EXTRAS_ARGS+=(--kusto-connector-uri "$CLUSTER_URI")
fi

bash "${SCRIPT_DIR}/apply-extras.sh" \
  "${APPLY_EXTRAS_ARGS[@]}"

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}  SRE Agent ready${NC}"
echo -e "${BLUE}============================================================${NC}"
echo "  Agent portal: $AGENT_PORTAL_URL"
echo "  Endpoint:     $AGENT_ENDPOINT"
echo "  Build dir:    $BUILD_DIR"
echo ""
