# Video Script — AI Agent Workstation on AWS with OpenClaw

---

## Introduction

[ Screen recording of OpenClaw running the cost report — agent executing commands, email arriving in inbox ]

"Do you want an AI agent that can automate cloud tasks directly inside your AWS environment?"

[ Architecture diagram — walk through it left to right: user, EC2 instance, Bedrock ]

"In this project we deploy an AI agent workstation on AWS using Terraform, Packer, OpenClaw, and AWS Bedrock."

[ OpenClaw UI showing the agent mid-task with terminal output visible ]

"The agent runs on an EC2 instance with access to the filesystem, terminal, browser, and AWS APIs — all through the instance IAM role."

[ Terminal running apply.sh — flying through build steps, ends with instance ID and connection details ]

"Follow along and in minutes you'll have a fully functional AI agent running in your AWS environment."

---

## Architecture

[ Full diagram ]

"Let's walk through the architecture before we build."

[ Highlight EC2 instance ]

"At the center is an Ubuntu EC2 instance with a desktop environment — the agent's workstation. You connect over RDP and get a normal desktop with Chrome, VS Code, and a terminal."

[ Highlight OpenClaw gateway ]

"OpenClaw runs on that instance and gives the agent its capabilities — shell execution, filesystem access, browser control, and email."

[ Highlight LiteLLM + Bedrock ]

"Reasoning goes through LiteLLM, which proxies requests to AWS Bedrock — Claude Sonnet, Claude Haiku, Nova Pro, Nova Lite."

[ Highlight SES ]

"Outbound email routes through Amazon SES, configured automatically at boot."

[ Full diagram ]

"A workstation on AWS, an AI agent on top of it, wired to Bedrock and AWS services. Let's build it."

---

## Build Results

[ Terminal — build complete, instance ID and connection details printed ]

"The build has completed. Now let's go into the console and see what was deployed."

[ AWS Console — EC2 instance running, public IP visible ]

"The AI agent's workstation is running as an EC2 instance."

[ AWS Console — Secrets Manager, openclaw_credentials and openclaw_ses_smtp ]

"Two secrets are in Secrets Manager — one holds the desktop password, the other holds the SES SMTP credentials. The instance pulls both at boot, no credentials ever touch the code."

[ AWS Console — SES verified identity ]

"SES is configured with a verified sender identity. Once you click the verification link in your inbox, the agent can send outbound email."

[ RDP session connecting — LXQt desktop loads ]

"Connect over RDP and the desktop is ready. Chrome, VS Code, a terminal — everything the agent needs to do real work."

[ Chrome opening to localhost:18789 — OpenClaw UI ]

"OpenClaw is already running. Open Chrome and the agent interface is waiting."

---

## Demo

[ OpenClaw UI — empty prompt box ]

"Let's give the agent its first task. One sentence, plain English."

[ Typing the prompt ]

"Generate an AWS cost report with the month-to-date total, a daily breakdown for the last 7 days, and the top 10 services by spend this month. Send it as a formatted HTML email to XXXXXXXX using msmtp directly and make that e-mail address the sender."

[ Agent working — AWS CLI calls visible, script being written and executed ]

"The agent figures out how to do this on its own. It calls Cost Explorer, builds an HTML report, and sends it through msmtp — no additional instructions."

[ Inbox — styled HTML cost report email arrives ]

"There's the report. Month-to-date total, daily breakdown, top services — formatted HTML, delivered through SES."

[ Back to OpenClaw — typing follow-up prompt ]

"Now let's make it recurring. Same agent, one more line."

[ Typing the prompt ]

"Schedule that as a nightly report."

[ Agent writing script to disk, adding crontab entry — cron confirmation visible ]

"The agent saves the script and registers a cron job. It runs every night automatically, no further input needed."

---
