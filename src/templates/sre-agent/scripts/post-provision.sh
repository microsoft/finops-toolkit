#!/usr/bin/env bash
# Post-provision: configure SRE Agent with repo-defined skills, agents, tools,
# and scheduled tasks via srectl.
# OAuth-based Outlook and Teams connectors are intentionally excluded here:
# Microsoft Learn currently documents them as interactive portal setup only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRECTL_SOURCE="https://pkgs.dev.azure.com/msazure/One/_packaging/SREAgentCli/nuget/v3/index.json"
DRY_RUN=0

log() { printf '[post-provision] %s\n' "$*"; }
fail() { printf '[post-provision] ERROR: %s\n' "$*" >&2; exit 1; }
dry_run_log() { printf '[DRY-RUN] %s\n' "$*"; }

run_cmd() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "would run: $*"
    return 0
  fi

  "$@"
}

run_output_cmd() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "would run: $*" >&2
    return 0
  fi

  "$@"
}

# Resolve SRE Agent endpoint from azd outputs or environment
resolve_endpoint() {
  local ep="${SRE_AGENT_ENDPOINT:-}"
  if [ -z "$ep" ] && command -v azd >/dev/null 2>&1; then
    ep="$(azd env get-value SRE_AGENT_ENDPOINT --no-prompt 2>/dev/null || true)"
  fi
  [ -n "$ep" ] && ! echo "$ep" | grep -q '^ERROR' || fail "SRE_AGENT_ENDPOINT is required."
  echo "$ep"
}

resolve_subscription_id() {
  local sub_id="${AZURE_SUBSCRIPTION_ID:-}"
  if [ -z "$sub_id" ]; then
    sub_id="$(run_output_cmd az account show --query id -o tsv 2>/dev/null || true)"
  fi

  [ -n "$sub_id" ] && ! echo "$sub_id" | grep -q '^ERROR' || fail "AZURE_SUBSCRIPTION_ID is required for RBAC assignment."
  echo "$sub_id"
}

resolve_identity_principal_id() {
  local principal_id="${IDENTITY_PRINCIPAL_ID:-}"
  if [ -z "$principal_id" ] && command -v azd >/dev/null 2>&1; then
    principal_id="$(azd env get-value IDENTITY_PRINCIPAL_ID --no-prompt 2>/dev/null || true)"
  fi

  [ -n "$principal_id" ] && ! echo "$principal_id" | grep -q '^ERROR' || fail "IDENTITY_PRINCIPAL_ID is required for RBAC assignment. Run azd env refresh after provisioning if this output is missing."
  echo "$principal_id"
}

assign_role_if_missing() {
  local principal_id="$1"
  local role_id="$2"
  local role_name="$3"
  local scope="$4"
  local existing

  existing="$(run_output_cmd az role assignment list --assignee "$principal_id" --role "$role_id" --scope "$scope" --query 'length(@)' -o tsv 2>/dev/null)" || fail "Failed to check $role_name assignment for $principal_id at $scope."
  if [ "${existing:-0}" != "0" ]; then
    log "$role_name already assigned to UAMI ($principal_id) at subscription scope."
    return 0
  fi

  log "Assigning $role_name to UAMI ($principal_id) at subscription scope..."
  run_cmd az role assignment create \
    --assignee-object-id "$principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "$role_id" \
    --scope "$scope" \
    --output none || fail "Failed to assign $role_name to $principal_id at $scope."
}

# Ensure srectl is installed
ensure_srectl() {
  if command -v srectl >/dev/null 2>&1 && run_cmd srectl --version >/dev/null 2>&1; then return; fi
  command -v dotnet >/dev/null 2>&1 || fail ".NET SDK required for srectl."
  log "Installing srectl..."
  dotnet tool install --global sreagent.cli --add-source "$SRECTL_SOURCE" >/dev/null
  command -v srectl >/dev/null 2>&1 || fail "srectl installation failed."
}

