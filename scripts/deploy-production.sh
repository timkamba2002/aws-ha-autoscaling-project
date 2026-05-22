#!/bin/bash
set -e

echo "🌍 Deploying to Production..."

LT_NAME="ha-project-lt"

cp scripts/user-data.sh scripts/user-data-temp.sh 2>/dev/null || true

aws ec2 create-launch-template-version \
  --launch-template-name "$LT_NAME" \
  --version-description "Deploy $(date +%Y%m%d-%H%M%S)" \
  --source-version 1 \
  --launch-template-data file://<(echo '{
    "UserData": "'"$(base64 -w 0 scripts/user-data-temp.sh)"'"
  }') || true

aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "ha-project-asg" \
  --preferences "MinHealthyPercentage=50,InstanceWarmup=90"

echo "🎉 Production deployment triggered!"
