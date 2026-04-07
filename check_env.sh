#!/bin/bash
# ================================================================================
# check_env.sh - Environment Validation
# ================================================================================
#
# Purpose:
#   - Validates required CLI tools are available in PATH.
#   - Verifies credentials.json exists and gcloud can authenticate.
#   - Enables required GCP APIs.
#
# ================================================================================

set -euo pipefail

echo "NOTE: Validating required commands in PATH."

commands=("gcloud" "terraform" "jq" "packer")

for cmd in "${commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}"
    exit 1
  fi
  echo "NOTE: Found required command: ${cmd}"
done

echo "NOTE: All required commands are available."

echo "NOTE: Validating credentials.json..."
if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: credentials.json not found in project root."
  echo "       Create a GCP service account key and save it as credentials.json"
  exit 1
fi

gcloud auth activate-service-account --key-file="./credentials.json"
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

echo "NOTE: gcloud authentication successful."

./api_setup.sh
