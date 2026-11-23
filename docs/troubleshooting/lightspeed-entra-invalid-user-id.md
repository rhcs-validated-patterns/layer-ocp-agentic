# Bug report: Lightspeed fails for Entra console users — non-UUID `user_id`

Use this write-up when opening **OCPBUGS** / Lightspeed product bugs. Operator-visible symptom is misleading; root cause is conversation-cache UUID validation vs OAuth TokenReview UIDs.

## Summary

OpenShift Lightspeed in the console shows **`[LLM Backend] An error occurred during LLM invocation`** for users who authenticate via **Microsoft Entra ID** (cluster `external-auth`). Server logs show **`ValueError: Invalid user ID <opaque-subject>`** during **conversation history / postgres cache** lookup. The failure occurs **before** the Azure OpenAI (or other LLM) provider is invoked.

## Products and versions (reproduction)

| Component | Version |
|-----------|---------|
| Platform | Red Hat OpenShift **5.0.0** (ARO HCP) |
| Lightspeed operator CSV | **lightspeed-operator.v2.0.1** |
| lightspeed-service image | `registry.redhat.io/openshift-lightspeed/lightspeed-service-api-rhel9@sha256:f2b14f5e0662646a9565fa52e99a06461462fc856870175318e4c1a8ce84413a` (pod as deployed 2026-11-17) |
| Cluster auth | Installer Entra OIDC (`operatorsAuths/entra`) + `entra-cluster-admin` for the Entra console user |
| LLM | Azure OpenAI private endpoint, `OLSConfig` provider `azure_openai`, secret via ESO `apitoken` |

## Environment

- **Cloud:** Azure ARO HCP, region `uksouth`
- **Profile:** `aro-agentic` (reference pattern; same behaviour expected on any Entra-backed console login)
- **Console URL:** `https://console-openshift-console.apps.<cluster>.<region>.aroapp-hcp.io`
- **OLSConfig:** `cluster` — `spec.ols.conversationCache.type: postgres` (operator default)
- **OLS status:** `overallStatus: Ready`, `ApiReady`, operator reconciliation healthy; failure is runtime per-request

## Steps to reproduce

1. Deploy OCP 5 with Lightspeed operator and a valid `OLSConfig` (e.g. Azure OpenAI + `apitoken` secret).
2. Configure console **Entra OIDC** external authentication (not kubeadmin-only).
3. Grant the Entra user cluster access (e.g. `cluster-admin` or `lightspeed-operator-query-access` for `/ols-access`).
4. Log into the console as the Entra user.
5. Open **OpenShift Lightspeed** and send a prompt (e.g. `hi!`).

## Actual result

- UI: **Danger alert** — `[LLM Backend] An error occurred during LLM invocation. Please contact your OpenShift Lightspeed administrator.`
- Pod log (`lightspeed-app-server`, container `lightspeed-service-api`):

```text
ValueError: Invalid user ID <opaque-entra-subject-not-a-uuid>
  File ".../ols/src/cache/cache.py", line 28, in _check_user_id
  File ".../ols/src/cache/postgres_cache.py", line 184, in get
  File ".../ols/src/query_helpers/history_support.py", line 143, in _retrieve_previous_input
  File ".../ols/app/endpoints/streaming_ols.py", line 318, in ...
ERROR: LLM error received: type=ValueError, message=Invalid user ID <opaque-entra-subject-not-a-uuid>
```

## Expected result

- Entra-authenticated console users can use Lightspeed without cache key errors.
- If K8s authentication supplies a non-UUID `user.uid` from `TokenReview`, the service should either:
  - normalize to a stable UUID (e.g. hash OID/`sub`), or
  - skip UUID validation for authenticated OCP users (`skip_user_id_check` where appropriate), or
  - use a documented identity claim (`oid`) that is UUID-shaped on Entra.

## Root cause (analysis)

1. **K8s auth** (`ols/src/auth/k8s.py`) returns `user_info.user.uid` from **TokenReview** with `skip_user_id_check=False`.
2. **Entra/OIDC** subjects for this user are **not RFC-4122 UUIDs** (opaque `sub`, not a UUID).
3. **Conversation cache** (`ols/utils/suid.py` → `uuid.UUID(suid)`) rejects the UID in `_check_user_id` before any LLM HTTP call.
4. **Error mapping** in `streaming_ols` / `errors_parsing` surfaces this as a generic **LLM Backend** error, which misleads operators into checking Azure OpenAI credentials.

**Contrast:** `kube:admin` path special-cases UID to cluster ID (UUID). Entra users have no equivalent normalization.

## What is *not* broken (ruled out)

- `OLSConfig` / operands **Ready**
- ExternalSecret → `apitoken` synced from Key Vault
- Azure OpenAI DNS to the private endpoint (`<account>.openai.azure.com` → private endpoint address)
- RBAC: `oc auth can-i get /ols-access --as=<entra-user>` → **yes**

## Workarounds

| Workaround | Limitation |
|------------|------------|
| Log in as break-glass / `kube:admin` if UID maps to cluster UUID | Not acceptable for production Entra users |
| Disable postgres cache / use memory cache | Not exposed on `OLSConfig` CR today (operator defaults to postgres) |
| Wait for product fix | Required for Entra + Lightspeed on HCP |

## Suggested fix (engineering)

- Map authenticated identity to a **stable UUID** for cache keys (e.g. SHA-256 UUID5 of `username` + idp, or prefer Entra **`oid`** when present in TokenReview extras).
- Or allow **skip_user_id_check** for validated K8s TokenReview identities where UID is opaque.
- Improve user-facing error: distinguish **identity/cache** failures from **LLM provider** failures.

## References

- Auth: `lightspeed-service` `ols/src/auth/k8s.py` (`return user_info.user.uid, …, False, token`)
- Cache validation: `ols/utils/suid.py` (`check_suid` → `uuid.UUID`)
- Similar OIDC issue pattern: Entra `sub` vs stable `oid` (not UUID-shaped `sub`)

## Reporter

- **Org:** Red Hat MOBB / reference pattern validation
- **Cluster:** `aro-agentic` lab profile
- **Repro log time (UTC):** 2026-11-17T02:34:38Z