# CLAUDE.md — aws-openclaw

## Project Overview

Terraform + Packer project that deploys an EC2 instance running **OpenClaw**
(an AI coding agent) backed by **LiteLLM proxy** pointed at **AWS Bedrock**.
Users RDP into an LXQt desktop and access the OpenClaw web UI at
`http://localhost:18789` in Chrome. No SSH keys, no open inbound ports —
RDP uses SSM Session Manager port-forwarding (or direct inbound RDP if SG
rules are opened).

## Architecture

```
01-core/          VPC + subnets + NAT gateway
02-packer/        Packer build: Ubuntu 24.04 → openclaw_ami
  scripts/        01-packages through 10-services
  files/          litellm.service, openclaw-gateway.service
03-openclaw/      EC2 instance + IAM role + security group + secrets
  scripts/
    userdata.sh   Boot: set password from secret, write litellm config,
                  start systemd services
```

### Deployment Order

1. `01-core` — VPC, subnets, NAT gateway
2. `02-packer` — Packer builds `openclaw_ami`
3. `03-openclaw` — EC2 from `openclaw_ami`, secrets, IAM

### Key Resources

| Resource | Value |
|---|---|
| Region | `us-east-1` |
| VPC / CIDR | `clawd-vpc` / `10.0.0.0/23` |
| EC2 instance tag | `openclaw-host` |
| Instance type | `t3.xlarge` (variable) |
| LiteLLM port | `4000` |
| LiteLLM master key | `sk-openclaw` |
| OpenClaw gateway port | `18789` (loopback only) |
| Bedrock model | Dynamically resolved from `list-foundation-models` |
| Linux user | `openclaw` (sudo, NOPASSWD) |
| Password source | AWS Secrets Manager `openclaw_credentials` |

## Common Commands

```bash
# Validate environment (checks aws, terraform, jq, packer in PATH + AWS auth)
./check_env.sh

# Deploy everything (01-core → 02-packer → 03-openclaw → validate)
./apply.sh

# Tear down (03-openclaw → deregister AMI → 01-core)
./destroy.sh

# Validate post-deploy
./validate.sh
```

### Connecting to the Instance

```bash
# Get instance ID
INSTANCE_ID=$(cd 03-openclaw && terraform output -raw instance_id)

# SSM shell session
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1

# RDP port-forward (then connect to localhost:13389)
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3389"],"localPortNumber":["13389"]}' \
  --region us-east-1
```

### Getting the openclaw User Password

```bash
aws secretsmanager get-secret-value \
  --secret-id openclaw_credentials \
  --query SecretString \
  --output text | jq -r '.password'
```

## What Packer (02-packer) Does

Builds `openclaw_ami` from Ubuntu 24.04 (fully self-contained):

| Script | What it installs |
|---|---|
| `01-packages.sh` | Removes snap, installs SSM agent DEB, base packages |
| `02-desktop.sh` | LXQt desktop environment |
| `03-xrdp.sh` | XRDP + LXQt session config |
| `04-chrome.sh` | Google Chrome Stable |
| `05-tools.sh` | Git, AWS CLI v2, Terraform, Packer, Azure CLI, gcloud, VS Code |
| `06-user.sh` | `openclaw` Linux user with passwordless sudo |
| `07-node.sh` | Node.js 22, openclaw at `/usr/local/bin/openclaw` |
| `08-litellm.sh` | Python venv at `/opt/litellm-venv`, `litellm[proxy]` |
| `09-openclaw-init.sh` | Runs gateway briefly to stamp config metadata; configures litellm provider |
| `10-services.sh` | Installs and enables `litellm.service` + `openclaw-gateway.service` |

## What userdata.sh Does

Runs at first boot on the `openclaw_ami` EC2 instance:

1. Reads `openclaw_credentials` from Secrets Manager via instance IAM role
2. Sets the `openclaw` Linux user password (`chpasswd`)
3. Writes `/opt/openclaw/litellm-config.yaml` with the actual Bedrock model ID
4. Starts `litellm.service` and `openclaw-gateway.service`

## Bedrock Model Discovery

`apply.sh` queries `aws bedrock list-foundation-models` to find the latest
active versioned Claude Sonnet model and prepends `us.` for cross-region
inference profiles:

```bash
BASE_MODEL_ID=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE` && contains(modelId, `claude-sonnet`)]' \
  --output json | jq -r '[.[] | select(.modelId | test("-v[0-9]+:[0-9]+$"))] | [.[].modelId] | sort | last')
BEDROCK_MODEL_ID="us.${BASE_MODEL_ID}"
```

## IAM Permissions

The instance role (`openclaw-role`) has:

| Policy | Purpose |
|---|---|
| `AmazonSSMManagedInstanceCore` | SSM Session Manager access |
| Inline `openclaw-bedrock` | `bedrock:InvokeModel` + `InvokeModelWithResponseStream` on foundation models and inference profiles |
| Inline `openclaw-secrets` | `secretsmanager:GetSecretValue` scoped to `openclaw_credentials*` |

## Networking Design

- `vm-subnet-1` / `vm-subnet-2` — private workload subnets, egress via NAT
- `pub-subnet-1` / `pub-subnet-2` — public subnets (NAT gateway + Packer builder)
- Security group `openclaw-sg` — port 3389 inbound, all outbound allowed
- **Packer build uses `pub-subnet-1`** (needs SSH from internet during build)
- **EC2 host uses `pub-subnet-1`** (direct RDP access)

## Password Format

Generated by Terraform in `03-openclaw/accounts.tf`:

```
<word>-<6-digit-number>   e.g. "rocket-482910"
```

Stored in Secrets Manager as `{"username": "openclaw", "password": "..."}`.
