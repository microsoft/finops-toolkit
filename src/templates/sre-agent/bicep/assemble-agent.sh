#!/usr/bin/env bash
# assemble-agent.sh — Reconstruct deploy-ready files from exported directory layout.
#
# Reads the structured directory produced by export-agent.sh and assembles:
#   <dir>.parameters.json  — Bicep-deployable (for deploy.sh)
#   <dir>.extras.json      — Data-plane config (for apply-extras.sh)
#
# Usage:
#   ./assemble-agent.sh <export-directory> [--secrets <env-file>]
#   ./assemble-agent.sh my-agent-export
#   ./assemble-agent.sh my-agent-export --secrets connectors.secrets.env
#
# The directory must contain agent.json. All other files are optional.
# File references in config/ JSONs (paths to .md files) are resolved inline.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <export-directory> [options]

Required:
  <export-directory>     Directory created by export-agent.sh

Options:
  --secrets <file>       Secrets env file (default: <dir>/connectors.secrets.env)
  --output <prefix>      Output file prefix (default: <dir>)
  -h, --help             Show this help
EOF
  exit "${1:-0}"
}

DIR="" SECRETS="" OUT_PREFIX=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secrets)  SECRETS="$2"; shift 2 ;;
    --output)   OUT_PREFIX="$2"; shift 2 ;;
    -h|--help)  usage 0 ;;
    -*)         echo "Unknown option: $1" >&2; usage 1 ;;
    *)          DIR="$1"; shift ;;
  esac
done

