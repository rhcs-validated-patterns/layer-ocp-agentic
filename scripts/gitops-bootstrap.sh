#!/usr/bin/env bash
# Install agentic operators and apply OLSConfig after Azure OpenAI + ESO secrets exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=mcp-gateway-lib.sh
source "${SCRIPT_DIR}/mcp-gateway-lib.sh"
TF_DIR="${ROOT_DIR}/terraform"
GITOPS_DIR="${ROOT_DIR}/gitops"
GITOPS_REPO="${GITOPS_REPO:-https://github.com/rhcs-validated-patterns/layer-ocp-agentic.git}"
GITOPS_REVISION="${GITOPS_REVISION:-main}"
KUBECONFIG="${KUBECONFIG:-${ROOT_DIR}/.kube/config}"
GITOPS_DRY_RUN="${GITOPS_DRY_RUN:-}"
: "${TFVARS:?TFVARS required}"

OVERLAY="${GITOPS_OVERLAY:-public}"
OVERLAY_DIR="${GITOPS_DIR}/overlays/${OVERLAY}"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() {
  log "ERROR: $*"
  exit 1
}

tf_raw() {
  terraform -chdir="${TF_DIR}" output -raw "$1" 2>/dev/null || true
}

wait_csv() {
  local ns=$1 name=$2
  log "Waiting for CSV ${name} in ${ns}"
  local i
  for ((i = 0; i < 80; i++)); do
    phase="$(oc get csv -n "${ns}" 2>/dev/null | awk -v n="${name}" '$1 ~ "^"n"[.]" {print $NF; exit}')"
    if [[ "${phase}" == "Succeeded" ]]; then
      log "CSV ${name} Succeeded"
      return 0
    fi
    sleep 15
  done
  die "Timed out waiting for CSV ${name} in ${ns} (last phase: ${phase:-none})"
}

wait_crd() {
  local crd=$1
  log "Waiting for CRD ${crd}"
  local i
  for ((i = 0; i < 40; i++)); do
    oc get crd "${crd}" >/dev/null 2>&1 && return 0
    sleep 5
  done
  die "Timed out waiting for CRD ${crd}"
}

wait_gateway_controller() {
  log "Waiting for Ingress Gateway API controller (openshift-default)"
  local i
  for ((i = 0; i < 60; i++)); do
    if oc get deploy istiod-openshift-gateway -n openshift-ingress >/dev/null 2>&1; then
      oc rollout status deploy/istiod-openshift-gateway -n openshift-ingress --timeout=120s >/dev/null 2>&1 && return 0
    fi
    sleep 10
  done
  die "Timed out waiting for istiod-openshift-gateway in openshift-ingress"
}

# Wildcard cert the default router uses for *.apps.<domain> Routes (IngressController defaultCertificate).
# On ROSA this is typically *-primary-cert-bundle-secret (Let's Encrypt). Falls back to default-ingress-cert.
router_tls_secret_name() {
  local name=""
  name="$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null || true)"
  if [[ -n "${name}" ]] && oc get secret "${name}" -n openshift-ingress >/dev/null 2>&1; then
    echo "${name}"
    return 0
  fi
  if oc get secret default-ingress-cert -n openshift-ingress >/dev/null 2>&1; then
    echo "default-ingress-cert"
    return 0
  fi
  die "No router TLS secret (IngressController defaultCertificate or default-ingress-cert)"
}

gateway_private_host() {
  local gw_name=$1 gw_ns=$2
  local svc port="8080"
  svc="$(oc get svc -n "${gw_ns}" -l "gateway.networking.k8s.io/gateway-name=${gw_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "${svc}" ]]; then
    svc="${gw_name}-openshift-gateway"
  fi
  echo "${svc}.${gw_ns}.svc.cluster.local:${port}"
}

apply_openshift_gateway() {
  local domain mcp_host gw_dir private_host tls_secret_name
  domain="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')"
  [[ -n "${domain}" ]] || die "cluster ingress domain empty"
  mcp_host="mcp.${domain}"
  tls_secret_name="$(router_tls_secret_name)"
  gw_dir="${GITOPS_DIR}/gateway-openshift"
  log "Enabling GatewayClass openshift-default (MCP host ${mcp_host}, HTTPS :443, tlsSecret=${tls_secret_name})"
  oc apply -f "${gw_dir}/gatewayclass.yaml"
  wait_gateway_controller
  sed \
    -e "s|mcp.REPLACE_CLUSTER_DOMAIN|${mcp_host}|g" \
    -e "s|REPLACE_ROUTER_TLS_SECRET|${tls_secret_name}|g" \
    "${gw_dir}/gateway.yaml" | oc apply -f -
  oc apply -f "${gw_dir}/referencegrant.yaml"
  log "Waiting for Gateway aro-agentic-mcp-gateway listener mcps"
  local i accepted=""
  for ((i = 0; i < 40; i++)); do
    accepted="$(oc get gateway aro-agentic-mcp-gateway -n openshift-ingress -o jsonpath='{.status.listeners[?(@.name=="mcps")].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || true)"
    [[ "${accepted}" == "True" ]] && break
    sleep 15
  done
  [[ "${accepted}" == "True" ]] || log "WARN Gateway listener mcps not Accepted yet (${accepted:-pending})"
  if oc get deploy kuadrant-operator-controller-manager -n kuadrant-system >/dev/null 2>&1; then
    oc rollout restart deploy/kuadrant-operator-controller-manager -n kuadrant-system >/dev/null 2>&1 || true
  fi
}

