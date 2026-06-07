# ECS + ECR + Container Security + Monitoring Guide

## 1. Less Noisy Production Refresh (Part 3)
The "Trigger ASG Refresh for Production" step now intelligently checks if a refresh is already in progress and prints only **one clean line** ("Skipping...") instead of always dumping the warning + error. This makes the production deploy logs much less noisy when refreshes overlap (very common during manual testing + pipeline).

## 2. ECS & ECR Basics (for someone new)

**ECR (Elastic Container Registry)**
- AWS's private Docker image registry (think Docker Hub but inside your AWS account).
- Supports automatic image scanning on push (we enable `scan_on_push = true`).
- You push images with tags like `sha-<commit>` or `v1.2.3`. Best practice is to use the image **digest** (`@sha256:...`) for deployments so you know exactly what is running.
- We created a module `terraform/modules/ecr` that creates the `ha-backend` repository with scanning and a lifecycle policy (keeps last 30 images to control cost).

**ECS (Elastic Container Service) with Fargate**
- Container orchestrator from AWS.
- **Fargate** = serverless. You define CPU/memory for your task. AWS runs the containers for you. No EC2 instances to manage, patch, or scale. This is the recommended path when you're new and want to move away from the current EC2 + user-data + ASG model.
- Key concepts you need:
  - Cluster (we created one with Container Insights enabled).
  - Task Definition (the "blueprint" — which image, ports, env vars, logging, CPU, memory, IAM role).
  - Service (keeps N tasks running, handles rolling updates, integrates with ALB).
  - Task (one running copy of your container).
- We added a starter `aws_ecs_task_definition` and `aws_ecs_service` in `main.tf` (Fargate, awsvpc networking, logging to CloudWatch).
- Full ALB integration (target group of type `ip`, listener rules for `/api/*` etc.) is left as the obvious next step once you are comfortable — the target group resource is already stubbed.

Migration tip: You can run the old EC2/ASG and the new ECS service side-by-side behind the same ALB during transition. Update listener rules gradually.

## 3. What was added for containers + security scanning

- `backend/Dockerfile`: proper multi-stage, non-root, healthcheck.
- Pipeline now has a `build-containers` job that:
  - Builds the backend image.
  - Runs **Trivy image scan** (table output + SARIF).
  - Pushes to ECR with immutable sha tag.
  - Uploads the exact image URI as an artifact (so staging/prod consume the *exact same* promoted image).
- Every deploy job (dev, staging, prod) now has:
  - A clear `### Vulnerabilities for <stage> stage (re-scanned)` section that runs Trivy on the promoted image and prints a table.
  - A dedicated step summary block (`## 🔒 + 📦 Security + Container Deploy ...`).
- SARIF is uploaded from the central build-containers job → you get a historical view in the GitHub Security tab (filter by workflow run / stage).
- This gives you the "specific section in the github actions pipeline to showcase my vulnerabilities for each stage and container images" you asked for.

Trivy is already used for filesystem scanning in the test job. We now also do it on the container image.

## 4. Step-by-Step: Running on Fargate Spot (no EC2 management, as you requested)

You said: "i'll run fargate spot because I don't want to manage it".

**Why Fargate Spot is perfect here**
- You define CPU (256) + memory (512) in the task definition.
- AWS schedules the containers on spare capacity in their Fargate fleet.
- ~70% cheaper than regular Fargate or EC2.
- No AMIs, no user-data, no patching, no ASG, no Instance Refresh for the *backend* (the EC2 ASG is now *only* for the static frontend/nginx layer).
- The service `capacity_provider_strategy` with `FARGATE_SPOT` (weight 1) tells ECS "always prefer Spot for this service".
- Trade-off: Spot capacity can be reclaimed (Fargate gives ~2 min notice via a spot interruption notice, then task is stopped). For this To-Do demo/portfolio it's fine and shows you understand the concept. In real prod you could do a mixed strategy (base:1 FARGATE + weight for SPOT) or just regular FARGATE for critical path.

**What changed in code (Terraform)**
- `aws_ecs_service.backend` now uses `capacity_provider_strategy { capacity_provider = "FARGATE_SPOT" ... }` (no `launch_type`).
- Full ALB integration: dedicated target group (type=ip), ingress SG from ALB, `load_balancer` block on service, and `aws_lb_listener_rule` with priority 100 for paths `/api/*` and `/api`.
- Result: your existing React (served via the ALB -> EC2 nginx) keeps calling the same `REACT_APP_API_BASE` (ALB DNS + /api). Traffic for API is now routed to the Fargate Spot tasks. Static frontend still comes from the EC2 layer (gradual migration story — excellent for interviews).
- DB creds: injected via `secrets[]` + valueFrom SSM ARNs (SecureString). Execution role has least-privilege SSM policy.
- Container Insights + CW log group + several ECS-specific alarms + a starter dashboard are created by TF.

