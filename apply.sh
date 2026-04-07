#!/bin/bash
# ================================================================================
# FILE: apply.sh
# ================================================================================
#
# Purpose:
#   Deploy core infrastructure.
#
# Deployment Flow:
#     1. Deploy core infrastructure (Terraform).
#     2. Build OpenClaw AMI (Packer).
#     3. Deploy OpenClaw EC2 host (Terraform).
#
# Design Principles:
#   - Fail-fast behavior using set -euo pipefail.
#   - Environment validation before execution.
#   - Post-build validation after provisioning completes.
#
# Requirements:
#   - AWS CLI configured with sufficient IAM permissions.
#   - Terraform installed and in PATH.
#   - check_env.sh and validate.sh present in working directory.
#
# Exit Codes:
#   0 = Success
#   1 = Validation failure or provisioning error
#
# ================================================================================


# ================================================================================
# SECTION: Configuration
# ================================================================================

# Target AWS region.
export AWS_DEFAULT_REGION="us-east-1"

# Fail on errors, unset variables, and pipe failures.
set -euo pipefail


# ================================================================================
# SECTION: Environment Validation
# ================================================================================

echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


# ================================================================================
# PHASE 1: Core Infrastructure
# ================================================================================

echo "NOTE: Building core infrastructure..."

cd 01-core || {
  echo "ERROR: Directory 01-core not found"
  exit 1
}

terraform init

SES_EMAIL=$(aws secretsmanager get-secret-value \
  --secret-id openclaw_ses_smtp \
  --query SecretString \
  --output text 2>/dev/null | jq -r '.from_email // empty' 2>/dev/null || true)

if [ -n "${SES_EMAIL}" ]; then
  echo "NOTE: Using existing SES email: ${SES_EMAIL}"
  terraform apply -auto-approve -var="ses_email=${SES_EMAIL}"
else
  terraform apply -auto-approve
fi

cd ..


# ================================================================================
# PHASE 2: Build OpenClaw AMI (Packer)
# ================================================================================

echo "NOTE: Building OpenClaw AMI with Packer..."

vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=clawd-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text)

subnet_id=$(aws ec2 describe-subnets \
  --filters \
    "Name=vpc-id,Values=${vpc_id}" \
    "Name=tag:Name,Values=pub-subnet-1" \
  --query "Subnets[0].SubnetId" \
  --output text)

cd 02-packer || {
  echo "ERROR: Directory 02-packer not found"
  exit 1
}

packer init ./openclaw.pkr.hcl
packer build \
  -var "vpc_id=${vpc_id}" \
  -var "subnet_id=${subnet_id}" \
  ./openclaw.pkr.hcl

cd ..


# ================================================================================
# SECTION: Bedrock Model Discovery
# ================================================================================

echo "NOTE: Resolving latest active Bedrock foundation models..."

# Claude Sonnet
CLAUDE_BASE=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE` && contains(modelId, `claude-sonnet`)]' \
  --output json | jq -r '[.[] | select(.modelId | test("-v[0-9]+:[0-9]+$"))] | [.[].modelId] | sort | last')

if [ -z "${CLAUDE_BASE}" ] || [ "${CLAUDE_BASE}" = "null" ]; then
  echo "ERROR: Could not resolve a Claude Sonnet foundation model from Bedrock."
  exit 1
fi
BEDROCK_MODEL_ID="us.${CLAUDE_BASE}"
echo "NOTE: Claude Sonnet: ${BEDROCK_MODEL_ID}"

# Claude Haiku
HAIKU_BASE=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE` && contains(modelId, `claude-haiku`)]' \
  --output json | jq -r '[.[] | select(.modelId | test("-v[0-9]+:[0-9]+$"))] | [.[].modelId] | sort | last')

if [ -z "${HAIKU_BASE}" ] || [ "${HAIKU_BASE}" = "null" ]; then
  echo "WARNING: Could not resolve Claude Haiku — using default"
  HAIKU_MODEL_ID="us.anthropic.claude-haiku-4-5-20251001-v1:0"
else
  HAIKU_MODEL_ID="us.${HAIKU_BASE}"
fi
echo "NOTE: Claude Haiku: ${HAIKU_MODEL_ID}"

# Amazon Nova Pro
NOVA_PRO_BASE=$(aws bedrock list-foundation-models \
  --by-provider amazon \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE` && contains(modelId, `nova-pro`)]' \
  --output json | jq -r '[.[].modelId] | sort | last' | cut -d: -f1,2)

if [ -z "${NOVA_PRO_BASE}" ] || [ "${NOVA_PRO_BASE}" = "null" ]; then
  echo "WARNING: Could not resolve Nova Pro — using default"
  NOVA_PRO_MODEL_ID="us.amazon.nova-pro-v1:0"
else
  NOVA_PRO_MODEL_ID="us.${NOVA_PRO_BASE}"
fi
echo "NOTE: Amazon Nova Pro: ${NOVA_PRO_MODEL_ID}"

# Amazon Nova Lite
NOVA_LITE_BASE=$(aws bedrock list-foundation-models \
  --by-provider amazon \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE` && contains(modelId, `nova-lite`)]' \
  --output json | jq -r '[.[].modelId] | sort | last' | cut -d: -f1,2)

if [ -z "${NOVA_LITE_BASE}" ] || [ "${NOVA_LITE_BASE}" = "null" ]; then
  echo "WARNING: Could not resolve Nova Lite — using default"
  NOVA_LITE_MODEL_ID="us.amazon.nova-lite-v1:0"
else
  NOVA_LITE_MODEL_ID="us.${NOVA_LITE_BASE}"
fi
echo "NOTE: Amazon Nova Lite: ${NOVA_LITE_MODEL_ID}"


# ================================================================================
# PHASE 3: OpenClaw Host
# ================================================================================

echo "NOTE: Building OpenClaw host..."

cd 03-openclaw || {
  echo "ERROR: Directory 03-openclaw not found"
  exit 1
}

terraform init
terraform apply -auto-approve \
  -var="bedrock_model_id=${BEDROCK_MODEL_ID}" \
  -var="haiku_model_id=${HAIKU_MODEL_ID}" \
  -var="nova_pro_model_id=${NOVA_PRO_MODEL_ID}" \
  -var="nova_lite_model_id=${NOVA_LITE_MODEL_ID}"

cd ..


# ================================================================================
# SECTION: Post-Deployment Validation
# ================================================================================

./validate.sh
