# AWS Commands Reference (PowerShell Focused)

This document contains the most frequently used commands for this project, written for **Windows PowerShell**.

> **Recommendation**: Use **PowerShell** (via Windows Terminal) as your primary shell for AWS work on this project. Git Bash can still be used when preferred, but PowerShell has fewer path-mangling issues with SSM and other services.

---

## 1. Instance & Auto Scaling Group Management

```powershell
# List all instances in the ASG with health status
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState,AvailabilityZone]" `
  --output table

# Get only the Instance IDs (useful for scripting)
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].InstanceId" `
  --output text
```

### Instance Refresh (after code or Launch Template changes)

```powershell
aws autoscaling start-instance-refresh `
  --auto-scaling-group-name ha-project-asg `
  --strategy Rolling `
  --preferences MinHealthyPercentage=50,InstanceWarmup=90 `
  --region us-east-1
```

---

## 2. Session Manager Access

```powershell
# Connect to a specific instance
aws ssm start-session --target i-032be2d59ff5a3000

# First find the instance IDs, then connect
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].InstanceId" `
  --output text
```

---

## 3. ALB Target Group Health

```powershell
aws elbv2 describe-target-health `
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:866934333672:targetgroup/ha-project-tg/afabd001a6045675 `
  --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]" `
  --output table
```

---

## 4. SSM Parameter Store (with path protection)

PowerShell does not support the Bash-style `VAR=value command` syntax. Use one of these patterns:

### Recommended Pattern (Safe)

```powershell
$env:MSYS_NO_PATHCONV = "1"

aws ssm put-parameter `
  --name "/ha-project/development/db_host" `
  --value "myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com" `
  --type String `
  --overwrite

Remove-Item Env:MSYS_NO_PATHCONV   # Clean up after use
```

### Alternative One-Liner (using cmd)

```powershell
cmd /c "set MSYS_NO_PATHCONV=1 && aws ssm put-parameter --name /ha-project/development/db_host --value myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com --type String --overwrite"
```

### Read Parameters

```powershell
aws ssm get-parameter `
  --name "/ha-project/development/db_host" `
  --query "Parameter.Value" `
  --output text

aws ssm get-parameter `
  --name "/ha-project/development/db_password" `
  --with-decryption `
  --query "Parameter.Value" `
  --output text
```

---

## 5. Useful Commands Inside EC2 Instances (via Session Manager)

Once connected to an instance (`sh-4.2$` prompt), these are the most valuable commands:

```bash
# View the complete bootstrap log (extremely important for debugging)
cat /var/log/user-data.log

# Check both critical services
sudo systemctl status ha-backend nginx --no-pager

# Quick local health and API tests
curl -I http://localhost/health
curl -s http://localhost/api/tasks?userId=demo-user-123 | head -c 400

# Check what is actually in the environment file written by user-data
cat /opt/ha-backend/.env

# View recent backend logs (shows real database connection errors)
sudo journalctl -u ha-backend -n 100 --no-pager
```

---

## 6. Terraform Commands Used in This Project

```powershell
# Common pattern used in the pipeline (accepts existing resource warnings)
terraform apply `
  -refresh=false `
  -lock=false `
  -var="environment=development" `
  -auto-approve
```

---

## 7. Quick Tips

- Always run AWS CLI commands from **PowerShell** when possible.
- Use `$env:MSYS_NO_PATHCONV = "1"` only when you hit path mangling on commands containing `/` (mainly SSM).
- After using the `MSYS_NO_PATHCONV` trick, clean it up with `Remove-Item Env:MSYS_NO_PATHCONV`.
- Keep Windows Terminal open with both a PowerShell tab and a Git Bash tab for flexibility.

---

*Last updated: June 2026*
