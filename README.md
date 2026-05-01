# OpenClaw — One-Click Deploy to Azure or AWS

Deploy a self-hosted OpenClaw AI agent to **your own Azure or AWS account** in
under one minute. No SSH, no Node.js install, no `openclaw onboard` interactive
prompt — the cloud-init / UserData bootstrap handles all of it.

> **Why your own cloud?** Managed services like Kimi Claw run OpenClaw on
> *their* servers using *their* model credits. With this repo, the box runs
> in **your** account, with **your** API keys, and you can `ssh` in. The
> tradeoff is you pay the underlying cloud cost (~$10–25/month for a B2s /
> t3.small) instead of a SaaS subscription.

---

## What's in this repo

```
openclaw-deploy/
├── azure/
│   ├── azuredeploy.json            ← ARM template (the actual deployment)
│   └── createUiDefinition.json     ← Friendly form for the Azure Portal
├── aws/
│   └── cloudformation.yml          ← CloudFormation template
├── site/
│   └── index.html                  ← Landing page with both deploy buttons
└── README.md                       ← (you are here)
```

---

## Quick start — fork, host, click

The "one-click" deploy buttons on the landing page need to point at **your
fork's raw template URLs** because Azure Portal and AWS CloudFormation both
fetch the template directly from a public HTTPS URL.

### Step 1 — Fork or upload to GitHub

```bash
# Either fork from GitHub UI, or push to your own org:
git init
git add .
git remote add origin https://github.com/Arun-Cloudsec/openclaw-deploy.git
git push -u origin main
```

### Step 2 — Replace the `Arun-Cloudsec` placeholder

Search-replace `Arun-Cloudsec` → your GitHub org/user name across `site/index.html`:

```bash
# macOS
sed -i '' 's/Arun-Cloudsec/your-actual-org/g' site/index.html

# Linux
sed -i 's/Arun-Cloudsec/your-actual-org/g' site/index.html
```

The button URLs are:

- **Azure** — `https://portal.azure.com/#create/Microsoft.Template/uri/<url-encoded raw template URL>/uiFormDefinitionUri/<url-encoded raw UI URL>`
- **AWS**   — `https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=<url-encoded raw template URL>&stackName=openclaw`

### Step 3 — Host the landing page

Anywhere static — GitHub Pages, Vercel, Netlify, S3, or Azure Static Web Apps.
For GitHub Pages:

```bash
# Push site/ to a gh-pages branch or set Pages source to /site
```

### Step 4 — Visit your page and click

The flow from the user's perspective:

1. Click **Deploy to Azure** → Azure Portal opens with the parameter form
   pre-loaded. They pick a model, paste an API key, paste an SSH public key,
   click **Create**.
2. ARM provisions the VNet, NSG, public IP, and Ubuntu 22.04 VM (~50–90 sec).
3. Cloud-init runs `/usr/local/bin/openclaw-bootstrap.sh` on first boot —
   installs Node 20, `npm install -g openclaw`, runs `openclaw onboard
   --non-interactive`, registers a systemd service.
4. ~30 seconds later the agent gateway is live at the FQDN shown in the
   deployment **Outputs** tab — `http://openclaw-xxxx.region.cloudapp.azure.com:18789`.

AWS works identically — replace "ARM" with "CloudFormation" and "FQDN" with
"Elastic IP".

---

## Per-cloud notes

### Azure

- **VM size default:** `Standard_B2s` (2 vCPU / 4 GB RAM). About $30/month
  if left on 24/7. Can be dropped to `Standard_B1ms` (~$15/month) for
  light testing.
- **Region:** Defaults to the resource group's region. Pick a region close
  to your model provider's nearest endpoint to minimize latency.
- **Public IP:** Static, with a stable DNS label (`<deploymentName>-<hash>.
  <region>.cloudapp.azure.com`). Survives VM stop/start.
- **Network:** New VNet `10.42.0.0/16`. NSG opens only port 22 (SSH) and
  18789 (OpenClaw gateway).
- **Cleanup:** Delete the resource group — that wipes everything.

### AWS

