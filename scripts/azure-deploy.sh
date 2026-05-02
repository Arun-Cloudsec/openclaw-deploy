#!/bin/bash
# azure-deploy.sh - One-click Azure deployment for OpenClaw
# Usage: ./azure-deploy.sh <provider> <api_key> <ssh_key_file> [channel_token]

set -e

PROVIDER=${1:-anthropic}
API_KEY=${2}
SSH_KEY_FILE=${3:-~/.ssh/id_ed25519.pub}
CHANNEL_TOKEN=${4}

if [ -z "$API_KEY" ] || [ -z "$SSH_KEY_FILE" ]; then
    echo "Usage: ./azure-deploy.sh <provider> <api_key> <ssh_key_file> [channel_token]"
    echo "Example: ./azure-deploy.sh anthropic sk-ant-xxx ~/.ssh/id_ed25519.pub"
    exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_FILE")
RG_NAME="openclaw-rg-$(date +%s)"
LOCATION="eastus"

echo "🚀 Deploying OpenClaw to Azure..."
echo "   Provider: $PROVIDER"
echo "   Resource Group: $RG_NAME"

az group create --name "$RG_NAME" --location "$LOCATION"

az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file azure/azuredeploy-v2.json \
  --parameters \
    deploymentName=openclaw \
    aiProvider="$PROVIDER" \
    apiKey="$API_KEY" \
    channelToken="$CHANNEL_TOKEN" \
    vmSize=Standard_B2s \
    adminUsername=claw \
    sshPublicKey="$SSH_KEY" \
    location="$LOCATION"

echo ""
echo "✅ Deployment Complete!"
echo "Resource Group: $RG_NAME"
az deployment group show \
  --resource-group "$RG_NAME" \
  --name openclaw \
  --query properties.outputs
