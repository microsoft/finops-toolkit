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

API_VERSION="2025-05-01-preview"
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
check "Model provider" "$(echo "$PROPS" | jq -r '.modelProvider')" "$(exp '.agent.defaultModelProvider')"
check "Incident platform" "$(echo "$PROPS" | jq -r '.incidentPlatform')" "$(exp '.agent.incidentPlatform')"

# ── Connectors (ARM) ──
CONNECTORS=$(arm_get "/DataConnectors")
CONN_CT=$(echo "$CONNECTORS" | jq '.value | length')
CONN_HEALTHY=$(echo "$CONNECTORS" | jq '[.value[] | select(.properties.provisioningState == "Succeeded")] | length')
CONN_ERRORED=$(echo "$CONNECTORS" | jq '[.value[] | select(.properties.provisioningState != "Succeeded" and .properties.provisioningState != "Running")] | length')
EXP_CONN_CT=$(exp '.connectors | length' "-")
check "Connectors (total)" "$CONN_CT" "$EXP_CONN_CT"
check "Connectors (healthy)" "$CONN_HEALTHY" "$CONN_CT"
# Show errored connectors explicitly
if [[ "$CONN_ERRORED" -gt 0 ]]; then
  ERRORED_LIST=$(echo "$CONNECTORS" | jq -r '.value[] | select(.properties.provisioningState != "Succeeded" and .properties.provisioningState != "Running") | "\(.name) (\(.properties.dataConnectorType)): \(.properties.provisioningState)"')
  RESULTS="${RESULTS}\n  ⚠ Errored connectors|${ERRORED_LIST}||❌ FAIL"
  FAIL=$((FAIL + 1))
fi
CONN_NAMES=$(echo "$CONNECTORS" | jq -r '.value[].name' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_CONN_NAMES=$(exp_list '.connectors[].name')
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
[[ "$TASK_CT" != "$TASK_UNIQUE" ]] && RESULTS="${RESULTS}\n  ⚠️  Duplicates|${TASK_CT} total, ${TASK_UNIQUE} unique|—|"

# ── Response Plans (Incident Filters) ──
FILTERS=$(dp_get "/api/v1/incidentPlayground/filters")
FILTER_CT=$(echo "$FILTERS" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo 0)
FILTER_NAMES=$(echo "$FILTERS" | jq -r '.[].id' 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
EXP_FILTER_CT=$(exp '.responsePlans | length' "-")
EXP_FILTER_NAMES=$(exp_list '.responsePlans[].name')
check "Response Plans" "$FILTER_CT" "$EXP_FILTER_CT"
[[ -n "$EXP_FILTER_NAMES" ]] && check "Filter names" "$FILTER_NAMES" "$EXP_FILTER_NAMES" || RESULTS="${RESULTS}\n  Filter names|${FILTER_NAMES}|—|"
  EXP_FILTERS=$(find "$EXPECTED_DIR/automations/incident-filters" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
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
