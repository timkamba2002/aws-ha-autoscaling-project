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

**Live / Good VPC identified in your latest run (June 2026):**
**`vpc-0d4035555d90998ca`** (confirmed by the instance query, ALB, *and* myapp-rds — this is the only one that matters).

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

### Live Resource Discovery — Audit Progress (your latest run)
**LIVE / GOOD VPC definitively identified as of your last paste:**

- `vpc-0d4035555d90998ca`
- Confirmed three independent ways:
  - Direct assignment from `describe-instances i-02689450a477ba8d1`
  - ALB (`ha-project-alb`) lives in it
  - RDS (`myapp-rds`) DB subnet group lives in it

This matches one of the 9 VPCs from your earlier `describe-vpcs` output.

**Note on the "None" you saw on re-run**: Classic PowerShell + backtick + AWS CLI quoting gotcha on Windows (variable reuse after multi-line commands). The first successful assignment + ALB + RDS cross-checks are solid. We now hard-code the ID in all follow-up commands.

The **only** VPC/NAT that matters right now is `vpc-0d4035555d90998ca`. All the other 8 ha-project VPCs (and the extra NATs) are repair-phase orphans.

### Findings from your deep dive on the live VPC (vpc-0d4035555d90998ca)
**NAT Gateways in the live VPC (2 instead of the expected 1):**
- `nat-0ab01038ba460d225` (available, in subnet-00ae5298d65cd5c75, EIP 35.169.36.81 / eipalloc-076205a7568b639f4, tagged ha-project-nat-gateway)
- `nat-07c6d2c9339ae5bd7` (available, in subnet-00ae5298d65cd5c75, EIP 100.26.76.73 / eipalloc-03f116e885ef0e7db, tagged ha-project-nat-gateway)

Both NATs are in the **same** public subnet (subnet-00ae5298d65cd5c75 — this is the public-a from the module).

**Route Tables in the live VPC (duplication — 3 tagged ha-project-private-rt instead of 1):**
- rtb-00482bebb8e54e0a5 (ha-project-private-rt) → 0.0.0.0/0 via **nat-0ab01038ba460d225**
- rtb-0a6315518589aaf19 (ha-project-private-rt) → 0.0.0.0/0 via **nat-0ab01038ba460d225**
- rtb-09529f75012db6772 (ha-project-private-rt) → 0.0.0.0/0 via **nat-025bb57097ddf02c9** (note: this NAT ID was *not* returned by the scoped query above — it may live in a different VPC or be a cross-reference orphan)
- rtb-046b92ace339e8922 (public-route-table) → 0.0.0.0/0 via igw-060f81f1a88936545 (correct for public)
- One untagged/None RT (rtb-096a1f8e15f935806)

**Private subnets (confirmed from both deep dive and TF state — these are the ones the module creates and TF owns):**
- subnet-01d86811e7aa5b89b (10.0.3.0/24, us-east-1a, private-subnet-a)   ← from `terraform state show module.vpc.aws_subnet.private_a`
- subnet-04412d44ddea1b645 (10.0.4.0/24, us-east-1b, private-subnet-b)   ← from `terraform state show module.vpc.aws_subnet.private_b`

These IDs match exactly what was seen in the live VPC deep dive.

**Network Interfaces (in-use attachments in this VPC):**
- ALB interfaces (good)
- RDS interface (good)
- Interface for NAT nat-0ab01038ba460d225 (good)
- Interface for NAT nat-07c6d2c9339ae5bd7 (the second NAT)
- Two other instance ENIs (i-0f255a80252d2695b and i-09ac736545e49f795) — these are likely previous ASG instances or other resources. Your current post-refresh instances (i-02689450a477ba8d1, i-06565e76c00a3b756) did not appear in this slice of the output.

**Key observations / problems even in the "live" VPC:**
- Duplication inside a single VPC (2 NATs, 3 private RTs with the same tag).
- One private RT points to a NAT ID that the scoped query didn't return for this VPC (nat-025bb57097ddf02c9). This suggests either a route pointing across VPCs (bad) or that NAT lives elsewhere.
- The current ASG instances' exact SubnetIds were not in the pasted output of the block (the command ran but the table result isn't shown here). We need those to know exactly which RT/NAT the live fleet is currently using.

**Findings from TF state inspection (development backend, successful remote init):**
- The development state **owns exactly our live VPC**:
  - `module.vpc.aws_vpc.main` = `vpc-0d4035555d90998ca` (matches)