[[ -n "$DIR" ]] || { echo "Error: export directory required" >&2; usage 1; }
[[ -d "$DIR" ]] || { echo "Error: directory not found: $DIR" >&2; exit 1; }
[[ -f "${DIR}/agent.json" ]] || { echo "Error: ${DIR}/agent.json not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 1; }

[[ -n "$OUT_PREFIX" ]] || OUT_PREFIX="$DIR"
[[ -n "$SECRETS" ]] || SECRETS="${DIR}/connectors.secrets.env"

PARAMS_FILE="${OUT_PREFIX}.parameters.json"
EXTRAS_FILE="${OUT_PREFIX}.extras.json"

_log()  { echo "  $*"; }
_info() { echo "── $* ──"; }

# ── Load secrets into env vars (for connector token substitution) ──
if [[ -f "$SECRETS" ]]; then
  _info "Loading secrets from ${SECRETS}"
  set -a
  # shellcheck disable=SC1090
  source "$SECRETS"
  set +a
fi

# ── Helper: resolve file references in JSON ──
# Config JSONs use relative paths like "skills/my-skill.md" for content fields.
# This function reads the file and inlines its content.
resolve_file_refs() {
  local json="$1" base_dir="$2"
  python3 -c "
import json, sys, os
base = '$base_dir'
data = json.loads('''$json''') if isinstance('''$json''', str) else json.load(sys.stdin)
def resolve(obj):
    if isinstance(obj, str):
        # Check if it's a relative path to a file in config/
        for prefix in ['skills/', 'subagents/', 'common-prompts/']:
            if obj.startswith(prefix) and obj.endswith(('.md', '.txt')):
                for config_base in ['config']:
                    path = os.path.join(base, config_base, obj)
                    if os.path.isfile(path):
                        with open(path) as f:
                            return f.read()
        # Also handle _file: prefix (legacy)
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

# ── Helper: collect all YAML (or JSON) files from a config subdirectory into a JSON array ──
# Reads from config/ and automations/
collect_config() {
  local subdir="$1"
  local result="[]"
  for base in "${DIR}/config" "${DIR}/automations"; do
    local full="${base}/${subdir}"
    if [[ -d "$full" ]]; then
      local items="[]"
      # Read YAML files
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
      # Also read JSON files (for backward compat)
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

# ── Helper: substitute env vars in connector JSON ──
resolve_env_vars() {
  local json="$1"
  echo "$json" | python3 -c "
import json, sys, os, re
data = json.load(sys.stdin)
def sub(obj):
    if isinstance(obj, str):
        return re.sub(r'\\\$\{(\w+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), obj)
    elif isinstance(obj, dict):
        return {k: sub(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sub(v) for v in obj]
    return obj
print(json.dumps(sub(data)))
" 2>/dev/null || echo "$json"
}

# ═══════ Read agent.json ═══════

_info "Reading agent.json"
AGENT_JSON=$(cat "${DIR}/agent.json")

AGENT_NAME=$(echo "$AGENT_JSON"  | jq -r '.identity.agentName')
AGENT_RG=$(echo "$AGENT_JSON"    | jq -r '.identity.resourceGroup')
AGENT_SUB=$(echo "$AGENT_JSON"   | jq -r '.identity.subscription // ""')
AGENT_LOC=$(echo "$AGENT_JSON"   | jq -r '.identity.location')
TARGET_RGS=$(echo "$AGENT_JSON"  | jq -c 'if .identity.targetResourceGroups | type == "array" then .identity.targetResourceGroups elif .identity.targetResourceGroups | type == "string" and length > 0 then [.identity.targetResourceGroups | split(",")[] | gsub("^\\s+|\\s+$"; "")] else [] end')
ACCESS=$(echo "$AGENT_JSON"      | jq -r '.access.accessLevel')
ACTION=$(echo "$AGENT_JSON"      | jq -r '.access.actionMode')
TOGGLES=$(echo "$AGENT_JSON"     | jq -c '.toggles // {}')
UPGRADE_CHANNEL=$(echo "$AGENT_JSON" | jq -r '.upgradeChannel // "Preview"')
MODEL_PROVIDER=$(echo "$AGENT_JSON"  | jq -r '.defaultModelProvider // "Anthropic"')
MONTHLY_LIMIT=$(echo "$AGENT_JSON"   | jq -r '.monthlyAgentUnitLimit // 10000')
TAGS=$(echo "$AGENT_JSON"            | jq -c '.tags // {}')
EXISTING_UAMI=$(echo "$AGENT_JSON"   | jq -r '.existingUamiId // ""')
EXISTING_AI=$(echo "$AGENT_JSON"    | jq -r '.existingAgentAppInsightsId // ""')

_log "Agent: ${AGENT_NAME} (${AGENT_LOC}, ${AGENT_RG})"

# ═══════ Read connectors.json ═══════

_info "Reading connectors.json"
CONNECTORS="[]"
CONNECTOR_TOGGLES="{}"
if [[ -f "${DIR}/connectors.json" ]]; then
  RAW_CONN=$(resolve_env_vars "$(cat "${DIR}/connectors.json")")
  # connectors.json can be an array (legacy) or object { toggles, connectors }
  if echo "$RAW_CONN" | jq -e 'type == "array"' >/dev/null 2>&1; then
    CONNECTORS="$RAW_CONN"
  else
    CONNECTOR_TOGGLES=$(echo "$RAW_CONN" | jq -c '.toggles // {}')
    CONNECTORS=$(echo "$RAW_CONN" | jq -c '.connectors // []')
  fi
  _log "$(echo "$CONNECTORS" | jq 'length') connector(s) from connectors.json"
fi

_log "Total: $(echo "$CONNECTORS" | jq 'length') connector(s)"

# ═══════ Read config/ ═══════

_info "Assembling config/"

# Skills — read JSON, resolve .md file references
RAW_SKILLS=$(collect_config "skills")
SKILLS=$(resolve_file_refs "$RAW_SKILLS" "$DIR")
_log "skills: $(echo "$SKILLS" | jq 'length')"

# Subagents — read JSON, resolve .md file references
RAW_SUBAGENTS=$(collect_config "subagents")
SUBAGENTS=$(resolve_file_refs "$RAW_SUBAGENTS" "$DIR")
_log "subagents: $(echo "$SUBAGENTS" | jq 'length')"

# Simple config arrays (no file refs needed)
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

INCIDENT_PLATFORMS=$(resolve_env_vars "$(collect_config "incident-platforms")")
_log "incident-platforms: $(echo "$INCIDENT_PLATFORMS" | jq 'length')"

REPOS=$(collect_config "repos")
_log "repos: $(echo "$REPOS" | jq 'length')"

MARKETPLACES="[]"
[[ -d "${DIR}/config/plugins/marketplaces" ]] && MARKETPLACES=$(collect_config "plugins/marketplaces")
INSTALLATIONS="[]"
[[ -d "${DIR}/config/plugins/installations" ]] && INSTALLATIONS=$(collect_config "plugins/installations")

# ═══════ Read data/ ═══════

_info "Reading data/"

KNOWLEDGE="[]"
[[ -f "${DIR}/data/knowledge.json" ]] && KNOWLEDGE=$(cat "${DIR}/data/knowledge.json")
KNOWLEDGE_ITEMS="[]"
[[ -f "${DIR}/data/knowledge-items.json" ]] && KNOWLEDGE_ITEMS=$(cat "${DIR}/data/knowledge-items.json")
SYNTH_KNOWLEDGE="[]"
SYNTH_KNOWLEDGE_DIR=""
[[ -f "${DIR}/data/synthesized-knowledge.json" ]] && SYNTH_KNOWLEDGE=$(cat "${DIR}/data/synthesized-knowledge.json")
# Discover synthesized knowledge files on disk
if [[ -d "${DIR}/data/synthesized-knowledge" ]]; then
  SYNTH_DIR_ABS="$(cd "${DIR}/data/synthesized-knowledge" && pwd)"
  SYNTH_KNOWLEDGE_DIR="$SYNTH_DIR_ABS"
  SK_COUNT=$(find "$SYNTH_DIR_ABS" -type f | wc -l | tr -d ' ')
  _log "Found ${SK_COUNT} synthesized knowledge file(s) in data/synthesized-knowledge/"
fi
REPO_INSTRUCTIONS="[]"
[[ -f "${DIR}/data/repo-instructions.json" ]] && REPO_INSTRUCTIONS=$(cat "${DIR}/data/repo-instructions.json")

# Auto-discover .md files in data/ and data/knowledge/ → convert to knowledge items for upload
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

# ═══════ Write parameters.json (Bicep) ═══════

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
  --argjson targetRgs "$TARGET_RGS" \
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
      "tags":                            { "value": $tags },
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
      "pluginConfigs":                 { "value": $pluginConfigs }
    }
  }' > "$PARAMS_FILE"

_log "Wrote $(wc -c < "$PARAMS_FILE" | tr -d ' ') bytes"

# ═══════ Write extras.json (data-plane) ═══════

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

# Merge admin settings if present (adminUsers for cross-tenant access)
if [[ -f "${DIR}/admin-settings.json" ]]; then
  _log "Merging admin-settings.json (adminUsers) into extras"
  EXTRAS_WITH_ADMIN=$(jq -s '.[0] * {
    "adminUsers": (.[1].adminUsers // []),
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
echo "Deploy with:"
echo "  ./deploy.sh ${PARAMS_FILE}"
echo "  ./apply-extras.sh ${AGENT_SUB:-\$(az account show -q id -o tsv)} ${AGENT_RG} ${AGENT_NAME} ${EXTRAS_FILE}"
echo
