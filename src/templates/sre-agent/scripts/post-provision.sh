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

main() {
  local endpoint
  endpoint="$(resolve_endpoint)"

  ensure_srectl

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
