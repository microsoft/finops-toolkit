#!/usr/bin/env bash
# check-prerequisites.sh — verify required tools are installed
# Source from any script: source "$(dirname "$0")/check-prerequisites.sh"

check_prerequisites() {
  local missing=0

  for cmd in az jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "  ❌ Missing: $cmd" >&2
      missing=$((missing + 1))
    fi
  done

  if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
    echo "  ❌ Missing: python3 (needed for YAML processing)" >&2
    missing=$((missing + 1))
  else
    local py=$(command -v python3 || command -v python)
    if ! "$py" -c "import yaml" 2>/dev/null; then
      echo "  ❌ Missing: PyYAML — install: pip install pyyaml" >&2
      missing=$((missing + 1))
    fi
  fi

  if ! command -v curl &>/dev/null; then
    echo "  ❌ Missing: curl" >&2
    missing=$((missing + 1))
  fi

  if [[ $missing -gt 0 ]]; then
    echo "  $missing prerequisite(s) missing. See README for install guide." >&2
    return 1
  fi
  return 0
}
