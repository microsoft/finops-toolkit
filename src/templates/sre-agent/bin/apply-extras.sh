#!/usr/bin/env bash
# =============================================================================
# apply-extras.sh - Apply non-Bicep SRE Agent recipe assets
#
# Follows the microsoft/sre-agent template pattern: Bicep deploys the ARM
# resource, then this script applies connectors, KnowledgeFile sources, skills,
# subagents, tools, and scheduled tasks through the supported ARM/data-plane
# surfaces. srectl is not used.
# =============================================================================

set -euo pipefail

usage() {
  cat <<EOF
Usage: bash bin/apply-extras.sh --endpoint <url> --subscription <id> --resource-group <name> --name <agent> --recipe <dir> --build-dir <dir> [options]

Required:
  --endpoint <url>              SRE Agent endpoint
  --subscription <id>           Azure subscription that contains the SRE Agent
  --resource-group <name>       Resource group that contains the SRE Agent
  --name <agent>                SRE Agent name
  --recipe <dir>                Recipe directory
  --build-dir <dir>             Working directory for generated extras and request files

Optional:
  --kusto-connector-uri <uri>   Database-qualified Kusto connector URI
  --dry-run                     Build extras and request payloads without Azure calls
  -h, --help                    Show this help
EOF
  exit "${1:-0}"
}

fail() {
  echo "$1" >&2
  exit "${2:-1}"
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == -* ]]; then
    fail "Error: flag ${flag} requires a value" 2
  fi
}

safe_name() {
  printf '%s' "$1" | tr '/:' '__' | tr -cd 'A-Za-z0-9._-'
}

urlencode() {
  printf '%s' "$1" | jq -sRr @uri
}

knowledge_source_name() {
  basename "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-//; s/-$//'
}

get_sre_token() {
  az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null
}

ENDPOINT=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
AGENT_NAME=""
RECIPE_DIR=""
BUILD_DIR=""
KUSTO_CONNECTOR_URI=""
DRY_RUN=""
ARM_API_VERSION="2025-05-01-preview"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      require_value "--endpoint" "${2:-}"
      ENDPOINT="$2"
      shift 2
      ;;
    --subscription)
      require_value "--subscription" "${2:-}"
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --resource-group)
      require_value "--resource-group" "${2:-}"
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --name)
      require_value "--name" "${2:-}"
      AGENT_NAME="$2"
      shift 2
      ;;
    --recipe)
      require_value "--recipe" "${2:-}"
      RECIPE_DIR="$2"
      shift 2
      ;;
    --build-dir)
      require_value "--build-dir" "${2:-}"
      BUILD_DIR="$2"
      shift 2
      ;;
    --kusto-connector-uri)
      require_value "--kusto-connector-uri" "${2:-}"
      KUSTO_CONNECTOR_URI="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      fail "Error: unknown argument '$1'" 2
      ;;
  esac
done

[[ -n "$ENDPOINT" ]] || fail "Error: --endpoint <url> is required" 2
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Error: --subscription <id> is required" 2
[[ -n "$RESOURCE_GROUP" ]] || fail "Error: --resource-group <name> is required" 2
[[ -n "$AGENT_NAME" ]] || fail "Error: --name <agent> is required" 2
[[ -n "$RECIPE_DIR" ]] || fail "Error: --recipe <dir> is required" 2
[[ -n "$BUILD_DIR" ]] || fail "Error: --build-dir <dir> is required" 2
[[ -d "$RECIPE_DIR" ]] || fail "Error: recipe directory not found: $RECIPE_DIR" 1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECIPE_DIR="$(cd "$RECIPE_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
EXTRAS_FILE="${BUILD_DIR}/extras.json"
REQUEST_DIR="${BUILD_DIR}/requests"
RESPONSE_DIR="${BUILD_DIR}/responses"
ARM_BASE="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/agents/${AGENT_NAME}"

command -v jq >/dev/null || fail "jq is required" 1
command -v base64 >/dev/null || fail "base64 is required" 1

PYTHON_CMD=""
if command -v python3 >/dev/null; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null && python --version 2>&1 | grep -q "Python 3"; then
  PYTHON_CMD="python"
else
  fail "Python 3 is required" 1
fi

"$PYTHON_CMD" -c "import yaml" 2>/dev/null || fail "PyYAML is required to build extras. Install with: pip install pyyaml" 1

mkdir -p "$REQUEST_DIR" "$RESPONSE_DIR"

