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
## 8. Auditing VPC and NAT Gateways (for cost and limits)

> **Run everything in this section from your laptop PowerShell (Windows Terminal recommended).**

### June 2026 Audit — Your Exact Results
You ran the basic tag queries and saw:

```
9 ha-project-vpc (all "available")
9 NAT Gateways total in account
5 of them tagged "ha-project-nat-gateway" (all available)
+ others from EKS / other projects
ha-project-private-rt 0.0.0.0/0 NAT query returned blank (no output)
```

**Direct answer to your (and your colleague's) question:**

**No — 9 VPCs and 5 ha-project NAT Gateways are NOT on purpose and are not the design.**

**What you should have (realistic target):**
- 1 "good" VPC + 1 NAT Gateway that your current ASG instances, ALB, and RDS subnet group are actually using.
- Up to 2 more (one per additional environment) if you want full network isolation between dev/staging/prod.
- **Total expected in a clean 3-env setup: 1–3 VPCs + 1–3 NATs** (depending on isolation choice).
- The vpc module ([terraform/modules/vpc/main.tf](terraform/modules/vpc/main.tf)) hard-codes:
  - `Name = "ha-project-vpc"`
  - `Name = "ha-project-nat-gateway"`
  - `Name = "ha-project-private-rt"`
  - CIDR `10.0.0.0/16`
  - No `var.environment` used in the module call in main.tf.

Because you (correctly) use **separate remote state keys** per environment (`ha-project/development/terraform.tfstate`, `/staging/...`, `/production/...`), each independent state "wants" to create its own full copy of the network. During the long repair/debug phase (repeated applies, manual human-credential applies, state repair attempts, staging/prod experiments while fixing user-data/SSM/RDS), Terraform created duplicate sets. This is the same root cause as the earlier `VpcLimitExceeded` / `AddressLimitExceeded` errors you saw.

### Live Resource Discovery (Start Here — Current Fleet)
The **only** VPC/NAT that matters right now is the one your two post-refresh healthy instances are using:

```powershell
# === 1. Confirm your current live instances (from the successful 30e12a52 refresh) ===
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names ha-project-asg `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState,AvailabilityZone]" `
  --output table

# Exact IDs from your last verify run
$INSTANCES = @("i-02689450a477ba8d1","i-06565e76c00a3b756")

# === 2. Find which VPC + subnets your live instances actually live in (this is the "good" one) ===
aws ec2 describe-instances `
  --instance-ids $INSTANCES `
  --query "Reservations[*].Instances[*].[InstanceId,VpcId,SubnetId,Placement.AvailabilityZone,State.Name]" `
  --output table

$LIVE_VPC = aws ec2 describe-instances --instance-ids i-02689450a477ba8d1 --query "Reservations[0].Instances[0].VpcId" --output text
echo "LIVE VPC (the one that actually matters): $LIVE_VPC"

# Cross-check with ALB and RDS (should match the live VPC)
$ALB_VPC = aws elbv2 describe-load-balancers --names ha-project-alb --query "LoadBalancers[0].VpcId" --output text
echo "ALB VPC: $ALB_VPC"

$ RDS_VPC = aws rds describe-db-instances --db-instance-identifier myapp-rds --query "DBInstances[0].DBSubnetGroup.VpcId" --output text
echo "RDS (myapp-rds) VPC: $RDS_VPC"
```

### Find the Live NAT + Private Route Table (in the LIVE VPC)
```powershell
# NAT Gateways that exist inside the live VPC
aws ec2 describe-nat-gateways `
  --filter "Name=vpc-id,Values=$LIVE_VPC" `
  --query "NatGateways[*].[NatGatewayId,State,SubnetId,Tags[?Key=='Name'].Value|[0]]" `
  --output table

# All route tables in the live VPC + the 0.0.0.0/0 next hop (this is the reliable way)
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values=$LIVE_VPC" `
  --query "RouteTables[*].[RouteTableId, Tags[?Key=='Name'].Value|[0], Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId|[0], Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId|[0] ]" `
  --output table

# Private subnets in the live VPC (your ASG instances should be here)
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=$LIVE_VPC" "Name=tag:Name,Values=private-subnet*" `
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key=='Name'].Value|[0]]" `
  --output table
