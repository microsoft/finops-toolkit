#!/usr/bin/env bash
# =============================================================================
# post-provision.sh - FinOps Toolkit SRE Agent srectl setup
#
# Copied from microsoft/sre-agent labs/starter-lab/scripts/post-provision.sh and
# updated for the FinOps Toolkit recipe layout.
# =============================================================================

set -euo pipefail

usage() {
  cat <<EOF
Usage: bash bin/post-provision.sh --endpoint <url> --recipe <dir> --build-dir <dir> [options]

Required:
  --endpoint <url>              SRE Agent endpoint
  --recipe <dir>                Recipe directory
  --build-dir <dir>             Working directory for generated connector/workspace files

Optional:
  --kusto-connector-uri <uri>   Database-qualified Kusto connector URI
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

ENDPOINT=""
RECIPE_DIR=""
BUILD_DIR=""
KUSTO_CONNECTOR_URI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      require_value "--endpoint" "${2:-}"
      ENDPOINT="$2"
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
    -h|--help)
      usage 0
      ;;
    *)
      fail "Error: unknown argument '$1'" 2
      ;;
  esac
done

[[ -n "$ENDPOINT" ]] || fail "Error: --endpoint <url> is required" 2
[[ -n "$RECIPE_DIR" ]] || fail "Error: --recipe <dir> is required" 2
[[ -n "$BUILD_DIR" ]] || fail "Error: --build-dir <dir> is required" 2
[[ -d "$RECIPE_DIR" ]] || fail "Error: recipe directory not found: $RECIPE_DIR" 1
command -v srectl >/dev/null || fail "srectl is required" 1

RECIPE_DIR="$(cd "$RECIPE_DIR" && pwd)"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

get_sre_token() {
  az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null
}

apply_kusto_connector() {
  local connector_dir="$1"
  local connector_name="$2"
  local body_file="${connector_dir}/${connector_name}.json"
  local response_file="${connector_dir}/${connector_name}.response.json"
  local token
  local http_code

  jq -n \
    --arg name "$connector_name" \
    --arg data_source "$KUSTO_CONNECTOR_URI" \
    '{
      name: $name,
      type: "AgentConnector",
      properties: {
        dataConnectorType: "Kusto",
        dataSource: $data_source,
        identity: "system"
      }
    }' > "$body_file"

  for attempt in 1 2 3 4 5; do
    token="$(get_sre_token)"
    [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X PUT "${ENDPOINT}/api/v2/extendedAgent/connectors/${connector_name}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}")"; then
      :
    else
      http_code="000"
    fi

    case "$http_code" in
      200|201|202)
        echo "  ${connector_name} connector configured"
        return 0
        ;;
    esac

    echo "  ${connector_name} connector attempt ${attempt}/5 returned HTTP ${http_code}"
    if [[ "$attempt" != "5" ]]; then
      sleep 15
    fi
  done

  echo "  ${connector_name} connector response: $response_file"
  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to configure ${connector_name} connector" 1
}

