#!/bin/bash
# ================================================================================
# check_env.sh - Environment Validation
# ================================================================================
#
# Purpose:
#   - Validates required CLI tools are available in PATH.
#   - Verifies credentials.json exists and gcloud can authenticate.
#   - Enables required GCP APIs.
#   - Verifies every model in gemini-config.sh actually answers on Vertex.
#
# The model check is last because it needs the APIs enabled by api_setup.sh.
# It is not merely a lookup: a Gemini id can be real, be listed by the
# publisher API, and still 404 or 403 for this project and location. The only
# reliable test is to make the call, so probe_vertex.py makes it.
#
# ================================================================================

set -euo pipefail

echo "NOTE: Validating required commands in PATH."

commands=("gcloud" "terraform" "jq" "packer" "python3")

for cmd in "${commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}"
    exit 1
  fi
  echo "NOTE: Found required command: ${cmd}"
done

echo "NOTE: All required commands are available."

echo "NOTE: Validating credentials.json..."
if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: credentials.json not found in project root."
  echo "       Create a GCP service account key and save it as credentials.json"
  exit 1
fi

gcloud auth activate-service-account --key-file="./credentials.json"
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

echo "NOTE: gcloud authentication successful."

./api_setup.sh


# ==============================================================================
# SECTION: Vertex AI Model Check
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/gemini-config.sh"

mapfile -t MODEL_IDS < <(gemini_model_ids)

if [ "${#MODEL_IDS[@]}" -eq 0 ]; then
  echo "ERROR: GEMINI_MODELS in gemini-config.sh is empty - nothing to deploy."
  exit 1
fi

# A primary that is not in the list yields an OpenClaw that starts fine and
# cannot run an agent. Terraform validates this too, but failing here means
# failing before anything is built.
if ! gemini_model_for_alias "${GEMINI_PRIMARY}" > /dev/null; then
  echo "ERROR: GEMINI_PRIMARY is '${GEMINI_PRIMARY}', which is not an alias in"
  echo "ERROR: GEMINI_MODELS. Valid aliases:"
  gemini_model_aliases | sed 's/^/ERROR:   /'
  exit 1
fi

echo "NOTE: Checking ${#MODEL_IDS[@]} model(s) in ${VERTEX_LOCATION}," \
     "primary ${GEMINI_PRIMARY}"

MODEL_FAILED=0
for model in "${MODEL_IDS[@]}"; do
  if python3 "${SCRIPT_DIR}/probe_vertex.py" \
       --check "${model}" --location "${VERTEX_LOCATION}" >/dev/null 2>&1; then
    echo "NOTE: Vertex AI model ${model} accessible."
  else
    echo "ERROR: Vertex AI model ${model} did not answer in ${VERTEX_LOCATION}."
    MODEL_FAILED=1
  fi
done

if [ "${MODEL_FAILED}" -ne 0 ]; then
  echo "ERROR: One or more models in gemini-config.sh are unavailable."
  echo "ERROR: Model ids expire, and availability is per project and location."
  echo "ERROR: Run ./probe_vertex.py to see what this project can serve, then"
  echo "ERROR: update GEMINI_MODELS in gemini-config.sh."
  exit 1
fi

echo "NOTE: All models in gemini-config.sh are available."