- The "official" NAT per TF:
  - `module.vpc.aws_nat_gateway.nat_gw` = `nat-0ab01038ba460d225` (the first one we saw; allocation eipalloc-076205a7568b639f4, public 35.169.36.81)
- The "official" private RT per TF:
  - `module.vpc.aws_route_table.private_rt` = `rtb-0a6315518589aaf19` (points to the above NAT)

This is great — TF's desired state for development matches the live resources we want to keep.

**Still present in the live VPC but NOT in the development TF state (duplicates/orphans inside the good VPC):**
- Extra NAT: `nat-07c6d2c9339ae5bd7` (the second one, same public subnet, different EIP)
- Extra private RTs:
  - `rtb-00482bebb8e54e0a5` (also points to the good NAT `nat-0ab01038ba460d225`)
  - `rtb-09529f75012db6772` (pointed to the now-deleted `nat-025bb57097ddf02c9`)
- The mystery NAT `nat-025bb57097ddf02c9` is **gone** (NatGatewayNotFound) — it was already cleaned (good).

The private subnets listed earlier match what the module creates (we can confirm exact IDs from `terraform state show module.vpc.aws_subnet.private_a` etc.).

**Latest from your run (subnets confirmed + associations + staging):**
- **Private subnets are correctly wired** to the TF-owned RT:
  - subnet-01d86811e7aa5b89b (private_a) → rtb-0a6315518589aaf19 (ha-project-private-rt)
  - subnet-04412d44ddea1b645 (private_b) → rtb-0a6315518589aaf19 (ha-project-private-rt)
  - This is **exactly** the RT owned by the development state (`module.vpc.aws_route_table.private_rt`).
  - Great news: the live ASG private subnets are attached to the correct/good RT (the one that points to the good NAT `nat-0ab01038ba460d225`).

- Current live InService instances (from ASG at the time of the run):
  - i-09ac736545e49f795
  - i-0f255a80252d2695b
  - (Note: these are newer than the ones from the 30e12a52 refresh you mentioned earlier; the fleet has rolled since then. Their ENIs were previously seen in the live VPC.)

- Staging state (after init):
  - `terraform state list` (full) only showed SSM parameters: `data.aws_ssm_parameter.db_password` and `aws_ssm_parameter.db_user`.
  - No network resources at all (`module.vpc.*` or raw vpc/nat/subnet/route_table resources).
  - **Conclusion**: Only the development state owns a VPC. The other 8 ha-project-vpc are unclaimed repair-phase orphans. Staging (and likely production) never got a successful full network stack in their state files.

**Final Live VPC State (after your cleanup run)**

**Achieved: Effectively a single functional NAT gateway.**

- Only **one available NAT** in the live VPC: the TF-owned `nat-0ab01038ba460d225` (in the correct public subnet).
- The extra NAT `nat-07c6d2c9339ae5bd7` is deleted (still visible briefly as "deleted" — AWS keeps the record for a while).
- EIP for the deleted NAT released via Console (as you did).

**Route tables in the live VPC (now 3):**
- `rtb-0a6315518589aaf19` — ha-project-private-rt (good one, TF-managed, used by your private subnets)
- `rtb-046b92ace339e8922` — public-route-table (TF-managed)
- `rtb-096a1f8e15f935806` — the **main/default route table** (untagged, created automatically by AWS when the VPC was first made). This one has only the local route (10.0.0.0/16) and is marked as "Main". 

**Important**: You cannot delete the main route table of a VPC while it is the main one. This is expected AWS behavior. Your explicit subnets (public and private) are associated to the TF-managed public and private route tables, so the main/default RT is not carrying your traffic. It is harmless and does not cost money (no NAT or custom routes attached to it). Leave it.

Your current instances are correctly placed in the TF private subnets and using the correct private RT + NAT.

You now have the practical equivalent of "single_nat_gateway" for the live environment.

### Remaining verification & stray RT cleanup (you already ran most)

From your paste:
- The main RT inspect showed it is the default/main one → delete is blocked (expected, do not force it).
- NAT list and route table list look good (only good NAT active, only good private + public RTs as the functional ones).

Run these for final confirmation after any waits:

```powershell
# NATs (expect 1 available)
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-0d4035555d90998ca" --query "NatGateways[*].[NatGatewayId,State,Tags[?Key=='Name'].Value|[0]]" --output table

# Route tables (expect the 3: main, good private, public)
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0d4035555d90998ca" --query "RouteTables[*].[RouteTableId, Tags[?Key=='Name'].Value|[0], Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId|[0]]" --output table
```