apply_mcp_gateway_extension() {
  wait_crd mcpgatewayextensions.mcp.kuadrant.io
  private_host="$(gateway_private_host aro-agentic-mcp-gateway openshift-ingress)"
  sed "s|REPLACE_PRIVATE_HOST|${private_host}|g" "${GITOPS_DIR}/operators/rhcl/mcp-gateway-extension.yaml" | oc apply -f -
}

# OIDC: RHCL AuthPolicy + MCPGatewayExtension oauthProtectedResource (Keycloak, Entra, etc.).
# OpenShift cluster OAuth / `oc whoami --show-token` are not MCP OIDC JWTs — see docs/guides/mcp-gateway-networking.md.
apply_mcp_gateway_oidc() {
  local cluster_dir domain mcp_host issuer resource well_known servers_json
  cluster_dir="$(dirname "${TFVARS}")"
  issuer="$(agentic_json mcp_oauth_issuer_url)"
  if [[ -z "${issuer}" ]] && [[ -f "${cluster_dir}/agentic.json" ]]; then
    issuer="$(jq -r '.mcp_oauth_issuer_url // empty' "${cluster_dir}/agentic.json")"
  fi
  if [[ -z "${issuer}" ]]; then
    if [[ "${MCP_GATEWAY_OIDC_REQUIRED:-true}" == "true" ]]; then
      die "MCP gateway OIDC required: set mcp_oauth_issuer_url in agentic.json (and optional mcp_oauth_authorization_servers). See docs/guides/mcp-gateway-networking.md#oidc-authentication. Export MCP_GATEWAY_OIDC_REQUIRED=false to skip (insecure on public clusters)."
    fi
    log "WARN MCP gateway OIDC skipped (no mcp_oauth_issuer_url in agentic.json)"
    return 0
  fi

  domain="$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')"
  [[ -n "${domain}" ]] || die "cluster ingress domain empty"
  mcp_host="mcp.${domain}"
  resource="https://${mcp_host}/mcp"
  well_known="https://${mcp_host}/.well-known/oauth-protected-resource"

  if [[ -f "${cluster_dir}/agentic.json" ]]; then
    servers_json="$(jq -c 'if (.mcp_oauth_authorization_servers // empty) | length > 0 then .mcp_oauth_authorization_servers else [.mcp_oauth_issuer_url] end' "${cluster_dir}/agentic.json")"
  else
    servers_json="$(jq -nc --arg i "${issuer}" '[$i]')"
  fi

  wait_crd authpolicies.kuadrant.io
  log "Applying MCP gateway OIDC (issuer=${issuer})"
  oc patch mcpgatewayextensions mcp-gateway -n mcp-gateway-system --type merge -p "$(jq -nc \
    --argjson servers "${servers_json}" \
    --arg res "${resource}" \
    '{spec:{oauthProtectedResource:{authorizationServers:$servers, resource:$res, scopesSupported:["basic"]}}}')"

  sed \
    -e "s|REPLACE_OAUTH_ISSUER_URL|${issuer}|g" \
    -e "s|REPLACE_MCP_WELL_KNOWN_URL|${well_known}|g" \
    "${GITOPS_DIR}/operators/rhcl/mcp-gateway-authpolicy.yaml" | oc apply -f -

  local i ready=""
  for ((i = 0; i < 24; i++)); do
    ready="$(oc get authpolicies mcp-gateway-oidc -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    [[ "${ready}" == "True" ]] && break
    sleep 10
  done
  [[ "${ready}" == "True" ]] || log "WARN AuthPolicy mcp-gateway-oidc not Ready (${ready:-pending})"
}

render_app() {
  awk -v repo="${GITOPS_REPO}" -v rev="${GITOPS_REVISION}" -v path="gitops/overlays/${OVERLAY}" '
    $1 == "repoURL:" { printf "    repoURL: %s\n", repo; next }
    $1 == "targetRevision:" { printf "    targetRevision: %s\n", rev; next }
    $1 == "path:" { printf "    path: %s\n", path; next }
    { print }
  ' "${GITOPS_DIR}/argocd/root-application.yaml"
}

agentic_json() {
  local key=$1
  local cluster_dir
  cluster_dir="$(dirname "${TFVARS}")"
  if [[ -f "${cluster_dir}/agentic.json" ]]; then
    jq -r --arg k "${key}" '.[$k] // empty' "${cluster_dir}/agentic.json"
    return 0
  fi
  tf_raw "${key}"
}

resolve_gitops_overlay() {
  local backend overlay default_overlay
  default_overlay="${GITOPS_OVERLAY:-public}"
  backend="$(agentic_json llm_backend)"
  overlay="$(agentic_json gitops_overlay)"
  if [[ -n "${overlay}" ]]; then
    echo "${overlay}"
  elif [[ "${backend}" == "aws" ]]; then
    echo "aws"
  else
    echo "${default_overlay}"
  fi
}

