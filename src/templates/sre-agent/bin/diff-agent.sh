#!/usr/bin/env bash
# diff-agent.sh — Compare local config against a deployed agent.
#
# Shows what will be created, updated, or is unchanged.
# Useful before deploy to preview changes, or in CI/CD for review gates.
#
# Usage:
#   ./diff-agent.sh <subscription> <resource-group> <agent-name> <config-dir>
#
# Exit codes:
#   0 = no changes (everything matches)
#   1 = changes detected (prints diff table)
#   2 = agent doesn't exist (all items will be created)

set -uo pipefail

usage() {
  cat <<EOF
Usage: $0 <subscription> <resource-group> <agent-name> <config-dir>

Arguments:
  <subscription>      Subscription
  <resource-group>    Resource group
  <agent-name>        Agent name
  <config-dir>        Recipe/config directory

Options:
  -h, --help          Show this help
EOF
  exit "${1:-0}"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -eq 4 ]] || usage 2

SUB="$1"
RG="$2"
AGENT="$3"
CONFIG_DIR="$4"

az() { command az "$@" --subscription "$SUB"; }

API_VERSION="2025-05-01-preview"
ARM_BASE="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/agents/${AGENT}"

# Check if agent exists
AGENT_JSON=$(az rest -m GET --url "${ARM_BASE}?api-version=${API_VERSION}" -o json 2>/dev/null || echo "{}")
ENDPOINT=$(echo "$AGENT_JSON" | jq -r '.properties.agentEndpoint // empty')

