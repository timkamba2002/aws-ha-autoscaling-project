# Presentation Notes & Talking Points

This document contains suggested talking points and framing for your instructor presentation.

---

## Opening / Project Overview

**Suggested opener:**

> "For this project, I built a 3-tier application on AWS with a full CI/CD promotion pipeline. The goal was to simulate a real enterprise workflow — including manual approval gates — while gaining hands-on experience with Terraform, GitHub Actions, and AWS services."

You can then briefly describe:
- React frontend + Node.js backend + RDS MySQL
- Infrastructure managed with Terraform
- CI/CD pipeline with automatic deployments to Dev & Staging + manual approval before Production

---

## Pipeline Walkthrough + Modern DevSecOps (Strongest Section)

Walk through a real run on `development`:

1. **Build + Test + Security** (single job graph):
   - Build React
   - Trivy SAST (filesystem) + Trivy container image scan + SARIF upload to GitHub Security tab
   - **Checkov** IaC Policy-as-Code on the entire `terraform/` directory
   - SBOM generation (CycloneDX) as artifact
2. **Deploy to Development** (automatic) — Terraform + ECS Fargate Spot backend + ASG refresh on frontend + ALB path routing
3. **DAST (ZAP)** — OWASP ZAP baseline active scan against the live ALB (post-deploy). HTML report as artifact.
4. **Auto-PR to staging** created by the pipeline
5. **Deploy to Staging** (after you manually merge the PR)
6. **Auto-PR to production**
7. **Manual Approval Gate** (GitHub Environment "production")
8. **Deploy to Production** (only after human approval)

**Key messages to emphasize (this is what makes the project portfolio-strong):**

> "This is a realistic enterprise-style promotion pipeline with immutable artifacts (image digest promotion), layered security gates, and explicit human approval before Production — exactly the kind of process you see at Amazon, Google, or finance companies."

> "The DevSecOps additions (Trivy + Checkov + SBOM + ZAP DAST) demonstrate shift-left security + supply chain practices without over-engineering. Checkov and ZAP findings are shown but the pipeline stays green for the demo (soft_fail + fail_action: false). In real use these would be hard gates."

> "Fargate Spot for the backend + Instance Refresh for the frontend lets me show both modern cost-optimized containers and classic reliable EC2 operations in the same stack."

---

## Current State & Honest Assessment (Very Important)

**Recommended framing (current June 2026 state):**

> "The project now demonstrates a modern hybrid architecture: React static frontend on EC2 ASG (for the Instance Refresh reliability demo) + Node.js backend on ECS Fargate Spot (cost-optimized, no EC2 management) behind the same ALB using path-based routing. Full end-to-end persistence to RDS works in dev. The CI/CD pipeline includes real DevSecOps (Trivy, Checkov, SBOM, OWASP ZAP DAST) and a proper promotion flow with manual gates."

**Talk about the real journey (this is gold for an instructor):**

- Long backend + RDS battle (wrong driver, port in SSM, IAM, user-data fragility on Amazon Linux 2)
- Multiple full rewrites of user-data until it was resilient
- IAM permission hell on both the GitHub OIDC role and EC2 roles (repeated 403s on PutRolePolicy, ListRolePolicies, TagRole, etc.)
- VPC/NAT sprawl (9 VPCs + 5 NATs) caused by per-env state + non-namespaced modules — diagnosed live, fleet unaffected, cleanup commands delivered
- Complete migration of backend to ECS Fargate Spot + ALB path routing while keeping the EC2 frontend for operations demos
- Adding a full industry-grade DevSecOps layer (Trivy kept + Checkov + SBOM + ZAP DAST) on top of the existing pipeline

**Key message:**

> "These are the messy, real-world problems you actually encounter when building production-style systems. Being able to diagnose, document, and systematically fix them (see DEV_HISTORY.md) is far more valuable than a perfect first-try tutorial project."

**Talk about the blockers you actually overcame:**

- Amazon Linux 2 package realities (nginx and modern Node not available in base repos)
- SSM Parameter Store + IAM permission propagation delays
- Making Auto Scaling Group Instance Refreshes reliable (including the 30e12a52 successful refresh that produced clean i-02689... / i-06565... instances)
- Diagnosing and documenting real infrastructure sprawl (9 ha-project-vpc + 5 ha-project-nat-gateway) caused by per-env state + non-namespaced networking module during repair; verified no impact on live fleet; added production-grade discovery + cleanup tooling in AWS_COMMANDS.md
- Proper separation of concerns between what belongs in Terraform vs what must be handled at runtime in user-data

Frame it as:

> "These are the kinds of messy, real-world problems you run into when moving beyond tutorials. Being able to diagnose them, document them, and systematically fix them is a much more valuable skill than just clicking 'deploy' in a console."

---

## Why the Manual Approval Gate Matters (Strong Talking Point)

This is excellent material for the presentation.

**Suggested explanation:**

> "In a real company, you wouldn't just push code straight to Production. The manual approval gate forces a human to evaluate whether the release is actually ready. In this case, I would have rejected the promotion to Production because the backend wasn't working properly. The gate did its job."

