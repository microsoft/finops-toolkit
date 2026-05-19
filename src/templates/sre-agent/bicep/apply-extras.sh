#!/usr/bin/env bash
# apply-extras.sh
#
# Applies agent configuration via ARM sub-resources (preferred) or data-plane.
#
# Two auth paths:
#
#   1. ARM sub-resources (connectors, incidentFilters, scheduledTasks,
#      commonPrompts) — uses `az rest` with management-plane token.
#      Works in Cloud Shell and CI/CD pipelines.
#
#   2. Data-plane only (hooks, httpTriggers, repos, knowledge upload)
#      — requires token for audience https://azuresre.dev.
#      Falls back gracefully: if data-plane token is unavailable,
#      prints what was skipped so you can finish from a compliant machine.
#
# Auth:
#   ARM calls         → `az login` (control-plane token, always available)
#   data-plane calls  → token with audience https://azuresre.dev
#                       (`az account get-access-token --resource ...`)
#                       Optional — script continues if unavailable
#
# Repo auth (GitHub / ADO):
#   GitHub — two paths, the script picks based on what env vars are set:
#     1. OAuth (default): no env vars needed. Script prints a sign-in URL at the
#        end. Click it, approve in the browser, GitHub redirects back to the
#        agent and the token is stored. No secrets in env.
#     2. PAT (optional, headless): export GITHUB_PAT=ghp_xxx before running.
#        Script POSTs the PAT silently — no browser.
#   ADO — set $ADO_PAT, $ADO_USE_AAD=1, or $ADO_USE_MI=1 (with $ADO_ORG).
#
# Usage:
#   ./apply-extras.sh <subscription-id> <resource-group> <agent-name> [extras-file]

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <subscription-id> <resource-group> <agent-name> [extras-file] [--force]

Arguments:
  <subscription-id>   Subscription
  <resource-group>    Resource group
  <agent-name>        Agent name
  [extras-file]       Extras JSON file (default: extras.parameters.json)

Options:
  --force             Continue past non-fatal checks
  -h, --help          Show this help
EOF
  exit "${1:-0}"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -ge 3 ]] || usage 2

SUB="$1"
RG="$2"
AGENT="$3"
shift 3

FILE="extras.parameters.json"
FORCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE="true"; shift ;;
    -h|--help) usage 0 ;;
    *)
      if [[ "$FILE" == "extras.parameters.json" ]]; then
        FILE="$1"
        shift
      else
        echo "Error: unexpected argument '$1'" >&2
        usage 2
      fi
      ;;
  esac
done

[[ -f "$FILE" ]] || { echo "extras file not found: $FILE" >&2; exit 1; }
command -v jq    >/dev/null || { echo "jq is required"    >&2; exit 1; }
command -v tar   >/dev/null || { echo "tar is required"   >&2; exit 1; }
command -v curl  >/dev/null || { echo "curl is required"  >&2; exit 1; }

az() { command az "$@" --subscription "$SUB"; }

API_VERSION="2025-05-01-preview"
ARM_BASE="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/agents/${AGENT}"

# Look up the data-plane endpoint and the agent's user-assigned MI (we use it
# as the connector identity).
AGENT_JSON=$(az rest -m GET --url "${ARM_BASE}?api-version=${API_VERSION}" -o json 2>/dev/null || echo "{}")
AGENT_ENDPOINT=$(echo "$AGENT_JSON" | jq -r '.properties.agentEndpoint // empty')
AGENT_UAMI=$(echo "$AGENT_JSON" | jq -r '.identity.userAssignedIdentities | keys[0] // empty')
if [[ -z "$AGENT_ENDPOINT" || "$AGENT_ENDPOINT" == "null" ]]; then
  echo "Could not resolve agent endpoint. Is ${AGENT} provisioned in ${RG}?" >&2
  exit 1
fi
echo "Agent endpoint: ${AGENT_ENDPOINT}"
[[ -n "$AGENT_UAMI" ]] && echo "Agent UAMI:     ${AGENT_UAMI##*/}"

# ---------------------------------------------------------------------------
# Probe data-plane token availability (optional — ARM path is preferred).
# If unavailable, ARM items still deploy; data-plane-only items are skipped.
# ---------------------------------------------------------------------------
DP_TOKEN_AVAILABLE=false
DP_SKIPPED_ITEMS=()
if az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv > /dev/null 2>&1; then
  DP_TOKEN_AVAILABLE=true
  echo "Data-plane:     token available"
else
  echo "Data-plane:     token unavailable (hooks, repos, httpTriggers will be skipped)"
  echo "                To apply later: az login --scope \"https://azuresre.dev/.default\" && re-run"
fi

