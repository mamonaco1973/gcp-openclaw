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

# ================================================================================
# gcp-infra-report
# ================================================================================

cat > /usr/local/bin/gcp-infra-report <<'SCRIPT'
#!/bin/bash
set -euo pipefail

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

md_table() {
  local header="$1"
  local data="$2"
  local cols="$3"  # pipe-separated column names

  echo "## ${header}"
  echo ""

  if [ -z "$data" ]; then
    echo "_None found._"
    echo ""
    return
  fi

  # Header row
  echo "$cols" | awk -F'|' '{
    for(i=1;i<=NF;i++) printf "| %s ", $i
    print "|"
  }'
  # Separator row
  echo "$cols" | awk -F'|' '{
    for(i=1;i<=NF;i++) printf "| --- "
    print "|"
  }'
  # Data rows
  echo "$data" | while read -r line; do
    echo "$line" | awk '{
      n=split($0,a,"\t")
      if(n<=1) n=split($0,a," +")
      for(i=1;i<=n;i++) printf "| %s ", a[i]
      print "|"
    }'
  done
  echo ""
}

echo "# GCP Infrastructure Snapshot"
echo ""
echo "**Project:** ${PROJECT_ID}  "
echo "**Generated:** $(date -u)"
echo ""
echo "---"
echo ""

md_table "Compute Instances" \
  "$(gcloud compute instances list \
    --format='value(name,zone.basename(),machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP.yesno(yes=Public,no=Internal))' \
    2>/dev/null || true)" \
  "Name|Zone|Machine Type|Status|Access"

md_table "Disks" \
  "$(gcloud compute disks list \
    --format='value(name,zone.basename(),sizeGb,type.basename(),status)' \
    2>/dev/null || true)" \
  "Name|Zone|Size (GB)|Type|Status"

md_table "Custom Images" \
  "$(gcloud compute images list --no-standard-images \
    --format='value(name,family,diskSizeGb,status,creationTimestamp.date(%Y-%m-%d))' \
    2>/dev/null || true)" \
  "Name|Family|Size (GB)|Status|Created"

md_table "Firewall Rules" \
  "$(gcloud compute firewall-rules list \
    --format='value(name,direction,allowed[].map().firewall_rule().list(),sourceRanges.list())' \
    2>/dev/null || true)" \
  "Name|Direction|Allowed|Source Ranges"

md_table "Secrets" \
  "$(gcloud secrets list \
    --format='value(name,createTime.date(%Y-%m-%d))' \
    2>/dev/null || true)" \
  "Name|Created"

md_table "Networks" \
  "$(gcloud compute networks list \
    --format='value(name,autoCreateSubnetworks,subnetworks.len())' \
    2>/dev/null || true)" \
  "Name|Auto Subnets|Subnet Count"

md_table "Storage Buckets" \
  "$(gcloud storage buckets list \
    --format='value(name,location,storageClass)' \
    2>/dev/null || true)" \
  "Name|Location|Class"
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
NOW=$(date -u)
DATE=$(date +%Y-%m-%d)

# ── Fetch data directly from gcloud (HTML-formatted tables) ───────────────────

instances_rows() {
  gcloud compute instances list \
    --format="value(name,zone.basename(),machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP.yesno(yes='Public',no='Internal'))" \
    2>/dev/null | while IFS=$'\t' read -r name zone mtype status access; do
      color="#27ae60"; [ "$status" != "RUNNING" ] && color="#e74c3c"
      echo "<tr><td>${name}</td><td>${zone}</td><td>${mtype}</td><td style='color:${color};font-weight:bold'>${status}</td><td>${access}</td></tr>"
    done
}

disks_rows() {
  gcloud compute disks list \
    --format="value(name,zone.basename(),sizeGb,type.basename(),status)" \
    2>/dev/null | while IFS=$'\t' read -r name zone size dtype status; do
      echo "<tr><td>${name}</td><td>${zone}</td><td>${size} GB</td><td>${dtype}</td><td>${status}</td></tr>"
    done
}

