#!/bin/bash
# ================================================================================
# FILE: apply.sh
# ================================================================================
#
# Purpose:
#   Deploy the OpenClaw AI Agent Workstation on GCP.
#
# Deployment Flow:
#     1. Deploy core infrastructure (Terraform: VPC, NAT, Secret Manager).
#     2. Build OpenClaw GCE image (Packer).
#     3. Deploy OpenClaw VM (Terraform).
#     4. Validate deployment.
#
# Requirements:
#   - credentials.json in project root (GCP service account key)
#   - gcloud, terraform, packer, jq in PATH
#
# ================================================================================

set -euo pipefail


# ================================================================================
# SECTION: Environment Validation
# ================================================================================

echo "NOTE: Running environment validation..."
./check_env.sh

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"
project_id=$(jq -r '.project_id' "./credentials.json")
GCP_ZONE="${GCP_ZONE:-us-central1-b}"


# ================================================================================
# PHASE 1: Core Infrastructure
# ================================================================================

echo "NOTE: Building core infrastructure..."

cd 01-core
terraform init
terraform apply -auto-approve
cd ..


# ================================================================================
# PHASE 2: Build OpenClaw GCE Image (Packer)
# ================================================================================

echo "NOTE: Building OpenClaw image with Packer..."

cd 02-packer
packer init ./openclaw.pkr.hcl
packer build \
  -var "project_id=${project_id}" \
  -var "zone=${GCP_ZONE}" \
  ./openclaw.pkr.hcl
cd ..


# ================================================================================
# PHASE 3: OpenClaw Host
# ================================================================================

echo "NOTE: Resolving latest openclaw image..."
openclaw_image=$(gcloud compute images list \
  --filter="name~'^openclaw-image' AND family=openclaw-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")

if [[ -z "${openclaw_image}" ]]; then
  echo "ERROR: No openclaw image found in family openclaw-images."
  exit 1
fi
echo "NOTE: Using image: ${openclaw_image}"

echo "NOTE: Deploying OpenClaw host..."
cd 03-openclaw
terraform init
terraform apply -auto-approve \
  -var="openclaw_image_name=${openclaw_image}" \
  -var="zone=${GCP_ZONE}"
cd ..


# ================================================================================
# SECTION: Post-Deployment Validation
# ================================================================================

./validate.sh
