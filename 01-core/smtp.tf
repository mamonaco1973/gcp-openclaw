# ================================================================================
# FILE: smtp.tf
# ================================================================================
#
# Purpose:
#   Stores SMTP credentials in GCP Secret Manager for outbound email sending.
#   Works with any SMTP provider — Gmail, SendGrid, Mailgun, etc.
#   Set smtp_* variables at apply time or accept the dummy defaults for testing.
#
# ================================================================================


# ================================================================================
# SECTION: SMTP Secret
# ================================================================================

resource "google_secret_manager_secret" "smtp" {
  secret_id = "openclaw-smtp"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "smtp" {
  secret = google_secret_manager_secret.smtp.id

  secret_data = jsonencode({
    smtp_host     = var.smtp_host
    smtp_port     = var.smtp_port
    smtp_username = var.smtp_username
    smtp_password = var.smtp_password
    from_email    = var.smtp_from
  })
}


# ================================================================================
# SECTION: IAM — allow VM service account to read this secret
# ================================================================================

resource "google_secret_manager_secret_iam_binding" "smtp" {
  secret_id = google_secret_manager_secret.smtp.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${local.service_account_email}"]
}
