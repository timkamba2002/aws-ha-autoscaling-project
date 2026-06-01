# Dev History & Project Journal

> A detailed, honest record of the challenges, fixes, breaks, and lessons learned while building this HA 3-Tier To-Do Application on AWS.

This document exists so future me (and anyone reviewing the project) can understand the real journey — not just the final architecture.

---

## Project Goals (Original Intent)

- Build a realistic 3-tier web application (React + Node.js + MySQL)
- Use Infrastructure as Code (Terraform) for everything
- Implement a professional CI/CD pipeline with promotion gates
- Gain hands-on experience aligned with AWS Solutions Architect Associate + real DevOps work
- Prepare a strong portfolio piece + presentation for instructor

---

## High-Level Timeline

| Period          | Focus Area                          | Key Outcome |
|----------------|-------------------------------------|-------------|
| Early Phase    | Initial Terraform + basic pipeline  | ALB + ASG + S3 frontend working |
| Backend Crisis | Getting Node backend + RDS talking  | Multiple failed attempts, manual fixes on instances |
| User-Data Hell | Making instances bootstrap reliably | Repeated ASG replacements, Session Manager debugging |
| Major Fixes    | IAM policy restoration + user-data rewrite | SSM credentials finally working automatically |
| Stabilization  | Fixing SSM parameter pollution + user-data improvements | Clean `db_host` + proper Node 16 + nginx install |
| Documentation  | Honest record + commands reference  | This file + updated docs |

---

## Major Challenges & How We Overcame Them

### 1. Backend Never Persisted Data (The Longest Battle)

**Problem**:  
Even when the React frontend loaded, calling `/api/tasks` would fail or return errors. Tasks created in the UI never appeared in the database.

**Root Causes Discovered Over Time**:
- Wrong database schema (initially written for Postgres instead of MySQL 8)
- EC2 IAM role missing permissions to read SSM Parameter Store (`ssm:GetParameter`)
- No AWS region set inside user-data → all `aws ssm` and `aws s3` calls were failing silently
- SSM parameter `db_host` was stored with `:3306` appended, causing `getaddrinfo ENOTFOUND` errors in Node.js
- Amazon Linux 2 package issues (default `nodejs` too old, `nginx` not available in base repos)

**How We Fixed It**:
- Rewrote `database/init.sql` with correct MySQL 8 DDL
- Restored the missing `aws_iam_role_policy.ssm_read_db_creds` via Terraform (after IAM permission drama)
- Added `export AWS_DEFAULT_REGION=us-east-1` very early in user-data
- Cleaned the `db_host` SSM parameter (removed port)
- Completely rewrote the package installation section in `user-data.sh.tpl`

**Lesson**:
Never trust that "it worked on my debug instance" means the automated path will work on new instances.

---

### 2. User-Data Was Extremely Fragile

**Problem**:  
Every new instance (or Instance Refresh) came up broken. We had to manually SSH in and run NodeSource install + `amazon-linux-extras install nginx1` + create `.env` by hand.

**Key Fixes Applied**:
- Proper Node 16 installation via NodeSource (required on AL2 due to glibc)
- Correct nginx installation using `amazon-linux-extras install nginx1`
- Early region export before any AWS CLI calls
- Added comprehensive logging: `exec > >(tee /var/log/user-data.log ...)`
- Better success/failure messaging throughout the bootstrap script

**Result**:
The improved `terraform/modules/ec2/user-data.sh.tpl` is now much more reliable.

---

### 3. IAM & Permission Nightmares

- GitHub OIDC role kept hitting `AccessDenied` on `iam:PutRolePolicy`, `ssm:PutParameter`, etc.
- EC2 role was missing SSM read permissions for a long time
- Company security policies made it difficult to get the right permissions restored

**Workarounds Used**:
- Used human IAM user for critical Terraform applies when OIDC role was blocked
- Temporarily gave broader permissions during repair phases (with plan to tighten later)
- Manual password resets on RDS when automated paths were blocked

---

### 4. Amazon Linux 2 Package Reality Check

Many assumptions from modern Linux or local development broke here:

- `yum install nginx` → does not exist in base repos
- Default `nodejs` package → too old and caused glibc errors
- Need for `amazon-linux-extras` for several packages

This forced us to hard-code the exact installation methods that actually worked during manual debugging.

---

### 5. ASG + Instance Refresh Pain

- Old AWS CLI versions didn't support `--instance-refresh-id`
- Instances would be terminated while we were debugging them
- Health checks (EC2 type) would kill instances before we finished fixing them

