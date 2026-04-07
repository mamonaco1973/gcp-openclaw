#!/bin/bash
# ================================================================================
# validate.sh
#
# Purpose
# Post-deploy validation for the OpenClaw AI Agent Workstation.
# Reads Terraform outputs and prints a quick-start summary of all key
# connection details needed to RDP into the instance.
#
# Requirements
# - terraform CLI installed and authenticated
# - AWS credentials configured
# - Terraform state must exist (run apply.sh first)
# ================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/03-openclaw"

# ================================================================================
# Read Terraform outputs
# ================================================================================

cd "${TF_DIR}"

INSTANCE_ID="$(terraform output -raw instance_id  2>/dev/null || echo '<not found>')"
PUBLIC_IP="$(terraform output -raw public_ip       2>/dev/null || echo '<not found>')"
PUBLIC_DNS="$(terraform output -raw public_dns     2>/dev/null || echo '<not found>')"

# ================================================================================
# Quick Start Output
# ================================================================================

echo ""
echo "============================================================================"
echo "OpenClaw AI Agent Workstation - Quick Start"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Instance ID:"         "${INSTANCE_ID}"
printf "%-28s %s\n" "NOTE: Public IP:"            "${PUBLIC_IP}"
printf "%-28s %s\n" "NOTE: Public FQDN:"          "${PUBLIC_DNS}"
echo ""
printf "%-28s %s\n" "NOTE: RDP Host:"             "${PUBLIC_IP}:3389"
printf "%-28s %s\n" "NOTE: Username:"             "openclaw"
printf "%-28s %s\n" "NOTE: Password:"             "See secret: openclaw_credentials"
echo ""
