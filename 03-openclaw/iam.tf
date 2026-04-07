# ================================================================================
# FILE: iam.tf
# ================================================================================
#
# Purpose:
#   IAM role and instance profile granting the OpenClaw EC2 instance:
#     - SSM Session Manager access (no SSH keys required)
#     - Bedrock model invocation for LiteLLM proxy
#     - Secrets Manager read access to retrieve the openclaw user credentials
#       at first boot
#
# ================================================================================

resource "aws_iam_role" "openclaw" {
  name = "openclaw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.openclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bedrock" {
  name = "openclaw-bedrock"
  role = aws_iam_role.openclaw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = [
        "arn:aws:bedrock:*::foundation-model/*",
        "arn:aws:bedrock:*:*:inference-profile/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "secrets" {
  name = "openclaw-secrets"
  role = aws_iam_role.openclaw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [
        "arn:aws:secretsmanager:*:*:secret:openclaw_credentials*",
        "arn:aws:secretsmanager:*:*:secret:openclaw_ses_smtp*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "ses" {
  name = "openclaw-ses"
  role = aws_iam_role.openclaw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "cost_explorer" {
  name = "openclaw-cost-explorer"
  role = aws_iam_role.openclaw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:GetDimensionValues",
        "ce:GetReservationUtilization",
        "ce:GetSavingsPlansUtilization",
        "ce:ListCostAllocationTags"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "openclaw" {
  name = "openclaw-profile"
  role = aws_iam_role.openclaw.name
}
