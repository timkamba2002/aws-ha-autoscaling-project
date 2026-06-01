# Next Steps – Project Options

After the major documentation update (June 2026), here are the most logical directions you can take the project.

---

## 1. Verify & Stabilize the Current Foundation (Recommended First Step)

**Goal**: Make sure the improved user-data and SSM fixes actually work reliably on fresh instances.

**Actions**:
- Trigger a fresh Instance Refresh on the dev ASG
- Connect to one of the new instances
- Verify `/var/log/user-data.log` shows clean success (Node 16, nginx, region, SSM credentials, backend running)
- Confirm the API works without manual intervention

**Why this matters**:
Everything else (pipeline improvements, containerization, monitoring) becomes much more valuable once the base application reliably comes up on its own.

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

## 3. Improve Terraform Environment Isolation

Current pain point: Running the pipeline against staging or production creates many "already exists" errors because Terraform is not properly separated by environment.

**Options**:
- Use Terraform workspaces (`development`, `staging`, `production`)
- Move to separate state files per environment
- Introduce environment-specific naming prefixes in resources

This will make the pipeline much cleaner when promoting between environments.

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

## Suggested Order (My Recommendation)

1. **Verify the user-data fix is solid** on new instances (quick win + confidence)
2. **Implement the branch promotion flow with auto-PRs** (biggest process improvement)
3. **Improve Terraform environment separation** (reduces pipeline pain)
4. Choose between:
   - Adding Security + Monitoring features, **or**
   - Starting the containerization journey

---

## Quick Decision Framework

| If you want to...                    | Prioritize |
|--------------------------------------|------------|
| Look most professional for the presentation | #1 (Verify) + #2 (Promotion Flow) |
| Reduce future deployment pain        | #3 (Terraform isolation) |
| Show breadth across the 4 domains    | #4 (Security/Monitoring) |
| Demonstrate modern cloud skills      | #5 (ECS Fargate) |

---

*Feel free to mix and match. The most important thing is being able to clearly explain *why* you chose the next direction.*
