#!/bin/bash
# ================================================================================
# validate.sh
# ================================================================================
#
# Purpose:
#   Post-deploy validation for the OpenClaw AI Agent Workstation on GCP.
#   Reads Terraform outputs and prints connection details.
#
# ================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/03-openclaw"

cd "${TF_DIR}"

INSTANCE_NAME="$(terraform output -raw instance_name 2>/dev/null || echo '<not found>')"
PUBLIC_IP="$(terraform output -raw public_ip         2>/dev/null || echo '<not found>')"
SECRET_ID="$(terraform output -raw credentials_secret_id 2>/dev/null || echo 'openclaw-credentials')"

# Print the password outright rather than sending the operator off to look
# it up. Secret Manager stays the source of truth; this just reads it back.
CREDS_JSON="$(gcloud secrets versions access latest --secret="${SECRET_ID}" 2>/dev/null || true)"
if [ -n "${CREDS_JSON}" ]; then
  PASSWORD="$(printf '%s' "${CREDS_JSON}" | jq -r '.password')"
else
  # Usually means the caller lacks secretmanager.versions.access, or the
  # deploy has not finished. Fall back to showing the lookup command.
  PASSWORD="<unavailable> - run: gcloud secrets versions access latest --secret=${SECRET_ID} | jq -r .password"
fi

echo ""
echo "============================================================================"
echo "OpenClaw AI Agent Workstation - Quick Start (GCP)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Instance Name:"        "${INSTANCE_NAME}"
printf "%-28s %s\n" "NOTE: Public IP:"             "${PUBLIC_IP}"
echo ""
printf "%-28s %s\n" "NOTE: RDP Host:"              "${PUBLIC_IP}:3389"
printf "%-28s %s\n" "NOTE: Username:"              "openclaw"
printf "%-28s %s\n" "NOTE: Password:"              "${PASSWORD}"
echo ""
