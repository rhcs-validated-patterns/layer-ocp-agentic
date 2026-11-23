#!/usr/bin/env bash
set -euo pipefail

: "${TFVARS:?TFVARS required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=mcp-gateway-lib.sh
source "${SCRIPT_DIR}/mcp-gateway-lib.sh"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() {
  log "FAIL: $*"
  exit 1
}

agentic_json() {
  local key=$1
  local cluster_dir
  cluster_dir="$(dirname "${TFVARS}")"
  if [[ -f "${cluster_dir}/agentic.json" ]]; then
    jq -r --arg k "${key}" '.[$k] // empty' "${cluster_dir}/agentic.json"
    return 0
  fi
  terraform -chdir="${ROOT_DIR}/terraform" output -json agentic 2>/dev/null | jq -r --arg k "${key}" '.[$k] // empty' || true
}

command -v oc >/dev/null || die "oc required"
oc whoami >/dev/null 2>&1 || die "API unreachable"

backend="$(agentic_json llm_backend)"
[[ -z "${backend}" ]] && backend="azure"

check_csv() {
  local ns=$1 pkg=$2
  phase="$(oc get csv -n "${ns}" 2>/dev/null | awk -v p="${pkg}" '$1 ~ p {print $NF; exit}')"
  [[ "${phase}" == "Succeeded" ]] || die "CSV ${pkg} in ${ns} not Succeeded (${phase:-missing})"
  log "OK ${pkg}"
}

check_csv openshift-cluster-observability-operator cluster-observability-operator
check_csv openshift-lightspeed lightspeed-operator
check_csv kuadrant-system rhcl-operator

enabled="$(oc get uiplugin monitoring -o jsonpath='{.spec.monitoring.perses.enabled}' 2>/dev/null || true)"
[[ "${enabled}" == "true" ]] || die "Perses UIPlugin not enabled"

lightspeed_es_name="$(agentic_json lightspeed_secret_name)"
[[ -z "${lightspeed_es_name}" ]] && lightspeed_es_name="lightspeed-azure-openai"

es="$(oc get externalsecret "${lightspeed_es_name}" -n openshift-lightspeed -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${es}" == "True" ]] || die "ExternalSecret ${lightspeed_es_name} not Ready"

oc get olsconfig cluster -o name >/dev/null 2>&1 || die "OLSConfig cluster missing"

if [[ "${backend}" == "aws" ]]; then
  oc get secret "${lightspeed_es_name}" -n openshift-lightspeed -o jsonpath='{.data.aws_access_key_id}' >/dev/null 2>&1 \
    || die "Lightspeed secret missing aws_access_key_id (re-run make cluster.<profile>.apply)"
fi

oc get kuadrant kuadrant -n kuadrant-system >/dev/null 2>&1 || log "WARN Kuadrant not Ready yet (RHCL still reconciling)"

phase="$(oc get olsconfig cluster -o jsonpath='{.status.conditions[?(@.type=="ResourceReconciliation")].status}' 2>/dev/null || true)"
if [[ -n "${phase}" ]]; then
  [[ "${phase}" == "True" ]] || die "OLSConfig ResourceReconciliation not True ($(oc get olsconfig cluster -o jsonpath='{.status.conditions[?(@.type=="ResourceReconciliation")].message}' 2>/dev/null || true))"
fi

overall="$(oc get olsconfig cluster -o jsonpath='{.status.overallStatus}' 2>/dev/null || true)"
api_msg="$(oc get olsconfig cluster -o jsonpath='{.status.conditions[?(@.type=="ApiReady")].message}' 2>/dev/null || true)"
if [[ "${overall}" != "Ready" ]]; then
  log "WARN OLSConfig overallStatus=${overall:-unknown} (ApiReady: ${api_msg:-n/a})"
fi

if mcp_public_gateway_enabled; then
  if oc get mcpgatewayextensions mcp-gateway -n mcp-gateway-system >/dev/null 2>&1; then
    ready="$(oc get mcpgatewayextensions mcp-gateway -n mcp-gateway-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${ready}" == "True" ]]; then
      log "OK MCPGatewayExtension"
    else
      die "MCPGatewayExtension not Ready (${ready:-unknown})"
    fi
    if [[ -n "$(agentic_json mcp_oauth_issuer_url)" ]] && oc get authpolicy mcp-gateway-oidc -n openshift-ingress >/dev/null 2>&1; then
      domain="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
      if [[ -n "${domain}" ]]; then
        code="$(curl -kfsS -o /dev/null -w '%{http_code}' "https://mcp.${domain}/status" 2>/dev/null || echo 000)"
        if [[ "${code}" == "401" ]]; then
          log "OK MCP gateway OIDC (anonymous /status → 401)"
        else
          log "WARN MCP /status returned ${code} (expected 401 without Bearer token)"
        fi
      fi
    fi
  else
    die "ENABLE_MCP_GATEWAY_PUBLIC=true but MCPGatewayExtension missing — re-run bootstrap"
  fi
else
  log "OK public MCP gateway not expected (default off; see mcp-gateway-networking.md)"
fi

log "Agentic verify passed (llm_backend=${backend})"