# Apply agents — copies to workspace, multiple passes to resolve handoff deps.
apply_agents() {
  local dir="$REPO_ROOT/sre-config/agents"
  [ -d "$dir" ] || return 0

  if [ "${DRY_RUN:-0}" = "1" ]; then
    for f in "$dir"/*.yaml "$dir"/*.yml; do
      [ -f "$f" ] || continue
      local name
      name="$(basename "$f")"
      name="${name%.yaml}"
      name="${name%.yml}"
      dry_run_log "Would apply agent: $name"
    done
    return 0
  fi

  # Copy agent YAMLs into srectl workspace
  cp "$dir"/*.yaml "$dir"/*.yml agents/ 2>/dev/null || true

  local max_passes=3
  local pass=1
  local pending=()
  local failed=()

  for f in "$dir"/*.yaml "$dir"/*.yml; do
    [ -f "$f" ] || continue
    pending+=("$(basename "$f" .yaml)")
  done

  while [ "$pass" -le "$max_passes" ] && [ "${#pending[@]}" -gt 0 ]; do
    log "Agent apply pass $pass (${#pending[@]} remaining)..."
    failed=()
    for name in "${pending[@]}"; do
      log "Applying agent: $name"
      if run_cmd srectl agent apply --name "$name" --quiet 2>&1; then
        true
      else
        log "  Deferred: $name (will retry)"
        failed+=("$name")
      fi
    done
    pending=("${failed[@]+"${failed[@]}"}")
    pass=$((pass + 1))
  done

  if [ "${#pending[@]}" -gt 0 ]; then
    for name in "${pending[@]}"; do
      log "WARNING: Failed to apply agent after $max_passes passes: $name"
    done
  fi
}

# Apply skills (srectl skill apply reads from workspace/skills/)
apply_skills() {
  local skills_dir="$REPO_ROOT/sre-config/skills"
  [ -d "$skills_dir" ] || return 0

  if [ "${DRY_RUN:-0}" = "1" ]; then
    for skill in "$skills_dir"/*/; do
      [ -d "$skill" ] || continue
      local name
      name="$(basename "$skill")"
      dry_run_log "Would apply skill: $name"
    done
    return 0
  fi

  # Copy resolved skills into srectl workspace (dereference symlinks, text only)
  rsync -rL \
    --exclude='docs-mslearn' \
    --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.ico' --exclude='*.svg' \
    "$skills_dir/" "skills/"

  for skill in skills/*/; do
    [ -d "$skill" ] || continue
    local name
    name="$(basename "$skill")"
    log "Applying skill: $name"
    run_cmd srectl skill apply --name "$name"
  done
}

# Apply tools — copies tool YAMLs into the srectl workspace tools/ dir
# then applies each by name (srectl tool apply --name reads from the workspace).
apply_tools() {
  local dir="$REPO_ROOT/tools"
  [ -d "$dir" ] || return 0
  if [ "${DRY_RUN:-0}" = "1" ]; then
    for f in "$dir"/*.yaml "$dir"/*.yml; do
      [ -f "$f" ] || continue
      local name
      name="$(basename "$f")"
      name="${name%.yaml}"
      name="${name%.yml}"
      dry_run_log "Would apply tool: $name"
    done
    return 0
  fi

  cp "$dir"/*.yaml "$dir"/*.yml tools/ 2>/dev/null || true
  for f in "$dir"/*.yaml "$dir"/*.yml; do
    [ -f "$f" ] || continue
    local name
    name="$(basename "$f" .yaml)"
    name="$(echo "$name" | sed 's/\.yml$//')"
    log "Applying tool: $name"
    run_cmd srectl tool apply --name "$name" --quiet 2>&1 || log "WARNING: Failed to apply tool $name"
  done
}

# Upload knowledge documents for onboarding and investigations
apply_knowledge() {
  local dir="$REPO_ROOT/sre-config/knowledge"
  [ -d "$dir" ] || return 0
  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "Would upload knowledge from sre-config/knowledge"
    return 0
  fi

  log "Uploading knowledge documents from sre-config/knowledge..."
  run_cmd srectl doc upload --file "$dir"
}

# Apply scheduled tasks using srectl scheduledtask apply (idempotent upsert)
apply_scheduled_tasks() {
  local tasks_dir="$REPO_ROOT/sre-config/scheduled-tasks"
  [ -d "$tasks_dir" ] || return 0
  for f in "$tasks_dir"/*.yaml "$tasks_dir"/*.yml; do
    [ -f "$f" ] || continue
    if [ "${DRY_RUN:-0}" = "1" ]; then
      dry_run_log "Would apply scheduled task: $(basename "$f")"
      continue
    fi
    log "Applying scheduled task: $(basename "$f")"
    run_cmd srectl scheduledtask apply --file "$f" --quiet 2>&1 || log "WARNING: Failed to apply $(basename "$f")"
  done
}

# Repo connector intentionally removed — the agent was searching the full
# codebase and attempting git commits. Knowledge docs provide the reference
# material the agent needs without repo access.
# add_repo_connector() { ... }

# Ensure the UAMI has the custom permissions needed by Python tools.
# Creates a custom role with Microsoft.Resources/checkZonePeers/action
# (not in the built-in Reader role) and assigns it to the UAMI.
# For multi-subscription capacity management, deploy this custom role at the
# management group level so the agent can map zones across all child subscriptions.
ensure_custom_permissions() {
  local sub_id uami_principal_id role_name role_exists
  sub_id="$(resolve_subscription_id)"
  uami_principal_id="$(resolve_identity_principal_id)"

  role_name="FinOps SRE Zone Peers Reader"
  scope="/subscriptions/${sub_id}"

  # Create custom role (idempotent — update if exists)
  role_exists="$(run_output_cmd az role definition list --name "$role_name" --scope "$scope" --query 'length(@)' -o tsv 2>/dev/null || echo 0)"
  if [ "$role_exists" = "0" ]; then
    log "Creating custom role: $role_name"
    run_cmd az role definition create --role-definition "{
      \"Name\": \"${role_name}\",
      \"Description\": \"Allows checking availability zone peer mappings across subscriptions. Used by the zone-mapping Python tool.\",
      \"Actions\": [\"Microsoft.Resources/checkZonePeers/action\"],
      \"AssignableScopes\": [\"${scope}\"]
    }" --output none 2>&1 || log "WARNING: Failed to create custom role (may require elevated permissions)."
  else
    log "Custom role $role_name already exists."
  fi

  # Assign the custom role to the UAMI (idempotent — az handles existing assignments)
  log "Assigning $role_name to UAMI ($uami_principal_id)"
  run_cmd az role assignment create \
    --assignee-object-id "$uami_principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "$role_name" \
    --scope "$scope" \
    --output none 2>&1 || log "WARNING: Role assignment may already exist or require elevated permissions."
}

# Assign subscription-level RBAC (Reader + Monitoring Contributor) to the UAMI.
# Moved from Bicep subscription-scoped deployment to post-provision so the
# template can be resource-group scoped.
assign_subscription_rbac() {
  local sub_id uami_principal_id
  sub_id="$(resolve_subscription_id)"
  uami_principal_id="$(resolve_identity_principal_id)"

  local scope="/subscriptions/${sub_id}"

  assign_role_if_missing "$uami_principal_id" "acdd72a7-3385-48ef-bd42-f606fba81ae7" "Reader" "$scope"
  assign_role_if_missing "$uami_principal_id" "749f88d5-cbae-40b8-bcfc-e573ddc772fa" "Monitoring Contributor" "$scope"
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --dry-run)
        DRY_RUN=1
        ;;
      *)
        fail "Unknown argument: $arg"
        ;;
    esac
  done

  local endpoint
  if [ "${DRY_RUN:-0}" = "1" ]; then
    endpoint="${SRE_AGENT_ENDPOINT:-https://dry-run.invalid}"
    dry_run_log "Dry-run mode enabled; skipping endpoint validation."
  else
    endpoint="$(resolve_endpoint)"
  fi

  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "Skipping srectl installation check."
  else
    ensure_srectl
  fi

  # Grant the UAMI any permissions that require custom role definitions.
  # This is done in post-provision rather than Bicep because custom role
  # definitions require management-group-level assignableScopes for multi-sub
  # capacity management, which Bicep subscription-scoped deployments cannot express.
  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "Skipping custom Azure permission checks."
    dry_run_log "Skipping subscription RBAC assignments."
  else
    ensure_custom_permissions
    assign_subscription_rbac
  fi

  # Work from a temp directory so srectl init doesn't pollute the repo
  local workdir
  workdir="$(mktemp -d)"
  trap "rm -rf '$workdir'" EXIT
  cd "$workdir"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    dry_run_log "Skipping srectl init for endpoint: $endpoint"
  else
    log "Initializing srectl..."
    run_cmd srectl init --resource-url "$endpoint"
  fi

  apply_skills
  apply_agents
  apply_tools
  apply_knowledge
  apply_scheduled_tasks

  log "Post-provision complete."
}

main "$@"
