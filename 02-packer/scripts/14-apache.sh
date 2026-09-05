#!/bin/bash
set -euo pipefail

# ==============================================================================
# Apache2
# ==============================================================================
#
# Gives the agent somewhere to publish to. It can write a page into the
# document root with the exec tool and immediately open it in Chrome at
# http://localhost/, which makes "build me something and show me" a single
# self-contained demo needing no external hosting.
#
# The document root is world-writable so the agent can drop files there without
# sudo. That is a lab posture, not a production one: any local user can replace
# anything Apache serves. The tighter alternative is
# `chown -R openclaw:openclaw /var/www/html` with 775, which achieves the same
# thing for this one user -- swap it in if this image is ever reused for
# anything real.
#
# Apache listens on :80, which is NOT opened by the firewall rules in 01-core.
# That is deliberate: the page is reachable from the desktop's own browser and
# nothing else. Add an ingress rule for 80 only if you want it published to the
# internet.
#
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [apache] installing apache2"
apt-get update -y
apt-get install -y apache2

echo "NOTE: [apache] enabling apache2 at boot"
systemctl enable apache2

# Ubuntu's default document root. Kept as a variable so the intent survives if
# a future base image changes it.
DOCROOT=/var/www/html

echo "NOTE: [apache] making ${DOCROOT} writable by the agent"
mkdir -p "${DOCROOT}"
chmod 777 "${DOCROOT}"

echo "NOTE: [apache] $(apache2 -v | head -1)"
echo "NOTE: [apache] document root: ${DOCROOT} ($(stat -c '%a' "${DOCROOT}"))"
echo "NOTE: [apache] done"
