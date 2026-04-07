#!/bin/bash
set -euo pipefail

# Centralized user-data logging
LOG=/root/userdata.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "NOTE: user-data start: $(date -Is)"


# ================================================================================
# Credentials
# ================================================================================

echo "NOTE: [credentials] reading openclaw credentials from Secrets Manager"
secret=$(aws secretsmanager get-secret-value \
  --secret-id openclaw_credentials \
  --query SecretString \
  --output text)

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
  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/${bedrock_model_id}
      aws_region_name: us-east-1

  - model_name: claude-haiku
    litellm_params:
      model: bedrock/${haiku_model_id}
      aws_region_name: us-east-1

  - model_name: nova-pro
    litellm_params:
      model: bedrock/${nova_pro_model_id}
      aws_region_name: us-east-1

  - model_name: nova-lite
    litellm_params:
      model: bedrock/${nova_lite_model_id}
      aws_region_name: us-east-1

general_settings:
  master_key: "sk-openclaw"
  drop_params: true
LITELLM
chown openclaw:openclaw /opt/openclaw/litellm-config.yaml
echo "NOTE: [litellm] config written"


# ================================================================================
# Start Services
# ================================================================================

echo "NOTE: [ses] reading SMTP credentials from Secrets Manager"
ses_secret=$(aws secretsmanager get-secret-value \
  --secret-id openclaw_ses_smtp \
  --query SecretString \
  --output text 2>/dev/null || echo "{}")

SMTP_HOST=$(echo "$ses_secret" | jq -r '.smtp_host // empty')
SMTP_PORT=$(echo "$ses_secret" | jq -r '.smtp_port // empty')
SMTP_USERNAME=$(echo "$ses_secret" | jq -r '.smtp_username // empty')
SMTP_PASSWORD=$(echo "$ses_secret" | jq -r '.smtp_password // empty')
SMTP_FROM=$(echo "$ses_secret" | jq -r '.from_email // empty')

if [ -n "$SMTP_HOST" ]; then
  echo "NOTE: [ses] injecting SMTP credentials into gateway service"
  mkdir -p /etc/systemd/system/openclaw-gateway.service.d
  cat > /etc/systemd/system/openclaw-gateway.service.d/ses.conf <<EOF
[Service]
Environment="SMTP_HOST=$${SMTP_HOST}"
Environment="SMTP_PORT=$${SMTP_PORT}"
Environment="SMTP_USERNAME=$${SMTP_USERNAME}"
Environment="SMTP_PASSWORD=$${SMTP_PASSWORD}"
Environment="SMTP_FROM=$${SMTP_FROM}"
EOF
  systemctl daemon-reload

  echo "NOTE: [ses] configuring msmtp for system-wide email sending"
  cat > /etc/msmtprc <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        ses
host           $${SMTP_HOST}
port           $${SMTP_PORT}
from           $${SMTP_FROM}
user           $${SMTP_USERNAME}
password       $${SMTP_PASSWORD}

account default : ses
EOF
  chmod 600 /etc/msmtprc
  touch /var/log/msmtp.log
  chmod 666 /var/log/msmtp.log

  cp /etc/msmtprc /home/openclaw/.msmtprc
  chown openclaw:openclaw /home/openclaw/.msmtprc
  chmod 600 /home/openclaw/.msmtprc

  echo "NOTE: [ses] writing email capability note to agent workspace"
  mkdir -p /home/openclaw/.openclaw/agents/main/workspace
  cat > /home/openclaw/.openclaw/agents/main/workspace/EMAIL.md <<EOF
# Email Sending

msmtp is configured system-wide with AWS SES SMTP credentials.
Use the \`mail\` command via exec to send email — no additional setup needed.

## Send a plain text email
\`\`\`bash
echo "Message body here" | mail -s "Subject" recipient@example.com
\`\`\`

## Send with a file attachment
\`\`\`bash
mail -s "Subject" -A /path/to/file.docx recipient@example.com < /dev/null
\`\`\`

## Send with body and attachment
\`\`\`bash
echo "Please find the report attached." | mail -s "Report" -A /path/to/report.docx recipient@example.com
\`\`\`

From address: $${SMTP_FROM}
EOF
  chown -R openclaw:openclaw /home/openclaw/.openclaw/agents/main/workspace

  echo "NOTE: [ses] done"
else
  echo "NOTE: [ses] no SES secret found, skipping"
fi


echo "NOTE: [services] starting litellm"
systemctl start litellm

echo "NOTE: [services] starting openclaw-gateway"
systemctl start openclaw-gateway

echo "NOTE: [services] done"

echo "NOTE: user-data complete: $(date -Is)"
