#!/bin/bash
set -euo pipefail

# ================================================================================
# Base Packages and SSM Agent
# ================================================================================
#
# XRDP has conflicts with the snap-based SSM agent, so snap is removed first
# and the SSM agent is installed via the official DEB package instead.
#
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [packages] removing snap and snap-based SSM agent"
systemctl stop snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
snap remove --purge amazon-ssm-agent 2>/dev/null || true
snap remove --purge core22 2>/dev/null || true
snap remove --purge snapd 2>/dev/null || true
apt-get purge -y snapd
echo -e "Package: snapd\nPin: release *\nPin-Priority: -10" \
  | tee /etc/apt/preferences.d/nosnap.pref
echo "NOTE: [packages] snap removed"

echo "NOTE: [packages] installing SSM agent via DEB"
apt-get update -y
curl -fsSL https://s3.amazonaws.com/amazon-ssm-us-east-1/latest/debian_amd64/amazon-ssm-agent.deb \
  -o /tmp/ssm.deb
dpkg -i /tmp/ssm.deb
rm /tmp/ssm.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
echo "NOTE: [packages] SSM agent installed"

echo "NOTE: [packages] installing base packages"
apt-get install -y \
  curl \
  ca-certificates \
  jq \
  unzip \
  wget \
  python3-venv \
  python3-pip
echo "NOTE: [packages] done"

echo "NOTE: [packages] removing LibreOffice"
apt-get purge -y libreoffice* liblibreoffice* || true
apt-get autoremove -y
echo "NOTE: [packages] LibreOffice removed"

echo "NOTE: [packages] disabling update notifications"
apt-get purge -y update-notifier update-notifier-common || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
echo 'APT::Periodic::Update-Package-Lists "0";' > /etc/apt/apt.conf.d/99disable-auto-updates
echo 'APT::Periodic::Unattended-Upgrade "0";'  >> /etc/apt/apt.conf.d/99disable-auto-updates
echo "NOTE: [packages] update notifications disabled"

echo "NOTE: [packages] disabling apport crash reporting"
systemctl disable apport.service 2>/dev/null || true
systemctl mask apport.service 2>/dev/null || true
echo "enabled=0" > /etc/default/apport
echo "NOTE: [packages] apport disabled"
