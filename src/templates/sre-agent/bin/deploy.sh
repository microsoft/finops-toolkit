#!/usr/bin/env bash
# deploy.sh — deploy an SRE Agent via Bicep.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/telemetry.sh"

usage() {
  cat <<EOF
Usage: bash bin/deploy.sh --recipe <dir> [options]
       bash bin/deploy.sh <legacy.parameters.json> [options]

Required for recipe directories:
  --recipe <dir>                        Recipe directory to assemble
  -g, --resource-group <name>          Resource group (portal field: "Resource group")
  -n, --name <name>                    Agent name (portal field: "Agent name")
  -l, --location <region>              Region (portal field: "Region"; currently documented: swedencentral, eastus2, australiaeast)
      --cluster-uri <uri>              Kusto connector URI when the recipe declares one

Optional:
      --subscription <id>              Subscription (portal field: "Subscription")
      --target-resource-group <name>   Repeatable target resource group
      --cluster-resource-id <id>       Kusto cluster ARM resource ID
      --deploy-name <name>             Deployment name override
      --dry-run                        Assemble and validate inputs without Azure calls
      --what-if                        Run live ARM what-if validation
      --force                          Continue when diff/discovery would otherwise stop
      --fallback-srectl                Deploy ARM core, then hydrate extensions with srectl
      --no-telemetry                   Disable anonymous telemetry for this run
  -h, --help                           Show this help

Legacy input:
  A pre-assembled .parameters.json file is accepted only as a positional argument.
  When using a legacy parameters file, identity and cluster flags are ignored.
EOF
  exit "${1:-0}"
}

error_exit() {
  echo "$1" >&2
  exit "${2:-1}"
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == -* ]]; then
    error_exit "Error: flag ${flag} requires a value" 2
  fi
}

closest_flag() {
  local unknown="$1"
  if command -v python3 >/dev/null 2>&1; then
    UNKNOWN_FLAG="$unknown" python3 - <<'PY'
import difflib
import os
flags = [
    '--recipe', '--resource-group', '--name', '--location', '--subscription',
    '--target-resource-group', '--cluster-uri', '--cluster-resource-id',
    '--deploy-name', '--dry-run', '--what-if', '--force',
    '--fallback-srectl', '--no-telemetry', '--help'
]
unknown = os.environ['UNKNOWN_FLAG']
match = difflib.get_close_matches(unknown, flags, n=1, cutoff=0.6)
print(match[0] if match else '')
PY
  fi
}

unknown_flag() {
  local flag="$1"
  local suggestion
  suggestion="$(closest_flag "$flag")"
  if [[ -n "$suggestion" ]]; then
    error_exit "Error: unknown flag '$flag'. Did you mean '$suggestion'?" 2
  fi
  error_exit "Error: unknown flag '$flag'" 2
}

warn_ignored_for_legacy() {
  local flag="$1"
  echo "WARN: --${flag} ignored when input is a pre-assembled parameters file"
}

recipe_string_field() {
  local json="$1"
  local path="$2"
  echo "$json" | jq -r "$path // empty | if . == null or . == \"null\" then \"\" else . end"
}

recipe_target_rgs() {
  local json="$1"
  echo "$json" | jq -c '
    if (.identity.targetResourceGroups // empty) == empty then []
    elif (.identity.targetResourceGroups | type) == "array" then
      [.identity.targetResourceGroups[] | select(. != null and . != "")]
    elif (.identity.targetResourceGroups | type) == "string" and (.identity.targetResourceGroups | length) > 0 then
      [.identity.targetResourceGroups | split(",")[] | gsub("^\\s+|\\s+$"; "") | select(length > 0)]
    else
      []
    end
  '
}

resolve_required_identity() {
  local cli_value="$1"
  local recipe_value="$2"
  local flag_text="$3"
  local portal_label="$4"
  if [[ -n "$cli_value" ]]; then
    printf '%s' "$cli_value"
  elif [[ -n "$recipe_value" ]]; then
    printf '%s' "$recipe_value"
  else
    error_exit "Error: ${flag_text} is required (portal field: \"${portal_label}\")" 2
  fi
}

inject_cluster_resource_id() {
  local source_file="$1"
  local cluster_id="$2"
  local out_file
  out_file=$(mktemp "${TMPDIR:-/tmp}/sre-kusto-rbac.XXXXXX.parameters.json")
  CLEANUP_FILES+=("$out_file")
  jq --arg clusterId "$cluster_id" '
    .parameters.enableFinopsHubKustoViewerRole = ((.parameters.enableFinopsHubKustoViewerRole // {}) + { value: true }) |
    .parameters.finopsHubKustoClusterResourceId = ((.parameters.finopsHubKustoClusterResourceId // {}) + { value: $clusterId })
  ' "$source_file" > "$out_file"
  FILE="$out_file"
  DEPLOY_FILE="$FILE"
}

DRY_RUN=""
FORCE=""
WHAT_IF=""
EXTENSION_FALLBACK=""
RECIPE_DIR=""
RESOURCE_GROUP=""
AGENT_NAME=""
LOCATION=""
SUBSCRIPTION_ID=""
CLUSTER_URI=""
CLUSTER_RESOURCE_ID=""
DEPLOY_NAME=""
RECIPE_FLAG_USED="false"
LEGACY_POSITIONAL_USED="false"
POSITIONALS=()
TARGET_RGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recipe)
      require_value "--recipe" "${2:-}"
      RECIPE_DIR="$2"
      RECIPE_FLAG_USED="true"
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
    --subscription)
      require_value "--subscription" "${2:-}"
      SUBSCRIPTION_ID="$2"
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
    --what-if)
      WHAT_IF="true"
      shift
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --fallback-srectl|--extension-fallback=srectl)
      EXTENSION_FALLBACK="srectl"
      shift
      ;;
    --extension-fallback=*)
      EXTENSION_FALLBACK="${1#*=}"
      shift
      ;;
    --no-telemetry)
      _NO_TELEMETRY="true"
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      unknown_flag "$1"
      ;;
    *)
      POSITIONALS+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$DRY_RUN" && -n "$WHAT_IF" ]]; then
  error_exit "Error: --dry-run and --what-if are mutually exclusive" 2
