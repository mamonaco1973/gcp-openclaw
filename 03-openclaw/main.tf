# ================================================================================
# FILE: main.tf
# ================================================================================
#
# Purpose:
#   Configure the Google Cloud provider and resolve shared networking and image
#   resources created by 01-core and 02-packer via data sources.
#
# ================================================================================

provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
}

provider "random" {}

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}


# ================================================================================
# SECTION: Data Sources
# ================================================================================

data "google_compute_network" "openclaw_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "openclaw_subnet" {
  name   = var.subnet_name
  region = var.region
}

data "google_compute_image" "openclaw" {
  name    = var.openclaw_image_name
  project = local.credentials.project_id
}
