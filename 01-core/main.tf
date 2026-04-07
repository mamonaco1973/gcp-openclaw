# ================================================================================
# FILE: main.tf
# ================================================================================
#
# Purpose:
#   Configure the Google Cloud provider for this Terraform root module.
#   Reads service account credentials from credentials.json in the project root.
#
# ================================================================================

provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
}

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}