**Exact commands you run (do in this order)**

1. Make sure your dev SSM params exist (host, user, password as SecureString). If any missing after previous work:
   ```bash
   # From PowerShell or Git Bash (MSYS_NO_PATHCONV protects the leading / on some shells)
   MSYS_NO_PATHCONV=1 aws ssm put-parameter --name "/ha-project/development/db_host" --type String --value "myapp-rds....us-east-1.rds.amazonaws.com" --overwrite
   MSYS_NO_PATHCONV=1 aws ssm put-parameter --name "/ha-project/development/db_user" --type String --value "admin" --overwrite
   MSYS_NO_PATHCONV=1 aws ssm put-parameter --name "/ha-project/development/db_password" --type SecureString --value "YOUR_REAL_PASSWORD" --overwrite
   ```

2. Apply the infrastructure (this is the big one that stands up Fargate Spot + ALB rule + everything):
   ```bash
   cd terraform
   terraform init -backend-config="key=ha-project/development/terraform.tfstate" -reconfigure
   terraform apply -var="environment=development" -var="db_password=YOUR_REAL_PASSWORD_HERE" -var="frontend_s3_prefix=current" -auto-approve
   ```
   Watch for the new resources: ecs_cluster, ecs_task_definition, ecs_service (Spot), lb_target_group (ecs), lb_listener_rule, security group ingress, iam_role_policy for ssm, cloudwatch alarms, cloudwatch_dashboard, log_group.

3. (After apply succeeds) Trigger a container build + deploy so the real image (with /metrics + prom) goes out:
   - Commit + push the changes we made (server.js, package.json, Dockerfile, the TF updates, deploy.yml tweaks).
   - The pipeline (dev job) will: build image, Trivy scan (with the per-stage vuln section), push to ECR, then the "Deploy Backend to ECS (Fargate Spot)" step will register a fresh task def revision (with the promoted digest + secrets) and `update-service --force-new-deployment`.
   - Because the *service* already has the FARGATE_SPOT strategy from TF, the new tasks will launch on Spot.

4. Verify in AWS Console / CLI:
   - ECS → Clusters → ha-project-cluster → Services → ha-backend-service
     - You should see "Capacity provider strategy: FARGATE_SPOT"
     - Tasks tab: 2 running tasks. Click one → see "Capacity provider: FARGATE_SPOT", private IP, health status.
   - Go to your website (ALB DNS). Create/edit a few tasks. They should save/load (proof the Fargate backend is now handling /api via the ALB rule, talking to the same RDS).
   - If you still see the old EC2 backend logs or behavior, the ALB rule may need a minute or you hit a cached task; force refresh or scale the service desired_count up/down to force replacement.

5. (Nice to have) Enable ECS Exec for live debugging inside a Fargate task (no SSH):
   - Add `enable_execute_command = true` on the service resource (we can do in a follow-up).
   - Then: `aws ecs execute-command --cluster ... --task <task-id> --container backend --interactive --command "/bin/sh"`

**Rollback / safety**
- If a bad image goes out, just `aws ecs update-service --task-definition <previous-good-revision>` or let the pipeline promote a fixed one.
- Because it's Fargate, no "instance" to terminate; the service does the rolling replacement for you.
- The old EC2 ASG + Instance Refresh story is still there for the frontend layer (you kept the reliability demo).

## 5. How to View CloudWatch Dashboards, Metrics, and Logging