apply_built_in_tools_config() {
  local config_file="$1"
  local output_dir="$2"
  local body_file="${output_dir}/built-in-tools.json"
  local response_file="${output_dir}/built-in-tools.response.json"
  local token
  local http_code
  local override_count

  [[ -f "$config_file" ]] || {
    echo "  built-in tools: no config"
    return 0
  }

  override_count="$(jq '.overrides | length' "$config_file")"
  if [[ "$override_count" == "0" ]]; then
    echo "  built-in tools: no overrides"
    return 0
  fi

  jq '{overrides: [.overrides[] | {name, enabled}]}' "$config_file" > "$body_file"

  for attempt in 1 2 3 4 5; do
    token="$(get_sre_token)"
    [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X POST "${ENDPOINT}/api/v2/agent/tools/configure" \
      -H "Authorization: Bearer ${token}" \
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

    echo "  built-in tools attempt ${attempt}/5 returned HTTP ${http_code}"
    if [[ "$attempt" != "5" ]]; then
      sleep 15
    fi
  done

  echo "  built-in tools response: $response_file"
  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to configure built-in tools" 1
}

echo ""
echo "============================================="
echo "  SRE Agent - Post-Provision Setup"
echo "============================================="
echo ""
echo "Agent endpoint: $ENDPOINT"
echo "Recipe:         $RECIPE_DIR"
echo ""

echo "Step 1/7: Initializing srectl..."
(
  cd "$BUILD_DIR"
  srectl init --resource-url "$ENDPOINT" --quiet
)
echo "  srectl initialized"
echo ""

if [[ -n "$KUSTO_CONNECTOR_URI" ]]; then
  command -v az >/dev/null || fail "az is required when --kusto-connector-uri is provided" 1
  command -v curl >/dev/null || fail "curl is required when --kusto-connector-uri is provided" 1
  command -v jq >/dev/null || fail "jq is required when --kusto-connector-uri is provided" 1
  echo "Step 2/7: Configuring FinOps Hub Kusto connector..."
  CONNECTOR_DIR="${BUILD_DIR}/connectors"
  mkdir -p "$CONNECTOR_DIR"
  apply_kusto_connector "$CONNECTOR_DIR" "finops-hub-kusto"
else
  echo "Step 2/7: Kusto connector skipped"
fi
echo ""

command -v az >/dev/null || fail "az is required to configure built-in tools" 1
command -v curl >/dev/null || fail "curl is required to configure built-in tools" 1
command -v jq >/dev/null || fail "jq is required to configure built-in tools" 1
echo "Step 3/7: Configuring built-in tools..."
BUILT_IN_TOOLS_DIR="${BUILD_DIR}/built-in-tools"
mkdir -p "$BUILT_IN_TOOLS_DIR"
apply_built_in_tools_config "${RECIPE_DIR}/config/built-in-tools.json" "$BUILT_IN_TOOLS_DIR"
echo ""

echo "Step 4/7: Uploading knowledge base..."
KNOWLEDGE_DOC_NAMES=()

knowledge_source_name() {
  basename "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g'
}

knowledge_content_type() {
  local file="$1"
  case "${file##*.}" in
    md) echo "text/markdown" ;;
    txt) echo "text/plain" ;;
    json) echo "application/json" ;;
    csv) echo "text/csv" ;;
    yaml|yml) echo "application/yaml" ;;
    *) file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream" ;;
  esac
}

upload_knowledge_file() {
  local file="$1"
  local label="${2:-$file}"
  local source_name
  local display_name
  local content_type
  local body_file
  local response_file
  local token
  local http_code

  source_name="$(knowledge_source_name "$file")"
  display_name="$(basename "$file")"
  content_type="$(knowledge_content_type "$file")"
  body_file="${KNOWLEDGE_SOURCE_DIR}/${source_name}.json"
  response_file="${KNOWLEDGE_SOURCE_DIR}/${source_name}.response.json"

  echo "  knowledge source: $label"

  jq -n \
    --arg name "$source_name" \
    --arg display_name "$display_name" \
    --arg file_name "$display_name" \
    --arg content_type "$content_type" \
    --arg file_content "$(base64 < "$file" | tr -d '\n')" \
    '{
      name: $name,
      type: "KnowledgeItem",
      properties: {
        dataConnectorType: "KnowledgeFile",
        dataSource: $name,
        extendedProperties: {
          displayName: $display_name,
          fileName: $file_name,
          fileContent: $file_content,
          contentType: $content_type
        }
      }
    }' > "$body_file"

  for attempt in 1 2 3 4 5; do
    token="$(get_sre_token)"
    [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X PUT "${ENDPOINT}/api/v2/extendedAgent/connectors/${source_name}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}")"; then
      :
    else
      http_code="000"
    fi

    case "$http_code" in
      200|201|202)
        return 0
        ;;
    esac

    echo "  knowledge source attempt ${attempt}/5 returned HTTP ${http_code}"
    if [[ "$attempt" != "5" ]]; then
      sleep 15
    fi
  done

  echo "  knowledge source response: $response_file"
  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to upload knowledge source: $display_name" 1
}

