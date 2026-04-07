#!/bin/bash
set -euo pipefail

# ================================================================================
# LiteLLM Proxy
# ================================================================================
#
# Creates a Python virtual environment at /opt/litellm-venv and installs the
# LiteLLM proxy package. The config directory /opt/openclaw is owned by the
# openclaw user so userdata.sh can write litellm-config.yaml at boot.
#
# ================================================================================

echo "NOTE: [litellm] creating venv at /opt/litellm-venv"
python3 -m venv /opt/litellm-venv

echo "NOTE: [litellm] installing litellm[proxy]"
/opt/litellm-venv/bin/pip install --upgrade pip --quiet
/opt/litellm-venv/bin/pip install 'litellm[proxy]' --quiet
echo "NOTE: [litellm] $(/opt/litellm-venv/bin/pip show litellm 2>/dev/null | grep Version)"

echo "NOTE: [litellm] creating /opt/openclaw config directory"
mkdir -p /opt/openclaw
chown openclaw:openclaw /opt/openclaw

echo "NOTE: [litellm] done"
