#!/bin/bash
# ================================================================================
# FILE: destroy.sh
# ================================================================================
#
# Purpose:
#   Orchestrate controlled teardown of the OpenClaw deployment.
#
# Teardown Order:
#     1. Destroy OpenClaw VM (03-openclaw).
#     2. Delete all openclaw GCE images.
#     3. Destroy core infrastructure (01-core).
#
# ================================================================================

set -euo pipefail

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"
project_id=$(jq -r '.project_id' "./credentials.json")

gcloud auth activate-service-account --key-file="./credentials.json" > /dev/null 2>&1


# ================================================================================
# PHASE 1: Destroy OpenClaw Host
# ================================================================================

echo "NOTE: Destroying OpenClaw host..."

openclaw_image=$(gcloud compute images list \
  --filter="name~'^openclaw-image' AND family=openclaw-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)" 2>/dev/null || true)

if [[ -z "${openclaw_image}" ]]; then
  echo "NOTE: No openclaw image found, using placeholder for destroy."
  openclaw_image="placeholder"
fi

cd 03-openclaw
terraform init
terraform destroy -auto-approve \
  -var="openclaw_image_name=${openclaw_image}"
cd ..


# ================================================================================
# PHASE 2: Delete OpenClaw GCE Images
# ================================================================================

echo "NOTE: Deleting all openclaw GCE images..."

image_list=$(gcloud compute images list \
  --format="value(name)" \
  --filter="name~'^openclaw-image'" 2>/dev/null || true)

if [ -z "${image_list}" ]; then
  echo "NOTE: No openclaw images found, skipping."
else
  for image in ${image_list}; do
    echo "NOTE: Deleting image: ${image}"
    gcloud compute images delete "${image}" --quiet \
      || echo "WARNING: Failed to delete image: ${image}"
  done
fi


# ================================================================================
# PHASE 3: Destroy Core Infrastructure
# ================================================================================

echo "NOTE: Destroying core infrastructure..."

cd 01-core
terraform init
terraform destroy -auto-approve
cd ..

echo "NOTE: Infrastructure teardown complete."
