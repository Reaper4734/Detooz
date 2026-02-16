<#
.SYNOPSIS
    Detooz Integration Script - Pull latest changes from GitHub
.DESCRIPTION
    1. Stashes any local changes
    2. Pulls latest code from GitHub
    3. Restores stashed changes (if any)
    4. Runs flutter pub get
.EXAMPLE
    .\pull.ps1
    .\pull.ps1 -NoPubGet
    .\pull.ps1 -Branch dev
#>

param(
    [string]$Branch = "main",
    [switch]$NoPubGet
)

# ============================================================
# CONFIGURATION
# ============================================================
$REPO_DIR = "C:\CP\plans\Detooz"   # PATH OF REPO HERE
$APP_DIR = "$REPO_DIR\app"

# Colors
function Write-Step { param([string]$text) Write-Host "`n>> $text" -ForegroundColor Cyan }
function Write-Ok { param([string]$text) Write-Host "[OK] $text" -ForegroundColor Green }
function Write-Fail { param([string]$text) Write-Host "[FAIL] $text" -ForegroundColor Red }
function Write-Info { param([string]$text) Write-Host "   $text" -ForegroundColor Gray }

Push-Location $REPO_DIR

# ============================================================
# STEP 1: STASH LOCAL CHANGES
# ============================================================
Write-Step "STEP 1/4: Checking local changes"
$hasStash = $false
$status = git status --porcelain 2>&1
if ($status) {
    Write-Info "Local changes detected, stashing..."
    $stashOutput = git stash push -m "auto-stash before pull $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1
    $stashText = $stashOutput -join " "
    if ($stashText -match "Saved working directory") {
        $hasStash = $true
        Write-Ok "Changes stashed"
    }
    else {
        Write-Info "Nothing to stash (untracked only)"
    }
}
else {
    Write-Info "Working tree clean"
}

# ============================================================
# STEP 2: PULL FROM GITHUB
# ============================================================
Write-Step "STEP 2/4: Pulling from GitHub ($Branch)"
$pullResult = git pull origin $Branch 2>&1
$pullText = $pullResult -join "`n"
Write-Info $pullText

if ($LASTEXITCODE -ne 0) {
    Write-Fail "Git pull failed"
    if ($hasStash) {
        Write-Info "Restoring stashed changes..."
        git stash pop 2>&1
    }
    Pop-Location
    exit 1
}
Write-Ok "Pull complete"

# ============================================================
# STEP 3: RESTORE STASH
# ============================================================
Write-Step "STEP 3/4: Restoring local changes"
if ($hasStash) {
    $stashResult = git stash pop 2>&1
    $stashText = $stashResult -join "`n"
    if ($stashText -match "CONFLICT") {
        Write-Fail "Stash restore has conflicts - resolve manually"
        Write-Info $stashText
    }
    else {
        Write-Ok "Stashed changes restored"
    }
}
else {
    Write-Info "Nothing to restore"
}

# ============================================================
# STEP 4: FLUTTER PUB GET
# ============================================================
if (-not $NoPubGet) {
    Write-Step "STEP 4/4: Running flutter pub get"
    Push-Location $APP_DIR
    flutter pub get 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Dependencies updated"
    }
    else {
        Write-Fail "flutter pub get failed"
    }
    Pop-Location
}
else {
    Write-Step "STEP 4/4: Skipping flutter pub get (NoPubGet flag set)"
}

# ============================================================
# DONE
# ============================================================
Pop-Location
Write-Host ""
Write-Host "============================================" -ForegroundColor DarkGray
Write-Host "  Integration Complete!" -ForegroundColor Green
Write-Host "  Branch: $Branch" -ForegroundColor White
Write-Host "  Repo: $REPO_DIR" -ForegroundColor White
Write-Host "============================================" -ForegroundColor DarkGray