echo ""
echo "============================================="
echo "  SRE Agent - Apply Extras"
echo "============================================="
echo ""
echo "Agent endpoint: $ENDPOINT"
echo "Recipe:         $RECIPE_DIR"
echo "Build dir:      $BUILD_DIR"
echo ""

echo "Step 1/8: Building extras manifest..."
SUMMARY_JSON="$("$PYTHON_CMD" "${SCRIPT_DIR}/build-extras.py" \
  --recipe "$RECIPE_DIR" \
  --output "$EXTRAS_FILE" \
  --kusto-connector-uri "$KUSTO_CONNECTOR_URI")"
echo "  extras: $EXTRAS_FILE"
echo "  summary: $SUMMARY_JSON"
echo ""

if [[ -z "$DRY_RUN" ]]; then
  command -v az >/dev/null || fail "az is required to apply extras" 1
  command -v curl >/dev/null || fail "curl is required to apply extras" 1
  az account set --subscription "$SUBSCRIPTION_ID" >/dev/null
  DP_TOKEN="$(get_sre_token)"
  [[ -n "$DP_TOKEN" ]] || fail "Error: failed to get Azure SRE Agent bearer token. Run: az login --scope https://azuresre.dev/.default" 1
else
  DP_TOKEN="dry-run"
  echo "Dry run enabled. Azure control-plane and data-plane calls will be skipped."
  echo ""
fi

arm_put_connector() {
  local name="$1"
  local body_json="$2"
  local safe
  local body_file
  local response_file
  local result

  safe="$(safe_name "$name")"
  body_file="${REQUEST_DIR}/arm-connectors/${safe}.json"
  response_file="${RESPONSE_DIR}/arm-connectors/${safe}.json"
  mkdir -p "$(dirname "$body_file")" "$(dirname "$response_file")"
  printf '%s\n' "$body_json" > "$body_file"

  if [[ -n "$DRY_RUN" ]]; then
    echo "  dry-run ARM PUT connectors/${name} -> $body_file"
    return 0
  fi

  for attempt in 1 2 3 4 5; do
    if result="$(az rest -m PUT \
      --url "${ARM_BASE}/connectors/${name}?api-version=${ARM_API_VERSION}" \
      --body "@${body_file}" \
      --headers "Content-Type=application/json" \
      -o json 2>&1)"; then
      printf '%s\n' "$result" > "$response_file"
      echo "  ARM PUT connectors/${name}: ok"
      return 0
    fi

    printf '%s\n' "$result" > "$response_file"
    echo "  ARM PUT connectors/${name}: attempt ${attempt}/5 failed"
    [[ "$attempt" != "5" ]] && sleep 15
  done

  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to apply connector ${name}" 1
}

dataplane_put_extended() {
  local kind="$1"
  local name="$2"
  local type="$3"
  local tags_json="$4"
  local props_json="$5"
  local safe
  local body_file
  local response_file
  local body
  local http_code
  local encoded_name

  safe="$(safe_name "$name")"
  body_file="${REQUEST_DIR}/dataplane-${kind}/${safe}.json"
  response_file="${RESPONSE_DIR}/dataplane-${kind}/${safe}.json"
  mkdir -p "$(dirname "$body_file")" "$(dirname "$response_file")"
  body="$(jq -nc --arg name "$name" --arg type "$type" --argjson tags "$tags_json" --argjson properties "$props_json" \
    '{name: $name, type: $type, tags: $tags, properties: $properties}')"
  printf '%s\n' "$body" > "$body_file"

  if [[ -n "$DRY_RUN" ]]; then
    echo "  dry-run PUT ${kind}/${name} -> $body_file"
    return 0
  fi

  encoded_name="$(urlencode "$name")"
  for attempt in 1 2 3 4 5; do
    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X PUT "${ENDPOINT}/api/v2/extendedAgent/${kind}/${encoded_name}" \
      -H "Authorization: Bearer ${DP_TOKEN}" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}")"; then
      :
    else
      http_code="000"
    fi

    case "$http_code" in
      200|201|202|204)
        echo "  PUT ${kind}/${name}: ok"
        return 0
        ;;
    esac

    echo "  PUT ${kind}/${name}: attempt ${attempt}/5 returned HTTP ${http_code}"
    [[ "$attempt" != "5" ]] && sleep 15
  done

  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to apply ${kind}/${name}" 1
}