**EIP**: Since you released it via Console, confirm:
```powershell
aws ec2 describe-addresses --query "Addresses[?AllocationId=='eipalloc-03f116e885ef0e7db']" --output table
```

(If gone, success.)

**Current fleet** (you already confirmed correct subnets):
The verify script ran successfully and showed healthy instances in the right subnets + healthy target group.

You also started a fresh Instance Refresh (`74aaf57f-...`). Monitor it with:
```powershell
aws autoscaling describe-instance-refreshes --auto-scaling-group-name ha-project-asg --instance-refresh-ids 74aaf57f-8639-4f4c-bab7-8469add621d6
```

### Terraform state now
With the extras removed, switch back to the development state and run a plan to see how happy TF is:

```powershell
cd terraform
terraform init -backend-config="bucket=ha-project-terraform-state-866934333672" -backend-config="key=ha-project/development/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="use_lockfile=true" -backend-config="encrypt=true" -reconfigure

terraform plan -var="environment=development" -var="db_password=..."   # use the secret if required
```

It should show little or no drift on the network resources it owns.

### The other 8 VPCs (final step for full cleanup)
The live VPC is now in good shape (single functional NAT + correct RTs for your subnets).

To clean the remaining 8 (all unclaimed by dev or staging state):

1. List current ones (excluding the live):
```powershell
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ha-project-vpc" --query "Vpcs[?VpcId!='vpc-0d4035555d90998ca'].[VpcId,State]" --output table
```

2. For each remaining VPC ID, run a quick safety check (should be empty of important resources):
```powershell
# Replace VPC_ID
aws ec2 describe-instances --filters "Name=vpc-id,Values=VPC_ID" --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output table
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=VPC_ID" --query "NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]" --output table
```

3. Safe delete order for an empty orphan VPC (NATs first):
- Delete any NATs in it + release their EIPs
- Delete any non-main route tables (remove custom routes first if needed)
- Detach and delete IGW
- Delete all subnets
- Delete the VPC (the main RT will go with it)

I can give the exact one-off commands for each of the 8 once you paste the current list of remaining VPC IDs from step 1 above.

You are extremely close to a clean, professional, low-cost network footprint. The main RT left behind in the live VPC is normal AWS behavior and not a problem.

### Original Discovery Block (kept for reference / re-running)
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

### (Historical reference only)
The sections below contain older discovery blocks from earlier in the audit. All current "single NAT" and live VPC status information is in the "Live VPC Final State & 'Single NAT' Reality" and "Cleanup of live VPC extras — SUCCESS" sections above. Do not use the old blocks for new work.

### Next Commands After Identifying the Live VPC (vpc-0d4035555d90998ca)
**Run this clean block now** (hard-codes the known-good VPC so you never hit the "None" problem again).

```powershell
# === HARD-CODE THE KNOWN LIVE VPC (from your successful run) ===
$LIVE_VPC = "vpc-0d4035555d90998ca"
echo "=== Working exclusively with LIVE VPC: $LIVE_VPC ==="

# 1. Your two current healthy instances + the *exact SubnetId* they landed in (critical)
aws ec2 describe-instances `
  --instance-ids i-02689450a477ba8d1 i-06565e76c00a3b756 `
  --query "Reservations[*].Instances[*].[InstanceId,SubnetId,VpcId,Placement.AvailabilityZone,State.Name]" `
  --output table

# 2. NAT Gateways *only inside this live VPC* (you should see exactly 1; the other 4 ha-project NATs belong to orphans)
aws ec2 describe-nat-gateways `
  --filter "Name=vpc-id,Values=$LIVE_VPC" `
  --query "NatGateways[*].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp,NatGatewayAddresses[0].AllocationId,Tags[?Key=='Name'].Value|[0]]" `
  --output table

# 3. ALL route tables in the live VPC + what 0.0.0.0/0 actually points to (NAT vs IGW). This is the reliable replacement for the old blank tag query.
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values=$LIVE_VPC" `
  --query "RouteTables[*].[RouteTableId, Tags[?Key=='Name'].Value|[0], Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId|[0], Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId|[0] ]" `
  --output table

# 4. Private subnets (the ones your ASG uses) that exist in this VPC
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=$LIVE_VPC" "Name=tag:Name,Values=private-subnet*" `
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key=='Name'].Value|[0]]" `
  --output table

