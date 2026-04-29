#!/usr/bin/env bash
# Post-provision: configure SRE Agent with repo-defined skills, agents, tools,
# and scheduled tasks via srectl.
# OAuth-based Outlook and Teams connectors are intentionally excluded here:
# Microsoft Learn currently documents them as interactive portal setup only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRECTL_SOURCE="https://pkgs.dev.azure.com/msazure/One/_packaging/SREAgentCli/nuget/v3/index.json"

log() { printf '[post-provision] %s\n' "$*"; }
fail() { printf '[post-provision] ERROR: %s\n' "$*" >&2; exit 1; }

# Resolve SRE Agent endpoint from azd outputs or environment
resolve_endpoint() {
  local ep="${SRE_AGENT_ENDPOINT:-}"
  if [ -z "$ep" ] && command -v azd >/dev/null 2>&1; then
    ep="$(azd env get-value SRE_AGENT_ENDPOINT --no-prompt 2>/dev/null || true)"
  fi
  [ -n "$ep" ] && ! echo "$ep" | grep -q '^ERROR' || fail "SRE_AGENT_ENDPOINT is required."
  echo "$ep"
}

# Ensure srectl is installed
ensure_srectl() {
  if command -v srectl >/dev/null 2>&1 && srectl --version >/dev/null 2>&1; then return; fi
  command -v dotnet >/dev/null 2>&1 || fail ".NET SDK required for srectl."
  log "Installing srectl..."
  dotnet tool install --global sreagent.cli --add-source "$SRECTL_SOURCE" >/dev/null
  command -v srectl >/dev/null 2>&1 || fail "srectl installation failed."
}

# Apply agents in dependency order (agents without handoffs first, then agents with handoffs)
apply_agents() {
  local dir="$REPO_ROOT/sre-config/agents"
  [ -d "$dir" ] || return 0

  # Pass 1: agents without handoffs (safe to create in any order)
  for f in "$dir"/*.yaml "$dir"/*.yml; do
    [ -f "$f" ] || continue
    if ! grep -q '^  handoffs:' "$f" 2>/dev/null; then
      log "Applying agent: $(basename "$f")"
      srectl apply-yaml --file "$f"
    fi
  done

  # Pass 2: agents with handoffs (their targets now exist)
  for f in "$dir"/*.yaml "$dir"/*.yml; do
    [ -f "$f" ] || continue
    if grep -q '^  handoffs:' "$f" 2>/dev/null; then
      log "Applying agent: $(basename "$f")"
      srectl apply-yaml --file "$f"
    fi
  done
}

# Apply skills (srectl skill apply reads from workspace/skills/)
apply_skills() {
  local skills_dir="$REPO_ROOT/sre-config/skills"
  [ -d "$skills_dir" ] || return 0

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
    srectl skill apply --name "$name"
  done
}

# Apply tools
apply_tools() {
  local dir="$REPO_ROOT/tools"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.yaml "$dir"/*.yml; do
    [ -f "$f" ] || continue
    log "Applying tool: $(basename "$f")"
    srectl apply-yaml --file "$f"
  done
}

# Upload knowledge documents for onboarding and investigations
apply_knowledge() {
  local dir="$REPO_ROOT/sre-config/knowledge"
  [ -d "$dir" ] || return 0
  log "Uploading knowledge documents from sre-config/knowledge..."
  srectl doc upload --file "$dir"
}

# Apply scheduled tasks using srectl scheduledtask apply (idempotent upsert)
apply_scheduled_tasks() {
  local tasks_dir="$REPO_ROOT/sre-config/scheduled-tasks"
  [ -d "$tasks_dir" ] || return 0
  for f in "$tasks_dir"/*.yaml "$tasks_dir"/*.yml; do
    [ -f "$f" ] || continue
    log "Applying scheduled task: $(basename "$f")"
    srectl scheduledtask apply --file "$f" --quiet 2>&1 || log "WARNING: Failed to apply $(basename "$f")"
  done
}

# Add repo connector (idempotent — srectl handles existing)
add_repo_connector() {
  log "Adding finops-toolkit repository connector..."
  srectl repo add --name finops-toolkit --url https://github.com/microsoft/finops-toolkit 2>&1 || \
    log "Repository connector may already exist."
}

# Ensure the UAMI has the custom permissions needed by Python tools.
# Creates a custom role with Microsoft.Resources/checkZonePeers/action
# (not in the built-in Reader role) and assigns it to the UAMI.
# For multi-subscription capacity management, deploy this custom role at the
# management group level so the agent can map zones across all child subscriptions.
ensure_custom_permissions() {
  local sub_id rg_name uami_principal_id role_name role_exists
  sub_id="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null)}"
  rg_name="${AZURE_RESOURCE_GROUP:-$(azd env get-value AZURE_RESOURCE_GROUP --no-prompt 2>/dev/null || true)}"

  if [ -z "$sub_id" ] || [ -z "$rg_name" ]; then
    log "WARNING: Cannot determine subscription or resource group — skipping custom permissions."
    return 0
  fi

  # Find the UAMI principal ID from the resource group
  uami_principal_id="$(az identity list --resource-group "$rg_name" --query '[0].principalId' -o tsv 2>/dev/null || true)"
  if [ -z "$uami_principal_id" ]; then
    log "WARNING: No managed identity found in $rg_name — skipping custom permissions."
    return 0
  fi

  role_name="FinOps SRE Zone Peers Reader"
  scope="/subscriptions/${sub_id}"

  # Create custom role (idempotent — update if exists)
  role_exists="$(az role definition list --name "$role_name" --scope "$scope" --query 'length(@)' -o tsv 2>/dev/null || echo 0)"
  if [ "$role_exists" = "0" ]; then
    log "Creating custom role: $role_name"
    az role definition create --role-definition "{
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
  az role assignment create \
    --assignee-object-id "$uami_principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "$role_name" \
    --scope "$scope" \
    --output none 2>&1 || log "WARNING: Role assignment may already exist or require elevated permissions."
}

main() {
  local endpoint
  endpoint="$(resolve_endpoint)"

  ensure_srectl

  # Grant the UAMI any permissions that require custom role definitions.
  # This is done in post-provision rather than Bicep because custom role
  # definitions require management-group-level assignableScopes for multi-sub
  # capacity management, which Bicep subscription-scoped deployments cannot express.
  ensure_custom_permissions

  # Work from a temp directory so srectl init doesn't pollute the repo
  local workdir
  workdir="$(mktemp -d)"
  trap "rm -rf '$workdir'" EXIT
  cd "$workdir"

  log "Initializing srectl..."
  srectl init --resource-url "$endpoint"

  apply_skills
  apply_agents
  apply_tools
  apply_knowledge
  apply_scheduled_tasks
  add_repo_connector

  log "Post-provision complete."
}

main "$@"
