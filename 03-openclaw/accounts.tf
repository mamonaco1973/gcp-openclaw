# ================================================================================
# FILE: accounts.tf
# ================================================================================
#
# Purpose:
#   Generate a memorable password for the local openclaw Linux user and store
#   it in AWS Secrets Manager. The EC2 instance reads this secret at first boot
#   to create and configure the account.
#
# Design:
#   - Password format: <word>-<6-digit-number>
#   - No credentials exposed via Terraform outputs.
#   - Secret permitted to be destroyed during teardown.
#
# ================================================================================


# ================================================================================
# SECTION: Memorable Word List
# ================================================================================

locals {
  memorable_words = [
    "bright", "simple", "orange", "window", "little",
    "people", "friend", "yellow", "animal", "family",
    "circle", "moment", "summer", "button", "planet",
    "rocket", "silver", "forest", "stream", "butter",
    "castle", "wonder", "gentle", "driver", "coffee"
  ]
}


# ================================================================================
# SECTION: Password Generation
# ================================================================================

resource "random_shuffle" "word" {
  input        = local.memorable_words
  result_count = 1
}

resource "random_integer" "num" {
  min = 100000
  max = 999999
}

locals {
  openclaw_password = format("%s-%d",
    random_shuffle.word.result[0],
    random_integer.num.result
  )
}


# ================================================================================
# SECTION: Secrets Manager
# ================================================================================

resource "aws_secretsmanager_secret" "openclaw" {
  name                    = "openclaw_credentials"
  description             = "Local openclaw desktop user credentials"
  recovery_window_in_days = 0

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "openclaw" {
  secret_id = aws_secretsmanager_secret.openclaw.id

  secret_string = jsonencode({
    username = "openclaw"
    password = local.openclaw_password
  })
}