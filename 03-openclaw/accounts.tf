# ================================================================================
# FILE: accounts.tf
# ================================================================================
#
# Purpose:
#   Generate a memorable password for the local openclaw Linux user and store
#   it in GCP Secret Manager. The VM reads this secret at first boot to set
#   the account password.
#
# Design:
#   - Password format: <word>-<6-digit-number>
#   - No credentials exposed via Terraform outputs.
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
# SECTION: Secret Manager
# ================================================================================

resource "google_secret_manager_secret" "openclaw_credentials" {
  secret_id = "openclaw-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openclaw_credentials" {
  secret = google_secret_manager_secret.openclaw_credentials.id

  secret_data = jsonencode({
    username = "openclaw"
    password = local.openclaw_password
  })
}

resource "google_secret_manager_secret_iam_binding" "openclaw_credentials" {
  secret_id = google_secret_manager_secret.openclaw_credentials.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${local.service_account_email}"]
}
