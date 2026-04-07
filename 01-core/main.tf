# ================================================================================
# FILE: main.tf
# ================================================================================
#
# Purpose:
#   Configure the AWS provider for this Terraform root module.
#
# Design:
#   - Region is explicitly pinned to ensure consistent deployments.
#   - All resources in this configuration will be created in us-east-1.
#
# ================================================================================

provider "aws" {
  region = "us-east-1"
}