# 5. Quick view of network interfaces in this VPC (shows what's actually attached and using the NAT)
aws ec2 describe-network-interfaces `
  --filters "Name=vpc-id,Values=$LIVE_VPC" `
  --query "NetworkInterfaces[*].[NetworkInterfaceId,Description,Status,Attachment.InstanceId]" `
  --output table
```

**What success looks like**:
- The two instances table will list their real SubnetId (e.g. subnet-xxx for private-a/b in 10.0.3.0/24 or 10.0.4.0/24).
- NAT table for this VPC will show **one** `nat-...` with a Public IP and AllocationId (this is your live NAT + the EIP costing money for the good VPC).
- Route tables table will have one row with a NatGatewayId under 0.0.0.0/0 and (probably) Name = `ha-project-private-rt`.
- That NatGatewayId from the route table = your **live, in-use NAT**.
- The other 8 VPCs + their NATs have no instances, no ALB, no RDS, and won't be listed in your Terraform states.

Paste the full output of the block above (the four tables are the most important). Then we will run the Terraform state inspection for dev/staging/prod.

### What Terraform Thinks It Owns (per environment state) — Current picture
**Development** (successfully loaded):
- Owns the live VPC + exactly one NAT + exactly one private RT + the four subnets.
- This is the only state that successfully created a full network stack.

**Staging** (you just ran it):
- Only a couple of SSM parameters.
- **No VPC, no NAT, no subnets, no route tables.**
- Therefore it claims none of the 9 ha-project-vpc entries.

**Production**:
- You can repeat the init with the production key the same way if you want a complete map, but given the pattern it is very likely also empty for networking.

**Practical result**:
- Only 1 VPC should exist long-term for the current working environment (the live one).
- The other 8 are unclaimed orphans from the repair phase.
- Inside the live VPC we still had 1 extra NAT + 2 extra private RTs (now being deleted with the commands above).

After you finish the live-VPC cleanup, we can give one command block to discover + safely delete the remaining 8 full VPC stacks (they should have no live ASG/ALB/RDS attachments).

**Note on using the Console for orphan VPC cleanup (recommended on Windows)**

Because of PowerShell + JMESPath quoting issues and hidden "available" resources, the easiest and quickest way for the 8 repair-phase orphan VPCs is the AWS Console:

1. VPC console → filter `tag:Name=ha-project-vpc`
2. Exclude the live one (vpc-0d4035555d90998ca)
3. Select one orphan → Actions → Delete VPC
4. The console will list every remaining blocker with direct delete options.

User progress (console method) — ALL 8 ORPHAN VPCs DELETED (final confirmation):
- Successfully deleted via console Delete VPC wizard (following blockers: NAT then its ENI):
  - vpc-084cc8e1ce18c3354
  - vpc-0a5766fc696cbc957
  - vpc-06021c16505b0a994
  - vpc-0a1da8346d9b54c37
  - vpc-0455cde88ed7b78a1
  - vpc-07d80c2f5cd98524c
  - vpc-09e0e06fee0db1762
  - vpc-0ce050ce3e2267735

Your latest run (after final cleanup):
- VPC list: only the live vpc-0d4035555d90998ca remains
- NATs in live VPC: only the good nat-0ab01038ba460d225
- ALB confirmed in live VPC
- New healthy ASG instances (normal ASG replacement)
- Terraform plan (development): network perfectly in sync. Only the two known pre-existing sensitive drifts (RDS password, db_host SSM) show as ~ update in-place.

You just completed the final Instance Refresh (ID 8f104fa0-8471-4dfc-b9ac-8b75b5b6d4b2) — Status: Successful.

**Your post-refresh verification run (after final cleanup + refresh):**
- Only the live VPC remains: vpc-0d4035555d90998ca
- Only the good NAT in the live VPC: nat-0ab01038ba460d225
- ALB confirmed in live VPC
- Current fleet on new healthy instances (i-0024c06cb73807f3e us-east-1a + i-03965d3d761fd93cc us-east-1b), both InService and healthy in target group
- Terraform plan (development): network perfectly in sync (only the two known pre-existing sensitive drifts on RDS password and db_host SSM)
- API test successful: returned real persisted tasks from RDS (including recent demo data like "gg" and "Demo Task 4")

