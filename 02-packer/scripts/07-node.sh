#!/bin/bash
set -euo pipefail

# ================================================================================
# Node.js 22 + pnpm + OpenClaw
# ================================================================================
#
# Installs Node.js 22 system-wide via the NodeSource APT repository.
# Installs pnpm globally via npm and uses /opt/pnpm as the store.
# Installs openclaw globally so the binary is available at a fixed path.
#
# ================================================================================

echo "NOTE: [node] installing Node.js 22 via NodeSource"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
echo "NOTE: [node] Node $(node --version) installed"

echo "NOTE: [openclaw] installing openclaw globally via npm"
npm install -g openclaw

# Symlink to a fixed path so all scripts and service files can use a
# consistent location regardless of npm's prefix configuration.
ln -sf "$(which openclaw)" /usr/local/bin/openclaw

echo "NOTE: [openclaw] $(openclaw --version 2>&1 | head -1)"

echo "NOTE: [openclaw] installing icon and desktop entry"
cp /tmp/openclaw.png /usr/share/pixmaps/openclaw.png

# ------------------------------------------------------------------------------
# Desktop launcher
# ------------------------------------------------------------------------------
# `openclaw dashboard` tries to open a browser itself and fails on this image
# ("Browser launch failed"), which with Terminal=false means clicking the icon
# appears to do nothing at all.
#
# It deliberately does NOT use `openclaw dashboard` to get the URL.  From
# 2026.8.2 that mints a one-time bootstrap token in the URL fragment, and
# re-pairing on page load races the Control UI's WebSocket connect: the tab
# comes up on the manual connect form and only works after a refresh.  With
# gateway.auth.mode=none there is nothing for that token to authenticate, so
# the plain chat URL is both sufficient and reliable.
# ------------------------------------------------------------------------------
cat > /usr/local/bin/openclaw-dashboard <<'LAUNCH'
#!/bin/bash
set -uo pipefail

URL="http://127.0.0.1:18789/chat/main"

# The gateway may still be starting when the desktop session comes up, so
# poll the port rather than failing on the first attempt after a reboot.
ready=""
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null --max-time 2 "${URL}"; then
    ready=1
    break
  fi
  sleep 2
done

if [ -z "${ready}" ]; then
  # Terminal=false hides stderr, so surface the failure somewhere visible
  # rather than letting the click look like a no-op.
  notify-send 'OpenClaw' 'Gateway not reachable. Run: openclaw status' \
    2>/dev/null || true
  exit 1
fi

exec google-chrome "${URL}"
LAUNCH
chmod 755 /usr/local/bin/openclaw-dashboard

cat > /usr/share/applications/openclaw.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=OpenClaw
Comment=OpenClaw AI Coding Agent
Exec=/usr/local/bin/openclaw-dashboard
Icon=openclaw
Categories=Development;
Terminal=false
EOF

echo "NOTE: [node] done"
