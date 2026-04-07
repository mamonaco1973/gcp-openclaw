#!/bin/bash
set -euo pipefail

# ================================================================================
# Base Packages
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [packages] removing snap"
systemctl stop snapd.service 2>/dev/null || true
snap remove --purge core22 2>/dev/null || true
snap remove --purge snapd 2>/dev/null || true
apt-get purge -y snapd
echo -e "Package: snapd\nPin: release *\nPin-Priority: -10" \
  | tee /etc/apt/preferences.d/nosnap.pref
echo "NOTE: [packages] snap removed"

echo "NOTE: [packages] installing base packages"
apt-get update -y
apt-get install -y \
  curl \
  ca-certificates \
  jq \
  unzip \
  wget \
  msmtp \
  msmtp-mta \
  mailutils \
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