if [[ -z "$ENDPOINT" || "$ENDPOINT" == "null" ]]; then
  echo "Agent '${AGENT}' does not exist in ${RG}. All items will be CREATED."
  echo ""
  # Count connectors from connectors.json
  if [[ -f "${CONFIG_DIR}/connectors.json" ]]; then
    toggle_ct=0
    for tog in enableLogAnalyticsConnector enableAppInsightsConnector enableAzureMonitorConnector; do
      v=$(jq -r ".toggles.${tog} // false" "${CONFIG_DIR}/connectors.json" 2>/dev/null)
      if [[ "$v" == "true" ]]; then
        toggle_ct=$((toggle_ct + 1))
        case "$tog" in
          enableLogAnalyticsConnector) echo "    + connector: Log Analytics (toggle)" ;;
          enableAppInsightsConnector)  echo "    + connector: App Insights (toggle)" ;;
          enableAzureMonitorConnector) echo "    + connector: Azure Monitor (toggle)" ;;
        esac
      fi
    done
    arr_ct=$(jq -r '.connectors // [] | length' "${CONFIG_DIR}/connectors.json" 2>/dev/null)
    if [[ "$arr_ct" -gt 0 ]]; then
      for cname in $(jq -r '.connectors[].name' "${CONFIG_DIR}/connectors.json" 2>/dev/null); do
        ctype=$(jq -r ".connectors[] | select(.name==\"$cname\") | .properties.dataConnectorType" "${CONFIG_DIR}/connectors.json")
        echo "    + connector: ${cname} (${ctype})"
      done
    fi
  fi
  # Check webhook bridge
  if [[ -f "${CONFIG_DIR}/agent.json" ]]; then
    wh=$(jq -r '.toggles.enableWebhookBridge // false' "${CONFIG_DIR}/agent.json" 2>/dev/null)
    [[ "$wh" == "true" ]] && echo "    + webhook bridge (Logic App)"
  fi
  # Count config/ items
  for d in skills subagents tools hooks common-prompts plugin-configs repos; do
    ct=$(find "${CONFIG_DIR}/config/${d}" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$ct" -gt 0 ]] && echo "    + ${d}: ${ct} (new)"
  done
  for d in scheduled-tasks incident-filters http-triggers incident-platforms; do
    ct=$(find "${CONFIG_DIR}/automations/${d}" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$ct" -gt 0 ]] && echo "    + ${d}: ${ct} (new)"
  done
  # Knowledge files
  if [[ -d "${CONFIG_DIR}/data" ]]; then
    kct=$(find "${CONFIG_DIR}/data" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    [[ "$kct" -gt 0 ]] && echo "    + knowledge: ${kct} file(s)"
  fi
  exit 2
fi

TOKEN=$(az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null)
dp_get() { curl -sS "$ENDPOINT$1" -H "Authorization: Bearer $TOKEN" 2>/dev/null; }

CREATES=0
ORPHANS=0
UNCHANGED=0
RESULTS=""

compare_items() {
  local label="$1" config_dir="$2" deployed_names="$3"
  local config_names=""

  if [[ -d "$config_dir" ]]; then
    for f in "${config_dir}"/*.yaml; do
      [[ -f "$f" ]] || continue
      local name
      name=$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$f')); print(d.get('metadata',{}).get('name','') or d.get('name',''))" 2>/dev/null)
      [[ -n "$name" ]] && config_names="${config_names} ${name}"
    done
  fi

  for name in $config_names; do
    if echo "$deployed_names" | grep -qw "$name"; then
      RESULTS="${RESULTS}\n  ${label}/${name}|= match"
      UNCHANGED=$((UNCHANGED + 1))
    else
      RESULTS="${RESULTS}\n  ${label}/${name}|+ CREATE"
      CREATES=$((CREATES + 1))
    fi
  done

  # Items deployed but not in config (orphaned)
  for name in $deployed_names; do
    [[ -z "$name" ]] && continue
    if ! echo "$config_names" | grep -qw "$name"; then
      RESULTS="${RESULTS}\n  ${label}/${name}|- ORPHAN (deployed, not in config)"
      ORPHANS=$((ORPHANS + 1))
      UNCHANGED=$((UNCHANGED + 1))
    fi
  done
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Change Detection: ${AGENT} in ${RG}"
echo "═══════════════════════════════════════════════════"
echo ""

# Skills
DEPLOYED_SKILLS=$(dp_get "/api/v1/extendedAgent/skills" | jq -r '(if type == "array" then . elif .value then .value else [] end)[].name' 2>/dev/null | tr '\n' ' ')
compare_items "skills" "${CONFIG_DIR}/config/skills" "$DEPLOYED_SKILLS"

# Subagents
DEPLOYED_SA=$(dp_get "/api/v2/extendedAgent/agents" | jq -r '.value[].name' 2>/dev/null | tr '\n' ' ')
compare_items "subagents" "${CONFIG_DIR}/config/subagents" "$DEPLOYED_SA"

# Hooks
DEPLOYED_HOOKS=$(dp_get "/api/v2/extendedAgent/hooks" | jq -r '(.value // .)[].name' 2>/dev/null | tr '\n' ' ')
compare_items "hooks" "${CONFIG_DIR}/config/hooks" "$DEPLOYED_HOOKS"

# Common Prompts
DEPLOYED_PROMPTS=$(dp_get "/api/v2/extendedAgent/commonprompts" | jq -r '(.value // .)[].name' 2>/dev/null | tr '\n' ' ')
compare_items "common-prompts" "${CONFIG_DIR}/config/common-prompts" "$DEPLOYED_PROMPTS"

# Scheduled Tasks
DEPLOYED_TASKS=$(dp_get "/api/v1/scheduledtasks" | jq -r '.[].name' 2>/dev/null | sort -u | tr '\n' ' ')
compare_items "scheduled-tasks" "${CONFIG_DIR}/automations/scheduled-tasks" "$DEPLOYED_TASKS"

# Incident Filters — deep compare (field-level diff)
DEPLOYED_FILTERS_JSON=$(dp_get "/api/v1/incidentPlayground/filters" 2>/dev/null || echo "[]")
DEPLOYED_FILTERS=$(echo "$DEPLOYED_FILTERS_JSON" | jq -r '.[].id' 2>/dev/null | tr '\n' ' ')
DEPLOYED_HANDLERS_JSON=$(dp_get "/api/v1/incidentPlayground/handlers" 2>/dev/null || echo "[]")
FILTER_DIR="${CONFIG_DIR}/automations/incident-filters"
if [[ -d "$FILTER_DIR" ]]; then
  for f in "${FILTER_DIR}"/*.yaml; do
    [[ -f "$f" ]] || continue
    local_name=$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$f')); print(d.get('metadata',{}).get('name',''))" 2>/dev/null)
    [[ -z "$local_name" ]] && continue
    if echo "$DEPLOYED_FILTERS" | grep -qw "$local_name"; then
      # Compare key fields
      deployed=$(echo "$DEPLOYED_FILTERS_JSON" | jq -c --arg n "$local_name" '[.[] | select(.id == $n)][0] // {}' 2>/dev/null)
      local_spec=$(python3 -c "
import yaml,json,sys
d=yaml.safe_load(open('$f'))
s=d.get('spec',{})
# Remove fields the API doesn't return or that are metadata
for k in ['customInstructions','incidentPlatform','maxAutomatedInvestigationAttempts']:
  s.pop(k,None)
print(json.dumps(s))
" 2>/dev/null)
      diffs=""
      for key in agentMode deepInvestigationEnabled isEnabled; do
        local_val=$(echo "$local_spec" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null)
        deploy_val=$(echo "$deployed" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null)
        if [[ -n "$local_val" && "$local_val" != "$deploy_val" ]]; then
          diffs="${diffs} ${key}:${deploy_val}→${local_val}"
        fi
      done
      # Check handler customInstructions
      local_ci=$(python3 -c "import yaml,sys; d=yaml.safe_load(open('$f')); print(d.get('spec',{}).get('customInstructions',''))" 2>/dev/null)
      deploy_ci=$(echo "$DEPLOYED_HANDLERS_JSON" | jq -r --arg n "$local_name" '[.[] | select(.incidentFilterId == $n)][0].customInstructions // ""' 2>/dev/null)
      if [[ -n "$local_ci" && "$local_ci" != "$deploy_ci" ]]; then
        diffs="${diffs} customInstructions:changed"
      fi
      if [[ -n "$diffs" ]]; then
        RESULTS="${RESULTS}\n  incident-filters/${local_name}|~ UPDATE (${diffs})"
        CREATES=$((CREATES + 1))
      else
        RESULTS="${RESULTS}\n  incident-filters/${local_name}|= match"
        UNCHANGED=$((UNCHANGED + 1))
      fi
    else
      RESULTS="${RESULTS}\n  incident-filters/${local_name}|+ CREATE"
      CREATES=$((CREATES + 1))
    fi
  done
  # Orphans
  for name in $DEPLOYED_FILTERS; do
    [[ -z "$name" ]] && continue
    if ! ls "${FILTER_DIR}"/*.yaml 2>/dev/null | xargs grep -l "name: ${name}" >/dev/null 2>/dev/null; then
      RESULTS="${RESULTS}\n  incident-filters/${name}|- ORPHAN (deployed, not in config)"
      ORPHANS=$((ORPHANS + 1))
      UNCHANGED=$((UNCHANGED + 1))
    fi
  done
fi

# Repos
DEPLOYED_REPOS=$(dp_get "/api/v2/repos" | jq -r '(.value // .)[].name' 2>/dev/null | tr '\n' ' ')
compare_items "repos" "${CONFIG_DIR}/config/repos" "$DEPLOYED_REPOS"

# Connectors (toggle-based, just check count)
DEPLOYED_CONN=$(az rest -m GET --url "${ARM_BASE}/DataConnectors?api-version=${API_VERSION}" --query "value[].name" -o tsv 2>/dev/null | tr '\n' ' ')
CONFIG_CONN_CT=$(jq '.toggles | to_entries | map(select(.key | startswith("enable")) | select(.value == true)) | length' "${CONFIG_DIR}/connectors.json" 2>/dev/null || echo 0)
DEPLOYED_CONN_CT=$(echo "$DEPLOYED_CONN" | wc -w | tr -d ' ')
if [[ "$CONFIG_CONN_CT" -eq "$DEPLOYED_CONN_CT" ]]; then
  RESULTS="${RESULTS}\n  connectors|= ${DEPLOYED_CONN_CT} connector(s) — no change"
else
  RESULTS="${RESULTS}\n  connectors|~ ${DEPLOYED_CONN_CT} deployed → ${CONFIG_CONN_CT} in config"
fi

# Print results
printf "  %-40s %s\n" "Resource" "Action"
printf "  %-40s %s\n" "────────────────────────────────────────" "──────────"
echo -e "$RESULTS" | while IFS='|' read -r name action; do
  [[ -z "$name" ]] && continue
  printf "  %-40s %s\n" "$name" "$action"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Summary: ${CREATES} new, ${UNCHANGED} match, ${ORPHANS} orphan"
echo "═══════════════════════════════════════════════════"
echo ""

# Exit 1 only if there are new items to create (needs deploy)
[[ "$CREATES" -gt 0 ]] && exit 1
exit 0
