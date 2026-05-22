#!/bin/bash
set -e

echo "🌍 Deploying to Production..."

cp ../scripts/user-data.sh ./user-data-temp.sh

aws ec2 create-launch-template-version \
  --launch-template-name "ha-project-lt" \
  --version-description "Deploy $(date +%Y%m%d-%H%M%S)" \
  --source-version 1 \
  --launch-template-data file://<(echo '{
    "UserData": "'"$(base64 -w 0 user-data-temp.sh)"'"
  }')

aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "ha-project-asg" \
  --preferences "MinHealthyPercentage=50,InstanceWarmup=90"

echo "🎉 Production deployment triggered!"