fi

if [[ -n "$EXTENSION_FALLBACK" && "$EXTENSION_FALLBACK" != "srectl" ]]; then
  error_exit "Unsupported --extension-fallback value: ${EXTENSION_FALLBACK}" 1
fi

if [[ "$RECIPE_FLAG_USED" == "true" ]]; then
  if [[ "${#POSITIONALS[@]}" -gt 0 ]]; then
    if [[ "${#POSITIONALS[@]}" -eq 1 ]]; then
      error_exit "Error: unexpected positional argument '${POSITIONALS[0]}'" 2
    fi
    error_exit "Error: unexpected positional arguments" 2
  fi
  [[ -d "$RECIPE_DIR" ]] || error_exit "Error: recipe directory not found: $RECIPE_DIR" 1
  INPUT="$RECIPE_DIR"
else
  if [[ "${#POSITIONALS[@]}" -eq 0 ]]; then
    error_exit "Error: --recipe <dir> is required" 2
  fi
  if [[ "${#POSITIONALS[@]}" -gt 1 ]]; then
    error_exit "Error: unexpected positional arguments" 2
  fi
  if [[ -d "${POSITIONALS[0]}" ]]; then
    INPUT="${POSITIONALS[0]}"
  elif [[ -f "${POSITIONALS[0]}" && "${POSITIONALS[0]}" == *.parameters.json ]]; then
    INPUT="${POSITIONALS[0]}"
    LEGACY_POSITIONAL_USED="true"
  else
    error_exit "Error: --recipe <dir> is required" 2
  fi
fi

[[ -n "$DEPLOY_NAME" ]] || DEPLOY_NAME="sre-agent-$(date -u +%Y%m%d-%H%M%S)"
NAME="$DEPLOY_NAME"
TEMPLATE="${SCRIPT_DIR}/../bicep/main.bicep"

command -v jq >/dev/null || error_exit "jq is required" 1

CLEANUP_FILES=()
cleanup() {
  if [[ "${#CLEANUP_FILES[@]}" -eq 0 ]]; then
    return 0
  fi
  for f in "${CLEANUP_FILES[@]}"; do
    rm -rf "$f" 2>/dev/null
  done
}
trap cleanup EXIT

if [[ -d "$INPUT" ]]; then
  RECIPE_DIR="$INPUT"
  AGENT_JSON=$(cat "${INPUT}/agent.json")
  RECIPE_RESOURCE_GROUP=$(recipe_string_field "$AGENT_JSON" '.identity.resourceGroup')
  RECIPE_AGENT_NAME=$(recipe_string_field "$AGENT_JSON" '.identity.agentName')
  RECIPE_LOCATION=$(recipe_string_field "$AGENT_JSON" '.identity.location')
  RECIPE_SUBSCRIPTION=$(recipe_string_field "$AGENT_JSON" '.identity.subscription')
  RECIPE_TARGET_RGS=$(recipe_target_rgs "$AGENT_JSON")

  RESOURCE_GROUP=$(resolve_required_identity "$RESOURCE_GROUP" "$RECIPE_RESOURCE_GROUP" '--resource-group / -g' 'Resource group')
  AGENT_NAME=$(resolve_required_identity "$AGENT_NAME" "$RECIPE_AGENT_NAME" '--name / -n' 'Agent name')
  LOCATION=$(resolve_required_identity "$LOCATION" "$RECIPE_LOCATION" '--location / -l' 'Region')
  [[ -n "$SUBSCRIPTION_ID" ]] || SUBSCRIPTION_ID="$RECIPE_SUBSCRIPTION"

  if [[ "${#TARGET_RGS[@]}" -eq 0 ]]; then
    if [[ "$RECIPE_TARGET_RGS" != "[]" ]]; then
      while IFS= read -r target_rg; do
        [[ -n "$target_rg" ]] && TARGET_RGS+=("$target_rg")
      done < <(echo "$RECIPE_TARGET_RGS" | jq -r '.[]')
    fi
  fi
  if [[ "${#TARGET_RGS[@]}" -eq 0 ]]; then
    TARGET_RGS=("$RESOURCE_GROUP")
  fi

  echo "── Assembling from directory: ${INPUT}/ ──"
  ASSEMBLE_DIR=$(mktemp -d)
  CLEANUP_FILES+=("$ASSEMBLE_DIR")
  ASSEMBLE_OUT="${ASSEMBLE_DIR}/assembled"
  ASSEMBLE_ARGS=(
    "$INPUT"
    --output "$ASSEMBLE_OUT"
    --resource-group "$RESOURCE_GROUP"
    --name "$AGENT_NAME"
    --location "$LOCATION"
  )
  [[ -n "$SUBSCRIPTION_ID" ]] && ASSEMBLE_ARGS+=(--subscription "$SUBSCRIPTION_ID")
  [[ -n "$CLUSTER_URI" ]] && ASSEMBLE_ARGS+=(--cluster-uri "$CLUSTER_URI")
  [[ -n "$CLUSTER_RESOURCE_ID" ]] && ASSEMBLE_ARGS+=(--cluster-resource-id "$CLUSTER_RESOURCE_ID")
  for target_rg in "${TARGET_RGS[@]}"; do
    ASSEMBLE_ARGS+=(--target-resource-group "$target_rg")
  done
  bash "${SCRIPT_DIR}/../bicep/assemble-agent.sh" "${ASSEMBLE_ARGS[@]}"
  FILE="${ASSEMBLE_OUT}.parameters.json"
  EXTRAS_FILE="${ASSEMBLE_OUT}.extras.json"
  echo
