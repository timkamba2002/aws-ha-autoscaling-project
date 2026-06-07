# Accessing Prometheus and Grafana UI + How It Relates to Your Project

## How Prometheus + Grafana Relates to *Your* HA To-Do Project
Your backend (running on ECS Fargate Spot) is already instrumented with `prom-client` (see `backend/server.js`).

It exposes `/metrics` with:
- Default Node.js process metrics (prefixed `ha_backend_process_*`)
- Custom metrics you care about:
  - `ha_backend_http_request_duration_seconds` (histogram for latency, labeled by method/route/status)
  - `ha_backend_http_requests_total`
  - `ha_backend_tasks_created_total` and `ha_backend_tasks_fetched_total` (business SLIs — actual usage of your To-Do app)
  - `ha_backend_db_query_duration_seconds` and `ha_backend_db_errors_total` (by operation — helps prove DB health during refreshes or Spot events)

**Prometheus** is a pull-based time-series database. It periodically scrapes HTTP endpoints that return the Prometheus text format (`metric{labels} value`). You query it with PromQL (powerful for rates, histograms, etc.).

**Grafana** is the dashboarding/alerting UI. It can query Prometheus *and* CloudWatch at the same time.

**Relation to your project**:
- CloudWatch (what you already have via Terraform): Infra/Container layer — ECS CPU/mem (Container Insights), RDS, ALB, logs, alarms, the `development-ha-project-overview` dashboard.
- Prometheus/Grafana (on top): Application layer — the metrics *you* control inside the Node process.
  - Golden signals (RED): Rate, Errors, Duration for the `/api` layer that your React frontend calls.
  - Business SLIs: Task creation rate (proves users are actively using the app even during an EC2 Instance Refresh or Fargate Spot churn).
  - Technical SLIs: DB query latency/errors (directly related to your past .env/SSM/DB connection issues).
- Why "on top": You can have one Grafana dashboard with Prom panels (app metrics) + CloudWatch panels (infra). This shows full observability: "The app stayed healthy (task creates steady) even while the frontend refreshed and backend ran on Spot."
- In the pipeline: The same image (with prom-client) is promoted via the artifact, and you re-scan vulns per stage.
- Long-term: Use Amazon Managed Prometheus (AMP) for scraping + Amazon Managed Grafana (AMG) with dual datasources (Prom + CW). No managing Docker.

This completes the "add Prometheus + Grafana on top of CloudWatch" requirement and gives you a strong demo story for reliability + observability.

## How to Access the UIs (Your Setup: Private Tasks + EC2 Bastion + SSM)

Tasks are private (10.0.4.x range). You cannot curl them directly from your laptop.

**Best way**: Use one of your existing EC2 instances (in the ASG, same VPC/private subnets, SSM-enabled) as the host.

