#!/usr/bin/env bash
# telemetry.sh — anonymous usage tracking for recipe popularity.
#
# Sends a single custom event to App Insights. Non-blocking, best-effort.
# No PII is collected — only recipe name, action, region, OS, and coarse booleans.
#
# Usage (sourced by other scripts):
#   source "$(dirname "$0")/telemetry.sh"
#   send_telemetry "deploy" "finops-hub" "westus3" "true" "false" "true" "false" "deploy"

_TELEMETRY_IKEY="f10eff7f-b995-4c41-8347-90f0f55d5969"
_TELEMETRY_ENDPOINT="https://eastus2-3.in.applicationinsights.azure.com/v2/track"

send_telemetry() {
  [[ "${_NO_TELEMETRY:-}" == "true" ]] && return 0

  local action="${1:-unknown}"
  local recipe="${2:-unknown}"
  local region="${3:-unknown}"
  local used_recipe_flag="${4:-false}"
  local used_legacy_positional="${5:-false}"
  local has_cluster_uri="${6:-false}"
  local has_cluster_resource_id="${7:-false}"
  local mode="${8:-deploy}"
  local os_type
  os_type="$(uname -s 2>/dev/null || echo unknown)"

  # Fire and forget — never block or fail the main script
  (curl -s -o /dev/null -m 5 -X POST "$_TELEMETRY_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "[{
      \"name\": \"Microsoft.ApplicationInsights.Event\",
      \"time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"iKey\": \"${_TELEMETRY_IKEY}\",
      \"data\": {
        \"baseType\": \"EventData\",
        \"baseData\": {
          \"name\": \"recipe-usage\",
          \"properties\": {
            \"action\": \"${action}\",
            \"recipe\": \"${recipe}\",
            \"region\": \"${region}\",
            \"os\": \"${os_type}\",
            \"used_recipe_flag\": \"${used_recipe_flag}\",
            \"used_legacy_positional\": \"${used_legacy_positional}\",
            \"has_cluster_uri\": \"${has_cluster_uri}\",
            \"has_cluster_resource_id\": \"${has_cluster_resource_id}\",
            \"mode\": \"${mode}\"
          }
        }
      }
    }]" 2>/dev/null &) 2>/dev/null
}