apply_built_in_tools_config() {
  local config_json
  local override_count
  local body_file="${REQUEST_DIR}/built-in-tools/configure.json"
  local response_file="${RESPONSE_DIR}/built-in-tools/configure.json"
  local http_code

  config_json="$(jq -c '.builtInTools // {"overrides":[]}' "$EXTRAS_FILE")"
  override_count="$(jq -r '.overrides | length' <<< "$config_json")"
  [[ "$override_count" != "0" ]] || {
    echo "  built-in tools: no overrides"
    return 0
  }

  mkdir -p "$(dirname "$body_file")" "$(dirname "$response_file")"
  jq '{overrides: [.overrides[] | {name, enabled}]}' <<< "$config_json" > "$body_file"

  if [[ -n "$DRY_RUN" ]]; then
    echo "  dry-run POST agent/tools/configure -> $body_file"
    return 0
  fi

  for attempt in 1 2 3 4 5; do
    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X POST "${ENDPOINT}/api/v2/agent/tools/configure" \
      -H "Authorization: Bearer ${DP_TOKEN}" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}")"; then
      :
    else
      http_code="000"
    fi

    case "$http_code" in
      200|201|202|204)
        echo "  built-in tools configured: ${override_count} overrides"
        return 0
        ;;
    esac

    echo "  built-in tools: attempt ${attempt}/5 returned HTTP ${http_code}"
    [[ "$attempt" != "5" ]] && sleep 15
  done

  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to configure built-in tools" 1
}

delete_existing_scheduled_tasks() {
  local count
  local response_file="${RESPONSE_DIR}/scheduledtasks.existing.json"
  local name
  local ids
  local id
  local http_code
  local deleted=0

  count="$(jq '.scheduledTasks // [] | length' "$EXTRAS_FILE")"
  [[ "$count" -gt 0 ]] || return 0

  if [[ -n "$DRY_RUN" ]]; then
    echo "  dry-run scheduled-task cleanup: ${count} task name(s)"
    return 0
  fi

  if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
    "${ENDPOINT}/api/v1/scheduledtasks" \
    -H "Authorization: Bearer ${DP_TOKEN}")"; then
    :
  else
    http_code="000"
  fi
  [[ "$http_code" == "200" ]] || fail "Failed to list existing scheduled tasks before apply (HTTP ${http_code})" 1

  for i in $(seq 0 $((count - 1))); do
    name="$(jq -r --argjson index "$i" '.scheduledTasks[$index].metadata.name' "$EXTRAS_FILE")"
    ids="$(jq -r --arg name "$name" '.[]? | select(.name == $name) | .id // empty' "$response_file" 2>/dev/null || true)"
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      if curl -sS -o /dev/null -X DELETE "${ENDPOINT}/api/v1/scheduledtasks/${id}" -H "Authorization: Bearer ${DP_TOKEN}"; then
        echo "  deleted existing scheduled-task ${name} (${id})"
        deleted=$((deleted + 1))
      else
        fail "Failed to delete existing scheduled-task ${name} (${id})" 1
      fi
    done <<< "$ids"
  done

  [[ "$deleted" -eq 0 ]] || echo "  scheduled-task cleanup: ${deleted} existing deleted"
}