# ---------------------------------------------------------------------------
# Helper: PUT an ARM sub-resource with base64-encoded value envelope.
# Used for incidentFilters, scheduledTasks, commonPrompts.
# Body: { properties: { value: "<base64 of JSON spec>" } }
# ---------------------------------------------------------------------------
arm_put_subresource() {
  local type="$1" name="$2" spec_json="$3"
  local url="${ARM_BASE}/${type}/${name}?api-version=${API_VERSION}"
  local encoded
  encoded=$(printf '%s' "$spec_json" | base64)
  local tmp
  tmp=$(mktemp)
  printf '{"properties":{"value":"%s"}}' "$encoded" > "$tmp"
  echo "  ARM PUT ${type}/${name}"
  local result
  result=$(az rest -m PUT --url "$url" --body "@${tmp}" \
       --headers "Content-Type=application/json" -o json 2>&1) && {
    echo "    ok"
  } || {
    echo "    FAILED — $(echo "$result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)"
  }
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Helper: PUT an ARM connector sub-resource (native properties, no base64).
# Used for MCP connectors, KnowledgeFile connectors.
# Body: { properties: { dataConnectorType, dataSource, extendedProperties, ... } }
# ---------------------------------------------------------------------------
arm_put_connector() {
  local name="$1" body_json="$2"
  local url="${ARM_BASE}/connectors/${name}?api-version=${API_VERSION}"
  local tmp
  tmp=$(mktemp)
  printf '%s' "$body_json" > "$tmp"
  echo "  ARM PUT connectors/${name}"
  local result
  result=$(az rest -m PUT --url "$url" --body "@${tmp}" \
       --headers "Content-Type=application/json" -o json 2>&1) && {
    echo "    ok"
  } || {
    echo "    FAILED — $(echo "$result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)"
  }
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Helper: build tar.gz from an inline files array, upload to data-plane.
# files JSON shape: [ { "path": "general.md", "content": "..." }, ... ]
# ---------------------------------------------------------------------------
dataplane_upload_tarball() {
  local label="$1" url="$2" files_json="$3"
  local stage tarball token
  stage=$(mktemp -d)
  trap 'rm -rf "$stage"' RETURN

  local n
  n=$(printf '%s' "$files_json" | jq 'length')
  for i in $(seq 0 $((n - 1))); do
    local p c full
    p=$(printf '%s' "$files_json" | jq -r --argjson i "$i" '.[$i].path')
    c=$(printf '%s' "$files_json" | jq -r --argjson i "$i" '.[$i].content')
    full="${stage}/${p}"
    mkdir -p "$(dirname "$full")"
    printf '%s' "$c" > "$full"
  done

  tarball=$(mktemp -t extras.XXXXXX.tar.gz)
  tar -czf "$tarball" -C "$stage" .

  token=$(az account get-access-token --resource https://azuresre.dev \
    --query accessToken -o tsv 2>/dev/null) || {
      echo "    FAILED — could not get data-plane token (audience https://azuresre.dev)"
      rm -f "$tarball"
      return 1
    }

  echo "  data-plane POST ${label}  ($n file$([[ $n -eq 1 ]] || echo s))"
  if curl -sS -f -X POST "$url" \
       -H "Authorization: Bearer ${token}" \
       -H "Content-Type: application/gzip" \
       --data-binary "@${tarball}" >/dev/null; then
    echo "    ok"
  else
    echo "    FAILED — POST ${url}"
  fi
  rm -f "$tarball"
}

# ---------------------------------------------------------------------------
# Helper: upload one file via multipart/form-data to AgentMemory.
# Used for `knowledge` entries (RAG-indexed via Azure AI Search).
# Each call uploads ONE file; service caps: ≤16MB/file, ≤100MB/request.
# Supports inline `content` (text) or `localPath` (binary).
# ---------------------------------------------------------------------------
dataplane_upload_multipart() {
  local label="$1" url="$2" filename="$3" mime="$4" trigger="$5" src_path="$6"
  local token
  token=$(_dp_token) || { echo "    FAILED — could not get data-plane token"; return 1; }

  echo "  data-plane multipart POST ${label} (${filename})"
  if curl -sS -f -X POST "${url}?triggerIndexing=${trigger}" \
       -H "Authorization: Bearer ${token}" \
       -F "files=@${src_path};filename=${filename};type=${mime}" >/dev/null; then
    echo "    ok"
  else
    echo "    FAILED — POST ${url}"
  fi
}

# ---------------------------------------------------------------------------
# Helper: POST a plugin marketplace or installation document (data-plane v2).
# ---------------------------------------------------------------------------
dataplane_post_json() {
  local label="$1" url="$2" body_json="$3"
  local token
  token=$(_dp_token) || { echo "    FAILED — could not get data-plane token"; return 1; }
  echo "  data-plane POST ${label}"
  if curl -sS -f -X POST "$url" \
       -H "Authorization: Bearer ${token}" \
       -H "Content-Type: application/json" \
       --data "$body_json" >/dev/null; then
    echo "    ok"
  else
    echo "    FAILED — POST ${url}"
  fi
}

# Reusable: get a data-plane bearer (defined here so multipart helper can use it)
_dp_token() { az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null; }

echo "Applying extras to ${AGENT} in ${RG}..."