else
  FILE="$INPUT"
  EXTRAS_FILE=""
  [[ -n "$RESOURCE_GROUP" ]] && warn_ignored_for_legacy "resource-group"
  [[ -n "$AGENT_NAME" ]] && warn_ignored_for_legacy "name"
  [[ -n "$LOCATION" ]] && warn_ignored_for_legacy "location"
  [[ -n "$SUBSCRIPTION_ID" ]] && warn_ignored_for_legacy "subscription"
  [[ "${#TARGET_RGS[@]}" -gt 0 ]] && warn_ignored_for_legacy "target-resource-group"
  [[ -n "$CLUSTER_URI" ]] && warn_ignored_for_legacy "cluster-uri"
  [[ -n "$CLUSTER_RESOURCE_ID" ]] && warn_ignored_for_legacy "cluster-resource-id"
fi

[[ -f "$FILE" ]] || error_exit "parameters file not found: $FILE" 1

ORIGINAL_FILE="$FILE"
DEPLOY_FILE="$FILE"
DISCOVERED_EXTRAS_FILE="${EXTRAS_FILE:-}"
if [[ -z "$DISCOVERED_EXTRAS_FILE" ]]; then
  DISCOVERED_EXTRAS_FILE="${FILE%.parameters.json}.extras.json"
  [[ ! -f "$DISCOVERED_EXTRAS_FILE" ]] && DISCOVERED_EXTRAS_FILE="$(dirname "$FILE")/assembled.extras.json"
fi

ACTION_MODE_VALUE=$(jq -r '.parameters.actionMode.value // "Review"' "$FILE")
if [[ "$ACTION_MODE_VALUE" == "Automatic" ]]; then
  COMPAT_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-actionmode-compat.XXXXXX.parameters.json")
  CLEANUP_FILES+=("$COMPAT_FILE")
  jq '.parameters.actionMode.value = "Autonomous"' "$FILE" > "$COMPAT_FILE"
  FILE="$COMPAT_FILE"
  DEPLOY_FILE="$FILE"
fi

KUSTO_CONNECTOR_DATASOURCE=$(jq -r '.parameters.connectors.value // [] | map(select((.properties.dataConnectorType // "") == "Kusto" and (.properties.identity // "") == "system")) | .[0].properties.dataSource // ""' "$FILE")
KUSTO_URI_TOKEN='$''{FINOPS_HUB_''CLUSTER_URI}'
if [[ "$KUSTO_CONNECTOR_DATASOURCE" == *"$KUSTO_URI_TOKEN"* ]]; then
  error_exit 'Error: --cluster-uri <uri> is required because the recipe declares a Kusto connector. Example: --cluster-uri https://<cluster>.<region>.kusto.windows.net/hub' 2
fi

if [[ -z "$DRY_RUN" ]]; then
  if [[ -z "$SUBSCRIPTION_ID" ]]; then
    SUBSCRIPTION_ID=$(command az account show --query id -o tsv)
  fi
  export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
  az() { command az "$@" --subscription "$SUBSCRIPTION_ID"; }
fi

if [[ -n "$KUSTO_CONNECTOR_DATASOURCE" ]]; then
  KUSTO_CLUSTER_RESOURCE_ID="$CLUSTER_RESOURCE_ID"
  if [[ -z "$KUSTO_CLUSTER_RESOURCE_ID" ]]; then
    KUSTO_CLUSTER_RESOURCE_ID=$(jq -r '.parameters.finopsHubKustoClusterResourceId.value // ""' "$FILE")
  fi

  if [[ -z "$KUSTO_CLUSTER_RESOURCE_ID" && -n "$DRY_RUN" ]]; then
    echo "WARN: cluster ARM ID not resolved in dry-run; live deploy will auto-discover it or require --cluster-resource-id if discovery fails."
  fi

  if [[ -z "$KUSTO_CLUSTER_RESOURCE_ID" && -z "$DRY_RUN" ]]; then
    KUSTO_HOST="${KUSTO_CONNECTOR_DATASOURCE#https://}"
    KUSTO_HOST="${KUSTO_HOST#http://}"
    KUSTO_HOST="${KUSTO_HOST%%/*}"
    KUSTO_CLUSTER_RESOURCE_ID=$(az kusto cluster list \
      --query "[?contains(uri, '${KUSTO_HOST}')].id | [0]" \
      -o tsv 2>/dev/null || true)
    if [[ -n "$KUSTO_CLUSTER_RESOURCE_ID" && "$KUSTO_CLUSTER_RESOURCE_ID" != "null" ]]; then
      inject_cluster_resource_id "$FILE" "$KUSTO_CLUSTER_RESOURCE_ID"
    else
      REMEDIATION="Error: cluster ARM ID discovery failed. Re-run with --cluster-resource-id /subscriptions/.../resourceGroups/.../providers/Microsoft.Kusto/clusters/<name>."
      if [[ -n "$FORCE" ]]; then
        echo "WARN: ${REMEDIATION#Error: }"
      else
        error_exit "$REMEDIATION" 2
      fi
    fi
  elif [[ -n "$KUSTO_CLUSTER_RESOURCE_ID" && "$KUSTO_CLUSTER_RESOURCE_ID" != "null" ]]; then
    inject_cluster_resource_id "$FILE" "$KUSTO_CLUSTER_RESOURCE_ID"
  fi
