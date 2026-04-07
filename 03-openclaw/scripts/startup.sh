#!/bin/bash
set -euo pipefail

# Centralized startup logging
LOG=/root/startup.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t startup -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "NOTE: startup start: $(date -Is)"


# ================================================================================
# Credentials
# ================================================================================

echo "NOTE: [credentials] reading openclaw credentials from Secret Manager"
secret=$(gcloud secrets versions access latest --secret="openclaw-credentials")

OPENCLAW_PASSWORD=$(echo "$secret" | jq -r '.password')

echo "NOTE: [credentials] setting openclaw user password"
echo "openclaw:$${OPENCLAW_PASSWORD}" | chpasswd
echo "NOTE: [credentials] done"


# ================================================================================
# LiteLLM Config
# ================================================================================

echo "NOTE: [litellm] writing config"
cat > /opt/openclaw/litellm-config.yaml <<LITELLM
model_list:
  - model_name: gemini-flash
    litellm_params:
      model: vertex_ai/${primary_model}
      vertex_project: ${project_id}
      vertex_location: us-central1

  - model_name: gemini-pro
    litellm_params:
      model: vertex_ai/${secondary_model}
      vertex_project: ${project_id}
      vertex_location: us-central1

general_settings:
  master_key: "sk-openclaw"
  drop_params: true
LITELLM
chown openclaw:openclaw /opt/openclaw/litellm-config.yaml
echo "NOTE: [litellm] config written"


# ================================================================================
# SMTP / Email
# ================================================================================

echo "NOTE: [smtp] reading SMTP credentials from Secret Manager"
smtp_secret=$(gcloud secrets versions access latest --secret="openclaw-smtp" 2>/dev/null || echo "{}")

SMTP_HOST=$(echo "$smtp_secret" | jq -r '.smtp_host // empty')
SMTP_PORT=$(echo "$smtp_secret" | jq -r '.smtp_port // empty')
SMTP_USERNAME=$(echo "$smtp_secret" | jq -r '.smtp_username // empty')
SMTP_PASSWORD=$(echo "$smtp_secret" | jq -r '.smtp_password // empty')
SMTP_FROM=$(echo "$smtp_secret" | jq -r '.from_email // empty')

if [ -n "$SMTP_HOST" ] && [ "$SMTP_HOST" != "smtp.example.com" ]; then
  echo "NOTE: [smtp] configuring msmtp"
  cat > /etc/msmtprc <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        smtp
host           $${SMTP_HOST}
port           $${SMTP_PORT}
from           $${SMTP_FROM}
user           $${SMTP_USERNAME}
password       $${SMTP_PASSWORD}

account default : smtp
EOF
  chmod 600 /etc/msmtprc
  touch /var/log/msmtp.log
  chmod 666 /var/log/msmtp.log

  cp /etc/msmtprc /home/openclaw/.msmtprc
  chown openclaw:openclaw /home/openclaw/.msmtprc
  chmod 600 /home/openclaw/.msmtprc

  mkdir -p /etc/systemd/system/openclaw-gateway.service.d
  cat > /etc/systemd/system/openclaw-gateway.service.d/smtp.conf <<EOF
[Service]
Environment="SMTP_HOST=$${SMTP_HOST}"
Environment="SMTP_PORT=$${SMTP_PORT}"
Environment="SMTP_USERNAME=$${SMTP_USERNAME}"
Environment="SMTP_PASSWORD=$${SMTP_PASSWORD}"
Environment="SMTP_FROM=$${SMTP_FROM}"
EOF
  systemctl daemon-reload
  echo "NOTE: [smtp] done"
else
  echo "NOTE: [smtp] dummy or missing credentials, skipping msmtp config"
fi


# ================================================================================
# Start Services
# ================================================================================

echo "NOTE: [services] starting litellm"
systemctl restart litellm

echo "NOTE: [services] starting openclaw-gateway"
systemctl restart openclaw-gateway

# First-boot only: configure openclaw model provider after gateway stamps config
FIRST_BOOT_FLAG="/etc/openclaw-configured"
if [ ! -f "$${FIRST_BOOT_FLAG}" ]; then
  echo "NOTE: [openclaw] first boot detected — configuring model provider"

  # Wait for gateway to finish stamping its config
  sleep 20

  OPENCLAW_BIN=$(which openclaw)
  sudo -u openclaw env HOME=/home/openclaw PATH="$${PATH}" bash -c "
    $${OPENCLAW_BIN} config set models.providers.litellm \
      '{\"baseUrl\":\"http://localhost:4000\",\"apiKey\":\"sk-openclaw\",\"models\":[{\"id\":\"gemini-flash\",\"name\":\"Gemini 2.5 Flash\",\"api\":\"openai-responses\"},{\"id\":\"gemini-pro\",\"name\":\"Gemini 2.5 Pro\",\"api\":\"openai-responses\"}]}' \
      --strict-json
    $${OPENCLAW_BIN} config set agents.defaults.model.primary litellm/gemini-pro
    $${OPENCLAW_BIN} approvals allowlist add --agent '*' '/**'
    $${OPENCLAW_BIN} approvals allowlist add --agent 'main' '/**'
  "

  echo "NOTE: [openclaw] restarting gateway to apply model config"
  systemctl restart openclaw-gateway

  touch "$${FIRST_BOOT_FLAG}"
  echo "NOTE: [openclaw] first boot configuration complete"
else
  echo "NOTE: [openclaw] not first boot — skipping model config"
fi

echo "NOTE: [services] done"

echo "NOTE: startup complete: $(date -Is)"
