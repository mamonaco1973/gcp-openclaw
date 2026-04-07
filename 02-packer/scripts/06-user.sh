#!/bin/bash
set -euo pipefail

# ================================================================================
# OpenClaw Linux User
# ================================================================================
#
# Creates the 'openclaw' system user with sudo access.
# No password is set here — userdata.sh sets it from Secrets Manager at boot.
# Desktop config (panel, session, pcmanfm-qt) is inherited from /etc/skel,
# populated by 02-desktop.sh before this script runs.
#
# ================================================================================

echo "NOTE: [user] creating openclaw user"
useradd -m -s /bin/bash openclaw
usermod -aG sudo openclaw

# Passwordless sudo — enables desktop admin actions without a password prompt.
echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw
chmod 440 /etc/sudoers.d/openclaw

echo "NOTE: [user] done"
