# Use this script to get safe commands.
# It will create temp JSON files for parameters (most reliable in PS).

$instance = "i-02b26c6720572282f"  # Update if needed from helper
$region = "us-east-1"

Write-Host "=== COPY AND RUN THESE BLOCKS ONE BY ONE ===" -ForegroundColor Cyan
Write-Host "Using instance $instance" -ForegroundColor Yellow
Write-Host ""

# 1. .env + health
$cmds1 = @("cat /opt/ha-backend/.env", "echo ---", "curl -s --max-time 5 http://127.0.0.1:3000/health || echo backend_health_failed")
$json1 = @{ commands = $cmds1 } | ConvertTo-Json -Compress
$json1 | Out-File -Encoding utf8 -NoNewline params1.json
Write-Host "# 1. .env + health"
Write-Host "aws ssm send-command --document-name AWS-RunShellScript --targets Key=instanceids,Values=$instance --parameters file://params1.json --region $region"

# 2. log tail
$cmds2 = @("tail -80 /var/log/user-data.log | cat")
$json2 = @{ commands = $cmds2 } | ConvertTo-Json -Compress
$json2 | Out-File -Encoding utf8 -NoNewline params2.json
Write-Host ""
Write-Host "# 2. recent log tail"
Write-Host "aws ssm send-command --document-name AWS-RunShellScript --targets Key=instanceids,Values=$instance --parameters file://params2.json --region $region"

# 3. key log lines
$cmds3 = @("grep -E \"ENV=|DB_|Fetching|retrieved|ERROR|Backend service|Nginx|Full Stack Bootstrap Complete|OK \" /var/log/user-data.log | cat")
$json3 = @{ commands = $cmds3 } | ConvertTo-Json -Compress
$json3 | Out-File -Encoding utf8 -NoNewline params3.json
Write-Host ""
Write-Host "# 3. key log lines"
Write-Host "aws ssm send-command --document-name AWS-RunShellScript --targets Key=instanceids,Values=$instance --parameters file://params3.json --region $region"

Write-Host ""
Write-Host "=== After each send (note the CommandId), wait 45s, then for each ID run: ===" -ForegroundColor Green
Write-Host '$env:PYTHONIOENCODING="utf-8"'
Write-Host 'aws ssm list-command-invocations --command-id <ID> --details --query "CommandInvocations[0].CommandPlugins[0].Output" --output text | Out-File -Encoding utf8 result.txt ; Get-Content result.txt'
Write-Host ""
Write-Host "Paste the contents of result.txt for each."
