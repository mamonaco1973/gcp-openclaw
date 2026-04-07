#AWS #AIAgent #OpenClaw #LiteLLM #Bedrock #Terraform #Packer #Claude #AmazonNova

*Run an AI Agent on AWS in Minutes (OpenClaw + Bedrock)*

Deploy a fully autonomous AI agent workstation on AWS using Terraform, Packer, OpenClaw, and AWS Bedrock. The agent runs on an Ubuntu EC2 instance with an LXQt desktop, backed by four foundation models — Claude Sonnet, Claude Haiku, Amazon Nova Pro, and Amazon Nova Lite — routed through a LiteLLM proxy.

In this project we give the agent a single natural language instruction and watch it query Cost Explorer, generate a styled HTML report, send it by email through Amazon SES, and schedule itself as a nightly recurring task — no scripts written by hand, no credentials managed, no additional configuration.

WHAT YOU'LL LEARN
• Deploying an AI agent workstation on AWS with Terraform and Packer
• Routing AWS Bedrock models through LiteLLM for OpenAI-compatible access
• Giving an AI agent access to AWS APIs through an IAM instance profile
• Configuring outbound email with Amazon SES and msmtp
• Driving real automation with plain English instructions

INFRASTRUCTURE DEPLOYED
• VPC with public and private subnets, NAT gateway (us-east-1)
• Ubuntu 24.04 EC2 instance (t3.xlarge) with LXQt desktop and XRDP
• Packer-built AMI with OpenClaw, LiteLLM, Chrome, VS Code, and developer tooling
• LiteLLM proxy configured for Claude Sonnet, Claude Haiku, Nova Pro, Nova Lite
• IAM instance profile with Bedrock, Secrets Manager, and Cost Explorer access
• Amazon SES email identity with SMTP credentials stored in Secrets Manager
• AWS Secrets Manager secrets for desktop password and SES SMTP credentials

GitHub
https://github.com/mamonaco1973/aws-openclaw

README
https://github.com/mamonaco1973/aws-openclaw/blob/main/README.md

TIMESTAMPS
00:00 Introduction
00:00 Architecture
00:00 Build the Code
00:00 Build Results
00:00 Demo