verify_knowledge_docs() {
  local expected_docs=("$@")
  local token
  local http_code
  local response_file="${KNOWLEDGE_SOURCE_DIR}/knowledge-sources.response.json"
  local detail_file
  local attempt
  local missing
  local unindexed
  local doc
  local source_name
  local entry
  local indexed
  local reason

  [[ "${#expected_docs[@]}" -gt 0 ]] || return 0
  command -v az >/dev/null || fail "az is required to verify knowledge indexing" 1
  command -v curl >/dev/null || fail "curl is required to verify knowledge indexing" 1
  command -v jq >/dev/null || fail "jq is required to verify knowledge indexing" 1

  echo "  waiting for knowledge sources to index..."
  for ((attempt = 1; attempt <= 20; attempt++)); do
    token="$(get_sre_token)"
    [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      "${ENDPOINT}/api/v2/extendedAgent/connectors" \
      -H "Authorization: Bearer ${token}")"; then
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

        detail_file="${KNOWLEDGE_SOURCE_DIR}/${source_name}.detail.json"
        if http_code="$(curl -sS -o "$detail_file" -w "%{http_code}" \
          "${ENDPOINT}/api/v2/extendedAgent/connectors/${source_name}" \
          -H "Authorization: Bearer ${token}")"; then
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
  if [[ -f "$response_file" ]]; then
    for doc in "${expected_docs[@]}"; do
      source_name="$(knowledge_source_name "$doc")"
      entry="$(jq -c --arg name "$source_name" '[.value[]? | select(.name == $name and .properties.dataConnectorType == "KnowledgeFile")][0] // empty' "$response_file" 2>/dev/null || true)"
      if [[ -z "$entry" ]]; then
        echo "    ${doc}: missing" >&2
      else
        detail_file="${KNOWLEDGE_SOURCE_DIR}/${source_name}.detail.json"
        indexed="$(jq -r '.properties.extendedProperties.createdAt // empty' "$detail_file" 2>/dev/null || true)"
        reason="$(jq -r '.properties.extendedProperties.errorReason // ""' "$detail_file" 2>/dev/null || true)"
        echo "    ${doc}: indexed=${indexed}${reason:+ reason=${reason}}" >&2
      fi
    done
  fi
  fail "Knowledge sources failed to index" 1
}

command -v az >/dev/null || fail "az is required to upload knowledge sources" 1
command -v base64 >/dev/null || fail "base64 is required to upload knowledge sources" 1
command -v curl >/dev/null || fail "curl is required to upload knowledge sources" 1
command -v jq >/dev/null || fail "jq is required to upload knowledge sources" 1

KNOWLEDGE_SOURCE_DIR="${BUILD_DIR}/knowledge-sources"
mkdir -p "$KNOWLEDGE_SOURCE_DIR"