**You do NOT need to run terraform apply again.** The plan you ran earlier (and any re-run) shows 0 adds/destroys on infrastructure. The live environment is already matching the desired state. The two drifts are harmless sensitive-value comparisons that existed before the orphan cleanup (common with RDS passwords and SSM). You can leave them, or we can add `lifecycle { ignore_changes = [password] }` etc. later if you want a zero-diff plan for the presentation.

**Final recommended steps:**
```powershell
# Re-verify from project root
./scripts/verify-deployment.ps1

# From terraform/ dir, re-init and plan (with db_password var)
cd terraform
terraform init -backend-config="bucket=ha-project-terraform-state-866934333672" -backend-config="key=ha-project/development/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="use_lockfile=true" -backend-config="encrypt=true" -reconfigure
terraform plan -var="environment=development"   # add -var="db_password=..." if needed

# Test the live site (PowerShell version)
(Invoke-WebRequest -Uri "http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/tasks?userId=demo-user-123" -UseBasicParsing).Content.Substring(0,300)
```

The project is now in final clean state: single VPC + single functional NAT, Terraform development state matches reality on the infrastructure, fleet on latest hardened user-data, all repair-phase sprawl removed. Excellent work! This is strong portfolio material (clean IaC, single-VPC design, Terraform matching reality, reliable refresh path, honest documentation of the whole journey). 

If you want a perfectly clean plan for demo, we can add ignore_changes for the sensitive fields. Let me know!

**After this refresh completes (monitor with describe-instance-refreshes):**
- Re-run `./scripts/verify-deployment.ps1`
- Re-run `terraform plan -var="environment=development"` (with db_password var) from the terraform directory.

Network is already perfectly in sync. The account is now clean: 1 ha-project-vpc, 1 functional NAT for the project. Excellent work!

**Promotion flow fix (FINAL - in .github/workflows/deploy.yml):**
The error you pasted ("The 'base' and 'branch' for a pull request must be different branches. Unable to continue.") was from running the old yaml where the peter-evans/create-pull-request step had `branch: staging` and `base: staging` (equal values → hard error in the action).

Even setting different values (e.g. branch: development + base: staging) is risky with this action. The action is designed to *create a new feature branch* from local changes made in the workflow and PR *that* to base. Its internal create-or-update-branch logic (temp branches, resets, cherry-picks, and conditional force pushes to the named `branch:`) assumes `branch:` names a disposable PR patch branch — not a long-lived branch like "development" that is also the current checkout. Using it that way can lead to the local "development" ref being reset/pushed to staging content (corrupting history).

**Final robust fix (replaced the action entirely):**
- Switched both promotion steps (dev→staging and staging→prod) to use the built-in `gh pr create --base <target> --head <source> ...`
- This safely opens a PR between the two *existing* long-lived branches using the GitHub API (no local branch juggling, no risk of resetting dev/staging).
- The PR body/labels match the old intent.
- When a human merges the PR, it performs a push to the target branch → triggers the corresponding deploy job (enforcing the manual gate).
- No extra third-party action; gh CLI is pre-installed on runners; we already had pull-requests:write.

