#!/usr/bin/env bash
# verify-agent.sh — Verify an SRE Agent deployment is complete.
#
# Usage:
#   ./verify-agent.sh <subscription> <resource-group> <agent-name> [--expected <config-dir>]
#
# Queries ARM + data-plane APIs and prints a pass/fail table.
# If --expected is given, compares counts against the config directory.

set -uo pipefail

usage() {
  cat <<EOF
Usage: $0 <subscription> <resource-group> <agent-name> [--expected <config-dir>]

Arguments:
  <subscription>      Subscription
  <resource-group>    Resource group
  <agent-name>        Agent name

Options:
  --expected <dir>    Expected config directory
  -h, --help          Show this help
EOF
  exit "${1:-0}"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -ge 3 ]] || usage 2

SUB="$1"
RG="$2"
AGENT="$3"
EXPECTED_DIR=""
EXPECTED_CONFIG=""
EXPECTED_CONNECTORS=""
EXPECTED_CONFIG_HAS_CONNECTORS="false"
shift 3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected) EXPECTED_DIR="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) shift ;;
  esac
done

az() { command az "$@" --subscription "$SUB"; }

# Load expected-config.json if present
if [[ -n "$EXPECTED_DIR" && -f "${EXPECTED_DIR}/expected-config.json" ]]; then
  EXPECTED_CONFIG=$(cat "${EXPECTED_DIR}/expected-config.json")
  if echo "$EXPECTED_CONFIG" | jq -e 'has("connectors")' >/dev/null 2>&1; then
    EXPECTED_CONFIG_HAS_CONNECTORS="true"
  fi
fi
if [[ -n "$EXPECTED_DIR" && -f "${EXPECTED_DIR}/connectors.json" ]]; then
  EXPECTED_CONNECTORS=$(jq -c '.connectors // []' "${EXPECTED_DIR}/connectors.json" 2>/dev/null || echo "[]")
fi

# Helper: get expected value from expected-config.json
exp() {
  local path="$1" fallback="${2:--}"
  if [[ -n "$EXPECTED_CONFIG" ]]; then
    local val
    val=$(echo "$EXPECTED_CONFIG" | jq -r "$path // empty" 2>/dev/null)
    [[ -n "$val" && "$val" != "null" ]] && echo "$val" && return
  fi
  echo "$fallback"
}
exp_list() {
  local path="$1"
  if [[ -n "$EXPECTED_CONFIG" ]]; then
    echo "$EXPECTED_CONFIG" | jq -r "$path // [] | sort | join(\",\")" 2>/dev/null
  fi
}
count_present_names() {
  local values="$1"
  local expected_csv="$2"
  echo "$values" | jq -r --arg expected_csv "$expected_csv" '
    ($expected_csv | split(",") | map(select(. != ""))) as $expected
    | [.[].name] as $actual
    | [$expected[] | . as $name | select($actual | index($name))] | length
  ' 2>/dev/null || echo 0
}
count_enabled_names() {
  local values="$1"
  local expected_csv="$2"
  echo "$values" | jq -r --arg expected_csv "$expected_csv" '
    ($expected_csv | split(",") | map(select(. != ""))) as $expected
    | [.[] | select(.enabled == true) | .name] as $actual
    | [$expected[] | . as $name | select($actual | index($name))] | length
  ' 2>/dev/null || echo 0
}

API_VERSION="2026-01-01"
ARM_BASE="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/agents/${AGENT}"

# Resolve agent endpoint
AGENT_JSON=$(az rest -m GET --url "${ARM_BASE}?api-version=${API_VERSION}" -o json 2>/dev/null || echo "{}")
ENDPOINT=$(echo "$AGENT_JSON" | jq -r '.properties.agentEndpoint // empty')
if [[ -z "$ENDPOINT" || "$ENDPOINT" == "null" ]]; then
  echo "FAIL: Could not resolve agent endpoint for ${AGENT} in ${RG}"
  exit 1
fi