**CloudWatch Dashboard (the one we IaC'ed)**
1. Go to AWS Console → search "CloudWatch" → Dashboards (left menu).
2. You will see `development-ha-project-overview` (created by `aws_cloudwatch_dashboard` in main.tf).
3. Click it. It has three widgets:
   - ECS Fargate + ALB (CPU/Mem for the service, ALB latency + request count)
   - RDS MySQL (CPU, connections, free storage)
   - Logs Insights widget that auto-runs a query for errors in `/ecs/ha-backend`

**Create / customize your own dashboard (portfolio talking point)**
- Dashboards → Create dashboard → give it a name.
- Add widget → Line / Number / etc.
- Browse metrics:
  - Namespace: AWS/ECS or ECS/ContainerInsights (filter ClusterName = ha-project-cluster, ServiceName = ha-backend-service)
  - Also AWS/ApplicationELB, AWS/RDS, etc.
- Add a Logs Insights widget: pick the log group `/ecs/ha-backend`, paste a query like the one below.

**Viewing raw metrics**
- CloudWatch → Metrics (left) → All metrics.
- Search "ha-project" or browse:
  - ECS → ClusterName, ServiceName
  - ContainerInsights (per-task CPU, Mem, NetworkRx/Tx, Storage — excellent for seeing Spot behavior)
  - ApplicationELB → by load balancer name
- You can create custom alarms from any of these (we already added several in TF for CPU/Mem/RunningTaskCount + the old RDS ones).

**Logging (the most important for debugging "Failed to fetch tasks" etc.)**
- CloudWatch → Logs → Log groups.
- Find `/ecs/ha-backend` (the one created by the `aws_cloudwatch_log_group` + used by the awslogs driver in task def).
- Click "View in Logs Insights" or just "Search log group".
- Powerful example queries (copy-paste):
  ```sql
  fields @timestamp, @message
  | filter @message like /error|Error|Failed|exception/
  | sort @timestamp desc
  | limit 50
  ```
  ```sql
  fields @timestamp, @message
  | filter @message like /tasks/
  | stats count() by bin(5m)
  ```
  ```sql
  SOURCE '/ecs/ha-backend' | fields @timestamp, @message | filter ispresent(userId) or @message like /userId/
  ```
- Streams tab shows live tail per task (each task gets its own stream prefix `ecs/backend/...`).

**Container Insights bonus view (ECS-native)**
- Go to ECS console → your cluster → click the "Container Insights" tab or the "View in CloudWatch" links.
- This gives you beautiful out-of-the-box dashboards for CPU, memory, task count, etc. per service + per container. This is often the first thing interviewers ask about when you say "we moved to Fargate".

**Alarms + SNS**
- CloudWatch → Alarms. Look for names containing `ecs-backend`, `rds-`, etc.
- They are wired to the SNS topic `<env>-ha-project-alarms`.
- In console you can subscribe your email to the topic so you actually get notified (great demo).

## 6. Best Project-Specific Metrics & Logging Ideas (What You Should Actually Measure)

Generic "CPU high" is ok for infra, but for a **portfolio + interview** you want to show you instrumented around the *business* and the *reliability story* of this specific project (To-Do app + ALB + RDS + CI/CD promotion + EC2 refresh + now Fargate Spot backend).

### Golden Signals (for the /api backend)
- **Latency**: `ha_backend_http_request_duration_seconds` histogram (p99, p50) or ALB TargetResponseTime. SLO idea: "p99 < 300 ms for task list/create".
- **Traffic**: requests/sec (ALB RequestCount or rate(ha_backend_http_requests_total[5m])).
- **Errors**: 5xx rate from ALB, or `ha_backend_db_errors_total`, or log filter count of "Failed to fetch/create".
- **Saturation**: ECS MemoryUtilization / CPUUtilization (Fargate tasks have hard caps — if you hit them you get killed). Also RDS DatabaseConnections vs the  max (we alarm at 80).

### Business / To-Do Specific (these make you stand out)
- `ha_backend_tasks_created_total` — rate of users creating todos (core feature usage).
- `ha_backend_tasks_fetched_total` — read load on the list view.
- Per-priority or per-status breakdowns if you add labels later.
- Error rate on write path (create/update) vs read — different user impact.

### DB Layer (critical because everything was breaking on .env / SSM / port before)
- `ha_backend_db_query_duration_seconds` histogram by operation (select_tasks, insert_task, update_task, health).
- `ha_backend_db_errors_total{operation=...}` — connection pool exhaustion, auth failures, etc.
- RDS FreeStorageSpace + DatabaseConnections (already alarmed).

### Reliability / Operations (your 4-domain story)
- RunningTaskCount (we alarm if <1) + Service deployment events.
- During EC2 Instance Refresh (still happening for the frontend layer): watch ALB healthy host count + error rate spikes + "Target.FailedHealthChecks". Show that even when instances go down/up the /api path (now on Fargate) stays up.
- Spot-specific: look in ECS task stopped reasons or CloudWatch events for "SpotInterruption" or capacity messages (Fargate hides a lot but you can still observe task churn).
- Pipeline success + image promotion: after a deploy you should see zero "Failed to fetch tasks" in the new tasks' logs.
- Health check pass rate on the ECS target group vs the EC2 one.

### Security / Supply Chain (from the Trivy work you asked for)
- Track (manually or script) number of CRITICAL + HIGH unfixed vulns per stage from the pipeline "Vulnerabilities for <stage>" sections + the SARIF in GitHub Security tab.
- Trend over time (you can even push a custom metric from the pipeline if ambitious).
- ECR scan_on_push findings.

### Logging Best Practices Applied Here
- Structured JSON (winston already does this).
- Add a correlationId (generate uuid per request, put in logger + response header + metrics label if you want).
- Log at key points: successful task create, DB errors with context (not just stack), request duration if you want.
- Use Logs Insights + CloudWatch Contributor Insights for top userIds or slowest queries.

**Example SLOs you can talk about**
- "The task API maintains 99.5% success rate and p99 latency <250ms even during EC2 refreshes and Spot placement."
- "We alert on >80% RDS connections or <2 healthy API tasks within 2 minutes."
- "Vuln count in promoted images must have 0 CRITICAL before manual prod approval."

These are the things that show you understand *observability for the actual system you built*, not just "turn on CloudWatch".

## 7. Adding Prometheus + Grafana on Top of CloudWatch (Learning-Focused)

You asked: "let's add prometheus + grafana on top of the cloudwatch also I wan't to learn about that"

**Why both?**
- **CloudWatch** = managed, zero-ops for AWS-native signals (EC2, ALB, RDS, ECS Container Insights, Logs, Alarms, Dashboards). Perfect base layer. The alarms and the IaC dashboard we added are already valuable.
- **Prometheus + Grafana** = open standard, pull-based, amazing for *application* metrics you control (`/metrics`), PromQL is extremely powerful for rate() / histogram_quantile() / recording rules, Grafana dashboards are beautiful and portable. You can also add the CloudWatch data source plugin to the *same* Grafana so one pane of glass shows infra (CW) + app (Prom).

This hybrid is very common on AWS.

**What we already did for you**
- Added `prom-client` to backend/package.json.
- Registered default process metrics (`ha_backend_process_*`) + custom:
  - `ha_backend_http_request_duration_seconds` (histogram with method/route/status)
  - `ha_backend_http_requests_total` (counter)
  - `ha_backend_tasks_created_total` / `tasks_fetched_total` (business)
  - `ha_backend_db_query_duration_seconds` + `db_errors_total` (by operation)
- Middleware that auto-instruments every request.
- `/metrics` endpoint (plain text prometheus exposition format).
- Updated health + queries to go through the timed helper.
- Dockerfile installs wget (for healthcheck) and will include the new dep on next build.
- The pipeline will ship images with this instrumentation.

**How to actually scrape & visualize right now (quick wins)**

1. **See /metrics locally or via a running task (immediate learning)**
   - After a task is running on Fargate:
     - Easiest for demo: use AWS ECS Exec (enable it) or temporarily `assign_public_ip = true` + look up the task ENI public? (Fargate tasks with public IP still have the port only reachable if SG allows; better not).
     - Practical way: from one of your EC2 instances (they are in the same VPC/private subnets), use SSM Session Manager or SSH and run:
       ```bash
       # Find a running task private IP (from ECS console Tasks tab or aws ecs list-tasks + describe)
       curl -s http://10.x.x.x:3000/metrics | head -30
       ```
     - You will see all the `ha_backend_*` lines + process_* . This is the scrape target.

2. **Quick local Prometheus + Grafana (zero AWS cost, great for learning)**
   - On your laptop:
     ```bash
     docker run -d -p 9090:9090 --name prom prom/prometheus
     docker run -d -p 3001:3000 --name graf grafana/grafana
     ```
   - Edit prometheus.yml (or use UI) to add a scrape job. For real scrape you need network reachability into the VPC (VPN, bastion, or for demo expose a test endpoint temporarily).
   - In Grafana add Prometheus data source (http://host.docker.internal:9090 if using Docker Desktop), import a dashboard or build panels for:
     - rate(ha_backend_tasks_created_total[5m])
     - histogram_quantile(0.99, rate(ha_backend_http_request_duration_seconds_bucket[5m]))
     - ha_backend_db_query_duration_seconds
   - Also add the CloudWatch data source plugin in Grafana (AWS sigv4 auth) and graph the same ECS/RDS metrics we have in the native CW dashboard. This demonstrates "on top".

3. **Production-grade on AWS (what you would actually run)**
   - **Amazon Managed Prometheus (AMP)**: create a workspace. It gives you a remote_write endpoint + PromQL query endpoint.
   - Scrape options for ECS Fargate:
     - Sidecar pattern (very common): add a second container in the same task definition that runs a small prometheus or the ADOT collector. It scrapes `http://localhost:3000/metrics` (same task = localhost networking even in awsvpc) and remote_writes to AMP. Config via volume or env.
     - Or use the AWS Prometheus scraper (newer service) that discovers ECS services via tags/annotations and scrapes on a schedule.
   - **Amazon Managed Grafana (AMG)**: create a workspace (SSO or IAM), add two data sources:
     - Prometheus (point at your AMP workspace)
     - Amazon CloudWatch (built-in)
   - Then build one dashboard that mixes "Fargate Spot CPU from CW" + "tasks created per minute from Prom" + "p99 API latency".
   - Cost: you pay for samples ingested into AMP + AMG user hours. For a demo/portfolio you can run for a few days and delete.

**Learning points to mention in your presentation / README**
- "We use CloudWatch for managed AWS signals and alarms because it is zero-effort and deeply integrated. We added Prometheus exposition from the app so we own our business SLIs (task creation rate, exact DB query latency) and can move the dashboards if we ever go multi-cloud."
- "The /metrics endpoint + prom-client is the standard. Every language has a client; the middleware + custom counters/histograms follow the RED method (Rate, Errors, Duration) + USE for resources + business metrics."
- "Fargate Spot + Container Insights gives us the saturation signal cheaply. Prometheus gives us the application-level view that CW can't see inside your Node process."
- "We kept the old EC2 refresh path running in parallel so we can demonstrate that the API (now on Spot) stays healthy while the frontend instances are refreshed."

**Next concrete steps for full Prom/Grafana (if you want to go further)**
- Enable execute-command on the service + add the required IAM (task role + ecs agent).
- Add a sidecar container definition example in the TF task (commented) that runs a prom config scraping localhost:3000 and writing to an AMP workspace id you create.
- Or just document the local docker method + the Grafana CW + Prom dual datasource as the learning exercise.

This combination (CW native + Prom instrumentation + hybrid Grafana + the tailored metrics list above) is exactly what a strong SAA + real-world project should show.

## 8. What to Do Right Now (Updated Commands + Verification)

```bash
# 1. (You) ensure SSM params exist for development (see step 1 in Fargate section above)

# 2. Apply the full Fargate Spot + ALB wiring + alarms + dashboard + CW resources
cd /mnt/c/Users/Timothy\ Kamba/aws-ha-autoscaling-project/terraform   # or however you cd
terraform init -backend-config="key=ha-project/development/terraform.tfstate" -reconfigure
terraform apply -var="environment=development" -var="db_password=THE_REAL_ONE" -var="frontend_s3_prefix=current" -auto-approve

# 3. Commit & push everything (TF changes, backend prom-client, Dockerfile, pipeline note, this guide)
git add -A
git commit -m "feat: Fargate Spot via capacity_provider_strategy + full ALB /api rule + DB secrets in ECS task + prom-client /metrics + CW dashboard/alarms + detailed guide for Spot, viewing, metrics ideas, Prom/Grafana"
git push origin development

# 4. Watch the dev pipeline. The "Deploy Backend to ECS (Fargate Spot)" step should succeed.

# 5. Verify the new world
# - Website still works, tasks persist (now served by Fargate Spot tasks)
# - ECS console: service shows FARGATE_SPOT, tasks healthy
# - CloudWatch > Dashboards > development-ha-project-overview (and the Logs Insights errors widget)
# - CloudWatch > Alarms (new ecs-backend-* ones)
# - Logs > /ecs/ha-backend
# - (When tasks running) From an EC2 instance or with exec: curl http://<private-task-ip>:3000/metrics
# - GitHub Security tab still shows the SARIF + the pipeline has the nice per-stage vuln tables

# 6. (Optional but cool) Manually force a task replacement to see Spot scheduling
aws ecs update-service --cluster ha-project-cluster --service ha-backend-service --force-new-deployment --region us-east-1
```

Everything prior (CI/CD promotion with gates + auto PRs, Trivy per stage, least-privilege IAM, per-env TF state hygiene with data sources + conditional, safer 100% Instance Refresh, backend fixes, etc.) is still there. This finishes the Monitoring/Logging + containerization piece you asked for.

You now have a very strong portfolio project covering IaC maturity, security in pipeline, reliability (refresh + Fargate rollout), and observability (CW + Prom path).

Run the apply + push, then tell me what you see in the ECS service and the CloudWatch dashboard and we'll polish anything (e.g. add execute-command, more Prom panels, or cut over the EC2 backend completely).
