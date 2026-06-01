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

## Pipeline Walkthrough (Strong Section)

Walk through the actual run:

1. **Build** – Compiles the React app
2. **Test** – Runs tests and quality checks
3. **Deploy to Development** – Automatic on push to `development` branch
4. **Deploy to Staging** – Continues automatically
5. **Manual Approval Gate** – Pipeline stops here
6. **Deploy to Production** – Only after explicit approval

**Key message to emphasize:**

> "One push to the development branch triggers everything up to Staging. The pipeline then correctly stops at the Production approval gate. This is intentional — we should not promote incomplete features to Production."

---

## Current State & Honest Assessment (Very Important)

This is where you can stand out.

**Recommended framing:**

> "Right now, the frontend is successfully deployed and working in the Staging environment. However, the backend is not reliably persisting data to the database."

Then explain **why** you're not promoting to Production:

> "Because the core functionality (saving tasks) isn't working end-to-end, I made the decision to hold at Staging. This is exactly what the manual approval gate is designed for — to prevent features that aren't ready from reaching real users."

**Talk about the blockers clearly:**

- Limited IAM permissions on the GitHub Actions role (due to company security policies)
- Terraform drift on pre-existing resources
- Difficulty managing ASG refreshes cleanly

Frame it as:
> "These are real-world constraints that many engineers face. The important thing is that I was still able to deliver a working frontend and a professional-grade promotion pipeline despite these limitations."

---

## Why the Manual Approval Gate Matters (Strong Talking Point)

This is excellent material for the presentation.

**Suggested explanation:**

> "In a real company, you wouldn't just push code straight to Production. The manual approval gate forces a human to evaluate whether the release is actually ready. In this case, I would have rejected the promotion to Production because the backend wasn't working properly. The gate did its job."

You can tie this directly to enterprise practices.

---

## Future Plans (Show Forward Thinking)

Briefly walk through the roadmap:

- First priority: Get the backend fully working and add integration tests
- Then: Containerize the backend with Docker and migrate to ECS Fargate
- Improve secrets management and observability
- Add Policy as Code and container scanning

This shows you have a plan and aren't just stopping here.

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

## Quick Reference – Key Messages

- **Pipeline is solid** → Emphasize the structure and approval gate.
- **Honesty is strength** → Clearly state what works and what doesn't.
- **Approval gate is working as intended** → You stopped promotion because the app wasn't ready.
- **You have a plan** → Show the Future Plans section.
- **Real-world constraints** → IAM limitations are common in enterprise environments.

Good luck with your presentation! You have a mature story to tell.