TOKEN=$(az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "FAIL: Could not get data-plane token"
  exit 1
fi

dp_get() { curl -sS "$ENDPOINT$1" -H "Authorization: Bearer $TOKEN" 2>/dev/null; }
arm_get() { az rest -m GET --url "${ARM_BASE}$1?api-version=${API_VERSION}" -o json 2>/dev/null || echo "{}"; }

PASS=0
FAIL=0
RESULTS=""

check() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$expected" == "-" ]]; then
    RESULTS="${RESULTS}\n  ${name}|${actual}|—|✅"
    PASS=$((PASS + 1))
  elif [[ "$actual" == "$expected" ]]; then
    RESULTS="${RESULTS}\n  ${name}|${actual}|${expected}|✅ PASS"
    PASS=$((PASS + 1))
  else
    RESULTS="${RESULTS}\n  ${name}|${actual}|${expected}|❌ FAIL"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  SRE Agent Verification: ${AGENT}"
echo "  Endpoint: ${ENDPOINT}"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Agent properties ──
PROPS=$(echo "$AGENT_JSON" | jq -c '{
  accessLevel: .properties.actionConfiguration.accessLevel,
  mode: .properties.actionConfiguration.mode,
  upgradeChannel: .properties.upgradeChannel,
  modelProvider: .properties.defaultModel.provider,
  incidentPlatform: (.properties.incidentManagementConfiguration.type // "None"),
  experimentalSettings: (.properties.experimentalSettings | keys | sort | join(","))
}')
check "Agent exists" "yes" "yes"
check "Access level" "$(echo "$PROPS" | jq -r '.accessLevel')" "$(exp '.agent.accessLevel')"
check "Action mode" "$(echo "$PROPS" | jq -r '.mode')" "$(exp '.agent.actionMode')"
check "Upgrade channel" "$(echo "$PROPS" | jq -r '.upgradeChannel')" "$(exp '.agent.upgradeChannel')"
EXP_EXPERIMENTAL_SETTINGS="$(exp_list '.agent.experimentalSettings')"
if [[ -n "$EXP_EXPERIMENTAL_SETTINGS" ]]; then
  EXP_EXPERIMENTAL_CT=$(exp '.agent.experimentalSettings | length' "-")
  ACTUAL_EXPERIMENTAL_SETTINGS="$(echo "$PROPS" | jq -r '.experimentalSettings')"
  ACTUAL_EXPERIMENTAL_VALUES="$(printf '%s\n' "$ACTUAL_EXPERIMENTAL_SETTINGS" | jq -R 'split(",") | map({name: .})')"
  EXPERIMENTAL_PRESENT=$(count_present_names "$ACTUAL_EXPERIMENTAL_VALUES" "$EXP_EXPERIMENTAL_SETTINGS")
  check "Experimental settings expected" "$EXPERIMENTAL_PRESENT" "$EXP_EXPERIMENTAL_CT"
  RESULTS="${RESULTS}\n  Experimental settings|${ACTUAL_EXPERIMENTAL_SETTINGS}|—|"
else
  check "Experimental settings" "$(echo "$PROPS" | jq -r '.experimentalSettings')" "-"
fi
check "Model provider" "$(echo "$PROPS" | jq -r '.modelProvider')" "$(exp '.agent.defaultModelProvider')"
check "Incident platform" "$(echo "$PROPS" | jq -r '.incidentPlatform')" "$(exp '.agent.incidentPlatform')"

# ── Onboarding discovery prerequisites ──
MANAGED_RESOURCE_GROUPS=$(echo "$AGENT_JSON" | jq -r '.properties.knowledgeGraphConfiguration.managedResources // [] | join(",")' 2>/dev/null)
EXPECTED_RG_ID="/subscriptions/${SUB}/resourceGroups/${RG}"
MANAGED_RESOURCE_GROUP_PRESENT=$(echo "$AGENT_JSON" | jq -r --arg expected "$EXPECTED_RG_ID" '
  [.properties.knowledgeGraphConfiguration.managedResources[]? | ascii_downcase] | index($expected | ascii_downcase) != null
' 2>/dev/null || echo false)
[[ "$MANAGED_RESOURCE_GROUP_PRESENT" == "true" ]] && check "Onboarding managed resource group" "present" "present" || check "Onboarding managed resource group" "missing" "present"
RESULTS="${RESULTS}\n  Managed resource groups|${MANAGED_RESOURCE_GROUPS}|—|"

ACTION_IDENTITY=$(echo "$AGENT_JSON" | jq -r '.properties.actionConfiguration.identity // empty' 2>/dev/null)
ACTION_PRINCIPAL_ID=""
if [[ -n "$ACTION_IDENTITY" ]]; then
  ACTION_PRINCIPAL_ID=$(echo "$AGENT_JSON" | jq -r --arg identity "$ACTION_IDENTITY" '
    .identity.userAssignedIdentities as $identities
    | ($identities[$identity].principalId // (
        $identities
        | to_entries[]
        | select(.key | ascii_downcase == ($identity | ascii_downcase))
        | .value.principalId
      ) // empty)
  ' 2>/dev/null)
fi

if [[ -n "$ACTION_PRINCIPAL_ID" ]]; then
  EXPECTED_TARGET_ROLES="Log Analytics Reader,Monitoring Reader,Reader"
  if [[ "$(echo "$PROPS" | jq -r '.accessLevel')" == "High" ]]; then
    EXPECTED_TARGET_ROLES="Contributor,Log Analytics Reader,Monitoring Reader,Reader"
  fi

  MANAGED_SCOPE_CT=$(echo "$AGENT_JSON" | jq '.properties.knowledgeGraphConfiguration.managedResources // [] | length' 2>/dev/null || echo 0)
  MANAGED_SCOPES_WITH_RBAC=0
  while IFS= read -r managed_scope; do
    [[ -n "$managed_scope" ]] || continue
    TARGET_ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$ACTION_PRINCIPAL_ID" --scope "$managed_scope" -o json 2>/dev/null || echo "[]")
    TARGET_ROLE_NAMES=$(echo "$TARGET_ROLE_ASSIGNMENTS" | jq -r '[.[].roleDefinitionName] | sort | join(",")' 2>/dev/null)
    TARGET_ROLES_PRESENT=$(echo "$TARGET_ROLE_ASSIGNMENTS" | jq -r --arg expected_csv "$EXPECTED_TARGET_ROLES" '
      ($expected_csv | split(",") | map(select(. != ""))) as $expected
      | [.[].roleDefinitionName] as $actual
      | all($expected[]; $actual | index(.))
    ' 2>/dev/null || echo false)
    if [[ "$TARGET_ROLES_PRESENT" == "true" ]]; then
      MANAGED_SCOPES_WITH_RBAC=$((MANAGED_SCOPES_WITH_RBAC + 1))
    fi
    RESULTS="${RESULTS}\n  Onboarding identity roles (${managed_scope})|${TARGET_ROLE_NAMES}|—|"
  done < <(echo "$AGENT_JSON" | jq -r '.properties.knowledgeGraphConfiguration.managedResources[]?' 2>/dev/null)
  check "Onboarding identity RBAC" "$MANAGED_SCOPES_WITH_RBAC" "$MANAGED_SCOPE_CT"
else
  check "Onboarding identity RBAC" "missing action identity" "present"
fi

# ── Connectors ──
CONNECTORS=$(dp_get "/api/v2/extendedAgent/connectors")
CONNECTOR_VALUES=$(echo "$CONNECTORS" | jq -c '(.value // []) | if type == "array" then [.[] | select(.properties.dataConnectorType != "KnowledgeFile" and .properties.dataConnectorType != "KnowledgeText" and .properties.dataConnectorType != "KnowledgeWebPage")] else [] end' 2>/dev/null || echo "[]")
CONN_CT=$(echo "$CONNECTOR_VALUES" | jq 'length')
CONN_HEALTHY=$(echo "$CONNECTOR_VALUES" | jq '[.[] | select((.properties.provisioningState // "Succeeded") == "Succeeded" or (.properties.provisioningState // "Succeeded") == "Running")] | length')
CONN_ERRORED=$(echo "$CONNECTOR_VALUES" | jq '[.[] | select((.properties.provisioningState // "Succeeded") != "Succeeded" and (.properties.provisioningState // "Succeeded") != "Running")] | length')
EXP_CONN_CT=$(exp '.connectors | length' "-")
if [[ "$EXPECTED_CONFIG_HAS_CONNECTORS" != "true" && -n "$EXPECTED_CONNECTORS" ]]; then
  EXP_CONN_CT=$(echo "$EXPECTED_CONNECTORS" | jq 'length')
fi
check "Connectors (total)" "$CONN_CT" "$EXP_CONN_CT"
check "Connectors (healthy)" "$CONN_HEALTHY" "$CONN_CT"
# Show errored connectors explicitly
if [[ "$CONN_ERRORED" -gt 0 ]]; then
  ERRORED_LIST=$(echo "$CONNECTOR_VALUES" | jq -r '.[] | select((.properties.provisioningState // "Succeeded") != "Succeeded" and (.properties.provisioningState // "Succeeded") != "Running") | "\(.name) (\(.properties.dataConnectorType)): \(.properties.provisioningState)"')
  RESULTS="${RESULTS}\n  ⚠ Errored connectors|${ERRORED_LIST}||❌ FAIL"
  FAIL=$((FAIL + 1))
fi
CONN_NAMES=$(echo "$CONNECTOR_VALUES" | jq -r '.[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_CONN_NAMES=$(exp_list '.connectors[].name')
if [[ "$EXPECTED_CONFIG_HAS_CONNECTORS" != "true" && -n "$EXPECTED_CONNECTORS" ]]; then
  EXP_CONN_NAMES=$(echo "$EXPECTED_CONNECTORS" | jq -r '[.[].name] | sort | join(",")')
fi
[[ -n "$EXP_CONN_NAMES" ]] && check "Connector names" "$CONN_NAMES" "$EXP_CONN_NAMES" || RESULTS="${RESULTS}\n  Connector names|${CONN_NAMES}|—|"

# ── Skills ──
SKILLS=$(dp_get "/api/v1/extendedAgent/skills")
SKILL_CT=$(echo "$SKILLS" | jq 'if type == "array" then length elif .value then (.value | length) else 0 end' 2>/dev/null || echo 0)
SKILL_NAMES=$(echo "$SKILLS" | jq -r '(if type == "array" then . elif .value then .value else [] end)[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_SKILL_CT=$(exp '.skills | length' "-")
EXP_SKILL_NAMES=$(exp_list '.skills')
check "Skills" "$SKILL_CT" "$EXP_SKILL_CT"
[[ -n "$EXP_SKILL_NAMES" ]] && check "Skill names" "$SKILL_NAMES" "$EXP_SKILL_NAMES" || RESULTS="${RESULTS}\n  Skill names|${SKILL_NAMES}|—|"

# ── Subagents ──
SUBAGENTS=$(dp_get "/api/v2/extendedAgent/agents")
SA_CT=$(echo "$SUBAGENTS" | jq '.value | length' 2>/dev/null || echo 0)
SA_NAMES=$(echo "$SUBAGENTS" | jq -r '.value[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_SA_CT=$(exp '.subagents | length' "-")
EXP_SA_NAMES=$(exp_list '.subagents')
check "Subagents" "$SA_CT" "$EXP_SA_CT"
[[ -n "$EXP_SA_NAMES" ]] && check "Subagent names" "$SA_NAMES" "$EXP_SA_NAMES" || RESULTS="${RESULTS}\n  Subagent names|${SA_NAMES}|—|"

EXP_ALL_SUBAGENT_TOOLS=$(exp_list '.subagentRequirements.allTools')
if [[ -n "$EXP_ALL_SUBAGENT_TOOLS" ]]; then
  SUBAGENTS_WITH_TOOLS=$(echo "$SUBAGENTS" | jq -r --arg expected_csv "$EXP_ALL_SUBAGENT_TOOLS" '
    ($expected_csv | split(",") | map(select(. != ""))) as $expected
    | [.value[]? | select((.properties.tools // []) as $tools | all($expected[]; $tools | index(.)))] | length
  ' 2>/dev/null || echo 0)
  check "Subagents with required tools" "$SUBAGENTS_WITH_TOOLS" "$SA_CT"
fi

if [[ -n "$EXPECTED_CONFIG" ]]; then
  EXP_HANDOFF_AGENT_NAMES=$(echo "$EXPECTED_CONFIG" | jq -r '.subagentRequirements.handoffs // {} | keys | sort | join(",")' 2>/dev/null)
  if [[ -n "$EXP_HANDOFF_AGENT_NAMES" ]]; then
    IFS=',' read -r -a HANDOFF_AGENTS <<< "$EXP_HANDOFF_AGENT_NAMES"
    for handoff_agent in "${HANDOFF_AGENTS[@]}"; do
      [[ -n "$handoff_agent" ]] || continue
      EXP_HANDOFFS=$(echo "$EXPECTED_CONFIG" | jq -r --arg agent "$handoff_agent" '.subagentRequirements.handoffs[$agent] // [] | sort | join(",")' 2>/dev/null)
      ACTUAL_HANDOFFS=$(echo "$SUBAGENTS" | jq -r --arg agent "$handoff_agent" '[.value[]? | select(.name == $agent)][0].properties.handoffs // [] | sort | join(",")' 2>/dev/null)
      check "Handoffs: ${handoff_agent}" "$ACTUAL_HANDOFFS" "$EXP_HANDOFFS"
    done
  fi
fi

# ── Built-in tool configuration ──
EXP_BUILT_IN_TOOL_NAMES=$(exp_list '.builtInTools.enabled')
if [[ -n "$EXP_BUILT_IN_TOOL_NAMES" ]]; then
  AGENT_TOOLS=$(dp_get "/api/v2/agent/tools")
  AGENT_TOOL_VALUES=$(echo "$AGENT_TOOLS" | jq -c '.data // []' 2>/dev/null || echo "[]")
  EXP_BUILT_IN_TOOL_CT=$(exp '.builtInTools.enabled | length' "-")
  BUILT_IN_ENABLED_PRESENT=$(count_enabled_names "$AGENT_TOOL_VALUES" "$EXP_BUILT_IN_TOOL_NAMES")
  check "Built-in tools enabled" "$BUILT_IN_ENABLED_PRESENT" "$EXP_BUILT_IN_TOOL_CT"

  EXPECTED_LOG_QUERY_CT=$(exp '.builtInTools.categories["Log Query"]' "-")
  if [[ "$EXPECTED_LOG_QUERY_CT" != "-" ]]; then
    ACTUAL_LOG_QUERY_CT=$(echo "$AGENT_TOOL_VALUES" | jq '[.[] | select(.category == "Log Query" and .enabled == true)] | length' 2>/dev/null || echo 0)
    check "Log Query tools enabled" "$ACTUAL_LOG_QUERY_CT" "$EXPECTED_LOG_QUERY_CT"
  fi

  EXPECTED_VISUALIZATION_CT=$(exp '.builtInTools.categories.Visualization' "-")
  if [[ "$EXPECTED_VISUALIZATION_CT" != "-" ]]; then
    ACTUAL_VISUALIZATION_CT=$(echo "$AGENT_TOOL_VALUES" | jq '[.[] | select(.category == "Visualization" and .enabled == true)] | length' 2>/dev/null || echo 0)
    check "Visualization tools enabled" "$ACTUAL_VISUALIZATION_CT" "$EXPECTED_VISUALIZATION_CT"
  fi
fi

# ── Hooks ──
HOOKS=$(dp_get "/api/v2/extendedAgent/hooks")
HOOK_CT=$(echo "$HOOKS" | jq '.value // . | if type == "array" then length else 0 end' 2>/dev/null || echo 0)
HOOK_NAMES=$(echo "$HOOKS" | jq -r '(.value // .)[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_HOOK_CT=$(exp '.hooks | length' "-")
EXP_HOOK_NAMES=$(exp_list '.hooks')
check "Hooks" "$HOOK_CT" "$EXP_HOOK_CT"
[[ -n "$EXP_HOOK_NAMES" ]] && check "Hook names" "$HOOK_NAMES" "$EXP_HOOK_NAMES" || RESULTS="${RESULTS}\n  Hook names|${HOOK_NAMES}|—|"

# ── Common Prompts ──
PROMPTS=$(dp_get "/api/v2/extendedAgent/commonprompts")
PROMPT_CT=$(echo "$PROMPTS" | jq '.value // . | if type == "array" then length else 0 end' 2>/dev/null || echo 0)
PROMPT_NAMES=$(echo "$PROMPTS" | jq -r '(.value // .)[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_PROMPT_CT=$(exp '.commonPrompts | length' "-")
EXP_PROMPT_NAMES=$(exp_list '.commonPrompts')
check "Common Prompts" "$PROMPT_CT" "$EXP_PROMPT_CT"
[[ -n "$EXP_PROMPT_NAMES" ]] && check "Prompt names" "$PROMPT_NAMES" "$EXP_PROMPT_NAMES" || RESULTS="${RESULTS}\n  Prompt names|${PROMPT_NAMES}|—|"

# ── Scheduled Tasks ──
TASKS=$(dp_get "/api/v1/scheduledtasks")
TASK_CT=$(echo "$TASKS" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
TASK_UNIQUE=$(echo "$TASKS" | jq '[.[].name] | unique | length' 2>/dev/null || echo 0)
TASK_NAMES=$(echo "$TASKS" | jq -r '[.[].name] | unique | sort | join(",")' 2>/dev/null)
EXP_TASK_CT=$(exp '.scheduledTasks | length' "-")
EXP_TASK_NAMES=$(exp_list '.scheduledTasks')
check "Scheduled Tasks (unique)" "$TASK_UNIQUE" "$EXP_TASK_CT"
[[ -n "$EXP_TASK_NAMES" ]] && check "Task names" "$TASK_NAMES" "$EXP_TASK_NAMES" || true
if [[ "$TASK_CT" != "$TASK_UNIQUE" ]]; then
  RESULTS="${RESULTS}\n  Scheduled task duplicates|${TASK_CT} total, ${TASK_UNIQUE} unique|0 duplicates|❌ FAIL"
  FAIL=$((FAIL + 1))
fi

# ── Knowledge sources ──
DATA_CONNECTORS=$(dp_get "/api/v2/extendedAgent/connectors")
KNOWLEDGE_SOURCE_VALUES=$(echo "$DATA_CONNECTORS" | jq -c '[.value[]? | select(.properties.dataConnectorType == "KnowledgeFile" or .properties.dataConnectorType == "KnowledgeText" or .properties.dataConnectorType == "KnowledgeWebPage")]' 2>/dev/null || echo "[]")
KS_CT=$(echo "$KNOWLEDGE_SOURCE_VALUES" | jq 'length')
KS_NAMES=$(echo "$KNOWLEDGE_SOURCE_VALUES" | jq -r '[.[].name] | sort | join(",")' 2>/dev/null)
KS_INDEXED=$(echo "$KNOWLEDGE_SOURCE_VALUES" | jq '[.[] | select(.properties.extendedProperties.createdAt != null)] | length' 2>/dev/null || echo 0)
EXP_KS_CT=$(exp '.knowledgeSources | length' "-")
EXP_KS_NAMES=$(exp_list '.knowledgeSources')
check "Knowledge sources" "$KS_CT" "$EXP_KS_CT"
if [[ -n "$EXP_KS_NAMES" ]]; then
  KS_EXPECTED_PRESENT=$(count_present_names "$KNOWLEDGE_SOURCE_VALUES" "$EXP_KS_NAMES")
  check "Knowledge sources expected" "$KS_EXPECTED_PRESENT" "$EXP_KS_CT"
fi
check "Knowledge sources indexed" "$KS_INDEXED" "$KS_CT"
UNINDEXED_KNOWLEDGE_SOURCES=$(echo "$KNOWLEDGE_SOURCE_VALUES" | jq -r '.[] | select(.properties.extendedProperties.createdAt == null) | "\(.name): \(.properties.extendedProperties.errorReason // "not indexed")"' 2>/dev/null)
if [[ -n "$UNINDEXED_KNOWLEDGE_SOURCES" ]]; then
  RESULTS="${RESULTS}\n  ⚠️  Unindexed knowledge sources|${UNINDEXED_KNOWLEDGE_SOURCES}|—|❌ FAIL"
  FAIL=$((FAIL + 1))
fi

# ── Response Plans (Incident Filters) ──
FILTERS=$(dp_get "/api/v1/incidentPlayground/filters")
FILTER_CT=$(echo "$FILTERS" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
FILTER_NAMES=$(echo "$FILTERS" | jq -r '.[].id' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_FILTER_CT=$(exp '.responsePlans | length' "-")
EXP_FILTER_NAMES=$(exp_list '.responsePlans[].name')
check "Response Plans" "$FILTER_CT" "$EXP_FILTER_CT"
[[ -n "$EXP_FILTER_NAMES" ]] && check "Filter names" "$FILTER_NAMES" "$EXP_FILTER_NAMES" || RESULTS="${RESULTS}\n  Filter names|${FILTER_NAMES}|—|"
  EXP_FILTERS=$(find -L "$EXPECTED_DIR/automations/incident-filters" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
[[ -n "$EXP_FILTER_NAMES" ]] && check "Filter names" "$FILTER_NAMES" "$EXP_FILTER_NAMES" || RESULTS="${RESULTS}\n  Filter names|${FILTER_NAMES}|—|"

# ── GitHub ──
GH_STATUS=$(dp_get "/api/v1/Github/auth/status")
GH_CONFIGURED=$(echo "$GH_STATUS" | jq -r '.isConfigured // .hosts[0].isConfigured // false' 2>/dev/null)
check "GitHub OAuth" "$GH_CONFIGURED" "-"

# ── Repos ──
REPOS=$(dp_get "/api/v2/repos")
REPO_CT=$(echo "$REPOS" | jq '.value // . | if type == "array" then length else 0 end' 2>/dev/null || echo 0)
REPO_NAMES=$(echo "$REPOS" | jq -r '(.value // .)[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_REPO_CT=$(exp '.repos | length' "-")
EXP_REPO_NAMES=$(exp_list '.repos')
check "Repos" "$REPO_CT" "$EXP_REPO_CT"
[[ -n "$EXP_REPO_NAMES" ]] && check "Repo names" "$REPO_NAMES" "$EXP_REPO_NAMES" || RESULTS="${RESULTS}\n  Repo names|${REPO_NAMES}|—|"

# ── Print results ──
echo ""
printf "  %-25s %-10s %-10s %s\n" "Check" "Actual" "Expected" "Result"
printf "  %-25s %-10s %-10s %s\n" "─────────────────────────" "──────────" "──────────" "──────"
echo -e "$RESULTS" | while IFS='|' read -r name actual expected result; do
  [[ -z "$name" ]] && continue
  printf "  %-25s %-10s %-10s %s\n" "$name" "$actual" "$expected" "$result"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "  Portal:  https://sre.azure.com/#/agent/${SUB}/${RG}/${AGENT}"
echo "═══════════════════════════════════════════════════"
echo ""

[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
