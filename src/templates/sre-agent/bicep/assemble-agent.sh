#!/usr/bin/env bash
# assemble-agent.sh — Reconstruct deploy-ready files from exported directory layout.
#
# Reads the structured directory produced by export-agent.sh and assembles:
#   <dir>.parameters.json  — Bicep-deployable (for deploy.sh)
#   <dir>.extras.json      — Data-plane config (for apply-extras.sh)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <export-directory> [options]

Required:
  <export-directory>                    Directory created by export-agent.sh

Identity options:
  -g, --resource-group <name>          Resource group (portal field: "Resource group")
  -n, --name <name>                    Agent name (portal field: "Agent name")
  -l, --location <region>              Region (portal field: "Region")
      --subscription <id>              Subscription (portal field: "Subscription")
      --target-resource-group <name>   Repeatable target resource group

Connector options:
      --cluster-uri <uri>              Substitute the recipe Kusto cluster URI token
      --cluster-resource-id <id>       Kusto cluster ARM resource ID

Other options:
      --output <prefix>                Output file prefix (default: <dir>)
  -h, --help                           Show this help
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

DIR=""
OUT_PREFIX=""
RESOURCE_GROUP=""
AGENT_NAME=""
LOCATION=""
SUBSCRIPTION_ID=""
CLUSTER_URI=""
CLUSTER_RESOURCE_ID=""
TARGET_RGS=()
POSITIONALS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --output)
      require_value "--output" "${2:-}"
      OUT_PREFIX="$2"
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      error_exit "Error: unknown flag '$1'" 2
      ;;
    *)
      POSITIONALS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#POSITIONALS[@]}" -ne 1 ]]; then
  error_exit "Error: export directory required" 1
fi

DIR="${POSITIONALS[0]}"
[[ -d "$DIR" ]] || error_exit "Error: directory not found: $DIR" 1
[[ -f "${DIR}/agent.json" ]] || error_exit "Error: ${DIR}/agent.json not found" 1
command -v jq >/dev/null || error_exit "Error: jq is required" 1
command -v python3 >/dev/null || error_exit "Error: python3 is required" 1

[[ -n "$OUT_PREFIX" ]] || OUT_PREFIX="$DIR"

PARAMS_FILE="${OUT_PREFIX}.parameters.json"
EXTRAS_FILE="${OUT_PREFIX}.extras.json"

_log()  { echo "  $*"; }
_info() { echo "── $* ──"; }