- **Instance type default:** `t3.small`. About $15/month if left on 24/7.
- **AMI:** Resolves the latest Ubuntu 22.04 LTS via SSM Parameter Store —
  no stale AMI IDs in the template.
- **Subnet:** You pick a public subnet inside an existing VPC. The default
  VPC works fine for testing.
- **Key pair:** You must have an existing EC2 key pair in the chosen
  region — the template references it by name.
- **Elastic IP:** Allocated and associated, so the gateway URL doesn't
  change on reboot.
- **Region:** Default `us-east-1`. To launch in a different region, edit
  the `region=us-east-1` query param in the Launch Stack URL.
- **Cleanup:** Delete the CloudFormation stack — wipes the EIP, instance,
  and security group.

---

## After deployment — verify the agent is up

The bootstrap takes 60–120 seconds total. To confirm it finished:

```bash
# SSH into the box
ssh claw@<fqdn-or-eip>          # Azure
ssh ubuntu@<eip>                 # AWS

# Tail the bootstrap log
sudo tail -f /var/log/openclaw-bootstrap.log

# Check the systemd unit
systemctl status openclaw

# Test the gateway
curl http://localhost:18789/health
```

Then point your browser at `http://<fqdn-or-eip>:18789` to use the
OpenClaw web UI, or message your Telegram bot if you provided a token.

---

## Hardening before production

This template is optimized for "deploy in <1 min", not for production. Before
relying on it for real workloads:

1. **Narrow the SSH CIDR.** Default is `0.0.0.0/0`. Change `AllowedSshCidr`
   (AWS) to `your.ip.address/32`, or modify the NSG rule (Azure).
2. **Put the gateway behind a TLS terminator.** Add an nginx reverse proxy +
   Let's Encrypt cert; or front it with Azure Application Gateway / AWS ALB.
   Don't expose port 18789 directly to the internet for production traffic.
3. **Move secrets out of cloud-init.** The model API key currently lives in
   `/etc/openclaw/env` (mode 0600) on the VM. For real deployments use
   Azure Key Vault references or AWS Secrets Manager via instance profile.
4. **Enable backups / snapshots.** OpenClaw stores agent memory in
   `/opt/openclaw`. Snapshot the OS disk (Azure) or use an AMI lifecycle
   policy (AWS) if you don't want to lose conversation memory on accidental
   instance termination.
5. **Auto-shutdown for cost.** Both clouds support scheduled stop/start.
   A B2s shut down outside 9am–6pm cuts the bill by ~70%.

---

## Troubleshooting

**Gateway doesn't answer after 2 minutes.**
SSH in and check `sudo tail /var/log/openclaw-bootstrap.log`. Most failures are
the `npm install -g openclaw` step hitting a network blip — retry with
`sudo bash /usr/local/bin/openclaw-bootstrap.sh`.

**Azure deployment fails on `osProfile.customData`.**
The cloud-init payload is base64-encoded inline. If you've edited
`azuredeploy.json` and broken the encoding, the deployment will fail
validation. Re-render via the included `tools/render-customdata.sh` (or
just stick to the original).

**AWS CloudFormation says "VPC has no default subnet".**
You need to pick a subnet that has `MapPublicIpOnLaunch = true`. Default-VPC
subnets always do; private subnets in a custom VPC don't.

**The provider "moonshot" isn't in OpenClaw's onboarding choices.**
Older OpenClaw versions lacked Moonshot as a first-class provider. The bootstrap
adds the env var anyway and OpenClaw picks it up via OPENAI-compatible base
URL config in `~/.openclaw/config.json`. If you want a different provider,
edit `OPENCLAW_PROVIDER` in `/etc/openclaw/env` and restart the unit:
`sudo systemctl restart openclaw`.

---

## Cost summary

| Cloud | Default size | ~Monthly (24/7) | ~Monthly (12h/day) |
|-------|-------------|-----------------|---------------------|
| Azure | B2s         | $30             | $15                 |
| AWS   | t3.small    | $15             | $8                  |

Plus model API costs (paid directly to the provider, not the cloud).

---

## License

MIT for the templates. OpenClaw itself is licensed separately — see
[openclaw.ai](https://openclaw.ai).
