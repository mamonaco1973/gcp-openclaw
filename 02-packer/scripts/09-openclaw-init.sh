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
#   1. Start litellm with a placeholder config so models auth can connect.
#   2. Run openclaw gateway in background as openclaw user (stamps config).
#   3. Configure the litellm model provider via CLI.
#   4. Stop both processes — config is persisted at /home/openclaw/.openclaw.
#
# ================================================================================

echo "NOTE: [openclaw-init] writing placeholder litellm config"
mkdir -p /opt/openclaw
cat > /opt/openclaw/litellm-config.yaml <<'LITELLM'
model_list:
  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/us.anthropic.claude-sonnet-4-5-20250929-v1:0
      aws_region_name: us-east-1

  - model_name: claude-haiku
    litellm_params:
      model: bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0
      aws_region_name: us-east-1

  - model_name: nova-pro
    litellm_params:
      model: bedrock/us.amazon.nova-pro-v1:0
      aws_region_name: us-east-1

  - model_name: nova-lite
    litellm_params:
      model: bedrock/us.amazon.nova-lite-v1:0
      aws_region_name: us-east-1

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
    '{\"baseUrl\":\"http://localhost:4000\",\"apiKey\":\"sk-openclaw\",\"models\":[{\"id\":\"claude-sonnet\",\"name\":\"Claude Sonnet (Bedrock)\"},{\"id\":\"claude-haiku\",\"name\":\"Claude Haiku (Bedrock)\"},{\"id\":\"nova-pro\",\"name\":\"Amazon Nova Pro (Bedrock)\"},{\"id\":\"nova-lite\",\"name\":\"Amazon Nova Lite (Bedrock)\"}]}' \
    --strict-json || true
  ${OPENCLAW_BIN} models set litellm/nova-lite || true
  ${OPENCLAW_BIN} models set litellm/nova-pro || true
  ${OPENCLAW_BIN} models set litellm/claude-haiku || true
  ${OPENCLAW_BIN} models set litellm/claude-sonnet || true
  ${OPENCLAW_BIN} config set agents.defaults.model.primary litellm/claude-sonnet || true
  ${OPENCLAW_BIN} approvals allowlist add --agent '*' '/**' || true
  ${OPENCLAW_BIN} approvals allowlist add --agent 'main' '/**' || true
"

echo "NOTE: [openclaw-init] stopping all openclaw and litellm processes"
# Kill all processes running as the openclaw user — this catches the gateway,
# any restarted child processes, node workers, and uvicorn/litellm children
# that pkill -f misses.
pkill -u openclaw 2>/dev/null || true
sleep 3
# Force-kill anything still alive
pkill -9 -u openclaw 2>/dev/null || true
rm -f /tmp/openclaw-init.pid

echo "NOTE: [openclaw-init] writing workspace files"
WORKSPACE=/home/openclaw/.openclaw/workspace
mkdir -p "${WORKSPACE}"

cat > "${WORKSPACE}/HEARTBEAT.md" <<'HEARTBEAT'
# System Context

You are running on an AWS EC2 instance with the following capabilities:

- **exec tool**: Full shell access — use it to run commands directly. Never ask the user to run commands manually.
- **AWS CLI**: Pre-authenticated via instance IAM role. No credentials needed. Run aws commands directly via exec.
- **Email**: Send email via `mail` command (msmtp + AWS SES SMTP): `echo "body" | mail -s "Subject" recipient@example.com`
- **Cost Explorer**: Use `aws ce get-cost-and-usage` — the IAM role has Cost Explorer access.

Read SYSTEM.md in this workspace for the full list of installed tools and capabilities.
HEARTBEAT

cat > "${WORKSPACE}/CLAUDE.md" <<'CLAUDE'
You have full exec access via the exec tool. The AWS CLI is installed and
pre-authenticated via the instance IAM role — no credentials needed. Use
exec to run AWS CLI commands directly to complete any AWS task.

To send email use the AWS CLI via exec:
  aws ses send-email \
    --from "you@example.com" \
    --destination "ToAddresses=you@example.com" \
    --message "Subject={Data=Subject},Body={Text={Data=Body}}" \
    --region us-east-1

The from address is in /etc/msmtprc — read it with: grep '^from' /etc/msmtprc | awk '{print $2}'

Never tell the user to do something manually that you can do yourself via exec.
CLAUDE

echo "NOTE: [openclaw-init] writing SYSTEM.md to workspace"
cat > "${WORKSPACE}/SYSTEM.md" <<'SYSTEM'
# System Capabilities

This instance has the following tools and capabilities available via exec.

## Email
msmtp is configured system-wide with AWS SES SMTP credentials.
Use the `mail` command to send email — no additional setup needed.

**Important:** The IAM role does NOT have SES API permissions. Do not use
`aws ses send-email` or boto3 SES calls — they will fail. Always use the
`mail` command via msmtp, which uses pre-configured SMTP credentials.

```bash
# Plain text
echo "Body here" | mail -s "Subject" recipient@example.com

# With attachment
echo "See attached." | mail -s "Subject" -A /path/to/file.docx recipient@example.com
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
- **imagemagick** — image manipulation (convert, resize, crop)
- **ffmpeg** — video/audio processing
- **poppler-utils** — PDF utilities (pdftotext, pdfinfo)
- **ghostscript** — PDF manipulation

## Cloud
- **AWS CLI** — configured via instance IAM role (no credentials needed)
  - Bedrock, S3, Cost Explorer, Secrets Manager, SES
- **Terraform**, **Packer** — infrastructure tools
- **gcloud**, **az** — Google Cloud and Azure CLIs

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
processing, AWS CLI, etc.). Keep that file around after onboarding.
EOF
fi

echo "NOTE: [openclaw-init] config directory contents:"
ls -la /home/openclaw/.openclaw/ 2>/dev/null || echo "(empty)"

echo "NOTE: [openclaw-init] done"
