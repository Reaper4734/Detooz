---
description: Push code to GitHub and deploy to EC2 via Docker
---

# Deploy to EC2

This workflow pushes your latest changes to GitHub and deploys them to EC2 using Docker.

## Prerequisites
- SSH key at `C:\CP\plans\Detooz\detooz-key.pem`
- EC2 instance running at `3.108.220.220`
- Docker installed on EC2

## Steps

// turbo-all

1. Run the deployment script:
```powershell
.\deploy.ps1
```
Working directory: `c:\CP\plans\Detooz`

## Options

- **Custom commit message**: `.\deploy.ps1 -Message "Fix login endpoint"`
- **Skip git push** (just redeploy): `.\deploy.ps1 -SkipPush`
- **Quick restart** (no rebuild): `.\deploy.ps1 -Quick`

## Manual Steps (if script fails)

1. Push to GitHub:
```powershell
cd C:\CP\plans\Detooz
git add -A; git commit -m "update"; git push origin main
```

2. SSH into EC2 and deploy:
```powershell
ssh -i "C:\CP\plans\Detooz\detooz-key.pem" ubuntu@3.108.220.220 "cd /home/ubuntu/Detooz && git pull origin main && cd backend && sudo docker compose down && sudo docker compose build --no-cache && sudo docker compose up -d"
```

3. Verify health:
```powershell
ssh -i "C:\CP\plans\Detooz\detooz-key.pem" ubuntu@3.108.220.220 "curl -s http://localhost:8000/health"
```