fi

if [[ "$EXTENSION_FALLBACK" == "srectl" ]]; then
  [[ -d "$INPUT" ]] || error_exit "--fallback-srectl requires a config directory input (not a parameters file)." 1
  command -v srectl >/dev/null || error_exit "srectl is required when --fallback-srectl is enabled." 1

  CORE_ONLY_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-core-only.XXXXXX.parameters.json")
  CLEANUP_FILES+=("$CORE_ONLY_FILE")
  jq '
    def set_param($k; $v): .parameters[$k] = ((.parameters[$k] // {}) + { value: $v });
    set_param("tools"; []) |
    set_param("subagents"; []) |
    set_param("skills"; []) |
    set_param("scheduledTasks"; []) |
    set_param("incidentFilters"; []) |
    set_param("connectors"; []) |
    set_param("hooks"; []) |
    set_param("commonPrompts"; []) |
    set_param("pluginConfigs"; []) |
    set_param("enableAppInsightsConnector"; false) |
    set_param("appInsightsResourceId"; "") |
    set_param("appInsightsAppId"; "") |
    set_param("enableLogAnalyticsConnector"; false) |
    set_param("lawResourceId"; "") |
    set_param("enableAzureMonitorConnector"; false) |
    set_param("enableDailyHealthCheckTask"; false) |
    set_param("enableDenyProdDeletesHook"; false) |
    set_param("enableSafetyRulesPrompt"; false)
  ' "$FILE" > "$CORE_ONLY_FILE"
  DEPLOY_FILE="$CORE_ONLY_FILE"
fi

echo "──────────────── SRE Agent deployment ────────────────"
LOC=$(jq -r '.parameters.location.value // ""' "$FILE")
AG=$(jq -r '.parameters.agentName.value // ""' "$FILE")
RG=$(jq -r '.parameters.agentResourceGroupName.value // ""' "$FILE")
TGT=$(jq -r '.parameters.targetResourceGroups.value // [] | join(", ")' "$FILE")
SUB="${SUBSCRIPTION_ID:-<active subscription not resolved in dry-run>}"

if [[ -n "$DRY_RUN" ]]; then
  echo "  Subscription:  ${SUB}"
else
  echo "  Subscription:  $(az account show --query name -o tsv) (${SUB})"
fi
echo "  Region:        $LOC"
echo "  Agent name:    $AG"
if [[ -n "$DRY_RUN" ]]; then
  echo "  Agent RG:      $RG"
else
  echo "  Agent RG:      $RG  $([[ "$(az group exists -n "$RG")" == "true" ]] && echo "(exists)" || echo "(will be created)")"
fi
echo "  Target RGs:    ${TGT:-<none>}"
echo "  Access level:  $(jq -r '.parameters.accessLevel.value // "Low"' "$FILE")"
echo "  Action mode:   $(jq -r '.parameters.actionMode.value // "Review"' "$FILE")"
echo "  Upgrade chan:  $(jq -r '.parameters.upgradeChannel.value // "Preview"' "$FILE")"
echo "  Model:         $(jq -r '.parameters.defaultModelProvider.value // "Anthropic"' "$FILE")"
echo "  Monthly limit: $(jq -r '.parameters.monthlyAgentUnitLimit.value // 10000' "$FILE") AU"
[[ "$EXTENSION_FALLBACK" == "srectl" ]] && echo "  Extension mode: ARM core + srectl hydration"
echo

echo "  Bicep (ARM) resources:"
WH=$(jq -r '.parameters.enableWebhookBridge.value // false' "$FILE")
[[ "$WH" == "true" ]] && echo "    ✓ Webhook bridge (Logic App)"
for tog in enableLogAnalyticsConnector enableAppInsightsConnector enableAzureMonitorConnector; do
  v=$(jq -r ".parameters.${tog}.value // false" "$FILE")
  if [[ "$v" == "true" ]]; then
    case "$tog" in
      enableLogAnalyticsConnector) echo "    ✓ Log Analytics connector" ;;
      enableAppInsightsConnector)  echo "    ✓ App Insights connector" ;;
      enableAzureMonitorConnector) echo "    ✓ Azure Monitor connector" ;;
    esac
  fi
done
n=$(jq -r '.parameters.connectors.value // [] | length' "$FILE")
if [[ "$n" -gt 0 ]]; then
  for cname in $(jq -r '.parameters.connectors.value[].name' "$FILE" 2>/dev/null); do
    ctype=$(jq -r ".parameters.connectors.value[] | select(.name==\"$cname\") | .properties.dataConnectorType" "$FILE")
    echo "    ✓ Connector: ${cname} (${ctype})"
  done
fi
KUSTO_RBAC_ENABLED=$(jq -r '.parameters.enableFinopsHubKustoViewerRole.value // false' "$FILE")
if [[ "$KUSTO_RBAC_ENABLED" == "true" ]]; then
  KUSTO_RBAC_CLUSTER_ID=$(jq -r '.parameters.finopsHubKustoClusterResourceId.value // ""' "$FILE")
  echo "    ✓ Kusto RBAC: AllDatabasesViewer (system MI)"
  [[ -n "$KUSTO_RBAC_CLUSTER_ID" ]] && echo "      Cluster: ${KUSTO_RBAC_CLUSTER_ID}"
