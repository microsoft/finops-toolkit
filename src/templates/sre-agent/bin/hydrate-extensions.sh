#!/usr/bin/env bash
# hydrate-extensions.sh
#
# Applies tools, subagents, and skills via srectl from a canonical recipe config
# directory. Intended for constrained tenants where ARM extension child resources
# are blocked during template deployment.
#
# Usage:
#   ./hydrate-extensions.sh <subscription-id> <resource-group> <agent-name> <config-dir>

set -euo pipefail

SUB="${1:?subscription-id required}"
RG="${2:?resource-group required}"
AGENT="${3:?agent-name required}"
CONFIG_DIR="${4:?config-dir required}"

[[ -d "$CONFIG_DIR" ]] || { echo "config directory not found: $CONFIG_DIR" >&2; exit 1; }
[[ -f "$CONFIG_DIR/agent.json" ]] || { echo "agent.json not found in: $CONFIG_DIR" >&2; exit 1; }
CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd)"

command -v az >/dev/null || { echo "az is required" >&2; exit 1; }
command -v srectl >/dev/null || { echo "srectl is required" >&2; exit 1; }

API_VERSION="2025-05-01-preview"
ARM_BASE="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/agents/${AGENT}"

AGENT_ENDPOINT=$(az rest -m GET --url "${ARM_BASE}?api-version=${API_VERSION}" --query properties.agentEndpoint -o tsv 2>/dev/null || true)
if [[ -z "$AGENT_ENDPOINT" || "$AGENT_ENDPOINT" == "null" ]]; then
  echo "Could not resolve agent endpoint for ${AGENT} in ${RG}." >&2
  exit 1
fi

TOOLS_DIR="${CONFIG_DIR}/config/tools"
SUBAGENTS_DIR="${CONFIG_DIR}/config/subagents"
SKILLS_DIR="${CONFIG_DIR}/config/skills"
SCHEDULED_TASKS_DIR="${CONFIG_DIR}/automations/scheduled-tasks"

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/srectl-hydrate.XXXXXX")
cleanup() { rm -rf "$WORKDIR" 2>/dev/null; }
trap cleanup EXIT

mkdir -p "${WORKDIR}/skills"
if [[ -d "$SKILLS_DIR" ]]; then
  cp -R "${SKILLS_DIR}/." "${WORKDIR}/skills/" 2>/dev/null || true
fi

(
  cd "$WORKDIR"
  srectl init --resource-url "$AGENT_ENDPOINT" --quiet >/dev/null
)

echo "Hydrating extension resources with srectl..."

failed=0
tools_total=0
tools_applied=0
subagents_total=0
subagents_applied=0
skills_total=0
skills_applied=0
scheduled_total=0
scheduled_applied=0

if [[ -d "$TOOLS_DIR" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    tools_total=$((tools_total + 1))
    rel="${file#${CONFIG_DIR}/}"
    echo "  tool: ${rel}"
    if (
      cd "$WORKDIR"
      srectl apply-yaml --file "$file" --quiet
    ); then
      tools_applied=$((tools_applied + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(find "$TOOLS_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
fi

if [[ -d "$SUBAGENTS_DIR" ]]; then
  subagent_retry_files=""
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    subagents_total=$((subagents_total + 1))
    rel="${file#${CONFIG_DIR}/}"
    echo "  subagent: ${rel}"
    if (
      cd "$WORKDIR"
      srectl apply-yaml --file "$file" --quiet
    ); then
      subagents_applied=$((subagents_applied + 1))
    else
      subagent_retry_files="${subagent_retry_files}${file}"$'\n'
    fi
  done < <(find "$SUBAGENTS_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)

  if [[ -n "$subagent_retry_files" ]]; then
    echo "  retrying subagents with dependency ordering..."
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      rel="${file#${CONFIG_DIR}/}"
      echo "  subagent (retry): ${rel}"
      if (
        cd "$WORKDIR"
        srectl apply-yaml --file "$file" --quiet
      ); then
        subagents_applied=$((subagents_applied + 1))
      else
        failed=$((failed + 1))
      fi
    done <<< "$subagent_retry_files"
  fi
fi

if [[ -d "${WORKDIR}/skills" ]]; then
  for skill_dir in "${WORKDIR}"/skills/*; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    skill_name=$(basename "$skill_dir")
    skills_total=$((skills_total + 1))
    echo "  skill: ${skill_name}"
    if (
      cd "$WORKDIR"
      srectl skill apply --name "$skill_name" --quiet
    ); then
      skills_applied=$((skills_applied + 1))
    else
      failed=$((failed + 1))
    fi
  done
fi

if [[ -d "$SCHEDULED_TASKS_DIR" ]]; then
  EXISTING_TASK_NAMES=$(
    (
      cd "$WORKDIR"
      srectl scheduledtask list --quiet 2>&1 || true
    ) | tr -d '\000' | sed -n 's/.*\[[0-9][0-9]*\] \([A-Za-z0-9._-][A-Za-z0-9._-]*\).*/\1/p' | sort -u
  )

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    scheduled_total=$((scheduled_total + 1))
    rel="${file#${CONFIG_DIR}/}"
    task_name=$(awk -F': *' '/^[[:space:]]*name:[[:space:]]*/{gsub(/"/, "", $2); print $2; exit}' "$file" | tr -d '\r' | xargs)
    if [[ -n "$task_name" ]] && grep -Fxq "$task_name" <<< "$EXISTING_TASK_NAMES"; then
      echo "  scheduled-task: ${rel} (exists, skipping)"
      scheduled_applied=$((scheduled_applied + 1))
      continue
    fi
    echo "  scheduled-task: ${rel}"
    if (
      cd "$WORKDIR"
      srectl scheduledtask apply --file "$file" --quiet
    ); then
      scheduled_applied=$((scheduled_applied + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(find "$SCHEDULED_TASKS_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)
fi

echo
echo "Hydration summary:"
echo "  tools:     ${tools_applied}/${tools_total}"
echo "  subagents: ${subagents_applied}/${subagents_total}"
echo "  skills:    ${skills_applied}/${skills_total}"
echo "  scheduled: ${scheduled_applied}/${scheduled_total}"

if [[ "$failed" -gt 0 ]]; then
  echo "Hydration failed: ${failed} item(s) could not be applied." >&2
  exit 1
fi
