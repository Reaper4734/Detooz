# 🚀 Cloud Deployment & CI/CD Implementation Plan

## Current Architecture Analysis

### What We Have

| Component | Current State | Production Need |
|-----------|---------------|-----------------|
| **Backend** | FastAPI (local) | Cloud-hosted API |
| **Database** | SQLite (detooz.db) | PostgreSQL |
| **Cache** | Redis (local) | Managed Redis |
| **Storage** | Local filesystem | Cloud storage |
| **Mobile App** | Debug APK | Play Store release |
| **ML Model** | TFLite in assets | CDN for model updates |

### Tech Stack Summary

```
Backend:  FastAPI 0.128.0, Python 3.11+
Database: SQLite → PostgreSQL (migration needed)
AI:       Groq API, Gemini API, TFLite (local)
Auth:     JWT tokens, Firebase Auth
Mobile:   Flutter 3.x, Android target
```

---

## Cloud Provider Comparison

### Option 1: Google Cloud Platform (GCP) ✅ Recommended

| Service | Use | Free Tier | Paid Estimate |
|---------|-----|-----------|---------------|
| Cloud Run | Backend hosting | 2M requests/mo | ~$15/mo |
| Cloud SQL | PostgreSQL | None | ~$10/mo |
| Cloud Storage | Uploads, models | 5GB | ~$2/mo |
| Memorystore | Redis | None | ~$15/mo |
| **Total** | - | - | **~$42/mo** |

**Why GCP?**
- Already using Gemini API (same ecosystem)
- $300 free credits available
- Cloud Run auto-scales to zero (cost-effective)

### Option 2: Railway (Simpler)

| Service | Use | Free Tier | Paid Estimate |
|---------|-----|-----------|---------------|
| Railway | Backend + DB + Redis | $5 credit/mo | ~$20/mo |

**Why Railway?**
- Simpler setup (1-click deploy)
- Built-in PostgreSQL and Redis
- Good for MVPs

### Option 3: Render + Supabase

| Service | Use | Free Tier | Paid Estimate |
|---------|-----|-----------|---------------|
| Render | Backend | 750 hrs/mo | ~$7/mo |
| Supabase | PostgreSQL | 500MB | ~$25/mo |
| Upstash | Redis | 10k cmds/day | Free |
| **Total** | - | - | **~$32/mo** |

### Decision: **GCP (Cloud Run + Cloud SQL)**
- Best for scale
- Matches existing Gemini integration
- Most professional setup

---

## Phase 1: Backend Containerization

### Dockerfile

```dockerfile
# backend/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/
COPY .env.production ./

# Expose port
EXPOSE 8080

# Run with gunicorn
CMD ["gunicorn", "app.main:app", "-w", "2", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8080"]
```

### Docker Compose (Local Testing)

```yaml
# backend/docker-compose.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/detooz
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: detooz
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

---

## Phase 2: Database Migration (SQLite → PostgreSQL)

### Step 1: Update Database URL Config

```python
# app/config.py (updated)
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite+aiosqlite:///./detooz.db"  # Local fallback
)

# Handle Heroku/Railway postgres:// → postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
```

### Step 2: Alembic Migration Setup

```bash
# Initialize Alembic (if not done)
alembic init alembic

# Generate migration from current models
alembic revision --autogenerate -m "Initial migration"

# Apply to new PostgreSQL
DATABASE_URL=postgresql://... alembic upgrade head
```

### Step 3: Data Export/Import Script

```python
# scripts/migrate_sqlite_to_postgres.py
import sqlite3
import psycopg2
import os

def migrate():
    # Connect to SQLite
    sqlite_conn = sqlite3.connect('detooz.db')
    
    # Connect to PostgreSQL
    pg_conn = psycopg2.connect(os.getenv('DATABASE_URL'))
    
    tables = ['users', 'scans', 'trusted_senders', 'feedback', ...]
    
    for table in tables:
        # Export from SQLite
        sqlite_cur = sqlite_conn.execute(f"SELECT * FROM {table}")
        rows = sqlite_cur.fetchall()
        
        # Import to PostgreSQL
        # ... insert logic
    
    print("Migration complete!")
```

---

## Phase 3: CI/CD Pipeline (GitHub Actions)

### Backend CI/CD

```yaml
# .github/workflows/backend-deploy.yml
name: Backend CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
  pull_request:
    branches: [main]
    paths:
      - 'backend/**'

env:
  PROJECT_ID: detooz-prod
  REGION: asia-south1
  SERVICE: detooz-api

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
          pip install pytest pytest-asyncio
      
      - name: Run tests
        run: |
          cd backend
          pytest tests/ -v

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Build and push Docker image
        run: |
          cd backend
          gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy $SERVICE \
            --image gcr.io/$PROJECT_ID/$SERVICE \
            --region $REGION \
            --platform managed \
            --allow-unauthenticated \
            --set-env-vars "DATABASE_URL=${{ secrets.DATABASE_URL }}" \
            --set-env-vars "GROQ_API_KEY=${{ secrets.GROQ_API_KEY }}" \
            --set-env-vars "GOOGLE_API_KEY=${{ secrets.GOOGLE_API_KEY }}"
```

### Mobile App CI/CD

```yaml
# .github/workflows/flutter-build.yml
name: Flutter CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
  pull_request:
    branches: [main]
    paths:
      - 'app/**'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: |
          cd app
          flutter pub get
      
      - name: Run tests
        run: |
          cd app
          flutter test
      
      - name: Build APK
        run: |
          cd app
          flutter build apk --release
      
      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: app/build/app/outputs/flutter-apk/app-release.apk

  deploy-play-store:
    needs: build-android
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Build App Bundle
        run: |
          cd app
          flutter pub get
          flutter build appbundle --release
      
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SA }}
          packageName: com.detooz.app
          releaseFiles: app/build/app/outputs/bundle/release/app-release.aab
          track: internal  # or 'alpha', 'beta', 'production'
