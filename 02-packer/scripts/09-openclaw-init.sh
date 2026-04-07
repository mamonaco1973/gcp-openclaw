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

echo "NOTE: [openclaw-init] writing placeholder litellm config"
mkdir -p /opt/openclaw
cat > /opt/openclaw/litellm-config.yaml <<'LITELLM'
model_list:
  - model_name: gemini-flash
    litellm_params:
      model: vertex_ai/gemini-2.0-flash-001
      vertex_project: placeholder
      vertex_location: us-central1

  - model_name: gemini-pro
    litellm_params:
      model: vertex_ai/gemini-2.0-pro-001
      vertex_project: placeholder
      vertex_location: us-central1

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

echo "NOTE: [openclaw-init] configuring litellm model provider"
sudo -u openclaw env HOME=/home/openclaw PATH="${PATH}" bash -c "
  ${OPENCLAW_BIN} config set gateway.mode local || true
  ${OPENCLAW_BIN} config set gateway.auth.mode none || true
  ${OPENCLAW_BIN} config set models.providers.litellm \
    '{\"baseUrl\":\"http://localhost:4000\",\"apiKey\":\"sk-openclaw\",\"models\":[{\"id\":\"gemini-flash\",\"name\":\"Gemini 2.0 Flash\",\"api\":\"openai\"},{\"id\":\"gemini-pro\",\"name\":\"Gemini 2.0 Pro\",\"api\":\"openai\"}]}' \
    --strict-json || true
  ${OPENCLAW_BIN} models set litellm/gemini-pro || true
  ${OPENCLAW_BIN} models set litellm/gemini-flash || true
  ${OPENCLAW_BIN} config set agents.defaults.model.primary litellm/gemini-flash || true
  ${OPENCLAW_BIN} approvals allowlist add --agent '*' '/**' || true
  ${OPENCLAW_BIN} approvals allowlist add --agent 'main' '/**' || true
"

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
- **Email**: Send email via `mail` command (msmtp SMTP): `echo "body" | mail -s "Subject" recipient@example.com`
- **Cost Report**: Run `gcp-cost-report` via exec to generate a GCP cost summary.
- **Send Cost Report**: Run `send-cost-report <email>` via exec — generates an HTML cost report and emails it via msmtp.

Read SYSTEM.md in this workspace for the full list of installed tools and capabilities.
HEARTBEAT

cat > "${WORKSPACE}/SYSTEM.md" <<'SYSTEM'
# System Capabilities

This instance has the following tools and capabilities available via exec.

## Email
msmtp is configured system-wide with SMTP credentials (injected at boot).
Use the `mail` command to send email — no additional setup needed.

```bash
# Plain text
echo "Body here" | mail -s "Subject" recipient@example.com

# With attachment
echo "See attached." | mail -s "Subject" -A /path/to/file.docx recipient@example.com
```

## GCP Cost Reporting
```bash
gcp-cost-report              # Print cost summary to stdout
send-cost-report user@example.com  # Email HTML cost report
```

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