images_rows() {
  gcloud compute images list --no-standard-images \
    --format="value(name,family,diskSizeGb,status,creationTimestamp.date('%Y-%m-%d'))" \
    2>/dev/null | while IFS=$'\t' read -r name family size status created; do
      echo "<tr><td>${name}</td><td>${family}</td><td>${size} GB</td><td>${status}</td><td>${created}</td></tr>"
    done
}

firewall_rows() {
  gcloud compute firewall-rules list \
    --format="value(name,direction,allowed[].map().firewall_rule().list(),sourceRanges.list())" \
    2>/dev/null | while IFS=$'\t' read -r name dir allowed src; do
      echo "<tr><td>${name}</td><td>${dir}</td><td>${allowed}</td><td>${src}</td></tr>"
    done
}

secrets_rows() {
  gcloud secrets list \
    --format="value(name,createTime.date('%Y-%m-%d'))" \
    2>/dev/null | while IFS=$'\t' read -r name created; do
      echo "<tr><td>${name}</td><td>${created}</td></tr>"
    done
}

section() {
  local title="$1" headers="$2" rows="$3"
  if [ -z "$rows" ]; then
    echo "<h2>${title}</h2><p style='color:#888'>None found.</p>"
    return
  fi
  echo "<h2>${title}</h2><table><thead><tr>"
  echo "$headers" | tr '|' '\n' | while read -r h; do echo "<th>${h}</th>"; done
  echo "</tr></thead><tbody>${rows}</tbody></table>"
}

INSTANCES=$(instances_rows)
DISKS=$(disks_rows)
IMAGES=$(images_rows)
FIREWALLS=$(firewall_rows)
SECRETS=$(secrets_rows)

HTML=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body { font-family: Arial, sans-serif; background: #f0f4f8; margin: 0; padding: 20px; }
  .container { max-width: 900px; margin: 0 auto; background: white; border-radius: 10px;
               box-shadow: 0 2px 12px rgba(0,0,0,0.12); overflow: hidden; }
  .header { background: #1a73e8; color: white; padding: 28px 36px; }
  .header h1 { margin: 0; font-size: 24px; letter-spacing: -0.5px; }
  .header p { margin: 6px 0 0; opacity: 0.85; font-size: 14px; }
  .body { padding: 28px 36px; }
  h2 { color: #1a73e8; font-size: 15px; text-transform: uppercase;
       letter-spacing: 0.5px; border-bottom: 2px solid #e8f0fe;
       padding-bottom: 6px; margin-top: 28px; }
  table { border-collapse: collapse; width: 100%; margin-top: 10px; font-size: 13px; }
  thead tr { background: #e8f0fe; }
  th { text-align: left; padding: 9px 12px; color: #1a73e8; font-weight: 600; white-space: nowrap; }
  td { padding: 8px 12px; border-bottom: 1px solid #f1f3f4; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: #f8f9fa; }
  .footer { background: #f0f4f8; padding: 14px 36px; font-size: 12px; color: #999;
            border-top: 1px solid #e0e0e0; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>GCP Infrastructure Snapshot</h1>
    <p>Project: ${PROJECT_ID} &nbsp;&bull;&nbsp; ${NOW}</p>
  </div>
  <div class="body">
    $(section "Compute Instances" "Name|Zone|Machine Type|Status|Access" "$INSTANCES")
    $(section "Disks" "Name|Zone|Size|Type|Status" "$DISKS")
    $(section "Custom Images" "Name|Family|Size|Status|Created" "$IMAGES")
    $(section "Firewall Rules" "Name|Direction|Allowed|Source Ranges" "$FIREWALLS")
    $(section "Secrets" "Name|Created" "$SECRETS")
  </div>
  <div class="footer">Sent from OpenClaw on GCP Compute Engine &bull; ${DATE}</div>
</div>
</body>
</html>
EOF
)

echo "$HTML" | gcp-mail \
  -s "GCP Infrastructure Snapshot — ${PROJECT_ID} — ${DATE}" \
  -a "Content-Type: text/html" \
  "$RECIPIENT"

echo "NOTE: Infrastructure report sent to ${RECIPIENT}"
SCRIPT

chmod 755 /usr/local/bin/send-infra-report

echo "NOTE: [gcp-tools] gcp-infra-report and send-infra-report installed"
