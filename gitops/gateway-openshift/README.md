# Gateway API resources for RHCL MCP

Applied by `scripts/gitops-bootstrap.sh` (`apply_openshift_gateway`).

- **`gatewayclass.yaml`** — enables `openshift-default` (Ingress Operator / lightweight Istio).
- **`gateway.yaml`** — `aro-agentic-mcp-gateway`; listener **`mcps`**, **HTTPS :443**, TLS **Terminate** with the **IngressController default certificate** Secret (not `default-ingress-cert`).
- **`referencegrant.yaml`** — cross-namespace reference from `mcp-gateway-system`.

**Not applied by default bootstrap.** Applied only when `ENABLE_MCP_GATEWAY_PUBLIC=true`. Architecture and roadmap: [MCP gateway networking](../../docs/guides/mcp-gateway-networking.md).

Official: [OCP Gateway API](https://docs.redhat.com/en/documentation/openshift_container_platform/5.0/html/ingress_and_load_balancing/configuring-gateway-api), [RHCL MCP gateway](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.5/html/install_the_mcp_gateway/mcp-gateway-install).