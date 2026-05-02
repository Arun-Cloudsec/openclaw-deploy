#!/bin/bash
# aws-deploy.sh - One-click AWS deployment for OpenClaw
# Usage: ./aws-deploy.sh <provider> <api_key> <ssh_key_file> [channel_token]

set -e

PROVIDER=${1:-anthropic}
API_KEY=${2}
SSH_KEY_FILE=${3:-~/.ssh/id_ed25519.pub}
CHANNEL_TOKEN=${4}

if [ -z "$API_KEY" ] || [ -z "$SSH_KEY_FILE" ]; then
    echo "Usage: ./aws-deploy.sh <provider> <api_key> <ssh_key_file> [channel_token]"
    echo "Example: ./aws-deploy.sh anthropic sk-ant-xxx ~/.ssh/id_ed25519.pub"
    exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_FILE")
STACK_NAME="openclaw-$(date +%s)"

echo "🚀 Deploying OpenClaw to AWS..."
echo "   Provider: $PROVIDER"
echo "   Stack: $STACK_NAME"

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://aws/openclaw-v2.yaml \
  --parameters \
    ParameterKey=DeploymentName,ParameterValue=openclaw \
    ParameterKey=AiProvider,ParameterValue="$PROVIDER" \
    ParameterKey=ApiKey,ParameterValue="$API_KEY" \
    ParameterKey=ChannelToken,ParameterValue="$CHANNEL_TOKEN" \
    ParameterKey=VmSize,ParameterValue=t3.small \
    ParameterKey=KeyPair,ParameterValue=your-keypair \
  --capabilities CAPABILITY_IAM \
  --tags Key=Project,Value=OpenClaw

echo "⏳ Waiting for stack creation..."
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"

OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs')
echo ""
echo "✅ Deployment Complete!"
echo "$OUTPUTS" | python3 -m json.tool