The yml now has (example for dev job):
```yaml
- name: Create Pull Request to promote to staging
  if: github.ref == 'refs/heads/development'
  run: |
    gh pr create \
      --base staging \
      --head development \
      --title "Promote: Development → Staging" \
      ...
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Same pattern for staging job (head=staging, base=production).

Push this change. Then do a tiny commit/push to `development` (e.g. edit a comment or add a line in README) to trigger a full dev deploy + promotion PR creation. 

**Important for first run after this change:**
- The workflow now auto-creates the labels "promotion" and "automated" (via `gh label create ... || true`) before calling `gh pr create --label ...`. This fixes the "could not add label: 'promotion' not found" error you saw.
- If an old "Promote: Development → Staging" PR already exists from previous attempts, close it first (or merge it), then re-trigger the dev deploy so a fresh one gets created cleanly.
- Watch the Actions run (the graph should now show the full linear chain thanks to `needs:` wiring), then go to the repo's Pull requests tab to see the auto-created "Promote: Development → Staging" PR. Merge it (no code review needed for demo) to fire the staging deploy.

The jobs are now connected in the Actions UI as: build → test → deploy-dev → deploy-staging → production-approval → deploy-prod (using `needs: [prev]` + `if: always() && ref == '...' ` so skipped jobs on a given branch don't break the visual flow).

This completes the 4-domain CI/CD + manual gate story for the presentation.

**Monitoring via CloudWatch/SNS:**
See the new section "9. Verifying Monitoring (CloudWatch + SNS)" I added to this file.

Exact steps:
- Subscribe your email to the SNS topic (development-ha-project-alarms)
- List the RDS alarms (development-rds-*)
- Test: set one alarm (e.g. development-rds-cpu-utilization-high) to ALARM state using aws cloudwatch set-alarm-state — this triggers SNS notification to your email.
- Check email, then reset the alarm to OK.

You can also do/view everything in the AWS Console (CloudWatch Alarms, SNS Topics).

This demonstrates the Monitoring domain end-to-end.

**API test verification into documentation:**
See the new section "10. API Test Verification" I added to this file.

You already successfully ran the test (the PowerShell Invoke-WebRequest version) and it returned real data from your RDS (tasks for demo-user-123, including recent demo data) — perfect.

The section explains:
- The test (the curl/Invoke-WebRequest to /api/tasks that you just ran successfully)
- The correct PowerShell command (the verify script now prints this instead of the old 'head' version that doesn't exist in PS)
- Expected successful output (real JSON array of persisted tasks from the DB)
- How to include it in your docs/presentation: run it after each refresh/deploy (as part of the verify script), screenshot the successful response showing real persisted data, combine with the verify script output (ASG instances, target health) for a complete end-to-end demo of a working refreshed deployment.

The verify script was also updated to print the correct PS-friendly API test command.

You don't need to run terraform apply. The plan showed the infra is already correct. The 2 drifts are pre-existing sensitive ones.

The promotion flow will work on the next dev push (after you push the yaml fix).

All the orphan cleanup is done (only 1 VPC left), single NAT, everything clean.

Good. If the create-pr still has issues after the fix (e.g. branch protection on development), we can change the 'branch' value to a unique temp name like 'promote/dev-to-staging' so it creates a dedicated promotion branch. But this should be the intended behavior.

**Promotion flow (final state):**
See the detailed explanation and the gh pr create implementation in the "Promotion flow fix (FINAL...)" block above. The peter-evans action was fully replaced with `gh pr create` for safety and correctness on long-lived branch promotion. Documentation of the API test + monitoring verification was added (sections 9 + 10 below) as requested.

You don't need to run terraform apply — the plan showed infra is already correct. The 2 drifts are pre-existing sensitive ones.

Push the yaml fix (the gh version), then the next dev deploy + tiny test push will demonstrate the full working promotion. The account is clean (only 1 VPC left). Good.

**Promotion flow fix (pushed to deploy.yml - FINAL):**
Replaced peter-evans/create-pull-request entirely with native `gh pr create --head <source> --base <target>` (see detailed FINAL fix note higher in this file). This avoids the "base and branch must be different" error you saw in the exact log you pasted, and avoids any risk of the action's reset/push logic touching your long-lived development/staging branches.

The gh-based promotion steps are committed. Next push to development will create the PR via gh. Merge of the PR → push to target → triggers next env deploy. Full manual gate story complete.

The API test verification + monitoring confirmation steps are documented in sections 9 and 10 below.

### Cost Reality
Each NAT Gateway costs ~$32–36/month (per AZ) + data processing fees. 5× ha-project NATs = real money even if idle. EIPs attached to deleted NATs that are still allocated also cost ~$3.65/mo each until released.

### Cleanup Strategy (Only After You Have Identified the Live One)
1. Confirm the live VPC (from instances/ALB/RDS) and its NAT.
2. For every other VPC tagged ha-project-vpc:
   - Check it has **zero** running instances, zero ENIs in use, zero ALB/NLB, zero RDS subnet groups, and is not listed in any of the three TF states above.
   - Then (in dependency order): delete NAT Gateway → release its EIP → delete routes/RT associations → delete subnets → delete IGW → delete VPC.
3. Never delete the live one.

**Improved deletion script for orphan VPCs (PowerShell-safe version — fixes the quoting and dependency errors you hit)**

Use the version below for the remaining VPCs. It uses `ConvertFrom-Json` + PowerShell filtering (no fragile JMESPath) and the critical "move subnets to main RT first" step.

```powershell
$VPC = "vpc-084cc8e1ce18c3354"   # change for each

Write-Host "=== Cleaning orphan VPC $VPC ===" -ForegroundColor Cyan

# Safety
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC" --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output table
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC" --query "NetworkInterfaces[*].[NetworkInterfaceId,Status]" --output table