verify_knowledge_docs() {
  local expected_docs=("$@")
  local response_file="${RESPONSE_DIR}/knowledge-sources/list.json"
  local detail_file
  local doc
  local source_name
  local entry
  local indexed
  local reason
  local missing
  local unindexed
  local http_code

  [[ "${#expected_docs[@]}" -gt 0 ]] || return 0
  [[ -z "$DRY_RUN" ]] || {
    echo "  dry-run knowledge verification skipped"
    return 0
  }

  mkdir -p "$(dirname "$response_file")"
  echo "  waiting for knowledge sources to index..."
  for attempt in $(seq 1 20); do
    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      "${ENDPOINT}/api/v2/extendedAgent/connectors" \
      -H "Authorization: Bearer ${DP_TOKEN}")"; then
      :
    else
      http_code="000"
    fi

    missing=0
    unindexed=0
    if [[ "$http_code" == "200" ]]; then
      for doc in "${expected_docs[@]}"; do
        source_name="$(knowledge_source_name "$doc")"
        entry="$(jq -c --arg name "$source_name" '[.value[]? | select(.name == $name and .properties.dataConnectorType == "KnowledgeFile")][0] // empty' "$response_file" 2>/dev/null || true)"
        if [[ -z "$entry" ]]; then
          missing=$((missing + 1))
          continue
        fi

        detail_file="${RESPONSE_DIR}/knowledge-sources/${source_name}.json"
        if http_code="$(curl -sS -o "$detail_file" -w "%{http_code}" \
          "${ENDPOINT}/api/v2/extendedAgent/connectors/${source_name}" \
          -H "Authorization: Bearer ${DP_TOKEN}")"; then
          :
        else
          http_code="000"
        fi

        indexed="$(jq -r '.properties.extendedProperties.createdAt // empty' "$detail_file" 2>/dev/null || true)"
        [[ -n "$indexed" ]] || unindexed=$((unindexed + 1))
      done

      if [[ "$missing" -eq 0 && "$unindexed" -eq 0 ]]; then
        echo "  knowledge sources indexed: ${#expected_docs[@]} docs"
        return 0
      fi

      echo "  knowledge indexing attempt ${attempt}/20: ${missing} missing, ${unindexed} not indexed"
    else
      echo "  knowledge indexing attempt ${attempt}/20: connectors returned HTTP ${http_code}"
    fi

    [[ "$attempt" -lt 20 ]] && sleep 15
  done

  echo "  knowledge source status:" >&2
  for doc in "${expected_docs[@]}"; do
    source_name="$(knowledge_source_name "$doc")"
    detail_file="${RESPONSE_DIR}/knowledge-sources/${source_name}.json"
    entry="$(jq -c --arg name "$source_name" '[.value[]? | select(.name == $name and .properties.dataConnectorType == "KnowledgeFile")][0] // empty' "$response_file" 2>/dev/null || true)"
    if [[ -z "$entry" ]]; then
      echo "    ${doc}: missing" >&2
    else
      indexed="$(jq -r '.properties.extendedProperties.createdAt // empty' "$detail_file" 2>/dev/null || true)"
      reason="$(jq -r '.properties.extendedProperties.errorReason // ""' "$detail_file" 2>/dev/null || true)"
      echo "    ${doc}: indexed=${indexed}${reason:+ reason=${reason}}" >&2
    fi
  done
  fail "Knowledge sources failed to index" 1
}

