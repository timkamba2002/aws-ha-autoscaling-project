#!/bin/bash
set -e

echo "🚀 Deploying to Staging..."

# Make user-data script available
cp ../scripts/user-data.sh ./user-data-temp.sh

# Create new Launch Template version
aws ec2 create-launch-template-version \
  --launch-template-name "ha-project-lt" \
  --version-description "Deploy $(date +%Y%m%d-%H%M%S)" \
  --source-version 1 \
  --launch-template-data file://<(echo '{
    "UserData": "'"$(base64 -w 0 user-data-temp.sh)"'"
  }')

echo "✅ New Launch Template version created. Starting rolling update..."

# Trigger rolling update on ASG
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "ha-project-asg" \
  --preferences "MinHealthyPercentage=50,InstanceWarmup=90"

echo "🎉 Staging deployment triggered!"
