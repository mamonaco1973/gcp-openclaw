# configure.md — Post-Deploy OpenClaw Setup

Steps to complete after `./apply.sh` finishes. Allow ~2 minutes for userdata
to set the password and start services.

---

## 1. Get the openclaw User Password

```bash
aws secretsmanager get-secret-value \
  --secret-id openclaw_credentials \
  --query SecretString \
  --output text | jq -r '.password'
```

---

## 2. RDP Into the Instance

Forward RDP via SSM Session Manager (no inbound port 3389 needed):

```bash
INSTANCE_ID=$(cd 03-openclaw && terraform output -raw instance_id)

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3389"],"localPortNumber":["13389"]}' \
  --region us-east-1
```

Then connect your RDP client to `localhost:13389` with:
- **Username:** `openclaw`
- **Password:** from step 1

---

## 3. Verify Services Are Running

From an SSM shell or the RDP terminal:

```bash
systemctl status litellm
systemctl status openclaw-gateway
```

Both should show `active (running)`. To check logs:

```bash
journalctl -u litellm -n 50
journalctl -u openclaw-gateway -n 50
```

Check userdata completed:

```bash
tail /root/userdata.log
```

---

## 4. Open OpenClaw in Chrome

Open Chrome from the desktop and navigate to:

```
http://localhost:18789
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `openclaw-gateway` fails to start | Check litellm is up first: `systemctl status litellm` |
| LiteLLM 401 / auth error | Verify master key: `grep master_key /opt/openclaw/litellm-config.yaml` |
| Bedrock 403 / credentials error | Check instance IAM role has `bedrock:InvokeModel` on inference-profile ARN |
| Invalid model name | `grep model /opt/openclaw/litellm-config.yaml` — verify model ID is active in Bedrock console |
| Change the Bedrock model | Edit `/opt/openclaw/litellm-config.yaml`, then `sudo systemctl restart litellm` |
| Services not started | Check userdata: `cat /root/userdata.log` |
