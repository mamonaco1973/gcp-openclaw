#!/bin/bash
set -euo pipefail

# ================================================================================
# Google Chrome
# ================================================================================

echo "NOTE: [chrome] adding Google signing key"
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
  | gpg --dearmor -o /usr/share/keyrings/google-linux-keyring.gpg

echo "NOTE: [chrome] adding Chrome APT repository"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-keyring.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
  | tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

echo "NOTE: [chrome] installing Google Chrome Stable"
apt-get update -y
apt-get install -y google-chrome-stable

echo "NOTE: [chrome] $(google-chrome --version)"

echo "NOTE: [chrome] allowing unprivileged user namespaces for the sandbox"
# Ubuntu 24.04 confines unprivileged user namespaces with AppArmor, which is
# exactly the primitive Chrome's sandbox is built on: without this, Chrome
# refuses to start unless launched with --no-sandbox.  Passing that flag makes
# Chrome run with no sandbox at all AND raises a permanent "unsupported
# command-line flag" banner across the top of every window.
#
# Lifting the restriction instead lets the real sandbox work, so the banner
# goes away and the browser is actually more isolated, not less.  The trade is
# that unprivileged userns become available machine-wide -- acceptable on a
# single-user desktop instance whose only exposed port is RDP.
cat > /etc/sysctl.d/60-chrome-userns.conf <<'EOF'
kernel.apparmor_restrict_unprivileged_userns=0
EOF
# Apply now as well as at boot: later build steps launch Chrome.
sysctl --system >/dev/null

echo "NOTE: [chrome] configuring flags for headless desktop use"
# Wrap the chrome binary so the desktop-hygiene flags are always passed.
# --disable-dev-shm-usage stays: /dev/shm is small on these machine types and
# Chrome crashes without it.  --no-sandbox is deliberately NOT here (see above).
mv /usr/bin/google-chrome /usr/bin/google-chrome-real
cat > /usr/bin/google-chrome <<'EOF'
#!/bin/bash
exec /usr/bin/google-chrome-real \
  --disable-dev-shm-usage \
  --no-first-run \
  --no-default-browser-check \
  --disable-sync \
  --disable-extensions \
  --disable-default-apps \
  "$@"
EOF
chmod 755 /usr/bin/google-chrome

echo "NOTE: [chrome] applying enterprise policies (suppress sign-in prompts)"
mkdir -p /etc/opt/chrome/policies/managed
cat > /etc/opt/chrome/policies/managed/openclaw.json <<'EOF'
{
  "BrowserSignin": 0,
  "SyncDisabled": true,
  "PromotionalTabsEnabled": false,
  "WelcomePageOnOSUpgradeEnabled": false
}
EOF

echo "NOTE: [chrome] suppressing first-run welcome page"
mkdir -p /etc/opt/chrome
cat > /etc/opt/chrome/initial_preferences <<'EOF'
{
  "browser": {
    "check_default_browser": false
  },
  "distribution": {
    "skip_first_run_ui": true,
    "show_welcome_page": false,
    "suppress_first_run_default_browser_prompt": true
  },
  "first_run_tabs": [],
  "sync_promo": {
    "user_skipped": true
  }
}
EOF

echo "NOTE: [chrome] done"
