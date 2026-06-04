# Quick helper to diagnose and start a safe Instance Refresh
# Run from PowerShell with AWS creds

Write-Host "=== ASG Current State ===" -ForegroundColor Cyan
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].{Min:min_size,Desired:desired_capacity,Max:max_size,LT:LaunchTemplate.LaunchTemplateName}" `
  --output table

Write-Host "`n=== In-Progress or Recent Refreshes ===" -ForegroundColor Cyan
aws autoscaling describe-instance-refreshes `
  --auto-scaling-group-name ha-project-asg `
  --query "InstanceRefreshes[?Status=='InProgress' || Status=='Cancelling' || Status=='Failed'].[InstanceRefreshId,Status,StartTime,PercentageComplete,StatusReason]" `
  --output table

Write-Host "`n=== Target Group Health (ALB) ===" -ForegroundColor Cyan
$tgArn = (aws elbv2 describe-target-groups --names ha-project-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $tgArn `
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' `
  --output table

Write-Host "`n=== Instances in ASG ===" -ForegroundColor Cyan
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState,AvailabilityZone]" `
  --output table

Write-Host "`nTo CANCEL a stuck refresh (if any ID shown above):" -ForegroundColor Yellow
Write-Host 'aws autoscaling cancel-instance-refresh --instance-refresh-id <the-id-from-above>'

Write-Host "`nTo START a SAFE refresh (recommended MinHealthy=100, longer warmup):" -ForegroundColor Green
Write-Host @'
aws autoscaling start-instance-refresh `
  --auto-scaling-group-name ha-project-asg `
  --strategy Rolling `
  --preferences MinHealthyPercentage=100,InstanceWarmup=180 `
  --region us-east-1
'@

Write-Host "`nAfter starting, poll status with the verify script or repeat the describe-instance-refreshes command."

Write-Host "`n=== Extra: Launch Template Version the ASG is using ===" -ForegroundColor Cyan
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].LaunchTemplate" `
  --output table

Write-Host "`n=== Recent Launch Template Versions (to see if staging apply created a new one) ===" -ForegroundColor Cyan
$ltName = "ha-project-lt20260521185755080700000002"
aws ec2 describe-launch-template-versions `
  --launch-template-name $ltName `
  --max-items 5 `
  --query "LaunchTemplateVersions[*].[VersionNumber,CreateTime]" `
  --output table

Write-Host "`n=== To poll results of a previous SSM send-command (replace <COMMAND_ID>) ===" -ForegroundColor Yellow
Write-Host 'aws ssm list-command-invocations --command-id <COMMAND_ID> --details --query "CommandInvocations[0].CommandPlugins[0].{Status:Status, Output:Output}" --output text'
