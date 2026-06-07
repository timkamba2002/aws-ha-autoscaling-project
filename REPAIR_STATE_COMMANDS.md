# Terraform State Repair Guide - HA Project

**Goal**: Stop Terraform from trying to CREATE resources that already exist in AWS (S3, IAM Role, VPC, EIP, etc).
Use remote backend + import existing resources into state. NO destroy/recreate.

---

## 1. One-time: Clean up local mess (run these first)

```powershell
# From repo root (C:\Users\Timothy Kamba\aws-ha-autoscaling-project)
cd "C:\Users\Timothy Kamba\aws-ha-autoscaling-project"

# Remove the confusing nested duplicate copy (untracked junk)
Remove-Item -Recurse -Force aws-ha-autoscaling-project -ErrorAction SilentlyContinue

# Remove stale local state files (we use remote now)
Remove-Item -Force terraform\terraform.tfstate* -ErrorAction SilentlyContinue
Remove-Item -Force terraform\modules\vpc\terraform.tfstate* -ErrorAction SilentlyContinue

# Make sure tracked junk states are gone from git
git rm --cached terraform/terraform.tfstate terraform/modules/vpc/terraform.tfstate 2>$null

git status
```

---

## 2. One-time: Create Remote Backend Resources (S3 + DynamoDB)

Run in a terminal with AWS credentials that can create S3/DynamoDB/IAM updates (your admin creds or the deploy role if it has perms).

```powershell
$AWS_REGION = "us-east-1"
$STATE_BUCKET = "ha-project-terraform-state-866934333672"
$LOCK_TABLE = "ha-project-terraform-locks"

# S3 bucket for state (us-east-1 has special syntax)
aws s3api create-bucket --bucket $STATE_BUCKET --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket $STATE_BUCKET `
  --versioning-configuration Status=Enabled

# DynamoDB for locking (pay-per-request is fine for TF)
aws dynamodb create-table `
  --table-name $LOCK_TABLE `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region $AWS_REGION

echo "Backend resources created. Now update IAM policy for the GitHub OIDC role."
```

**Update the GitHubActionsDeployRole-HAProjectV2 trust/policy** to allow access to the state bucket and lock table (add via IAM console or CLI). Minimal policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::ha-project-terraform-state-866934333672",
        "arn:aws:s3:::ha-project-terraform-state-866934333672/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:866934333672:table/ha-project-terraform-locks"
    }
  ]
}
```

Also ensure the role has broad permissions for the resources TF manages (ec2, iam, autoscaling, rds, s3, etc). You can attach AdministratorAccess for speed during repair (remove later).

---

## 3. Discover Existing Resource IDs (run locally with AWS creds)

```powershell
# Set your AWS creds first (aws configure or env vars)
aws sts get-caller-identity

# === Key ones causing your errors ===
$FRONTEND_BUCKET = "ha-project-frontend-builds"
aws s3 ls s3://$FRONTEND_BUCKET   # confirm exists

aws iam get-role --role-name ha-project-ec2-frontend-role

# VPC used by your running ALB/ASG (critical - find the one with your resources)
$ALB_VPC_ID = aws elbv2 describe-load-balancers --names ha-project-alb --query "LoadBalancers[0].VpcId" --output text
echo "Your ALB is in VPC: $ALB_VPC_ID"

# All VPCs (see which one has your subnets/instances)
aws ec2 describe-vpcs --query "Vpcs[].[VpcId, CidrBlock, Tags[?Key=='Name'].Value|[0]]" --output table

# EIPs (find the one for NAT)
aws ec2 describe-addresses --query "Addresses[].[AllocationId, PublicIp, AssociationId, Tags[?Key=='Name'].Value|[0]]" --output table

# Subnets in your VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$ALB_VPC_ID" --query "Subnets[].[SubnetId, CidrBlock, AvailabilityZone, Tags[?Key=='Name'].Value|[0]]" --output table

# Security Groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$ALB_VPC_ID" --query "SecurityGroups[].[GroupId, GroupName]" --output table

# RDS
aws rds describe-db-instances --db-instance-identifier myapp-rds --query "DBInstances[0].[DBInstanceIdentifier, Endpoint.Address, DBSubnetGroup.VpcId]"

# ASG, Launch Template, etc.
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ha-project-asg
aws ec2 describe-launch-templates --filters "Name=launch-template-name,Values=ha-project-lt*"
```

**Save the IDs** - you will use them in the import commands below.

---

## 4. Repair State Locally (the critical part)

