#!/usr/bin/env bash
# Shared gate for public MCP (Gateway API + RHCL). Sourced by bootstrap and verify.
# Default: no public listener — see docs/guides/mcp-gateway-networking.md.

mcp_public_gateway_enabled() {
  if [[ "${ENABLE_MCP_GATEWAY_PUBLIC:-false}" == "true" ]]; then
    return 0
  fi
  # Legacy: SKIP_MCP_GATEWAY=false enabled public MCP before the default flipped.
  if [[ "${SKIP_MCP_GATEWAY:-}" == "false" ]]; then
    return 0
  fi
  return 1
}
