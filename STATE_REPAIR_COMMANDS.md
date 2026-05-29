# URGENT: Terraform State Repair Commands (Run These FIRST)

**Goal**: Stop all "already exists" errors (S3, IAM role, VPC, EIP, RDS subnet group, ALB, etc.) without destroying anything.

---

## STEP 1: Clean Local Junk (Run Now)

```powershell
cd "C:\Users\Timothy Kamba\aws-ha-autoscaling-project"

# Remove the duplicate nested project (biggest source of confusion)
Remove-Item -Recurse -Force aws-ha-autoscaling-project -ErrorAction SilentlyContinue

# Remove any local state files (we are moving to remote S3 backend)
Remove-Item -Force terraform\*.tfstate* -ErrorAction SilentlyContinue
Remove-Item -Force terraform\modules\vpc\*.tfstate* -ErrorAction SilentlyContinue

git rm --cached terraform/terraform.tfstate terraform/modules/vpc/terraform.tfstate 2>$null

git status
```

---

## STEP 2: Create Remote Backend (S3 + DynamoDB) — ONE TIME

Run these with an account that can create S3/DynamoDB (your personal AWS creds or admin role):

```powershell
$BUCKET = "ha-project-terraform-state-866934333672"
$TABLE  = "ha-project-terraform-locks"
$REGION = "us-east-1"

aws s3api create-bucket --bucket $BUCKET --region $REGION

aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled

aws dynamodb create-table `
  --table-name $TABLE `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region $REGION

echo "Backend infrastructure created."
```

**Add this policy** to your GitHub OIDC role (`GitHubActionsDeployRole-HAProjectV2`) so CI can write state:

(Use IAM console → attach inline policy)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": ["arn:aws:s3:::ha-project-terraform-state-866934333672", "arn:aws:s3:::ha-project-terraform-state-866934333672/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:*"],
      "Resource": "arn:aws:dynamodb:us-east-1:866934333672:table/ha-project-terraform-locks"
    }
  ]
}
```

---

## STEP 3: Discover Your Existing Resource IDs (Critical)

```powershell
aws sts get-caller-identity

# Find the VPC that your current ALB + ASG are actually using
$ALB_VPC = aws elbv2 describe-load-balancers --names ha-project-alb --query "LoadBalancers[0].VpcId" --output text
echo "VPC in use by ALB: $ALB_VPC"

# List everything in that VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$ALB_VPC" --query "Subnets[].[SubnetId, CidrBlock, Tags[?Key=='Name'].Value|[0]]" --output table

aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$ALB_VPC" --query "SecurityGroups[].[GroupId, GroupName]" --output table

# EIP / NAT
aws ec2 describe-addresses --query "Addresses[].[AllocationId, PublicIp, Tags]" --output table

# RDS (current MySQL or new Postgres)
aws rds describe-db-instances --query "DBInstances[].[DBInstanceIdentifier, Engine, Endpoint.Address]" --output table

# ALB ARN (for import)
aws elbv2 describe-load-balancers --names ha-project-alb --query "LoadBalancers[0].LoadBalancerArn" --output text
```

**Write down the real IDs** — you will paste them into import commands.

---

## STEP 4: Repair State Locally (The Fix)

```powershell
cd terraform

# 1. Fresh init against remote backend
terraform init `
  -backend-config="bucket=ha-project-terraform-state-866934333672" `
  -backend-config="key=ha-project/development/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=ha-project-terraform-locks" `
  -backend-config="encrypt=true" `
  -reconfigure

# 2. IMPORT the real resources (run one by one, replace IDs)

# === Networking (the ones causing VpcLimitExceeded + EIP limit) ===
terraform import module.vpc.aws_vpc.main vpc-0123456789abcdef0
terraform import module.vpc.aws_subnet.public_a subnet-0aaa1111bbbb2222
terraform import module.vpc.aws_subnet.public_b subnet-0ccc3333dddd4444
terraform import module.vpc.aws_subnet.private_a subnet-0eee5555ffff6666
terraform import module.vpc.aws_subnet.private_b subnet-0ggg7777hhhh8888

terraform import module.vpc.aws_internet_gateway.igw igw-0aabbccdd11223344
terraform import module.vpc.aws_eip.nat_eip eipalloc-0a1b2c3d4e5f67890
terraform import module.vpc.aws_nat_gateway.nat_gw nat-0aabb112233445566

# Route tables + associations (use subnet ID or association ID)
terraform import module.vpc.aws_route_table.public rtb-0aabb1122334455
terraform import module.vpc.aws_route_table.private_rt rtb-0ccdd3344556677
terraform import 'module.vpc.aws_route_table_association.public_a' subnet-0aaa1111bbbb2222

# === S3 + IAM (the "already exists" ones) ===
terraform import aws_s3_bucket.frontend_builds ha-project-frontend-builds
terraform import aws_s3_bucket_public_access_block.frontend_builds ha-project-frontend-builds
terraform import aws_s3_bucket_versioning.frontend_builds ha-project-frontend-builds

terraform import module.ec2.aws_iam_role.ec2_role ha-project-ec2-frontend-role
terraform import module.ec2.aws_iam_instance_profile.ec2_profile ha-project-ec2-frontend-profile
terraform import 'module.ec2.aws_iam_role_policy.s3_frontend_read' 'ha-project-ec2-frontend-role:S3FrontendBuildRead'

# === Security Groups ===
terraform import module.security_groups.aws_security_group.alb_sg sg-0abc123def456789
terraform import module.security_groups.aws_security_group.ec2_sg sg-0def456abc789012

# === ALB + Target Group + Listener (use full ARNs) ===
terraform import module.alb.aws_lb.alb arn:aws:elasticloadbalancing:us-east-1:866934333672:loadbalancer/app/ha-project-alb/...
terraform import module.alb.aws_lb_target_group.tg arn:aws:elasticloadbalancing:us-east-1:866934333672:targetgroup/ha-project-tg/...
terraform import module.alb.aws_lb_listener.listener arn:aws:elasticloadbalancing:us-east-1:866934333672:listener/app/ha-project-alb/.../...

# === Launch Template + ASG ===
terraform import module.ec2.aws_launch_template.lt lt-0aabbcc11223344
terraform import module.autoscaling.aws_autoscaling_group.asg ha-project-asg

# === RDS (import your existing one, or the new Postgres after it is created) ===
terraform import aws_db_subnet_group.main main-db-subnet-group
terraform import aws_security_group.rds_sg sg-0rds123456789
terraform import aws_db_instance.main ha-project-postgres     # or myapp-rds if keeping MySQL

# 3. After imports
terraform plan -var="db_password=YOUR_REAL_DB_PASSWORD" -var="environment=development"

# If plan is mostly clean (some diffs on user_data / tags are normal), you are done.
```

---

## STEP 5: Push the Fixed State

```powershell
git add -A
git commit -m "fix: remote S3 backend + import all existing resources + full 3-tier pipeline + Postgres support"
git push origin development
```

The next pipeline run on `development` will use the healthy remote state + targeted applies and should succeed.

---

**After repair you must still**:
1. Copy your real React code into `app/` at root (so the build job works).
2. Update `TodoApp.tsx` with the real ALB DNS from `terraform output alb_dns_name`.
3. Run the DDL from `database/init.sql` against your RDS Postgres (or let the backend create tables on first insert).
4. Make sure the GitHub secret `DB_PASSWORD` is set.

Do the imports today. Everything else can be iterated tomorrow.