# 1. incidentPlatforms — ARM PATCH on agent resource (not sub-resource PUT)
# This sets the incident management type (AzMonitor, PagerDuty, ServiceNow, etc.)
count=$(jq '.incidentPlatforms // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "incidentPlatforms: ${count}"
  # Use the first platform (agent only supports one at a time)
  platform_type=$(jq -r '.incidentPlatforms[0].spec.platformType // .incidentPlatforms[0].spec.incidentPlatform // empty' "$FILE")
  if [[ -n "$platform_type" ]]; then
    # Check for connectionKey (PagerDuty/ServiceNow need API key)
    conn_key=$(jq -r '.incidentPlatforms[0].spec.connectionKey // empty' "$FILE")
    echo "  ARM PATCH → incidentManagementConfiguration.type=${platform_type}"
    patch_body=""
    if [[ -n "$conn_key" ]]; then
      patch_body="{\"properties\":{\"incidentManagementConfiguration\":{\"type\":\"${platform_type}\",\"connectionKey\":\"${conn_key}\",\"connectionName\":\"$(echo "$platform_type" | tr '[:upper:]' '[:lower:]')\"}}}"
    else
      patch_body="{\"properties\":{\"incidentManagementConfiguration\":{\"type\":\"${platform_type}\",\"connectionName\":\"$(echo "$platform_type" | tr '[:upper:]' '[:lower:]')\"}}}"
    fi
    if az rest --method PATCH \
      --url "${ARM_BASE}?api-version=${API_VERSION}" \
      --body "$patch_body" \
      --output none 2>&1; then
      echo "    ok"
    else
      echo "    FAILED — could not set incident platform"
    fi
    # Wait for platform to initialize
    echo "  Waiting 30s for platform to initialize..."
    sleep 30
  fi
fi

# 1b. incidentFilters — ARM PUT sub-resource
# Body: base64-encoded JSON with incidentPlatform, priorities, agentMode, handlingAgent.
# Handlers (customInstructions) require data-plane — applied if token available.
count=$(jq '.incidentFilters // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "incidentFilters (response plans): ${count}"
  for i in $(seq 0 $((count - 1))); do
    name=$(jq -r --argjson i "$i" '.incidentFilters[$i].metadata.name' "$FILE")
    spec=$(jq -c --argjson i "$i" '.incidentFilters[$i].spec' "$FILE")

    # Build ARM filter spec — pass all fields, override platform/handler/enabled
    platform=$(echo "$spec" | jq -r '.incidentPlatform // .platformType // "AzureMonitor"')
    handling=$(echo "$spec" | jq -r 'if .handlingAgent == "" or .handlingAgent == null then "default" else .handlingAgent end')
    arm_spec=$(echo "$spec" | jq -c --arg p "$platform" --arg h "$handling" \
      'del(.customInstructions) + {incidentPlatform: $p, handlingAgent: $h, isEnabled: true}')

    # ARM PUT with retry — platform init may still be in progress after PATCH
    filter_ok=false
    for attempt in 1 2 3 4; do
      local_url="${ARM_BASE}/incidentFilters/${name}?api-version=${API_VERSION}"
      local_encoded=$(printf '%s' "$arm_spec" | base64)
      local_tmp=$(mktemp)
      printf '{"properties":{"value":"%s"}}' "$local_encoded" > "$local_tmp"
      local_result=$(az rest -m PUT --url "$local_url" --body "@${local_tmp}" \
           --headers "Content-Type=application/json" -o json 2>&1) && {
        echo "  ARM PUT incidentFilters/${name}"
        echo "    ok"
        filter_ok=true
        rm -f "$local_tmp"
        break
      } || {
        rm -f "$local_tmp"
        if [[ $attempt -lt 4 ]]; then
          echo "  ARM PUT incidentFilters/${name} — retry ${attempt}/4 in 30s (platform init)..."
          sleep 30
        else
          echo "  ARM PUT incidentFilters/${name}"
          echo "    FAILED — $(echo "$local_result" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)"
        fi
      }
    done
  done
fi

# 1c. scheduledTasks — ARM PUT sub-resource
count=$(jq '.scheduledTasks // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "scheduledTasks: ${count}"
  for i in $(seq 0 $((count - 1))); do
    name=$(jq -r --argjson i "$i" '.scheduledTasks[$i].metadata.name' "$FILE")
    spec=$(jq -c --argjson i "$i" '.scheduledTasks[$i].spec' "$FILE")
    # Normalize field names for the ARM envelope
    arm_spec=$(jq -c '{
      name: (.name // ""),
      description: (.description // ""),
      cronExpression: (.schedule // .cronExpression // ""),
      agentPrompt: (.prompt // .agentPrompt // ""),
      agentMode: (.mode // .agentMode // "Review")
    }' <<< "$spec")
    arm_put_subresource "scheduledTasks" "$name" "$arm_spec"
  done
fi

# 2. repos — data-plane only (requires azuresre.dev token)
count=$(jq '[.repos // [] | .[] | select(.spec.url // "" | length > 0)] | length' "$FILE")
oauth_repos=()
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    for i in $(seq 0 $((count - 1))); do
    name=$(jq -r --argjson i "$i" '[.repos[] | select(.spec.url // "" | length > 0)][$i].name' "$FILE")
    oauth_repos+=("$name")
  done
  echo "repos: ${count} (will be wired up after GitHub sign-in below)"
  else
    echo "repos: ${count} — ⚠ skipped (no data-plane token)"
    for i in $(seq 0 $((count - 1))); do
      name=$(jq -r --argjson i "$i" '.repos[$i].name' "$FILE")
      DP_SKIPPED_ITEMS+=("repo/${name}")
    done
  fi
fi

# 3. repoInstructions (data-plane tar.gz, one per repo)
count=$(jq '.repoInstructions // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    echo "repoInstructions: ${count}"
    for i in $(seq 0 $((count - 1))); do
      repo=$(jq -r --argjson i "$i" '.repoInstructions[$i].repo' "$FILE")
      files=$(jq -c --argjson i "$i" '.repoInstructions[$i].files' "$FILE")
      url="${AGENT_ENDPOINT}/api/v1/WorkspaceMemory/repo-instructions?repo=$(printf %s "$repo" | jq -sRr @uri)"
      dataplane_upload_tarball "repo-instructions/${repo}" "$url" "$files"
    done
  else
    echo "repoInstructions: ${count} — ⚠ skipped (no data-plane token)"
    DP_SKIPPED_ITEMS+=("repoInstructions (${count} items)")
  fi
fi

# 4. knowledge — AgentMemory multipart upload (data-plane only)
count=$(jq '.knowledge // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    echo "knowledge: ${count} file(s)"
    url="${AGENT_ENDPOINT}/api/v1/AgentMemory/upload"
    for i in $(seq 0 $((count - 1))); do
      fname=$(jq -r --argjson i "$i" '.knowledge[$i].filename' "$FILE")
      mime=$(jq -r --argjson i "$i" '.knowledge[$i].mimeType // "application/octet-stream"' "$FILE")
      trig=$(jq -r --argjson i "$i" '.knowledge[$i].triggerIndexing // true' "$FILE")
      lpath=$(jq -r --argjson i "$i" '.knowledge[$i].localPath // empty' "$FILE")
      if [[ -n "$lpath" ]]; then
        [[ -f "$lpath" ]] || { echo "    FAILED — localPath not found: $lpath"; continue; }
        dataplane_upload_multipart "knowledge#${i}" "$url" "$fname" "$mime" "$trig" "$lpath"
      else
        tmpf=$(mktemp)
        jq -r --argjson i "$i" '.knowledge[$i].content // ""' "$FILE" > "$tmpf"
        dataplane_upload_multipart "knowledge#${i}" "$url" "$fname" "$mime" "$trig" "$tmpf"
        rm -f "$tmpf"
      fi
    done
  else
    echo "knowledge: ${count} file(s) — ⚠ skipped (no data-plane token)"
    DP_SKIPPED_ITEMS+=("knowledge (${count} files)")
  fi
fi

# 4a-2. knowledgeItems — ARM PUT as KnowledgeFile connectors (visible in portal Knowledge Sources)
count=$(jq '.knowledgeItems // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "knowledgeItems: ${count} file(s) → Knowledge Sources (ARM)"
  for i in $(seq 0 $((count - 1))); do
    fname=$(jq -r --argjson i "$i" '.knowledgeItems[$i].name' "$FILE")
    content=$(jq -r --argjson i "$i" '.knowledgeItems[$i].content' "$FILE")
    content_length=${#content}
    sanitized=$(echo "$fname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
    b64=$(echo "$content" | base64)
    case "$fname" in
      *.md)   ctype="text/markdown" ;;
      *.txt)  ctype="text/plain" ;;
      *.pdf)  ctype="application/pdf" ;;
      *.json) ctype="application/json" ;;
      *)      ctype="application/octet-stream" ;;
    esac
    body=$(jq -nc \
      --arg name "$sanitized" \
      --arg displayName "$fname" \
      --arg fileName "$fname" \
      --arg fileContent "$b64" \
      --arg contentType "$ctype" \
      '{
        properties: {
          dataConnectorType: "KnowledgeFile",
          dataSource: $name,
          extendedProperties: {
            displayName: $displayName,
            fileName: $fileName,
            fileContent: $fileContent,
            contentType: $contentType
          }
        }
      }')
    arm_put_connector "$sanitized" "$body"
    # KnowledgeFile connectors need 15s between PUTs to avoid 500s
    [[ $i -lt $((count - 1)) ]] && sleep 15
  done
fi

# 4a-3. synthesizedKnowledge — tar.gz upload to WorkspaceMemory (data-plane)
synth_dir=$(jq -r '.synthesizedKnowledgeDir // empty' "$FILE")
if [[ -n "$synth_dir" && -d "$synth_dir" ]]; then
  sk_count=$(find "$synth_dir" -type f | wc -l | tr -d ' ')
  if [[ "$sk_count" -gt 0 ]]; then
    if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
      echo "synthesizedKnowledge: ${sk_count} file(s)"
      tarball=$(mktemp -t synth.XXXXXX.tar.gz)
      tar -czf "$tarball" -C "$synth_dir" .
      token=$(_dp_token) || { echo "    FAILED — token"; rm -f "$tarball"; }
      if [[ -n "$token" ]]; then
        echo "  data-plane POST WorkspaceMemory/synthesized-knowledge (${sk_count} files)"
        if curl -sS -f -X POST "${AGENT_ENDPOINT}/api/v1/WorkspaceMemory/synthesized-knowledge" \
             -H "Authorization: Bearer ${token}" \
             -H "Content-Type: application/gzip" \
             --data-binary "@${tarball}" >/dev/null 2>&1; then
          echo "    ok"
        else
          echo "    FAILED"
        fi
        rm -f "$tarball"
      fi
    else
      echo "synthesizedKnowledge: ${sk_count} file(s) — ⚠ skipped (no data-plane token)"
      DP_SKIPPED_ITEMS+=("synthesizedKnowledge (${sk_count} files)")
    fi
  fi
fi

# 4b. plugins.marketplaces (data-plane v2)
count=$(jq '.plugins.marketplaces // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    echo "plugins.marketplaces: ${count}"
    url="${AGENT_ENDPOINT}/api/v2/plugins/marketplaces"
    for i in $(seq 0 $((count - 1))); do
      body=$(jq -c --argjson i "$i" '{ metadata: { name: .plugins.marketplaces[$i].name }, spec: .plugins.marketplaces[$i].spec }' "$FILE")
      name=$(jq -r --argjson i "$i" '.plugins.marketplaces[$i].name' "$FILE")
      dataplane_post_json "marketplaces/${name}" "$url" "$body"
    done
  else
    echo "plugins.marketplaces: ${count} — ⚠ skipped (no data-plane token)"
    DP_SKIPPED_ITEMS+=("plugins.marketplaces (${count} items)")
  fi
fi

# 4c. plugins.installations (data-plane v2)
count=$(jq '.plugins.installations // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    echo "plugins.installations: ${count}"
    url="${AGENT_ENDPOINT}/api/v2/plugins/installations"
    for i in $(seq 0 $((count - 1))); do
      body=$(jq -c --argjson i "$i" '{ metadata: { name: .plugins.installations[$i].name }, spec: .plugins.installations[$i].spec }' "$FILE")
      name=$(jq -r --argjson i "$i" '.plugins.installations[$i].name' "$FILE")
      dataplane_post_json "installations/${name}" "$url" "$body"
    done
  else
    echo "plugins.installations: ${count} — ⚠ skipped (no data-plane token)"
    DP_SKIPPED_ITEMS+=("plugins.installations (${count} items)")
  fi
fi

# ---------------------------------------------------------------------------
# Helper: PUT to v2 extendedAgent dataplane (hooks/commonprompts/plugins).
# Body shape (from Agent.Web/ApiResources/ApiRequestEnvelope.cs):
#   { name, type, tags, properties: <spec> }
# Routes (from Agent.Web/Controllers/v2/ExtendedAgentApiController.cs):
#   PUT /api/v2/extendedAgent/{kind}/{name}  where kind ∈ {hooks,commonprompts,plugins}
# ---------------------------------------------------------------------------
dataplane_put_extended() {
  local kind="$1" name="$2" type="$3" tags_json="$4" props_json="$5"
  local TOKEN body url
  TOKEN=$(_dp_token)
  body=$(jq -nc --arg n "$name" --arg t "$type" --argjson tags "$tags_json" --argjson props "$props_json" \
    '{name:$n, type:$t, tags:$tags, properties:$props}')
  url="${AGENT_ENDPOINT}/api/v2/extendedAgent/${kind}/$(printf %s "$name" | jq -sRr @uri)"
  if curl -sS -f -X PUT "$url" \
       -H "Authorization: Bearer ${TOKEN}" \
       -H "Content-Type: application/json" \
       --data "$body" >/dev/null; then
    echo "  ok ${kind}/${name}"
  else
    echo "  FAILED — PUT ${kind}/${name}"
  fi
}

# Generic processor for hooks / commonPrompts / pluginConfigs entries.
# Each entry: { name, type, tags?, properties }
_process_extended() {
  local jq_key="$1" kind="$2"
  local count name type tags props
  count=$(jq "(.${jq_key} // []) | length" "$FILE")
  [[ "$count" -gt 0 ]] || return 0
  echo "${jq_key}: ${count}"
  for i in $(seq 0 $((count - 1))); do
    name=$(jq -r --argjson i "$i" ".${jq_key}[\$i].name" "$FILE")
    type=$(jq -r --argjson i "$i" ".${jq_key}[\$i].type // \"\"" "$FILE")
    tags=$(jq -c --argjson i "$i" ".${jq_key}[\$i].tags // []" "$FILE")
    props=$(jq -c --argjson i "$i" ".${jq_key}[\$i].properties // {}" "$FILE")
    dataplane_put_extended "$kind" "$name" "$type" "$tags" "$props"
  done
}

# 4d. hooks — data-plane only (no ARM sub-resource)
count=$(jq '(.hooks // []) | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    _process_extended "hooks" "hooks"
  else
    echo "hooks: ${count} — ⚠ skipped (no data-plane token)"
    for i in $(seq 0 $((count - 1))); do
      hname=$(jq -r --argjson i "$i" '.hooks[$i].name' "$FILE")
      DP_SKIPPED_ITEMS+=("hook/${hname}")
    done
  fi
fi

# 4e. commonPrompts — ARM PUT sub-resource
count=$(jq '(.commonPrompts // []) | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "commonPrompts: ${count} (ARM)"
  for i in $(seq 0 $((count - 1))); do
    name=$(jq -r --argjson i "$i" '.commonPrompts[$i].name' "$FILE")
    props=$(jq -c --argjson i "$i" '.commonPrompts[$i].properties // {}' "$FILE")
    arm_put_subresource "commonPrompts" "$name" "$props"
  done
fi

# 4f. pluginConfigs — data-plane only
count=$(jq '(.pluginConfigs // []) | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    _process_extended "pluginConfigs" "plugins"
  else
    echo "pluginConfigs: ${count} — ⚠ skipped (no data-plane token)"
    DP_SKIPPED_ITEMS+=("pluginConfigs (${count} items)")
  fi
fi

# 4g. httpTriggers — data-plane only
count=$(jq '.httpTriggers // [] | length' "$FILE")
HTTP_TRIGGER_URL=""
if [[ "$count" -gt 0 ]]; then
  if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then
    echo "httpTriggers: ${count}"
    TOKEN=$(_dp_token)
    EXISTING_TRIGGERS=$(curl -sS "${AGENT_ENDPOINT}/api/v1/httpTriggers" \
      -H "Authorization: Bearer ${TOKEN}" 2>/dev/null || echo '[]')
    for i in $(seq 0 $((count - 1))); do
      name=$(jq -r --argjson i "$i" '.httpTriggers[$i].name' "$FILE")
      spec=$(jq -c --argjson i "$i" '.httpTriggers[$i].spec // .httpTriggers[$i]' "$FILE")
      body=$(jq -n --arg name "$name" --argjson spec "$spec" '{name: $name} + $spec')
      existing_id=$(echo "$EXISTING_TRIGGERS" | jq -r --arg n "$name" '[.[] | select(.name == $n)] | first | .id // empty')
      if [[ -n "$existing_id" ]]; then
        existing_url="${AGENT_ENDPOINT}/api/v1/httptriggers/trigger/${existing_id}"
        echo "  httpTrigger/${name}: ${existing_url}"
        [[ -z "$HTTP_TRIGGER_URL" ]] && HTTP_TRIGGER_URL="$existing_url"
      else
        resp=$(curl -sS -w "\n%{http_code}" -X POST "${AGENT_ENDPOINT}/api/v1/httptriggers/create" \
          -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "$body" 2>&1)
        http_code=$(echo "$resp" | tail -1)
        if [[ "$http_code" =~ ^2 ]]; then
          trigger_url=$(echo "$resp" | sed '$d' | jq -r '.triggerUrl // "created"')
          echo "  httpTrigger/${name}: ${trigger_url}"
          [[ -z "$HTTP_TRIGGER_URL" ]] && HTTP_TRIGGER_URL="$trigger_url"
        else
          echo "  httpTrigger/${name}: FAILED (HTTP ${http_code})"
        fi
      fi
    done
  else
    echo "httpTriggers: ${count} — ⚠ skipped (no data-plane token)"
    for i in $(seq 0 $((count - 1))); do
      hname=$(jq -r --argjson i "$i" '.httpTriggers[$i].name' "$FILE")
      DP_SKIPPED_ITEMS+=("httpTrigger/${hname}")
    done
  fi
fi

# 4h. MCP connectors — ARM PUT (native properties, no data-plane token needed)
count=$(jq '.connectors // [] | length' "$FILE")
if [[ "$count" -gt 0 ]]; then
  echo "connectors: ${count} (ARM)"
  for i in $(seq 0 $((count - 1))); do
    cname=$(jq -r --argjson i "$i" '.connectors[$i].name' "$FILE")
    ctype=$(jq -r --argjson i "$i" '.connectors[$i].properties.dataConnectorType' "$FILE")
    body=$(jq -c --argjson i "$i" '{properties: .connectors[$i].properties}' "$FILE")
    arm_put_connector "$cname" "$body"
  done
fi

# 4i. Webhook bridge Logic App — auto-deploy if httpTriggers exist and enableWebhookBridge is set
#     Solves the chicken-and-egg: trigger URL is only known after httpTrigger creation above.
if [[ -n "$HTTP_TRIGGER_URL" ]]; then
  # Check if agent.json has enableWebhookBridge=true
  AGENT_JSON_DIR=$(dirname "$FILE")
  # The FILE is extras.json — look for agent.json in the original config dir
  # deploy.sh passes INPUT as an env var if available
  WH_ENABLED="false"
  for candidate in "${INPUT}/agent.json" "${AGENT_JSON_DIR}/../agent.json" "${AGENT_JSON_DIR}/agent.json"; do
    if [[ -f "$candidate" ]]; then
      WH_ENABLED=$(jq -r '.toggles.enableWebhookBridge // false' "$candidate" 2>/dev/null)
      break
    fi
  done

  if [[ "$WH_ENABLED" == "true" ]]; then
    # Check if Logic App already exists
    EXISTING_LA=$(az resource list -g "$RG" --resource-type Microsoft.Logic/workflows --query "[?name=='${AGENT}-webhook-bridge'].name" -o tsv 2>/dev/null)
    if [[ -n "$EXISTING_LA" ]]; then
      WH_CALLBACK=$(az rest --method POST \
        --url "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Logic/workflows/${AGENT}-webhook-bridge/triggers/incoming_webhook/listCallbackUrl?api-version=2019-05-01" \
        --query value -o tsv 2>/dev/null)
      echo
      echo "webhook-bridge: already exists"
      echo "  Callback URL: ${WH_CALLBACK}"
    else
      echo
      echo "── Deploying webhook bridge Logic App ──"
      echo "  Trigger URL: ${HTTP_TRIGGER_URL}"
      SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      LA_RESULT=$(az deployment group create \
        --resource-group "$RG" \
        --template-file "${SCRIPT_PATH}/logic-app-bridge.bicep" \
        --parameters agentName="$AGENT" location="$(az group show -n "$RG" --query location -o tsv)" triggerUrl="$HTTP_TRIGGER_URL" \
        --output json 2>&1)
      LA_STATE=$(echo "$LA_RESULT" | jq -r '.properties.provisioningState // "?"' 2>/dev/null)
      if [[ "$LA_STATE" == "Succeeded" ]]; then
        WH_CALLBACK=$(echo "$LA_RESULT" | jq -r '.properties.outputs.logicAppCallbackUrl.value // empty')
        echo "  ✅ Webhook bridge deployed"
        echo "  Callback URL: ${WH_CALLBACK}"
      else
        echo "  ❌ Webhook bridge deployment failed"
        echo "$LA_RESULT" | head -10
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 5. Post-deploy auth wiring (data-plane). All optional — driven by env vars
#    so secrets never sit in JSON. Requires data-plane token.
# ---------------------------------------------------------------------------

if [[ "$DP_TOKEN_AVAILABLE" == "true" ]]; then

# Reusable: get a data-plane bearer (already defined above for multipart helper)

# 5a. GitHub auth
#   - GITHUB_PAT set  → install PAT silently (no browser)
#   - GITHUB_PAT unset → print OAuth login URL at the end (browser sign-in, no secret in env)
if [[ -n "${GITHUB_PAT:-}" ]]; then
  echo "GitHub auth: installing PAT (no browser needed)"
  TOKEN=$(_dp_token)
  if curl -sS -f -X POST "${AGENT_ENDPOINT}/api/v1/Github/auth/pat" \
       -H "Authorization: Bearer ${TOKEN}" \
       -H "Content-Type: application/json" \
       --data "{\"accessToken\":\"${GITHUB_PAT}\"}" >/dev/null; then
    echo "  ok"
  else
    echo "  FAILED — POST /api/v1/Github/auth/pat"
  fi
elif [[ ${#oauth_repos[@]} -gt 0 ]]; then
  echo "GitHub auth: will use OAuth (browser sign-in) — see URL below"
fi

# 5b. Azure DevOps PAT
if [[ -n "${ADO_PAT:-}" && -n "${ADO_ORG:-}" ]]; then
  echo "post_deploy: ADO PAT detected — wiring up for ${ADO_ORG}"
  TOKEN=$(_dp_token)
  if curl -sS -f -X POST "${AGENT_ENDPOINT}/api/v1/AzureDevOps/auth/pat?organization=${ADO_ORG}" \
       -H "Authorization: Bearer ${TOKEN}" \
       -H "Content-Type: application/json" \
       --data "{\"accessToken\":\"${ADO_PAT}\"}" >/dev/null; then
    echo "  ok"
  else
    echo "  FAILED — POST /api/v1/AzureDevOps/auth/pat"
  fi
fi

# 5c. Azure DevOps via AAD (uses your `az login` token, no PAT needed)
if [[ "${ADO_USE_AAD:-0}" == "1" && -n "${ADO_ORG:-}" ]]; then
  echo "post_deploy: wiring ADO via your AAD token for ${ADO_ORG}"
  AAD_TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>/dev/null)
  TOKEN=$(_dp_token)
  if curl -sS -f -X POST "${AGENT_ENDPOINT}/api/v1/AzureDevOps/aadauth/complete?organization=${ADO_ORG}" \
       -H "Authorization: Bearer ${TOKEN}" \
       -H "Content-Type: application/json" \
       --data "{\"aadAccessToken\":\"${AAD_TOKEN}\"}" >/dev/null; then
    echo "  ok"
  else
    echo "  FAILED — POST /api/v1/AzureDevOps/aadauth/complete"
  fi
fi

# 5d. Azure DevOps via Managed Identity
if [[ "${ADO_USE_MI:-0}" == "1" && -n "${ADO_ORG:-}" ]]; then
  echo "post_deploy: wiring ADO via agent MI for ${ADO_ORG}"
  TOKEN=$(_dp_token)
  if curl -sS -f -X POST "${AGENT_ENDPOINT}/api/v1/AzureDevOps/auth/mi?organization=${ADO_ORG}" \
       -H "Authorization: Bearer ${TOKEN}" >/dev/null; then
    echo "  ok"
  else
    echo "  FAILED — POST /api/v1/AzureDevOps/auth/mi"
  fi
fi

echo

# ---------------------------------------------------------------------------
# GitHub: OAuth sign-in + connector + repo wiring.
# Three-state flow:
#   - No repos requested              → skip
#   - Repos requested, OAuth NOT done → print sign-in URL, instruct re-run
#   - Repos requested, OAuth DONE     → create GitHubOAuth connector + PUT repos
# Repo PUT body and connector body shapes come from sreagent-investigation:
#   src/Agent/Agent.Web/Client/src/src/Common/Clients/ExtendedAgentClient.ts
#   src/Agent/Agent.Web/Client/src/src/Space/Settings/Connectors/Wizard/Common/DialogHelper.tsx
# ---------------------------------------------------------------------------
if [[ ${#oauth_repos[@]} -gt 0 ]]; then
  TOKEN=$(_dp_token 2>/dev/null || true)
  GH_STATUS=$(curl -sS -H "Authorization: Bearer ${TOKEN}" \
    "${AGENT_ENDPOINT}/api/v1/Github/auth/status" 2>/dev/null || echo '{}')
  GH_CONFIGURED=$(echo "$GH_STATUS" | jq -r '.isConfigured // .hosts[0].isConfigured // false')

  if [[ "$GH_CONFIGURED" == "true" || -n "${GITHUB_PAT:-}" ]]; then
    # ── OAuth (or PAT) is in place — wire the connector + repos ──
    echo "── Wiring GitHub connector + repos ──"

    if [[ -z "$AGENT_UAMI" ]]; then
      echo "  WARN: agent has no user-assigned MI; falling back to SystemAssigned."
      IDENT="SystemAssigned"
    else
      IDENT="$AGENT_UAMI"
    fi

    # 1) Create the GitHubOAuth connector (named 'github')
    body=$(jq -nc --arg id "$IDENT" '{
      name: "github",
      type: "AgentConnector",
      properties: {
        dataConnectorType: "GitHubOAuth",
        dataSource: "github-oauth",
        identity: $id
      }
    }')
    if curl -sS -f -X PUT "${AGENT_ENDPOINT}/api/v2/extendedAgent/connectors/github" \
         -H "Authorization: Bearer ${TOKEN}" \
         -H "Content-Type: application/json" \
         --data "$body" >/dev/null; then
      echo "  ok connector/github (GitHubOAuth, identity=${IDENT##*/})"
    else
      echo "  FAILED — PUT /api/v2/extendedAgent/connectors/github"
    fi

    # 2) Attach each repo via the v2 repos dataplane (CodeRepoApiController).
    # Route: PUT /api/v2/repos/{name}
    # Body : { name, type:"CodeRepo", properties:{ url, type:"GitHub"|"AzureDevOps", description? } }
    count=$(jq '.repos // [] | length' "$FILE")
    for i in $(seq 0 $((count - 1))); do
      rname=$(jq -r --argjson i "$i" '.repos[$i].name' "$FILE")
      rurl=$(jq -r  --argjson i "$i" '.repos[$i].spec.url' "$FILE")
      # Map our spec.type ("github"/"ado") to the View enum ("GitHub"/"AzureDevOps").
      rtype_in=$(jq -r --argjson i "$i" '.repos[$i].spec.type // "github"' "$FILE")
      case "$(printf %s "$rtype_in" | tr "[:upper:]" "[:lower:]")" in
        ado|azuredevops|azure-devops) rtype="AzureDevOps" ;;
        *)                            rtype="GitHub" ;;
      esac
      rdesc=$(jq -r --argjson i "$i" '.repos[$i].spec.description // ""' "$FILE")
      rbody=$(jq -nc --arg n "$rname" --arg u "$rurl" --arg t "$rtype" --arg d "$rdesc" '{
        name: $n,
        type: "CodeRepo",
        properties: ({ url: $u, type: $t } + (if $d == "" then {} else { description: $d } end))
      }')
      if curl -sS -f -X PUT "${AGENT_ENDPOINT}/api/v2/repos/$(printf %s "$rname" | jq -sRr @uri)" \
           -H "Authorization: Bearer ${TOKEN}" \
           -H "Content-Type: application/json" \
           --data "$rbody" >/dev/null; then
        echo "  ok repo/${rname} (${rurl})"
      else
        echo "  FAILED — PUT /api/v2/repos/${rname} (try the portal Repos blade)"
      fi
    done
    echo
  else
    # ── OAuth not done — print sign-in URL ──
    echo "── GitHub OAuth sign-in required ──"
    echo "Repos waiting: ${oauth_repos[*]}"
    OAUTH_URL=""
    if [[ -n "$TOKEN" ]]; then
      OAUTH_URL=$(curl -sS -f -H "Authorization: Bearer ${TOKEN}" \
        "${AGENT_ENDPOINT}/api/v1/Github/config" 2>/dev/null \
        | jq -r '.oAuthUrl // .OAuthUrl // empty')
    fi
    if [[ -n "${OAUTH_URL:-}" ]]; then
      echo "  1. Open this URL in a browser:"
      echo "     ${OAUTH_URL}"
      echo "  2. Sign in to GitHub and approve the SRE Agent app."
      echo
      echo "  Waiting for GitHub authorization (Ctrl-C to skip)..."
      auth_ok=false
      for attempt in $(seq 1 24); do
        sleep 10
        TOKEN=$(_dp_token 2>/dev/null || true)
        GH_CHECK=$(curl -sS -H "Authorization: Bearer ${TOKEN}" \
          "${AGENT_ENDPOINT}/api/v1/Github/auth/status" 2>/dev/null || echo '{}')
        if echo "$GH_CHECK" | jq -e '.isConfigured // .hosts[0].isConfigured' 2>/dev/null | grep -q 'true'; then
          echo "  GitHub authorized!"
          auth_ok=true
          break
        fi
        printf "  ... waiting (%d/240s)\r" $((attempt * 10))
      done
      echo

      if [[ "$auth_ok" == "true" ]]; then
        # Re-enter the OAuth-done path: create connector + repos
        echo "── Wiring GitHub connector + repos ──"
        if [[ -z "$AGENT_UAMI" ]]; then IDENT="SystemAssigned"; else IDENT="$AGENT_UAMI"; fi
        TOKEN=$(_dp_token)
        body=$(jq -nc --arg id "$IDENT" '{name:"github",type:"AgentConnector",properties:{dataConnectorType:"GitHubOAuth",dataSource:"github-oauth",identity:$id}}')
        curl -sS -f -X PUT "${AGENT_ENDPOINT}/api/v2/extendedAgent/connectors/github" \
          -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" --data "$body" >/dev/null && \
          echo "  ok connector/github" || echo "  FAILED connector/github"
        count=$(jq '.repos // [] | length' "$FILE")
        for i in $(seq 0 $((count - 1))); do
          rname=$(jq -r --argjson i "$i" '.repos[$i].name' "$FILE")
          rurl=$(jq -r --argjson i "$i" '.repos[$i].spec.url' "$FILE")
          rtype_in=$(jq -r --argjson i "$i" '.repos[$i].spec.type // "github"' "$FILE")
          case "$(printf %s "$rtype_in" | tr "[:upper:]" "[:lower:]")" in ado*) rtype="AzureDevOps" ;; *) rtype="GitHub" ;; esac
          rbody=$(jq -nc --arg n "$rname" --arg u "$rurl" --arg t "$rtype" '{name:$n,type:"CodeRepo",properties:{url:$u,type:$t}}')
          curl -sS -f -X PUT "${AGENT_ENDPOINT}/api/v2/repos/$(printf %s "$rname" | jq -sRr @uri)" \
            -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" --data "$rbody" >/dev/null && \
            echo "  ok repo/${rname}" || echo "  FAILED repo/${rname}"
        done
      else
        echo "  Timed out. Re-run apply-extras after authorizing."
        echo "  Headless alternative: export GITHUB_PAT=ghp_xxx && re-run"
      fi
    else
      echo "  Could not fetch OAuth URL from ${AGENT_ENDPOINT}/api/v1/Github/config."
      echo "  Fallback: Azure portal → agent → Repos → 'Authorize' next to each repo."
    fi
    echo
  fi
fi

if [[ -z "${ADO_PAT:-}" && "${ADO_USE_AAD:-0}" != "1" && "${ADO_USE_MI:-0}" != "1" ]]; then
  echo "Optional Azure DevOps auth (only needed if you have ADO repos / connectors):"
  echo "  PAT:  export ADO_ORG=https://dev.azure.com/<org> ADO_PAT=<pat> && re-run"
  echo "  AAD:  export ADO_ORG=https://dev.azure.com/<org> ADO_USE_AAD=1 && re-run"
  echo "  MI:   export ADO_ORG=https://dev.azure.com/<org> ADO_USE_MI=1  && re-run"
  echo
fi

fi  # end DP_TOKEN_AVAILABLE block

# ---------------------------------------------------------------------------
# Summary of skipped items (data-plane token unavailable)
# ---------------------------------------------------------------------------
if [[ ${#DP_SKIPPED_ITEMS[@]} -gt 0 ]]; then
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  ⚠ ${#DP_SKIPPED_ITEMS[@]} item(s) skipped (no data-plane token)"
  echo "  These require audience https://azuresre.dev which is not"
  echo "  available in this environment (Cloud Shell MSI)."
  echo ""
  echo "  To apply the remaining items:"
  echo "    1. From a compliant machine: az login && re-run this script"
  echo "    2. Or configure in the portal: https://sre.azure.com"
  echo ""
  echo "  Skipped:"
  for item in "${DP_SKIPPED_ITEMS[@]}"; do
    echo "    - ${item}"
  done
  echo "══════════════════════════════════════════════════════════════"
fi

echo ""
echo "── Your agent ──"
echo "  Open agent:    https://sre.azure.com/#/agent/${SUB}/${RG}/${AGENT}"
echo "  Resource group: https://portal.azure.com/#@/resource/subscriptions/${SUB}/resourceGroups/${RG}/overview"
echo "  Data plane:    ${AGENT_ENDPOINT}"
echo
echo "Done."