fi
for arr in skills subagents; do
  n=$(jq -r ".parameters.${arr}.value // [] | length" "$FILE")
  [[ "$n" -gt 0 ]] && echo "    ✓ ${arr}: ${n}"
done
echo
echo "  Data-plane (apply-extras):"
if [[ -f "$DISCOVERED_EXTRAS_FILE" ]]; then
  for key in hooks commonPrompts incidentPlatforms incidentFilters scheduledTasks httpTriggers repos knowledgeItems knowledge; do
    n=$(jq -r ".${key} // [] | length" "$DISCOVERED_EXTRAS_FILE" 2>/dev/null)
    if [[ "$n" -gt 0 ]]; then
      case "$key" in
        hooks)              echo "    ✓ Hooks: ${n}" ;;
        commonPrompts)      echo "    ✓ Common prompts: ${n}" ;;
        incidentPlatforms)  echo "    ✓ Incident platforms: ${n}" ;;
        incidentFilters)    echo "    ✓ Incident filters (response plans): ${n}" ;;
        scheduledTasks)     echo "    ✓ Scheduled tasks: ${n}" ;;
        httpTriggers)       echo "    ✓ HTTP triggers: ${n}" ;;
        repos)              echo "    ✓ Repos: ${n}" ;;
        knowledgeItems)     echo "    ✓ Knowledge files: ${n}" ;;
        knowledge)          echo "    ✓ Knowledge docs: ${n}" ;;
      esac
    fi
  done
else
  echo "    (extras file not found — data-plane items shown in change detection below)"
fi

echo
echo "  Deployment name: $NAME"
echo "─────────────────────────────────────────────────────"
echo

CHANGES_DETECTED=""
if [[ -z "$DRY_RUN" && -z "$WHAT_IF" && -d "$INPUT" ]]; then
  echo "── Change detection ──"
  DIFF_EXIT=0
  "${SCRIPT_DIR}/diff-agent.sh" "$SUB" "$RG" "$AG" "$INPUT" 2>/dev/null || DIFF_EXIT=$?
  if [[ "$DIFF_EXIT" -eq 0 ]]; then
    echo "  No changes detected."
    if [[ -z "$FORCE" ]]; then
      echo "  Skipping deployment. Use --force to redeploy anyway."
      echo
      echo "── Current state verification ──"
      "${SCRIPT_DIR}/verify-agent.sh" "$SUB" "$RG" "$AG" --expected "$INPUT" 2>&1 || true
      exit 0
    else
      echo "  --force: redeploying anyway."
    fi
  elif [[ "$DIFF_EXIT" -eq 2 ]]; then
    CHANGES_DETECTED="new"
  else
    CHANGES_DETECTED="update"
  fi
  echo
fi

if [[ -n "$DRY_RUN" ]]; then
  RECIPE_NAME="unknown"
  [[ -d "$INPUT" && -f "${INPUT}/agent.json" ]] && RECIPE_NAME=$(jq -r '._scenario // "custom"' "${INPUT}/agent.json" 2>/dev/null)
  [[ -f "$INPUT" ]] && RECIPE_NAME="legacy-parameters"
  echo "── DRY RUN — no deployment performed ──"
  echo "  Assemble: ✅ (parameters + extras built)"
  echo "  To validate against ARM without deploying: --what-if"
  echo "  To deploy for real: remove --dry-run"
  send_telemetry "deploy" "$RECIPE_NAME" "$LOC" "$RECIPE_FLAG_USED" "$LEGACY_POSITIONAL_USED" "$([[ -n "$CLUSTER_URI" ]] && echo true || echo false)" "$([[ -n "$CLUSTER_RESOURCE_ID" ]] && echo true || echo false)" "dry-run"
  exit 0
fi

if [[ -n "$WHAT_IF" ]]; then
  RECIPE_NAME="unknown"
  [[ -d "$INPUT" && -f "${INPUT}/agent.json" ]] && RECIPE_NAME=$(jq -r '._scenario // "custom"' "${INPUT}/agent.json" 2>/dev/null)
  [[ -f "$INPUT" ]] && RECIPE_NAME="legacy-parameters"
  echo "── What-if validation (ARM preflight) ──"
  echo
  WHAT_IF_EXIT=0
  if az deployment sub what-if \
    --location "$LOC" \
    --name "$NAME" \
    --template-file "$TEMPLATE" \
    --parameters "@${DEPLOY_FILE}" \
    --no-pretty-print 2>&1
  then
    echo
    echo "✅ What-if passed — deployment should succeed."
  else
    WHAT_IF_EXIT=$?
    echo
    echo "❌ What-if found errors — fix before deploying."
  fi
  send_telemetry "deploy" "$RECIPE_NAME" "$LOC" "$RECIPE_FLAG_USED" "$LEGACY_POSITIONAL_USED" "$([[ -n "$CLUSTER_URI" ]] && echo true || echo false)" "$([[ -n "$CLUSTER_RESOURCE_ID" ]] && echo true || echo false)" "what-if"
  exit "$WHAT_IF_EXIT"
fi

# ── Run the deployment with progress visible ──
TMP=$(mktemp)

echo "Starting deployment (this typically takes 3-5 min)..."
echo "Tip: open another terminal and run 'az deployment operation sub list --subscription $SUB -n $NAME -o table' to watch progress."
echo

az deployment sub create \
  --location "$LOC" \
  --name "$NAME" \
  --template-file "$TEMPLATE" \
  --parameters "@${DEPLOY_FILE}" \
  --output json | tee "$TMP"