echo "Step 2/8: Applying connectors..."
CONNECTOR_COUNT="$(jq '.connectors // [] | length' "$EXTRAS_FILE")"
if [[ "$CONNECTOR_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((CONNECTOR_COUNT - 1))); do
    name="$(jq -r --argjson index "$i" '.connectors[$index].name' "$EXTRAS_FILE")"
    connector_type="$(jq -r --argjson index "$i" '.connectors[$index].properties.dataConnectorType // .connectors[$index].properties.type // ""' "$EXTRAS_FILE")"
    connector_type_lower="$(printf '%s' "$connector_type" | tr '[:upper:]' '[:lower:]')"
    if [[ "$connector_type_lower" == "mcp" ]]; then
      jq -e --argjson index "$i" '.connectors[$index].properties.extendedProperties.type == "http" and (.connectors[$index].properties.extendedProperties.endpoint // "") != ""' "$EXTRAS_FILE" >/dev/null \
        || fail "Error: MCP connector ${name} must use properties.extendedProperties.type and endpoint" 1
      jq -e --argjson index "$i" '(.connectors[$index].properties.extendedProperties.headers? | type) != "object"' "$EXTRAS_FILE" >/dev/null \
        || fail "Error: MCP connector ${name} must flatten custom headers into properties.extendedProperties" 1
    fi
    body="$(jq -c --argjson index "$i" '{properties: (.connectors[$index].properties | if (.identity // "") == "" then . + {identity: "system"} else . end)}' "$EXTRAS_FILE")"
    arm_put_connector "$name" "$body"
  done
else
  echo "  connectors: none"
fi
echo ""

echo "Step 3/8: Configuring built-in tools..."
apply_built_in_tools_config
echo ""

echo "Step 4/8: Uploading knowledge sources..."
KNOWLEDGE_COUNT="$(jq '.knowledgeItems // [] | length' "$EXTRAS_FILE")"
KNOWLEDGE_DOC_NAMES=()
if [[ "$KNOWLEDGE_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((KNOWLEDGE_COUNT - 1))); do
    fname="$(jq -r --argjson index "$i" '.knowledgeItems[$index].name' "$EXTRAS_FILE")"
    content_type="$(jq -r --argjson index "$i" '.knowledgeItems[$index].contentType // "application/octet-stream"' "$EXTRAS_FILE")"
    source_name="$(knowledge_source_name "$fname")"
    content_b64="$(jq -rj --argjson index "$i" '.knowledgeItems[$index].content' "$EXTRAS_FILE" | base64 | tr -d '\n')"
    KNOWLEDGE_DOC_NAMES+=("$fname")
    body="$(jq -nc \
      --arg dataSource "$source_name" \
      --arg displayName "$fname" \
      --arg fileName "$fname" \
      --arg fileContent "$content_b64" \
      --arg contentType "$content_type" \
      '{properties:{dataConnectorType:"KnowledgeFile",dataSource:$dataSource,extendedProperties:{displayName:$displayName,fileName:$fileName,fileContent:$fileContent,contentType:$contentType}}}')"
    arm_put_connector "$source_name" "$body"
    [[ -z "$DRY_RUN" && "$i" -lt $((KNOWLEDGE_COUNT - 1)) ]] && sleep 15
  done
  verify_knowledge_docs "${KNOWLEDGE_DOC_NAMES[@]}"
else
  echo "  knowledge sources: none"
fi
echo ""

echo "Step 5/8: Applying tools..."
TOOL_COUNT="$(jq '.tools // [] | length' "$EXTRAS_FILE")"
if [[ "$TOOL_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((TOOL_COUNT - 1))); do
    name="$(jq -r --argjson index "$i" '.tools[$index].metadata.name' "$EXTRAS_FILE")"
    props="$(jq -c --argjson index "$i" '.tools[$index].spec' "$EXTRAS_FILE")"
    dataplane_put_extended "tools" "$name" "Tool" "[]" "$props"
  done
else
  echo "  tools: none"
fi
echo ""

echo "Step 6/8: Applying skills..."
SKILL_COUNT="$(jq '.skills // [] | length' "$EXTRAS_FILE")"
if [[ "$SKILL_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((SKILL_COUNT - 1))); do
    name="$(jq -r --argjson index "$i" '.skills[$index].metadata.name' "$EXTRAS_FILE")"
    props="$(jq -c --argjson index "$i" '
      {
        name: .skills[$index].metadata.name,
        description: (.skills[$index].metadata.description // ""),
        tools: (.skills[$index].metadata.spec.tools // []),
        skillContent: (.skills[$index].skillContent // ""),
        additionalFiles: (.skills[$index].additionalFiles // [])
      }' "$EXTRAS_FILE")"
    dataplane_put_extended "skills" "$name" "Skill" "[]" "$props"
  done
else
  echo "  skills: none"
fi
echo ""

echo "Step 7/8: Applying subagents..."
SUBAGENT_COUNT="$(jq '.subagents // [] | length' "$EXTRAS_FILE")"
if [[ "$SUBAGENT_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((SUBAGENT_COUNT - 1))); do
    name="$(jq -r --argjson index "$i" '.subagents[$index].metadata.name' "$EXTRAS_FILE")"
    props="$(jq -c --argjson index "$i" '.subagents[$index].spec' "$EXTRAS_FILE")"
    dataplane_put_extended "agents" "$name" "ExtendedAgent" "[]" "$props"
  done
else
  echo "  subagents: none"
fi
echo ""

echo "Step 8/8: Applying scheduled tasks..."
TASK_COUNT="$(jq '.scheduledTasks // [] | length' "$EXTRAS_FILE")"
if [[ "$TASK_COUNT" -gt 0 ]]; then
  delete_existing_scheduled_tasks
  for i in $(seq 0 $((TASK_COUNT - 1))); do
    name="$(jq -r --argjson index "$i" '.scheduledTasks[$index].metadata.name' "$EXTRAS_FILE")"
    props="$(jq -c --argjson index "$i" '
      .scheduledTasks[$index].spec as $spec |
      {
        name: ($spec.name // .scheduledTasks[$index].metadata.name // ""),
        description: ($spec.description // ""),
        cronExpression: ($spec.schedule // $spec.cronExpression // $spec.cron_expression // ""),
        agentPrompt: ($spec.prompt // $spec.agentPrompt // $spec.agent_prompt // ""),
        agentMode: ($spec.mode // $spec.agentMode // $spec.agent_mode // "Review"),
        isEnabled: ($spec.enabled // true),
        agent: ($spec.agent // "")
      }' "$EXTRAS_FILE")"
    dataplane_put_extended "scheduledtasks" "$name" "ScheduledTask" "[]" "$props"
  done
else
  echo "  scheduled tasks: none"
fi
echo ""

echo "============================================="
echo "  SRE Agent extras complete"
echo "============================================="
echo ""
