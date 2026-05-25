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
  --managed-identity-id <id>    Agent user-assigned managed identity resource ID
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
MANAGED_IDENTITY_ID=""

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
    --managed-identity-id)
      require_value "--managed-identity-id" "${2:-}"
      MANAGED_IDENTITY_ID="$2"
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
  local body_file="${connector_dir}/finops-hub-kusto.json"
  local response_file="${connector_dir}/finops-hub-kusto.response.json"
  local token
  local http_code

  jq -n \
    --arg data_source "$KUSTO_CONNECTOR_URI" \
    --arg identity "$MANAGED_IDENTITY_ID" \
    '{
      name: "finops-hub-kusto",
      type: "AgentConnector",
      properties: {
        dataConnectorType: "Kusto",
        dataSource: $data_source,
        identity: $identity
      }
    }' > "$body_file"

  for attempt in 1 2 3 4 5; do
    token="$(get_sre_token)"
    [[ -n "$token" ]] || fail "Error: failed to get Azure SRE Agent bearer token" 1

    if http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
      -X PUT "${ENDPOINT}/api/v2/extendedAgent/connectors/finops-hub-kusto" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}")"; then
      :
    else
      http_code="000"
    fi

    case "$http_code" in
      200|201|202)
        echo "  finops-hub-kusto connector configured"
        return 0
        ;;
    esac

    echo "  connector attempt ${attempt}/5 returned HTTP ${http_code}"
    if [[ "$attempt" != "5" ]]; then
      sleep 15
    fi
  done

  echo "  connector response: $response_file"
  sed -n '1,120p' "$response_file" >&2 || true
  fail "Failed to configure finops-hub-kusto connector" 1
}

echo ""
echo "============================================="
echo "  SRE Agent - Post-Provision Setup"
echo "============================================="
echo ""
echo "Agent endpoint: $ENDPOINT"
echo "Recipe:         $RECIPE_DIR"
echo ""

echo "Step 1/6: Initializing srectl..."
(
  cd "$BUILD_DIR"
  srectl init --resource-url "$ENDPOINT" --quiet
)
echo "  srectl initialized"
echo ""

if [[ -n "$KUSTO_CONNECTOR_URI" ]]; then
  [[ -n "$MANAGED_IDENTITY_ID" ]] || fail "Error: --managed-identity-id is required when --kusto-connector-uri is provided" 2
  command -v az >/dev/null || fail "az is required when --kusto-connector-uri is provided" 1
  command -v curl >/dev/null || fail "curl is required when --kusto-connector-uri is provided" 1
  command -v jq >/dev/null || fail "jq is required when --kusto-connector-uri is provided" 1
  echo "Step 2/6: Configuring FinOps Hub Kusto connector..."
  CONNECTOR_DIR="${BUILD_DIR}/connectors"
  mkdir -p "$CONNECTOR_DIR"
  apply_kusto_connector "$CONNECTOR_DIR"
else
  echo "Step 2/6: Kusto connector skipped"
fi
echo ""

echo "Step 3/6: Uploading knowledge base..."
KNOWLEDGE_DIR="${RECIPE_DIR}/knowledge"
if [[ -d "$KNOWLEDGE_DIR" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    echo "  doc: ${file#${RECIPE_DIR}/}"
    (
      cd "$BUILD_DIR"
      srectl doc upload --file "$file"
    )
  done < <(find "$KNOWLEDGE_DIR" -type f | sort)
else
  echo "  no knowledge directory"
fi
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
  done < <(find "$dir" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
  echo "  ${label}: ${total} applied"
}

ordered_subagent_files() {
  local dir="$1"

  python3 - "$dir" <<'PY'
import pathlib
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required to order subagent handoffs", file=sys.stderr)
    sys.exit(1)

root = pathlib.Path(sys.argv[1])
files = sorted(
    path for path in root.rglob("*")
    if path.is_file() and path.suffix.lower() in {".yaml", ".yml"}
)

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

echo "Step 4/6: Applying tools..."
apply_yaml_dir "tool" "${RECIPE_DIR}/config/tools"
echo ""

echo "Step 5/6: Applying skills and subagents..."
SKILLS_SRC="${RECIPE_DIR}/config/skills"
SKILLS_WORK="${BUILD_DIR}/skills"
rm -rf "$SKILLS_WORK"
mkdir -p "$SKILLS_WORK"
if [[ -d "$SKILLS_SRC" ]]; then
  cp -R "${SKILLS_SRC}/." "$SKILLS_WORK/"
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

echo "Step 6/6: Applying scheduled tasks..."
TASK_DIR="${RECIPE_DIR}/automations/scheduled-tasks"
if [[ -d "$TASK_DIR" ]]; then
  total=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    total=$((total + 1))
    echo "  scheduled-task: ${file#${RECIPE_DIR}/}"
    (
      cd "$BUILD_DIR"
      srectl scheduledtask apply --file "$file" --quiet
    )
  done < <(find "$TASK_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
  echo "  scheduled-task: ${total} applied"
else
  echo "  scheduled-task: none"
fi
echo ""

echo "============================================="
echo "  SRE Agent post-provision complete"
echo "============================================="
echo ""
