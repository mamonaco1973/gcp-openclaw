#!/bin/bash
# ==============================================================================
# check_env.sh - Environment Validation
# ------------------------------------------------------------------------------
# Purpose:
#   - Validates that required CLI tools are available in the current PATH.
#   - Verifies AWS CLI authentication and connectivity.
#
# Scope:
#   - Checks for aws, terraform, and jq binaries.
#   - Confirms the caller identity via AWS STS.
#
# Fast-Fail Behavior:
#   - Script exits immediately on command failure, unset variables,
#     or failed pipelines.
#
# Requirements:
#   - AWS CLI installed and configured.
#   - Terraform installed.
#   - jq installed.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Required Commands
# ------------------------------------------------------------------------------
echo "NOTE: Validating required commands in PATH."

commands=("aws" "terraform" "jq" "packer")

for cmd in "${commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}"
    exit 1
  fi

  echo "NOTE: Found required command: ${cmd}"
done

echo "NOTE: All required commands are available."

# ------------------------------------------------------------------------------
# AWS Connectivity Check
# ------------------------------------------------------------------------------
echo "NOTE: Verifying AWS CLI connectivity..."

aws sts get-caller-identity --query "Account" --output text >/dev/null

echo "NOTE: AWS CLI authentication successful."

# ------------------------------------------------------------------------------
# Bedrock Model Access Check
# ------------------------------------------------------------------------------
echo "NOTE: Checking Bedrock model access..."

check_bedrock_model() {
  local label="$1"
  local model_id="$2"
  local payload="$3"

  # Check model is active in the region
  local base_id="${model_id#us.}"
  local active
  active=$(aws bedrock list-foundation-models \
    --query "modelSummaries[?modelId=='${base_id}'].modelLifecycle.status" \
    --output text 2>/dev/null || true)

  if [ "${active}" != "ACTIVE" ]; then
    echo "ERROR: ${label} (${base_id}) is not active in this region."
    echo "       Check: https://console.aws.amazon.com/bedrock/home#/models"
    return 1
  fi

  # Test actual account access via a minimal invocation
  local tmp errtmp
  tmp=$(mktemp)
  errtmp=$(mktemp)
  if ! aws bedrock-runtime invoke-model \
    --model-id "${model_id}" \
    --body "${payload}" \
    --cli-binary-format raw-in-base64-out \
    "${tmp}" >/dev/null 2>"${errtmp}"; then
    local errmsg
    errmsg=$(cat "${errtmp}")
    rm -f "${tmp}" "${errtmp}"
    if echo "${errmsg}" | grep -qi "AccessDenied\|not authorized\|not subscribed"; then
      echo "ERROR: ${label} — access not granted."
      if [[ "${model_id}" == *"anthropic"* ]]; then
        echo "       Request access at: https://console.aws.amazon.com/bedrock/home#/modelaccess"
      fi
    else
      echo "ERROR: ${label} — invocation failed: ${errmsg}"
    fi
    return 1
  fi

  rm -f "${tmp}" "${errtmp}"
  echo "NOTE: ${label} — OK"
}

CLAUDE_PAYLOAD='{"anthropic_version":"bedrock-2023-05-31","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
NOVA_PAYLOAD='{"messages":[{"role":"user","content":[{"text":"hi"}]}],"inferenceConfig":{"maxTokens":1}}'

check_bedrock_model "Claude Sonnet"   "us.anthropic.claude-sonnet-4-5-20250929-v1:0"  "${CLAUDE_PAYLOAD}"
check_bedrock_model "Claude Haiku"    "us.anthropic.claude-haiku-4-5-20251001-v1:0"   "${CLAUDE_PAYLOAD}"
check_bedrock_model "Amazon Nova Pro" "us.amazon.nova-pro-v1:0"                        "${NOVA_PAYLOAD}"
check_bedrock_model "Amazon Nova Lite" "us.amazon.nova-lite-v1:0"                     "${NOVA_PAYLOAD}"

echo "NOTE: All Bedrock models accessible."