KNOWLEDGE_DIR="${RECIPE_DIR}/knowledge"
if [[ -d "$KNOWLEDGE_DIR" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    KNOWLEDGE_DOC_NAMES+=("$(basename "$file")")
    upload_knowledge_file "$file" "${file#${RECIPE_DIR}/}"
  done < <(find -L "$KNOWLEDGE_DIR" -type f | sort)
else
  echo "  no knowledge directory"
fi

OUTPUT_STYLE_DOC="${RECIPE_DIR}/../../../claude-plugin/output-styles/ftk-output-style.md"
[[ -f "$OUTPUT_STYLE_DOC" ]] || fail "Error: output style knowledge document not found: $OUTPUT_STYLE_DOC" 1
KNOWLEDGE_DOC_NAMES+=("$(basename "$OUTPUT_STYLE_DOC")")
upload_knowledge_file "$OUTPUT_STYLE_DOC" "claude-plugin/output-styles/ftk-output-style.md"
verify_knowledge_docs "${KNOWLEDGE_DOC_NAMES[@]}"
echo ""

apply_yaml_dir() {
  local label="$1"
  local dir="$2"
  local total=0
  [[ -d "$dir" ]] || {
    echo "  ${label}: none"
    return 0
  }

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    total=$((total + 1))
    echo "  ${label}: ${file#${RECIPE_DIR}/}"
    (
      cd "$BUILD_DIR"
      srectl apply-yaml --file "$file" --quiet
    )
  done < <(find -L "$dir" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
  echo "  ${label}: ${total} applied"
}

scheduled_task_names() {
  local dir="$1"

  python3 - "$dir" <<'PY'
import os
import pathlib
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required to read scheduled task manifests", file=sys.stderr)
    sys.exit(1)

root = pathlib.Path(sys.argv[1])
paths = []
for dirpath, _, filenames in os.walk(root, followlinks=True):
    for filename in filenames:
        path = pathlib.Path(dirpath) / filename
        if path.suffix.lower() in {".yaml", ".yml"}:
            paths.append(path)

for path in sorted(paths):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    metadata = data.get("metadata") or {}
    spec = data.get("spec") or {}
    name = metadata.get("name") or spec.get("name")
    if not name:
        raise SystemExit(f"Scheduled task manifest missing metadata.name/spec.name: {path}")
    print(name)
PY
}

delete_existing_scheduled_tasks() {
  local dir="$1"
  local names_file="${BUILD_DIR}/scheduledtasks.names"
  local response_file="${BUILD_DIR}/scheduledtasks.existing.json"
  local token
  local http_code
  local name
  local ids
  local id
  local deleted=0

  [[ -d "$dir" ]] || return 0
  scheduled_task_names "$dir" > "$names_file"
  [[ -s "$names_file" ]] || return 0

  token="$(get_sre_token)"
  [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

  if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
    "${ENDPOINT}/api/v1/scheduledtasks" \
    -H "Authorization: Bearer ${token}")"; then
    :
  else
    http_code="000"
  fi

  [[ "$http_code" == "200" ]] || fail "Failed to list existing scheduled tasks before apply (HTTP ${http_code})" 1

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    ids="$(jq -r --arg name "$name" '.[]? | select(.name == $name) | .id // empty' "$response_file" 2>/dev/null || true)"
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      echo "  scheduled-task: deleting existing ${name} (${id})"
      (
        cd "$BUILD_DIR"
        srectl scheduledtask delete --id "$id" --quiet
      )
      deleted=$((deleted + 1))
    done <<< "$ids"
  done < "$names_file"

  [[ "$deleted" -eq 0 ]] || echo "  scheduled-task: ${deleted} existing deleted before apply"
}

ordered_subagent_files() {
  local dir="$1"

  python3 - "$dir" <<'PY'
import os
import pathlib
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required to order subagent handoffs", file=sys.stderr)
    sys.exit(1)

root = pathlib.Path(sys.argv[1])
files = []
for dirpath, _, filenames in os.walk(root, followlinks=True):
    for filename in filenames:
        path = pathlib.Path(dirpath) / filename
        if path.suffix.lower() in {".yaml", ".yml"}:
            files.append(path)
files = sorted(files)

by_name = {}
metadata = {}
for path in files:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    metadata_section = data.get("metadata") or {}
    spec = data.get("spec") or {}
    name = metadata_section.get("name") or spec.get("name") or path.stem
    handoffs = spec.get("handoffs") or []
    by_name[name] = path
    metadata[path] = {"name": name, "handoffs": handoffs}

dependencies = {
    path: [by_name[name] for name in metadata[path]["handoffs"] if name in by_name]
    for path in files
}

ordered = []
visiting = set()
visited = set()

def visit(path):
    if path in visited:
        return
    if path in visiting:
        cycle = " -> ".join(p.name for p in visiting) + f" -> {path.name}"
        raise SystemExit(f"Subagent handoff cycle detected: {cycle}")
    visiting.add(path)
    for dependency in dependencies[path]:
        visit(dependency)
    visiting.remove(path)
    visited.add(path)
    ordered.append(path)

for path in files:
    visit(path)

for path in ordered:
    print(path)
PY
}

apply_subagents_dir() {
  local dir="$1"
  local total=0
  local order_file="${BUILD_DIR}/subagents.order"
  [[ -d "$dir" ]] || {
    echo "  subagent: none"
    return 0
  }

  ordered_subagent_files "$dir" > "$order_file"
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    total=$((total + 1))
    echo "  subagent: ${file#${RECIPE_DIR}/}"
    (
      cd "$BUILD_DIR"
      srectl apply-yaml --file "$file" --quiet
    )
  done < "$order_file"
  echo "  subagent: ${total} applied"
}

echo "Step 5/7: Applying tools..."
apply_yaml_dir "tool" "${RECIPE_DIR}/config/tools"
echo ""

echo "Step 6/7: Applying skills and subagents..."
SKILLS_SRC="${RECIPE_DIR}/config/skills"
SKILLS_WORK="${BUILD_DIR}/skills"
rm -rf "$SKILLS_WORK"
mkdir -p "$SKILLS_WORK"
if [[ -d "$SKILLS_SRC" ]]; then
  cp -RL "${SKILLS_SRC}/." "$SKILLS_WORK/"
  for skill_dir in "$SKILLS_WORK"/*; do
    [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
    skill_name="$(basename "$skill_dir")"
    echo "  skill: $skill_name"
    (
      cd "$BUILD_DIR"
      srectl skill apply --name "$skill_name" --quiet
    )
  done
else
  echo "  skills: none"
fi
apply_subagents_dir "${RECIPE_DIR}/config/subagents"
echo ""

echo "Step 7/7: Applying scheduled tasks..."
TASK_DIR="${RECIPE_DIR}/automations/scheduled-tasks"
if [[ -d "$TASK_DIR" ]]; then
  delete_existing_scheduled_tasks "$TASK_DIR"
  total=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    total=$((total + 1))
    echo "  scheduled-task: ${file#${RECIPE_DIR}/}"
    (
      cd "$BUILD_DIR"
      srectl scheduledtask apply --file "$file" --quiet
    )
  done < <(find -L "$TASK_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
  echo "  scheduled-task: ${total} applied"
else
  echo "  scheduled-task: none"
fi
echo ""

echo "============================================="
echo "  SRE Agent post-provision complete"
echo "============================================="
echo ""