```powershell
cd terraform

# 1. Init against the NEW remote backend (this creates the state file in S3 if missing)
terraform init `
  -backend-config="bucket=ha-project-terraform-state-866934333672" `
  -backend-config="key=ha-project/development/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=ha-project-terraform-locks" `
  -backend-config="encrypt=true" `
  -reconfigure

# 2. Import existing resources into the remote state.
# Run these ONE BY ONE. Some will fail if names/IDs don't match exactly - adjust and retry.
# Order: foundational first (VPC, then subnets, gateways, then SGs, ALB, etc.)

# --- VPC + Networking (the ones hitting VpcLimitExceeded / AddressLimitExceeded) ---
terraform import module.vpc.aws_vpc.main vpc-0abc123def4567890          # <-- REPLACE with real ID from step 3

terraform import module.vpc.aws_subnet.public_a subnet-0123456789abcdef0
terraform import module.vpc.aws_subnet.public_b subnet-0fedcba9876543210
terraform import module.vpc.aws_subnet.private_a subnet-0a1b2c3d4e5f67890
terraform import module.vpc.aws_subnet.private_b subnet-0b1c2d3e4f5a67891

terraform import module.vpc.aws_internet_gateway.igw igw-0a1b2c3d4e5f67890
terraform import module.vpc.aws_eip.nat_eip eipalloc-0a1b2c3d4e5f67890     # the one used by your NAT

terraform import module.vpc.aws_nat_gateway.nat_gw nat-0a1b2c3d4e5f67890
terraform import module.vpc.aws_route_table.public rtb-0a1b2c3d4e5f67890
terraform import module.vpc.aws_route_table.private_rt rtb-0fedcba987654321

# Route table associations (use the actual association IDs or the subnet+rtb pair - import by ID)
terraform import module.vpc.aws_route_table_association.public_a subnet-0123...:rtb-0abc...
# (Terraform usually accepts the subnet ID for association resources in recent versions; check docs)

# Repeat for the other 3 associations...

# --- S3 + IAM (the ones hitting BucketAlreadyExists / EntityAlreadyExists) ---
terraform import aws_s3_bucket.frontend_builds ha-project-frontend-builds
terraform import aws_s3_bucket_public_access_block.frontend_builds ha-project-frontend-builds
terraform import aws_s3_bucket_versioning.frontend_builds ha-project-frontend-builds

terraform import module.ec2.aws_iam_role.ec2_role ha-project-ec2-frontend-role
terraform import module.ec2.aws_iam_instance_profile.ec2_profile ha-project-ec2-frontend-profile

# The inline policy name is usually "S3FrontendBuildRead" or check with: aws iam list-role-policies --role-name ha-project-ec2-frontend-role
terraform import module.ec2.aws_iam_role_policy.s3_frontend_read ha-project-ec2-frontend-role:S3FrontendBuildRead

# --- Security Groups ---
terraform import module.security_groups.aws_security_group.alb_sg sg-0abc123def456   # use real GroupId
terraform import module.security_groups.aws_security_group.ec2_sg sg-0def456abc789

terraform import aws_security_group.rds_sg sg-0123rds456

# --- ALB / TG / Listener ---
terraform import module.alb.aws_lb.alb arn:aws:elasticloadbalancing:us-east-1:866934333672:loadbalancer/app/ha-project-alb/1234567890abcdef
terraform import module.alb.aws_lb_target_group.tg arn:aws:elasticloadbalancing:us-east-1:866934333672:targetgroup/ha-project-tg/1234567890abcdef
terraform import module.alb.aws_lb_listener.listener arn:aws:elasticloadbalancing:us-east-1:866934333672:listener/app/ha-project-alb/1234567890abcdef/80abcdef12345678

# --- Launch Template + ASG ---
terraform import module.ec2.aws_launch_template.lt lt-0a1b2c3d4e5f67890
terraform import module.autoscaling.aws_autoscaling_group.asg ha-project-asg

# --- RDS (if it exists and you want TF to manage it) ---
terraform import aws_db_subnet_group.main main-db-subnet-group
terraform import aws_db_instance.main myapp-rds

# 3. After imports, run plan to see drift
terraform plan -var="db_password=THE_REAL_PASSWORD" -var="environment=development"

# 4. If plan looks reasonable (or only shows ignorable diffs like user_data, tags, AMIs), push state + code
#    Then commit and push so CI uses the good remote state.
```

**Common import fixes**:
- For `aws_lb_listener`: the ID is the full ARN of the listener.
- If a resource doesn't exist in AWS exactly as coded (different name), either:
  - Temporarily comment it out in .tf, import what you can, or
  - Use `terraform state rm <address>` for ones you don't want managed yet.
- Launch template user_data will almost always show as changed after import → add `lifecycle { ignore_changes = [user_data] }` to the lt resource if you don't want it to replace instances every apply.

---

## 5. After Repair - Make CI Green

1. `git add -A`
2. `git commit -m "fix: remote S3 backend + importable resources + targeted deploy job"`
3. `git push origin development`

The next push to development will run:
- Build React
- Test & Plan (uses remote state, should show no-op or small drift)
- Deploy to Development (targeted foundational then full apply + sync build to S3)

---

## 6. React To-Do + RDS (eventual)

Current TF serves static React via httpd on the ASG instances. The TodoApp.tsx hardcodes an old ALB DNS for `/api`.

After this repair:
- Update `app/src/components/TodoApp.tsx` → change `API_BASE` to the real output value (`terraform output alb_dns_name`)
- Deploy a real backend (Express in `app/app.js` or the one in your local backend/server.js) onto the EC2s:
  - Extend user-data.sh.tpl to also install Node, your backend code (or pull from S3), run it on port 3000 with PM2.
  - Use nginx or httpd ProxyPass /api → localhost:3000
  - Or create a second ALB target group + listener rule for path `/api*` → backend ASG (more "HA" but more complex for Monday).

For demo on Monday you can:
- Hardcode the correct ALB DNS in the React code for now
- Or make the TodoApp use localStorage only (no backend) and note "RDS backend coming in Staging"
- Or manually SSH one instance and run the backend temporarily.

The RDS is created by TF (if you imported or let it create). Use the `terraform output rds_endpoint` + secret to connect your backend.

---

## 7. Quick Local Test After Imports

```powershell
cd terraform
terraform init -reconfigure   # (with the -backend-config flags as above)
terraform plan -var="db_password=xxx" -var="environment=development"
```

If clean or only expected diffs → you are good for the presentation.

---

**Do this before Monday morning.** Once the remote state has the imported resources, every future `terraform plan/apply` (local or CI) will see the real world and only do incremental changes.

Good luck with the demo!