```

### What Terraform Thinks It Owns (per environment state)
Run this for **each** environment. This tells you which VPC IDs are "claimed" by your TF states vs. true orphans.

```powershell
cd terraform

# --- DEVELOPMENT state ---
terraform init `
  -backend-config="bucket=ha-project-terraform-state-866934333672" `
  -backend-config="key=ha-project/development/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="use_lockfile=true" `
  -backend-config="encrypt=true" `
  -reconfigure

terraform state list | Select-String -Pattern 'vpc|nat_gateway|aws_eip|subnet|route_table'
# To see the actual VPC ID recorded in dev state:
terraform state show module.vpc.aws_vpc.main | Select-String '^\s+id\s+='

# --- Repeat for STAGING (change the key) ---
terraform init `
  -backend-config="bucket=ha-project-terraform-state-866934333672" `
  -backend-config="key=ha-project/staging/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="use_lockfile=true" `
  -backend-config="encrypt=true" `
  -reconfigure

terraform state list | Select-String -Pattern 'vpc|nat_gateway|aws_eip|subnet|route_table'
terraform state show module.vpc.aws_vpc.main | Select-String '^\s+id\s+='

# --- PRODUCTION ---
# (same pattern, key=ha-project/production/terraform.tfstate)
```

Compare the VPC IDs from `terraform state show` against the `$LIVE_VPC` from your live instances. The ones that match your live instances + ALB + RDS are "yours". The rest of the 9 are repair-phase orphans.

### Cost Reality
Each NAT Gateway costs ~$32–36/month (per AZ) + data processing fees. 5× ha-project NATs = real money even if idle. EIPs attached to deleted NATs that are still allocated also cost ~$3.65/mo each until released.

### Cleanup Strategy (Only After You Have Identified the Live One)
1. Confirm the live VPC (from instances/ALB/RDS) and its NAT.
2. For every other VPC tagged ha-project-vpc:
   - Check it has **zero** running instances, zero ENIs in use, zero ALB/NLB, zero RDS subnet groups, and is not listed in any of the three TF states above.
   - Then (in dependency order): delete NAT Gateway → release its EIP → delete routes/RT associations → delete subnets → delete IGW → delete VPC.
3. Never delete the live one.

**Deletion commands (example for a known-orphan VPC — replace the ID):**
```powershell
# WARNING: Only run on confirmed orphans after the discovery steps above
$ORPHAN_VPC = "vpc-0a5766fc696cbc957"   # example — verify first!

# 1. Find and delete NAT + EIP in it
$NAT = aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$ORPHAN_VPC" --query "NatGateways[0].NatGatewayId" --output text
if ($NAT -and $NAT -ne "None") {
  $EIP_ALLOC = aws ec2 describe-nat-gateways --nat-gateway-ids $NAT --query "NatGateways[0].NatGatewayAddresses[0].AllocationId" --output text
  aws ec2 delete-nat-gateway --nat-gateway-id $NAT
  # wait for deleted state, then:
  aws ec2 release-address --allocation-id $EIP_ALLOC
}

# 2. Detach IGW, delete subnets, route tables, then VPC (full sequence in AWS_COMMANDS or console is safer for first time)
```

**Strong recommendation**: Do the discovery first. Paste the output of the live discovery block + the three `terraform state show` results here if you want me to help you mark exactly which  VPCs are safe to nuke.

After cleanup, re-run the basic tag queries — you should see 1 (or at most 3) ha-project-vpc and matching NATs.

This audit + cleanup is now part of the **Operations & Reliability** story for your presentation (you detected excess spend, traced root cause to IaC design, verified no impact on running fleet via successful Instance Refresh, and have a plan to clean it).

*Last updated: June 2026 (post 30e12a52 refresh + 9-VPC audit)*
