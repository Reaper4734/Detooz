# Detooz Backend Analysis Report

## 1. Architecture Overview
The Detooz backend is Built on **FastAPI (v1.3.0)**, ensuring high performance through asynchronous operations (`async/await`). It follows a clean, modular structure that separates concerns:

- **Web Layer**: FastAPI routers handle HTTP requests.
- **Service Layer**: Business logic (detection, guardian management, etc.).
- **Data Layer**: SQLAlchemy for database operations (SQLite/PostgreSQL).
- **Communication Layer**: FCM (Firebase Cloud Messaging) for push notifications.

## 2. Core Components & Logic

### 2.1 Scam Detection Engine (`services/scam_detector.py`)
The heart of the backend, the Scam Detection Engine Uses a hybrid methodology:
1. **Pattern Matching**: Regex-based quick lookup for known high-risk keywords (KYC, Prize, OTP theft).
2. **Cloud AI Analysis**: Integrates with **Groq (Llama 3.3 70B)** for deep context analysis of suspicious messages.
3. **Screenshot Analysis**: Uses **OpenRouter (Meta Llama 3.2 11B Vision)** to analyze WhatsApp or UI screenshots for scam patterns.

### 2.2 Guardian System (`routers/guardian_link.py`, `routers/guardian_alerts.py`)
Provides a safety net by linking "Guardians" (trusted contacts) to vulnerable "Users":
- **Linking**: Secure OTP-based handshake to establish a trusted bond.
- **Alerting**: Automated triggers that send a high-priority push notification to the Guardian when a "Scam" or "High Risk" message is detected on the User's device.

### 2.3 Reputation System (`routers/reputation.py`)
Crowdsources security data:
- **Number Lookup**: Checks a local and external database of reported scammer numbers.
- **URL Analysis**: Scours for malicious short-links (bit.ly, tinyurl) frequently used in phishing.

## 3. API Infrastructure

| Category | Endpoint Range | Primary Function |
|----------|---------------|------------------|
| **Authentication**| `/api/auth/*` | Email, Google, and Phone OTP flows. |
| **Detection** | `/api/sms/*`, `/api/manual-scan/*`| Text and Image-based scam analysis. |
| **Guardian** | `/api/guardian/*` | Requests, alerts, and link management. |
| **Education** | `/api/education/*` | RSS feeds for security awareness. |
| **Feedback** | `/api/feedback/*` | Crowdsourced ML dataset improvement. |

## 4. Scalability & Deployment
- **Database**: Supports SQLite for development and PostgreSQL for production.
- **Caching**: **Redis** is utilized for temporary session storage and fast response for frequent lookups.
- **Containerization**: Deployable via Docker, integrated into the `deploy.ps1` CI/CD pipeline.

## 5. Security & Privacy
- **JWT Authentication**: Secure HS256-signed tokens for session management.
- **Consent Logs**: Tracks user permissions for data usage and training, complying with GDPR principles.
- **Data Anonymization**: Options for anonymous scanning without storing personal information.