**Mitigations**:
- Upgraded AWS CLI in the pipeline before running refreshes
- Used defensive early placeholder HTML + `/health` file in user-data so ALB stayed happy during rollouts

---

## Current State (as of latest session)

- Both instances in the dev ASG are healthy behind the ALB
- React frontend loads correctly through the public ALB
- Node.js backend is running on both instances
- Tasks created in the UI are successfully saved to RDS MySQL and visible after refresh
- The improved user-data script now handles Node 16, nginx, region, and SSM credentials automatically
- The `db_host` SSM parameter has been cleaned (no more `:3306`)

**Still Fragile Areas**:
- Terraform is not well isolated between environments (causes errors when deploying to staging/prod)
- Pipeline still uses defensive "non-fatal issues" pattern
- No automated promotion flow with PRs yet (manual workflow_dispatch or push triggers)

---

## What We Have Left / Roadmap

### Immediate / High Priority
- Verify the new user-data script works cleanly on fresh instances after the SSM parameter fix
- Update documentation (this file + README + PRESENTATION_NOTES)
- Decide on next infrastructure improvement (ECS Fargate vs stay on EC2)

### Pipeline & Process
- Implement proper branch promotion flow:
  - Push to `development` → auto PR to `staging`
  - Merge to `staging` (manual approval) → deploy to staging
  - After staging passes → auto PR to `production`
  - Merge to `production` (manual approval) → deploy to prod
- Improve Terraform environment isolation (workspaces or separate state files)

### Next Technical Domains (Instructor 4-Domain Model)
1. **Security** — Add Trivy scanning in pipeline, improve IAM least-privilege, consider Secrets Manager
2. **Monitoring / Observability** — CloudWatch Alarms + SNS notifications
3. **Operations & Reliability** — Better rollback strategy, improved health checks, Ansible for config management

### Longer Term
- Containerize backend and move to ECS Fargate
- Add proper integration tests
- Explore Ansible + GitOps patterns

---

## AWS PowerShell Cheat Sheet (Most Used Commands)

### Instance & ASG Management

```powershell
# List current instances in the ASG with health
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState,AvailabilityZone]" `
  --output table

# Start an Instance Refresh (after user-data or Launch Template changes)
aws autoscaling start-instance-refresh `
  --auto-scaling-group-name ha-project-asg `
  --strategy Rolling `
  --preferences MinHealthyPercentage=50,InstanceWarmup=90 `
  --region us-east-1
```

### Session Manager Access

```powershell
# Connect to an instance
aws ssm start-session --target i-032be2d59ff5a3000

# Find instance IDs first if you don't have them
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].InstanceId" `
  --output text
```

### ALB / Target Group Health

```powershell
aws elbv2 describe-target-health `
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:866934333672:targetgroup/ha-project-tg/afabd001a6045675 `
  --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]" `
  --output table
```

### SSM Parameters (with path protection)

```powershell
# Set a parameter safely from PowerShell
$env:MSYS_NO_PATHCONV = "1"
aws ssm put-parameter `
  --name "/ha-project/development/db_host" `
  --value "myapp-rds.cefo7yhuwfxg.us-east-1.rds.amazonaws.com" `
  --type String `
  --overwrite
Remove-Item Env:MSYS_NO_PATHCONV

# Read a parameter
aws ssm get-parameter `
  --name "/ha-project/development/db_host" `
  --query "Parameter.Value" `
  --output text
```

### Useful One-Liners Inside EC2 (via Session Manager)

```bash
# View full bootstrap log (extremely valuable)
cat /var/log/user-data.log

# Check both services
sudo systemctl status ha-backend nginx

# Quick API test from the instance
curl -s http://localhost/api/tasks?userId=demo-user-123 | head -c 400
```

---

## Other Useful Commands

### Terraform (with common flags used in this project)

```powershell
# Safe apply used in pipeline (with known existing resource warnings)
terraform apply -refresh=false -lock=false -var="environment=development" -auto-approve
```

### GitHub Actions Related

- Trigger manual workflow: Go to Actions tab → Select workflow → "Run workflow"
- Check specific run logs for Terraform vs deployment stages

---

## Final Notes

This project taught far more through the failures and debugging sessions than through the clean successes. The biggest wins were:

- Learning to make user-data resilient instead of relying on manual fixes
- Understanding how small details (region, package sources, parameter formatting) can completely break automated infrastructure
- Experiencing real IAM and permissions friction that exists in actual companies

Documenting this journey honestly is more valuable than pretending everything worked smoothly the first time.

---

*Last major update: June 2026*
