#!/usr/bin/env bash
set -euo pipefail

# ─── parse --dry-run flag (must come before positional args) ──
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=true; shift; fi

SUB="${1:?subscription id required}"; RG="${2:?resource group required}"; AGENT="${3:?agent name required}"; FILE="${4:?extras file required}"
API_VERSION="2025-05-01-preview"
ARM_BASE="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/agents/${AGENT}"
ADX_ASSIGNMENT_POLL_ATTEMPTS=30; ADX_ASSIGNMENT_POLL_SECONDS=10
fail(){ printf '[apply-extras] ERROR: %s\n' "$*" >&2; exit 1; }
log(){ printf '[apply-extras] %s\n' "$*"; }
dry(){ if [ "$DRY_RUN" = true ]; then log "[dry-run] would: $*"; return 0; else return 1; fi; }
for cmd in az jq curl; do command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"; done
[ -f "$FILE" ] || fail "extras file not found: $FILE"
AGENT_JSON="$(az rest -m GET --url "${ARM_BASE}?api-version=${API_VERSION}" -o json 2>/dev/null || echo '{}')"
AGENT_ENDPOINT="$(printf '%s' "$AGENT_JSON" | jq -r '.properties.agentEndpoint // empty')"
SYSTEM_PRINCIPAL_ID="$(printf '%s' "$AGENT_JSON" | jq -r '.identity.principalId // empty')"
UAMI_ID="$(printf '%s' "$AGENT_JSON" | jq -r '.identity.userAssignedIdentities // {} | keys[0] // empty')"
UAMI_PRINCIPAL_ID=""
if [ -n "$UAMI_ID" ]; then UAMI_PRINCIPAL_ID="$(az resource show --ids "$UAMI_ID" --api-version 2024-11-30 --query properties.principalId -o tsv 2>/dev/null || true)"; fi
if [ -z "$AGENT_ENDPOINT" ]; then
  if [ "$DRY_RUN" = true ]; then log "[dry-run] Agent does not exist yet — skipping data-plane extras"; exit 0
  else fail "Could not resolve agent endpoint. Deploy the agent first (Step 2)."; fi
fi
if az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv >/dev/null 2>&1; then DP_TOKEN_AVAILABLE=true; else DP_TOKEN_AVAILABLE=false; fi
_dp_token(){ az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv 2>/dev/null; }
json_body_file(){ local name="$1"; local body="$2"; local path="${FILE}.work.${name}.json"; printf '%s' "$body" > "$path"; printf '%s' "$path"; }
cleanup_work(){ rm -f "${FILE}".work.*.json 2>/dev/null || true; }
trap cleanup_work EXIT
arm_put_value(){ local type="$1" name="$2" spec="$3" encoded body path; encoded="$(printf '%s' "$spec" | base64 | tr -d '\n')"; body="{\"properties\":{\"value\":\"${encoded}\"}}"; path="$(json_body_file "${type}-${name}" "$body")"; dry "ARM PUT ${type}/${name}" && return 0; log "ARM PUT ${type}/${name}"; az rest -m PUT --url "${ARM_BASE}/${type}/${name}?api-version=${API_VERSION}" --body "@${path}" --headers 'Content-Type=application/json' -o none; }
arm_put_connector(){ local name="$1" body="$2" path; path="$(json_body_file "connector-${name}" "$body")"; dry "ARM PUT connectors/${name}" && return 0; log "ARM PUT connectors/${name}"; az rest -m PUT --url "${ARM_BASE}/connectors/${name}?api-version=${API_VERSION}" --body "@${path}" --headers 'Content-Type=application/json' -o none; }
count="$(jq '.incidentPlatforms // [] | length' "$FILE")"
if [ "$count" -gt 0 ]; then
  platform_type="$(jq -r '.incidentPlatforms[0].spec.platformType // .incidentPlatforms[0].spec.incidentPlatform // empty' "$FILE")"
  if [ -n "$platform_type" ]; then body="$(jq -nc --arg t "$platform_type" '{properties:{incidentManagementConfiguration:{type:$t,connectionName:($t|ascii_downcase)}}}')"; if dry "ARM PATCH incident platform $platform_type"; then :; else log "ARM PATCH incident platform $platform_type"; az rest --method PATCH --url "${ARM_BASE}?api-version=${API_VERSION}" --body "$body" --output none; sleep 30; fi; fi
