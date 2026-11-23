# Agentic stack agent playbook

Sibling of the cluster installers. ARO: [`validated-pattern-aro-hcp`](../validated-pattern-aro-hcp) (`llm_backend=azure`). ROSA: [`vp-terraform-rosa`](../vp-terraform-rosa) (`llm_backend=aws`). Prerequisites: installer `apply` → kubeconfig (`kubeconfig` / `external-auth` on ARO, `login` on ROSA) → `bootstrap` → `platform`. Contracts: [`docs/guides/platform-contract.md`](docs/guides/platform-contract.md).

## Done-when

| Step | Command | Done when |
|------|---------|-----------|
| Platform | `ARO_HCP_ROOT=…` or `VP_TERRAFORM_ROSA_ROOT=… make cluster.<name>.apply` | `agentic.json` written; Azure PE + Key Vault secrets, or Bedrock Secrets Manager secret |
| GitOps | `make cluster.<name>.bootstrap` | COO, Lightspeed, RHCL CSVs `Succeeded`; `OLSConfig` applied |
| Verify | `make cluster.<name>.verify` | `scripts/verify.sh` exits 0 |

## Destroy

`make cluster.<name>.destroy` here **before** installer destroy.

## Known failure modes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| OpenAI account create 409/403 | Quota or region SKU | `az cognitiveservices account list-skus -l <location>`; request quota |
| Lightspeed CSV `UnsupportedOperatorGroup` | OG used AllNamespaces; operator needs SingleNamespace | `spec.targetNamespaces: [openshift-lightspeed]` on Lightspeed OG only |
| COO/RHCL CSV `UnsupportedOperatorGroup` | OG used OwnNamespace | Remove `targetNamespaces` on COO and RHCL OperatorGroups (AllNamespaces) |
| OLM `lightspeed-catalog` ResolutionFailed | Stale custom CatalogSource from earlier apply | `oc delete catalogsource lightspeed-catalog -n openshift-marketplace`; recreate subs |
| OLSConfig missing `apitoken` | ExternalSecret used `AZURE_OPENAI_*` keys | Sync `apitoken` from KV; set `credentialKey: apitoken` on provider |
| OLS `NotReady` / RHOKP Pending | 2-worker cluster lacks CPU/ephemeral storage for RHOKP | Default `spec.ols.byokRAGOnly: true` in GitOps; scale workers to enable OKP |
| RHCL stuck on 1.4.x | Channel `stable-1.5` not in index | Confirm `oc get packagemanifest rhcl-operator`; adjust channel |
| Kuadrant NotReady (Gateway API) | No `openshift-default` GatewayClass | **Expected** when public MCP is off (default). With `ENABLE_MCP_GATEWAY_PUBLIC=true`, bootstrap applies `gitops/gateway-openshift/`; restart kuadrant operator if stalled |
| MCPGatewayExtension not Ready | Gateway listener not Accepted / wrong `privateHost` | Only when `ENABLE_MCP_GATEWAY_PUBLIC=true`; TLS from IngressController **defaultCertificate** — see [MCP gateway networking](docs/guides/mcp-gateway-networking.md) |
| ExternalSecret fails | KV secret names mismatch | Re-run installer ESO bootstrap; re-apply Terraform |
| Console LS “LLM Backend” + `Invalid user ID` in app-server logs | Entra TokenReview UID is not UUID; postgres cache rejects | [Bug write-up](docs/troubleshooting/lightspeed-entra-invalid-user-id.md); file OCPBUGS |