```

---

## Phase 4: Environment Configuration

### Required Secrets (GitHub)

| Secret | Purpose |
|--------|---------|
| `GCP_SA_KEY` | GCP service account JSON |
| `DATABASE_URL` | PostgreSQL connection string |
| `GROQ_API_KEY` | Groq API for scam detection |
| `GOOGLE_API_KEY` | Gemini API key |
| `PLAY_STORE_SA` | Play Store service account |
| `KEYSTORE_BASE64` | Android signing keystore |
| `KEY_ALIAS` | Keystore alias |
| `KEY_PASSWORD` | Keystore password |

### Production Environment Variables

```bash
# .env.production
DATABASE_URL=postgresql://user:pass@/detooz?host=/cloudsql/project:region:instance
REDIS_URL=redis://10.0.0.1:6379
GROQ_API_KEY=gsk_xxx
GOOGLE_API_KEY=AIza_xxx
JWT_SECRET=your-production-secret
ENVIRONMENT=production
```

---

## Phase 5: GCP Setup Steps

### 1. Create Project

```bash
# Create project
gcloud projects create detooz-prod --name="Detooz Production"

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com
```

### 2. Create Cloud SQL Instance

```bash
gcloud sql instances create detooz-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=asia-south1

gcloud sql databases create detooz --instance=detooz-db

gcloud sql users create detooz_user \
  --instance=detooz-db \
  --password=SECURE_PASSWORD
```

### 3. Deploy to Cloud Run

```bash
cd backend

# Build and submit
gcloud builds submit --tag gcr.io/detooz-prod/detooz-api

# Deploy
gcloud run deploy detooz-api \
  --image gcr.io/detooz-prod/detooz-api \
  --region asia-south1 \
  --add-cloudsql-instances detooz-prod:asia-south1:detooz-db \
  --set-env-vars "DATABASE_URL=postgresql://..." \
  --allow-unauthenticated
```

### 4. Set Up Custom Domain (Optional)

```bash
# Map domain
gcloud run domain-mappings create \
  --service detooz-api \
  --domain api.detooz.com \
  --region asia-south1
```

---

## Phase 6: Monitoring & Logging

### Cloud Monitoring Setup

```yaml
# monitoring/alerts.yaml
displayName: API Error Rate Alert
conditions:
  - displayName: Error rate > 1%
    conditionThreshold:
      filter: resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count"
      comparison: COMPARISON_GT
      thresholdValue: 0.01
      duration: 300s

notificationChannels:
  - email: your-email@example.com
```

### Application Logging

```python
# app/core/logging.py
import logging
from google.cloud import logging as cloud_logging

def setup_logging():
    if os.getenv('ENVIRONMENT') == 'production':
        client = cloud_logging.Client()
        client.setup_logging()
    else:
        logging.basicConfig(level=logging.INFO)
```

---

## Phase 7: Mobile App Production Setup

### 1. Update API Base URL

```dart
// lib/services/api_service.dart
class ApiConfig {
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://api.detooz.com';  // Production
    }
    return 'http://10.0.2.2:8000';  // Local emulator
  }
}
```

### 2. Android Signing

```bash
# Generate keystore
keytool -genkey -v -keystore detooz-release.keystore \
  -alias detooz -keyalg RSA -keysize 2048 -validity 10000
```

```properties
# android/key.properties
storePassword=xxx
keyPassword=xxx
keyAlias=detooz
storeFile=../detooz-release.keystore
```

### 3. Play Store Listing Prep

| Asset | Requirement |
|-------|-------------|
| App icon | 512x512 PNG |
| Feature graphic | 1024x500 PNG |
| Screenshots | At least 2 per device type |
| Privacy Policy | URL required |
| Short description | Max 80 chars |
| Full description | Max 4000 chars |

---

## Cost Estimate (Monthly)

| Service | Development | Production |
|---------|-------------|------------|
| Cloud Run | $0 (free tier) | $15-30 |
| Cloud SQL | $0 (trial) | $10-25 |
| Cloud Storage | $0 (5GB free) | $2-5 |
| Domain | - | $12/year |
| Play Store | - | $25 (one-time) |
| **Total** | **$0** | **~$50/mo** |

---

## Implementation Timeline

| Week | Tasks |
|------|-------|
| **1** | Dockerize backend, set up GCP project |
| **2** | Deploy to Cloud Run, migrate database |
| **3** | Set up CI/CD pipelines |
| **4** | Configure monitoring, custom domain |
| **5** | Prepare Play Store listing, beta release |
| **6** | Production launch |

---

## Files to Create

```
Detooz/
├── backend/
│   ├── Dockerfile                    # [NEW]
│   ├── docker-compose.yml           # [NEW]
│   ├── .env.production              # [NEW]
│   └── cloudbuild.yaml              # [NEW]
├── .github/
│   └── workflows/
│       ├── backend-deploy.yml       # [NEW]
│       └── flutter-build.yml        # [NEW]
├── app/
│   └── android/
│       └── key.properties           # [NEW]
└── docs/
    └── deployment/
        ├── GCP_SETUP.md             # [NEW]
        └── PLAYSTORE_CHECKLIST.md   # [NEW]
```

---

## Next Steps

1. **Approve this plan**
2. Create Dockerfile and docker-compose.yml
3. Set up GCP project with Cloud Run
4. Configure GitHub Actions workflows
5. Test deployment pipeline
6. Prepare Play Store assets

Ready to proceed with implementation?