OVERLAY="$(resolve_gitops_overlay)"
OVERLAY_DIR="${GITOPS_DIR}/overlays/${OVERLAY}"

apply_olsconfig() {
  local endpoint deployment api_version backend region model
  backend="$(agentic_json llm_backend)"
  [[ -z "${backend}" ]] && backend="azure"
  if [[ "${backend}" == "aws" ]]; then
    region="$(agentic_json bedrock_region)"
    model="$(agentic_json bedrock_model_id)"
    [[ -n "${region}" ]] || die "bedrock_region empty; run make cluster.<name>.apply (llm_backend=aws)"
    [[ -n "${model}" ]] || die "bedrock_model_id empty"
    sed \
      -e "s|BEDROCK_REGION|${region}|g" \
      -e "s|BEDROCK_MODEL_ID|${model}|g" \
      "${GITOPS_DIR}/operators/lightspeed/olsconfig-bedrock.yaml" | oc apply -f -
    return 0
  fi
  endpoint="$(agentic_json openai_endpoint)"
  deployment="$(agentic_json openai_deployment_name)"
  api_version="$(agentic_json openai_model_version)"
  [[ -n "${endpoint}" ]] || die "openai_endpoint empty; run make cluster.<name>.apply (llm_backend=azure) or fill agentic.json"
  [[ -n "${deployment}" ]] || die "openai_deployment_name empty"
  [[ -n "${api_version}" ]] || api_version="2025-08-07"
  sed \
    -e "s|https://REPLACE.openai.azure.com/|${endpoint}|g" \
    -e "s|DEPLOYMENT_NAME|${deployment}|g" \
    -e "s|API_VERSION|${api_version}|g" \
    "${GITOPS_DIR}/operators/lightspeed/olsconfig.yaml" | oc apply -f -
}

apply_lightspeed_externalsecret() {
  local backend sm_secret_name
  backend="$(agentic_json llm_backend)"
  [[ -z "${backend}" ]] && backend="azure"
  if [[ "${backend}" == "aws" ]]; then
    sm_secret_name="$(agentic_json secrets_manager_secret_name)"
    [[ -n "${sm_secret_name}" ]] || die "secrets_manager_secret_name empty; run make cluster.<name>.apply (llm_backend=aws)"
    sed "s|SECRETS_MANAGER_SECRET_NAME|${sm_secret_name}|g" \
      "${GITOPS_DIR}/operators/lightspeed/externalsecret-bedrock.yaml" | oc apply -f -
    return 0
  fi
  oc apply -f "${GITOPS_DIR}/operators/lightspeed/externalsecret.yaml"
}

if [[ -n "${GITOPS_DRY_RUN}" ]]; then
  render_app
  echo "---"
  oc kustomize "${OVERLAY_DIR}" 2>/dev/null || kubectl kustomize "${OVERLAY_DIR}"
  exit 0
fi

command -v oc >/dev/null || die "oc required"
export KUBECONFIG
oc whoami >/dev/null 2>&1 || die "Cannot reach API (set KUBECONFIG)"
oc get ns openshift-gitops >/dev/null 2>&1 || die "Run installer make cluster.<name>.bootstrap first"

log "Applying operator subscriptions (${OVERLAY_DIR})"
oc apply -k "${OVERLAY_DIR}"

wait_csv openshift-cluster-observability-operator cluster-observability-operator
wait_csv openshift-lightspeed lightspeed-operator
wait_csv kuadrant-system rhcl-operator

if mcp_public_gateway_enabled; then
  apply_openshift_gateway
else
  log "Public MCP gateway skipped (default). Lightspeed in-cluster MCP is unchanged. Opt in with ENABLE_MCP_GATEWAY_PUBLIC=true after completing docs/guides/mcp-gateway-networking.md (roadmap)."
fi

log "Applying operands (CRs requiring operator CRDs)"
oc apply -f "${GITOPS_DIR}/operators/coo/uiplugin-perses.yaml"
apply_lightspeed_externalsecret
oc apply -f "${GITOPS_DIR}/operators/rhcl/mcp-namespace.yaml"
oc apply -f "${GITOPS_DIR}/operators/rhcl/kuadrant.yaml"

if mcp_public_gateway_enabled; then
  log "Applying MCPGatewayExtension (openshift-default)"
  apply_mcp_gateway_extension
  apply_mcp_gateway_oidc
fi

lightspeed_es_name="$(agentic_json lightspeed_secret_name)"
[[ -z "${lightspeed_es_name}" ]] && lightspeed_es_name="lightspeed-azure-openai"

log "Waiting for ExternalSecret ${lightspeed_es_name}"
for ((i = 0; i < 40; i++)); do
  st="$(oc get externalsecret "${lightspeed_es_name}" -n openshift-lightspeed -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  [[ "${st}" == "True" ]] && break
  sleep 15
done

log "Applying OLSConfig"
apply_olsconfig

log "Planting Argo CD Application agentic-stack"
render_app | oc apply -f -

log "Agentic GitOps bootstrap complete"