# 1. NATs + EIPs
$NATS = aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query "NatGateways[?State=='available'].NatGatewayId" --output text
foreach ($nat in ($NATS -split '\s+' | Where-Object { $_ })) {
    Write-Host "Deleting NAT $nat" -ForegroundColor Yellow
    $alloc = aws ec2 describe-nat-gateways --nat-gateway-ids $nat --query "NatGateways[0].NatGatewayAddresses[0].AllocationId" --output text
    aws ec2 delete-nat-gateway --nat-gateway-id $nat | Out-Null
    Start-Sleep -Seconds 45
    if ($alloc -and $alloc -ne "None" -and $alloc -ne "") {
        Write-Host "Releasing EIP $alloc"
        aws ec2 release-address --allocation-id $alloc 2>$null
    }
}

# 2. Get route tables as objects (reliable on Windows)
$rtData = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --output json | ConvertFrom-Json

# Find main RT
$mainRtObj = $rtData.RouteTables | Where-Object { $_.Associations | Where-Object { $_.Main -eq $true } } | Select-Object -First 1
$MAIN_RT = $mainRtObj.RouteTableId
Write-Host "Main RT = $MAIN_RT"

# 3. List current associations for visibility
Write-Host "Current subnet associations:"
$rtData.RouteTables | ForEach-Object {
    $rt = $_
    $_.Associations | Where-Object { $_.SubnetId } | ForEach-Object {
        [PSCustomObject]@{ SubnetId = $_.SubnetId; RouteTableId = $rt.RouteTableId; IsMain = $_.Main }
    }
} | Format-Table

# 4. Re-associate ALL subnets to the main RT (this is the key step)
$SUBS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query "Subnets[*].SubnetId" --output text
foreach ($sn in ($SUBS -split '\s+' | Where-Object { $_ })) {
    Write-Host "Moving subnet $sn to main RT..."
    aws ec2 associate-route-table --route-table-id $MAIN_RT --subnet-id $sn 2>$null | Out-Null
}

# 5. Now delete non-main RTs (clear routes first)
$nonMainRts = $rtData.RouteTables | Where-Object { 
    -not ($_.Associations | Where-Object { $_.Main -eq $true })
} | Select-Object -ExpandProperty RouteTableId

foreach ($rt in $nonMainRts) {
    Write-Host "Cleaning non-main RT $rt"
    aws ec2 delete-route --route-table-id $rt --destination-cidr-block 0.0.0.0/0 2>$null
    aws ec2 delete-route-table --route-table-id $rt 2>$null
}

# 6. IGW with safe check
$igwJson = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC" --output json | ConvertFrom-Json
$IGW = $igwJson.InternetGateways[0].InternetGatewayId
if ($IGW -and $IGW -ne "None" -and $IGW -ne "") {
    Write-Host "Detaching and deleting IGW $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC 2>$null
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW 2>$null
} else {
    Write-Host "No IGW (or already gone)"
}

# 7. Delete subnets (re-query)
$SUBS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query "Subnets[*].SubnetId" --output text
foreach ($sn in ($SUBS -split '\s+' | Where-Object { $_ })) {
    Write-Host "Deleting subnet $sn"
    aws ec2 delete-subnet --subnet-id $sn 2>$null
}

# 8. Delete the VPC
Write-Host "Deleting VPC $VPC"
aws ec2 delete-vpc --vpc-id $VPC

Write-Host "=== Finished $VPC ===" -ForegroundColor Green
```

# 2. Find main RT and move every subnet to it (this clears dependencies on other RTs)
$MAIN_RT = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --query "RouteTables[?Associations[?Main==\`true\`]].RouteTableId" --output text
$SUBS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query "Subnets[*].SubnetId" --output text
foreach ($sn in ($SUBS -split '\s+' | Where-Object { $_ })) {
    aws ec2 associate-route-table --route-table-id $MAIN_RT --subnet-id $sn 2>$null | Out-Null
}

# 3. Now delete non-main RTs (after clearing routes)
$NON_MAIN = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --query "RouteTables[?Associations[?Main!= \`true\`]].RouteTableId" --output text
foreach ($rt in ($NON_MAIN -split '\s+' | Where-Object { $_ })) {
    aws ec2 delete-route --route-table-id $rt --destination-cidr-block 0.0.0.0/0 2>$null
    aws ec2 delete-route-table --route-table-id $rt 2>$null
}

# 4. IGW (with proper empty check)
$IGW = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC" --query "InternetGateways[*].InternetGatewayId" --output text
if ($IGW -and $IGW -ne "None" -and $IGW -ne "") {
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC 2>$null
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW 2>$null
}

# 5. Subnets
foreach ($sn in ($SUBS -split '\s+' | Where-Object { $_ })) {
    aws ec2 delete-subnet --subnet-id $sn 2>$null
}

# 6. VPC
aws ec2 delete-vpc --vpc-id $VPC
Write-Host "Done $VPC" -ForegroundColor Green
```

