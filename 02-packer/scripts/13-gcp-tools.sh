#!/bin/bash
set -euo pipefail

# ================================================================================
# GCP Helper Scripts
# ================================================================================
#
# Installs gcp-infra-report and send-infra-report helper scripts.
# These are designed to be called by the OpenClaw agent via exec.
#
# gcp-infra-report   — queries GCP APIs and prints an infrastructure snapshot
# send-infra-report  — calls gcp-infra-report, formats HTML, emails via msmtp
#
# ================================================================================

CACHE_FILE="/tmp/gcp-infra-report.cache"
CACHE_TTL=300


# ================================================================================
# gcp-infra-report
# ================================================================================

cat > /usr/local/bin/gcp-infra-report <<'SCRIPT'
#!/bin/bash
set -euo pipefail

CACHE_FILE="/tmp/gcp-infra-report.cache"
CACHE_TTL=300

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

{
  echo "GCP Infrastructure Snapshot — Project: ${PROJECT_ID}"
  echo "Generated: $(date -u)"
  echo ""

  # ── Compute Instances ──────────────────────────────────────────────────────
  echo "=== Compute Instances ==="
  INSTANCES=$(gcloud compute instances list \
    --format="table[no-heading](name,zone.basename(),machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP.yesno(yes='public',no='internal'))" \
    2>/dev/null || true)
  if [ -n "${INSTANCES}" ]; then
    printf "  %-30s %-15s %-18s %-10s %s\n" "NAME" "ZONE" "MACHINE TYPE" "STATUS" "ACCESS"
    echo "${INSTANCES}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No instances found."
  fi
  echo ""

  # ── Disks ──────────────────────────────────────────────────────────────────
  echo "=== Disks ==="
  DISKS=$(gcloud compute disks list \
    --format="table[no-heading](name,zone.basename(),sizeGb,type.basename(),status)" \
    2>/dev/null || true)
  if [ -n "${DISKS}" ]; then
    printf "  %-40s %-15s %-8s %-15s %s\n" "NAME" "ZONE" "SIZE GB" "TYPE" "STATUS"
    echo "${DISKS}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No disks found."
  fi
  echo ""

  # ── Custom Images ──────────────────────────────────────────────────────────
  echo "=== Custom Images ==="
  IMAGES=$(gcloud compute images list --no-standard-images \
    --format="table[no-heading](name,family,diskSizeGb,status,creationTimestamp.date('%Y-%m-%d'))" \
    2>/dev/null || true)
  if [ -n "${IMAGES}" ]; then
    printf "  %-45s %-20s %-8s %-10s %s\n" "NAME" "FAMILY" "SIZE GB" "STATUS" "CREATED"
    echo "${IMAGES}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No custom images found."
  fi
  echo ""

  # ── Firewall Rules ─────────────────────────────────────────────────────────
  echo "=== Firewall Rules ==="
  FW=$(gcloud compute firewall-rules list \
    --format="table[no-heading](name,direction,allowed[].map().firewall_rule().list():label=ALLOW,sourceRanges.list())" \
    2>/dev/null || true)
  if [ -n "${FW}" ]; then
    echo "${FW}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No firewall rules found."
  fi
  echo ""

  # ── Secret Manager ─────────────────────────────────────────────────────────
  echo "=== Secrets ==="
  SECRETS=$(gcloud secrets list \
    --format="table[no-heading](name,createTime.date('%Y-%m-%d'),replication.automatic.yesno(yes='auto',no='manual'))" \
    2>/dev/null || true)
  if [ -n "${SECRETS}" ]; then
    printf "  %-40s %-12s %s\n" "NAME" "CREATED" "REPLICATION"
    echo "${SECRETS}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No secrets found."
  fi
  echo ""

  # ── VPC / Subnets ──────────────────────────────────────────────────────────
  echo "=== Networks ==="
  NETWORKS=$(gcloud compute networks list \
    --format="table[no-heading](name,autoCreateSubnetworks,subnetworks.len():label=SUBNETS)" \
    2>/dev/null || true)
  if [ -n "${NETWORKS}" ]; then
    echo "${NETWORKS}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No networks found."
  fi
  echo ""

  # ── Storage Buckets ────────────────────────────────────────────────────────
  echo "=== Storage Buckets ==="
  BUCKETS=$(gcloud storage buckets list \
    --format="table[no-heading](name,location,storageClass)" \
    2>/dev/null || true)
  if [ -n "${BUCKETS}" ]; then
    printf "  %-45s %-15s %s\n" "NAME" "LOCATION" "CLASS"
    echo "${BUCKETS}" | while read -r line; do
      printf "  %s\n" "${line}"
    done
  else
    echo "  No storage buckets found."
  fi

} | tee "$CACHE_FILE"
SCRIPT

chmod 755 /usr/local/bin/gcp-infra-report


# ================================================================================
# send-infra-report
# ================================================================================

cat > /usr/local/bin/send-infra-report <<'SCRIPT'
#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: send-infra-report <email>"
  exit 1
fi

RECIPIENT="$1"
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REPORT=$(gcp-infra-report)
NOW=$(date -u)

SMTP_FROM=$(grep '^from' /etc/msmtprc 2>/dev/null | awk '{print $2}' | head -1 || echo "openclaw@localhost")

HTML=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body { font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px; }
  .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 8px;
               box-shadow: 0 2px 8px rgba(0,0,0,0.1); overflow: hidden; }
  .header { background: #1a73e8; color: white; padding: 24px 32px; }
  .header h1 { margin: 0; font-size: 22px; }
  .header p { margin: 4px 0 0; opacity: 0.85; font-size: 14px; }
  .body { padding: 24px 32px; }
  pre { background: #f8f8f8; border: 1px solid #ddd; border-radius: 4px;
        padding: 16px; font-size: 12px; white-space: pre-wrap; word-wrap: break-word; }
  .footer { background: #f4f4f4; padding: 12px 32px; font-size: 12px; color: #888;
            border-top: 1px solid #e0e0e0; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>GCP Infrastructure Snapshot</h1>
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
  -s "GCP Infrastructure Snapshot — ${PROJECT_ID} — $(date +%Y-%m-%d)" \
  -a "From: ${SMTP_FROM}" \
  -a "Content-Type: text/html" \
  "$RECIPIENT"

echo "NOTE: Infrastructure report sent to ${RECIPIENT}"
SCRIPT

chmod 755 /usr/local/bin/send-infra-report

echo "NOTE: [gcp-tools] gcp-infra-report and send-infra-report installed"
