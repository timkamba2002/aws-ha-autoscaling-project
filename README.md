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

## 📌 Lessons & Reflection

This project demonstrates real-world challenges:

- Infrastructure drift when working with restricted IAM roles
- The value of manual approval gates
- Importance of honest status communication in a team/project setting
- How to continue delivering value (frontend + pipeline) even when some components are blocked

---

## 👤 Author

**Timothy Kamba**  
Cloud / DevOps Learning Project

---

*Last updated: For presentation week – focusing on CI/CD promotion flow and honest status reporting.*
