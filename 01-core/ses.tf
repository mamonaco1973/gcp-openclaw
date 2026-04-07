# ================================================================================
# FILE: ses.tf
# ================================================================================
#
# Purpose:
#   Creates SES email identity and SMTP credentials for outbound email.
#
# Post-deploy step:
#   AWS will send a verification email to var.ses_email. Click the link to
#   activate sending. Until verified, SES will reject outbound messages.
#
# ================================================================================


# ================================================================================
# SECTION: Email Identity
# ================================================================================

resource "aws_ses_email_identity" "sender" {
  email = var.ses_email
}


# ================================================================================
# SECTION: SMTP Credentials
# ================================================================================

resource "aws_iam_user" "ses_smtp" {
  name = "openclaw-ses-smtp"
  tags = { Name = "openclaw-ses-smtp" }
}

resource "aws_iam_user_policy" "ses_smtp" {
  name = "openclaw-ses-send"
  user = aws_iam_user.ses_smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_access_key" "ses_smtp" {
  user = aws_iam_user.ses_smtp.name
}


# ================================================================================
# SECTION: SMTP Secret
# ================================================================================

resource "aws_secretsmanager_secret" "ses_smtp" {
  name                    = "openclaw_ses_smtp"
  description             = "SES SMTP credentials for OpenClaw outbound email sending"
  recovery_window_in_days = 0
  tags                    = { Name = "openclaw-ses-smtp" }
}

resource "aws_secretsmanager_secret_version" "ses_smtp" {
  secret_id = aws_secretsmanager_secret.ses_smtp.id
  secret_string = jsonencode({
    smtp_host     = "email-smtp.us-east-1.amazonaws.com"
    smtp_port     = "587"
    smtp_username = aws_iam_access_key.ses_smtp.id
    smtp_password = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
    from_email    = var.ses_email
  })
}