fi
count="$(jq '.incidentFilters // [] | length' "$FILE")"
if [ "$count" -gt 0 ]; then
  for i in $(seq 0 $((count - 1))); do
    name="$(jq -r --argjson i "$i" '.incidentFilters[$i].metadata.name' "$FILE")"; spec="$(jq -c --argjson i "$i" '.incidentFilters[$i].spec' "$FILE")"; arm_spec="$(printf '%s' "$spec" | jq -c 'del(.customInstructions) + {isEnabled: true}')"
    ok=false; for attempt in 1 2 3 4; do if arm_put_value incidentFilters "$name" "$arm_spec"; then ok=true; break; fi; [ "$attempt" -lt 4 ] && sleep 30; done; [ "$ok" = true ] || fail "Failed to apply incident filter $name."
  done
fi
count="$(jq '.scheduledTasks // [] | length' "$FILE")"
if [ "$count" -gt 0 ]; then
  for i in $(seq 0 $((count - 1))); do
    name="$(jq -r --argjson i "$i" '.scheduledTasks[$i].metadata.name' "$FILE")"
    spec="$(jq -c --argjson i "$i" '.scheduledTasks[$i].spec | {name:(.name // ""),description:(.description // ""),cronExpression:(.cron_expression // .schedule // .cronExpression // ""),agentPrompt:(.agent_prompt // .prompt // .agentPrompt // ""),agentMode:(.agent_mode // .mode // .agentMode // "Review"),agent:(.agent // "")}' "$FILE")"
    arm_put_value scheduledTasks "$name" "$spec"
  done
fi
count="$(jq '(.connectors // []) | length' "$FILE")"
if [ "$count" -gt 0 ]; then for i in $(seq 0 $((count - 1))); do name="$(jq -r --argjson i "$i" '.connectors[$i].name' "$FILE")"; body="$(jq -c --argjson i "$i" '{properties:.connectors[$i].properties}' "$FILE")"; arm_put_connector "$name" "$body"; done; fi
count="$(jq '(.knowledge // []) | length' "$FILE")"
if [ "$count" -gt 0 ]; then
  if [ "$DP_TOKEN_AVAILABLE" = true ]; then token="$(_dp_token)"; url="${AGENT_ENDPOINT}/api/v1/AgentMemory/upload"; for i in $(seq 0 $((count - 1))); do fname="$(jq -r --argjson i "$i" '.knowledge[$i].filename' "$FILE")"; mime="$(jq -r --argjson i "$i" '.knowledge[$i].mimeType // "text/plain"' "$FILE")"; trig="$(jq -r --argjson i "$i" '.knowledge[$i].triggerIndexing // true' "$FILE")"; lpath="$(jq -r --argjson i "$i" '.knowledge[$i].localPath' "$FILE")"; [ -f "$lpath" ] || { log "Skipping missing knowledge file $lpath"; continue; }; if dry "upload knowledge $fname from $lpath"; then :; else log "Upload knowledge $fname"; curl -sS -f -X POST "${url}?triggerIndexing=${trig}" -H "Authorization: Bearer ${token}" -F "files=@${lpath};filename=${fname};type=${mime}" >/dev/null; fi; done
  else log "Data-plane token unavailable; skipped $count knowledge upload(s)."; fi
fi
count="$(jq '(.hooks // []) | length' "$FILE")"
if [ "$count" -gt 0 ]; then
  if [ "$DP_TOKEN_AVAILABLE" = true ]; then token="$(_dp_token)"; for i in $(seq 0 $((count - 1))); do name="$(jq -r --argjson i "$i" '.hooks[$i].metadata.name // .hooks[$i].name' "$FILE")"; props="$(jq -c --argjson i "$i" '.hooks[$i].spec // .hooks[$i].properties // {}' "$FILE")"; body="$(jq -nc --arg n "$name" --argjson p "$props" '{name:$n,type:"GlobalHook",tags:[],properties:$p}')"; if dry "PUT hook $name"; then :; else log "PUT hook $name"; curl -sS -f -X PUT "${AGENT_ENDPOINT}/api/v2/extendedAgent/hooks/${name}" -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' --data "$body" >/dev/null; fi; done
  else log "Data-plane token unavailable; skipped $count hook(s)."; fi
