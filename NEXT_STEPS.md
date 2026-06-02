# Next Steps – Project Options

After the major documentation update (June 2026), here are the most logical directions you can take the project.

---

## 1. Verify & Stabilize the Current Foundation (✅ Largely Complete)

**Goal**: Make sure the improved user-data and SSM fixes actually work reliably on fresh instances.

**Status (June 2026)**:
- Fresh Instance Refresh `30e12a52-85f8-422f-86b3-c059336f66e3` completed **Successful 100%**.
- New instances (`i-02689450a477ba8d1`, `i-06565e76c00a3b756`) came up clean with the hardened user-data (full bootstrap + backend + nginx proxy + DB connectivity).
- Verified via `./scripts/verify-deployment.ps1` + target group health + live site.

**Remaining in this area**:
- Optional: one more manual SSM session on a post-refresh instance to `cat /var/log/user-data.log` and `journalctl -u ha-backend` for the presentation screenshots.

---

## 2. Implement Proper Branch Promotion Flow with Auto-PRs + Manual Approvals

This is the flow you described wanting:

- Push to `development` → automatically creates PR to `staging`
- Merge to `staging` (requires manual approval) → deploys to Staging
- After Staging succeeds → automatically creates PR to `production`
- Merge to `production` (requires manual approval) → deploys to Production

**Work involved**:
- Refactor GitHub Actions workflows
- Use `peter-evans/create-pull-request` action
- Set up GitHub Environments (`staging` and `production`) with required reviewers
- Update branch protection rules

**Value**: This is one of the strongest "real enterprise process" demonstrations you can show.

---

## 3. Improve Terraform Environment Isolation (Root Cause of VPC/NAT Sprawl)

**Current status**: The June 2026 audit revealed 9 ha-project-vpc + 5 ha-project-nat-gateway because the `vpc` module (and its call in `main.tf`) does not receive or use `var.environment` for names/tags, while the project correctly uses per-env remote state keys. Repair-phase applies created independent duplicate networks.

**Immediate action**:
- Complete the live discovery + orphan cleanup using the enhanced commands in [AWS_COMMANDS.md §8](AWS_COMMANDS.md#8-auditing-vpc-and-nat-gateways-for-cost-and-limits).
- This removes the billing risk and limit pressure.

**Longer-term fix options** (after cleanup, before or after Monday):
- Make VPC/subnet/NAT/RT names and tags include the environment (e.g. `ha-project-${var.environment}-vpc`). This requires a small migration (new resources or `terraform state rm` + careful apply, or a dedicated "network" state that other envs read via `terraform_remote_state`).
- Or keep a single shared "base" VPC and have dev/staging/prod only manage the app-layer resources (ALB/ASG/RDS/etc.) inside it via data sources.
- Workspaces are an alternative but less explicit than separate state files + namespacing for a portfolio project.

This is now tracked as part of the **Operations & Reliability** + IaC maturity story.

---

## 4. Move into the Next Instructor Domain (Security / Monitoring)

Once the foundation is stable, you can start delivering on the other domains from the 4-domain model:

- **Security**: Add Trivy scanning in the pipeline, tighten IAM policies, consider Secrets Manager
- **Monitoring & Observability**: CloudWatch Alarms + SNS email/SMS notifications for backend failures or high error rates
- **Operations & Reliability**: Improve rollback strategy, add better health checks, explore Ansible for configuration drift

---

## 5. Containerization & ECS Fargate Migration (Bigger Technical Leap)

This is a common next step for this type of project:

- Dockerize the Node.js backend
- Push images to Amazon ECR
- Migrate from EC2 + user-data to ECS Fargate
- Update the pipeline to build, scan, and deploy containers

**Pros**: Much more modern and impressive on a resume
**Cons**: Significant lift — best done after the current EC2 setup is rock solid

---

## Suggested Order (My Recommendation — Updated June 2026)

1. ✅ **Verify the user-data fix is solid** on new instances (done via 30e12a52 refresh + verify script)
2. **Run the VPC/NAT live discovery + cleanup of orphans** (cost control + limits + strong Ops story — commands ready in AWS_COMMANDS.md)
3. **Implement / test the branch promotion flow with auto-PRs** (tiny commit to development + observe the create-PR step; then manual merge to staging)
4. **Improve Terraform environment separation** for networking (after cleanup; prevents recurrence)
5. Choose between:
   - Adding Security + Monitoring features (Trivy is already in the Test job; SNS alarms are wired), **or**
   - Starting the containerization journey (bigger lift)

---

## Quick Decision Framework (Updated)

| If you want to...                    | Prioritize |
|--------------------------------------|------------|
| Look most professional for the presentation (IaC maturity + real Ops story) | VPC/NAT audit+cleanup (#2 above) + test promotion flow + existing 4-domain notes |
| Reduce future deployment pain        | #4 (Terraform isolation refactor after cleanup) |
| Show you can diagnose & control cost/sprawl | The June 2026 VPC/NAT audit + cleanup commands |
| Show breadth across the 4 domains    | Trivy (already present) + CloudWatch/SNS alarms (wired in main.tf) + this cleanup |
| Demonstrate modern cloud skills      | #5 (ECS Fargate) — best as a "future work" slide |

---

*Feel free to mix and match. The most important thing is being able to clearly explain *why* you chose the next direction.*

**Current session note**: VPC/NAT audit + docs + discovery tooling delivered. Next concrete action for you: run the "Live Resource Discovery" block from AWS_COMMANDS.md (using your two current instance IDs), paste results if you want help labeling the safe-to-delete VPCs. After that, a tiny push to development to exercise the promotion PR logic is the best end-to-end validation before Monday.

