#!/usr/bin/env bash
# List Bedrock Mantle models callable with the Lightspeed SM secret credentials.
# Org SCP may block bedrock:ListFoundationModels for all principals; Mantle ListModels still works.
set -euo pipefail

: "${CLUSTER_NAME:?Set CLUSTER_NAME (e.g. rosa-public)}"
: "${AWS_REGION:=ap-southeast-2}"

sm_secret_id="${CLUSTER_NAME}-lightspeed-bedrock"
SM_JSON="$(aws secretsmanager get-secret-value \
  --secret-id "${sm_secret_id}" \
  --region "${AWS_REGION}" \
  --query SecretString --output text)"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID="$(jq -r '.aws_access_key_id' <<<"${SM_JSON}")"
AWS_SECRET_ACCESS_KEY="$(jq -r '.aws_secret_access_key' <<<"${SM_JSON}")"

BEDROCK_REGION="$(jq -r '.region // empty' <<<"${SM_JSON}")"
BEDROCK_REGION="${BEDROCK_REGION:-us-east-1}"

echo "Secret: ${sm_secret_id}"
echo "Mantle region (from secret.region): ${BEDROCK_REGION}"
echo ""

MODELS_JSON="$(curl -sS "https://bedrock-mantle.${BEDROCK_REGION}.api.aws/v1/models" \
  --aws-sigv4 "aws:amz:${BEDROCK_REGION}:bedrock-mantle" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}")"

echo "=== Mantle model IDs (${BEDROCK_REGION}) ==="
jq -r '.data[].id' <<<"${MODELS_JSON}" | sort

echo ""
echo "=== Quick chat/completions probe (optional) ==="
echo "Set PROBE_MODEL to test one ID, e.g. PROBE_MODEL=qwen.qwen3-32b ${0}"
if [[ -n "${PROBE_MODEL:-}" ]]; then
  BODY="$(jq -nc --arg m "${PROBE_MODEL}" \
    '{model:$m, messages:[{role:"user",content:"say ok"}], max_tokens:8}')"
  curl -sS -w "\nHTTP %{http_code}\n" \
    "https://bedrock-mantle.${BEDROCK_REGION}.api.aws/v1/chat/completions" \
    -H "Content-Type: application/json" -d "${BODY}" \
    --aws-sigv4 "aws:amz:${BEDROCK_REGION}:bedrock-mantle" \
    --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}"
fi
