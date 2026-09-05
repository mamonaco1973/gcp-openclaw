#!/bin/bash
set -euo pipefail

# ================================================================================
# OpenClaw Config Initialization
# ================================================================================
#
# Runs the openclaw gateway briefly as the openclaw user to stamp the config
# file with internal metadata. Without this step, openclaw detects a
# "missing-meta-before-write" condition on first launch and overwrites any
# pre-written config with defaults, discarding the litellm provider settings.
#
# Flow:
#   1. Start litellm with a placeholder config so model auth can connect.
#   2. Run openclaw gateway in background as openclaw user (stamps config).
#   3. Configure the litellm model provider via CLI.
#   4. Stop both processes — config is persisted at /home/openclaw/.openclaw.
#
# ================================================================================

# Placeholder only: startup.sh rewrites this file at first boot from
# gemini-config.sh, and vertex_project is not even real here. It exists so
# LiteLLM will start and the gateway can stamp its config during the build.
# The ids are still kept off the retiring 2.5 family so nothing in the image
# advertises a model this project no longer deploys.
echo "NOTE: [openclaw-init] writing placeholder litellm config"
mkdir -p /opt/openclaw
cat > /opt/openclaw/litellm-config.yaml <<'LITELLM'
model_list:
  - model_name: gemini-primary
    litellm_params:
      model: vertex_ai/gemini-3.8-flash
      vertex_project: placeholder
      vertex_location: global

general_settings:
  master_key: "sk-openclaw"
  drop_params: true
LITELLM
chown openclaw:openclaw /opt/openclaw/litellm-config.yaml

echo "NOTE: [openclaw-init] starting litellm placeholder"
sudo -u openclaw /opt/litellm-venv/bin/litellm \
  --config /opt/openclaw/litellm-config.yaml --port 4000 &
LITELLM_PID=$!
sleep 8

OPENCLAW_BIN=$(which openclaw)
echo "NOTE: [openclaw-init] openclaw binary: ${OPENCLAW_BIN}"

echo "NOTE: [openclaw-init] starting openclaw gateway to stamp config metadata"
sudo -u openclaw env HOME=/home/openclaw PATH="${PATH}" bash -c "
  ${OPENCLAW_BIN} gateway run \
    --allow-unconfigured --bind loopback --port 18789 &
  echo \$! > /tmp/openclaw-init.pid
"
sleep 12

echo "NOTE: [openclaw-init] configuring gateway settings"
sudo -u openclaw env HOME=/home/openclaw PATH="${PATH}" bash -c "
  ${OPENCLAW_BIN} config set gateway.mode local || true
  ${OPENCLAW_BIN} config set gateway.auth.mode none || true
  ${OPENCLAW_BIN} approvals allowlist add --agent '*' '/**' || true
  ${OPENCLAW_BIN} approvals allowlist add --agent 'main' '/**' || true
"
# Note: model provider config is set in startup.sh at first boot, after the
# gateway has stamped its config — setting it here gets overwritten on restart.

echo "NOTE: [openclaw-init] stopping all openclaw and litellm processes"
pkill -u openclaw 2>/dev/null || true
sleep 3
pkill -9 -u openclaw 2>/dev/null || true
rm -f /tmp/openclaw-init.pid

echo "NOTE: [openclaw-init] writing workspace files"
WORKSPACE=/home/openclaw/.openclaw/workspace
mkdir -p "${WORKSPACE}"

cat > "${WORKSPACE}/HEARTBEAT.md" <<'HEARTBEAT'
# System Context

You are running on a GCP Compute Engine VM with the following capabilities:

- **exec tool**: Full shell access — use it to run commands directly. Never ask the user to run commands manually.
- **gcloud CLI**: Pre-authenticated via VM service account. No credentials needed. Run gcloud commands directly via exec.
- **Email**: Send email via `gcp-mail` (from address pre-configured): `echo "body" | gcp-mail -s "Subject" recipient@example.com`
- **Infrastructure Report**: Run `gcp-infra-report` via exec to generate a GCP infrastructure snapshot.
- **Send Infrastructure Report**: Run `send-infra-report <email>` via exec — generates an HTML infrastructure snapshot and emails it via msmtp.
- **Web**: Apache2 serves /var/www/html (world-writable) at http://localhost/ — write a file there and open it in the browser.

