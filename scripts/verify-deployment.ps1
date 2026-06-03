# Verify Deployment Script for HA Project
# Run this from your laptop PowerShell after code changes or to stabilize the fleet

Write-Host "=== HA Project Deployment Verification ===" -ForegroundColor Green

# 1. Check current instances
Write-Host "`n1. Current ASG Instances:" -ForegroundColor Yellow
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState,AvailabilityZone]" `
  --output table

# 2. Trigger Instance Refresh (uncomment the lines below to run)
Write-Host "`n2. To trigger Instance Refresh (rolls out latest user-data to all instances):" -ForegroundColor Yellow
Write-Host 'aws autoscaling start-instance-refresh `'
Write-Host '  --auto-scaling-group-name ha-project-asg `'
Write-Host '  --strategy Rolling `'
Write-Host '  --preferences MinHealthyPercentage=50,InstanceWarmup=60 `'
Write-Host '  --region us-east-1'

# 3. Check Target Group Health
Write-Host "`n3. ALB Target Group Health:" -ForegroundColor Yellow
aws elbv2 describe-target-health `
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:866934333672:targetgroup/ha-project-tg/afabd001a6045675 `
  --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]" `
  --output table

# 4. Test public API
Write-Host "`n4. Test Public API (replace ALB DNS if needed):" -ForegroundColor Yellow
Write-Host 'PowerShell: (Invoke-WebRequest -Uri "http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/tasks?userId=demo-user-123" -UseBasicParsing).Content.Substring(0,300)'
Write-Host 'If curl.exe available: curl.exe -s "http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/tasks?userId=demo-user-123" | Out-String | ForEach-Object { $_.Substring(0, [Math]::Min(300, $_.Length)) }'

Write-Host "`n=== Instructions ===" -ForegroundColor Cyan
Write-Host "1. Run the Instance Refresh command above (from PowerShell) to stabilize the fleet with latest user-data."
Write-Host "2. Wait for refresh to complete (check AWS console or describe-auto-scaling-groups)."
Write-Host "3. Verify both instances bootstrap cleanly using AWS_COMMANDS.md."
Write-Host "4. Test the live site in browser (use the PowerShell command printed above for the API test)."