# ── Post-deploy: print key links ──
STATE=$(jq -r '.properties.provisioningState // "?"' "$TMP" 2>/dev/null || echo "Failed")
if [[ "$STATE" != "Succeeded" ]]; then
  echo
  echo "══════════ Deployment FAILED ══════════"
  # Extract the most useful error message
  ERR_MSG=$(jq -r '.. | .message? // empty' "$TMP" 2>/dev/null | grep -v "^At least" | head -3)
  if [[ -n "$ERR_MSG" ]]; then
    echo
    echo "  Root cause:"
    echo "$ERR_MSG" | sed 's/^/    /'
  fi
  echo
  echo "  Debug: az deployment operation sub list --subscription $SUB -n $NAME -o table"
  if [[ -z "$EXTENSION_FALLBACK" ]] && jq -r '.. | .message? // empty' "$TMP" 2>/dev/null | grep -qi "Failed to create or update extension in Kubernetes"; then
    echo "  Hint: extension resource writes are blocked in this tenant."
    echo "  Retry with: bash bin/deploy.sh --recipe \"$RECIPE_DIR\" --resource-group \"$RESOURCE_GROUP\" --name \"$AGENT_NAME\" --location \"$LOCATION\" --cluster-uri \"$CLUSTER_URI\" --fallback-srectl"
  fi
  echo
  exit 1
fi

echo
echo "─────────────── Deployment Succeeded ───────────────"
echo "  Agent (portal):  $(jq -r '.properties.outputs.agentPortalUrl.value // empty' "$TMP")"
echo "  Resource group:  $(jq -r '.properties.outputs.resourceGroupPortalUrl.value // empty' "$TMP")"
echo "  Data plane:      $(jq -r '.properties.outputs.agentDataPlaneUrl.value // empty' "$TMP")"
echo

# ── Telemetry ──
RECIPE_NAME="unknown"
[[ -d "$INPUT" && -f "${INPUT}/agent.json" ]] && RECIPE_NAME=$(jq -r '._scenario // "custom"' "${INPUT}/agent.json" 2>/dev/null)
[[ -f "$INPUT" ]] && RECIPE_NAME="legacy-parameters"
TELEMETRY_MODE="deploy"
[[ "$EXTENSION_FALLBACK" == "srectl" ]] && TELEMETRY_MODE="fallback-srectl"
send_telemetry "deploy" "$RECIPE_NAME" "$LOC" "$RECIPE_FLAG_USED" "$LEGACY_POSITIONAL_USED" "$([[ -n "$CLUSTER_URI" ]] && echo true || echo false)" "$([[ -n "$CLUSTER_RESOURCE_ID" ]] && echo true || echo false)" "$TELEMETRY_MODE"

# Auto-run apply-extras.sh if we assembled from a directory and have extras
APPLY_EXTRAS_FILE="${DISCOVERED_EXTRAS_FILE}"
if [[ "$EXTENSION_FALLBACK" == "srectl" && -f "$APPLY_EXTRAS_FILE" ]]; then
  FALLBACK_EXTRAS_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-fallback-extras.XXXXXX.json")
  CLEANUP_FILES+=("$FALLBACK_EXTRAS_FILE")
  jq '.scheduledTasks = []' "$APPLY_EXTRAS_FILE" > "$FALLBACK_EXTRAS_FILE"
  APPLY_EXTRAS_FILE="$FALLBACK_EXTRAS_FILE"
fi

if [[ -n "${APPLY_EXTRAS_FILE:-}" && -f "$APPLY_EXTRAS_FILE" ]]; then
  EXTRAS_SIZE=$(jq 'del(._exported_from) | to_entries | map(select(.value | if type == "array" then length > 0 elif type == "object" then length > 0 else false end)) | length' "$APPLY_EXTRAS_FILE" 2>/dev/null || echo 0)
  if [[ "$EXTRAS_SIZE" -gt 0 ]]; then
    echo "── Applying data-plane config (extras) ──"
    export INPUT
    bash "${SCRIPT_DIR}/../bicep/apply-extras.sh" "$SUB" "$RG" "$AG" "$APPLY_EXTRAS_FILE" ${FORCE:+--force}
  else
    echo "No data-plane extras to apply."
  fi
else
  echo "Next: apply data-plane config (repos, hooks, knowledge, GitHub/ADO auth):"
  echo "  ./apply-extras.sh $SUB $RG $AG <extras-file>"
fi

if [[ "$EXTENSION_FALLBACK" == "srectl" ]]; then
  echo "── Hydrating tools, subagents, skills, and scheduled tasks via srectl ──"
  bash "${SCRIPT_DIR}/hydrate-extensions.sh" "$SUB" "$RG" "$AG" "$INPUT"
fi

echo "─────────────────────────────────────────────────────"

# ── Deployment log ──
LOG_DIR="${INPUT}"
[[ -d "$INPUT" ]] && LOG_DIR="$INPUT" || LOG_DIR="$(dirname "$INPUT")"
DEPLOY_LOG="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

{
  echo "Deployment: ${NAME}"
  echo "Timestamp:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Agent:      ${AG}"
  echo "RG:         ${RG}"
  echo "Region:     ${LOC}"
  echo "State:      ${STATE}"
  echo "Duration:   $(jq -r '.properties.duration // "?"' "$TMP")"
  echo "Portal:     $(jq -r '.properties.outputs.agentPortalUrl.value // empty' "$TMP")"
  echo ""
} > "$DEPLOY_LOG" 2>/dev/null || true

