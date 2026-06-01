# 🚀 HA 3-Tier To-Do Application on AWS

A Cloud/DevOps learning project demonstrating a production-style CI/CD pipeline with infrastructure as code, auto-scaling, and manual promotion gates.

**Current Status:** Frontend is deployed and working in Staging. Backend integration is incomplete due to external IAM restrictions (see below).

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

| Area              | Status                          | Notes |
|-------------------|----------------------------------|-------|
| **Frontend**      | ✅ Working in Staging           | React app loads correctly |
| **Backend**       | ⚠️ Partially working            | API calls fail to persist data |
| **CI/CD Flow**    | ✅ Fully functional             | Clean Dev → Staging → Approval Gate → Prod |
| **Infrastructure**| ⚠️ Some drift & limitations     | Limited by IAM permissions |
| **Production**    | ⛔ Not promoted                 | Correctly held at approval gate |

### Why the Backend Isn't Fully Working

The backend cannot reliably persist data to RDS due to ongoing IAM permission restrictions on the GitHub Actions OIDC role and previous Terraform state drift. These are external blockers outside the scope of the current sprint.

**This is a deliberate teaching moment** for the presentation.

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

## 🚀 How to Demo the Pipeline

1. Make a small change and push to `development`
2. Watch the pipeline run through Build → Test → Dev → Staging
3. Show the pipeline pausing at the Production approval gate
4. (Optional) Approve the gate and show Production deployment

---

## 🚀 Future Plans & Roadmap

This project is intentionally being used as a **hands-on learning platform** to build real DevOps and Cloud Engineering skills while preparing for the AWS Solutions Architect Associate certification.

### CI/CD Pipeline Evolution

The current pipeline is already quite mature for a learning project. Planned improvements include:

- **Container-Native Deployments**: Once the backend is moved to ECS Fargate, the pipeline will build Docker images, push them to ECR, and deploy via ECS instead of syncing static files to S3.
- **Artifact Promotion Model**: Build and test once → promote the exact same container image through Dev → Staging → Production (instead of rebuilding).
- **Security Scanning**: Add Trivy (or similar) container vulnerability scanning in the pipeline before promotion.
- **GitHub Environments for all stages**: Apply deployment protection rules to Staging in addition to Production.
- **Reusable Workflows**: Extract common steps (Terraform init/apply, ECR login, etc.) into reusable workflows for better maintainability.
- **Manual Promotion Workflows**: Create dedicated "Promote to Staging" and "Promote to Production" workflows (triggered manually) for clearer audit trails and demos.

### 30-Day Focus (June 2026)

| Priority | Initiative | Description | Skills Gained | Status |
|----------|------------|-------------|---------------|--------|
| **1** | **Containerization** | Dockerize the Node.js backend and push images to Amazon ECR | Docker, ECR, Immutable deployments | Planned |
| **2** | **ECS Fargate Migration** | Move backend from EC2 to ECS Fargate (serverless containers) | ECS, Fargate, Task Definitions, Service discovery | Planned |
| **3** | **Secrets Management** | Migrate from SSM Parameter Store to AWS Secrets Manager | Secrets Manager, IAM least privilege | Planned |
| **4** | **Observability** | Add CloudWatch Alarms, dashboards, and SNS notifications for failures | CloudWatch, Monitoring, Alerting | Planned |
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
