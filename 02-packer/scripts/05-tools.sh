#!/bin/bash
set -euo pipefail

# ================================================================================
# Cloud + Dev Tooling
# ================================================================================
#
# Installs cloud CLI tools and developer tooling needed for multi-cloud
# project work from the OpenClaw desktop:
#   - Git
#   - AWS CLI v2
#   - HashiCorp (Terraform + Packer)
#   - Azure CLI
#   - Google Cloud SDK
#   - Visual Studio Code
#
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

# ================================================================================
# Git
# ================================================================================

echo "NOTE: [tools] installing git"
apt-get install -y git
echo "NOTE: [tools] git $(git --version)"


# ================================================================================
# AWS CLI v2
# ================================================================================

echo "NOTE: [tools] installing AWS CLI v2"
cd /tmp
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws
echo "NOTE: [tools] $(aws --version)"


# ================================================================================
# HashiCorp (Terraform + Packer)
# ================================================================================

echo "NOTE: [tools] adding HashiCorp APT repository"
apt-get install -y gnupg software-properties-common
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
apt-get update -y
apt-get install -y terraform packer
echo "NOTE: [tools] $(terraform -version | head -1)"
echo "NOTE: [tools] $(packer -version)"


# ================================================================================
# Azure CLI
# ================================================================================

echo "NOTE: [tools] adding Azure CLI APT repository"
mkdir -p /etc/apt/keyrings
curl -sL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg] \
https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/azure-cli.list >/dev/null
apt-get update -y
apt-get install -y azure-cli
echo "NOTE: [tools] $(az --version | head -1)"


# ================================================================================
# Google Cloud SDK
# ================================================================================

echo "NOTE: [tools] adding Google Cloud SDK APT repository"
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" \
  | tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
apt-get update -y
apt-get install -y google-cloud-sdk
echo "NOTE: [tools] $(gcloud --version | head -1)"


# ================================================================================
# Visual Studio Code
# ================================================================================

echo "NOTE: [tools] adding VS Code APT repository"
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
  | tee /etc/apt/sources.list.d/vscode.list >/dev/null
apt-get update -y
apt-get install -y code
echo "NOTE: [tools] VS Code installed"

echo "NOTE: [tools] done"
