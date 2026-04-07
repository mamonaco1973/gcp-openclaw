#!/bin/bash
set -euo pipefail

# ================================================================================
# Systemd Service Installation
# ================================================================================
#
# Installs litellm.service and openclaw-gateway.service and enables them so
# they start automatically at boot. Services are NOT started here — userdata.sh
# writes the litellm config with the actual Bedrock model ID before starting.
#
# ================================================================================

echo "NOTE: [services] installing service unit files"
cp /tmp/litellm.service /etc/systemd/system/litellm.service
cp /tmp/openclaw-gateway.service /etc/systemd/system/openclaw-gateway.service
cp /tmp/xvfb.service /etc/systemd/system/xvfb.service

chmod 644 /etc/systemd/system/litellm.service
chmod 644 /etc/systemd/system/openclaw-gateway.service
chmod 644 /etc/systemd/system/xvfb.service

echo "NOTE: [services] reloading systemd daemon"
systemctl daemon-reload

echo "NOTE: [services] enabling services for autostart at boot"
systemctl enable xvfb
systemctl enable litellm
systemctl enable openclaw-gateway

echo "NOTE: [services] setting up desktop icons"
mkdir -p /etc/skel/Desktop
mkdir -p /home/openclaw/Desktop
for app in openclaw.desktop google-chrome.desktop code.desktop pcmanfm-qt.desktop qterminal.desktop onlyoffice-desktopeditors.desktop; do
  src="/usr/share/applications/${app}"
  if [ -f "$src" ]; then
    ln -sf "$src" "/etc/skel/Desktop/${app}"
    ln -sf "$src" "/home/openclaw/Desktop/${app}"
  else
    echo "WARNING: ${app} not found, skipping"
  fi
done
chown -R openclaw:openclaw /home/openclaw/Desktop

echo "NOTE: [services] creating Openclaw symlink in home directories"
ln -sf /home/openclaw/.openclaw /home/openclaw/Openclaw
chown -h openclaw:openclaw /home/openclaw/Openclaw
ln -sf .openclaw /etc/skel/Openclaw

echo "NOTE: [services] done"