**How to run for the remaining 7**:
- Paste the block.
- Change only the `$VPC = "..."` line.
- Run one VPC at a time.
- If a step fails, re-run the two safety `describe-instances` and `describe-network-interfaces` for that VPC to see what's left.

This version includes the critical "move subnets to main RT first" step that was missing in your first attempt.

# 2. Detach IGW, delete subnets, route tables, then VPC (full sequence in AWS_COMMANDS or console is safer for first time)
```

**Strong recommendation**: Do the discovery first. Paste the output of the live discovery block + the three `terraform state show` results here if you want me to help you mark exactly which  VPCs are safe to nuke.

After cleanup, re-run the basic tag queries — you should see 1 (or at most 3) ha-project-vpc and matching NATs.

This audit + cleanup is now part of the **Operations & Reliability** story for your presentation (you detected excess spend, traced root cause to IaC design, verified no impact on running fleet via successful Instance Refresh, and have a plan to clean it).

*Last updated: June 2026 (post 30e12a52 refresh + 9-VPC audit)*

## 9. Verifying Monitoring (CloudWatch + SNS)

The infrastructure includes CloudWatch alarms for the RDS instance (CPU, connections, free storage) wired to an SNS topic for notifications.

**SNS Topic name:** `development-ha-project-alarms` (per-environment)

**To confirm it works:**

1. Subscribe an email (or SMS) to the SNS topic:
   ```powershell
   aws sns subscribe `
     --topic-arn arn:aws:sns:us-east-1:866934333672:development-ha-project-alarms `
     --protocol email `
     --notification-endpoint your-email@example.com
   ```
   (Check your email and confirm the subscription.)

2. List the alarms:
   ```powershell
   aws cloudwatch describe-alarms --alarm-name-prefix development-rds --output table
   ```

3. Test by manually setting an alarm to ALARM state (this will trigger the SNS notification):
   ```powershell
   aws cloudwatch set-alarm-state `
     --alarm-name development-rds-cpu-utilization-high `
     --state-value ALARM `
     --state-reason "Manual test of monitoring via CloudWatch/SNS"
   ```

4. Check your email for the alarm notification from SNS.

5. (Optional) Reset the alarm:
   ```powershell
   aws cloudwatch set-alarm-state `
     --alarm-name development-rds-cpu-utilization-high `
     --state-value OK `
     --state-reason "Test complete - resetting alarm"
   ```

You can also view alarms and metrics in the AWS Console under CloudWatch > Alarms and SNS > Topics.

This demonstrates the **Monitoring & Observability** domain.

## 10. API Test Verification

The `verify-deployment.ps1` script includes an API test step to confirm the full stack (ALB → EC2 backend → RDS) is working and data is persisting.

**The command (PowerShell version for Windows):**
```powershell
(Invoke-WebRequest -Uri "http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/tasks?userId=demo-user-123" -UseBasicParsing).Content.Substring(0,300)
```

**Expected successful output (example):**
```json
[{"id":10,"user_id":"demo-user-123","task":"gg","description":null,"status":"pending","priority":"Medium","created_at":"2026-06-02T14:39:21.000Z","updated_at":"2026-06-02T14:39:21.000Z"}, ... ]
```

This proves:
- The ALB is routing traffic correctly.
- The backend Node.js app is running and connected to RDS MySQL.
- The database schema and data persistence are working (tasks are being created and returned).

**In documentation / presentation:**
- Run this after each Instance Refresh or deploy to demonstrate end-to-end functionality.
- Include a screenshot of the successful JSON response (showing real persisted tasks).
- Note that this test uses the public ALB DNS and the demo user ID.
- Combine with the verify script output (ASG instances, target health) for a complete demo of a working, refreshed, monitored deployment.

Run the full script regularly:
```powershell
./scripts/verify-deployment.ps1
```

This test was added as part of the Operations & Reliability verification process.