# ── Post-deploy verification ──
if [[ -d "$INPUT" ]]; then
  echo
  echo "── Post-deploy verification ──"
  VERIFY_OUTPUT=$("${SCRIPT_DIR}/verify-agent.sh" "$SUB" "$RG" "$AG" --expected "$INPUT" 2>&1) || true
  echo "$VERIFY_OUTPUT"
  # Append verify results to log
  {
    echo "── Verification Results ──"
    echo "$VERIFY_OUTPUT"
    echo ""
  } >> "$DEPLOY_LOG" 2>/dev/null || true
  echo
  echo "  Log saved: ${DEPLOY_LOG}"
fi

# ── Post-deploy: process roles.yaml if present ──
ROLES_FILE=""
if [[ -d "$INPUT" && -f "${INPUT}/roles.yaml" ]]; then
  ROLES_FILE="${INPUT}/roles.yaml"
fi

# Also check the scenario template if we came from new-agent.sh
[[ -z "$ROLES_FILE" && -d "$INPUT" ]] && {
  for rf in "${INPUT}/roles.yaml" "${INPUT}/../roles.yaml"; do
    [[ -f "$rf" ]] && ROLES_FILE="$rf" && break
  done
}

UAMI_ID=$(jq -r '.properties.outputs.managedIdentityId.value // empty' "$TMP" 2>/dev/null)
UAMI_PRINCIPAL=$(az identity show --ids "$UAMI_ID" --query principalId -o tsv 2>/dev/null || echo "")

if [[ -n "$ROLES_FILE" && -f "$ROLES_FILE" ]]; then
  echo
  echo "── Setting up UAMI roles (from roles.yaml) ──"
  [[ -n "$UAMI_PRINCIPAL" ]] && echo "  UAMI principal ID: ${UAMI_PRINCIPAL}"
  echo

  python3 -c "
import yaml, sys, os

uami = '${UAMI_PRINCIPAL}'
sub = '${SUB}'
rg = '${RG}'
ag = '${AG}'
loc = '${LOC}'

with open('${ROLES_FILE}') as f:
    data = yaml.safe_load(f)

for role in (data.get('roles') or []):
    rtype = role.get('type', 'manual')
    name = role.get('name', 'unnamed')
    instructions = role.get('instructions', '')

    if rtype == 'azure-role':
        scope = role.get('scope', '')
        role_id = role.get('role_definition_id', '')
        print(f'  Granting Azure role: {name}')
        cmd = f'az role assignment create --subscription \"{sub}\" --assignee-object-id {uami} --assignee-principal-type ServicePrincipal --role \"{role_id}\" --scope \"{scope}\"'
        print(f'    Command: {cmd}')
        if uami:
            os.system(cmd)
        else:
            print('    SKIPPED — UAMI principal ID not available')

    elif rtype == 'adx-principal':
        scope = role.get('scope', '')
        adx_role = role.get('role', 'Viewer')
        print(f'  Granting ADX role: {name} ({adx_role})')
        parts = scope.split('/databases/')
        if len(parts) == 2 and uami:
            cluster_url = parts[0]
            db = parts[1]
            # Try to run automatically
            cmd = f'az kusto database-principal-assignment create --cluster-name \"{cluster_url.split(\"/\")[-1]}\" --database-name \"{db}\" --principal-id \"{uami}\" --principal-type App --role \"{adx_role}\" --principal-assignment-name \"sre-agent-{ag}\" --subscription \"{sub}\" 2>/dev/null || az kusto database add-principal --cluster-name \"{cluster_url.split(\"/\")[-1]}\" --database-name \"{db}\" --value name=\"sre-agent-{ag}\" type=\"App\" app-id=\"{uami}\" role=\"{adx_role}\" --subscription \"{sub}\" 2>/dev/null'
            if os.system(cmd) == 0:
                print(f'    ✅ ADX {adx_role} granted on {db}')
            else:
                print(f'    ⚠ Could not auto-grant. Run manually:')
                print(f'    az kusto database add-principal --cluster-name \"{cluster_url.split(\"/\")[-1]}\" --database-name \"{db}\" --value name=\"sre-agent-{ag}\" type=\"App\" app-id=\"{uami}\" role=\"{adx_role}\" --subscription \"{sub}\"')
        else:
            print(f'    Run manually after deploy — scope: {scope}')

    elif rtype == 'token':
        env_var = role.get('env_var', '')
        print(f'  Token required: {name}')
        if env_var:
            print(f'    Export {env_var}=<value> in your environment before running deploy.sh')
        if instructions:
            for line in instructions.strip().split(chr(10)):
                print(f'    {line}')

    elif rtype == 'manual':
        print(f'  Manual setup required: {name}')
        if instructions:
            for line in instructions.strip().split(chr(10)):
                print(f'    {line}')
        if uami:
            print(f'    UAMI principal ID: {uami}')

    elif rtype == 'api-connection':
        api_name = role.get('api', '')
        conn_name = f'{ag}-{api_name}'
        print(f'  Creating API connection: {name} ({api_name})')
        # Create the Microsoft.Web/connections resource
        create_cmd = (
            f'az resource create '
            f'--subscription \"{sub}\" '
            f'--resource-group \"{rg}\" '
            f'--resource-type \"Microsoft.Web/connections\" '
            f'--name \"{conn_name}\" '
            f'--location \"{loc}\" '
            f'--properties \'{{\"displayName\":\"{name}\",\"api\":{{\"id\":\"/subscriptions/{sub}/providers/Microsoft.Web/locations/{loc}/managedApis/{api_name}\"}}}}\' '
            f'--api-version 2016-06-01'
        )
        print(f'    Creating connection resource...')
        if os.system(create_cmd) == 0:
            # Get the consent URL
            consent_cmd = (
                f'az rest --subscription \"{sub}\" --method POST '
                f'--url \"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/connections/{conn_name}/listConsentLinks?api-version=2016-06-01\" '
                f'--body \'{{\"parameters\":[{{\"parameterName\":\"token\",\"redirectUrl\":\"https://portal.azure.com\"}}]}}\' '
                f'--query \"value[0].link\" -o tsv 2>/dev/null'
            )
            import subprocess
            result = subprocess.run(consent_cmd, shell=True, capture_output=True, text=True)
            consent_url = result.stdout.strip()
            if consent_url:
                print(f'    ✅ Connection created. Open this URL to sign in:')
                print(f'    {consent_url}')
            else:
                print(f'    ✅ Connection created. Get consent URL from portal:')
                print(f'    Portal → Resource Group → {conn_name} → Edit API Connection → Authorize')
        else:
            print(f'    ❌ Failed to create connection. Create manually in portal.')

    print()