You already have the IP (10.0.4.190 — confirm it's still a current healthy task in ECS console → Tasks tab → click task → Networking).

### Option 1: Full Interactive Shell on EC2 via Terminal (Easiest for Testing)
From your PowerShell (no browser SSM needed):

1. Get an InService EC2 instance ID (run this):
   ```powershell
   $instanceId = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ha-project-asg --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId | [0]" --output text
   Write-Host "Using EC2: $instanceId"
   ```

2. (Important) Make sure the security group rule is updated and the EC2 role has ECS read permissions (so it can ListTasks etc.):
   ```powershell
   cd terraform
   $env:TF_VAR_db_password = aws ssm get-parameter --name "/ha-project/development/db_password" --with-decryption --query "Parameter.Value" --output text
   terraform apply -var="environment=development" -var="frontend_s3_prefix=current" -auto-approve
   ```
   (This applies the new "ECSReadTasks" policy to ha-project-ec2-frontend-role and the ingress rule from EC2 SG to ECS SG on port 3000. The apply should be quick.)

3. Start a *new* interactive session (exit current one first with `exit`, then):
   ```powershell
   aws ssm start-session --target $instanceId
   ```

4. Inside the (new) shell on the EC2, first get the *current* private IPs of the running tasks (they can change):
   ```bash
   export AWS_DEFAULT_REGION=us-east-1
   for arn in $(aws ecs list-tasks --cluster ha-project-cluster --service-name ha-backend-service --query 'taskArns[*]' --output text); do
     aws ecs describe-tasks --cluster ha-project-cluster --tasks $arn --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text
   done
   ```

5. Then run the curl with a *current* IP (use --connect-timeout to avoid hanging). **Important: do NOT put < > around the IP** — that causes bash to treat it as file redirection (that's why you got "No such file or directory").
   ```bash
   curl -v --connect-timeout 5 http://10.0.3.95:3000/metrics | head -40
   ```
   or for health first:
   ```bash
   curl -v --connect-timeout 5 http://10.0.3.95:3000/health
   ```

   Try the other IP too if this one fails:
   ```bash
   curl -v --connect-timeout 5 http://10.0.4.195:3000/health
   ```

   You will see the `ha_backend_*` metrics directly in your terminal if it works.

6. To exit the session: type `exit`

This is "on terminal instead of SSM on console" — full shell, no browser.

You can run any commands (including the Docker steps below) inside this session.

### Option 2: Non-Interactive (send-command) — Good for One-Off Curls
```powershell
$instanceId = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ha-project-asg --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId | [0]" --output text

$commandId = aws ssm send-command --instance-ids $instanceId --document-name "AWS-RunShellScript" --parameters "commands=['curl -s http://10.0.4.190:3000/metrics | head -40']" --region us-east-1 --query "Command.CommandId" --output text

# Wait a few seconds, then get output
aws ssm list-command-invocations --command-id $commandId --details --query "CommandInvocations[0].CommandPlugins[0].Output" --output text
```

### Running Prometheus + Grafana for UI Access (on the EC2)
While in the SSM session (or via send-command), run these on the EC2:

```bash
sudo yum install -y docker
sudo service docker start

# Fix the permission denied error (the user ec2-user is not in the docker group yet)
# When sudo usermod asks for password, enter the password for the ec2-user account
# (if you don't know it, you can set one with: sudo passwd ec2-user )
# If sudo usermod asks for password and you get stuck (common in SSM sessions where ec2-user has no password set):
# Simplest for this test: just prefix docker commands with sudo (no need for usermod/newgrp)
# Or, to set password:
sudo passwd ec2-user   # set a temp password e.g. TestPass123!
# then
sudo usermod -aG docker ec2-user
# enter the password you set
newgrp docker

# Verify
docker info   # or use sudo docker info if still issues

# Prometheus config (we'll overwrite this with live IPs later)
cat > /tmp/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'ha-backend-fargate'
    static_configs:
      - targets: ['10.0.3.95:3000']
EOF

# Prometheus on host network so other containers / host can easily reach it
sudo docker run -d --name prom-test \
  --network host \
  -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Grafana also on host network + custom port so "localhost" inside Grafana can reach prom on 9090
# and the SSM port-forward on 3001 continues to work
sudo docker rm -f grafana-test 2>/dev/null || true
sudo docker run -d --name grafana-test \
  --network host \
  -e "GF_SERVER_HTTP_PORT=3001" \
  grafana/grafana

# Verify
sudo docker ps | grep -E 'prom-test|grafana-test'
```

### Accessing the UIs (Prometheus on 9090, Grafana on 3001)
**Preferred: SSM Port Forwarding** (from your PowerShell terminal — no SG changes needed):

Use these **one-line** commands (copy exactly, including the escaped quotes; the quoting is tricky in PowerShell):

```powershell
# Prometheus (run in ONE PowerShell window)
aws ssm start-session --target i-008a75109789ceabf --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"9090\"],\"localPortNumber\":[\"9090\"]}'

# Grafana (run in a *SEPARATE* PowerShell window)
aws ssm start-session --target i-008a75109789ceabf --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3001\"],\"localPortNumber\":[\"3001\"]}'
```

Then open in your browser:
- Prometheus UI: **http://localhost:9090**
- Grafana UI: **http://localhost:3001** (default login: admin / admin — change password right away!)

Leave the sessions running while you test.

**Alternative (if EC2 has public IP)**: Update the EC2 security group temporarily to allow your laptop IP on 9090 and 3000, then use `http://<ec2-public-ip>:9090` etc. Remember to remove the rule after.

### How to Use the UIs (Project-Specific)
**Prometheus UI (http://localhost:9090)**:
- Go to **Graph**.
- Enter queries (these match your exact metrics from the curls you ran):
  - `rate(ha_backend_tasks_created_total[1m])` — tasks created per second (key business SLI for your To-Do app).
  - `histogram_quantile(0.99, rate(ha_backend_http_request_duration_seconds_bucket[5m]))` — p99 latency.
  - `ha_backend_db_query_duration_seconds{operation="health"}` — DB query time.
  - `ha_backend_http_requests_total{status_code="200"}` — successful requests.
- Click Execute. Use the time picker (last 5m / 1h) and refresh button.
- Go to **Status > Targets** to see if your task is being scraped ("UP").

**Grafana UI (http://localhost:3001)**:
- Login (admin/admin first time — change password immediately).
- **Add Prometheus datasource** (this is what turns the raw PromQL into pretty graphs):
  1. If you haven't already, make sure both containers are running with host networking (run this in your SSM session):
     ```bash
     sudo docker rm -f prom-test grafana-test 2>/dev/null || true

     # prom with current live IPs (run the discovery block from the troubleshooting section first if needed)
     sudo docker run -d --name prom-test \
       --network host \
       -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
       prom/prometheus

     sudo docker run -d --name grafana-test \
       --network host \
       -e "GF_SERVER_HTTP_PORT=3001" \
       grafana/grafana
     ```
  2. Click the gear icon (⚙️ Configuration) in the left sidebar → **Data sources** → **Add data source**.
  3. Choose **Prometheus**.
  4. Fill exactly like this:
     - **Name**: `prometheus` (or `HA-Prometheus`)
     - **Prometheus server URL**: `http://localhost:9090`
     - **Authentication method**: `No Authentication`
     - **Prometheus type**: Choose `Prometheus` (the standard / first option, not Mimir/Thanos/Cortex)
     - **HTTP method**: `POST` (recommended)
     - **Scrape interval**: `15s` (matches our config)
     - Leave almost everything else at the defaults (TLS off, no extra headers, etc.).
  5. Click **Save & Test** at the bottom.
     - You should see a green "Data source is working" message (or "Successfully queried the Prometheus API").
     - If it fails with connection refused / timeout / "unable to connect", the containers are probably not both on `--network host`. Re-run the docker commands above from the SSM session, wait 10s, then try Save & Test again.
- **Add CloudWatch datasource** (this is the "on top of CloudWatch" part — hybrid view):
  1. Back in Data sources → **Add data source** → **CloudWatch**.
  2. Name: `CloudWatch`
  3. **Authentication**: Select **SDK DEFAULT** (this is the correct choice for our setup — it automatically uses the IAM role attached to the EC2 instance the containers are running on).
     - Do **not** pick Access & Secret Key or credentials file.
  4. Default Region: `us-east-1`
  5. Click **Save & Test**.
  6. If the test fails with access/permission errors (like the ListMetrics / DescribeLogGroups ones below), run this in PowerShell to grant the missing permissions, then re-test Save & Test:

```powershell
cd "C:\Users\Timothy Kamba\aws-ha-autoscaling-project\terraform"

$env:TF_VAR_db_password = aws ssm get-parameter --name "/ha-project/development/db_password" --with-decryption --query "Parameter.Value" --output text

terraform apply -var="environment=development" -var="frontend_s3_prefix=current" -auto-approve
```
- **Create the hybrid dashboard** (this is the portfolio gold — one screen showing your app SLIs from Prometheus + infra from CloudWatch):
  1. Left sidebar → **+** (Create) → **Dashboard**.
  2. Click **Add new panel** (or the big + in the middle).
  3. You will land in the panel editor. You will probably see a visual "Builder" with "Metric", "Label filters", "Expression", "Operations" etc. — this is the confusing part.
  4. **Switch to Code editor** (critical):
     - In the query section (near "A" and the prometheus data source), look for the **Builder** / **Code** toggle (or a small `{ }` code icon, or "Switch to code editor").
     - Click **Code**. A large text box will appear where you can paste raw PromQL.
  5. On the right sidebar, click the current visualization (at the very top of the right panel) and pick the recommended type below (most of ours are **Time series**).
  6. Paste one of the queries below into the big text box.
  7. Set a clear **Title** at the top of the panel.
  8. (Nice to have) On the right under Standard options, set a **Unit** (req/s or s).
  9. Click **Run queries** if needed, then **Apply** (top right).
  10. Repeat: Add new panel → switch to Code → paste next query → title → Apply.
  When finished with panels, click the save (disk) icon and name the dashboard **`HA To-Do – Prom + CloudWatch`**.

**Recommended panels (copy the queries exactly):**

**Prometheus panels (app-level + business SLIs you own):**

**Panel 1**
- **Title:** `Task Creation Rate (Business SLI)`
- **Query:** `rate(ha_backend_tasks_created_total[5m])`
- **Visualization:** Time series (or Stat for a big single number)
- **Unit to type:** `req` (select req/s or requests per second)
- **Why:** This is your main **business SLI**. It shows how many tasks users are actually creating per second. The line should go up when you use the website to create tasks.

**Panel 2**
- **Title:** `p99 API Request Latency`
- **Query:** `histogram_quantile(0.99, rate(ha_backend_http_request_duration_seconds_bucket[5m]))`
- **Visualization:** Time series
- **Unit to type:** `s` (select seconds)
- **Why:** Shows the 99th percentile response time (p99 latency). This is a key technical SLI — proves whether the API stays fast even during refreshes or Spot interruptions.

**Panel 3**
- **Title:** `HTTP Requests by Status`
- **Query:** `sum by (status_code) (rate(ha_backend_http_requests_total[5m]))`
- **Visualization:** Time series (recommended: turn on "Stack series" under Graph styles on the right for a stacked look)
- **Alternative viz:** Bar chart
- **Unit to type:** `req` (select req/s)
- **Why:** Breaks down request rate by HTTP status (200, 500, etc.). Great for seeing error rates at a glance.

**Panel 4 — DB Latency (optional, can be skipped if flaky)**
- **Title:** `DB Query Duration by Operation (p95)`
- **Query:** `histogram_quantile(0.95, sum by (le, operation) (rate(ha_backend_db_query_duration_seconds_bucket[5m]))) by (operation) and on (operation) (sum by (operation) (rate(ha_backend_db_query_duration_seconds_count[5m])) > 0)`
- **Visualization:** Time series
- **Unit to type:** `s` (select seconds)
- **Why:** Shows p95 DB latency per operation. Often flaky because non-health ops have low/sparse traffic. You can skip or comment it out.

**Strongly recommended DB panel (the one that actually works reliably):**
- **Title:** `DB Operations Rate by Type`
- **Query:** `sum by (operation) (rate(ha_backend_db_query_duration_seconds_count[5m]))`
- **Visualization:** Time series
- **Unit to type:** `req/s`
- **Why:** Shows frequency of each DB operation. Spikes clearly when you create tasks or load the list. This + HTTP p99 + Task Creation Rate already gives a strong observability story. Much more reliable than the quantile version.

**Optional Panel 5**
- **Title:** `Task Fetches Rate`
- **Query:** `rate(ha_backend_tasks_fetched_total[5m])`
- **Visualization:** Time series
- **Unit to type:** `req` (select req/s)
- **Why:** Another business SLI — shows how often the frontend is loading the task list. Good companion to task creation rate.

**CloudWatch panels (infra you already defined in Terraform):**

**Raw code queries (use these in the Expression field — this is the proper "code" way):**

**Important first:**
- Make sure the query type/selector is set to **CloudWatch Metrics** (not CloudWatch Logs or CWLI). If it's on Logs, the curly brace or wrong syntax will give "Invalid syntax".

**ECS Backend CPU (Fargate Spot)**
Paste this in the **Expression** field (raw/code mode):
```sql
SELECT AVG(CPUUtilization) 
FROM "AWS/ECS" 
WHERE ClusterName = 'ha-project-cluster' 
  AND ServiceName = 'ha-backend-service'
```
- Region: us-east-1 or default
- Click **Run queries**
- Right side → Visualization: **Time series**

**ECS Backend Memory (Fargate Spot)**
Duplicate the panel and paste:
```sql
SELECT AVG(MemoryUtilization) 
FROM "AWS/ECS" 
WHERE ClusterName = 'ha-project-cluster' 
  AND ServiceName = 'ha-backend-service'
```

**ALB Target Response Time**
ALB dimension value (from your CLI run): app/ha-project-alb/08c9a04bf9cac52f

Use this exact query in the Expression field (raw mode):
```sql
SELECT AVG(TargetResponseTime) 
FROM "AWS/ApplicationELB" 
WHERE LoadBalancer = 'app/ha-project-alb/08c9a04bf9cac52f'
```

**The error "parse error: unexpected <aggr:AVG>" is a Prometheus error, not CloudWatch.**
This means the panel (or the query inside it) is using the Prometheus datasource by mistake. Prometheus sees "SELECT AVG" and chokes on the aggregation.

**Fix:**
- In the panel editor, at the very top of the query section, the **Data source** dropdown must say "cloudwatch" (your CloudWatch one), **not** the Prometheus datasource.
- If it's showing Prometheus fields, change the data source to cloudwatch first.
- Then paste the SELECT in the Expression field (make sure it's in raw/code mode for CloudWatch Metrics, not Logs).
- Click **Run queries**.

**Quick way to add it correctly:**
- Add a brand new panel (don't edit an existing Prom panel).
- Immediately set Data source to cloudwatch.
- Switch to raw Expression.
- Paste the SELECT above.
- Run queries.
- Visualization: Time series.

**Interpreting "going straight down":**
The line trending downward means average response time from the backend targets to the ALB is decreasing over your selected time window – this is generally **good** (faster responses, system is healthy or improving under load). 

To see more interesting movement:
- Set the dashboard time range to **Last 5 minutes** or **Last 15 minutes**.
- Actively use the website (create tasks, refresh lists) while the dashboard is open – this generates real ALB traffic and the graph should react with changes/spikes.
- Click refresh on the panel.

If it's dropping to near zero or flatlining, it often means the selected time window has mostly low recent traffic – more site usage will populate fresher data. The graph is a trend across the whole range, not just "now".
- Title: ALB Target Response Time.

Generate traffic on the site (create tasks) and use a recent time range (Last 15 min). Use Query inspector if it still fails after fixing the datasource.
  - Value: `app/ha-project-alb/08c9a04bf9cac52f`
- Click **Run queries**
- Right sidebar: Visualization = `Time series`
- Title the panel: `ALB Target Response Time`

Make sure the dashboard time range is recent (Last 15 min or 1h) and create a few tasks on the website so the ALB sees traffic (the site is behind the ALB).

**Tip:** After adding these, arrange the dashboard with Prom panels on the left (app SLIs) and CloudWatch on the right (infra). Use "Last 15 minutes" or "Last 1 hour" time range. Generate traffic in the website (create tasks) while viewing so both sets of lines move. Save when done.

**Session save note (2026-06-05)**: Dashboard currently has Prom panels + 2 ECS CW panels. ALB panel ready (query + CLI command for dimension value below). User paused due to AWSDenyALL policy on account (resume tomorrow after admin removes it). All raw SELECT queries are in this guide. Full RESUME + DEV_HISTORY updated for continuity. User will handle GitHub commits themselves.

After adding 5–8 panels, drag them around to arrange nicely on the grid, then click the **save icon** (floppy disk) in the top bar and name the dashboard exactly:

**`HA To-Do – Prom + CloudWatch`**

**Pro tip while building**:
- Keep the React To-Do website open in another browser tab.
- Create 3–5 new tasks (and refresh the list) every 30–60 seconds while adding panels — you'll see the Task Creation Rate and other lines start moving live. This makes the demo much stronger.
- Top-right time picker → set to "Last 15 minutes" or "Last 1 hour", and use the refresh button.
- You can always come back later and add alerts (e.g. if task creation rate drops).

This single saved dashboard is excellent portfolio evidence for "Prometheus + Grafana on top of CloudWatch". It shows both the app metrics you own (from prom-client in your Node code) and the AWS infra metrics. Later you can recreate the exact same thing in Amazon Managed Grafana + Amazon Managed Prometheus with zero servers to manage.

**Usage Tips for Your Project**:
- Keep the React website open in another tab and create/edit a few tasks every 30–60 seconds while you build panels. This makes the "Task Creation Rate" line actually move and proves the business SLI is live.
- During an ASG refresh (frontend layer): watch if Prom metrics (backend) stay stable while the EC2 layer refreshes.
- This is exactly "Prometheus + Grafana on top of CloudWatch": app-level SLIs (your custom ha_backend_* business + technical metrics) + infra (CW). One view for the full reliability story (Fargate Spot + refreshes).
- For real/prod later: Replace the Docker with Amazon Managed Prometheus (AMP) for scraping + Amazon Managed Grafana (AMG) using the exact same queries + dual datasources.

**Bonus (no Grafana needed)**: You already have a real CloudWatch dashboard from Terraform called something like `development-ha-project-overview`. Go to CloudWatch → Dashboards in the AWS Console to see the ECS/ALB/RDS widgets you defined in code. Grafana just makes the *Prometheus* side (your app code metrics) look beautiful and mixable.

### Troubleshooting: "Empty query result / This query returned no data"
This is the most common first-time issue. It almost always means one of these (in order of likelihood):

1. **Stale task IP in /tmp/prometheus.yml** (Fargate Spot tasks get *new private IPs* every time they are replaced or restarted. The IP you used when you first ran the curl (e.g. 10.0.3.95) is probably dead now.)
2. **Docker bridge network can't reach the task ENI** (your host-shell `curl http://10.x.x.x:3000/metrics` worked because the EC2 host has a direct route; the prom container by default is on a private bridge and may not).
3. **No increments yet on the *business* counters** (`ha_backend_tasks_created_total` etc. only go up when the React frontend actually calls `POST /api/tasks` and `GET /api/tasks`. Pure /health and /metrics traffic does *not* increment them. `rate(...)` over a window with zero increase returns no series.)
4. Scrape never succeeded (check Targets page).

**Immediate fix steps (do these now):**

**A. In your Prometheus browser tab (http://localhost:9090):**
- Click the **Status > Targets** tab (top menu).
- Look for the row with job `ha-backend-fargate` targeting the old IP.
- Note: Is it **UP** or **DOWN**? What does the "Last Error" or "Last Scrape" say? Paste it here.

**B. Refresh the scrape target with *live* IPs + fix networking (run in a *new* SSM shell — keep your two port-forward windows open!):**

In a fresh PowerShell:
```powershell
$instanceId = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ha-project-asg --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId | [0]" --output text
Write-Host "SSM to: $instanceId"
aws ssm start-session --target $instanceId
```

Inside the SSM bash session, paste this whole block (it auto-discovers current task IPs and restarts prom correctly):
```bash
export AWS_DEFAULT_REGION=us-east-1

echo "=== Discovering CURRENT live Fargate task IPs ==="
IPS=$(aws ecs list-tasks --cluster ha-project-cluster --service-name ha-backend-service --query 'taskArns[*]' --output text | tr '\t' '\n' | while read arn; do
  aws ecs describe-tasks --cluster ha-project-cluster --tasks "$arn" --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text
done | tr '\n' ' ')

echo "Live IPs: $IPS"

# Write a fresh prometheus.yml that targets *all* current tasks (supports the desired_count=2)
{
  echo 'global:'
  echo '  scrape_interval: 15s'
  echo 'scrape_configs:'
  echo '  - job_name: '\''ha-backend-fargate'\'''
  echo '    static_configs:'
  echo '      - targets:'
  for ip in $IPS; do
    echo "        - '$ip:3000'"
  done
} > /tmp/prometheus.yml

echo "=== New config ==="
cat /tmp/prometheus.yml

echo "=== Restarting prom-test with --network host ==="
sudo docker rm -f prom-test 2>/dev/null || true
sudo docker run -d --name prom-test \
  --network host \
  -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

echo "=== (Re)starting grafana-test also with host networking + port 3001 so localhost works inside Grafana ==="
sudo docker rm -f grafana-test 2>/dev/null || true
sudo docker run -d --name grafana-test \
  --network host \
  -e "GF_SERVER_HTTP_PORT=3001" \
  grafana/grafana

sleep 5
sudo docker ps | grep -E 'prom-test|grafana-test'

echo "=== Quick reachability test FROM INSIDE the prom container ==="
FIRST_IP=$(echo $IPS | awk '{print $1}')
sudo docker exec prom-test sh -c "
  (wget -qO- --timeout=3 http://$FIRST_IP:3000/metrics 2>/dev/null || \
   (apk add --no-cache curl >/dev/null 2>&1 && curl -s --max-time 3 http://$FIRST_IP:3000/metrics)) | head -15
" || echo "Inside test failed — will show in Targets error"
```

**C. Verify in UI**
- Wait 20–30 seconds (scrape interval is 15s).
- Refresh http://localhost:9090
- Go back to **Status > Targets** — the job should now be **UP** with a recent "Last Scrape".
- If still DOWN, the error column will tell us the exact problem (connection refused, timeout, DNS, etc.). Paste the error.

**D. Generate real traffic so the business metrics have data**
- Open your live website (the ALB URL that shows the React To-Do app — the one you confirmed was working earlier).
- Create 3–4 new tasks using the UI (this hits the real `POST /api/tasks` path that does `tasksCreatedTotal.inc()`).
- The list should also load (GET /api/tasks → tasksFetchedTotal).
- Do this a couple of times.

**E. Now run the queries (in Graph tab)**
Start with the *raw* counters (these appear as soon as a scrape succeeds, even if value is still small):
- `ha_backend_tasks_created_total`
- `ha_backend_http_requests_total`
- `ha_backend_db_query_duration_seconds`

Then the derived ones that were giving you "no data":
- `rate(ha_backend_tasks_created_total[1m])`
- `histogram_quantile(0.99, rate(ha_backend_http_request_duration_seconds_bucket[5m]))`
- `ha_backend_db_query_duration_seconds{operation="insert_task"}`

Click the refresh icon and use the time range "Last 5 minutes".

Once the raw series appear with non-zero values after your task creations, the `rate()` and `histogram_quantile()` will light up.

**F. (Optional but great for learning)**
Inside the same SSM session you can also curl the live /metrics after creating tasks:
```bash
curl -s http://<one-of-the-live-ips>:3000/metrics | grep -E 'ha_backend_tasks|ha_backend_http_requests_total'
```
You should see the counter values increase.

After you do the block above, paste:
- the output of the discovery block
- what Status > Targets now says
- a screenshot or the result of one of the raw counter queries

We'll get the graphs populated, then finish the Grafana hybrid dashboard (Prom panels + your existing CloudWatch ones).

**Cleanup when done (in the SSM session)**
```bash
sudo docker stop prom-test grafana-test
sudo docker rm prom-test grafana-test
```

(You can exit the SSM session anytime — the containers keep running because of `-d`.)