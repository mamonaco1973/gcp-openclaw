#!/bin/bash
# ================================================================================
# api_setup.sh - GCP API Enablement
# ================================================================================
#
# Purpose:
#   Enables required Google Cloud APIs for this deployment.
#   Must be run before Terraform can provision resources.
#
# ================================================================================

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: credentials.json not found." >&2
  exit 1
fi

gcloud auth activate-service-account --key-file="./credentials.json" > /dev/null 2>&1

project_id=$(jq -r '.project_id' "./credentials.json")
gcloud config set project "$project_id"

echo "NOTE: Enabling required GCP APIs..."

gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable aiplatform.googleapis.com
gcloud services enable cloudbilling.googleapis.com
gcloud services enable storage.googleapis.com

echo "NOTE: APIs enabled."