resolve_file_refs() {
  local json="$1" base_dir="$2"
  python3 -c "
import json, sys, os
base = '$base_dir'
data = json.loads('''$json''') if isinstance('''$json''', str) else json.load(sys.stdin)
def resolve(obj):
    if isinstance(obj, str):
        for prefix in ['skills/', 'subagents/', 'common-prompts/']:
            if obj.startswith(prefix) and obj.endswith(('.md', '.txt')):
                for config_base in ['config']:
                    path = os.path.join(base, config_base, obj)
                    if os.path.isfile(path):
                        with open(path) as f:
                            return f.read()
        if obj.startswith('_file:'):
            path = os.path.join(base, obj[6:])
            if os.path.isfile(path):
                with open(path) as f:
                    return f.read()
        return obj
    elif isinstance(obj, dict):
        return {k: resolve(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [resolve(v) for v in obj]
    return obj
print(json.dumps(resolve(data)))
" 2>/dev/null || echo "$json"
}

collect_config() {
  local subdir="$1"
  local result="[]"
  for base in "${DIR}/config" "${DIR}/automations"; do
    local full="${base}/${subdir}"
    if [[ -d "$full" ]]; then
      local items="[]"
      for f in "${full}"/*.yaml "${full}"/*.yml; do
        [[ -f "$f" ]] || continue
        local item
        item=$(python3 -c "
import sys, yaml, json
with open('$f') as fh:
    data = yaml.safe_load(fh)
print(json.dumps(data))
" 2>/dev/null) || continue
        items=$(echo "$items" | jq -c --argjson i "$item" '. + [$i]')
      done
      for f in "${full}"/*.json; do
        [[ -f "$f" ]] || continue
        local item
        item=$(cat "$f") || continue
        items=$(echo "$items" | jq -c --argjson i "$item" '. + [$i]' 2>/dev/null) || continue
      done
      result=$(echo "$result" "$items" | jq -sc 'add // []')
    fi
  done
  echo "$result"
}

resolve_cluster_uri_token() {
  local json="$1"
  local cluster_uri="$2"
  if [[ -z "$cluster_uri" ]]; then
    printf '%s' "$json"
    return 0
  fi

  CLUSTER_URI_VALUE="$cluster_uri" python3 -c '
import os
import sys
token = "${FINOPS_HUB_" + "CLUSTER_URI}"
cluster_uri = os.environ["CLUSTER_URI_VALUE"]
sys.stdout.write(sys.stdin.read().replace(token, cluster_uri))
' <<<"$json"
}

recipe_string_field() {
  local path="$1"
  echo "$AGENT_JSON" | jq -r "$path // empty | if . == null or . == \"null\" then \"\" else . end"
}

recipe_target_rgs() {
  echo "$AGENT_JSON" | jq -c '
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

_info "Reading agent.json"
AGENT_JSON=$(cat "${DIR}/agent.json")

RECIPE_AGENT_NAME=$(recipe_string_field '.identity.agentName')
RECIPE_AGENT_RG=$(recipe_string_field '.identity.resourceGroup')
RECIPE_AGENT_SUB=$(recipe_string_field '.identity.subscription')
RECIPE_AGENT_LOC=$(recipe_string_field '.identity.location')
RECIPE_TARGET_RGS=$(recipe_target_rgs)

AGENT_NAME=$(resolve_required_identity "$AGENT_NAME" "$RECIPE_AGENT_NAME" '--name / -n' 'Agent name')
AGENT_RG=$(resolve_required_identity "$RESOURCE_GROUP" "$RECIPE_AGENT_RG" '--resource-group / -g' 'Resource group')
AGENT_LOC=$(resolve_required_identity "$LOCATION" "$RECIPE_AGENT_LOC" '--location / -l' 'Region')
AGENT_SUB="${SUBSCRIPTION_ID:-$RECIPE_AGENT_SUB}"

if [[ "${#TARGET_RGS[@]}" -gt 0 ]]; then
  TARGET_RGS_JSON=$(printf '%s\n' "${TARGET_RGS[@]}" | jq -R . | jq -sc '.')
elif [[ "$RECIPE_TARGET_RGS" != "[]" ]]; then
  TARGET_RGS_JSON="$RECIPE_TARGET_RGS"
else
  TARGET_RGS_JSON=$(printf '%s\n' "$AGENT_RG" | jq -R . | jq -sc '.')
fi

ACCESS=$(echo "$AGENT_JSON" | jq -r '.access.accessLevel')
ACTION=$(echo "$AGENT_JSON" | jq -r '.access.actionMode')
TOGGLES=$(echo "$AGENT_JSON" | jq -c '.toggles // {}')
UPGRADE_CHANNEL=$(echo "$AGENT_JSON" | jq -r '.upgradeChannel // "Preview"')
MODEL_PROVIDER=$(echo "$AGENT_JSON" | jq -r '.defaultModelProvider // "Anthropic"')
MONTHLY_LIMIT=$(echo "$AGENT_JSON" | jq -r '.monthlyAgentUnitLimit // 10000')
TAGS=$(echo "$AGENT_JSON" | jq -c '.tags // {}')
EXISTING_UAMI=$(echo "$AGENT_JSON" | jq -r '.existingUamiId // ""')
EXISTING_AI=$(echo "$AGENT_JSON" | jq -r '.existingAgentAppInsightsId // ""')

_log "Agent: ${AGENT_NAME} (${AGENT_LOC}, ${AGENT_RG})"

_info "Reading connectors.json"
CONNECTORS="[]"
CONNECTOR_TOGGLES="{}"
if [[ -f "${DIR}/connectors.json" ]]; then
  RAW_CONN=$(resolve_cluster_uri_token "$(cat "${DIR}/connectors.json")" "$CLUSTER_URI")
  if echo "$RAW_CONN" | jq -e 'type == "array"' >/dev/null 2>&1; then
    CONNECTORS="$RAW_CONN"
  else
    CONNECTOR_TOGGLES=$(echo "$RAW_CONN" | jq -c '.toggles // {}')
    CONNECTORS=$(echo "$RAW_CONN" | jq -c '.connectors // []')
  fi
  _log "$(echo "$CONNECTORS" | jq 'length') connector(s) from connectors.json"
fi

_log "Total: $(echo "$CONNECTORS" | jq 'length') connector(s)"

_info "Assembling config/"

RAW_SKILLS=$(collect_config "skills")
SKILLS=$(resolve_file_refs "$RAW_SKILLS" "$DIR")
_log "skills: $(echo "$SKILLS" | jq 'length')"

RAW_SUBAGENTS=$(collect_config "subagents")
SUBAGENTS=$(resolve_file_refs "$RAW_SUBAGENTS" "$DIR")
_log "subagents: $(echo "$SUBAGENTS" | jq 'length')"

TOOLS=$(collect_config "tools")
_log "tools: $(echo "$TOOLS" | jq 'length')"

HOOKS=$(collect_config "hooks")
_log "hooks: $(echo "$HOOKS" | jq 'length')"

RAW_PROMPTS=$(collect_config "common-prompts")
COMMON_PROMPTS=$(resolve_file_refs "$RAW_PROMPTS" "$DIR")
_log "common-prompts: $(echo "$COMMON_PROMPTS" | jq 'length')"

SCHEDULED_TASKS=$(collect_config "scheduled-tasks")
_log "scheduled-tasks: $(echo "$SCHEDULED_TASKS" | jq 'length')"

INCIDENT_FILTERS=$(collect_config "incident-filters")
_log "incident-filters: $(echo "$INCIDENT_FILTERS" | jq 'length')"

HTTP_TRIGGERS=$(collect_config "http-triggers")
_log "http-triggers: $(echo "$HTTP_TRIGGERS" | jq 'length')"

PLUGIN_CONFIGS=$(collect_config "plugin-configs")
_log "plugin-configs: $(echo "$PLUGIN_CONFIGS" | jq 'length')"

INCIDENT_PLATFORMS=$(collect_config "incident-platforms")
_log "incident-platforms: $(echo "$INCIDENT_PLATFORMS" | jq 'length')"

REPOS=$(collect_config "repos")
_log "repos: $(echo "$REPOS" | jq 'length')"

MARKETPLACES="[]"
[[ -d "${DIR}/config/plugins/marketplaces" ]] && MARKETPLACES=$(collect_config "plugins/marketplaces")
INSTALLATIONS="[]"
[[ -d "${DIR}/config/plugins/installations" ]] && INSTALLATIONS=$(collect_config "plugins/installations")

_info "Reading data/"

KNOWLEDGE="[]"
[[ -f "${DIR}/data/knowledge.json" ]] && KNOWLEDGE=$(cat "${DIR}/data/knowledge.json")
KNOWLEDGE_ITEMS="[]"
[[ -f "${DIR}/data/knowledge-items.json" ]] && KNOWLEDGE_ITEMS=$(cat "${DIR}/data/knowledge-items.json")
SYNTH_KNOWLEDGE="[]"
SYNTH_KNOWLEDGE_DIR=""
[[ -f "${DIR}/data/synthesized-knowledge.json" ]] && SYNTH_KNOWLEDGE=$(cat "${DIR}/data/synthesized-knowledge.json")
if [[ -d "${DIR}/data/synthesized-knowledge" ]]; then
  SYNTH_DIR_ABS="$(cd "${DIR}/data/synthesized-knowledge" && pwd)"
  SYNTH_KNOWLEDGE_DIR="$SYNTH_DIR_ABS"
  SK_COUNT=$(find "$SYNTH_DIR_ABS" -type f | wc -l | tr -d ' ')
  _log "Found ${SK_COUNT} synthesized knowledge file(s) in data/synthesized-knowledge/"
fi
REPO_INSTRUCTIONS="[]"
[[ -f "${DIR}/data/repo-instructions.json" ]] && REPO_INSTRUCTIONS=$(cat "${DIR}/data/repo-instructions.json")

MD_FILES=$(find "${DIR}/data" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true; \
           find "${DIR}/data/knowledge" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
if [[ -n "$MD_FILES" ]]; then
  MD_COUNT=$(echo "$MD_FILES" | wc -l | tr -d ' ')
  _log "Found ${MD_COUNT} knowledge .md file(s) in data/"
  for mdf in $MD_FILES; do
    fname=$(basename "$mdf")
    content=$(cat "$mdf")
    KNOWLEDGE_ITEMS=$(echo "$KNOWLEDGE_ITEMS" | jq --arg name "$fname" --arg content "$content" \
      '. + [{"name": $name, "type": "KnowledgeText", "content": $content}]')
  done
fi

_log "knowledge: $(echo "$KNOWLEDGE" | jq 'length'), items: $(echo "$KNOWLEDGE_ITEMS" | jq 'length')"

_info "Writing ${PARAMS_FILE}"

jq -n \
  --arg agent "$AGENT_NAME" \
  --arg rg "$AGENT_RG" \
  --arg loc "$AGENT_LOC" \
  --arg access "$ACCESS" \
  --arg action "$ACTION" \
  --arg upgradeChannel "$UPGRADE_CHANNEL" \
  --arg modelProvider "$MODEL_PROVIDER" \
  --argjson monthlyLimit "$MONTHLY_LIMIT" \
  --argjson tags "$TAGS" \
  --arg existingUami "$EXISTING_UAMI" \
  --arg existingAi "$EXISTING_AI" \
  --arg clusterResourceId "$CLUSTER_RESOURCE_ID" \
  --argjson targetRgs "$TARGET_RGS_JSON" \
  --argjson toggles "$TOGGLES" \
  --argjson ctog "$CONNECTOR_TOGGLES" \
  --argjson connectors "$CONNECTORS" \
  --argjson tools "$TOOLS" \
  --argjson skills "$SKILLS" \
  --argjson subagents "$SUBAGENTS" \
  --argjson scheduledTasks "$SCHEDULED_TASKS" \
  --argjson incidentFilters "$INCIDENT_FILTERS" \
  --argjson commonPrompts "$COMMON_PROMPTS" \
  --argjson pluginConfigs "$PLUGIN_CONFIGS" \
  '{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "agentName":                     { "value": $agent },
      "agentResourceGroupName":        { "value": $rg },
      "location":                      { "value": $loc },
      "targetResourceGroups":          { "value": $targetRgs },
      "accessLevel":                   { "value": $access },
      "actionMode":                    { "value": $action },
      "upgradeChannel":                { "value": $upgradeChannel },
      "defaultModelProvider":          { "value": $modelProvider },
      "monthlyAgentUnitLimit":         { "value": $monthlyLimit },
      "tags":                          { "value": $tags },
      "existingManagedIdentityId":     { "value": $existingUami },
      "existingAgentAppInsightsId":    { "value": $existingAi },
      "enableAppInsightsConnector":    { "value": ($ctog.enableAppInsightsConnector // false) },
      "appInsightsResourceId":         { "value": ($ctog.appInsightsResourceId // "") },
      "appInsightsAppId":              { "value": ($ctog.appInsightsAppId // "") },
      "enableLogAnalyticsConnector":   { "value": ($ctog.enableLogAnalyticsConnector // false) },
      "lawResourceId":                 { "value": ($ctog.lawResourceId // "") },
      "enableAzureMonitorConnector":   { "value": ($ctog.enableAzureMonitorConnector // false) },
      "azureMonitorLookbackDays":      { "value": ($ctog.azureMonitorLookbackDays // 7) },
      "enableDailyHealthCheckTask":    { "value": ($toggles.enableDailyHealthCheckTask // false) },
      "enableDenyProdDeletesHook":     { "value": ($toggles.enableDenyProdDeletesHook // false) },
      "enableSafetyRulesPrompt":       { "value": ($toggles.enableSafetyRulesPrompt // false) },
      "enableWebhookBridge":           { "value": ($toggles.enableWebhookBridge // false) },
      "webhookBridgeTriggerUrl":       { "value": ($toggles.webhookBridgeTriggerUrl // "") },
      "connectors":                    { "value": [$connectors[] | select(.properties.dataConnectorType != "KnowledgeFile")] },
      "tools":                         { "value": $tools },
      "skills":                        { "value": $skills },
      "subagents":                     { "value": $subagents },
      "scheduledTasks":                { "value": [] },
      "incidentFilters":               { "value": [] },
      "commonPrompts":                 { "value": [($commonPrompts // [])[] | {name: (.metadata.name // .name), type: (.type // "CommonPrompt"), tags: (.tags // []), properties: (.spec // .properties // {})}] },
      "pluginConfigs":                 { "value": $pluginConfigs },
      "enableFinopsHubKustoViewerRole": { "value": ($clusterResourceId != "") },
      "finopsHubKustoClusterResourceId": { "value": $clusterResourceId }
    }
  }' > "$PARAMS_FILE"

_log "Wrote $(wc -c < "$PARAMS_FILE" | tr -d ' ') bytes"

_info "Writing ${EXTRAS_FILE}"

jq -n \
  --argjson repos "$REPOS" \
  --argjson incidentPlatforms "$INCIDENT_PLATFORMS" \
  --argjson incidentFilters "$INCIDENT_FILTERS" \
  --argjson scheduledTasks "$SCHEDULED_TASKS" \
  --argjson hooks "$HOOKS" \
  --argjson commonPrompts "$COMMON_PROMPTS" \
  --argjson httpTriggers "$HTTP_TRIGGERS" \
  --argjson knowledge "$KNOWLEDGE" \
  --argjson knowledgeItems "$KNOWLEDGE_ITEMS" \
  --argjson synthesizedKnowledge "$SYNTH_KNOWLEDGE" \
  --arg synthesizedKnowledgeDir "$SYNTH_KNOWLEDGE_DIR" \
  --argjson repoInstructions "$REPO_INSTRUCTIONS" \
  --argjson marketplaces "$MARKETPLACES" \
  --argjson installations "$INSTALLATIONS" \
  --argjson connectors "$CONNECTORS" \
  '{
    "repos": $repos,
    "incidentPlatforms": $incidentPlatforms,
    "incidentFilters": $incidentFilters,
    "scheduledTasks": $scheduledTasks,
    "hooks": [($hooks // [])[] | {name: (.metadata.name // .name), type: (.type // "GlobalHook"), tags: (.tags // []), properties: (.spec // .properties // {})}],
    "commonPrompts": [($commonPrompts // [])[] | {name: (.metadata.name // .name), type: (.type // "CommonPrompt"), tags: (.tags // []), properties: (.spec // .properties // {})}],
    "httpTriggers": $httpTriggers,
    "knowledge": $knowledge,
    "knowledgeItems": $knowledgeItems,
    "synthesizedKnowledge": $synthesizedKnowledge,
    "synthesizedKnowledgeDir": $synthesizedKnowledgeDir,
    "repoInstructions": $repoInstructions,
    "plugins": {
      "marketplaces": $marketplaces,
      "installations": $installations
    },
    "connectors": [$connectors[] | select(.properties.dataConnectorType == "Mcp" or .properties.dataConnectorType == "KnowledgeFile")]
  }' > "$EXTRAS_FILE"

if [[ -f "${DIR}/admin-settings.json" ]]; then
  _log "Merging admin-settings.json (adminUsers) into extras"
  EXTRAS_WITH_ADMIN=$(jq -s '.[0] * {
    "adminUsers": (.[1].adminUsers // [])
  }' "$EXTRAS_FILE" "${DIR}/admin-settings.json")
  echo "$EXTRAS_WITH_ADMIN" > "$EXTRAS_FILE"
fi

_log "Wrote $(wc -c < "$EXTRAS_FILE" | tr -d ' ') bytes"

echo
_info "Assembly complete"
echo
echo "  ${PARAMS_FILE}  ← for deploy.sh (Bicep)"
echo "  ${EXTRAS_FILE}  ← for apply-extras.sh (data-plane)"
echo
