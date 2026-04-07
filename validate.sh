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
printf "%-28s %s\n" "NOTE: Password:"              "Run: gcloud secrets versions access latest --secret=openclaw-credentials | jq -r .password"
echo ""
