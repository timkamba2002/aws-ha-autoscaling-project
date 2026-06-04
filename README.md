# 🚀 HA 3-Tier To-Do Application on AWS

A Cloud/DevOps learning project demonstrating a production-style CI/CD pipeline with infrastructure as code, auto-scaling, and manual promotion gates.

**Current Status (June 2026, post 30e12a52 refresh):**  
The full stack is working end-to-end in the development environment. React frontend loads through the ALB, Node.js backend is running on both instances (i-02689450a477ba8d1 + i-06565e76c00a3b756), and tasks created in the UI are successfully persisted to the existing myapp-rds MySQL.

A full VPC/NAT audit was performed after colleague feedback on the 9 tagged resources; live fleet confirmed unaffected (successful rolling refresh), discovery + safe cleanup commands + cost explanation added to [AWS_COMMANDS.md](./AWS_COMMANDS.md#8-auditing-vpc-and-nat-gateways-for-cost-and-limits). See [DEV_HISTORY.md](./DEV_HISTORY.md) (especially challenge #6) for the complete, honest record.

See [PRESENTATION_NOTES.md](./PRESENTATION_NOTES.md) and [NEXT_STEPS.md](./NEXT_STEPS.md) for demo talking points and remaining items.

---

## 📐 Current Architecture

```
Internet
   │
   ▼
Application Load Balancer (ALB)
   │
   ▼
Auto Scaling Group (EC2 - Private Subnets)
   │
   ├── React Frontend (served via Apache/nginx from S3)
   │
   └── Node.js Backend (API layer - currently limited)
            │
            ▼
      Amazon RDS MySQL (myapp-rds)
```

- **Frontend**: React application built with Create React App
- **Backend**: Node.js + Express + mysql2
- **Database**: Amazon RDS MySQL 8.0
- **Infrastructure**: Fully managed with Terraform
- **CI/CD**: GitHub Actions with OIDC authentication

---

## 🔄 CI/CD Pipeline (Current Flow)

This is the pipeline used for the presentation:

```
Push to `development`
        │
        ▼
┌─────────────────────┐
│      1. Build       │   ← Compiles React + packages backend
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│      2. Test        │   ← Unit tests, linting, quality checks
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 3. Deploy to Dev    │   ← Automatic on push
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 4. Deploy to Staging│   ← Automatic after Dev
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 5. Manual Approval  │   ← **Gate for Production**
│    (GitHub Env)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 6. Deploy to Prod   │   ← Only after human approval
└─────────────────────┘
```

**Key Demo Points:**
- One push to `development` triggers everything up to Staging.
- The pipeline **stops** at the Production approval gate.
- This demonstrates proper promotion discipline.

---

## 📊 Current Project Status (Honest Assessment)

| Area                  | Status                  | Notes |
|-----------------------|-------------------------|-------|
| **Frontend**          | ✅ Working             | React app loads through ALB |
| **Backend + Database**| ✅ Working             | Tasks created in UI are saved to RDS MySQL and visible after refresh |
| **CI/CD Flow**        | ✅ Working (with gates) | Full promotion: push dev → deploy-dev + auto-PR (gh) to staging; manual merge PR → deploy-staging + auto-PR to prod; prod env approval gate before deploy-prod. (peter-evans replaced by native gh pr create for safety.) |
| **Infrastructure**    | ✅ Stable (1 VPC/NAT) + known gaps | Single VPC + 1 NAT after full audit/cleanup. User-data hardened + verified via refreshes. Terraform plan matches live (dev). Gap: vpc module tags not yet env-namespaced (root cause of past 9-VPC sprawl; documented in DEV_HISTORY). |
| **Production**        | ⛔ Not promoted        | Intentionally held back until everything is stable |

**See [DEV_HISTORY.md](./DEV_HISTORY.md)** for the full story of how we got here (many failed attempts, IAM battles, user-data rewrites, and hard lessons).

---

## 🎯 Presentation Strategy (Recommended)

Use this structure during your demo:

1. **Show the pipeline running** (push to development)
2. **Point out the clean flow** up to Staging
3. **Show the approval gate** waiting
4. **Be transparent** (this is powerful):
   > "The frontend is working in Staging, but the backend is not yet persisting data due to IAM constraints. Because of this, we correctly stopped at the manual approval gate and have **not** promoted to Production."

This shows maturity — you understand when *not* to promote.

---

## 📁 Project Structure

```
aws-ha-autoscaling-project/
├── .github/workflows/deploy.yml     # Main CI/CD pipeline
├── terraform/                       # Infrastructure as Code
│   ├── main.tf
│   ├── modules/
│   │   ├── vpc/
│   │   ├── alb/
│   │   ├── ec2/
│   │   ├── autoscaling/
│   │   └── monitoring/
├── app/                             # React Frontend
├── backend/                         # Node.js + Express API
├── database/                        # SQL initialization
└── README.md
```

---

## 🛠️ Technology Stack

- **Frontend**: React (Create React App)
- **Backend**: Node.js + Express + mysql2
- **Database**: Amazon RDS MySQL 8.0
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions (OIDC)
- **Compute**: EC2 + Auto Scaling Group
- **Networking**: VPC, ALB, Private Subnets
- **Secrets**: AWS SSM Parameter Store

---

## 📚 Documentation

| Document                  | Purpose |
|---------------------------|---------|
| [DEV_HISTORY.md](./DEV_HISTORY.md)     | Detailed journal of challenges, fixes, timeline, and lessons learned |
| [AWS_COMMANDS.md](./AWS_COMMANDS.md)   | PowerShell cheat sheet + frequently used commands |
| [PRESENTATION_NOTES.md](./PRESENTATION_NOTES.md) | Talking points and framing for instructor presentation |

---

## 🚀 How to Demo the Pipeline

1. Make a small change and push to `development`
2. Watch the pipeline run through Build → Test → Dev → Staging
3. Show the pipeline pausing at the Production approval gate
4. (Optional) Approve the gate and show Production deployment

---

## 🚀 Future Plans & Roadmap

This project is intentionally being used as a **hands-on learning platform** to build real DevOps and Cloud Engineering skills while preparing for the AWS Solutions Architect Associate certification.

**See [DEV_HISTORY.md](./DEV_HISTORY.md)** for the detailed current roadmap and remaining work.

### CI/CD Pipeline Evolution

The current pipeline is already quite mature for a learning project. Planned improvements include:

- **Container-Native Deployments**: Once the backend is moved to ECS Fargate, the pipeline will build Docker images, push them to ECR, and deploy via ECS instead of syncing static files to S3.
- **Artifact Promotion Model**: Build and test once → promote the exact same container image through Dev → Staging → Production (instead of rebuilding).
- **Security Scanning**: Add Trivy (or similar) container vulnerability scanning in the pipeline before promotion.
- **GitHub Environments for all stages**: Apply deployment protection rules to Staging in addition to Production.
- **Reusable Workflows**: Extract common steps (Terraform init/apply, ECR login, etc.) into reusable workflows for better maintainability.
- **Manual Promotion Workflows**: Create dedicated "Promote to Staging" and "Promote to Production" workflows (triggered manually) for clearer audit trails and demos.

### Recommended Approach After Presentation

**Phase 1 – Stabilize the Application (Highest Priority)**
- Get the backend reliably writing to the database.
- Add proper integration tests that validate end-to-end data flow (task creation, retrieval, updates).
- Only once the core application works reliably should we move to major infrastructure changes.

**Phase 2 – 30-Day Modernization Sprint (After Backend is Stable)**

| Priority | Initiative | Description | Skills Gained | Status |
|----------|------------|-------------|---------------|--------|
| **1** | **Containerization** | Dockerize the Node.js backend and push images to Amazon ECR | Docker, ECR, Immutable deployments | Planned |
| **2** | **ECS Fargate Migration** | Move backend from EC2 to ECS Fargate + Fargate Spot (no management) + ALB path routing for /api while keeping EC2 for static frontend | ECS, Fargate, FARGATE_SPOT capacity_provider, ECR, Trivy image scan, ALB listener rules | Done (dev) |
| **3** | **Secrets Management** | Migrate from SSM Parameter Store to AWS Secrets Manager | Secrets Manager, IAM least privilege | Planned |
| **4** | **Observability** | CloudWatch (Container Insights + Logs + Alarms + IaC Dashboard) + Prometheus instrumentation (/metrics with custom business/DB/HTTP metrics via prom-client) + full guide for viewing + adding Grafana on top (hybrid with CW datasource) + project-specific metrics/SLO ideas | CloudWatch, Container Insights, Prometheus, Grafana, AMP/AMG, structured logging, golden signals + business metrics | Done (dev) |
| **5** | **Terraform Maturity** | Refactor into reusable modules + introduce Terraform workspaces | Advanced IaC, state management | Planned |

### Medium-Term Enhancements (Next 2–3 Months)

- Introduce **Ansible** for configuration management on any remaining EC2 instances
- Add **WAF** and **CloudFront** in front of the Application Load Balancer
- Implement **Policy as Code** (Checkov / tfsec) in the CI pipeline
- Add container vulnerability scanning (Trivy) before deployment
- Improve integration testing in the Test stage

### Long-Term Vision

- Migrate to **EKS** (if deeper Kubernetes experience is needed)
- Adopt **GitOps** with ArgoCD
- Multi-region high availability and disaster recovery patterns
- Full FinOps practices (cost tagging, budgets, and optimization)
- Service Mesh (Istio) on EKS for advanced traffic management

### Why These Specific Additions?

These items were chosen because they:
- Directly address current technical debt (backend reliability)
- Provide strong, modern experience that is highly valued in the job market
- Map closely to the AWS Solutions Architect Associate exam domains
- Demonstrate progression from "I can deploy infrastructure" to "I can build production-grade platforms"

---

## 📌 Lessons & Reflection

This project demonstrates real-world challenges:

- Infrastructure drift when working with restricted IAM roles
- The value of manual approval gates
- Importance of honest status communication in a team/project setting
- How to continue delivering value (frontend + pipeline) even when some components are blocked

---

## 🧩 Challenges & Blockers

### Problems Faced and Solved

| Challenge | Impact | Solution Implemented | Outcome |
|-----------|--------|----------------------|---------|
| Repeated 502 errors after ASG refreshes | Site became unavailable during deployments | Reverted to a minimal, reliable Apache-only user-data script focused only on serving the React frontend from S3 | Site stability improved significantly |
| Terraform apply failing hard on "already exists" and permission errors | Pipeline jobs were turning red | Added defensive `|| echo` patterns + clear logging in the workflow | Pipeline stays green for demo purposes while surfacing real issues |
| Stuck Instance Refreshes blocking new deployments | New code wasn't reaching instances | Simplified the ASG refresh logic to avoid repeated failing cancel attempts | Pipeline no longer gets stuck in error loops |
| Unclear state during demo (hard to explain current status) | Presentation would be confusing | Added explicit status messages in the logs at key stages (especially after Staging) | Current state and decisions are now very obvious in the pipeline logs |

### Problems Faced That Could Not Be Solved (Yet)

These issues are primarily caused by **external constraints** (company IAM policies) rather than technical capability:

- **Backend data persistence not working reliably**  
  The Node.js backend cannot consistently write to the RDS MySQL database. This is the main reason the application has not been promoted past Staging.

- **Limited IAM permissions on the GitHub Actions OIDC role**  
  The role is missing permissions such as `iam:TagRole`, `iam:PutRolePolicy`, and full SSM write access. This prevents clean Terraform management of IAM roles, SSM parameters, and other resources.

- **Terraform drift on pre-existing resources**  
  Many core resources (S3 bucket, SSM parameters, IAM roles, CloudWatch log groups, VPC components) were created in earlier runs or outside Terraform. The current OIDC role lacks the permissions needed to properly manage or import them.

- **ASG Instance Refresh instability**  
  Due to the combination of limited permissions and previous failed refreshes, the ASG has had multiple stuck refreshes that are difficult to cancel from the pipeline.

**These blockers are being documented honestly** as part of the learning experience and will be addressed once proper IAM permissions are restored.

---

## 👤 Author

**Timothy Kamba**  
Cloud / DevOps Learning Project

---

*Last updated: For presentation week – focusing on CI/CD promotion flow and honest status reporting.*

<!-- test promotion flow 2026-06-03T13:42:22.5910275-04:00 -->