" 2>/dev/null || echo "  Could not process roles.yaml (python3 + pyyaml required)"
fi

# ── Recipe-specific post-deploy instructions ──
if [[ -d "$INPUT" ]]; then
  SCENARIO=$(jq -r '._scenario // empty' "${INPUT}/agent.json" 2>/dev/null)
  WH_ENABLED=$(jq -r '.toggles.enableWebhookBridge // false' "${INPUT}/agent.json" 2>/dev/null)
  WH_URL=$(jq -r '.properties.outputs.webhookBridgeTriggerUrl.value // empty' "$TMP" 2>/dev/null)

  case "$SCENARIO" in
    dynatrace-mcp)
      # Try to get the Logic App callback URL
      WH_CALLBACK=$(az rest --method POST \
        --url "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Logic/workflows/${AG}-webhook-bridge/triggers/incoming_webhook/listCallbackUrl?api-version=2019-05-01" \
        --query value -o tsv 2>/dev/null || echo "")
      echo
      echo "── Dynatrace setup (required to receive alerts) ──"
      echo
      if [[ -n "$WH_CALLBACK" ]]; then
        echo "  Webhook bridge URL (use this in Dynatrace):"
        echo "     ${WH_CALLBACK}"
      else
        echo "  ⚠ Webhook bridge not found. Check Azure portal → ${RG} → ${AG}-webhook-bridge"
      fi
      echo
      echo "  Option A: Dynatrace Workflow (recommended)"
      echo "  ─────────────────────────────────────────────"
      echo "  1. Go to Dynatrace → Automations → Workflows → + Workflow"
      echo "  2. Add trigger: 'Davis problem' trigger"
      echo "     - Filter: event.status_transition == \"CREATED\""
      echo "       (fires once per problem, not on every status update)"
      echo "  3. Add action: 'Send HTTP request'"
      echo "     - Method: POST"
      if [[ -n "$WH_CALLBACK" ]]; then
        echo "     - URL: ${WH_CALLBACK}"
      else
        echo "     - URL: <webhook bridge URL>"
      fi
      echo "     - Headers: Content-Type: application/json"
      echo "     - Payload:"
      echo '       {'
      echo '         "ProblemID": "{{ event()['"'"'event.id'"'"'] }}",'
      echo '         "ProblemTitle": "{{ event()['"'"'display_id'"'"'] }}: {{ event()['"'"'event.name'"'"'] }}",'
      echo '         "State": "{{ event()['"'"'event.status'"'"'] }}",'
      echo '         "ProblemSeverity": "{{ event()['"'"'event.category'"'"'] }}",'
      echo '         "ProblemURL": "{{ environment().url }}/ui/apps/dynatrace.classic.problems/#problems/problemdetails;pid={{ event()['"'"'event.id'"'"'] }}",'
      echo '         "ImpactedEntities": "{{ event()['"'"'affected_entity_ids'"'"'] }}",'
      echo '         "ProblemDetailsText": "{{ event()['"'"'event.name'"'"'] }}"'
      echo '       }'
      echo "  4. Grant workflow permissions:"
      echo "     Settings → Authorization → Automation Service → grant permissions"
      echo "  5. Activate the workflow"
      echo
      echo "  Option B: Classic webhook (simpler but less control)"
      echo "  ────────────────────────────────────────────────────"
      echo "  1. Go to Settings → Integration → Problem notifications"
      echo "  2. Add 'Custom Integration' webhook"
      if [[ -n "$WH_CALLBACK" ]]; then
        echo "  3. URL: ${WH_CALLBACK}"
      else
        echo "  3. URL: <webhook bridge URL>"
      fi
      echo "  4. Send test notification to verify"
      echo
      echo "  Test: trigger a problem in Dynatrace (or use the test button)"
      echo "  Then check the agent portal for the incoming investigation:"
      echo "  Portal: https://sre.azure.com/#/agent/${SUB}/${RG}/${AG}"
      echo
      ;;
    pagerduty-law-vmcosmos)
      echo
      echo "── PagerDuty setup ──"
      echo
      echo "  1. Open the agent portal: https://sre.azure.com/#/agent/${SUB}/${RG}/${AG}"
      echo "  2. Navigate to Incident Platforms → PagerDuty"
      echo "  3. Complete the OAuth flow to connect your PagerDuty account"
      echo "  4. Select which PagerDuty services to monitor"
      echo "  5. The pd-p1p2 response plan routes P1/P2 incidents with customInstructions"
      echo
      ;;
  esac
fi

rm -f "$TMP"
