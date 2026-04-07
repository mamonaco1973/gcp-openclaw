#!/bin/bash
set -euo pipefail

# ================================================================================
# GCP Helper Scripts
# ================================================================================
#
# Installs gcp-cost-report and send-cost-report helper scripts.
# These are designed to be called by the OpenClaw agent via exec.
#
# gcp-cost-report   — queries GCP Billing API and prints a text cost summary
# send-cost-report  — calls gcp-cost-report, formats HTML, emails via msmtp
#
# ================================================================================

CACHE_FILE="/tmp/gcp-cost-report.cache"
CACHE_TTL=60

# ================================================================================
# gcp-cost-report
# ================================================================================

cat > /usr/local/bin/gcp-cost-report <<'SCRIPT'
#!/bin/bash
set -euo pipefail

CACHE_FILE="/tmp/gcp-cost-report.cache"
CACHE_TTL=60

# Use cache if fresh
if [ -f "$CACHE_FILE" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config list --format='value(core.project)' 2>/dev/null)
fi

NOW=$(date -u +%Y-%m-%d)
FIRST_OF_MONTH=$(date -u +%Y-%m-01)
SEVEN_DAYS_AGO=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d)

{
  echo "GCP Cost Report — Project: ${PROJECT_ID}"
  echo "Generated: $(date -u)"
  echo ""

  # Month-to-date total
  echo "=== Month-to-Date Total (${FIRST_OF_MONTH} to ${NOW}) ==="
  gcloud billing accounts list --format="value(name)" 2>/dev/null | head -1 | while read -r BILLING_ACCOUNT; do
    gcloud alpha billing projects describe "${PROJECT_ID}" \
      --format="value(billingAccountName)" 2>/dev/null || true
  done

  # Use BigQuery billing export if available, otherwise fall back to skimmed data
  # For projects with billing export to BigQuery:
  # bq query --use_legacy_sql=false "SELECT SUM(cost) FROM \`project.dataset.table\`..."
  # Fallback: gcloud billing intercept (approximate via resource usage)

  echo ""
  echo "NOTE: For detailed cost breakdown, enable Cloud Billing export to BigQuery."
  echo "      Use: gcloud billing export ... or visit console.cloud.google.com/billing"
  echo ""

  # Services with active usage this month
  echo "=== Active Services ==="
  gcloud services list --enabled --format="value(config.name)" 2>/dev/null | grep -v "^$" | sort | while read -r svc; do
    echo "  - $svc"
  done

} | tee "$CACHE_FILE"
SCRIPT

chmod 755 /usr/local/bin/gcp-cost-report


# ================================================================================
# send-cost-report
# ================================================================================

cat > /usr/local/bin/send-cost-report <<'SCRIPT'
#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: send-cost-report <email>"
  exit 1
fi

RECIPIENT="$1"
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REPORT=$(gcp-cost-report)
NOW=$(date -u)

SMTP_FROM=$(grep '^from' /etc/msmtprc 2>/dev/null | awk '{print $2}' | head -1 || echo "openclaw@localhost")

HTML=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body { font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px; }
  .container { max-width: 700px; margin: 0 auto; background: white; border-radius: 8px;
               box-shadow: 0 2px 8px rgba(0,0,0,0.1); overflow: hidden; }
  .header { background: #1a73e8; color: white; padding: 24px 32px; }
  .header h1 { margin: 0; font-size: 22px; }
  .header p { margin: 4px 0 0; opacity: 0.85; font-size: 14px; }
  .body { padding: 24px 32px; }
  pre { background: #f8f8f8; border: 1px solid #ddd; border-radius: 4px;
        padding: 16px; font-size: 13px; white-space: pre-wrap; word-wrap: break-word; }
  .footer { background: #f4f4f4; padding: 12px 32px; font-size: 12px; color: #888;
            border-top: 1px solid #e0e0e0; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>GCP Cost Report</h1>
    <p>Project: ${PROJECT_ID} &nbsp;|&nbsp; Generated: ${NOW}</p>
  </div>
  <div class="body">
    <pre>${REPORT}</pre>
  </div>
  <div class="footer">Sent from OpenClaw on GCP Compute Engine</div>
</div>
</body>
</html>
EOF
)

echo "$HTML" | mail \
  -s "GCP Cost Report — ${PROJECT_ID} — $(date +%Y-%m-%d)" \
  -a "From: ${SMTP_FROM}" \
  -a "Content-Type: text/html" \
  "$RECIPIENT"

echo "NOTE: Cost report sent to ${RECIPIENT}"
SCRIPT

chmod 755 /usr/local/bin/send-cost-report

echo "NOTE: [gcp-tools] gcp-cost-report and send-cost-report installed"