You can tie this directly to enterprise practices.

---

## Future Plans / What Was Recently Delivered (Show Forward Thinking + Completion)

**What is now complete (the big recent additions):**

- Full ECS Fargate Spot migration for backend (with ALB `/api/*` routing) while preserving EC2 + Instance Refresh for frontend (best of both worlds for a portfolio)
- Complete DevSecOps layer: Trivy (SAST + image, per-stage re-scans + SARIF), **Checkov** Policy-as-Code, SBOM generation, **OWASP ZAP** DAST after dev deploy
- Hybrid observability (CloudWatch + Prometheus + Grafana) with real business SLIs (task create/fetch rates) + golden signals

**Honest next steps you can mention:**

- VPC/NAT orphan cleanup (already audited — commands ready)
- More integration tests + make the "verify-deployment" script even stronger
- Optional: move more of the security jobs to reusable composite actions
- Longer term: Secrets Manager, WAF, proper HTTPS listener + ACM, etc.

This shows you delivered on the instructor's 4-domain request (CI/CD+IaC, Security, Monitoring, Operations/Reliability) plus the requested SAST/DAST work, while keeping the project realistic for a student.

---

## How to Handle Questions About the Backend Not Working

Possible tough question: *"Why isn't the full application working?"*

**Good answers:**

- "Due to restricted IAM permissions on the deployment role, I was unable to fully troubleshoot and resolve the backend-to-RDS connectivity issues within the project timeline."
- "I chose to focus on delivering a stable, professional CI/CD pipeline and promotion process rather than forcing a half-working backend into Production."
- "This situation actually highlighted the value of the approval gate — it prevented an incomplete feature from being promoted."

---

## Closing Statement (Strong Ending)

**Suggested closing:**

> "This project taught me that shipping reliable software isn't just about writing code — it's about having the right processes, visibility, and gates in place. Even with external constraints, I was able to build and demonstrate a complete promotion pipeline with proper controls. My next steps are to resolve the backend persistence issues and then modernize the deployment using containers and ECS Fargate."

---

## Quick Reference – Key Messages (Updated for Current State)

- **4 domains covered end-to-end**: CI/CD + mature IaC (Terraform per-env state + promotion), Security (full DevSecOps with Trivy/Checkov/SBOM/ZAP + light finance simulation via gates + artifacts), Monitoring (CW + Prom/Grafana hybrid with business metrics), Operations/Reliability (Fargate Spot + Instance Refresh MinHealthy 100% + healthchecks + real debugging story).
- **Promotion + gates are real**: Push to development triggers full security scan + deploy + DAST + auto-PR. Manual merge + Prod environment approval required.
- **Honesty + journey > perfection**: Talk about the long backend/RDS/IAM/debugging battle and the VPC sprawl diagnosis — it makes the wins (Fargate migration, DevSecOps layer, hybrid monitoring) much more credible.
- **Security layer is the new highlight**: You kept Trivy (as requested), added Checkov + SBOM + ZAP DAST exactly per your 6-point confirmation with the instructor. The pipeline shows the findings but stays green for the demo (realistic).
- **Modern + classic in one project**: Fargate Spot (cost, no management) + classic EC2 Instance Refresh (operations demo) behind one ALB.

## Demoing Monitoring (CloudWatch + SNS) & API Verification (for instructor review)

**Monitoring confirmation (shows the Monitoring domain):**
- In AWS Console or CLI: subscribe your email to the per-env SNS topic e.g. `development-ha-project-alarms` (arn:aws:sns:us-east-1:866934333672:development-ha-project-alarms)
- List alarms: `aws cloudwatch describe-alarms --alarm-name-prefix development-rds --output table`
- Trigger test notification: `aws cloudwatch set-alarm-state --alarm-name development-rds-cpu-utilization-high --state-value ALARM --state-reason "Manual test of monitoring pipeline"`
- Watch for email from SNS (AWS Notifications). Then reset to OK.
- Also visible in CloudWatch console > Alarms (RDS cpu-high, free-storage-low, connections-high wired to the SNS).

**API test verification (proves full stack + Operations/Reliability):**
- After any deploy or Instance Refresh, run `./scripts/verify-deployment.ps1` (or the one-liner).
- The key command (PS): `(Invoke-WebRequest -Uri "http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/tasks?userId=demo-user-123" -UseBasicParsing).Content.Substring(0,300)`
- Successful output contains real JSON from RDS, e.g. `[{"id":10,"user_id":"demo-user-123","task":"gg",... "created_at":...}, ...]`
- This proves: ALB healthy routing → backend (Node on refreshed instances, .env from SSM) → RDS MySQL persistence (tasks table with inserts).
- Screenshot the JSON + the verify script's ASG table + target health table for your demo/portfolio.
- Full details + expected output in [AWS_COMMANDS.md §10](AWS_COMMANDS.md#10-api-test-verification).

Add these live runs + screenshots to your presentation deck / instructor handoff. They directly map to the 4-domain model (CI/CD+IaC, Security/Trivy already in Test job, Monitoring here, Operations via refresh/verify/cleanup story).

Good luck with your presentation! You have a mature story to tell.