fi
resolve_finops_hub_cluster(){
  [ -n "${FINOPS_HUB_CLUSTER_URI:-}" ] || return 0
  local uri_no_scheme host base_uri query body resolved count
  uri_no_scheme="$(python3 -c 'import os; u=os.environ.get("FINOPS_HUB_CLUSTER_URI",""); print(u.removeprefix("https://"))')"; host="$(python3 -c 'import os; u=os.environ.get("FINOPS_HUB_CLUSTER_URI","").removeprefix("https://"); print(u.split("/",1)[0])')"; base_uri="https://${host}"
  if [ -n "${FINOPS_HUB_CLUSTER_NAME:-}" ] && [ -n "${FINOPS_HUB_CLUSTER_RESOURCE_GROUP:-}" ]; then FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/${SUB}/resourceGroups/${FINOPS_HUB_CLUSTER_RESOURCE_GROUP}/providers/Microsoft.Kusto/clusters/${FINOPS_HUB_CLUSTER_NAME}"; return 0; fi
  query="Resources | where type =~ 'microsoft.kusto/clusters' | where tostring(properties.uri) =~ '${base_uri}' | project name, resourceGroup, id"; body="$(jq -nc --arg sub "$SUB" --arg query "$query" '{subscriptions:[$sub],query:$query}')"
  count="$(az rest --method post --uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' --body "$body" --query 'length(data)' -o tsv)"; [ "$count" = "1" ] || fail "Expected one FinOps Hub ADX cluster for $base_uri; found $count."
  resolved="$(az rest --method post --uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' --body "$body" --query 'data[0].[name,resourceGroup,id]' -o tsv)"; read -r FINOPS_HUB_CLUSTER_NAME FINOPS_HUB_CLUSTER_RESOURCE_GROUP FINOPS_HUB_CLUSTER_RESOURCE_ID <<EOF_RESOLVED
$resolved
EOF_RESOLVED
}
put_kusto_assignment(){ local principal_id="$1" label="$2" name body path url; [ -n "$principal_id" ] || { log "Skipping ADX assignment for $label; no principal ID."; return 0; }; name="$(python3 -c 'import sys,uuid; print(uuid.uuid5(uuid.NAMESPACE_URL, sys.argv[1]+"/"+sys.argv[2]+"/AllDatabasesViewer"))' "$FINOPS_HUB_CLUSTER_RESOURCE_ID" "$principal_id")"; body="$(jq -nc --arg pid "$principal_id" --arg tid "$(az account show --query tenantId -o tsv)" '{properties:{principalType:"App",principalId:$pid,tenantId:$tid,role:"AllDatabasesViewer"}}')"; path="$(json_body_file "adx-${name}" "$body")"; url="https://management.azure.com${FINOPS_HUB_CLUSTER_RESOURCE_ID}/principalAssignments/${name}?api-version=2024-04-13"; dry "PUT ADX AllDatabasesViewer for $label" && return 0; log "PUT ADX AllDatabasesViewer for $label"; az rest -m PUT --url "$url" --body "@${path}" --headers 'Content-Type=application/json' -o none; }
verify_kusto_assignment(){ local principal_id="$1" label="$2" n attempt; [ -n "$principal_id" ] || return 0; dry "verify ADX assignment for $label" && return 0; for attempt in $(seq 1 "$ADX_ASSIGNMENT_POLL_ATTEMPTS"); do n="$(az rest --method get --url "https://management.azure.com${FINOPS_HUB_CLUSTER_RESOURCE_ID}/principalAssignments?api-version=2024-04-13" --query "length(value[?properties.principalId=='${principal_id}' && properties.role=='AllDatabasesViewer'])" -o tsv 2>/dev/null || echo 0)"; [ "${n:-0}" != "0" ] && return 0; [ "$attempt" -lt "$ADX_ASSIGNMENT_POLL_ATTEMPTS" ] && sleep "$ADX_ASSIGNMENT_POLL_SECONDS"; done; fail "ADX AllDatabasesViewer assignment missing for $label."; }
reconcile_kusto_connector(){ local expected_uri="$1" conn_name="finops-hub-kusto" existing ds body; dry "reconcile connector ${conn_name} dataSource" && return 0; existing="$(az rest -m GET --url "${ARM_BASE}/connectors/${conn_name}?api-version=${API_VERSION}" -o json 2>/dev/null || echo '{}')"; ds="$(printf '%s' "$existing" | jq -r '.properties.dataSource // empty')"; if [ "$ds" = "$expected_uri" ]; then log "Connector ${conn_name} dataSource OK: ${ds}"; return 0; fi; log "Connector ${conn_name} dataSource mismatch: got '${ds:-null}', expected '${expected_uri}'"; body="$(jq -nc --arg uri "$expected_uri" '{properties:{dataConnectorType:"Kusto",dataSource:$uri,identity:"system"}}')"; arm_put_connector "$conn_name" "$body"; log "Connector ${conn_name} dataSource corrected to ${expected_uri}"; }
if [ -n "${FINOPS_HUB_CLUSTER_URI:-}" ]; then resolve_finops_hub_cluster; put_kusto_assignment "$UAMI_PRINCIPAL_ID" 'user-assigned managed identity'; put_kusto_assignment "$SYSTEM_PRINCIPAL_ID" 'system-assigned managed identity'; verify_kusto_assignment "$UAMI_PRINCIPAL_ID" 'user-assigned managed identity'; verify_kusto_assignment "$SYSTEM_PRINCIPAL_ID" 'system-assigned managed identity'; reconcile_kusto_connector "$FINOPS_HUB_CLUSTER_URI"; fi
log 'Extras applied.'