Read SYSTEM.md in this workspace for the full list of installed tools and capabilities.
HEARTBEAT

cat > "${WORKSPACE}/SYSTEM.md" <<'SYSTEM'
# System Capabilities

This instance has the following tools and capabilities available via exec.

## Email
msmtp is configured system-wide with SMTP credentials (injected at boot).
Use the `gcp-mail` wrapper — from address is pre-configured, no extra flags needed.

```bash
# Plain text
echo "Body here" | gcp-mail -s "Subject" recipient@example.com

# HTML
echo "<h1>Hello</h1>" | gcp-mail -s "Subject" -a "Content-Type: text/html" recipient@example.com
```

## GCP Infrastructure Reporting
```bash
gcp-infra-report                       # Print infrastructure snapshot to stdout
send-infra-report user@example.com     # Email HTML infrastructure snapshot
```

## Web publishing
Apache2 is installed and running. The document root is `/var/www/html`, and it
is world-writable, so you can publish a page with the exec tool and no sudo:

```bash
echo "<h1>hello</h1>" > /var/www/html/index.html
```

It is then served at http://localhost/ — open that with the browser tool to
show the user the result. Port 80 is not reachable from outside the instance,
so this is for showing things on the desktop, not for publishing to the web.

Anything self-contained works: a single HTML file, or HTML plus CSS and
JavaScript. Write the files, then open the page to demonstrate it.

## Document Processing
- **python-docx** — read/write Word documents
- **python-pptx** — read/write PowerPoint files
- **openpyxl** — read/write Excel files
- **pymupdf** — read/extract PDF content
- **reportlab** — generate PDFs
- **pandoc** — convert between document formats
- **OnlyOffice** — desktop app for editing DOCX/XLSX/PPTX files

## Data & Analysis
- **pandas**, **numpy** — data analysis
- **matplotlib** — charts and visualizations
- **sqlite3** — local database

## Web & HTTP
- **curl**, **wget** — HTTP requests
- **beautifulsoup4**, **lxml** — HTML parsing
- **httpx**, **requests** — Python HTTP

## Media
- **imagemagick** — image manipulation
- **ffmpeg** — video/audio processing
- **poppler-utils** — PDF utilities
- **ghostscript** — PDF manipulation

## Cloud
- **gcloud** — pre-authenticated via VM service account (no credentials needed)
  - Vertex AI, Secret Manager, Billing, Cloud Storage
- **AWS CLI**, **az** — multi-cloud CLIs (require separate authentication)
- **Terraform**, **Packer** — infrastructure tools

## File System
- Workspace: `~/.openclaw/workspace` (also accessible as `~/Openclaw/workspace`)
- Home: `/home/openclaw`

## Utilities
- **jq** — JSON processing
- **csvkit** — CSV tools
- **xmlstarlet** — XML processing
- **Rich** (Python) — formatted terminal output
SYSTEM

chown -R openclaw:openclaw "${WORKSPACE}"

echo "NOTE: [openclaw-init] appending SYSTEM.md reference to BOOTSTRAP.md"
BOOTSTRAP="${WORKSPACE}/BOOTSTRAP.md"
if [ -f "${BOOTSTRAP}" ]; then
  cat >> "${BOOTSTRAP}" <<'EOF'

---

## This System

Before you delete this file, read `SYSTEM.md` in this workspace — it lists
the tools, commands, and capabilities available on this machine (email, document
processing, gcloud CLI, etc.). Keep that file around after onboarding.
EOF
fi

echo "NOTE: [openclaw-init] config directory contents:"
ls -la /home/openclaw/.openclaw/ 2>/dev/null || echo "(empty)"

echo "NOTE: [openclaw-init] done"
