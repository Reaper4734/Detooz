<#
.SYNOPSIS
    Detooz Deployment Script - Push to GitHub + Deploy to EC2 via Docker
.DESCRIPTION
    1. Commits and pushes all changes to GitHub
    2. SSHs into EC2, pulls latest code
    3. Rebuilds and restarts Docker container
    4. Verifies health check
.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -Message "Fix login endpoint"
    .\deploy.ps1 -SkipPush
    .\deploy.ps1 -Quick
#>

param(
    [string]$Message = "",
    [switch]$SkipPush,
    [switch]$Quick
)

# ============================================================
# CONFIGURATION - Edit these paths for your setup
# ============================================================
$EC2_IP = "3.108.220.220"
$EC2_USER = "ubuntu"
$SSH_KEY = "C:\CP\plans\Detooz\detooz-key.pem"   # PATH OF PEM KEY HERE
$REMOTE_DIR = "/home/ubuntu/Detooz"
$BACKEND_DIR = "/home/ubuntu/Detooz/backend"
$REPO_DIR = "C:\CP\plans\Detooz"                  # PATH OF REPO HERE

# Colors
function Write-Step { param([string]$text) Write-Host "`n>> $text" -ForegroundColor Cyan }
function Write-Ok { param([string]$text) Write-Host "[OK] $text" -ForegroundColor Green }
function Write-Fail { param([string]$text) Write-Host "[FAIL] $text" -ForegroundColor Red }
function Write-Info { param([string]$text) Write-Host "   $text" -ForegroundColor Gray }

# SSH Helper
function Invoke-EC2 {
    param([string]$cmd)
    $sshTarget = "$EC2_USER@$EC2_IP"
    $result = ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 $sshTarget $cmd 2>&1
    return $result
}

# ============================================================
# STEP 1: GIT PUSH (unless skipped)
# ============================================================
if (-not $SkipPush) {
    Write-Step "STEP 1/5: Pushing to GitHub"

    Push-Location $REPO_DIR

    # Check for changes
    $status = git status --porcelain 2>&1
    if ($status) {
        git add -A

        if (-not $Message) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
            $changedFiles = (git diff --cached --name-only | Measure-Object).Count
            $Message = "Deploy: $changedFiles files updated ($timestamp)"
        }

        git commit -m $Message
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Git commit failed"
            Pop-Location
            exit 1
        }
        Write-Info "Committed: $Message"
    } else {
        Write-Info "No local changes to commit"
    }

    git push origin main 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Git push failed"
        Pop-Location
        exit 1
    }
    Write-Ok "Pushed to GitHub"
    Pop-Location
} else {
    Write-Step "STEP 1/5: Skipping git push (SkipPush flag set)"
}

# ============================================================
# STEP 2: TEST CONNECTION
# ============================================================
Write-Step "STEP 2/5: Testing EC2 connection"
$testResult = Invoke-EC2 "echo OK"
if ($testResult -ne "OK") {
    Write-Fail "Cannot connect to EC2 ($EC2_IP)"
    Write-Info "Check: SSH key at $SSH_KEY"
    Write-Info "Check: EC2 security group allows SSH (port 22)"
    exit 1
}
Write-Ok "Connected to EC2"

# ============================================================
# STEP 3: PULL LATEST CODE
# ============================================================
Write-Step "STEP 3/5: Pulling latest code on EC2"
$pullResult = Invoke-EC2 "cd $REMOTE_DIR && git pull origin main 2>&1"
Write-Info ($pullResult -join "`n")
Write-Ok "Code pulled"

# ============================================================
# STEP 4: DOCKER BUILD + DEPLOY
# ============================================================
if ($Quick) {
    Write-Step "STEP 4/5: Quick restart (no rebuild)"
    $deployResult = Invoke-EC2 "cd $BACKEND_DIR && sudo docker compose restart 2>&1"
    Write-Info ($deployResult -join "`n")
} else {
    Write-Step "STEP 4/5: Rebuilding Docker image and restarting"
    $deployResult = Invoke-EC2 "cd $BACKEND_DIR && sudo docker compose down 2>&1 && sudo docker compose build --no-cache 2>&1 && sudo docker compose up -d 2>&1"
    Write-Info ($deployResult -join "`n")
}
Write-Ok "Container deployed"

# ============================================================
# STEP 5: HEALTH CHECK
# ============================================================
Write-Step "STEP 5/5: Verifying health (waiting 10s for startup...)"
Start-Sleep -Seconds 10

$healthResult = Invoke-EC2 "curl -s http://localhost:8000/health"
if ($healthResult -match "healthy") {
    Write-Ok "Health check PASSED"

    $containerStatus = Invoke-EC2 "sudo docker ps 2>&1"
    Write-Info ($containerStatus -join "`n")
} else {
    Write-Fail "Health check FAILED"
    Write-Info "Response: $healthResult"
    Write-Info "Checking logs..."
    $logs = Invoke-EC2 "sudo docker logs detooz-backend --tail 20 2>&1"
    Write-Info ($logs -join "`n")
    exit 1
}

# ============================================================
# DONE
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor DarkGray
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "  Server: http://${EC2_IP}:8000" -ForegroundColor White
Write-Host "  Health: http://${EC2_IP}:8000/health" -ForegroundColor White
Write-Host "============================================" -ForegroundColor DarkGray
